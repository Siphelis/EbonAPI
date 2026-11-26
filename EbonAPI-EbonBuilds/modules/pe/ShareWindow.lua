local WIDTH, HEIGHT = 640, 518
local TAB_WIDTH, TAB_HEIGHT = 170, 18
local BUTTON_HEIGHT = 22
local ZONE_X, ZONE_Y, ZONE_WIDTH, ZONE_HEIGHT = 20, 91, 600, 290
local CARD_WIDTH, CARD_HEIGHT = 190, 62
local COLUMNS = { 0, 196, 392 }
local POOL_SIZE = 24
local ROW_PITCH = 68
local TITLE_TOP = 7
local LINE_OFFSET = 14
local CARDS_OFFSET = 20
local GROUP_GAP = 29
local LINE_WIDTH = 582
local ICON_LIMIT = 6
local GOLD = "|cffFFD100"
local RED = "|cffff5555"
local GREY = "|cff888888"
local RESET = "|r"

local QUALITY_COLORS = {
    [0] = { 1, 1, 1, 1 },
    [1] = { 0.12, 1, 0, 1 },
    [2] = { 0, 0.44, 0.87, 1 },
    [3] = { 0.64, 0.21, 0.93, 1 },
    [4] = { 1, 0.5, 0, 1 },
}

local api
local window, root, tabs
local importPanel, exportPanel
local importBox, recognizedCard, noteLine, saveButton
local exportBox, copyLine, scroll, child
local groupViews = {}
local cells, pool = {}, {}
local state = { result = nil, selected = nil, copyMessage = nil, tab = "import", dirty = true }
local subscribed = false
local selectEntry

local function T(key, fallback)
    local L = EbonBuilds.L
    local value = L and L[key]
    if type(value) == "string" and value ~= key then
        return value
    end
    return fallback
end

local show = EbonBuilds.Pe.Common.show

local function classColor(token)
    local color = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if color then
        return { color.r, color.g, color.b, 1 }
    end
    return { 0.5, 0.5, 0.5, 1 }
end

local function className(token)
    local card = token and EbonAPI.ClientData.Class(token)
    return card and card.name or token or ""
end

local function qualityColor(quality)
    return QUALITY_COLORS[quality or 0] or QUALITY_COLORS[0]
end

local function countText(count)
    return string.format(T("SHARE_ECHOES_COUNT", "%d Echoes"), count)
end

local function problemText(problem, code)
    if not problem and code then
        local ok, made = pcall(api.Problem, api, "IMPORT." .. tostring(code), {})
        problem = ok and made or nil
    end
    if problem then
        return api:ProblemText(problem)
    end
    return T("SHARE_IMPORT_FAILED", "The build could not be imported.")
end

local function label(parent, x, y, width, getter)
    local element = api:Create("text", parent, { width = width, text = getter })
    element:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    return element
end

local function button(parent, x, y, width, getter, onClick)
    local element = api:Create("button", parent, { width = width, text = getter, onClick = onClick })
    element:SetWidth(width)
    element:SetHeight(BUTTON_HEIGHT)
    element:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    return element
end

local function importText(text)
    return EbonBuilds.ExportImport.ImportEBH1(text)
end

local function recognizedBuild(text)
    if type(text) ~= "string" or strtrim(text) == "" then
        return nil
    end
    local parsed, code, problem = EbonBuilds.ExportImport.ParseEBH1(text)
    return parsed, code, problem
end

local function exportEntries()
    local Build = EbonBuilds.Build
    local playerClass = Build.PlayerClassToken()
    local player, favorites, recovered, slots = {}, {}, {}, {}

    local builds = Build.List()
    for i = 1, #builds do
        local build = builds[i]
        player[#player + 1] = {
            kind = "player",
            key = "player:" .. tostring(build.id),
            id = build.id,
            name = build.title or "",
            class = build.class ~= "" and build.class or playerClass,
            echoes = Build.Echoes(build),
        }
    end

    local list = EbonBuilds.Favorites.List()
    for i = 1, #list do
        local favorite = list[i]
        favorites[#favorites + 1] = {
            kind = "favorite",
            key = "favorite:" .. tostring(favorite.id),
            id = favorite.id,
            name = favorite.name or "",
            class = favorite.class,
            echoes = favorite.echoes or {},
            favorite = true,
            raw = favorite,
        }
    end

    list = EbonBuilds.Recovered.List()
    for i = 1, #list do
        local entry = list[i]
        if entry.favorite == false then
            recovered[#recovered + 1] = {
                kind = "recovered",
                key = "recovered:" .. i .. ":" .. tostring(entry.name),
                name = entry.name or "",
                class = entry.class,
                echoes = entry.echoes or {},
                raw = entry,
            }
        end
    end

    local server = EbonAPI.BuildSlots and EbonAPI.BuildSlots.GetServerSlots()
    if type(server) == "table" then
        local order = {}
        for number, slot in pairs(server) do
            if type(number) == "number" and type(slot) == "table" and type(slot.echoes) == "table" and #slot.echoes > 0 then
                order[#order + 1] = number
            end
        end
        table.sort(order)
        for i = 1, #order do
            local number = order[i]
            local slot = server[number]
            local name = type(slot.name) == "string" and slot.name ~= "" and slot.name
                or string.format(T("SHARE_SLOT_NAME", "Slot %d"), number)
            slots[#slots + 1] = {
                kind = "slot",
                key = "slot:" .. number,
                name = name,
                class = playerClass,
                echoes = slot.echoes,
                raw = { name = name, echoes = slot.echoes },
            }
        end
    end

    return {
        { title = "SHARE_GROUP_PLAYER", fallback = "Player builds", entries = player },
        { title = "SHARE_GROUP_FAVORITES", fallback = "Favorites", entries = favorites },
        { title = "SHARE_GROUP_RECOVERED", fallback = "Automatically recovered", entries = recovered },
        { title = "SHARE_GROUP_PE", fallback = "Saved builds of the game", entries = slots },
    }
end

local function exportCode(entry)
    if entry.kind == "slot" then
        if #entry.echoes == 0 then
            return nil, "EXPORT_EMPTY"
        end
        local text = EbonAPI.BuildSlots.Export(entry.raw)
        if type(text) ~= "string" or text == "" then
            return nil, "EXPORT_EMPTY"
        end
        return text
    end
    local source = entry.raw
    if entry.kind == "player" then
        source = entry.id
    elseif entry.kind == "favorite" then
        source = EbonBuilds.Favorites.Get(entry.id) or entry.raw
    end
    return EbonBuilds.ExportImport.ExportEBH1(source)
end

local function refreshNote()
    noteLine:Refresh()
end

local function refreshCopy()
    copyLine:Refresh()
end

local function updateRecognized(text)
    local parsed, code, problem = recognizedBuild(text)
    if not parsed and type(text) == "string" and strtrim(text) ~= "" then
        state.result = RED .. problemText(problem, code) .. RESET
    else
        state.result = nil
    end
    refreshNote()
    if parsed then
        local subtitle = countText(#parsed.echoes)
        if parsed.class then
            subtitle = className(parsed.class) .. " \194\183 " .. subtitle
        end
        recognizedCard:SetSpec({
            name = parsed.name,
            classColor = classColor(parsed.class),
            subtitle = subtitle,
            echoes = {},
        })
        recognizedCard:Show()
    else
        recognizedCard:Hide()
    end
    show(recognizedCard.shareLabel, parsed ~= nil)
    saveButton:SetDisabledState(parsed == nil)
end

local function onImportChanged(text)
    updateRecognized(text)
end

local function saveFavorite()
    local text = importBox:GetText()
    local id, info, problem = importText(text)
    if id then
        if info and info.classMismatch then
            state.result = GOLD .. problemText(api:Problem("IMPORT.CLASS_MISMATCH", {})) .. RESET
        else
            state.result = GOLD .. string.format(T("SHARE_FAVORITE_CREATED", "Favorite created: %s"), info and info.name or "") .. RESET
        end
    else
        state.result = RED .. problemText(problem, info) .. RESET
    end
    refreshNote()
end

local function cancelImport()
    importBox:SetText("")
    state.result = nil
    refreshNote()
    updateRecognized("")
end

local placeIcons

local function newCard(parent)
    local card = api:Create("buildCard", parent, { name = "", echoes = {} })
    local icons = EbonAPI.Bricks.media("icons")
    card:SetWidth(CARD_WIDTH)
    card:SetHeight(CARD_HEIGHT)
    card.shareStar = card:CreateTexture(nil, "OVERLAY")
    card.shareStar:SetWidth(12)
    card.shareStar:SetHeight(12)
    card.shareStar:SetPoint("CENTER", card, "TOPLEFT", 176, -10)
    card.shareStar:SetTexture(icons)
    card.shareStar:SetTexCoord(EbonAPI.Bricks.glyphCoords("starOn"))
    card.shareStar:SetVertexColor(1, 0.82, 0, 1)
    card.shareLock = card:CreateTexture(nil, "OVERLAY")
    card.shareLock:SetWidth(12)
    card.shareLock:SetHeight(12)
    card.shareLock:SetPoint("CENTER", card, "TOPLEFT", 174, -49)
    card.shareLock:SetTexture(icons)
    card.shareLock:SetTexCoord(EbonAPI.Bricks.glyphCoords("lock"))
    card.shareLock:SetVertexColor(1, 0.82, 0, 1)
    placeIcons(card)
    return card
end

local function paintCard(card, entry)
    local selected = entry.key == state.selected
    if card.shareEntry == entry and card.shareSelected == selected then
        return
    end
    card.shareEntry = entry
    card.shareSelected = selected
    local echoes, locked = {}, false
    for i = 1, #entry.echoes do
        local echo = entry.echoes[i]
        if echo.locked == true then
            locked = true
        end
        if i <= ICON_LIMIT then
            echoes[i] = { color = qualityColor(echo.quality), locked = false }
        end
    end
    card:SetSpec({
        name = entry.name,
        classColor = classColor(entry.class),
        subtitle = countText(#entry.echoes),
        echoes = echoes,
        selected = selected,
        onClick = function()
            selectEntry(entry)
        end,
    })
    show(card.shareStar, entry.favorite == true)
    show(card.shareLock, locked)
end

function placeIcons(card)
    for index = 1, #card.icons do
        local icon = card.icons[index]
        icon:SetWidth(10)
        icon:SetHeight(10)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", card, "TOPLEFT", 53 + (index - 1) * 20, -50)
    end
end

local function groupView(index)
    local view = groupViews[index]
    if view then
        return view
    end
    view = { cards = {} }
    view.title = ""
    view.heading = api:Create("text", child, {
        width = ZONE_WIDTH,
        text = function()
            return GOLD .. view.title .. RESET
        end,
    })
    view.line = child:CreateTexture(nil, "ARTWORK")
    view.line:SetTexture("Interface\\Buttons\\WHITE8X8")
    view.line:SetVertexColor(1, 0.82, 0, 1)
    view.line:SetHeight(1)
    view.line:SetWidth(LINE_WIDTH)
    view.empty = api:Create("text", child, {
        width = ZONE_WIDTH,
        text = function()
            return GREY .. T("SHARE_EMPTY_GROUP", "None") .. RESET
        end,
    })
    groupViews[index] = view
    return view
end

local function paintVisible()
    local W = EbonBuilds.Widgets
    local top = (W.ScrollOffset(scroll) or 0) - ROW_PITCH
    local bottom = top + (W.ScrollView(scroll) or ZONE_HEIGHT) + 2 * ROW_PITCH
    local shown = {}
    for i = 1, #cells do
        local cell = cells[i]
        if cell.y > bottom then
            break
        end
        if cell.y + CARD_HEIGHT >= top then
            local slot = (i - 1) % POOL_SIZE + 1
            local card = pool[slot]
            if not card then
                card = newCard(child)
                pool[slot] = card
            end
            if card.shareX ~= cell.x or card.shareY ~= cell.y then
                card.shareX, card.shareY = cell.x, cell.y
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", child, "TOPLEFT", cell.x, -cell.y)
            end
            paintCard(card, cell.entry)
            card:Show()
            shown[slot] = true
        end
    end
    for slot = 1, #pool do
        if pool[slot] and not shown[slot] then
            pool[slot]:Hide()
        end
    end
end

local function layoutExport()
    local groups = exportEntries()
    local cursor = TITLE_TOP
    local keys = {}
    cells = {}
    for g = 1, #groups do
        local group = groups[g]
        local view = groupView(g)
        local entries = group.entries
        view.title = T(group.title, group.fallback)
        view.heading:Refresh()
        view.heading:ClearAllPoints()
        view.heading:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -cursor)
        view.line:ClearAllPoints()
        view.line:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(cursor + LINE_OFFSET))
        view.empty:ClearAllPoints()
        view.empty:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(cursor + CARDS_OFFSET))
        show(view.empty, #entries == 0)
        for i = 1, #entries do
            local entry = entries[i]
            cells[#cells + 1] = {
                entry = entry,
                x = COLUMNS[(i - 1) % 3 + 1],
                y = cursor + CARDS_OFFSET + math.floor((i - 1) / 3) * ROW_PITCH,
            }
            keys[entry.key] = entry
        end
        local rows = math.ceil(#entries / 3)
        if rows == 0 then
            cursor = cursor + CARDS_OFFSET + CARD_HEIGHT + GROUP_GAP
        else
            cursor = cursor + CARDS_OFFSET + rows * ROW_PITCH - (ROW_PITCH - CARD_HEIGHT) + GROUP_GAP
        end
    end
    EbonBuilds.Widgets.ScrollHeight(scroll, cursor)
    paintVisible()
    return keys
end

local function clearSelection()
    state.selected = nil
    state.copyMessage = nil
    exportBox:SetText("")
    refreshCopy()
end

local function refreshExport()
    local keys = layoutExport()
    state.dirty = false
    if state.selected and not keys[state.selected] then
        clearSelection()
    end
end

function selectEntry(entry)
    state.selected = entry.key
    paintVisible()
    local code, reason = exportCode(entry)
    if code and code ~= "" then
        state.copyMessage = nil
        exportBox:SetText(code)
        refreshCopy()
        exportBox:SelectAll()
    else
        exportBox:SetText("")
        if reason == "EXPORT_EMPTY" then
            state.copyMessage = RED .. T("SHARE_EXPORT_EMPTY", "This build has no Echo to export.") .. RESET
        else
            state.copyMessage = RED .. T("SHARE_EXPORT_FAILED", "This build could not be found.") .. RESET
        end
        refreshCopy()
    end
end

local function onDataChanged()
    state.dirty = true
    if window and window:IsShown() and state.tab == "export" then
        refreshExport()
    end
end

local function subscribe()
    if subscribed then
        return
    end
    subscribed = true
    EbonBuilds.Events.On("EB_BUILDS_CHANGED", onDataChanged, "share.builds")
    EbonAPI:On("BUILD_SLOTS_CHANGED", onDataChanged)
end

local function unsubscribe()
    if not subscribed then
        return
    end
    subscribed = false
    EbonBuilds.Events.Off("EB_BUILDS_CHANGED", onDataChanged)
    EbonAPI:Off("BUILD_SLOTS_CHANGED", onDataChanged)
end

local function selectTab(id)
    state.tab = id
    show(importPanel, id == "import")
    show(exportPanel, id == "export")
    if id == "export" then
        clearSelection()
        EbonBuilds.Widgets.ScrollTo(scroll, 0)
        refreshExport()
    end
end

local function buildTabs()
    tabs = api:Create("tabs", root, {
        onSelect = function(_, id)
            selectTab(id)
        end,
    })
    tabs:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -39)
    local first = tabs:AddTab("import", {
        text = function()
            return T("SHARE_TAB_IMPORT", "Import")
        end,
    })
    local second = tabs:AddTab("export", {
        text = function()
            return T("SHARE_TAB_EXPORT", "Export")
        end,
    })
    for _, id in ipairs({ "import", "export" }) do
        local tab = tabs.tabs[id]
        tab.Fit = function(self)
            self:SetWidth(TAB_WIDTH)
        end
    end
    local base = tabs.kitLayoutTabs
    tabs.kitLayoutTabs = function(self)
        base(self)
        local exportTab = self.tabs and self.tabs.export
        if exportTab and self.strip then
            exportTab:ClearAllPoints()
            exportTab:SetPoint("TOPLEFT", self.strip, "TOPLEFT", 180, 0)
        end
    end
    tabs:kitLayoutTabs()
    return first, second
end

local function buildImport(panel)
    label(panel, 20, 77, ZONE_WIDTH, function()
        return T("SHARE_IMPORT_HINT", "Paste a shared build code here.")
    end)
    importBox = api:Create("codeBox", panel, { width = ZONE_WIDTH, height = 250, onChange = onImportChanged })
    importBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -99)

    local recognizedLabel = label(panel, 20, 369, ZONE_WIDTH, function()
        return GOLD .. T("SHARE_RECOGNIZED", "Build recognized") .. RESET
    end)
    recognizedCard = api:Create("buildCard", panel, { name = "", echoes = {} })
    recognizedCard:SetWidth(ZONE_WIDTH)
    recognizedCard:SetHeight(56)
    recognizedCard:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -383)
    recognizedCard.shareLabel = recognizedLabel
    recognizedCard:Hide()
    recognizedLabel:Hide()

    noteLine = label(panel, 20, 457, ZONE_WIDTH, function()
        if state.result then
            return state.result
        end
        return T("SHARE_FAVORITE_NOTE", "This build will be saved as a favorite. It is not added to your builds.")
    end)

    button(panel, 354, 481, 86, function()
        return T("SHARE_CANCEL", "Cancel")
    end, cancelImport)
    saveButton = button(panel, 450, 481, 170, function()
        return T("SHARE_SAVE_FAVORITE", "Save as favorite")
    end, saveFavorite)
    saveButton:SetDisabledState(true)
end

local function buildExport(panel)
    label(panel, 20, 71, ZONE_WIDTH, function()
        return T("SHARE_EXPORT_HINT", "Choose the build to share.")
    end)

    local W = EbonBuilds.Widgets
    scroll = W.Scroll(panel, { width = ZONE_WIDTH, height = ZONE_HEIGHT, onScroll = paintVisible })
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", ZONE_X, -ZONE_Y)
    W.ScrollSize(scroll, ZONE_WIDTH, ZONE_HEIGHT)
    child = scroll._content

    exportBox = api:Create("codeBox", panel, { width = ZONE_WIDTH, height = 56, readOnly = true, copyHint = true })
    exportBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -397)

    copyLine = label(panel, 20, 492, 500, function()
        return state.copyMessage or ""
    end)

    button(panel, 534, 481, 86, function()
        return T("SHARE_CLOSE", "Close")
    end, function()
        window:Close()
    end)
end

local function build()
    api = EbonBuilds.api
    window = api:Window("share", {
        text = function()
            return T("SHARE_WINDOW_TITLE", "Share a build")
        end,
        width = WIDTH,
        height = HEIGHT,
    })
    window:SetFrameStrata("DIALOG")

    root = CreateFrame("Frame", nil, window)
    root:SetWidth(WIDTH)
    root:SetHeight(HEIGHT)
    root:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    root:SetFrameLevel(window:GetFrameLevel() + 5)

    importPanel = CreateFrame("Frame", nil, root)
    importPanel:SetAllPoints(root)
    exportPanel = CreateFrame("Frame", nil, root)
    exportPanel:SetAllPoints(root)

    buildImport(importPanel)
    buildExport(exportPanel)
    buildTabs()
    selectTab("import")

    EbonBuilds.Favorites.OnChanged(onDataChanged)
    EbonBuilds.Recovered.OnChanged(onDataChanged)

    window:HookScript("OnShow", function()
        subscribe()
        if state.tab == "export" and state.dirty then
            refreshExport()
        end
    end)
    window:HookScript("OnHide", unsubscribe)
    subscribe()
    return window
end

EbonBuilds.Pe.Registry.RegisterFloat("share", {
    build = build,
    refresh = function()
        if window and window:IsShown() and state.tab == "export" and state.dirty then
            refreshExport()
        end
    end,
    hide = function()
        if window then
            window:Close()
        end
    end,
})
