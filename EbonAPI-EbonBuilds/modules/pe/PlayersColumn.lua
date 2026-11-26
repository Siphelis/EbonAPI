local ns = EbonBuilds
local Widgets = ns.Widgets

ns.Pe = ns.Pe or {}
local Column = {}
ns.Pe.PlayersColumn = Column

local WIDTH = 170
local MIN_STEP = 16
local ERROR_HEIGHT = 24
local ROW_HEIGHT = 20
local CLASS_STEP = 24
local CLASS_ICON = 20
local ROLE_ICON = 18
local ROLE_STEP = 24
local ROLE_LEVEL = 6
local ROLE_X = 30
local COUNT_WIDTH = 28
local LINE_ALPHA = 0.6
local DIM_ALPHA = 0.35
local MINE_Y = 0
local FAVORITE_Y = 22
local LINE_Y = 44
local CLASSES_Y = 50
local INPUT_HEIGHT = 48
local BUTTON_HEIGHT = 22
local IMPORT_HEIGHT = 28 + INPUT_HEIGHT + 4 + BUTTON_HEIGHT + 4 + ERROR_HEIGHT
local IMPORT_GAP = 6

local column = {
    rows = {},
    roleKeys = {},
    importable = false,
}

local function text(key)
    return ns.L[key] or key
end

local function put(object, parent, x, y)
    object:ClearAllPoints()
    object:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
end

local function line(frame, y)
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetHeight(1)
    tex:SetWidth(WIDTH)
    put(tex, frame, 0, y)
    Widgets.OnLook(function()
        local r, g, b = Widgets.Color("accent")
        tex:SetTexture(ns.Const.SOLID)
        tex:SetVertexColor(r, g, b, LINE_ALPHA)
    end)
    return tex
end

local function label(frame, x, y, width, content, color)
    local piece = Widgets.Kit("text", frame, { text = content, width = width, color = color })
    put(piece, frame, x, y)
    return piece
end

local function counter(frame, y, getter)
    local piece = Widgets.Kit("text", frame, { text = function() return tostring(getter() or 0) end, width = COUNT_WIDTH, color = "muted" })
    piece.text:SetJustifyH("RIGHT")
    put(piece, frame, WIDTH - COUNT_WIDTH, y + 3)
    return piece
end

local function selectionOf(view)
    return view.state and view.state.selection or {}
end

local function newRow(frame, y, onClick)
    local row = EbonAPI.Bricks.create("row", frame)
    row:SetWidth(WIDTH)
    row:SetHeight(y.height or ROW_HEIGHT)
    row:SetLabel("")
    row.onClick = function() onClick() end
    put(row, frame, 0, y.y)
    return row
end

local function framedIcon(parent, size, onClick)
    local button = Widgets.Kit("icon", parent, { size = size, onClick = onClick })
    button.ring = Widgets.Ring(button)
    Widgets.OnLook(function()
        local r, g, b = Widgets.Color("accent")
        button.ring:SetVertexColor(r, g, b, 1)
    end)
    return button
end

local function roleName(key)
    return ns.FamilyName(key)
end

local function roleIcon(parent, key, onClick)
    local button = Widgets.Kit("icon", parent, {
        size = ROLE_ICON,
        onClick = onClick,
        tip = function(lines) lines:Add(roleName(key), "text") end,
    })
    if type(button.SetBackdrop) == "function" then button:SetBackdrop(nil) end
    button.icon:ClearAllPoints()
    button.icon:SetAllPoints(button)
    button.icon:SetTexture(column.roleIcons[key])
    if type(button.SetFrameLevel) == "function" and type(parent.GetFrameLevel) == "function" then
        button:SetFrameLevel(parent:GetFrameLevel() + ROLE_LEVEL)
    end
    button.ring = button:CreateTexture(nil, "BACKGROUND")
    button.ring:SetTexture(ns.Const.SOLID)
    button.ring:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    button.ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button.ring:Hide()
    Widgets.OnLook(function()
        local r, g, b = Widgets.Color("accent")
        button.ring:SetVertexColor(r, g, b, 1)
    end)
    return button
end

local function buildClassRow(frame, view, class, y)
    local token = class.token
    local row = newRow(frame, { y = y, height = CLASS_STEP - 2 }, function()
        view.Select({ kind = "class", class = token })
    end)
    local entry = { token = token, row = row, roles = {}, y = y }

    entry.icon = framedIcon(row, CLASS_ICON, nil)
    entry.icon:EnableMouse(false)
    put(entry.icon, row, 2, 1)
    Widgets.SetClassIcon(entry.icon.icon, token)
    entry.count = counter(frame, y, function() return entry.total end)

    for i = 1, #column.roleKeys do
        local key = column.roleKeys[i]
        local button = roleIcon(frame, key, function()
            local sel = selectionOf(view)
            if sel.kind == "class" and sel.class == token and sel.role == key then
                view.Select({ kind = "class", class = token })
            else
                view.Select({ kind = "class", class = token, role = key })
            end
        end)
        button:Hide()
        entry.roles[key] = button
    end
    return entry
end

local function refreshImportButton()
    if column.importButton then column.importButton:Refresh() end
end

local function problemTextOf(text_)
    local entry, problem, code = ns.PlayerBuilds.Preview(text_)
    if entry then return true, nil end
    if problem or code then return false, ns.PlayerBuilds.ProblemText(problem, code) end
    return false, nil
end

local function onTyped(view, typed)
    local state = view.state
    state.importText = typed
    local ok, message = problemTextOf(typed)
    column.importable = ok
    state.importProblem = message
    column.error:Refresh()
    if message then column.error:Show() else column.error:Hide() end
    refreshImportButton()
end

local function buildImport(parent, view)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(WIDTH)
    frame:SetHeight(IMPORT_HEIGHT)
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    column.importFrame = frame
    local y = 0
    line(frame, y)
    label(frame, 0, y + 4, WIDTH, text("PLAYERS_IMPORT"), "heading")

    column.input = Widgets.Kit("codeBox", frame, {
        width = WIDTH,
        height = INPUT_HEIGHT,
        hint = text("PLAYERS_PASTE"),
        onChange = function(typed) onTyped(view, typed) end,
    })
    put(column.input, frame, 0, y + 28)

    column.button = Widgets.Kit("button", frame, {
        text = text("PLAYERS_IMPORT"),
        width = WIDTH,
        height = BUTTON_HEIGHT,
        disabled = function() return not column.importable end,
        onClick = function()
            if column.importable then view.Preview(view.state.importText) end
        end,
    })
    column.importButton = column.button
    put(column.button, frame, 0, y + 28 + INPUT_HEIGHT + 4)

    column.error = Widgets.Kit("text", frame, {
        text = function() return view.state and view.state.importProblem or "" end,
        width = WIDTH,
        color = "danger",
    })
    put(column.error, frame, 0, y + 28 + INPUT_HEIGHT + 4 + BUTTON_HEIGHT + 4)
    column.error:Hide()
end

function Column.Build(parent, view)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    column.frame = frame
    column.height = nil
    column.step = CLASS_STEP
    column.rows = {}
    column.roleKeys = {}
    column.roleIcons = {}

    local families = EbonAPI.ClientData.Families() or {}
    for i = 1, #families do
        column.roleKeys[#column.roleKeys + 1] = families[i].key
        column.roleIcons[families[i].key] = families[i].icon
    end

    column.mine = newRow(frame, { y = MINE_Y }, function() view.Select({ kind = "mine" }) end)
    label(column.mine, 12, 3, WIDTH - COUNT_WIDTH - 12, text("PLAYERS_MINE"), "text")
    column.mineCount = counter(frame, MINE_Y, function() return column.mineTotal end)

    column.favorites = newRow(frame, { y = FAVORITE_Y }, function() view.Select({ kind = "favorites" }) end)
    column.favoriteStar = column.favorites:CreateTexture(nil, "OVERLAY")
    column.favoriteStar:SetWidth(14)
    column.favoriteStar:SetHeight(14)
    column.favoriteStar:SetPoint("LEFT", column.favorites, "LEFT", 12, 0)
    column.favoriteStar:SetTexture(EbonAPI.Bricks.media("icons"))
    column.favoriteStar:SetTexCoord(EbonAPI.Bricks.glyphCoords("starOn"))
    column.favoriteStar:SetVertexColor(1, 0.82, 0, 1)
    column.favoritesCount = counter(frame, FAVORITE_Y, function() return column.favoritesTotal end)

    line(frame, LINE_Y)

    local classes = EbonAPI.ClientData.Classes() or {}
    for i = 1, #classes do
        column.rows[i] = buildClassRow(frame, view, classes[i], CLASSES_Y + (i - 1) * CLASS_STEP)
    end

    buildImport(frame, view)
    frame:SetScript("OnSizeChanged", function()
        if Column.Layout() and column.view then
            Column.Refresh(column.lists, column.counts, column.view)
        end
    end)
    Column.Layout()

    column.mineTotal, column.favoritesTotal = 0, 0
    return frame
end

function Column.Layout()
    local frame = column.frame
    if not frame then return false end
    local h = frame:GetHeight()
    if not h or h <= 0 then
        local parent = frame:GetParent()
        h = parent and parent:GetHeight() or 0
    end
    h = math.floor((h or 0) + 0.5)
    if h <= 0 or h == column.height then return false end
    column.height = h
    local count = #column.rows
    local step = CLASS_STEP
    if count > 0 then
        local room = h - CLASSES_Y - IMPORT_HEIGHT - IMPORT_GAP
        step = math.max(MIN_STEP, math.min(CLASS_STEP, math.floor(room / count)))
    end
    column.step = step
    for i = 1, count do
        local entry = column.rows[i]
        entry.y = CLASSES_Y + (i - 1) * step
        put(entry.row, frame, 0, entry.y)
        entry.row:SetHeight(step - 2)
        local size = math.min(CLASS_ICON, step - 2)
        entry.icon:SetWidth(size)
        entry.icon:SetHeight(size)
        put(entry.count, frame, WIDTH - COUNT_WIDTH, entry.y + 3)
    end
    return true
end

local function refreshRoles(entry, roleCounts, sel)
    local x = ROLE_X
    for i = 1, #column.roleKeys do
        local key = column.roleKeys[i]
        local button = entry.roles[key]
        if roleCounts and (roleCounts[key] or 0) > 0 then
            put(button, column.frame, x, entry.y + math.floor((column.step - ROLE_ICON) / 2))
            button:Show()
            x = x + ROLE_STEP
            local chosen = sel.kind == "class" and sel.class == entry.token and sel.role == key
            if chosen then button.ring:Show() else button.ring:Hide() end
        else
            button:Hide()
        end
    end
end

function Column.Refresh(lists, counts, view)
    if not column.frame then return end
    column.lists, column.counts, column.view = lists, counts, view
    Column.Layout()
    local state = view.state
    local sel = selectionOf(view)

    column.mineTotal = lists and lists.mine and #lists.mine or 0
    column.favoritesTotal = lists and lists.favorites and #lists.favorites or 0
    column.mineCount:Refresh()
    column.favoritesCount:Refresh()

    if sel.kind == "mine" then column.mine:SetSelected(true) else column.mine:SetSelected(false) end
    if sel.kind == "favorites" then column.favorites:SetSelected(true) else column.favorites:SetSelected(false) end

    for i = 1, #column.rows do
        local entry = column.rows[i]
        local data = counts and counts[entry.token]
        entry.total = data and data.total or 0
        entry.count:Refresh()
        local alpha = entry.total > 0 and 1 or DIM_ALPHA
        entry.icon.icon:SetAlpha(alpha)
        entry.count:SetAlpha(alpha)
        local own = sel.kind == "class" and sel.class == entry.token
        if own and sel.role == nil then entry.row:SetSelected(true) else entry.row:SetSelected(false) end
        if own then entry.icon.ring:Show() else entry.icon.ring:Hide() end
        refreshRoles(entry, data and data.roles, sel)
    end

    if column.input then
        local current = state.importText or ""
        if column.input:GetText() ~= current then
            column.input:SetText(current)
            local ok = problemTextOf(current)
            column.importable = ok
        end
        refreshImportButton()
        column.error:Refresh()
        if state.importProblem then column.error:Show() else column.error:Hide() end
    end
end
