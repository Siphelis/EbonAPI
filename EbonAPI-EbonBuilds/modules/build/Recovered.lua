EbonBuilds.Recovered = EbonBuilds.Recovered or {}
local Recovered = EbonBuilds.Recovered

local callbacks = {}
local cache = nil
local byName = nil

local function Emit(kind)
    for i = 1, #callbacks do
        callbacks[i](kind)
    end
end

local function Quality(spellId)
    local data = EbonAPI.EchoCatalog.Entry(spellId)
    return data and data.quality or 0
end

local function SortEchoes(a, b)
    return a.spellId < b.spellId
end

local function Signature(class, echoes)
    local parts = { class or "" }
    for i = 1, #echoes do
        local e = echoes[i]
        parts[#parts + 1] = e.spellId .. "." .. e.quality .. "." .. e.stacks
    end
    return table.concat(parts, "|")
end

local function ByNameThenSignature(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.sig < b.sig
end

local function Copy(entry)
    local echoes = {}
    for i = 1, #entry.echoes do
        local e = entry.echoes[i]
        echoes[i] = { spellId = e.spellId, quality = e.quality, stacks = e.stacks, locked = e.locked }
    end
    return {
        name      = entry.name,
        class     = entry.class,
        echoes    = echoes,
        favorite  = entry.favorite,
        recovered = entry.recovered,
    }
end

local function FromFavorite(fav, keys)
    local echoes = {}
    for _, e in ipairs(fav.echoes or {}) do
        echoes[#echoes + 1] = {
            spellId = e.spellId,
            quality = e.quality or 0,
            stacks  = e.stacks or 1,
        }
    end
    table.sort(echoes, SortEchoes)
    local sig = Signature(fav.class, echoes)
    keys[sig] = true
    return {
        name        = fav.name or "",
        class       = fav.class,
        echoes      = echoes,
        favorite    = true,
        recovered   = fav.source == "recovered",
        sig         = sig,
    }
end

local floor = math.floor

local lightMeta = {
    __index = function(entry, field)
        if field ~= "echoes" then return nil end
        local keys, lockSet = rawget(entry, "keys"), rawget(entry, "lockSet")
        local echoes = {}
        for i = 1, #keys do
            local id = floor(keys[i] / 64)
            local flag = nil
            if lockSet then flag = lockSet[id] == true end
            echoes[i] = { spellId = id, quality = Quality(id), stacks = keys[i] - id * 64, locked = flag }
        end
        rawset(entry, "echoes", echoes)
        return echoes
    end,
}

local function Scan(me)
    if not EbonBuilds.Profiles then return {} end
    local Profile = EbonAPI.Profile
    local qualities, parts, scratch = {}, {}, {}
    local order, byKey = {}, {}
    EbonBuilds.Profiles.EachSlot(function(name, class, _, hash, text, locked)
        if name == me or not hash or not text or text == "" then return end
        if not EbonBuilds.Profiles.IsComplete(text, locked) then return end
        local token = Profile.ClassToken(class)
        local ids, stacks, n = Profile.DecodeBuild(text)
        if not token or not ids then return end
        local lockedIds = locked and Profile.DecodeLocked(locked)
        local lockSet, lockN = nil, n
        if lockedIds then
            lockSet, lockN = {}, 0
            for i = 1, #lockedIds do lockSet[lockedIds[i]] = true end
            for i = 1, n do
                if lockSet[ids[i]] then lockN = lockN + 1 end
            end
        end
        local keys = {}
        local ascending = true
        for i = 1, n do
            local k = ids[i] * 64 + (stacks[i] or 1)
            keys[i] = k
            if i > 1 and k < keys[i - 1] then ascending = false end
        end
        if not ascending then table.sort(keys) end
        parts[1] = token
        for i = 1, n do
            local k = keys[i]
            local part = scratch[k]
            if not part then
                local id = floor(k / 64)
                local q = qualities[id]
                if not q then
                    q = Quality(id)
                    qualities[id] = q
                end
                part = id .. "." .. q .. "." .. (k - id * 64)
                scratch[k] = part
            end
            parts[i + 1] = part
        end
        for i = n + 2, #parts do parts[i] = nil end
        local sig = table.concat(parts, "|")
        local ck = name .. "\0" .. sig
        if byKey[ck] == nil then
            order[#order + 1] = ck
            byKey[ck] = setmetatable({
                name      = name,
                class     = token,
                favorite  = false,
                recovered = true,
                sig       = sig,
                keys      = keys,
                lockSet   = lockSet,
                lockN     = lockN,
            }, lightMeta)
        end
    end)
    table.sort(order)
    local found = {}
    for i = 1, #order do found[i] = byKey[order[i]] end
    return found
end

local scanned, scannedFor, scannedVersion

local function Candidates(me, keys)
    local Matrix = EbonBuilds.Matrix
    local version = Matrix and Matrix.Version and Matrix.Version()
    if scanned == nil or scannedFor ~= me or scannedVersion ~= version then
        scanned, scannedFor, scannedVersion = Scan(me), me, version
    end
    local found = scanned
    local out, seen = {}, {}
    for i = 1, #found do
        local c = found[i]
        if not seen[c.sig] and not keys[c.sig] then
            seen[c.sig] = true
            out[#out + 1] = c
        end
    end
    return out
end

local function Build()
    local keys, favorites = {}, {}
    local list = EbonBuilds.Favorites.List()
    for i = 1, #list do
        favorites[#favorites + 1] = FromFavorite(list[i], keys)
    end
    table.sort(favorites, ByNameThenSignature)
    local out = {}
    for i = 1, #favorites do
        out[#out + 1] = favorites[i]
    end
    for _, c in ipairs(Candidates(UnitName("player"), keys)) do
        out[#out + 1] = c
    end
    return out
end

local function Rebuild()
    cache = Build()
    byName = {}
    for i = 1, #cache do
        local name = cache[i].name
        if byName[name] == nil then byName[name] = cache[i] end
    end
    return cache
end

local function Ensure()
    if cache == nil then return Rebuild() end
    return cache
end

function Recovered.Entries()
    return Ensure()
end

function Recovered.Peek(name)
    Ensure()
    return byName[name]
end

function Recovered.List()
    return Ensure()
end

function Recovered.Get(name)
    local entries = Ensure()
    for i = 1, #entries do
        if entries[i].name == name then return Copy(entries[i]) end
    end
    return nil
end

function Recovered.Counts()
    local entries = Ensure()
    local favorites, auto = 0, 0
    for i = 1, #entries do
        if entries[i].favorite then
            favorites = favorites + 1
        else
            auto = auto + 1
        end
    end
    return favorites, auto
end

function Recovered.Refresh()
    scanned = nil
    Rebuild()
    Emit("refreshed")
end

function Recovered.OnChanged(fn)
    if type(fn) == "function" then callbacks[#callbacks + 1] = fn end
end

EbonBuilds.Favorites.OnChanged(function()
    cache = nil
    byName = nil
    Emit("refreshed")
end)
