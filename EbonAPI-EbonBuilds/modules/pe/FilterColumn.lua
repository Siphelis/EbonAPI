EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.FilterColumn = EbonBuilds.Pe.FilterColumn or {}

local FilterColumn = EbonBuilds.Pe.FilterColumn

FilterColumn.WIDTH = 180
FilterColumn.PAD = 5
FilterColumn.GAP = 10

local WIDTH, PAD = FilterColumn.WIDTH, FilterColumn.PAD
local INNER = WIDTH - 2 * PAD
local HEIGHT = 480
local START_Y = 6
local SELECT_HEIGHT = 40
local SEGMENT_HEIGHT = 24
local SEARCH_DELAY = 0.25
local SEARCH_INPUT = 10
local SEARCH_STEP = 41
local CELL_STEP = 86
local CELL_WIDTH = 82
local GAP = 2
local ROW = 15
local LABEL_STEP = 14
local BUTTON_HEIGHT = 20
local WHITE = "Interface\\Buttons\\WHITE8X8"

local CLASS_ICON = 30
local CLASS_GAP = 4
local CLASS_PER_ROW = 5
local SPEC_PER_CLASS = 3
local GRID_WIDTH = CLASS_PER_ROW * CLASS_ICON + (CLASS_PER_ROW - 1) * CLASS_GAP
local SPEC_ROW_WIDTH = SPEC_PER_CLASS * CLASS_ICON + (SPEC_PER_CLASS - 1) * CLASS_GAP

local ICON = 24
local ICON_GAP = 4
local ICON_PER_ROW = 6

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

local function kit(kind, parent, spec)
    return EbonBuilds.Widgets.Kit(kind, parent, spec)
end

local function noLines() end

local function str(value)
    if type(value) == "function" then return value() end
    return value
end

local function notify(column)
    if column.onChange then column.onChange() end
end

local function acted(column)
    column.Refresh()
    notify(column)
end

local function title(column, group, y)
    if not group.title then return 0 end
    local fontString = column.Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontString:SetPoint("TOPLEFT", column.Frame, "TOPLEFT", PAD, -y)
    fontString:SetText(group.title)
    return LABEL_STEP
end

local function mark(icon, selected)
    icon:SetCheckedState(selected)
    icon.icon:SetDesaturated(not selected)
    icon:SetAlpha(selected and 1 or EbonAPI.Bricks.value("widgets.disabledAlpha"))
end

local function addNote(column, group, y)
    if not group.note then return end
    local note = column.Frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPRIGHT", column.Frame, "TOPRIGHT", -PAD, -y)
    note:Hide()
    column.refreshers[#column.refreshers + 1] = function()
        local shown = group.note()
        if shown and shown ~= "" then
            note:SetText(shown)
            note:Show()
        else
            note:SetText("")
            note:Hide()
        end
    end
end

local function buildSearch(column, group, y)
    local frame = column.Frame
    local offset = title(column, group, y) > 0 and SEARCH_INPUT or 0
    local waiter = CreateFrame("Frame", nil, frame)
    local state = {}

    local function cancel()
        waiter:SetScript("OnUpdate", nil)
        state.pending = nil
    end

    local function schedule(value)
        state.pending = value or ""
        waiter.elapsed = 0
        waiter:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < SEARCH_DELAY then return end
            self:SetScript("OnUpdate", nil)
            local pending = state.pending
            state.pending = nil
            if pending ~= nil then
                group.write(pending)
                notify(column)
            end
        end)
    end

    local box = kit("input", frame, {
        width = INNER,
        hint = group.hint,
        onInput = function(_, value) schedule(value) end,
        onChange = function(_, value) schedule(value) end,
    })
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(y + offset))

    column.cancels[#column.cancels + 1] = cancel
    column.clears[#column.clears + 1] = function()
        if box.SetValue then box:SetValue("") end
    end
    column.refreshers[#column.refreshers + 1] = function()
        if state.pending == nil and box.edit then
            local value = group.read() or ""
            if (box.edit:GetText() or ""):lower() ~= value:lower() then
                box:SetValue(value)
            end
        end
    end
    return y + offset + SEARCH_STEP
end

local function buildClasses(column, group, y)
    local frame = column.Frame
    local top = y + title(column, group, y)
    local icons, indexOf = {}, {}
    local items = group.items
    for i = 1, #items do
        local token = items[i].token
        local item = items[i]
        local icon = kit("icon", frame, {
            size = CLASS_ICON,
            icon = function() return EbonAPI.ClientData.Class(token).texture end,
            text = function() return str(item.name) end,
            tip = noLines,
            onClick = function()
                if group.read() == token then
                    group.write(nil)
                else
                    group.write(token)
                end
                acted(column)
            end,
        })
        EbonBuilds.Widgets.ClassIcon(icon, function() return token end)
        local c, r = (i - 1) % CLASS_PER_ROW, floor((i - 1) / CLASS_PER_ROW)
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2 + c * (CLASS_ICON + CLASS_GAP),
            -(top + r * (CLASS_ICON + CLASS_GAP)))
        icons[token] = icon
        indexOf[token] = i
    end

    local cursor = top + ceil(#items / CLASS_PER_ROW) * (CLASS_ICON + CLASS_GAP)
    local specTop = cursor
    local specSets = {}
    local specs = group.specs

    local function specSet(token)
        if specSets[token] then return specSets[token] end
        local list = specs.of(token)
        local set = {}
        for i = 1, min(#list, SPEC_PER_CLASS) do
            local spec = list[i]
            local icon = kit("icon", frame, {
                size = CLASS_ICON,
                icon = function() return spec.icon end,
                text = function() return str(spec.name) end,
                tip = noLines,
                onClick = function()
                    local selected = specs.read()
                    specs.write(spec.key, not (selected[spec.key] == true))
                    acted(column)
                end,
            })
            icon:Hide()
            set[i] = { icon = icon, key = spec.key }
        end
        specSets[token] = set
        return set
    end

    if specs then cursor = cursor + CLASS_ICON + GAP end

    if group.mine then
        local mine = group.mine
        local box = kit("checkBox", frame, {
            text = mine.text,
            width = INNER - 2,
            onChange = function(checked)
                mine.write(checked and true or false)
                acted(column)
            end,
        })
        box:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -cursor)
        cursor = cursor + ROW + GAP
        column.refreshers[#column.refreshers + 1] = function()
            box:SetChecked(mine.read() == true)
        end
    elseif not specs then
        cursor = cursor + GAP
    end

    column.refreshers[#column.refreshers + 1] = function()
        local current = group.read()
        for token, icon in pairs(icons) do
            mark(icon, token == current)
        end
        if not specs then return end
        for _, set in pairs(specSets) do
            for i = 1, #set do set[i].icon:Hide() end
        end
        if not current or not indexOf[current] then return end
        local set = specSet(current)
        local selected = specs.read()
        local centre = PAD + 2 + ((indexOf[current] - 1) % CLASS_PER_ROW) * (CLASS_ICON + CLASS_GAP) + CLASS_ICON / 2
        local left = max(PAD + 2, min(centre - SPEC_ROW_WIDTH / 2, PAD + 2 + GRID_WIDTH - SPEC_ROW_WIDTH))
        for i = 1, #set do
            local icon = set[i].icon
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", left + (i - 1) * (CLASS_ICON + CLASS_GAP), -specTop)
            icon:Show()
            mark(icon, selected[set[i].key] == true)
        end
    end
    return cursor
end

local function buildChecks(column, group, y)
    local frame = column.Frame
    local top = y + title(column, group, y)
    local columns = group.columns or 1
    local rowHeight = group.height or ROW
    local width = columns == 1 and INNER - 2 or CELL_WIDTH
    local items = group.items
    for i = 1, #items do
        local item = items[i]
        local caption = item.text
        local color = item.color
        if color then
            caption = string.format("|cff%02x%02x%02x%s|r", floor(color[1] * 255 + 0.5), floor(color[2] * 255 + 0.5),
                floor(color[3] * 255 + 0.5), caption)
        end
        local box = kit("checkBox", frame, {
            text = caption,
            width = width,
            height = group.height,
            onChange = function(checked)
                item.write(checked and true or false)
                acted(column)
            end,
        })
        local c, r = (i - 1) % columns, floor((i - 1) / columns)
        box:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2 + c * CELL_STEP, -(top + r * rowHeight))
        if color then
            local swatch = box:CreateTexture(nil, "OVERLAY")
            swatch:SetTexture(WHITE)
            swatch:SetVertexColor(color[1], color[2], color[3])
            swatch:SetSize(9, 9)
            swatch:SetPoint("RIGHT", box, "RIGHT", -2, 0)
        end
        column.refreshers[#column.refreshers + 1] = function()
            box:SetChecked(item.read() == true)
        end
    end
    return top + ceil(#items / columns) * rowHeight + GAP
end

local function buildIcons(column, group, y)
    local frame = column.Frame
    local top = y + title(column, group, y)
    local items = group.items
    local count = #items
    for i = 1, count do
        local item = items[i]
        local color = item.color
        local icon = kit("icon", frame, {
            size = ICON,
            icon = function() return color and WHITE or item.icon end,
            text = function() return str(item.name) end,
            tip = noLines,
            onClick = function()
                item.write(not (item.read() == true))
                acted(column)
            end,
        })
        if color then icon.icon:SetVertexColor(color[1], color[2], color[3]) end
        local border = item.border
        if border then
            icon.borders = {}
            for side = 1, 4 do
                local line = icon:CreateTexture(nil, "OVERLAY")
                line:SetTexture(WHITE)
                line:SetVertexColor(border[1], border[2], border[3])
                if side == 1 then
                    line:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
                    line:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
                    line:SetHeight(1)
                elseif side == 2 then
                    line:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
                    line:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
                    line:SetHeight(1)
                elseif side == 3 then
                    line:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
                    line:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
                    line:SetWidth(1)
                else
                    line:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
                    line:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
                    line:SetWidth(1)
                end
                icon.borders[side] = line
            end
        end
        local c, r = (i - 1) % ICON_PER_ROW, floor((i - 1) / ICON_PER_ROW)
        local inRow = min(ICON_PER_ROW, count - r * ICON_PER_ROW)
        local left = PAD + 2 + (GRID_WIDTH - (inRow * ICON + (inRow - 1) * ICON_GAP)) / 2
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", left + c * (ICON + ICON_GAP), -(top + r * (ICON + ICON_GAP)))
        column.refreshers[#column.refreshers + 1] = function()
            mark(icon, item.read() == true)
        end
    end
    local rows = ceil(count / ICON_PER_ROW)
    return top + rows * (ICON + ICON_GAP) - ICON_GAP + GAP
end

local function buildDropdown(column, group, y)
    local frame = column.Frame
    local titled = title(column, group, y) > 0
    addNote(column, group, y)
    local values = {}
    for i = 1, #group.items do
        values[i] = { key = group.items[i].value, text = group.items[i].text }
    end
    local select = kit("select", frame, {
        width = INNER,
        values = values,
        get = function() return group.read() end,
        onChange = function(_, key)
            group.write(key)
            acted(column)
        end,
    })
    select:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(titled and y - 3 or y))
    local height = select:GetHeight()
    if not height or height < 20 then height = SELECT_HEIGHT end
    column.refreshers[#column.refreshers + 1] = function()
        select:SetValue(group.read())
    end
    return y + height + GAP
end

local function buildSegment(column, group, y)
    local frame = column.Frame
    local offset = title(column, group, y)
    addNote(column, group, y)
    local items = {}
    for i = 1, #group.items do
        local item = group.items[i]
        items[i] = { id = item.value, text = item.text, count = str(item.count) }
    end
    local segment = kit("choice", frame, {
        shape = "segment",
        items = items,
        width = INNER,
        onChange = function(id)
            group.write(id)
            acted(column)
        end,
    })
    segment:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(y + offset))
    local height = segment:GetHeight()
    if not height or height < 10 then height = SEGMENT_HEIGHT end
    column.refreshers[#column.refreshers + 1] = function()
        segment:SetValue(group.read())
        for i = 1, #group.items do
            local item = group.items[i]
            if type(item.count) == "function" then
                segment:SetCount(item.value, item.count())
            end
        end
    end
    return y + offset + height + GAP
end

local function buildReset(column, group, y)
    local button = kit("button", column.Frame, {
        text = group.text,
        width = INNER,
        height = BUTTON_HEIGHT,
        onClick = function() column.Reset() end,
    })
    button:SetPoint("TOPLEFT", column.Frame, "TOPLEFT", PAD, -y)
    column.resetClick = group.onClick
    return y + BUTTON_HEIGHT + GAP
end

local function raiseSiblings(frame, keep, ...)
    local base = frame:GetFrameLevel()
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if child ~= keep and child.GetFrameLevel and child:GetFrameLevel() > base then
            EbonAPI.Bricks.under(child, 12)
        end
    end
end

local function buildEmblem(column, group, y)
    local side = math.min(INNER, (column.Height or HEIGHT) - y - PAD - PAD)
    if side < 48 and group.fallback then
        return buildChecks(column, group.fallback, y)
    end
    local reroll = EbonBuilds.Reroll
    if not reroll or not reroll.IsHunting or not reroll.SetArmed or not reroll.GetArmed then
        return y
    end
    local button = kit("emblem", column.Frame, {
        name = group.name,
        size = side,
        get = reroll.IsHunting,
        onClick = function()
            reroll.SetArmed(not reroll.GetArmed())
            acted(column)
        end,
    })
    local drop = math.max(0, ((column.Height or HEIGHT) - y - side) / 2)
    button:SetPoint("TOPLEFT", column.Frame, "TOPLEFT", (WIDTH - side) / 2, -(y + drop))
    if EbonAPI and EbonAPI.Bricks and EbonAPI.Bricks.under then
        raiseSiblings(column.Frame, button, column.Frame:GetChildren())
    end
    EbonBuilds.Widgets.Tip(button, function(add)
        local L = EbonBuilds.L
        add(reroll.IsHunting() and L.HUNT_EMBLEM_ON or L.HUNT_EMBLEM_OFF, "text")
    end, "ANCHOR_TOP")
    column.refreshers[#column.refreshers + 1] = function()
        button:Refresh()
    end
    return y + side + GAP
end

local BUILDERS = {
    search = buildSearch,
    classes = buildClasses,
    checks = buildChecks,
    icons = buildIcons,
    dropdown = buildDropdown,
    segment = buildSegment,
    reset = buildReset,
    emblem = buildEmblem,
}

function FilterColumn.Create(parent, groups, onChange)
    local column = { onChange = onChange, refreshers = {}, cancels = {}, clears = {} }

    local frame = CreateFrame("Frame", nil, parent)
    local zoneHeight = parent:GetHeight()
    if not zoneHeight or zoneHeight < 100 then zoneHeight = HEIGHT end
    frame:SetSize(WIDTH, zoneHeight)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    column.Frame = frame
    column.Height = zoneHeight

    local function cancelAll()
        for i = 1, #column.cancels do column.cancels[i]() end
    end

    function column.Refresh()
        for i = 1, #column.refreshers do column.refreshers[i]() end
    end

    function column.Reset()
        cancelAll()
        if column.resetClick then column.resetClick() end
        for i = 1, #column.clears do column.clears[i]() end
        column.Refresh()
        notify(column)
    end

    local y = START_Y
    for i = 1, #groups do
        local build = BUILDERS[groups[i].kind]
        if not build then
            error("FilterColumn: unknown group kind " .. tostring(groups[i].kind), 2)
        end
        y = build(column, groups[i], y)
    end

    frame:SetScript("OnHide", cancelAll)
    column.Refresh()
    return column
end
