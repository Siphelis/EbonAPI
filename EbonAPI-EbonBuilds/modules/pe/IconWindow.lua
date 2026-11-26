local COLUMNS = 10
local GAP = 4
local BAR_WIDTH = 24
local ZONE_X, ZONE_Y = 20, 40
local ZONE_HEIGHT = 380
local HEIGHT = ZONE_Y + ZONE_HEIGHT + 20
local DEFAULT_ICON = "Spell_Shadow_SoulGem"

local api
local window, scroll, child, defaultCell
local pool = {}
local headers = {}
local groupButtons, subButtons = {}, {}
local icons = {}
local sorted
local model, viewGroup, viewSub = nil, 1, nil
local target = {}
local size, pitch, zoneWidth, gridWidth, headHeight, leftWidth

local OTHER_GROUP = 7
local PREFIX = { spell = 2, ability = 3, inv = 4, trade = 5, achievement = 6 }
local SCHOOL = { fire = 1, frost = 2, holy = 3, shadow = 4, nature = 5, arcane = 6 }
local CLASSES = {
    warrior = 1, paladin = 2, hunter = 3, rogue = 4, priest = 5,
    deathknight = 6, shaman = 7, mage = 8, warlock = 9, druid = 10,
}
local ITEM = {
    sword = 1, axe = 1, mace = 1, hammer = 1, staff = 1, wand = 1, weapon = 1, spear = 1,
    throwingknife = 1, throwingaxe = 1, knife = 1,
    helmet = 2, chest = 2, shoulder = 2, boots = 2, gauntlets = 2, belt = 2, bracer = 2,
    pants = 2, shirt = 2, shield = 2, crown = 2,
}
local SEGMENTS = { [2] = SCHOOL, [3] = CLASSES, [4] = ITEM }
local FALLBACK = { [2] = 7, [3] = 11, [4] = 3 }
local QUESTION = "INV_Misc_QuestionMark"

local GROUPS = {
    { key = "ICONWIN_GROUP_ALL", icon = "INV_Misc_Book_09" },
    { key = "ICONWIN_GROUP_SPELLS", icon = "Spell_Fire_FlameBolt" },
    { key = "ICONWIN_GROUP_ABILITIES", icon = "Ability_Warrior_Charge" },
    { key = "ICONWIN_GROUP_ITEMS", icon = "INV_Sword_04" },
    { key = "ICONWIN_GROUP_TRADES", icon = "Trade_BlackSmithing" },
    { key = "ICONWIN_GROUP_ACHIEVEMENTS", icon = "Achievement_General" },
    { key = "ICONWIN_GROUP_OTHER", icon = QUESTION },
}

local SUBS = {
    [2] = {
        { key = "ICONWIN_SCHOOL_FIRE", icon = "Spell_Fire_FireBolt02" },
        { key = "ICONWIN_SCHOOL_FROST", icon = "Spell_Frost_FrostBolt02" },
        { key = "ICONWIN_SCHOOL_HOLY", icon = "Spell_Holy_HolyBolt" },
        { key = "ICONWIN_SCHOOL_SHADOW", icon = "Spell_Shadow_ShadowBolt" },
        { key = "ICONWIN_SCHOOL_NATURE", icon = "Spell_Nature_Lightning" },
        { key = "ICONWIN_SCHOOL_ARCANE", icon = "Spell_Arcane_Blast" },
        { key = "ICONWIN_SUB_OTHER", icon = QUESTION },
    },
    [3] = {
        { class = "WARRIOR" }, { class = "PALADIN" }, { class = "HUNTER" }, { class = "ROGUE" },
        { class = "PRIEST" }, { class = "DEATHKNIGHT" }, { class = "SHAMAN" }, { class = "MAGE" },
        { class = "WARLOCK" }, { class = "DRUID" },
        { key = "ICONWIN_SUB_OTHER", icon = QUESTION },
    },
    [4] = {
        { key = "ICONWIN_ITEM_WEAPONS", icon = "INV_Sword_04" },
        { key = "ICONWIN_ITEM_ARMOR", icon = "INV_Chest_Plate01" },
        { key = "ICONWIN_ITEM_MISC", icon = "INV_Misc_Bag_08" },
    },
}

local function noLines() end

local function T(key, fallback)
    local L = EbonBuilds.L
    local value = L and L[key]
    if type(value) == "string" and value ~= key then
        return value
    end
    return fallback
end

local function store()
    local data = EbonAPIEbonBuildsCharDB
    data.buildIcons = data.buildIcons or {}
    return data.buildIcons
end

local IconWindow = {}
EbonBuilds.Pe.IconWindow = IconWindow

IconWindow.DEFAULT_ICON = DEFAULT_ICON

function IconWindow.Get(slot, name)
    local entry = store()[slot]
    if entry and entry.build == name and type(entry.icon) == "string" then
        return entry.icon
    end
    return DEFAULT_ICON
end

local function save(icon)
    local entries = store()
    if icon == DEFAULT_ICON then
        entries[target.slot] = nil
    else
        entries[target.slot] = { icon = icon, build = target.name }
    end
    local Rail = EbonBuilds.Pe.Rail
    if Rail and Rail.Refresh then
        Rail.Refresh()
    end
    window:Close()
end

local function subLabel(entry)
    if entry.class then
        return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class
    end
    return T(entry.key, entry.key)
end

local function subIcon(entry)
    if entry.class then
        local card = EbonAPI.ClientData.Class(entry.class)
        return card and card.texture
    end
    return entry.icon
end

local function classify(name)
    if type(name) ~= "string" or name == "" then
        return OTHER_GROUP, nil
    end
    local file = string.lower(string.match(name, "[^\\/]*$") or "")
    local first, second = string.match(file, "^([^_]*)_?([^_]*)")
    local group = PREFIX[first]
    if not group then
        return OTHER_GROUP, nil
    end
    local segments = SEGMENTS[group]
    if not segments then
        return group, nil
    end
    return group, segments[second] or FALLBACK[group]
end

function IconWindow.Classify(name)
    return classify(name)
end

function IconWindow.Sort(list)
    local buckets = {}
    for group = 2, OTHER_GROUP do
        local entry = {}
        local subs = SUBS[group]
        if subs then
            for sub = 1, #subs do
                entry[sub] = {}
            end
        else
            entry[0] = {}
        end
        buckets[group] = entry
    end
    for i = 1, #list do
        local name = list[i]
        local group, sub = classify(name)
        local bucket = buckets[group][sub or 0]
        bucket[#bucket + 1] = name
    end
    return buckets
end

local function readIcons()
    for i = 1, GetNumMacroIcons() do
        icons[#icons + 1] = GetMacroIconInfo(i)
    end
    for i = 1, GetNumMacroItemIcons() do
        icons[#icons + 1] = GetMacroItemIconInfo(i)
    end
end

local function ensureSorted()
    if not sorted then
        readIcons()
        sorted = IconWindow.Sort(icons)
    end
    return sorted
end

function IconWindow.BuildModel(buckets, group, sub)
    local rows = { { kind = "default", top = 0, height = pitch } }
    local top = pitch
    local first = group ~= 1 and group or 2
    local last = group ~= 1 and group or OTHER_GROUP
    local started = false
    for g = first, last do
        local subs = SUBS[g]
        local from, to = 0, 0
        if subs then
            from, to = sub or 1, sub or #subs
        end
        for s = from, to do
            local list = buckets[g][s]
            if list and #list > 0 then
                local title = T(GROUPS[g].key, GROUPS[g].key)
                if subs then
                    title = string.format(T("ICONWIN_SECTION", "%s · %s"), title, subLabel(subs[s]))
                end
                local height = headHeight * (started and 2 or 1)
                rows[#rows + 1] = { kind = "header", top = top, height = height, title = title, separated = started }
                top = top + height
                started = true
                for index = 1, #list, COLUMNS do
                    rows[#rows + 1] = {
                        kind = "icons",
                        top = top,
                        height = pitch,
                        list = list,
                        first = index,
                        count = math.min(COLUMNS, #list - index + 1),
                    }
                    top = top + pitch
                end
            end
        end
    end
    return rows, top
end

function IconWindow.FirstVisible(rows, offset)
    local low, high = 1, #rows
    while low < high do
        local mid = math.floor((low + high) / 2)
        local row = rows[mid]
        if row.top + row.height > offset then
            high = mid
        else
            low = mid + 1
        end
    end
    return low
end

function IconWindow.NextView(group, sub, clickedGroup, clickedSub)
    if clickedGroup then
        return clickedGroup, nil
    end
    if clickedSub == sub then
        return group, nil
    end
    return group, clickedSub
end

local function paintCell(cell, list, index, top, left)
    local icon = list[index]
    cell.iconName = icon
    cell.spec.icon = icon
    cell:kitRefresh()
    cell:SetCheckedState(icon == target.icon)
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", child, "TOPLEFT", left, -top)
    cell:Show()
end

local function newCell()
    local cell = api:Create("icon", child, { size = size, icon = DEFAULT_ICON })
    cell.spec.onClick = function()
        save(cell.iconName)
    end
    return cell
end

local function newHeader()
    local entry = {
        title = EbonBuilds.Widgets.Kit("heading", child, { text = "", width = gridWidth }),
        rule = EbonBuilds.Widgets.Kit("heading", child, { text = "", width = gridWidth }),
    }
    return entry
end

local function placeHeader(entry, row)
    local titleTop = row.top
    if row.separated then
        entry.rule:ClearAllPoints()
        entry.rule:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -row.top)
        entry.rule:Show()
        titleTop = row.top + headHeight
    else
        entry.rule:Hide()
    end
    entry.title.spec.text = row.title
    entry.title:kitRefresh()
    entry.title:ClearAllPoints()
    entry.title:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -titleTop)
    entry.title:Show()
end

local function paintVisible()
    if not model then
        return
    end
    local W = EbonBuilds.Widgets
    local offset = W.ScrollOffset(scroll) or 0
    local bottom = offset + (W.ScrollView(scroll) or ZONE_HEIGHT)
    local cells, heads = 0, 0
    for i = IconWindow.FirstVisible(model, offset), #model do
        local row = model[i]
        if row.top >= bottom then
            break
        end
        if row.kind == "header" then
            heads = heads + 1
            local entry = headers[heads]
            if not entry then
                entry = newHeader()
                headers[heads] = entry
            end
            placeHeader(entry, row)
        elseif row.kind == "icons" then
            for k = 0, row.count - 1 do
                cells = cells + 1
                local cell = pool[cells]
                if not cell then
                    cell = newCell()
                    pool[cells] = cell
                end
                paintCell(cell, row.list, row.first + k, row.top, k * pitch)
            end
        end
    end
    for i = cells + 1, #pool do
        pool[i]:Hide()
    end
    for i = heads + 1, #headers do
        headers[i].title:Hide()
        headers[i].rule:Hide()
    end
end

local function refreshColumns()
    for g = 1, #GROUPS do
        groupButtons[g]:SetCheckedState(g == viewGroup)
    end
    local subs = SUBS[viewGroup]
    for s = 1, #subButtons do
        local button = subButtons[s]
        if subs and subs[s] then
            button.entry = subs[s]
            button:Refresh()
            button:SetCheckedState(s == viewSub)
            button:Show()
        else
            button:Hide()
        end
    end
end

local function applyView(group, sub)
    viewGroup, viewSub = group, sub
    local total
    model, total = IconWindow.BuildModel(ensureSorted(), group, sub)
    local W = EbonBuilds.Widgets
    W.ScrollHeight(scroll, total)
    W.ScrollTo(scroll, 0)
    refreshColumns()
    defaultCell:SetCheckedState(target.icon == DEFAULT_ICON)
    paintVisible()
end

local function populate()
    applyView(1, nil)
end

local function newColumnButton(parent, left, top, entryOf, onClick)
    local button = api:Create("icon", parent, {
        size = size,
        icon = function(self)
            return subIcon(entryOf(self))
        end,
        text = function(self)
            return subLabel(entryOf(self))
        end,
        tip = noLines,
        onClick = onClick,
    })
    hooksecurefunc(button, "Refresh", function(self)
        local entry = entryOf(self)
        if entry.class then
            EbonBuilds.Widgets.SetClassIcon(self.icon, entry.class)
        else
            self.icon:SetTexCoord(0, 1, 0, 1)
        end
    end)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)
    return button
end

local function buildColumns(root)
    for g = 1, #GROUPS do
        groupButtons[g] = newColumnButton(root, ZONE_X, ZONE_Y + (g - 1) * pitch, function()
            return GROUPS[g]
        end, function()
            applyView(IconWindow.NextView(viewGroup, viewSub, g, nil))
        end)
    end
    for s = 1, #SUBS[3] do
        local button = newColumnButton(root, ZONE_X + pitch, ZONE_Y + (s - 1) * pitch, function(self)
            return self.entry or {}
        end, function()
            applyView(IconWindow.NextView(viewGroup, viewSub, nil, s))
        end)
        button.entry = {}
        button:Hide()
        subButtons[s] = button
    end
end

local function build()
    api = EbonBuilds.api
    size = EbonAPI.Bricks.value("kit.icon.size")
    pitch = size + GAP
    gridWidth = COLUMNS * pitch - GAP
    zoneWidth = COLUMNS * pitch + BAR_WIDTH
    headHeight = EbonAPI.Bricks.value("widgets.heading.height") + GAP
    leftWidth = 2 * pitch + GAP

    window = api:Window("iconchoice", {
        text = function()
            return string.format(T("ICONWIN_TITLE", "Choose an icon: %s"), target.name or "")
        end,
        width = leftWidth + zoneWidth + 3 * ZONE_X,
        height = HEIGHT,
    })
    window:SetFrameStrata("DIALOG")

    local root = CreateFrame("Frame", nil, window)
    root:SetAllPoints(window)
    root:SetFrameLevel(window:GetFrameLevel() + 5)

    buildColumns(root)

    local W = EbonBuilds.Widgets
    scroll = W.Scroll(root, { width = zoneWidth, height = ZONE_HEIGHT, onScroll = paintVisible })
    scroll:SetPoint("TOPLEFT", root, "TOPLEFT", ZONE_X + leftWidth + ZONE_X, -ZONE_Y)
    W.ScrollSize(scroll, zoneWidth, ZONE_HEIGHT)
    child = scroll._content

    defaultCell = api:Create("icon", child, {
        size = size,
        icon = DEFAULT_ICON,
        text = function()
            return T("ICONWIN_DEFAULT", "Default icon")
        end,
        tip = T("ICONWIN_DEFAULT_TIP", "Icon shown by Project Ebonhold."),
        onClick = function()
            save(DEFAULT_ICON)
        end,
    })
    defaultCell:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)

    return window
end

function IconWindow.Open(slot, name)
    target.slot, target.name = slot, name
    target.icon = IconWindow.Get(slot, name)
    EbonBuilds.Pe.Registry.OpenFloat("iconchoice")
    if window and window:IsShown() then
        if window.Refresh then
            window:Refresh()
        end
        populate()
    end
end

EbonBuilds.Pe.Registry.RegisterFloat("iconchoice", {
    build = build,
    hide = function()
        if window then
            window:Close()
        end
    end,
})
