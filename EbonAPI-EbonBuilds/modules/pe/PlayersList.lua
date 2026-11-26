EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.PlayersList = EbonBuilds.Pe.PlayersList or {}

local PlayersList = EbonBuilds.Pe.PlayersList

local MAX_POOL = 30
local ROW_HEIGHT = 44
local CLASS_X = 6
local CLASS_SIZE = 28
local ROLE_X = CLASS_X + CLASS_SIZE + 4
local ROLE_SIZE = 20
local ECHO_SIZE = 26
local ECHO_STEP = 32
local ECHO_X = ROLE_X + ROLE_SIZE + 6
local STAR_SIZE = 16
local STAR_GAP = 2
local STAR_LEAD = 12
local STAR_MARGIN = 8
local SLOTS = EbonBuilds.Const.BUILD_LOCKED_SLOTS
local COUNT_STARS = 3
local floor, max = math.floor, math.max

local scroll, content
local rows = {}
local current = {}
local owner
local listFrame
local height = 0
local rowWidth = 0
local overhead

local function starsWidth()
    return COUNT_STARS * STAR_SIZE + (COUNT_STARS - 1) * STAR_GAP
end

function PlayersList.RowWidth()
    local echoesEnd = ECHO_X + (SLOTS - 1) * ECHO_STEP + ECHO_SIZE
    return echoesEnd + STAR_LEAD + starsWidth() + STAR_MARGIN
end

local function skinNumber(key, fallback)
    local skins = EbonAPI and EbonAPI.Skins
    local value = skins and skins.value and skins.value(key)
    return tonumber(value) or fallback
end

function PlayersList.BarRoom()
    return skinNumber("widgets.scroll.width", 8) + skinNumber("kit.gap", 2)
end

function PlayersList.Overhead()
    if overhead then return overhead end
    return 2 * skinNumber("widgets.group.padding", 0)
end

function PlayersList.Width()
    return PlayersList.RowWidth() + PlayersList.BarRoom() + PlayersList.Overhead()
end

local function placeStars(row)
    if rowWidth >= PlayersList.RowWidth() then
        EbonBuilds.Stars.Place(row._stars, "RIGHT", row, "RIGHT", -(STAR_MARGIN + STAR_SIZE + STAR_GAP), 0)
    else
        local x = ECHO_X + (SLOTS - 1) * ECHO_STEP + ECHO_SIZE + STAR_LEAD + STAR_SIZE + STAR_GAP
        EbonBuilds.Stars.Place(row._stars, "LEFT", row, "LEFT", x, 0)
    end
end

local function roleIcon(key)
    local families = EbonAPI and EbonAPI.ClientData and EbonAPI.ClientData.Families and EbonAPI.ClientData.Families()
    if type(families) ~= "table" or not key then return nil end
    for i = 1, #families do
        if families[i].key == key then return families[i].icon end
    end
    return nil
end

local function lockedEchoes(entry)
    local list = {}
    local echoes = entry and entry.echoes
    if type(echoes) ~= "table" then return list end
    for i = 1, #echoes do
        if echoes[i].locked ~= false then
            list[#list + 1] = echoes[i]
            if #list >= SLOTS then break end
        end
    end
    return list
end

local function paintRow(row, entry)
    local W = EbonBuilds.Widgets
    row._entry = entry
    local selection = owner and owner.state and owner.state.selection
    row:SetSelected(selection ~= nil and selection.entry == entry)
    W.SetClassIcon(row._class, entry.class)
    local role = EbonBuilds.PlayerBuilds.Roles(entry)
    local path = roleIcon(role)
    if path then
        row._role:SetTexture(path)
        row._role:Show()
    else
        row._role:Hide()
    end
    local echoes = lockedEchoes(entry)
    for i = 1, SLOTS do
        local icon = row._echoes[i]
        local echo = echoes[i]
        icon._spellId = echo and echo.spellId or nil
        icon._quality = echo and echo.quality or nil
        icon:Refresh()
        if echo then
            W.SetRing(icon._ring, echo.quality or 0)
            icon:Show()
        else
            icon._ring:Hide()
            icon:Hide()
        end
    end
    EbonBuilds.Stars.Set(row._stars, EbonBuilds.PlayerBuilds.Stars(entry))
end

local function paint()
    if not scroll then return end
    local offset = EbonBuilds.Widgets.ScrollOffset(scroll) or 0
    local first = max(0, floor(offset / ROW_HEIGHT))
    for i = 1, #rows do
        local row = rows[i]
        local index = first + i
        local entry = current[index]
        if entry then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
            paintRow(row, entry)
            row:Show()
        else
            row._entry = nil
            row:Hide()
        end
    end
end

local function choose(row)
    local entry = row._entry
    if not entry or not owner then return end
    owner.state.selection.entry = entry
    paint()
    if owner.SelectEntry then
        owner.SelectEntry(entry)
    elseif owner.Refresh then
        owner.Refresh()
    end
end

local function newRow()
    local W = EbonBuilds.Widgets
    local row = EbonAPI.Bricks.create("row", content)
    row:SetWidth(rowWidth)
    row:SetHeight(ROW_HEIGHT - 2)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self) choose(self) end)
    row._class = row:CreateTexture(nil, "ARTWORK")
    row._class:SetWidth(CLASS_SIZE)
    row._class:SetHeight(CLASS_SIZE)
    row._class:SetPoint("LEFT", row, "LEFT", CLASS_X, 0)
    row._role = row:CreateTexture(nil, "ARTWORK")
    row._role:SetWidth(ROLE_SIZE)
    row._role:SetHeight(ROLE_SIZE)
    row._role:SetPoint("LEFT", row, "LEFT", ROLE_X, 0)
    row._stars = EbonBuilds.Stars.Create(row, STAR_SIZE, STAR_GAP, "OVERLAY")
    placeStars(row)
    row._echoes = {}
    for i = 1, SLOTS do
        local icon = W.Kit("icon", row, {
            size = ECHO_SIZE,
            icon = function(self)
                return self._spellId and select(3, GetSpellInfo(self._spellId)) or nil
            end,
            onClick = function() choose(row) end,
        })
        icon:SetPoint("LEFT", row, "LEFT", ECHO_X + (i - 1) * ECHO_STEP, 0)
        icon:SetFrameLevel(row:GetFrameLevel() + 2)
        icon._ring = W.Ring(icon)
        W.SpellTip(icon, function(self) return self._spellId, self._quality end, { describe = true, colored = true })
        row._echoes[i] = icon
    end
    row:Hide()
    return row
end

local function measure()
    if not listFrame then return 0 end
    local h = listFrame:GetHeight()
    if not h or h <= 0 then
        local parent = listFrame:GetParent()
        h = parent and parent:GetHeight() or 0
    end
    return floor((h or 0) + 0.5)
end

local function fit()
    local w = content and content:GetWidth() or 0
    if w <= 0 or w == rowWidth then return end
    rowWidth = w
    for i = 1, #rows do
        rows[i]:SetWidth(w)
        placeStars(rows[i])
    end
end

local function settle(h)
    local W = EbonBuilds.Widgets
    for _ = 1, 3 do
        local wide = PlayersList.Width()
        W.ScrollSize(scroll, wide, h)
        local view = scroll.kitScroll and scroll.kitScroll.child and scroll.kitScroll.child:GetWidth() or 0
        if view <= 0 then break end
        local found = max(0, wide - PlayersList.BarRoom() - view)
        if found == PlayersList.Overhead() then break end
        overhead = found
    end
    local wide = PlayersList.Width()
    if listFrame and owner and owner.SetListWidth then owner.SetListWidth(wide) end
end

local function layout()
    local h = measure()
    if h <= 0 then return false end
    local heightChanged = h ~= height
    height = h
    settle(h)
    fit()
    if not heightChanged then return false end
    local need = math.min(MAX_POOL, math.ceil(h / ROW_HEIGHT) + 2)
    for i = #rows + 1, need do
        rows[i] = newRow()
    end
    return true
end

function PlayersList.Build(parent, view)
    local W = EbonBuilds.Widgets
    owner = view
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    listFrame = frame
    height = 0
    rows = {}
    overhead = nil
    rowWidth = 0
    scroll = W.Scroll(frame, { width = PlayersList.Width(), height = 1, onScroll = paint })
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    content = scroll._content
    frame:SetScript("OnSizeChanged", function()
        if layout() then PlayersList.Refresh(current, owner) end
    end)
    layout()
    PlayersList.frame = frame
    return frame
end

function PlayersList.Refresh(filtered, view)
    if view then owner = view end
    current = filtered or {}
    if not scroll then return end
    layout()
    local W = EbonBuilds.Widgets
    local shown = math.max(height, 1)
    W.ScrollHeight(scroll, max(shown, #current * ROW_HEIGHT))
    local limit = max(0, #current * ROW_HEIGHT - shown)
    if (W.ScrollOffset(scroll) or 0) > limit then W.ScrollTo(scroll, limit) end
    paint()
end
