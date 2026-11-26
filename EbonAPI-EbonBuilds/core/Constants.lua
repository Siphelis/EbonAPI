local folder, ns = ...
EbonBuilds = ns

ns.NAME = "EbonBuilds"
ns.FOLDER = folder
ns.api = EbonAPI and EbonAPI:NewAddon(ns.NAME, 2, 1, { icon = "Spell_Shadow_SoulGem" }) or nil

local Const = {}
EbonBuilds.Const = Const

function Const.QualityHex(quality)
    local card = EbonAPI.ClientData.Quality(quality)
    return card and card.hex
end

Const.SAVED_SLOTS = 10

Const.BUILD_LOCKED_SLOTS = 6

Const.BUILD_TOTAL_STACKS = 85

function Const.CompleteBuild(echoesText, lockedText)
    local profile = EbonAPI and EbonAPI.Profile
    if not profile then return false end
    local ids, stacks, count = profile.DecodeBuild(echoesText)
    if not ids then return false end
    local total = 0
    for i = 1, count do total = total + stacks[i] end
    if total ~= Const.BUILD_TOTAL_STACKS then return false end
    local locked, lockedCount = profile.DecodeLocked(lockedText)
    return locked ~= nil and lockedCount == Const.BUILD_LOCKED_SLOTS
end

Const.UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
Const.EMPTY_SLOT = "Interface\\Buttons\\UI-EmptySlot"
Const.SOLID = "Interface\\Buttons\\WHITE8X8"

local roles

function Const.NormFamily(family)
    if family == nil then return nil end
    local data = EbonAPI.ClientData
    if not roles then
        roles = {}
        for _, card in ipairs(data.Families()) do roles[card.key] = true end
    end
    local key = data.Family(family)
    if roles[key] then return key end
    return nil
end
