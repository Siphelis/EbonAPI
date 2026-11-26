EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}

local View = {}
EbonBuilds.Pe.PlayersView = View

local WIDTH = 1150
local BOTTOM_MARGIN = 6
local COLUMN = { x = 20, w = 170 }
local GAP = 15
local LIST = { x = COLUMN.x + COLUMN.w + GAP }

local state = {
    view = "list",
    selection = { kind = "mine" },
    importText = "",
    importEntry = nil,
    importProblem = nil,
    previous = nil,
    pushed = nil,
    pushedSet = false,
}
View.state = state

local dirty = true
local saving = false
local pendingId
local subscribed = false
local lists, counts, filtered = nil, nil, {}
local builtFrame
local firstPending = false

local function copySelection(selection)
    local copy = {}
    for key, value in pairs(selection or {}) do
        copy[key] = value
    end
    return copy
end

local function zone(parent, rect)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", rect.x, 0)
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", rect.x, BOTTOM_MARGIN)
    frame:SetWidth(rect.w)
    return frame
end

local function listZone(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", LIST.x, 0)
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", LIST.x, BOTTOM_MARGIN)
    frame:SetWidth(EbonBuilds.Pe.PlayersList.Width())
    return frame
end

local function detailZone(parent, list)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", list, "TOPRIGHT", GAP, 0)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, BOTTOM_MARGIN)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    return frame
end

local function markDirty()
    dirty = true
    EbonBuilds.PlayerBuilds.Invalidate()
    if not saving and builtFrame and builtFrame:IsShown() then
        View.Refresh()
    end
end

local function indexOf(list, test)
    for i, item in ipairs(list) do
        if test(item) then
            return i
        end
    end
    return nil
end

local function clearImport()
    state.importEntry = nil
    state.importProblem = nil
end

local function sourceFor(selection)
    if not lists then
        return {}
    end
    if selection.kind == "favorites" then
        return lists.favorites or {}
    elseif selection.kind == "class" then
        return lists.received or {}
    end
    return lists.mine or {}
end

local function computeFiltered()
    local selection = state.selection
    local source = sourceFor(selection)
    if selection.kind == "class" then
        filtered = EbonBuilds.PlayerBuilds.Filter(source, selection.class, selection.role)
    else
        filtered = source
    end
    if pendingId then
        local wanted = pendingId
        pendingId = nil
        selection.entry = nil
        local at = indexOf(filtered, function(item) return item.id == wanted end)
        selection.entry = at and filtered[at] or nil
        return
    end
    if selection.entry and not indexOf(filtered, function(item) return item == selection.entry end) then
        selection.entry = nil
    end
    if not selection.entry then
        selection.entry = filtered[1]
    end
end

local function pushPreview()
    local pilot = EbonAPI and EbonAPI.JournalPilot
    if not (pilot and pilot.SetPreviewBuild) then
        return
    end
    local entry
    if state.view == "import" then
        entry = state.importEntry
    else
        entry = state.selection and state.selection.entry
    end
    local list = entry and entry.echoes
    if not (list and #list > 0) then
        entry = nil
    end
    if state.pushedSet and state.pushed == entry then
        if not pilot.GetPreviewBuild or pilot.GetPreviewBuild() == state.pushedBuild then
            return
        end
    end
    state.pushedSet = true
    state.pushed = entry
    state.pushedBuild = nil
    if not entry then
        pilot.SetPreviewBuild(nil)
        return
    end
    local echoes = {}
    for _, echo in ipairs(entry.echoes) do
        if not echo.avoid then
            echoes[#echoes + 1] = { spellId = echo.spellId, quality = echo.quality, stacks = echo.stacks, locked = echo.locked ~= false }
        end
    end
    state.pushedBuild = { echoes = echoes }
    pilot.SetPreviewBuild(state.pushedBuild)
end

function View.SetListWidth(width)
    local host = View.listHost
    if host and width and width > 0 and host:GetWidth() ~= width then
        host:SetWidth(width)
    end
end

function View.contentWidth()
    return WIDTH
end

function View.Build(parent)
    local frame = CreateFrame("Frame", nil, parent)
    builtFrame = frame
    View.frame = frame
    if frame.SetScript then
        frame:SetScript("OnHide", function()
            local pilot = EbonAPI and EbonAPI.JournalPilot
            if not (pilot and pilot.GetPreviewBuild) then
                state.pushed = nil
                state.pushedSet = false
            end
        end)
        frame:SetScript("OnShow", function()
            if firstPending then View.Refresh() end
        end)
    end

    local Pe = EbonBuilds.Pe
    View.columnFrame = Pe.PlayersColumn.Build(zone(frame, COLUMN), View)
    local listHost = listZone(frame)
    View.listHost = listHost
    View.listFrame = Pe.PlayersList.Build(listHost, View)
    View.detailFrame = Pe.PlayersDetail.Build(detailZone(frame, listHost), View)

    if not subscribed then
        subscribed = true
        if EbonBuilds.Recovered and EbonBuilds.Recovered.OnChanged then
            EbonBuilds.Recovered.OnChanged(markDirty)
        end
    end

    dirty = true
    firstPending = true
    return frame
end

function View.Refresh()
    local Pe = EbonBuilds.Pe
    local PB = EbonBuilds.PlayerBuilds
    if not View.columnFrame then
        return
    end
    firstPending = false
    if dirty or not lists then
        dirty = false
        local mine, favorites, received = PB.Lists()
        lists = { mine = mine, favorites = favorites, received = received }
        counts = PB.ClassCounts(lists.received or {})
    end
    computeFiltered()
    Pe.PlayersColumn.Refresh(lists, counts, View)
    Pe.PlayersList.Refresh(filtered, View)
    Pe.PlayersDetail.Refresh(View)
    pushPreview()
end

function View.SelectEntry(entry)
    local selection = state.selection
    if not (View.columnFrame and selection) then return end
    selection.entry = entry
    EbonBuilds.Pe.PlayersDetail.Refresh(View)
    pushPreview()
end

function View.Select(selection)
    state.selection = copySelection(selection)
    state.view = "list"
    clearImport()
    View.Refresh()
end

function View.Preview(text)
    state.importText = text or ""
    local entry, problem, code = EbonBuilds.PlayerBuilds.Preview(text)
    if entry then
        state.previous = copySelection(state.selection)
        state.view = "import"
        state.importEntry = entry
        state.importProblem = nil
    else
        state.importEntry = nil
        if problem or code then
            state.importProblem = EbonBuilds.PlayerBuilds.ProblemText(problem, code)
        else
            state.importProblem = nil
        end
    end
    View.Refresh()
end

function View.Save()
    saving = true
    local ok, id, problem, code = pcall(EbonBuilds.PlayerBuilds.Save, state.importText)
    saving = false
    if not ok then error(id, 0) end
    if id then
        pendingId = id
        state.view = "list"
        state.selection = { kind = "favorites" }
        clearImport()
        state.importText = ""
        dirty = true
        EbonBuilds.PlayerBuilds.Invalidate()
    else
        state.importProblem = EbonBuilds.PlayerBuilds.ProblemText(problem, code)
    end
    View.Refresh()
end

function View.Cancel()
    state.view = "list"
    state.selection = state.previous or { kind = "mine" }
    state.previous = nil
    clearImport()
    View.Refresh()
end

EbonBuilds.Pe.Registry.RegisterScreen("players", {
    contentWidth = function()
        return WIDTH
    end,
    build = function(parent)
        return View.Build(parent)
    end,
    refresh = function()
        View.Refresh()
    end,
})
