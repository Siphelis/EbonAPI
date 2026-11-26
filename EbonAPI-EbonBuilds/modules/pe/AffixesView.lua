EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.AffixesView = EbonBuilds.Pe.AffixesView or {}

local View = EbonBuilds.Pe.AffixesView

local format, lower, find = string.format, string.lower, string.find
local floor, max, min = math.floor, math.max, math.min
local sort = table.sort

local GRID_COLUMNS = 10
local GRID_WIDTH = 560
local COLUMN_STEP = GRID_WIDTH / GRID_COLUMNS
local ICON_SIZE = 46 * 0.8
local MIN_COLUMNS = 7
local ROW_STEP = 78
local HEADING_HEIGHT = 26
local GROUP_GAP = 12
local GRID_Y = 28
local PANEL_WIDTH = 340
local PANEL_GAP = 20
local ROWS_TOP = 39
local ROW_HEIGHT = 26
local WORN_GAP = 4
local WORN_ICON_MAX = 44
local WORN_ROWS = 8
local WORN_MARGIN = 12
local LEGEND_HEIGHT = 14
local LEGEND_GAP = 4

local EN = {
    AFF_TITLE_PORTES = "Worn affixes",
    AFF_SLOT_HEAD = "Head",
    AFF_SLOT_NECK = "Neck",
    AFF_SLOT_SHOULDERS = "Shoulders",
    AFF_SLOT_BACK = "Back",
    AFF_SLOT_CHEST = "Chest",
    AFF_SLOT_WRISTS = "Wrists",
    AFF_SLOT_HANDS = "Hands",
    AFF_SLOT_WAIST = "Waist",
    AFF_SLOT_LEGS = "Legs",
    AFF_SLOT_FEET = "Feet",
    AFF_SLOT_RING1 = "Ring 1",
    AFF_SLOT_RING2 = "Ring 2",
    AFF_SLOT_TRINKET1 = "Trinket 1",
    AFF_SLOT_TRINKET2 = "Trinket 2",
    AFF_SLOT_WEAPON = "Weapon",
    AFF_NONE = "none",
    AFF_TITLE_AFFIXES = "Affixes",
    AFF_COUNT = "%d / %d learned",
    AFF_GROUP_ALL = "All classes",
    AFF_CLASS_WARRIOR = "Warrior",
    AFF_CLASS_PALADIN = "Paladin",
    AFF_CLASS_HUNTER = "Hunter",
    AFF_CLASS_ROGUE = "Rogue",
    AFF_CLASS_PRIEST = "Priest",
    AFF_CLASS_DEATHKNIGHT = "Death Knight",
    AFF_CLASS_SHAMAN = "Shaman",
    AFF_CLASS_MAGE = "Mage",
    AFF_CLASS_WARLOCK = "Warlock",
    AFF_CLASS_DRUID = "Druid",
    AFF_MY_CLASS_ONLY = "My class only",
    AFF_FILTER_CLASS = "Class",
    AFF_FILTER_CATEGORY = "Category",
    AFF_CATEGORY_OFFENSIVE = "Offensive",
    AFF_CATEGORY_DEFENSIVE = "Defensive",
    AFF_CATEGORY_RESOURCE = "Resource",
    AFF_CATEGORY_UTILITY = "Utility",
    AFF_CATEGORY_MOBILITY = "Mobility",
    AFF_FILTER_STATE = "State",
    AFF_STATE_ALL = "All",
    AFF_STATE_LEARNED = "Learned",
    AFF_STATE_UNLEARNED = "Not learned",
    AFF_FILTER_WHERE = "Where",
    AFF_WHERE_EQUIPPED = "Equipped",
    AFF_WHERE_BAGS = "In bags",
    AFF_WHERE_LEARNED = "Learned",
    AFF_RESET_FILTERS = "Reset filters",
    AFF_SEARCH_LABEL = "Search",
    AFF_SEARCH_HINT = "Search an affix",
    AFF_LEGEND_BAG = "In a bag",
    AFF_LEGEND_EQUIPPED = "Equipped",
    AFF_WAITING_SERVER = "Waiting for the server",
    AFF_NO_DATA = "Affix data unavailable",
    AFF_NO_RESULT = "No affix matches the filters",
    AFF_TIP_TITLE = "%s %s",
    AFF_TIP_CATEGORY = "%s - %s",
    AFF_TIP_SLOTS = "Slots: %s",
    AFF_TIP_EQUIPPED = "Equipped on:",
    AFF_TIP_BAGS = "In your bags:",
    AFF_TIP_ITEM = "%s (rank %s)",
    AFF_TIP_LEARNED = "Learned: highest rank %s",
    AFF_TIP_UNLEARNED = "Not learned yet: extract it from a piece of gear that carries it.",
}

local function T(key)
    local L = EbonBuilds.L
    local value = L and L[key]
    if type(value) ~= "string" or value == key then
        value = EN[key]
    end
    return value or key
end

local ROMAN = { "I", "II", "III", "IV", "V" }

local CATEGORY_KEYS = { "offensive", "defensive", "resource", "utility", "mobility" }
local CATEGORY_TEXT = {
    "AFF_CATEGORY_OFFENSIVE", "AFF_CATEGORY_DEFENSIVE", "AFF_CATEGORY_RESOURCE",
    "AFF_CATEGORY_UTILITY", "AFF_CATEGORY_MOBILITY",
}
local CATEGORY_ICONS = {
    "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    "Interface\\Icons\\INV_Elemental_Mote_Mana",
    "Interface\\Icons\\INV_Misc_Gear_01",
    "Interface\\Icons\\Ability_Rogue_Sprint",
}
local CATEGORY_COLORS = {
    { 0xE0 / 255, 0x5A / 255, 0x4E / 255 },
    { 0x4A / 255, 0x9B / 255, 0xE0 / 255 },
    { 0x4C / 255, 0xC2 / 255, 0x6A / 255 },
    { 0xF0 / 255, 0x8A / 255, 0x28 / 255 },
    { 0xB0 / 255, 0x6A / 255, 0xE0 / 255 },
}

local SLOTS = {
    { key = "AFF_SLOT_HEAD", slot = 1, loc = "INVTYPE_HEAD" },
    { key = "AFF_SLOT_NECK", slot = 2, loc = "INVTYPE_NECK" },
    { key = "AFF_SLOT_SHOULDERS", slot = 3, loc = "INVTYPE_SHOULDER" },
    { key = "AFF_SLOT_BACK", slot = 15, loc = "INVTYPE_CLOAK" },
    { key = "AFF_SLOT_CHEST", slot = 5, loc = "INVTYPE_CHEST" },
    { key = "AFF_SLOT_WRISTS", slot = 9, loc = "INVTYPE_WRIST" },
    { key = "AFF_SLOT_HANDS", slot = 10, loc = "INVTYPE_HAND" },
    { key = "AFF_SLOT_WAIST", slot = 6, loc = "INVTYPE_WAIST" },
    { key = "AFF_SLOT_LEGS", slot = 7, loc = "INVTYPE_LEGS" },
    { key = "AFF_SLOT_FEET", slot = 8, loc = "INVTYPE_FEET" },
    { key = "AFF_SLOT_RING1", slot = 11, loc = "INVTYPE_FINGER" },
    { key = "AFF_SLOT_RING2", slot = 12, loc = "INVTYPE_FINGER" },
    { key = "AFF_SLOT_TRINKET1", slot = 13, loc = "INVTYPE_TRINKET" },
    { key = "AFF_SLOT_TRINKET2", slot = 14, loc = "INVTYPE_TRINKET" },
    { key = "AFF_SLOT_WEAPON", slot = 16, loc = "INVTYPE_WEAPON" },
    { key = "AFF_SLOT_WEAPON", slot = 17, loc = "INVTYPE_WEAPONOFFHAND" },
    { key = "AFF_SLOT_RANGED", slot = 18, loc = "INVTYPE_RANGED", label = function() return _G.INVTYPE_RANGED end },
}
local PANEL_ROWS = 15
local PANEL_HEIGHT = PANEL_ROWS * ROW_HEIGHT
local SELECTION_EDGE = 2

local SLOT_INDEX = {}
for index, def in ipairs(SLOTS) do
    SLOT_INDEX[def.slot] = index
end

local WORN = {
    { slot = 1, name = "HeadSlot", column = 1, row = 1 },
    { slot = 2, name = "NeckSlot", column = 1, row = 2 },
    { slot = 3, name = "ShoulderSlot", column = 1, row = 3 },
    { slot = 15, name = "BackSlot", column = 1, row = 4 },
    { slot = 5, name = "ChestSlot", column = 1, row = 5 },
    { slot = 4, name = "ShirtSlot", column = 1, row = 6 },
    { slot = 19, name = "TabardSlot", column = 1, row = 7 },
    { slot = 9, name = "WristSlot", column = 1, row = 8 },
    { slot = 10, name = "HandsSlot", column = 2, row = 1 },
    { slot = 6, name = "WaistSlot", column = 2, row = 2 },
    { slot = 7, name = "LegsSlot", column = 2, row = 3 },
    { slot = 8, name = "FeetSlot", column = 2, row = 4 },
    { slot = 11, name = "Finger0Slot", column = 2, row = 5 },
    { slot = 12, name = "Finger1Slot", column = 2, row = 6 },
    { slot = 13, name = "Trinket0Slot", column = 2, row = 7 },
    { slot = 14, name = "Trinket1Slot", column = 2, row = 8 },
    { slot = 16, name = "MainHandSlot", column = 3, row = 9, place = 1 },
    { slot = 17, name = "SecondaryHandSlot", column = 3, row = 9, place = 2 },
    { slot = 18, name = "RangedSlot", column = 3, row = 9, place = 3 },
}

local CLASSES = {
    { token = "WARRIOR", id = 1, key = "AFF_CLASS_WARRIOR" },
    { token = "PALADIN", id = 2, key = "AFF_CLASS_PALADIN" },
    { token = "HUNTER", id = 3, key = "AFF_CLASS_HUNTER" },
    { token = "ROGUE", id = 4, key = "AFF_CLASS_ROGUE" },
    { token = "PRIEST", id = 5, key = "AFF_CLASS_PRIEST" },
    { token = "DEATHKNIGHT", id = 6, key = "AFF_CLASS_DEATHKNIGHT" },
    { token = "SHAMAN", id = 7, key = "AFF_CLASS_SHAMAN" },
    { token = "MAGE", id = 8, key = "AFF_CLASS_MAGE" },
    { token = "WARLOCK", id = 9, key = "AFF_CLASS_WARLOCK" },
    { token = "DRUID", id = 11, key = "AFF_CLASS_DRUID" },
}

local CLASS_IDS = {}
for _, class in ipairs(CLASSES) do
    CLASS_IDS[class.token] = class.id
end

local function has(collection, value)
    if type(collection) ~= "table" then
        return false
    end
    if collection[value] then
        return true
    end
    for _, item in ipairs(collection) do
        if item == value then
            return true
        end
    end
    return false
end

local function highestRanks(learned)
    local ranks = {}
    if type(learned) ~= "table" then
        return ranks
    end
    for _, item in ipairs(learned) do
        local id, rank = item.familyId, item.rank
        if id and rank and (not ranks[id] or rank > ranks[id]) then
            ranks[id] = rank
        end
    end
    return ranks
end

local function learnedCount(learned)
    if type(learned) ~= "table" then
        return 0
    end
    local seen, count = {}, 0
    for _, item in ipairs(learned) do
        if item.familyId and not seen[item.familyId] then
            seen[item.familyId] = true
            count = count + 1
        end
    end
    return count
end

local function totalCount(families)
    if type(families) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(families) do
        count = count + 1
    end
    return count
end

local function newFilters()
    return {
        search = "",
        classes = {},
        myClass = false,
        categories = {},
        slot = "all",
        wornSlot = nil,
    }
end

local function matchFamily(family, familyId, filters, ctx)
    ctx = ctx or {}
    local search = filters.search
    if search and search ~= "" then
        local needle = lower(search)
        local original = find(lower(family.name or ""), needle, 1, true)
        if not original and not find(lower(EbonAPI.Affixes.GetFamilyName(family) or ""), needle, 1, true) then
            return false
        end
    end

    local categories = filters.categories
    if categories and next(categories) ~= nil and not has(categories, family.category) then
        return false
    end

    if filters.slot ~= nil and filters.slot ~= "all" and ctx.allowed then
        if not ctx.allowed[family.category] then
            return false
        end
    end

    return true
end

local function groupsFor(families, filters, playerClassId, ctx)
    local list = {}
    if type(families) ~= "table" then
        return list, "AFF_NO_DATA"
    end
    if next(families) == nil then
        return list, nil
    end

    local defs = {}
    local added = {}
    local function addClass(class)
        if not added[class.token] then
            added[class.token] = true
            defs[#defs + 1] = {
                key = class.token,
                label = T(class.key),
                bit = bit.lshift(1, class.id - 1),
            }
        end
    end

    if filters.myClass then
        for _, class in ipairs(CLASSES) do
            if class.id == playerClassId then
                addClass(class)
            end
        end
    else
        for _, class in ipairs(CLASSES) do
            if has(filters.classes, class.token) then
                addClass(class)
            end
        end
    end

    if #defs == 0 then
        defs[1] = { key = "ALL", label = T("AFF_GROUP_ALL"), bit = nil, keep = true }
        for _, class in ipairs(CLASSES) do
            if class.id == playerClassId then
                addClass(class)
            end
        end
    end

    local any = false
    for _, def in ipairs(defs) do
        local ids = {}
        for familyId, family in pairs(families) do
            local mask = family.classMask or 0
            local inGroup
            if def.bit then
                inGroup = bit.band(mask, def.bit) ~= 0
            else
                inGroup = mask == 0
            end
            if inGroup and matchFamily(family, familyId, filters, ctx) then
                ids[#ids + 1] = familyId
            end
        end
        sort(ids)
        if #ids > 0 then
            any = true
        end
        if #ids > 0 or def.keep then
            list[#list + 1] = { key = def.key, label = def.label, ids = ids }
        end
    end

    if not any then
        return list, "AFF_NO_RESULT"
    end
    return list, nil
end

View.highestRanks = highestRanks
View.learnedCount = learnedCount
View.totalCount = totalCount
View.matchFamily = matchFamily
View.groupsFor = groupsFor
View.newFilters = newFilters

local view = {}

function View.GetWornSlot()
    return view.filters and view.filters.wornSlot
end

local function playerClassId()
    local _, token = UnitClass("player")
    return CLASS_IDS[token]
end

local function label(parent, text, width, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    if width then
        fs:SetWidth(width)
    end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text or "")
    return fs
end

local function put(object, parent, x, y)
    object:ClearAllPoints()
    object:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
end

local function createKit(kind, parent, spec)
    return EbonAPI.Kit.create("EbonBuilds", kind, parent, spec)
end

local function currentContext(data)
    return {
        highestRank = data.highestRank,
        allowed = data.allowed,
    }
end

local function addPlaces(tip, title, places)
    if not places then
        return
    end
    tip:AddLine(title, 1, 0.82, 0)
    for _, place in ipairs(places) do
        tip:AddLine(format(T("AFF_TIP_ITEM"), place.link, ROMAN[place.rank] or tostring(place.rank)), 1, 1, 1)
    end
end

local function slotName(def)
    if def.label then
        return def.label()
    end
    return T(def.key)
end

local function slotsText(category)
    local allowed
    local Affixes = EbonAPI.Affixes
    local names, seen = {}, {}
    for _, def in ipairs(SLOTS) do
        allowed = Affixes.AllowedCategories(def.loc)
        if allowed and allowed[category] and not seen[def.key] then
            seen[def.key] = true
            names[#names + 1] = slotName(def)
        end
    end
    return table.concat(names, ", ")
end

local function classesText(mask)
    local names = {}
    for _, class in ipairs(CLASSES) do
        if bit.band(mask, bit.lshift(1, class.id - 1)) ~= 0 then
            names[#names + 1] = T(class.key)
        end
    end
    return table.concat(names, ", ")
end

local ENGRAVED_TIP_NAME = "EbonBuildsEngravedTooltip"

local function fillAffixTip(tip, familyId, rank, header)
    local data = view.data
    local family = familyId and data and data.families and data.families[familyId]
    if not family then
        return false
    end

    local color = CATEGORY_COLORS[family.category] or { 1, 1, 1 }
    local name = EbonAPI.Affixes.GetFamilyName(family) or ""
    if rank then
        name = format(T("AFF_TIP_TITLE"), name, ROMAN[rank] or tostring(rank))
    end

    if header then
        tip:SetText(header, 0.7, 0.7, 0.7)
        local line = _G[ENGRAVED_TIP_NAME .. "TextLeft1"]
        if line and GameTooltipTextSmall then
            line:SetFontObject(GameTooltipTextSmall)
        end
        tip:AddLine(name, color[1], color[2], color[3])
    else
        tip:SetText(name, color[1], color[2], color[3])
    end

    local entry = family.ranks and family.ranks[rank or 1]
    if entry then
        local text = EbonAPI.Affixes.RenderText(entry)
        if text then
            tip:AddLine(text, 1, 0.5, 0, true)
        end
    end

    local category = T(CATEGORY_TEXT[family.category] or "AFF_FILTER_CATEGORY")
    local detail = family.spec
    if not detail or detail == "" then
        detail = family.classMask and family.classMask ~= 0 and classesText(family.classMask) or nil
    end
    tip:AddLine(" ")
    tip:AddLine(detail and format(T("AFF_TIP_CATEGORY"), category, detail) or category, color[1], color[2], color[3])

    local slots = slotsText(family.category)
    if slots ~= "" then
        tip:AddLine(format(T("AFF_TIP_SLOTS"), slots), 0.7, 0.7, 0.7, true)
    end

    addPlaces(tip, T("AFF_TIP_EQUIPPED"), data.equippedBy and data.equippedBy[familyId])
    addPlaces(tip, T("AFF_TIP_BAGS"), data.baggedBy and data.baggedBy[familyId])

    local learned = data.highestRank and data.highestRank[familyId]
    if learned then
        tip:AddLine(format(T("AFF_TIP_LEARNED"), ROMAN[learned] or tostring(learned)), 0.3, 0.9, 0.3)
    else
        tip:AddLine(T("AFF_TIP_UNLEARNED"), 0.6, 0.6, 0.6, true)
    end
    tip:Show()
    return true
end

local function hideEngravedTip()
    if view.engravedTip then
        view.engravedTip:Hide()
    end
end

local function showEngravedTip()
    local data = view.data
    local slot = view.filters and view.filters.wornSlot
    local worn = slot and data and data.worn and data.worn[slot]
    if not (worn and worn.familyId and worn.rank) then
        hideEngravedTip()
        return
    end
    local tip = view.engravedTip
    if not tip then
        tip = CreateFrame("GameTooltip", ENGRAVED_TIP_NAME, UIParent, "GameTooltipTemplate")
        view.engravedTip = tip
    end
    tip:SetOwner(GameTooltip, "ANCHOR_NONE")
    if not fillAffixTip(tip, worn.familyId, worn.rank, T("AFF_TIP_ENGRAVED_NOW")) then
        tip:Hide()
        return
    end
    tip:ClearAllPoints()
    local left = GameTooltip:GetLeft()
    if left and left - tip:GetWidth() < 0 then
        tip:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 0, 0)
    else
        tip:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", 0, 0)
    end
end

local function showAffixTip(tile)
    local familyId = tile.familyId
    local data = view.data
    if not (familyId and data and data.families and data.families[familyId]) then
        return
    end
    GameTooltip:SetOwner(tile, "ANCHOR_RIGHT")
    fillAffixTip(GameTooltip, familyId, data.highestRank and data.highestRank[familyId])
    showEngravedTip()
end

local function hideAffixTip()
    GameTooltip:Hide()
    hideEngravedTip()
end

local function engrave()
    return EbonBuilds.Pe.AffixEngrave
end

local function closeEngrave()
    local module = engrave()
    if module and module.Close then
        module.Close()
    end
end

local function onTileClick(tile, button)
    if button and button ~= "LeftButton" then
        return
    end
    local slot = view.filters and view.filters.wornSlot
    local module = engrave()
    if not slot or not module or not tile.familyId then
        return
    end
    local rank = (view.data.highestRank and view.data.highestRank[tile.familyId]) or 1
    if module.IsOpen() then
        local openFamily, openRank = module.GetFamily()
        if openFamily == tile.familyId and openRank == rank then
            module.Close()
            return
        end
    end
    module.Open(tile.familyId, rank, tile, slot)
end

local function acquireTile(index)
    local tile = view.tiles[index]
    if not tile then
        tile = createKit("affixTile", view.child, { category = "offensive", equipped = false, bagged = false, text = "", iconSize = ICON_SIZE })
        tile:EnableMouse(true)
        tile:HookScript("OnEnter", showAffixTip)
        tile:HookScript("OnLeave", hideAffixTip)
        tile:HookScript("OnMouseUp", onTileClick)
        view.tiles[index] = tile
    end
    return tile
end

local function acquireHeading(index)
    local heading = view.headings[index]
    if not heading then
        heading = createKit("heading", view.child, { text = "", width = view.gridW })
        view.headings[index] = heading
    end
    return heading
end

local function paintVisible()
    local top = view.scrollY
    local bottom = top + view.gridH
    local tilesUsed, headsUsed = 0, 0
    local families = view.data.families or {}

    for _, line in ipairs(view.lines) do
        if line.y + line.h >= top and line.y <= bottom then
            if line.heading then
                headsUsed = headsUsed + 1
                local heading = acquireHeading(headsUsed)
                if heading.kitText ~= line.heading then
                    heading.kitText = line.heading
                    heading.spec.text = line.heading
                    heading:Refresh()
                end
                heading:ClearAllPoints()
                heading:SetPoint("TOPLEFT", view.child, "TOPLEFT", 0, -line.y)
                heading:Show()
            else
                for column, familyId in ipairs(line.ids) do
                    local family = families[familyId]
                    tilesUsed = tilesUsed + 1
                    local tile = acquireTile(tilesUsed)
                    tile.familyId = familyId
                    local rank = view.data.highestRank and view.data.highestRank[familyId]
                    local equipped = view.data.equippedSet and view.data.equippedSet[familyId] and true or false
                    local bagged = view.data.baggedSet and view.data.baggedSet[familyId] and true or false
                    local signature = familyId .. ":" .. tostring(rank) .. ":" .. tostring(equipped) .. ":" .. tostring(bagged) .. ":" .. tostring(family.icon)
                    if tile.signature ~= signature then
                        tile.signature = signature
                        tile.spec.category = CATEGORY_KEYS[family.category]
                        tile.spec.icon = family.icon
                        tile.spec.state = nil
                        tile.spec.equipped = equipped
                        tile.spec.bagged = bagged
                        tile.spec.rank = rank
                        tile.spec.text = EbonAPI.Affixes.GetFamilyName(family) or ""
                        tile:Refresh()
                    end
                    tile:ClearAllPoints()
                    tile:SetPoint("TOPLEFT", view.child, "TOPLEFT", (column - 1) * COLUMN_STEP, -line.y)
                    tile:Show()
                end
            end
        end
    end

    for index = tilesUsed + 1, #view.tiles do
        view.tiles[index]:Hide()
    end
    for index = headsUsed + 1, #view.headings do
        view.headings[index]:Hide()
    end
end

local function layoutLines(groups)
    local lines = {}
    local y = 0
    local columns = view.columns
    for _, group in ipairs(groups) do
        lines[#lines + 1] = { y = y, h = HEADING_HEIGHT, heading = group.label }
        y = y + HEADING_HEIGHT
        local total = #group.ids
        local first = 1
        while first <= total do
            local ids = {}
            for column = 0, columns - 1 do
                local id = group.ids[first + column]
                if id then
                    ids[#ids + 1] = id
                end
            end
            lines[#lines + 1] = { y = y, h = ROW_STEP, ids = ids }
            y = y + ROW_STEP
            first = first + columns
        end
        y = y + GROUP_GAP
    end
    view.lines = lines
    view.total = y
end

local function setScroll(value)
    local limit = max(0, view.total - view.gridH)
    view.scrollY = max(0, min(limit, value))
    view.scroll:SetVerticalScroll(view.scrollY)
end

local function updateStatus(learned, families)
    local parts = {}
    if families and learned == nil then
        parts[#parts + 1] = T("AFF_WAITING_SERVER")
    end
    view.status:SetText(table.concat(parts, "  -  "))
end

local function refreshWorn(withModel)
    if not view.slotRows then
        return
    end
    if view.pieceBox then
        view.pieceBox:Hide()
    end
    for _, button in ipairs(view.slotRows) do
        local texture = GetInventoryItemTexture("player", button.inventorySlot)
        button.spec.icon = texture or button.emptyTexture
        button:Refresh()
    end
    if withModel and view.model and view.model:IsShown() then
        view.model:SetUnit("player")
    end
end

local function layoutWorn(height)
    local size = max(8, min(WORN_ICON_MAX, floor((height - WORN_ROWS * WORN_GAP) / (WORN_ROWS + 1))))
    local step = size + WORN_GAP
    local modelHeight = max(1, height - size - WORN_GAP)
    for index, def in ipairs(WORN) do
        local button = view.slotRows[index]
        button:SetWidth(size)
        button:SetHeight(size)
        local x, y
        if def.column == 1 then
            x = WORN_MARGIN
        elseif def.column == 2 then
            x = PANEL_WIDTH - size
        else
            x = floor((WORN_MARGIN + PANEL_WIDTH - (3 * size + 2 * WORN_GAP)) / 2) + (def.place - 1) * step
        end
        if def.column == 1 or def.column == 2 then
            y = floor((def.row - 1) * (modelHeight - size) / (WORN_ROWS - 1) + 0.5)
        else
            y = height - size
        end
        put(button, view.panel, x, y)
    end
    view.model:ClearAllPoints()
    view.model:SetPoint("TOPLEFT", view.panel, "TOPLEFT", WORN_MARGIN + step, 0)
    view.model:SetWidth(max(1, PANEL_WIDTH - WORN_MARGIN - 2 * step))
    view.model:SetHeight(modelHeight)
end

local layout

local function updateSelection()
    local frame = view.selection
    if not frame then
        return
    end
    local slot = view.filters.wornSlot
    if view.selectedSlot == slot then
        return
    end
    view.selectedSlot = slot
    hideEngravedTip()
    if engrave() and engrave().onWornSlotChanged then
        engrave().onWornSlotChanged()
    end
    if not slot then
        frame:Hide()
        return
    end
    for index, def in ipairs(WORN) do
        if def.slot == slot then
            local button = view.slotRows[index]
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", button, "TOPLEFT", -SELECTION_EDGE, SELECTION_EDGE)
            frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", SELECTION_EDGE, -SELECTION_EDGE)
            frame:Show()
            return
        end
    end
    frame:Hide()
end

local function update(resetScroll)
    if not view.frame then
        return
    end

    local Affixes = EbonAPI and EbonAPI.Affixes
    if not Affixes then
        return
    end

    layout()
    if not view.gridH then
        return
    end

    local families = Affixes.GetFamilies()
    local equipped = Affixes.GetEquipped() or {}
    local bagged = Affixes.GetBagged() or {}
    local learned = Affixes.GetLearned()

    local equippedSet, baggedSet = {}, {}
    local equippedBy, baggedBy = {}, {}
    for slot = 1, 19 do
        local entry = equipped[slot]
        if entry and entry.familyId then
            equippedSet[entry.familyId] = true
            local places = equippedBy[entry.familyId] or {}
            equippedBy[entry.familyId] = places
            places[#places + 1] = { link = entry.itemLink, rank = entry.rank }
        end
    end
    for _, entry in ipairs(bagged) do
        if entry.familyId then
            baggedSet[entry.familyId] = true
            local places = baggedBy[entry.familyId] or {}
            baggedBy[entry.familyId] = places
            places[#places + 1] = { link = entry.itemLink, rank = entry.rank }
        end
    end

    local filters = view.filters
    local allowed
    if filters.slot ~= "all" then
        local def = SLOTS[filters.slot]
        allowed = def and Affixes.AllowedCategories(def.loc) or nil
    end

    view.data = {
        families = families,
        equippedSet = equippedSet,
        baggedSet = baggedSet,
        equippedBy = equippedBy,
        baggedBy = baggedBy,
        highestRank = highestRanks(learned),
        allowed = allowed,
        worn = equipped,
    }

    refreshWorn(false)
    updateSelection()

    updateStatus(learned, families)

    local groups, message = groupsFor(families, filters, playerClassId(), currentContext(view.data))
    layoutLines(groups)
    view.child:SetHeight(max(view.total, view.gridH))
    if message then
        view.message:SetText(T(message))
        view.message:Show()
    else
        view.message:Hide()
    end

    setScroll(resetScroll and 0 or view.scrollY)
    paintVisible()
end

local function onFilter()
    if engrave() and engrave().onFilterChanged then
        engrave().onFilterChanged()
    end
    update(true)
end

local function pickSlot(button, mouse)
    if mouse ~= "LeftButton" then
        return
    end
    local filters = view.filters
    local slot = button.inventorySlot
    if filters.wornSlot == slot then
        filters.slot, filters.wornSlot = "all", nil
    elseif SLOT_INDEX[slot] then
        filters.slot, filters.wornSlot = SLOT_INDEX[slot], slot
    else
        return
    end
    onFilter()
end

local PIECE_PAD = 6

local function hideTooltip()
    if view.pieceBox then
        view.pieceBox:Hide()
    end
end

local function pieceBox()
    local box = view.pieceBox
    if box then
        return box
    end
    box = CreateFrame("Frame", nil, view.panel)
    box:EnableMouse(false)
    box:SetFrameLevel(view.model:GetFrameLevel() + 5)
    EbonAPI.Bricks.frame(box, "small")
    box.name = label(box, "", nil, "GameFontNormal")
    box.title = label(box, "", nil, "GameFontNormalSmall")
    box.effect = label(box, "", nil, "GameFontHighlightSmall")
    for _, line in ipairs({ box.name, box.title, box.effect }) do
        line:SetWordWrap(true)
        line:SetNonSpaceWrap(true)
    end
    box.effect:SetTextColor(1, 0.5, 0)
    box:Hide()
    view.pieceBox = box
    return box
end

local function slotTooltip(self)
    local link = GetInventoryItemLink("player", self.inventorySlot)
    if not link then
        hideTooltip()
        return
    end
    local box = pieceBox()
    local itemName, _, quality = GetItemInfo(link)
    local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    local width = max(1, view.model:GetWidth() - 2 * PIECE_PAD)

    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", view.model, "TOPLEFT", 0, 0)
    box:SetPoint("TOPRIGHT", view.model, "TOPRIGHT", 0, 0)

    box.name:SetWidth(width)
    box.name:SetText(itemName or link)
    if qc then
        box.name:SetTextColor(qc.r, qc.g, qc.b)
    end
    box.name:ClearAllPoints()
    box.name:SetPoint("TOPLEFT", box, "TOPLEFT", PIECE_PAD, -PIECE_PAD)
    local used = PIECE_PAD + box.name:GetStringHeight()

    box.title:SetText("")
    box.effect:SetText("")
    local entry = (EbonAPI.Affixes.GetEquipped() or {})[self.inventorySlot]
    local families = (view.data and view.data.families) or EbonAPI.Affixes.GetFamilies()
    local family = entry and entry.familyId and families and families[entry.familyId]
    if family then
        local color = CATEGORY_COLORS[family.category] or { 1, 1, 1 }
        box.title:SetWidth(width)
        box.title:SetText(format(T("AFF_TIP_TITLE"), EbonAPI.Affixes.GetFamilyName(family) or "", ROMAN[entry.rank] or tostring(entry.rank)))
        box.title:SetTextColor(color[1], color[2], color[3])
        box.title:ClearAllPoints()
        box.title:SetPoint("TOPLEFT", box, "TOPLEFT", PIECE_PAD, -(used + PIECE_PAD))
        used = used + PIECE_PAD + box.title:GetStringHeight()

        local ranked = family.ranks and family.ranks[entry.rank or 1]
        local text
        if ranked then
            text = EbonAPI.Affixes.RenderText(ranked)
        end
        if text then
            box.effect:SetWidth(width)
            box.effect:SetText(text)
            box.effect:ClearAllPoints()
            box.effect:SetPoint("TOPLEFT", box, "TOPLEFT", PIECE_PAD, -(used + 2))
            used = used + 2 + box.effect:GetStringHeight()
        end
    end

    box:SetHeight(min(used + PIECE_PAD, view.model:GetHeight()))
    box:Show()
end

local function buildPanel(frame)
    view.panelTitle = label(frame, T("AFF_TITLE_PORTES"), nil, "GameFontNormalLarge")
    put(view.panelTitle, frame, WORN_MARGIN, 9)

    local panel = CreateFrame("Frame", nil, frame)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetHeight(PANEL_HEIGHT)
    put(panel, frame, 0, ROWS_TOP)
    view.panel, view.panelH = panel, PANEL_HEIGHT

    view.model = CreateFrame("PlayerModel", nil, panel)
    local function bindUnit(self)
        if self:GetWidth() > 0 and self:GetHeight() > 0 then
            self:SetUnit("player")
        end
    end
    view.model:SetScript("OnShow", bindUnit)
    view.model:SetScript("OnSizeChanged", bindUnit)

    view.slotRows = {}
    for index, def in ipairs(WORN) do
        local _, emptyTexture = GetInventorySlotInfo(def.name)
        local button
        button = createKit("icon", panel, {
            size = WORN_ICON_MAX,
            icon = emptyTexture,
            onClick = function(_, mouse) pickSlot(button, mouse) end,
        })
        button.inventorySlot = def.slot
        button.emptyTexture = emptyTexture
        button:HookScript("OnEnter", slotTooltip)
        button:HookScript("OnLeave", hideTooltip)
        view.slotRows[index] = button
    end

    local selection = CreateFrame("Frame", nil, panel)
    selection:SetFrameLevel(panel:GetFrameLevel() + 10)
    local bricks = EbonAPI.Bricks
    selection:SetBackdrop({ edgeFile = bricks.media("solid"), edgeSize = SELECTION_EDGE })
    bricks.paint(selection, "SetBackdropBorderColor", "focus")
    selection:Hide()
    view.selection = selection

    local events = CreateFrame("Frame", nil, frame)
    events:SetScript("OnShow", function(self)
        self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        refreshWorn(true)
    end)
    events:SetScript("OnHide", function(self)
        self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
        hideEngravedTip()
        closeEngrave()
    end)
    events:SetScript("OnEvent", function()
        refreshWorn(true)
    end)
    view.events = events
end

local function buildGrid(frame)
    view.gridTitle = label(frame, T("AFF_TITLE_AFFIXES"), nil, "GameFontNormalLarge")
    view.status = label(frame, "", 100, "GameFontDisableSmall")
    view.status:SetHeight(12)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    local child = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        closeEngrave()
        setScroll(view.scrollY - delta * ROW_STEP)
        paintVisible()
    end)

    view.scroll, view.child = scroll, child
    view.tiles, view.headings = {}, {}
    view.lines, view.total, view.scrollY = {}, 0, 0

    view.message = label(frame, "", 100, "GameFontDisable", "CENTER")
    view.message:Hide()

end

local function filterGroups()
    local classItems = {}
    for index, class in ipairs(CLASSES) do
        classItems[index] = { token = class.token, name = T(class.key) }
    end

    local categoryItems = {}
    for category = 1, 5 do
        categoryItems[category] = {
            key = category,
            icon = CATEGORY_ICONS[category],
            border = CATEGORY_COLORS[category],
            name = T(CATEGORY_TEXT[category]),
            read = function() return view.filters.categories[category] == true end,
            write = function(checked) view.filters.categories[category] = checked and true or nil end,
        }
    end

    return {
        {
            kind = "search",
            title = T("AFF_SEARCH_LABEL"),
            hint = T("AFF_SEARCH_HINT"),
            read = function() return view.filters.search end,
            write = function(text) view.filters.search = text or "" end,
        },
        {
            kind = "classes",
            title = T("AFF_FILTER_CLASS"),
            items = classItems,
            read = function()
                for _, class in ipairs(CLASSES) do
                    if view.filters.classes[class.token] == true then
                        return class.token
                    end
                end
                return nil
            end,
            write = function(token)
                view.filters.classes = token and { [token] = true } or {}
            end,
            mine = {
                text = T("AFF_MY_CLASS_ONLY"),
                read = function() return view.filters.myClass == true end,
                write = function(checked) view.filters.myClass = checked and true or false end,
            },
        },
        { kind = "icons", title = T("AFF_FILTER_CATEGORY"), items = categoryItems },
        { kind = "reset", text = T("AFF_RESET_FILTERS"), onClick = function() view.filters = newFilters() end },
    }
end

local function buildFilters(frame)
    view.column = EbonBuilds.Pe.FilterColumn.Create(frame, filterGroups(), onFilter)
end

layout = function()
    local frame = view.frame
    if not frame then
        return false
    end
    local width, height = frame:GetWidth(), frame:GetHeight()
    if not width or width <= 0 or not height or height <= 0 then
        local parent = frame:GetParent()
        width = parent and parent:GetWidth() or 0
        height = parent and parent:GetHeight() or 0
    end
    if not width or width <= 0 or not height or height <= 0 then
        return false
    end
    width, height = floor(width + 0.5), floor(height + 0.5)
    if view.width == width and view.height == height then
        return false
    end
    view.width, view.height = width, height

    view.panelH = max(1, height - ROWS_TOP)
    view.panel:SetHeight(view.panelH)
    layoutWorn(view.panelH)

    local gridX = PANEL_WIDTH + PANEL_GAP
    local available = width - EbonBuilds.Pe.FilterColumn.WIDTH - gridX
    view.columns = max(MIN_COLUMNS, GRID_COLUMNS, floor(available / COLUMN_STEP))
    view.gridW = view.columns * COLUMN_STEP

    local legendY = height - LEGEND_HEIGHT
    local availableHeight = legendY - LEGEND_GAP - GRID_Y
    view.gridH = max(1, availableHeight)

    put(view.gridTitle, frame, gridX, 9)
    put(view.scroll, frame, gridX, GRID_Y)
    view.scroll:SetWidth(view.gridW)
    view.scroll:SetHeight(view.gridH)
    view.child:SetWidth(view.gridW)
    view.child:SetHeight(max(view.total or 0, view.gridH))
    for _, heading in ipairs(view.headings) do
        heading:SetWidth(view.gridW)
    end
    view.message:SetWidth(view.gridW)
    put(view.message, frame, gridX, GRID_Y + 60)

    put(view.status, frame, gridX + 700, legendY)
    view.status:SetWidth(max(60, width - gridX - 700))

    return true
end

EbonBuilds.Pe.Registry.RegisterScreen("affixes", {
    contentWidth = function()
        return PANEL_WIDTH + PANEL_GAP + GRID_WIDTH + EbonBuilds.Pe.FilterColumn.WIDTH
    end,
    build = function(parent)
        local frame = CreateFrame("Frame", nil, parent)
        view.frame = frame
        view.filters = newFilters()
        view.selectedSlot = nil
        view.data = {}
        view.width, view.height = nil, nil

        buildPanel(frame)
        buildGrid(frame)
        buildFilters(frame)

        frame:SetScript("OnSizeChanged", function()
            if layout() and view.data and view.data.families then
                update(false)
            end
        end)
        layout()

        if EbonAPI and EbonAPI.On then
            EbonAPI:On("AFFIXES_CHANGED", function()
                if view.frame and view.frame:IsShown() then
                    update(false)
                end
            end)
        end

        return frame
    end,
    refresh = function(frame)
        if view.frame and frame == view.frame then
            update(false)
        end
    end,
    hide = function()
        hideTooltip()
    end,
})
