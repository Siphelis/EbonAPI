local NS = SkillTreeAutoLoad

-- Presets livrés avec STAL : lecture seule, présentés comme des sauvegardes (voir NS.PresetsData).
local Presets = {}
NS.Presets = Presets

local PREFIX = "preset:"

-- Les données sont lues à l'appel : l'ordre de chargement de presetsdata.lua ne compte pas.
local function Source()
    return NS.PresetsData or { groups = {}, presets = {} }
end

local function FindPreset(presetId)
    if Presets.IsPresetId(presetId) then presetId = presetId:sub(#PREFIX + 1) end
    local list = Source().presets
    for i = 1, #list do
        if list[i].id == presetId then return list[i] end
    end
end

function Presets.IsPresetId(saveId)
    return type(saveId) == "string" and saveId:sub(1, #PREFIX) == PREFIX
end

function Presets.Groups()
    local L = NS.L
    local data = Source()
    local groups = {}
    for g = 1, #data.groups do
        local group = data.groups[g]
        local items = {}
        for i = 1, #data.presets do
            if data.presets[i].group == group.id then items[#items + 1] = data.presets[i].id end
        end
        groups[#groups + 1] = {
            id = group.id,
            name = L["PRESET_GROUP_" .. group.id:upper()],
            items = items,
        }
    end
    return groups
end

-- Nœuds du preset + ses ancêtres au rang max (un nœud ne s'active que si ses parents sont au
-- rang max). Calcul au premier appel, quand la TalentDatabase est là ; mis en cache par preset.
local closed = {}

local function ClosedRanks(preset)
    local cached = closed[preset.id]
    if not cached then
        local ranks = {}
        for nodeId, rank in pairs(preset.nodes) do ranks[nodeId] = rank end
        local added, count = NS.Plan.Ancestors(preset.nodes)
        if added then
            for nodeId, rank in pairs(added) do ranks[nodeId] = rank end
            cached = { ranks = ranks, extra = count }
            closed[preset.id] = cached
        else
            return ranks, 0 -- arbre pas encore chargé : on réessaie au prochain appel
        end
    end

    -- Copie : l'appelant ne peut modifier ni la donnée livrée ni le cache.
    local copy = {}
    for nodeId, rank in pairs(cached.ranks) do copy[nodeId] = rank end
    return copy, cached.extra
end

function Presets.GetSave(presetId)
    local preset = FindPreset(presetId)
    if not preset then return nil end

    local name
    if preset.classToken then
        name = LOCALIZED_CLASS_NAMES_MALE[preset.classToken]
    else
        name = NS.L["PRESET_" .. preset.id:upper()]
    end

    local nodeRanks, extra = ClosedRanks(preset)

    return {
        id = PREFIX .. preset.id,
        name = name,
        nodeRanks = nodeRanks,
        extra = extra,
        progressive = NS.Data.GetPresetMode(preset.id),
        readonly = true,
        color = preset.color,
        preset = true,
    }
end

function Presets.SetProgressive(presetId, enabled)
    local preset = FindPreset(presetId)
    if not preset then return false end
    NS.Data.SetPresetMode(preset.id, enabled)
    return true
end

-- Même clé de monnaie que Cost.RankCost ; le nœud vient des définitions de Core.
function Presets.NodeCurrency(nodeId)
    local defs = NS.Core.GetNodeDefs()
    local node = defs and defs[nodeId]
    return node and node.currency or "ash"
end
