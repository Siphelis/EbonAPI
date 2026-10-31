local _, ns = ...

local Profiles = {}
ns.Profiles = Profiles

local api = ns.api
local Codec = EbonAPI.Profile
local Key = ns.Catalog.Key

local db = nil
local SAVED_SLOTS = ns.Const.SAVED_SLOTS

local find, sub, match, gmatch, concat, byte = string.find, string.sub, string.match, string.gmatch, table.concat, string.byte

-- Format A : players[nom] = "c|slot,h,e,l[,k,u];...[|x|xh]". c porte parfois les lettres L, K, U (table l, k ou u
-- vide au niveau du joueur). Dans un slot, l vaut "" quand il est absent et "~" quand il vaut la chaine vide ;
-- k et u ne sont ecrits (les deux champs) que si l'un des deux existe. Les separateurs | , ; sont refuses a la
-- reception (x garde ses ;). Un profil que le format ne sait pas porter sans perte reste une table lisible.
local KNOWN = { c = true, h = true, e = true, l = true, k = true, u = true, x = true, xh = true, t = true }
local EMPTY_L = "~"
local migration = { migrated = 0, failed = 0, reasons = {} }

local function IsInt(n)
    return type(n) == "number" and n >= 0 and n % 1 == 0
end

local function Entries(t, slots, name)
    if t == nil then return true end
    if type(t) ~= "table" then return nil, "bad_type" end
    for slot, v in pairs(t) do
        if slots[slot] == nil then return nil, "orphan_" .. name end
        if type(v) ~= "string" then return nil, "bad_type" end
    end
    return true
end

local function Encode(p)
    if type(p) ~= "table" then return nil, "bad_type" end
    for key in pairs(p) do
        if not KNOWN[key] then return nil, "unknown_field" end
    end
    if not IsInt(p.c) then return nil, "bad_class" end
    if type(p.h) ~= "table" or type(p.e) ~= "table" then return nil, "bad_type" end

    local slots, list = {}, {}
    for slot, hash in pairs(p.h) do
        if not IsInt(slot) or type(hash) ~= "string" or type(p.e[slot]) ~= "string" then return nil, "bad_slot" end
        slots[slot] = true
        list[#list + 1] = slot
    end
    for slot in pairs(p.e) do
        if not slots[slot] then return nil, "bad_slot" end
    end
    for _, name in ipairs({ "l", "k", "u" }) do
        local ok, why = Entries(p[name], slots, name)
        if not ok then return nil, why end
    end
    if (p.x == nil) ~= (p.xh == nil) then return nil, "x_xh_unpaired" end
    if p.x ~= nil and (type(p.x) ~= "string" or type(p.xh) ~= "string") then return nil, "bad_type" end
    table.sort(list)

    local k, u, l = p.k, p.u, p.l
    local parts = {}
    for i = 1, #list do
        local slot = list[i]
        local hash, text = p.h[slot], p.e[slot]
        local lf = l and l[slot]
        local kf, uf = k and k[slot], u and u[slot]
        if find(hash, "[|,;]") or find(text, "[|,;]") then return nil, "separator" end
        if lf then
            if find(lf, "[|,;]") then return nil, "separator" end
            if lf == EMPTY_L then return nil, "reserved" end
            if lf == "" then lf = EMPTY_L end
        end
        local entry = slot .. "," .. hash .. "," .. text .. "," .. (lf or "")
        if kf or uf then
            if kf == "" or uf == "" then return nil, "empty_value" end
            if (kf and find(kf, "[|,;]")) or (uf and find(uf, "[|,;]")) then return nil, "separator" end
            entry = entry .. "," .. (kf or "") .. "," .. (uf or "")
        end
        parts[i] = entry
    end

    local head = tostring(p.c)
    if l and next(l) == nil then head = head .. "L" end
    if k and next(k) == nil then head = head .. "K" end
    if u and next(u) == nil then head = head .. "U" end
    local out = head .. "|" .. concat(parts, ";")
    if p.x ~= nil then
        if find(p.x, "[|,]") or find(p.xh, "[|,;]") then return nil, "separator" end
        out = out .. "|" .. p.x .. "|" .. p.xh
    end
    return out
end

local function SplitSlot(entry)
    local fields, n = {}, 0
    for f in gmatch(entry .. ",", "([^,]*),") do
        n = n + 1
        fields[n] = f
    end
    return fields
end

local function Decode(value)
    if type(value) ~= "string" then return value end
    local bar = find(value, "|", 1, true)
    local head = sub(value, 1, bar - 1)
    local rest = sub(value, bar + 1)
    local slotsPart, x, xh = rest, nil, nil
    local bar2 = find(rest, "|", 1, true)
    if bar2 then
        slotsPart = sub(rest, 1, bar2 - 1)
        local tail = sub(rest, bar2 + 1)
        local bar3 = find(tail, "|", 1, true)
        x, xh = sub(tail, 1, bar3 - 1), sub(tail, bar3 + 1)
    end
    local p = { c = tonumber(match(head, "^%d+")), h = {}, e = {}, x = x, xh = xh }
    if find(head, "L", 1, true) then p.l = {} end
    if find(head, "K", 1, true) then p.k = {} end
    if find(head, "U", 1, true) then p.u = {} end
    for entry in gmatch(slotsPart, "[^;]+") do
        local f = SplitSlot(entry)
        local slot = tonumber(f[1])
        p.h[slot], p.e[slot] = f[2], f[3]
        local lf = f[4]
        if lf and lf ~= "" then
            p.l = p.l or {}
            p.l[slot] = lf == EMPTY_L and "" or lf
        end
        if f[5] and f[5] ~= "" then p.k = p.k or {}; p.k[slot] = f[5] end
        if f[6] and f[6] ~= "" then p.u = p.u or {}; p.u[slot] = f[6] end
    end
    return p
end

-- Lectures partielles, sans decoder le profil entier.
local function ClassOf(value)
    if type(value) == "string" then
        -- Encode ecrit toujours tostring(c) en tete : on lit les chiffres sans creer de chaine.
        local c, i = byte(value, 1) - 48, 2
        local b = byte(value, i)
        while b and b >= 48 and b <= 57 do c = c * 10 + b - 48; i = i + 1; b = byte(value, i) end
        return c
    end
    return value.c
end

-- Un echo par entree, lu directement dans la chaine (aucune copie, aucune table). Les entrees commencent par
-- | (la 1re) ou ; ; x ne contient jamais de virgule (OnBans la refuse), donc rien n'est lu apres la liste.
local TEXT = "[|;]%d+,[^,|;]*,([^,|;]*)"
local SLOT = "[|;](%d+),([^,|;]*),([^,|;]*),([^,|;]*)"

-- Positions des barres du format : la liste des slots est entre la 1re et la 2e, x entre la 2e et la 3e, xh apres.
local function Bars(value)
    local bar = find(value, "|", 1, true)
    local bar2 = bar and find(value, "|", bar + 1, true)
    local bar3 = bar2 and find(value, "|", bar2 + 1, true)
    return bar, bar2, bar3
end

local function Players()
    return db.account.players
end

local function Index(class)
    if type(class) == "number" then return class end
    return Codec.ClassIndex(class)
end

local folds = {}

local EMPTY_FOLD = { sum = {}, people = 0, builds = 0, version = 0 }

local function Absorb(text, name, sign, total, hits)
    local ids, _, n = Codec.DecodeBuild(text)
    if not ids and sign == 1 then
        api:Reject("PROFILE.REJECTED", { sender = name, reason = "undecodable_build", sample = tostring(text):sub(1, 60) })
    end
    if ids then
        total = total + 1
        hits = hits or {}
        local seen = {}
        for j = 1, n do
            local id = Key(ids[j])
            if not seen[id] then
                seen[id] = true
                hits[id] = (hits[id] or 0) + 1
            end
        end
    end
    return total, hits
end

local function Contribute(fold, name, player, sign) -- player : chaine du format A ou table lisible
    local total, hits = 0, nil
    if type(player) == "string" then
        for text in gmatch(player, TEXT) do
            if text ~= "" then total, hits = Absorb(text, name, sign, total, hits) end
        end
    else
        for _, text in pairs(player.e) do
            if text ~= "" then total, hits = Absorb(text, name, sign, total, hits) end
        end
    end
    if total == 0 then return end

    fold.people = fold.people + sign
    fold.builds = fold.builds + sign * total
    local sum = fold.sum
    for id, n in pairs(hits) do
        local value = (sum[id] or 0) + sign * n / total
        if value < 1e-9 and value > -1e-9 then value = nil end
        sum[id] = value
    end
    fold.version = fold.version + 1
end

local function BuildFold(class)
    local fold = { sum = {}, people = 0, builds = 0, version = 0 }
    for name, player in pairs(Players()) do
        if ClassOf(player) == class then Contribute(fold, name, player, 1) end
    end
    folds[class] = fold
    return fold
end

function Profiles.Fold(class)
    class = Index(class)
    if not class then return EMPTY_FOLD end
    return folds[class] or BuildFold(class)
end

local function Store(name, player)
    local text, why = Encode(player)
    if text then
        Players()[name] = text
    else
        Players()[name] = player
        api:Reject("PROFILE.REJECTED", { sender = name, reason = "not_encodable_" .. why, sample = "kept as a readable table" })
    end
end

local function Player(name, class)
    local value = Players()[name]
    if value then return Decode(value) end
    local player = { c = class, h = {}, e = {} }
    Store(name, player)
    return player
end

local function Reshape(name, player, class, change)
    local before = folds[player.c]
    if before then Contribute(before, name, player, -1) end
    change(player)
    player.c = class
    Store(name, player)
    local after = folds[class]
    if after then Contribute(after, name, player, 1) end
    ns.Matrix.Touch()
    ns.Events.Fire("EB_PROFILES_CHANGED")
end

-- Refuse une valeur recue qui porterait un separateur du format ; rien n'est change.
local function Clean(sender, ...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        local bad = type(v) == "number" and v % 1 ~= 0 and "bad_value"
            or type(v) == "string" and find(v, "[|,;]") and "separator"
            or type(v) ~= "number" and type(v) ~= "string" and v ~= nil and "bad_value"
        if bad then
            api:Reject("PROFILE.REJECTED", { sender = sender, reason = bad, sample = tostring(v):sub(1, 60) })
            return false
        end
    end
    return true
end

local function OnSlots(_, sender, class, slots)
    if not Clean(sender, class, unpack(slots)) then return end
    if not IsInt(class) then
        api:Reject("PROFILE.REJECTED", { sender = sender, reason = "bad_value", sample = tostring(class):sub(1, 60) })
        return
    end
    local keep = {}
    for i = 1, #slots do keep[slots[i]] = true end

    -- Profil deja en chaine : "rien n'a change" se lit sur la chaine, sans decoder.
    local value = Players()[sender]
    if type(value) == "string" and ClassOf(value) == class then
        local stale = false
        for slot in gmatch(value, "[|;](%d+),") do
            if not keep[tonumber(slot)] then stale = true; break end
        end
        if not stale then return end
    end

    local player = Player(sender, class)
    local stale = false
    for slot in pairs(player.h) do
        if not keep[slot] then stale = true; break end
    end
    if not stale and player.c == class then return end

    Reshape(sender, player, class, function(p)
        for slot in pairs(p.h) do
            if not keep[slot] then
                p.h[slot] = nil
                p.e[slot] = nil
                if p.k then p.k[slot] = nil end
                if p.u then p.u[slot] = nil end
                if p.l then p.l[slot] = nil end
            end
        end
    end)
end

local function OnBuild(_, sender, class, slot, hash, text, locked)
    if slot > SAVED_SLOTS then
        api:Reject("PROFILE.REJECTED", { sender = sender, reason = "slot_limit", sample = "slot " .. tostring(slot) })
        return
    end
    if not Clean(sender, class, slot, hash, text, locked) then return end
    if locked == EMPTY_L then
        api:Reject("PROFILE.REJECTED", { sender = sender, reason = "reserved", sample = locked })
        return
    end
    local value = Players()[sender]
    if type(value) == "string" and type(hash) == "string" and ClassOf(value) == class then
        local key = slot .. "," .. hash .. ","
        if find(value, "|" .. key, 1, true) or find(value, ";" .. key, 1, true) then return end
    end
    local player = Player(sender, class)
    if player.h[slot] == hash and player.c == class then return end

    Reshape(sender, player, class, function(p)
        if p.h[slot] ~= hash and p.u then p.u[slot] = nil end
        p.h[slot] = hash
        p.e[slot] = text
        if locked then
            p.l = p.l or {}
            p.l[slot] = locked
        elseif p.l then
            p.l[slot] = nil
        end
    end)
end

local function OnBans(_, sender, class, hash, text)
    if not Clean(sender, class, hash) then return end
    if type(text) == "string" and find(text, "[|,]") then
        api:Reject("PROFILE.REJECTED", { sender = sender, reason = "separator", sample = text:sub(1, 60) })
        return
    end
    local value = Players()[sender]
    if type(value) == "string" and type(hash) == "string" and ClassOf(value) == class then
        local _, _, bar3 = Bars(value)
        if bar3 and sub(value, bar3 + 1) == hash then return end
    end
    local player = Player(sender, class)
    if player.xh == hash and player.c == class then return end

    Reshape(sender, player, class, function(p)
        p.xh = hash
        p.x = text
    end)

    if ns.Matrix and ns.Matrix.InvalidateBanVotes then
        ns.Matrix.InvalidateBanVotes()
    end
end

local function Field(t, slot)
    return t and t[slot]
end

function Profiles.Merge(name, class, builds)
    if name == UnitName("player") then return false end
    local players = Players()
    if not players[name] and next(builds) == nil then return false end
    for slot, b in pairs(builds) do
        if slot <= SAVED_SLOTS and not Clean(name, b.echoes, b.locked, b.category, b.usage) then return false end
        if slot <= SAVED_SLOTS and b.locked == EMPTY_L then
            api:Reject("PROFILE.REJECTED", { sender = name, reason = "reserved", sample = b.locked })
            return false
        end
    end
    local stored = players[name]
    local lazy = type(stored) == "string"
    local player = not lazy and Player(name, class) or nil
    local changed = player and player.c ~= class
    local hashes = {}
    local kept = {}
    for slot, b in pairs(builds) do
        if slot > SAVED_SLOTS then
            api:Reject("PROFILE.REJECTED", { sender = name, reason = "slot_limit", sample = "slot " .. tostring(slot) })
        else
            kept[slot] = b
        end
    end
    for slot, b in pairs(kept) do
        local signed = class .. ":" .. slot .. ":" .. b.echoes
        if b.locked then signed = signed .. ":" .. b.locked end
        hashes[slot] = Codec.Signature(signed)
    end
    if lazy then
        -- Profil en chaine : on ecrit la chaine que donnerait Encode pour ces slots et on la compare au debut de la
        -- chaine stockee (x/xh restent apres). Egale = rien n'a change, sans decoder. Sinon (y compris drapeaux
        -- L/K/U ou classe differente) on decode et on suit le chemin d'avant.
        local list = {}
        for slot in pairs(kept) do list[#list + 1] = slot end
        table.sort(list)
        local parts = {}
        for i = 1, #list do
            local slot = list[i]
            local b = kept[slot]
            local lf = b.locked
            if lf == "" then lf = EMPTY_L end
            local entry = slot .. "," .. hashes[slot] .. "," .. b.echoes .. "," .. (lf or "")
            if b.category or b.usage then entry = entry .. "," .. (b.category or "") .. "," .. (b.usage or "") end
            parts[i] = entry
        end
        local want = tostring(class) .. "|" .. concat(parts, ";")
        if find(stored, want, 1, true) == 1 then
            local nextChar = byte(stored, #want + 1)
            if nextChar == nil or nextChar == 124 then return false end
        end
        player = Decode(stored)
        changed = player.c ~= class
    end
    for slot, b in pairs(kept) do
        local hash = hashes[slot]
        if player.h[slot] ~= hash or Field(player.k, slot) ~= b.category or Field(player.u, slot) ~= b.usage
            or Field(player.l, slot) ~= b.locked then
            changed = true
        end
    end
    if not changed then
        for slot in pairs(player.h) do
            if not kept[slot] then
                changed = true
                break
            end
        end
    end
    if not changed then return false end

    Reshape(name, player, class, function(p)
        for slot in pairs(p.h) do
            if not kept[slot] then p.h[slot], p.e[slot] = nil, nil end
        end
        p.k, p.u, p.l = nil, nil, nil
        for slot, b in pairs(kept) do
            p.h[slot], p.e[slot] = hashes[slot], b.echoes
            if b.locked then
                p.l = p.l or {}
                p.l[slot] = b.locked
            end
            if b.category then
                p.k = p.k or {}
                p.k[slot] = b.category
            end
            if b.usage then
                p.u = p.u or {}
                p.u[slot] = b.usage
            end
        end
    end)
    return true
end

-- Un appel par slot, sans table : fn(nom, classe, slot, hash, echos, verrous).
function Profiles.EachSlot(fn)
    for name, value in pairs(Players()) do
        if type(value) == "string" then
            local class = ClassOf(value)
            for slot, hash, text, lf in gmatch(value, SLOT) do
                if lf == EMPTY_L then lf = "" elseif lf == "" then lf = nil end
                fn(name, class, tonumber(slot), hash, text, lf)
            end
        else
            for slot, text in pairs(value.e) do
                fn(name, value.c, slot, value.h[slot], text, value.l and value.l[slot])
            end
        end
    end
end

function Profiles.Get(name)
    local value = Players()[name]
    return value and Decode(value)
end

function Profiles.EachBuild(class, fn)
    class = Index(class)
    if not class then return end
    for name, value in pairs(Players()) do
        if ClassOf(value) == class then
            if type(value) == "string" then
                for text in gmatch(value, TEXT) do
                    if text ~= "" then fn(name, text) end
                end
            else
                for _, text in pairs(value.e) do
                    if text ~= "" then fn(name, text) end
                end
            end
        end
    end
end

function Profiles.EachBanList(class, fn)
    class = Index(class)
    if not class then return end
    for name, value in pairs(Players()) do
        if ClassOf(value) == class then
            local text
            if type(value) == "string" then
                local _, bar2, bar3 = Bars(value)
                if bar3 then text = sub(value, bar2 + 1, bar3 - 1) end
            else
                text = value.x
            end
            if text and text ~= "" then
                local lists = Codec.DecodeBans(text)
                if lists then
                    for i = 1, #lists do fn(name, lists[i]) end
                else
                    api:Reject("PROFILE.REJECTED", { sender = name, reason = "undecodable_bans", sample = text:sub(1, 60) })
                end
            end
        end
    end
end

function Profiles.Count(class)
    class = Index(class)
    local n = 0
    for _, value in pairs(Players()) do
        if class == nil or ClassOf(value) == class then n = n + 1 end
    end
    return n
end

Profiles.Encode = Encode
Profiles.Decode = Decode

function Profiles.Migration() return migration end

function Profiles.Wipe()
    db.account.players = {}
    folds = {}
    if ns.Matrix and ns.Matrix.InvalidateBanVotes then
        ns.Matrix.InvalidateBanVotes()
    end
end

function Profiles.SendBans()
    local class = ns.Build.PlayerClassToken()
    if not class then return false end

    local lists = {}
    for _, build in pairs(EbonAPIEbonBuildsDB.builds or {}) do
        local list = build.class == class and build.settings and build.settings.echoBanList
        if list and next(list) then
            local ids = {}
            for spellId in pairs(list) do
                local id = tonumber(spellId)
                if id then ids[#ids + 1] = id end
            end
            if #ids > 0 then lists[#lists + 1] = ids end
        end
    end

    local ok = api:SetProfileBans(lists)
    if not ok then
        api:Report(api:Problem("PROFILE.SEND_FAILED", { class = class }))
    end
    return ok
end

-- Migration unique : chaque profil encore sous forme de table passe au format A ; un echec garde la table
-- lisible (jamais supprimee) et est compte avec son motif.
local function Migrate()
    migration = { migrated = 0, failed = 0, reasons = {} }
    for name, value in pairs(Players()) do
        if type(value) == "table" then
            local text, why = Encode(value)
            if text then
                Players()[name] = text
                migration.migrated = migration.migrated + 1
            else
                migration.failed = migration.failed + 1
                migration.reasons[why] = (migration.reasons[why] or 0) + 1
                api:Reject("PROFILE.REJECTED", { sender = name, reason = "migration_" .. why, sample = "kept as a readable table" })
            end
        end
    end
    db.account.playersFormat = "A"
end

function Profiles.Load()
    db = api:DB({ account = { players = {} } })
    migration = { migrated = 0, failed = 0, reasons = {} }
    if db.account.playersFormat ~= "A" then Migrate() end
end

function Profiles.Init()
    Profiles.Load()

    api:On("PROFILE_SLOTS", OnSlots)
    api:On("PROFILE_BUILD", OnBuild)
    api:On("PROFILE_BANS", OnBans)

    ns.Events.On("EB_BUILDS_CHANGED", Profiles.SendBans, "Profiles bans")
    Profiles.SendBans()
end
