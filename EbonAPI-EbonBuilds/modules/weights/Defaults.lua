local BASE = 1
local RARITY_STEP = 1
local SPEC_BONUS = 2

EbonBuilds.Weights = EbonBuilds.Weights or {}

local function hasBit(mask, bit)
    return math.floor(mask / bit) % 2 == 1
end

function EbonBuilds.Weights.IsOwnSpec(entry, classToken, spec)
    if type(entry) ~= "table" or not classToken or type(entry.families) ~= "table" then return false end
    local specCard = EbonAPI.ClientData.Spec(classToken, spec)
    local family = specCard and specCard.key
    if not family then return false end
    for _, f in ipairs(entry.families) do
        if f == family then return true end
    end
    return false
end

local specBadgeCache = {}

local function firstSpecIcon(entry)
    for _, f in ipairs(entry.families) do
        local card = EbonAPI.ClientData.SpecByKey(f)
        if card then return card.icon end
    end
    return nil
end

function EbonBuilds.Weights.SpecBadge(entry)
    if type(entry) ~= "table" or type(entry.families) ~= "table" then return nil end
    local classToken = EbonBuilds.Build.PlayerClassToken()
    local spec = EbonBuilds.Build.PlayerTopTalentTab()
    local stateKey = tostring(classToken) .. "|" .. tostring(spec)
    local byEntry = specBadgeCache[stateKey]
    if not byEntry then
        byEntry = {}
        specBadgeCache[stateKey] = byEntry
    end
    local key = entry.id or entry
    local cached = byEntry[key]
    if cached == nil then
        if EbonBuilds.Weights.IsOwnSpec(entry, classToken, spec) then
            cached = EbonAPI.ClientData.Spec(classToken, spec).icon
        else
            cached = firstSpecIcon(entry)
        end
        cached = cached or false
        byEntry[key] = cached
    end
    return cached or nil
end

function EbonBuilds.Weights.SpecBadgeOfSpell(spellId)
    local entry = spellId and EbonAPI.EchoCatalog.Entry(spellId)
    return entry and EbonBuilds.Weights.SpecBadge(entry) or nil
end

function EbonBuilds.Weights.Default(entry, classToken, spec)
    if type(entry) ~= "table" then return 0 end
    local mask = tonumber(entry.classMask) or 0
    local card = classToken and EbonAPI.ClientData.Class(classToken)
    local bit = card and card.bit
    if mask ~= 0 and bit and not hasBit(mask, bit) then return 0 end
    local rarity = math.floor(tonumber(entry.quality) or 0)
    if rarity < 0 then rarity = 0 elseif rarity > 4 then rarity = 4 end
    local weight = BASE + RARITY_STEP * rarity
    if EbonBuilds.Weights.IsOwnSpec(entry, classToken, spec) then
        weight = weight + SPEC_BONUS
    end
    return weight
end
