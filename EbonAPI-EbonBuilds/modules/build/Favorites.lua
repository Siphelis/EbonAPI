EbonBuilds.Favorites = EbonBuilds.Favorites or {}
local Favorites = EbonBuilds.Favorites

local NAME_LENGTH = 32
local callbacks = {}

local function Store()
    EbonAPIEbonBuildsDB = EbonAPIEbonBuildsDB or {}
    EbonAPIEbonBuildsDB.favorites = EbonAPIEbonBuildsDB.favorites or {}
    return EbonAPIEbonBuildsDB.favorites
end

local function CleanName(name)
    name = tostring(name or ""):gsub("[|;:,]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return name:sub(1, NAME_LENGTH)
end

local function Emit(kind, id)
    for i = 1, #callbacks do
        callbacks[i](kind, id)
    end
end

local function CopyEchoes(echoes)
    local out = {}
    for _, e in ipairs(echoes or {}) do
        local spellId = tonumber(e.spellId or e[1])
        if spellId then
            local stacks = tonumber(e.stacks or e[3]) or 1
            if stacks < 1 then stacks = 1 end
            local quality = tonumber(e.quality or e[2])
            if not quality then
                local cat = EbonAPI and EbonAPI.EchoCatalog
                local entry = cat and cat.Entry and cat.Entry(spellId)
                quality = entry and tonumber(entry.quality) or 0
            end
            local item = { spellId = spellId, quality = quality, stacks = stacks }
            if e.avoid == true then item.avoid = true end
            out[#out + 1] = item
        end
    end
    table.sort(out, function(a, b) return a.spellId < b.spellId end)
    return out
end

local function Signature(class, echoes)
    local parts = { class or "" }
    for i = 1, #echoes do
        local e = echoes[i]
        parts[#parts + 1] = e.spellId .. "." .. e.quality .. "." .. e.stacks .. "." .. (e.avoid and "1" or "0")
    end
    return table.concat(parts, "|")
end

local function FindBySignature(signature)
    for id, fav in pairs(Store()) do
        if Signature(fav.class, fav.echoes) == signature then return id end
    end
    return nil
end

function Favorites.List()
    local out = {}
    for _, fav in pairs(Store()) do out[#out + 1] = fav end
    table.sort(out, function(a, b)
        local an, bn = (a.name or ""):lower(), (b.name or ""):lower()
        if an ~= bn then return an < bn end
        return tostring(a.id) < tostring(b.id)
    end)
    return out
end

function Favorites.Get(id)
    if not id then return nil end
    return Store()[id]
end

function Favorites.Add(data)
    data = data or {}
    local echoes = CopyEchoes(data.echoes)
    if #echoes == 0 then return nil, "FAVORITE_EMPTY" end
    local class = data.class
    if class == "" then class = nil end
    local existing = FindBySignature(Signature(class, echoes))
    if existing then return nil, "FAVORITE_DUPLICATE", existing end
    local id = EbonBuilds.Build.NewObjectId()
    local name = CleanName(data.name)
    if name == "" then name = id:sub(1, 8) end
    local source = data.source
    if source ~= "ebh1" and source ~= "recovered" and source ~= "player" then
        source = "player"
    end
    Store()[id] = {
        id        = id,
        name      = name,
        class     = class,
        echoes    = echoes,
        source    = source,
        createdAt = time(),
        owner     = data.owner,
    }
    Emit("added", id)
    return id
end

function Favorites.AddFromRecovered(playerName)
    local rec = EbonBuilds.Recovered and EbonBuilds.Recovered.Get
        and EbonBuilds.Recovered.Get(playerName)
    if not rec then return nil, "RECOVERED_NOT_FOUND" end
    return Favorites.Add({
        name   = rec.name or playerName,
        class  = rec.class,
        echoes = rec.echoes,
        source = "recovered",
        owner  = rec.name or playerName,
    })
end

function Favorites.AddFromBuild(buildId)
    local build = EbonBuilds.Build.Get(buildId)
    if not build then return nil, "BUILD_NOT_FOUND" end
    local list = EbonBuilds.Build.Echoes and EbonBuilds.Build.Echoes(build) or {}
    local echoes = {}
    for i = 1, #list do
        local echo = list[i]
        echoes[i] = { spellId = echo.spellId, quality = echo.quality, stacks = echo.stacks }
    end
    return Favorites.Add({
        name   = build.title,
        class  = build.class,
        echoes = echoes,
        source = "player",
        owner  = UnitName and UnitName("player") or nil,
    })
end

function Favorites.Rename(id, name)
    local fav = Favorites.Get(id)
    if not fav then return nil, "FAVORITE_NOT_FOUND" end
    name = CleanName(name)
    if name == "" then return nil, "NAME_EMPTY" end
    fav.name = name
    Emit("renamed", id)
    return true
end

function Favorites.Remove(id)
    if not Favorites.Get(id) then return nil, "FAVORITE_NOT_FOUND" end
    Store()[id] = nil
    Emit("removed", id)
    return true
end

function Favorites.IsFavorite(playerName)
    if not playerName then return nil end
    for id, fav in pairs(Store()) do
        if fav.source == "recovered" and fav.owner == playerName then return id end
    end
    return nil
end

function Favorites.OnChanged(fn)
    if type(fn) == "function" then callbacks[#callbacks + 1] = fn end
end
