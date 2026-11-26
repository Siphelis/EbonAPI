EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.AffixEngrave = EbonBuilds.Pe.AffixEngrave or {}

local Engrave = EbonBuilds.Pe.AffixEngrave

local format = string.format
local select, tonumber, type, ipairs = select, tonumber, type, ipairs

local WIDTH = 392
local HEIGHT = 330
local MARGIN = 12
local COLUMN_WIDTH = 168
local COLUMN_RIGHT = 212
local ICON_SIZE = 46 * 0.8
local TITLE_Y = 10
local TILE_Y = 28
local NAME_Y = 112
local EFFECT_Y = 134
local EFFECT_HEIGHT = 70
local COST_Y = 214
local REPLACE_Y = 236
local REASON_Y = 258
local RESULT_Y = 280
local BUTTON_Y = 300
local BAG = 255
local REPLY_DELAY = 5
local MIN_QUALITY = 3
local ROMAN = { "I", "II", "III", "IV", "V" }
local CATEGORY_KEYS = { "offensive", "defensive", "resource", "utility", "mobility" }

local SLOT_LOC = {
    [1] = "INVTYPE_HEAD", [2] = "INVTYPE_NECK", [3] = "INVTYPE_SHOULDER", [5] = "INVTYPE_CHEST",
    [6] = "INVTYPE_WAIST", [7] = "INVTYPE_LEGS", [8] = "INVTYPE_FEET", [9] = "INVTYPE_WRIST",
    [10] = "INVTYPE_HAND", [11] = "INVTYPE_FINGER", [12] = "INVTYPE_FINGER", [13] = "INVTYPE_TRINKET",
    [14] = "INVTYPE_TRINKET", [15] = "INVTYPE_CLOAK", [16] = "INVTYPE_WEAPON",
    [17] = "INVTYPE_WEAPONOFFHAND", [18] = "INVTYPE_RANGED",
}

local state = {}

local function T(key)
    local L = EbonBuilds.L
    local value = L and L[key]
    if type(value) ~= "string" then
        return key
    end
    return value
end

local function createKit(kind, parent, spec)
    return EbonAPI.Kit.create("EbonBuilds", kind, parent, spec)
end

local function linkRandomProperty(link)
    if not link then
        return 0
    end
    local index, value = 0, nil
    for part in (link .. ":"):gmatch("([^:]*):") do
        index = index + 1
        if index == 8 then
            value = part
            break
        end
    end
    return value and tonumber(value) or 0
end

local function hasForeignRandomProperty(link)
    local property = linkRandomProperty(link)
    if property == 0 then
        return false
    end
    if property < 0 then
        return true
    end
    return EbonAPI.Affixes.GetByEnchant(property) == nil
end

local function itemQuality(link)
    local quality = select(3, GetItemInfo(link))
    return quality or 0
end

local function equipLocation(link, slot)
    return select(9, GetItemInfo(link)) or SLOT_LOC[slot]
end

local function wornSlot()
    if state.slot then
        return state.slot
    end
    local view = EbonBuilds.Pe.AffixesView
    if view and view.GetWornSlot then
        return view.GetWornSlot()
    end
    return nil
end

local function familyName(family, rank)
    local name = EbonAPI.Affixes.GetFamilyName(family) or ""
    if rank then
        name = format(T("AFF_TIP_TITLE"), name, ROMAN[rank] or tostring(rank))
    end
    return name
end

local function effectText(family, rank)
    local entry = family.ranks and family.ranks[rank or 1]
    if not entry then
        return ""
    end
    return EbonAPI.Affixes.RenderText(entry) or ""
end

local function isLearned(familyId, rank)
    local learned = EbonAPI.Affixes.GetLearned()
    for _, entry in ipairs(learned or {}) do
        if entry.familyId == familyId and entry.rank == rank then
            return true
        end
    end
    return false
end

local function setText(element, text)
    if element.spec.text ~= text then
        element.spec.text = text
        element:Refresh()
    end
end

local function setTile(tile, family, rank, equipped, learned)
    if not family then
        tile:Hide()
        return
    end
    tile.spec.category = CATEGORY_KEYS[family.category]
    tile.spec.icon = family.icon
    tile.spec.state = nil
    tile.spec.equipped = equipped
    tile.spec.bagged = false
    tile.spec.rank = learned and rank or nil
    tile.spec.text = ""
    tile:Refresh()
    tile:Show()
end

local function evaluate(families, slot, link)
    local familyId, rank = state.familyId, state.rank
    local family = families and families[familyId]
    local entry = family and family.ranks and family.ranks[rank]
    local cost = entry and entry.applyCost or 0
    local reason

    if not link then
        reason = "AFF_ENGRAVE_NO_PIECE"
    elseif itemQuality(link) < MIN_QUALITY then
        reason = "AFF_ENGRAVE_NOT_RARE"
    elseif hasForeignRandomProperty(link) then
        reason = "AFF_ENGRAVE_RANDOM"
    elseif not isLearned(familyId, rank) then
        reason = "AFF_ENGRAVE_NOT_LEARNED"
    else
        local allowed = EbonAPI.Affixes.AllowedCategories(equipLocation(link, slot))
        local worn = EbonAPI.Affixes.GetEquipped()[slot]
        if not (allowed and family and allowed[family.category]) then
            reason = "AFF_ENGRAVE_NOT_ALLOWED"
        elseif worn and worn.familyId == familyId and worn.rank == rank then
            reason = "AFF_ENGRAVE_ALREADY"
        elseif GetMoney() < cost then
            reason = "AFF_ENGRAVE_NO_GOLD"
        end
    end
    return reason, cost
end

local function refresh()
    local window = state.window
    if not window or not state.familyId then
        return
    end

    local Affixes = EbonAPI.Affixes
    local families = Affixes.GetFamilies()
    local family = families and families[state.familyId]
    local slot = wornSlot()
    local link = slot and GetInventoryItemLink("player", slot) or nil
    local worn = slot and Affixes.GetEquipped()[slot] or nil
    local wornFamily = worn and worn.familyId and families and families[worn.familyId] or nil
    local learned = family and isLearned(state.familyId, state.rank)

    setText(window.beforeTitle, T("AFF_ENGRAVE_BEFORE"))
    setText(window.afterTitle, T("AFF_ENGRAVE_AFTER"))

    if wornFamily then
        setTile(window.beforeTile, wornFamily, worn.rank, true, true)
        setText(window.beforeName, familyName(wornFamily, worn.rank))
        setText(window.beforeEffect, effectText(wornFamily, worn.rank))
    else
        setTile(window.beforeTile, nil)
        setText(window.beforeName, link and T("AFF_ENGRAVE_NONE") or T("AFF_ENGRAVE_NO_PIECE"))
        setText(window.beforeEffect, "")
    end

    setTile(window.afterTile, family, state.rank, false, learned)
    setText(window.afterName, family and familyName(family, state.rank) or "")
    setText(window.afterEffect, family and effectText(family, state.rank) or "")

    local reason, cost = evaluate(families, slot, link)
    setText(window.costLabel, T("AFF_ENGRAVE_COST"))
    setText(window.costValue, GetCoinTextureString(cost, 12))
    setText(window.replace, wornFamily and format(T("AFF_ENGRAVE_REPLACES"), familyName(wornFamily, worn.rank)) or "")
    setText(window.reason, reason and T(reason) or "")
    setText(window.result, state.result or "")

    state.canEngrave = reason == nil
    window.button.spec.disabled = (reason ~= nil) or state.pending == true
    window.button:Refresh()
end

local function finish(result)
    state.pending = false
    state.result = result
    if state.timer then
        EbonBuilds.Timer.Cancel(state.timer)
    end
    refresh()
end

local function onReply(payload)
    if not state.pending then
        return
    end
    if type(payload) == "table" and payload.ok then
        finish(T("AFF_ENGRAVE_DONE"))
    elseif type(payload) == "table" and payload.pattern == "anvilTooFar" then
        finish(T("AFF_ENGRAVE_TOO_FAR"))
    else
        finish(type(payload) == "table" and payload.reason or T("AFF_ENGRAVE_NO_REPLY"))
    end
end

local function onTimeout()
    if state.pending then
        finish(T("AFF_ENGRAVE_NO_REPLY"))
    end
end

local function engrave()
    if state.pending or not state.canEngrave or not state.window or not state.window:IsShown() then
        return
    end
    local slot = wornSlot()
    local families = EbonAPI.Affixes.GetFamilies()
    local family = families and families[state.familyId]
    local entry = family and family.ranks and family.ranks[state.rank]
    if not (slot and entry and entry.spellId) then
        return
    end
    local sent = EbonAPI.Actions.ApplyAffix(entry.spellId, BAG, slot - 1)
    if not (sent and sent.sent) then
        state.result = T("AFF_ENGRAVE_NO_REPLY")
        refresh()
        return
    end
    state.pending = true
    state.result = nil
    state.timer = state.timer or EbonBuilds.Timer.New("AffixEngrave")
    EbonBuilds.Timer.Arm(state.timer, REPLY_DELAY, onTimeout)
    refresh()
end

local function place(window, key, kind, spec, x, y)
    local element = createKit(kind, window, spec)
    element:SetPoint("TOPLEFT", window, "TOPLEFT", x, -y)
    window[key] = element
    return element
end

local function column(window, prefix, x)
    place(window, prefix .. "Title", "status", { text = "", width = COLUMN_WIDTH }, x, TITLE_Y)
    place(window, prefix .. "Tile", "affixTile", { category = "offensive", equipped = false, bagged = false, text = "", iconSize = ICON_SIZE }, x, TILE_Y)
    place(window, prefix .. "Name", "text", { text = "", width = COLUMN_WIDTH }, x, NAME_Y)
    place(window, prefix .. "Effect", "status", { text = "", width = COLUMN_WIDTH, height = EFFECT_HEIGHT }, x, EFFECT_Y)
end

local function refreshIfShown()
    if state.window and state.window:IsShown() then
        refresh()
    end
end

local function build()
    local window = CreateFrame("Frame", nil, UIParent)
    window:SetFrameStrata("DIALOG")
    window:SetWidth(WIDTH)
    window:SetHeight(HEIGHT)
    window:EnableMouse(true)
    window.spec = {}
    if EbonAPI.Bricks.frame then
        EbonAPI.Bricks.frame(window, "small")
    end
    window:Hide()

    column(window, "before", MARGIN)
    column(window, "after", COLUMN_RIGHT)

    local full = WIDTH - 2 * MARGIN
    place(window, "costLabel", "status", { text = "", width = COLUMN_WIDTH }, MARGIN, COST_Y)
    place(window, "costValue", "text", { text = "", width = COLUMN_WIDTH }, COLUMN_RIGHT, COST_Y)
    place(window, "replace", "status", { text = "", width = full }, MARGIN, REPLACE_Y)
    place(window, "reason", "text", { text = "", width = full }, MARGIN, REASON_Y)
    place(window, "result", "text", { text = "", width = full }, MARGIN, RESULT_Y)
    place(window, "button", "button", { text = T("AFF_ENGRAVE_BUTTON"), disabled = true, onClick = engrave }, MARGIN, BUTTON_Y)

    window:RegisterEvent("PLAYER_MONEY")
    window:SetScript("OnEvent", refreshIfShown)

    EbonAPI.Decoders.subscribe(512, onReply)
    EbonAPI:On("AFFIXES_CHANGED", refreshIfShown)

    state.window = window
    return window
end

function Engrave.Open(familyId, rank, anchorTile, slot)
    if not (familyId and rank) then
        return
    end
    local window = state.window or build()
    state.familyId, state.rank, state.result = familyId, rank, nil
    state.slot = slot
    window:ClearAllPoints()
    if anchorTile then
        window:SetPoint("TOPLEFT", anchorTile, "TOPRIGHT", 8, 0)
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    refresh()
    window:Show()
end

function Engrave.Close()
    if state.window then
        state.window:Hide()
    end
    state.familyId, state.rank, state.slot = nil, nil, nil
end

function Engrave.IsOpen()
    return state.window ~= nil and state.window:IsShown() and state.familyId ~= nil
end

function Engrave.GetFamily()
    if Engrave.IsOpen() then
        return state.familyId, state.rank
    end
    return nil
end

function Engrave.onWornSlotChanged()
    if not Engrave.IsOpen() then
        return
    end
    state.slot = nil
    if wornSlot() then
        state.result = nil
        refresh()
    else
        Engrave.Close()
    end
end

function Engrave.onFilterChanged()
    Engrave.Close()
end
