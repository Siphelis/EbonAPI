local _, ns = ...

EbonBuilds.Compare = {}

local Compare = EbonBuilds.Compare

local function QualityOf(spellId, fallback)
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    local entry = catalog and catalog.Entry and catalog.Entry(spellId)
    local quality = entry and tonumber(entry.quality)
    if quality then return quality end
    return tonumber(fallback) or 0
end

local function PositiveStacks(value)
    local n = tonumber(value)
    if n and n >= 1 then return math.floor(n) end
    return 1
end

local function KeyOf(spellId)
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    local key = catalog and catalog.GroupKey and catalog.GroupKey(spellId)
    return key or spellId
end

local function Dedupe(echoes)
    local byKey = {}
    local order = {}
    for _, e in ipairs(echoes or {}) do
        local spellId = tonumber(e.spellId)
        local key = spellId and KeyOf(spellId)
        if key and not byKey[key] then
            local item = { key = key, spellId = spellId, quality = QualityOf(spellId, e.quality), stacks = PositiveStacks(e.stacks), locked = e.locked == true }
            byKey[key] = item
            order[#order + 1] = item
        end
    end
    return order
end

function Compare.LockedCount(echoes)
    local list = Dedupe(echoes)
    local locked = 0
    for i = 1, #list do
        if list[i].locked then locked = locked + 1 end
    end
    return locked
end

