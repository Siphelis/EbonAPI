EbonBuilds.AffixTooltip = EbonBuilds.AffixTooltip or {}
local AffixTooltip = EbonBuilds.AffixTooltip

local floor, abs = math.floor, math.abs
local strsplit, tonumber, select, type = strsplit, tonumber, select, type

local GREEN = "|cff1eff00"
local RED = "|cffff4040"
local GREY = "|cff9d9d9d"
local BULLET = "|cffffd100\226\128\162|r "

local FALLBACK = {
    RG_DEALT_LINE = "Damage dealt: %s DPS",
    RG_TAKEN_LINE = "Damage taken: %s per second",
    RG_SOURCE_NOTE = "based on your recent fights",
    AFF_ALREADY_KNOWN = "Affix already known",
}

local TOOLTIPS = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ShoppingTooltip3",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
}

local memory = {}
local knownMemory = {}
local names = {}
local installed = false

local function text(key)
    local L = EbonBuilds.L
    local value = type(L) == "table" and L[key] or nil
    if type(value) ~= "string" or value == "" or value == key then
        return FALLBACK[key]
    end
    return value
end

local function groupDigits(n)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return (out:gsub("^ ", ""))
end

local function perSecond(perMinute)
    if type(perMinute) ~= "number" then return nil end
    local n = floor(abs(perMinute) / 60 + 0.5)
    if n == 0 then return nil end
    if perMinute < 0 then n = -n end
    return n
end

local function signed(n)
    if n < 0 then
        return "-" .. groupDigits(-n)
    end
    return "+" .. groupDigits(n)
end

local function compute(link)
    local enchantId = tonumber((select(8, strsplit(":", link))))
    if not enchantId or enchantId < 10000 then
        return false
    end
    local calc = EbonBuilds.AffixCalc
    if type(calc) ~= "table" or type(calc.Estimer) ~= "function" then
        return false
    end
    local res = calc.Estimer(enchantId)
    if type(res) ~= "table" or not res.calculable then
        return false
    end
    local dealt = perSecond(res.inflige)
    local taken = perSecond(res.subis)
    if not dealt and not taken then
        return false
    end
    return { dealt = dealt, taken = taken }
end

local function lookup(link)
    local hit = memory[link]
    if hit == nil then
        hit = compute(link)
        memory[link] = hit
    end
    return hit
end

local function affixApi()
    local root = _G.EbonAPI
    local affixes = type(root) == "table" and root.Affixes or nil
    if type(affixes) ~= "table" then return nil end
    return affixes
end

local function recall(link)
    local entry = knownMemory[link]
    if entry then return entry end
    local affixes = affixApi()
    local enchantId = tonumber((select(8, strsplit(":", link))))
    local known = false
    if enchantId and enchantId >= 10000 and affixes and type(affixes.IsLearned) == "function" then
        known = affixes.IsLearned(enchantId) and true or false
    end
    entry = { known = known, enchantId = enchantId }
    if known or (affixes and type(affixes.IsLearnedReceived) == "function" and affixes.IsLearnedReceived()) then
        knownMemory[link] = entry
    end
    return entry
end

local function showKnown(tooltip, link)
    if tooltip.ebKnownLink == link then return end
    local entry = recall(link)
    if not entry.known then return end
    tooltip.ebKnownLink = link

    local mention = (RED_FONT_COLOR_CODE or "") .. text("AFF_ALREADY_KNOWN") .. "|r"
    local affixes = affixApi()
    local line, current, index
    if affixes and type(affixes.FindTooltipLine) == "function" then
        line, current, index = affixes.FindTooltipLine(tooltip, entry.enchantId, entry.index, names[tooltip])
    end
    if line then
        entry.index = index
        line:SetText(current .. "\n" .. mention)
    else
        tooltip:AddLine(mention)
    end
    tooltip:Show()
end

local function restoreFont(tooltip)
    local shrunk = tooltip.ebShrunk
    if not shrunk then return end
    tooltip.ebShrunk = nil
    shrunk.line:SetFont(shrunk.font, shrunk.size, shrunk.flags)
end

local function shrinkFont(tooltip, line)
    restoreFont(tooltip)
    local font, size, flags = line:GetFont()
    if not font or not size then return end
    line:SetFont(font, size - 2, flags)
    tooltip.ebShrunk = { line = line, font = font, size = size, flags = flags }
end

local function OnTooltipSetItem(tooltip)
    local _, link = tooltip:GetItem()
    if type(link) ~= "string" then return end
    showKnown(tooltip, link)
    if tooltip.ebAffixLink == link then return end
    local hit = lookup(link)
    if not hit then return end

    tooltip.ebAffixLink = link
    tooltip:AddLine(" ")
    if hit.dealt then
        local color = hit.dealt > 0 and GREEN or RED
        tooltip:AddLine(BULLET .. color .. string.format(text("RG_DEALT_LINE"), signed(hit.dealt)) .. "|r")
    end
    if hit.taken then
        local color = hit.taken > 0 and RED or GREEN
        tooltip:AddLine(BULLET .. color .. string.format(text("RG_TAKEN_LINE"), signed(hit.taken)) .. "|r")
    end
    tooltip:AddLine(GREY .. text("RG_SOURCE_NOTE") .. "|r")

    local name = tooltip:GetName()
    if name then
        local line = _G[name .. "TextLeft" .. tooltip:NumLines()]
        if line then shrinkFont(tooltip, line) end
    end
    tooltip:Show()
end

local function OnTooltipCleared(tooltip)
    restoreFont(tooltip)
    tooltip.ebAffixLink = nil
    tooltip.ebKnownLink = nil
end

function AffixTooltip.Invalidate()
    for key in pairs(memory) do
        memory[key] = nil
    end
    for key in pairs(knownMemory) do
        knownMemory[key] = nil
    end
    if type(EbonBuilds.AffixCalc) == "table" and type(EbonBuilds.AffixCalc.Invalidate) == "function" then
        EbonBuilds.AffixCalc.Invalidate()
    end
end

local function OnStats(unit)
    if unit == "player" then
        AffixTooltip.Invalidate()
    end
end

function AffixTooltip.Init()
    if installed then return end
    installed = true

    for i = 1, #TOOLTIPS do
        local tooltip = _G[TOOLTIPS[i]]
        if tooltip and tooltip.HookScript then
            names[tooltip] = TOOLTIPS[i]
            tooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
            tooltip:HookScript("OnTooltipCleared", OnTooltipCleared)
        end
    end

    EbonBuilds.Events.On("PLAYER_REGEN_ENABLED", AffixTooltip.Invalidate, "AffixTooltip")
    EbonBuilds.Events.On("PLAYER_EQUIPMENT_CHANGED", AffixTooltip.Invalidate, "AffixTooltip")
    EbonBuilds.Events.On("COMBAT_RATING_UPDATE", AffixTooltip.Invalidate, "AffixTooltip")
    EbonBuilds.Events.On("UNIT_STATS", OnStats, "AffixTooltip")
    EbonBuilds.api:On("AFFIXES_CHANGED", AffixTooltip.Invalidate)
end
