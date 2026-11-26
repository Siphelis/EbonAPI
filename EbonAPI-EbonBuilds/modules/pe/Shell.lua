local _, ns = ...

EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.Shell = EbonBuilds.Pe.Shell or {}

local Shell = EbonBuilds.Pe.Shell

local RAIL_WIDTH = 70
local RAIL_GAP = 10
local FILTER_WIDTH = 180
local WIDE_ZONE = 350
local PE_WIDTH = 920
local PE_PAD = 20
local MARGIN_LEFT = 5
local MARGIN_RIGHT = 10
local MARGIN_BOTTOM = 16
local JOURNAL_TOP = 40
local LANE_TOP = 120
local TABS_X = 10
local TABS_TOP = 34
local TABS_GAP = 4
local ORB_ROW = 36
local ORB_PAD = 6
local ROW_GAP = 4
local BLOCK_GAP = 10
local TRAIT_HEIGHT = 1
local MYRUN_WIDTH = 300
local CATALOG_WIDTH = 545
local PANEL_PAD = 6
local BAR_WIDTH = 8
local HEADER_BUTTON = 36
local HEADER_HEIGHT = HEADER_BUTTON + 2 * PANEL_PAD
local JOURNAL_LEFT = RAIL_WIDTH + RAIL_GAP
local PANELS_LEFT = MARGIN_LEFT + RAIL_WIDTH
local MYRUN_ZONE = MYRUN_WIDTH + 2 * PANEL_PAD + BAR_WIDTH
local CATALOG_ZONE = CATALOG_WIDTH + 2 * PANEL_PAD + BAR_WIDTH
local ECHOES_WIDTH = PANELS_LEFT + MYRUN_ZONE + CATALOG_ZONE + FILTER_WIDTH + MARGIN_RIGHT
local WIDE_WIDTH = JOURNAL_LEFT + PE_WIDTH + PE_PAD + WIDE_ZONE + MARGIN_RIGHT

local INSETS = {
    "ProjectEbonholdEchoJournalMyRunInset",
    "ProjectEbonholdEchoJournalCatalogInset",
}

local PANELS = {
    "ProjectEbonholdEchoJournalMyRunScroll",
    "ProjectEbonholdEchoJournalScroll",
}

local CONTROLS = {
    "ProjectEbonholdEchoJournalLoadoutDD",
    "ProjectEbonholdEchoJournalLoadoutDDButton",
    "ProjectEbonholdEchoJournalSearchBox",
    "ProjectEbonholdEchoJournalFilterButton",
    "ProjectEbonholdEchoJournalFilterDD",
}

local SCROLL_LEFT = PANELS_LEFT + PANEL_PAD - JOURNAL_LEFT
local MYRUN_SCROLL = "ProjectEbonholdEchoJournalMyRunScroll"
local CATALOG_SCROLL = "ProjectEbonholdEchoJournalScroll"

local SEPARATORS = {
    { "ProjectEbonholdEchoJournalMyRunInset", "TOPLEFT", "BOTTOMLEFT", 0 },
    { "ProjectEbonholdEchoJournalCatalogInset", "TOPLEFT", "BOTTOMLEFT", 0 },
    { "ProjectEbonholdEchoJournalCatalogInset", "TOPRIGHT", "BOTTOMRIGHT", BAR_WIDTH },
}

local SUBTABS = {
    { "SHELL_TAB_ECHOES", "Echoes", "echoes" },
    { "SHELL_TAB_AFFIXES", "Affixes", "affixes" },
    { "SHELL_TAB_PLAYERS", "Player builds", "players" },
}

local FULL_SCREENS = { affixes = true }

local CATALOG = { "ProjectEbonholdEchoJournalScroll" }

local frame
local lane
local tabs
local rail
local content
local screens = {}
local current
local hooked = {}
local hiddenByUs = {}
local groupOf = {}
local groupOn = { panels = false, catalog = false, controls = false, slots = false, insets = false, orbs = false }
local playersOn = false
local playersMoved = {}
local installed = false
local attached = false
local hooksReady = false
local applying = false
local originalWidth
local barPoints = {}
local placedHooked = {}
local specOf = {}
local bubbleOrigin
local bubbleHooked
local BAR_PANELS = {
    { "ProjectEbonholdEchoJournalMyRunScrollScrollBar", "ProjectEbonholdEchoJournalMyRunInset" },
    { "ProjectEbonholdEchoJournalScrollScrollBar", "ProjectEbonholdEchoJournalCatalogInset" },
}

local function dockBars()
    for _, pair in ipairs(BAR_PANELS) do
        local bar = rawget(_G, pair[1])
        local inset = rawget(_G, pair[2])
        if bar and inset and bar._duiReskinned then
            if not barPoints[bar] then
                local points = {}
                for i = 1, bar:GetNumPoints() do
                    points[i] = { bar:GetPoint(i) }
                end
                barPoints[bar] = points
            end
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", inset, "TOPRIGHT", 0, 0)
            bar:SetPoint("BOTTOMLEFT", inset, "BOTTOMRIGHT", 0, 0)
        end
    end
end

local function undockBars()
    for bar, points in pairs(barPoints) do
        bar:ClearAllPoints()
        for i = 1, #points do
            bar:SetPoint(unpack(points[i]))
        end
    end
    barPoints = {}
end
local panelOrigin = {}
local docked = false
local bubbleDocked = false
local separators
local previousFound
local previousVisible

local function text(key, fallback)
    local L = EbonBuilds.L
    return L and L[key] or fallback
end

local function journal()
    return rawget(_G, "ProjectEbonholdEchoJournal")
end

local function active()
    local window = _G.CollectionsJournal
    local host = journal()
    if not window or not host or not window:IsVisible() then
        return false
    end
    if PanelTemplates_GetSelectedTab(window) ~= 1 then
        return false
    end
    return host:GetParent() == window and host:IsVisible() and true or false
end

local function notifyChase()
    if previousVisible then
        previousVisible(frame and frame:IsShown() and current == "echoes" or false)
    end
end

local seedActive = true

local function clearPilot()
    seedActive = true
    local pilot = EbonAPI and EbonAPI.JournalPilot
    if not pilot then
        return
    end
    if pilot.SetFilter then
        pilot.SetFilter(nil)
    end
    if pilot.SetPreview then
        pilot.SetPreview(nil)
    end
    if pilot.SetPreviewBuild then
        pilot.SetPreviewBuild(nil)
    end
end

local function seedActivePreview()
    seedActive = false
    local pilot = EbonAPI and EbonAPI.JournalPilot
    if not pilot or not pilot.SetPreview then
        return
    end
    local _, slot = EbonAPI.State.activeBuild()
    slot = tonumber(slot)
    if slot then
        pilot.SetPreview(slot)
        if rail and EbonBuilds.Pe.Rail and EbonBuilds.Pe.Rail.Refresh then
            EbonBuilds.Pe.Rail.Refresh()
        end
    end
end

local function nativeFrames(names, group)
    local list = {}
    for i = 1, #names do
        local f = rawget(_G, names[i])
        if f then
            groupOf[f] = group
            list[#list + 1] = f
        end
    end
    if group == "controls" then
        local dd = rawget(_G, "ProjectEbonholdEchoJournalLoadoutDD")
        local footer = dd and dd:GetParent()
        if footer and footer ~= journal() then
            groupOf[footer] = group
            list[#list + 1] = footer
        end
    end
    return list
end

local function suppress(f)
    if f:IsShown() then
        hiddenByUs[f] = true
        f:Hide()
    end
end

local function hookShow(f)
    if hooked[f] then
        return
    end
    hooked[f] = true
    hooksecurefunc(f, "Show", function(self)
        if groupOn[groupOf[self]] then
            suppress(self)
        end
    end)
end

local function hideGroup(names, group)
    groupOn[group] = true
    local list = nativeFrames(names, group)
    for i = 1, #list do
        hookShow(list[i])
        suppress(list[i])
    end
end

local function showGroup(names, group)
    groupOn[group] = false
    local list = nativeFrames(names, group)
    for i = 1, #list do
        if hiddenByUs[list[i]] then
            hiddenByUs[list[i]] = nil
            list[i]:Show()
        end
    end
end

local function slotFrames()
    local pe = rawget(_G, "ProjectEbonhold")
    local slot = pe and pe.EchoJournal and pe.EchoJournal.lastPermanentSlot
    local bar = slot and slot:GetParent()
    local list = {}
    if bar then
        local children = { bar:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if child._bg and child:GetObjectType() == "Button" then
                groupOf[child] = "slots"
                list[#list + 1] = child
            end
        end
    end
    return list
end

local function hideSlots()
    groupOn.slots = true
    local list = slotFrames()
    for i = 1, #list do
        hookShow(list[i])
        suppress(list[i])
    end
end

local function showSlots()
    groupOn.slots = false
    local list = slotFrames()
    for i = 1, #list do
        if hiddenByUs[list[i]] then
            hiddenByUs[list[i]] = nil
            list[i]:Show()
        end
    end
end

local function hideOrbs()
    groupOn.orbs = true
    local bubble = rawget(_G, "EbonholdOrbBubble")
    if bubble then
        groupOf[bubble] = "orbs"
        hookShow(bubble)
        suppress(bubble)
    end
end

local function showOrbs()
    groupOn.orbs = false
    local bubble = rawget(_G, "EbonholdOrbBubble")
    if bubble and hiddenByUs[bubble] then
        hiddenByUs[bubble] = nil
        bubble:Show()
    end
end

function Shell.HideNative()
    showGroup(CATALOG, "catalog")
    hideGroup(PANELS, "panels")
end

function Shell.ShowNative()
    showGroup(CATALOG, "catalog")
    showGroup(PANELS, "panels")
end

local function showPlayersPieces()
    showGroup(PANELS, "panels")
    hideGroup(CATALOG, "catalog")
end

function Shell.RailWidth()
    return RAIL_WIDTH
end

function Shell.HeaderHeight()
    return HEADER_HEIGHT
end

function Shell.HeaderButton()
    return HEADER_BUTTON
end

function Shell.RowGap()
    return ROW_GAP
end

function Shell.PlaceHeader(header)
    if not lane then
        return
    end
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", lane, "TOPLEFT", RAIL_WIDTH, 0)
    header:SetPoint("TOPRIGHT", lane, "TOPLEFT", RAIL_WIDTH + MYRUN_WIDTH + 2 * PANEL_PAD, 0)
end

function Shell.FilterWidth()
    return FILTER_WIDTH
end

local function tabsBottom()
    local strip = tabs and tabs.strip
    return TABS_TOP + (strip and strip:GetHeight() or 0) + TABS_GAP
end

local function laneTop()
    if current == "echoes" then
        return tabsBottom()
    end
    return LANE_TOP
end

local function laneDrop()
    return tabsBottom() - JOURNAL_TOP
end

local function slotMetrics()
    local pe = rawget(_G, "ProjectEbonhold")
    local slot = pe and pe.EchoJournal and pe.EchoJournal.lastPermanentSlot
    if not slot then
        return nil
    end
    local _, _, _, _, y = slot:GetPoint(1)
    return slot:GetHeight(), y or 0
end

local function listOffset()
    local height = slotMetrics()
    return HEADER_HEIGHT + ROW_GAP + (height or 0) + BLOCK_GAP + TRAIT_HEIGHT + ROW_GAP + PANEL_PAD
end

local function barTopY()
    local _, slotY = slotMetrics()
    return -laneDrop() - HEADER_HEIGHT - ROW_GAP - (slotY or 0)
end

local function findBar()
    local pe = rawget(_G, "ProjectEbonhold")
    local slot = pe and pe.EchoJournal and pe.EchoJournal.lastPermanentSlot
    return slot and slot:GetParent() or nil
end

local PLACED = {
    {
        find = function()
            return rawget(_G, MYRUN_SCROLL)
        end,
        x = { TOPLEFT = SCROLL_LEFT, BOTTOMLEFT = SCROLL_LEFT },
        y = {
            TOPLEFT = function()
                return -laneDrop() - listOffset()
            end,
        },
    },
    {
        find = function()
            return rawget(_G, CATALOG_SCROLL)
        end,
        x = {
            TOPLEFT = PANELS_LEFT + MYRUN_ZONE + PANEL_PAD - JOURNAL_LEFT,
            BOTTOMRIGHT = PANELS_LEFT + MYRUN_ZONE + PANEL_PAD + CATALOG_WIDTH - JOURNAL_LEFT - PE_WIDTH,
        },
        y = {
            TOPLEFT = function()
                return -laneDrop() - PANEL_PAD
            end,
        },
    },
    {
        find = function()
            return rawget(_G, "ProjectEbonholdEchoJournalMyRunInset")
        end,
        rel = function()
            return rawget(_G, MYRUN_SCROLL)
        end,
        x = { TOPLEFT = -6 },
        y = {
            TOPLEFT = function()
                return listOffset()
            end,
        },
    },
    {
        find = findBar,
        x = { TOPLEFT = SCROLL_LEFT, TOPRIGHT = SCROLL_LEFT + MYRUN_WIDTH },
        anchor = { TOPRIGHT = "TOPLEFT" },
        y = { TOPLEFT = barTopY, TOPRIGHT = barTopY },
    },
}

local function recordPoint(f, point, rel, relPoint, x, y)
    panelOrigin[f] = panelOrigin[f] or {}
    panelOrigin[f][point] = { point, rel, relPoint, x, y }
end

local function shiftPoint(f, point, rel, relPoint, y)
    local spec = specOf[f]
    if spec and spec.x[point] and rel == (spec.rel and spec.rel() or journal()) then
        local top = spec.y and spec.y[point]
        f:SetPoint(point, rel, spec.anchor and spec.anchor[point] or relPoint, spec.x[point], top and top() or y)
    end
end

local function placeBubble()
    local bubble = rawget(_G, "EbonholdOrbBubble")
    if bubble and frame then
        bubble:ClearAllPoints()
        bubble:SetPoint("LEFT", frame, "TOPLEFT", MARGIN_LEFT + ORB_PAD, -(tabsBottom() + ORB_ROW / 2))
    end
end

local function hookBubble()
    local bubble = rawget(_G, "EbonholdOrbBubble")
    if not bubble or bubbleHooked then
        return
    end
    bubbleHooked = true
    hooksecurefunc(bubble, "SetPoint", function(self, point, rel, relPoint, x, y)
        if applying then
            return
        end
        bubbleOrigin = { point, rel, relPoint, x, y }
        if groupOn.slots then
            hideSlots()
        end
        if bubbleDocked then
            applying = true
            placeBubble()
            applying = false
        end
    end)
end

local function playersAnchors()
    local detail = EbonBuilds.Pe.PlayersDetail
    local anchors = detail and detail.Anchors and detail.Anchors()
    if anchors and anchors.panel and anchors.bar then
        return anchors
    end
    return nil
end

local function captureOrigin(f)
    for n = 1, f:GetNumPoints() do
        local point, rel, relPoint, x, y = f:GetPoint(n)
        if not (panelOrigin[f] and panelOrigin[f][point]) then
            recordPoint(f, point, rel, relPoint, x, y)
        end
    end
end

local function placePlayers()
    local anchors = playersAnchors()
    local panel = rawget(_G, MYRUN_SCROLL)
    local bar = findBar()
    if not anchors or not panel or not bar then
        return false
    end
    captureOrigin(panel)
    captureOrigin(bar)
    local wasApplying = applying
    applying = true
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", anchors.panel, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", anchors.panel, "BOTTOMRIGHT", 0, 0)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", anchors.bar, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", anchors.bar, "TOPRIGHT", 0, 0)
    applying = wasApplying
    playersMoved = { panel, bar }
    playersOn = true
    return true
end

local function hookPlaced()
    for i = 1, #PLACED do
        local spec = PLACED[i]
        local f = spec.find()
        if f then
            specOf[f] = spec
            if not placedHooked[f] then
                placedHooked[f] = true
                hooksecurefunc(f, "SetPoint", function(self, point, rel, relPoint, x, y)
                    if applying then
                        return
                    end
                    if playersOn and (self == playersMoved[1] or self == playersMoved[2]) then
                        applying = true
                        placePlayers()
                        applying = false
                        return
                    end
                    recordPoint(self, point, rel, relPoint, x, y)
                    if docked then
                        applying = true
                        hookPlaced()
                        hookBubble()
                        shiftPoint(self, point, rel, relPoint, y)
                        placeBubble()
                        applying = false
                    end
                end)
            end
        end
    end
end

local function dockPanels()
    hookPlaced()
    for i = 1, #PLACED do
        local f = PLACED[i].find()
        if f then
            local points = {}
            for n = 1, f:GetNumPoints() do
                points[n] = { f:GetPoint(n) }
            end
            for n = 1, #points do
                local point, rel, relPoint, x, y = unpack(points[n])
                if not (panelOrigin[f] and panelOrigin[f][point]) then
                    recordPoint(f, point, rel, relPoint, x, y)
                end
                shiftPoint(f, point, rel, relPoint, y)
            end
        end
    end
end

local function dockBubble()
    hookBubble()
    bubbleDocked = true
    local bubble = rawget(_G, "EbonholdOrbBubble")
    if bubble then
        if not bubbleOrigin and bubble:GetNumPoints() > 0 then
            bubbleOrigin = { bubble:GetPoint(1) }
        end
        placeBubble()
    end
end

local function undockBubble()
    bubbleDocked = false
    local bubble = rawget(_G, "EbonholdOrbBubble")
    if bubble and bubbleOrigin then
        bubble:ClearAllPoints()
        bubble:SetPoint(unpack(bubbleOrigin))
    end
    bubbleOrigin = nil
end

local undockPanels

local function releasePlayers()
    if not playersOn then
        return
    end
    playersOn = false
    for i = 1, #playersMoved do
        playersMoved[i]:ClearAllPoints()
    end
    playersMoved = {}
    undockPanels()
end

function undockPanels()
    for f, points in pairs(panelOrigin) do
        for _, p in pairs(points) do
            f:SetPoint(unpack(p))
        end
    end
    panelOrigin = {}
end

local function placeSeparators()
    if not separators then
        separators = CreateFrame("Frame", nil, frame)
        separators.lines = {}
        for i = 1, #SEPARATORS do
            local line = separators:CreateTexture(nil, "ARTWORK")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            EbonAPI.Bricks.paint(line, "SetVertexColor", "border")
            line:SetWidth(1)
            separators.lines[i] = line
        end
    end
    for i = 1, #SEPARATORS do
        local spec = SEPARATORS[i]
        local rel = rawget(_G, spec[1])
        local line = separators.lines[i]
        line:ClearAllPoints()
        if rel then
            line:SetPoint("TOPLEFT", rel, spec[2], spec[4], 0)
            line:SetPoint("BOTTOMLEFT", rel, spec[3], spec[4], 0)
        end
    end
end

local function affixesWidth()
    local def = EbonBuilds.Pe.Registry.GetScreen("affixes")
    local zone = def and def.contentWidth and def.contentWidth()
    if not zone then
        return ECHOES_WIDTH
    end
    return MARGIN_LEFT + zone + MARGIN_RIGHT
end

local function playersWidth()
    local def = EbonBuilds.Pe.Registry.GetScreen("players")
    local zone = def and def.contentWidth and def.contentWidth()
    if not zone then
        return ECHOES_WIDTH
    end
    return MARGIN_LEFT + zone + MARGIN_RIGHT
end

local function targetWidth()
    if current == "echoes" then
        return ECHOES_WIDTH
    end
    if current == "players" then
        return playersWidth()
    end
    if FULL_SCREENS[current] then
        return affixesWidth()
    end
    return WIDE_WIDTH
end

local function isShellWidth(width)
    return math.abs(width - ECHOES_WIDTH) <= 0.5 or math.abs(width - WIDE_WIDTH) <= 0.5
        or math.abs(width - affixesWidth()) <= 0.5 or math.abs(width - playersWidth()) <= 0.5
end

local function applyGeometry()
    local window = _G.CollectionsJournal
    local host = journal()
    if applying or not window or not host then
        return
    end
    applying = true
    releasePlayers()
    local width = window:GetWidth()
    if not isShellWidth(width) then
        originalWidth = width
    end
    if math.abs(width - targetWidth()) > 0.5 then
        window:SetSize(targetWidth(), window:GetHeight())
    end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", window, "TOPLEFT", JOURNAL_LEFT, -JOURNAL_TOP)
    docked = current == "echoes"
    dockBubble()
    if docked then
        dockPanels()
        placeSeparators()
        separators:Show()
    else
        undockPanels()
        if separators then
            separators:Hide()
        end
    end
    if current == "players" then
        placePlayers()
    else
        dockBars()
    end
    applying = false
end

local function restoreGeometry()
    local window = _G.CollectionsJournal
    if originalWidth and window and not applying and isShellWidth(window:GetWidth()) then
        applying = true
        window:SetSize(originalWidth, window:GetHeight())
        applying = false
    end
    applying = true
    docked = false
    releasePlayers()
    undockPanels()
    undockBubble()
    applying = false
    undockBars()
    originalWidth = nil
end

local function placeContent()
    if not content then
        return
    end
    content:ClearAllPoints()
    if current == "echoes" then
        content:SetPoint("TOPLEFT", lane, "TOPRIGHT", -FILTER_WIDTH, 0)
    elseif FULL_SCREENS[current] or current == "players" then
        content:SetPoint("TOPLEFT", lane, "TOPLEFT", 0, LANE_TOP - tabsBottom())
    else
        content:SetPoint("TOPLEFT", lane, "TOPLEFT", RAIL_WIDTH + RAIL_GAP, 0)
    end
    content:SetPoint("BOTTOMRIGHT", lane, "BOTTOMRIGHT", 0, 0)
end

local function placeScreen(screenFrame)
    screenFrame:ClearAllPoints()
    screenFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    screenFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
end

function Shell.Layout()
    if not frame then
        return
    end
    tabs:ClearAllPoints()
    tabs:SetPoint("TOPLEFT", frame, "TOPLEFT", JOURNAL_LEFT + TABS_X, -TABS_TOP)
    lane:ClearAllPoints()
    lane:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN_LEFT, -laneTop())
    lane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -MARGIN_RIGHT, MARGIN_BOTTOM)
    if rail then
        rail:ClearAllPoints()
        rail:SetPoint("TOPLEFT", lane, "TOPLEFT", 0, current == "echoes" and -ORB_ROW or 0)
        rail:SetPoint("BOTTOMLEFT", lane, "BOTTOMLEFT", 0, 0)
        if FULL_SCREENS[current] or current == "players" then
            rail:Hide()
        else
            rail:Show()
        end
    end
    placeContent()
end

local function hideScreen(key)
    local entry = screens[key]
    local def = entry and EbonBuilds.Pe.Registry.GetScreen(key)
    if def and def.hide then
        def.hide(entry)
    end
end

local function refreshScreen(key)
    local entry = screens[key]
    local def = EbonBuilds.Pe.Registry.GetScreen(key)
    if entry and def and def.refresh then
        def.refresh(entry, EbonBuilds.Build.GetActive and EbonBuilds.Build.GetActive() or nil)
    end
end

function Shell.Refresh()
    if frame and frame:IsShown() and current then
        refreshScreen(current)
    end
    if rail and EbonBuilds.Pe.Rail and EbonBuilds.Pe.Rail.Refresh then
        EbonBuilds.Pe.Rail.Refresh()
    end
end

function Shell.Select(key)
    if not frame then
        return false
    end
    local Registry = EbonBuilds.Pe.Registry
    if current and screens[current] and current ~= key then
        hideScreen(current)
        screens[current]:Hide()
        if current == "echoes" or current == "players" then
            clearPilot()
        end
    end
    current = key
    applyGeometry()
    Shell.Layout()
    local def = Registry.GetScreen(key)
    if def and not screens[key] and def.build then
        local built = def.build(content)
        if built then
            screens[key] = built
            placeScreen(built)
        end
    end
    if key == "echoes" then
        if seedActive then
            seedActivePreview()
        end
        Shell.ShowNative()
        showSlots()
    elseif key == "players" then
        showPlayersPieces()
        showSlots()
        placePlayers()
    else
        Shell.HideNative()
        hideSlots()
    end
    if FULL_SCREENS[key] or key == "players" then
        hideOrbs()
    else
        showOrbs()
    end
    if tabs.current ~= key then
        tabs:Select(key)
    end
    if screens[key] then
        screens[key]:Show()
    end
    refreshScreen(key)
    notifyChase()
    return true
end

local function build()
    local window = _G.CollectionsJournal
    if not window then
        return false
    end
    frame = CreateFrame("Frame", nil, window)
    frame:SetAllPoints(window)
    frame:SetFrameLevel(window:GetFrameLevel() + 20)
    frame:Hide()

    lane = CreateFrame("Frame", nil, frame)

    content = CreateFrame("Frame", nil, lane)

    tabs = EbonBuilds.Widgets.Kit("tabs", frame, {
        onSelect = function(_, id)
            if id ~= current then
                Shell.Select(id)
            end
        end,
    })
    for i = 1, #SUBTABS do
        local row = SUBTABS[i]
        tabs:AddTab(row[3], {
            text = function()
                return text(row[1], row[2])
            end,
        })
    end

    local Rail = EbonBuilds.Pe.Rail
    if Rail and Rail.Create then
        rail = Rail.Create(lane)
    end

    frame:SetScript("OnHide", function()
        if current then
            hideScreen(current)
        end
    end)

    EbonBuilds.Build.OnActiveChanged(function()
        Shell.Refresh()
    end)
    return true
end

function Shell.Open()
    if not EbonAPI.Ebonhold.IsPresent() or not active() then
        return false
    end
    if not frame and not build() then
        return false
    end
    applyGeometry()
    frame:Show()
    Shell.Layout()
    hideGroup(CONTROLS, "controls")
    hideGroup(INSETS, "insets")
    local keys = EbonBuilds.Pe.Registry.ScreenKeys()
    local first = current or SUBTABS[1][3]
    if not current then
        for i = 1, #SUBTABS do
            if EbonBuilds.Pe.Registry.GetScreen(SUBTABS[i][3]) then
                first = SUBTABS[i][3]
                break
            end
        end
        if keys[1] and not EbonBuilds.Pe.Registry.GetScreen(first) then
            first = keys[1]
        end
    end
    Shell.Select(first)
    if rail and EbonBuilds.Pe.Rail.Refresh then
        EbonBuilds.Pe.Rail.Refresh()
    end
    return true
end

function Shell.Hide()
    if frame and frame:IsShown() then
        frame:Hide()
        clearPilot()
    end
    showGroup(CATALOG, "catalog")
    showGroup(PANELS, "panels")
    showGroup(CONTROLS, "controls")
    showGroup(INSETS, "insets")
    showSlots()
    showOrbs()
    restoreGeometry()
    notifyChase()
end

local function evaluate()
    if not attached then
        return
    end
    local open = frame and frame:IsShown()
    if active() then
        if not open then
            Shell.Open()
        else
            applyGeometry()
        end
    elseif open or groupOn.panels or groupOn.controls or groupOn.insets or groupOn.slots or groupOn.orbs or originalWidth then
        Shell.Hide()
    end
end

local function installHooks()
    if hooksReady then
        return
    end
    local window = _G.CollectionsJournal
    local host = journal()
    if not window or not host then
        return
    end
    hooksReady = true
    hooksecurefunc("CollectionsJournal_UpdateSelectedTab", evaluate)
    hooksecurefunc(window, "SetSize", function()
        if not applying and attached and frame and frame:IsShown() then
            evaluate()
        end
    end)
    hooksecurefunc(host, "SetPoint", function()
        if not applying and attached and frame and frame:IsShown() then
            applyGeometry()
        end
    end)
    hookPlaced()
    window:HookScript("OnHide", evaluate)
end

function Shell.Attach()
    attached = true
    installHooks()
    evaluate()
end

local function onEchoes(on)
    if not attached then
        if previousVisible then previousVisible(on) end
        return
    end
    evaluate()
    notifyChase()
end

function Shell.Install()
    if installed then
        return false
    end
    installed = true
    previousFound = ns.OnJournalFound
    previousVisible = ns.OnEchoesVisible
    ns.OnJournalFound = function(journalRoot)
        if previousFound then previousFound(journalRoot) end
        Shell.Attach()
    end
    ns.OnEchoesVisible = onEchoes
    return true
end
