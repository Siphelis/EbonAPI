EbonBuilds.PlayerBuilds = EbonBuilds.PlayerBuilds or {}
local PlayerBuilds = EbonBuilds.PlayerBuilds

local roleSet
local roleCache = setmetatable({}, { __mode = "k" })
local echoRoleCache = {}
local EMPTY_ROLES = {}

local function T(key, fallback)
    local L = EbonBuilds.L
    local value = L and L[key]
    if type(value) == "string" and value ~= key then
        return value
    end
    return fallback
end

local function roleKeys()
    if not roleSet then
        roleSet = {}
        local families = EbonAPI.ClientData.Families()
        for i = 1, #families do
            local key = families[i].key
            if key and key ~= "No family" then roleSet[key] = true end
        end
    end
    return roleSet
end

local function echoRoles(spellId)
    if spellId == nil then return EMPTY_ROLES end
    local cached = echoRoleCache[spellId]
    if cached then return cached end
    local roles = {}
    local info = EbonAPI.EchoCatalog.Entry(spellId)
    local families = info and info.families
    if type(families) == "table" then
        for i = 1, #families do
            local key = EbonBuilds.Const.NormFamily(families[i])
            if key and roleKeys()[key] then roles[key] = true end
        end
    end
    echoRoleCache[spellId] = roles
    return roles
end

local function tallyRoles(ids)
    local counts = {}
    for i = 1, #ids do
        for key in pairs(echoRoles(ids[i])) do
            counts[key] = (counts[key] or 0) + 1
        end
    end
    return counts
end

local function maxRoles(counts)
    local best, winners = 0, {}
    for key, n in pairs(counts) do
        if n > best then
            best = n
            winners = { key }
        elseif n == best then
            winners[#winners + 1] = key
        end
    end
    return best, winners
end

local function computeRole(ids)
    local counts = tallyRoles(ids)
    local best, winners = maxRoles(counts)
    if best == 0 then return nil end
    if #winners == 1 then return winners[1] end

    local families = EbonAPI.ClientData.Families()
    for i = 1, #families do
        local key = families[i].key
        if counts[key] == best then return key end
    end
    return nil
end

local function spellIds(entry)
    local ids = {}
    local keys = rawget(entry, "keys")
    if keys and rawget(entry, "echoes") == nil then
        for i = 1, #keys do ids[i] = math.floor(keys[i] / 64) end
        return ids
    end
    local echoes = entry.echoes or {}
    for i = 1, #echoes do ids[i] = echoes[i].spellId end
    return ids
end

function PlayerBuilds.Roles(entry)
    if type(entry) ~= "table" then return nil end
    local cached = roleCache[entry]
    if cached then return cached.role end
    local role = computeRole(spellIds(entry))
    roleCache[entry] = { role = role }
    return role
end

local countsCache = setmetatable({}, { __mode = "k" })
local filterCache = setmetatable({}, { __mode = "k" })
local shared
local recoveredWrap = setmetatable({}, { __mode = "k" })

function PlayerBuilds.Invalidate()
    shared = nil
end

function PlayerBuilds.ResetRoleCache()
    roleCache = setmetatable({}, { __mode = "k" })
    countsCache = setmetatable({}, { __mode = "k" })
    filterCache = setmetatable({}, { __mode = "k" })
    echoRoleCache = {}
    roleSet = nil
end

local scoreCache = setmetatable({}, { __mode = "k" })

local function matrixVersion()
    local Matrix = EbonBuilds.Matrix
    return Matrix and Matrix.Version and Matrix.Version() or 0
end

function PlayerBuilds.Score(entry)
    if type(entry) ~= "table" then return nil end
    local version = matrixVersion()
    local cached = scoreCache[entry]
    if cached and cached.version == version then return cached.score end
    local score
    local Rating = EbonBuilds.Rating
    if Rating and Rating.Value then
        local ids = spellIds(entry)
        local sum, count = 0, 0
        for i = 1, #ids do
            local value = Rating.Value(ids[i], false, entry.class)
            if value ~= nil then
                sum = sum + value
                count = count + 1
            end
        end
        if count > 0 then score = sum / count end
    end
    scoreCache[entry] = { version = version, score = score }
    return score
end

function PlayerBuilds.Stars(entry)
    local score = PlayerBuilds.Score(entry)
    if score == nil then return nil end
    local stars = math.floor(score + 0.5)
    if stars < 1 then stars = 1 end
    if stars > 3 then stars = 3 end
    return stars
end

local function sortByScore(list)
    local size = #list
    local scores, order = {}, {}
    for i = 1, size do
        order[i] = i
        scores[i] = PlayerBuilds.Score(list[i])
    end
    table.sort(order, function(a, b)
        local sa, sb = scores[a], scores[b]
        if sa == sb then return a < b end
        if sa == nil then return false end
        if sb == nil then return true end
        return sa > sb
    end)
    local sorted = {}
    for i = 1, size do sorted[i] = list[order[i]] end
    for i = 1, size do list[i] = sorted[i] end
    return list
end

function PlayerBuilds.Accepts(entry)
    local lockN = rawget(entry, "lockN")
    if lockN ~= nil then return lockN == EbonBuilds.Const.BUILD_LOCKED_SLOTS end
    local echoes = entry.echoes or {}
    local locked = 0
    for i = 1, #echoes do
        if echoes[i].locked ~= false then locked = locked + 1 end
    end
    return locked == EbonBuilds.Const.BUILD_LOCKED_SLOTS
end

function PlayerBuilds.ClassCounts(list)
    local hit = countsCache[list]
    if hit and hit.size == #list then return hit.counts end
    local out = {}
    for i = 1, #list do
        local build = list[i]
        local token = build.class
        if token then
            local slot = out[token]
            if not slot then
                slot = { total = 0, roles = {} }
                out[token] = slot
            end
            slot.total = slot.total + 1
            local role = PlayerBuilds.Roles(build)
            if role then slot.roles[role] = (slot.roles[role] or 0) + 1 end
        end
    end
    countsCache[list] = { size = #list, counts = out }
    return out
end

function PlayerBuilds.Filter(list, classToken, roleKey)
    local version = matrixVersion()
    local slot = filterCache[list]
    if not slot or slot.version ~= version or slot.size ~= #list then
        slot = { version = version, size = #list, results = {} }
        filterCache[list] = slot
    end
    local key = (classToken or "*") .. "|" .. (roleKey or "*")
    local hit = slot.results[key]
    if hit then return hit end
    local out = {}
    for i = 1, #list do
        local build = list[i]
        if (classToken == nil or build.class == classToken)
            and (roleKey == nil or PlayerBuilds.Roles(build) == roleKey) then
            out[#out + 1] = build
        end
    end
    sortByScore(out)
    slot.results[key] = out
    return out
end

function PlayerBuilds.ExportSource(entry)
    if entry.kind == "player" and entry.source == "slot" then return entry end
    if entry.kind == "player" then return entry.id end
    if entry.kind == "favorite" then
        return EbonBuilds.Favorites.Get(entry.id) or entry
    end
    return entry
end

local function copyEchoes(echoes)
    local out = {}
    for i = 1, #(echoes or {}) do
        local source = echoes[i]
        local copy = {}
        for k, v in pairs(source) do
            if k ~= "locked" then copy[k] = v end
        end
        out[i] = copy
    end
    return out
end

local function catalogQuality(spellId)
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    local data = catalog and catalog.Entry and catalog.Entry(spellId)
    return data and data.quality or 0
end

local function withQuality(echoes)
    if type(echoes) ~= "table" then return echoes end
    local missing = false
    for i = 1, #echoes do
        local q = echoes[i].quality
        if not q or (q == 0 and catalogQuality(echoes[i].spellId) ~= 0) then missing = true break end
    end
    if not missing then return echoes end
    local out = {}
    for i = 1, #echoes do
        local copy = {}
        for k, v in pairs(echoes[i]) do copy[k] = v end
        if not copy.quality or copy.quality == 0 then
            copy.quality = catalogQuality(copy.spellId)
        end
        out[i] = copy
    end
    return out
end

local function qualified(list)
    for i = 1, #list do
        local entry = list[i]
        if entry.echoes then entry.echoes = withQuality(entry.echoes) end
    end
    return list
end

local function copyWithKind(list, kind)
    local out = {}
    for i = 1, #list do
        local copy = {}
        for k, v in pairs(list[i]) do copy[k] = v end
        copy.kind = kind
        out[i] = copy
    end
    return out
end

function PlayerBuilds.Preview(text)
    if type(text) ~= "string" or not text:find("%S") then return nil, nil, nil end
    local parsed, code, problem = EbonBuilds.ExportImport.ParseEBH1(text)
    if not parsed then return nil, problem, code end
    return {
        kind = "imported",
        class = parsed.class,
        name = parsed.name or "",
        echoes = copyEchoes(parsed.echoes),
        raw = parsed,
    }
end

function PlayerBuilds.Save(text)
    if type(text) ~= "string" or not text:find("%S") then return nil, nil, nil end
    local id, a, b = EbonBuilds.ExportImport.ImportEBH1(text)
    if id then return id, a end
    return nil, b, a
end

function PlayerBuilds.ProblemText(problem, code)
    local api = EbonBuilds.api
    if not problem and code then
        local ok, made = pcall(api.Problem, api, "IMPORT." .. tostring(code), {})
        problem = ok and made or nil
    end
    if problem then
        return api:ProblemText(problem)
    end
    return T("SHARE_IMPORT_FAILED", "The build could not be imported.")
end

function PlayerBuilds.Lists()
    local Build = EbonBuilds.Build
    local playerClass = Build.PlayerClassToken()

    local mine = {}
    local State = EbonAPI and EbonAPI.State
    local slots = State and State.sortedBuilds and State.sortedBuilds() or {}
    for i = 1, #slots do
        local slot = slots[i]
        if slot.kind == "live" then
            local echoes = {}
            local list = State.BuildEchoes(slot) or {}
            for j = 1, #list do
                if not list[j].avoid then
                    local copy = {}
                    for k, v in pairs(list[j]) do copy[k] = v end
                    echoes[#echoes + 1] = copy
                end
            end
            if #echoes > 0 then
                local name = tostring(slot.name or "")
                if name == "" then
                    name = string.format(T("SHARE_SLOT_NAME", "Slot %d"), tonumber(slot.slot) or 0)
                end
                mine[#mine + 1] = {
                    kind = "player",
                    source = "slot",
                    id = slot.slot,
                    name = name,
                    class = playerClass,
                    echoes = echoes,
                }
            end
        end
    end

    local created = {}
    local builds = Build.List()
    for i = 1, #builds do
        local build = builds[i]
        local class = build.class
        if not class or class == "" then class = playerClass end
        created[#created + 1] = {
            kind = "player",
            source = "ebonbuilds",
            id = build.id,
            name = build.title or "",
            class = class,
            echoes = Build.Echoes(build),
        }
    end
    sortByScore(created)
    for i = 1, #created do mine[#mine + 1] = created[i] end

    local recovered = EbonBuilds.Recovered.List()
    local version = matrixVersion()
    if not (shared and shared.source == recovered and shared.size == #recovered and shared.version == version) then
        local favorites = sortByScore(copyWithKind(EbonBuilds.Favorites.List(), "favorite"))
        local received = {}
        for i = 1, #recovered do
            local source = recovered[i]
            if source.favorite == false then
                local wrapped = recoveredWrap[source]
                if wrapped == nil then
                    wrapped = false
                    if PlayerBuilds.Accepts(source) then
                        wrapped = {}
                        for k, v in pairs(source) do wrapped[k] = v end
                        wrapped.kind = "recovered"
                        setmetatable(wrapped, getmetatable(source))
                        local materialized = rawget(wrapped, "echoes")
                        if materialized then wrapped.echoes = withQuality(materialized) end
                    end
                    recoveredWrap[source] = wrapped
                end
                if wrapped then received[#received + 1] = wrapped end
            end
        end
        shared = {
            source = recovered,
            size = #recovered,
            version = version,
            favorites = qualified(favorites),
            received = received,
        }
    end

    return qualified(mine), shared.favorites, shared.received
end

return PlayerBuilds
