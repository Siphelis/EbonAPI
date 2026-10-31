EbonAPI = EbonAPI or {}
EbonAPI.QueueTable = EbonAPI.QueueTable or {}

-- The holders table of the Fetch tab: one line per holder (name, requests in flight as pips, keys held,
-- state as a pill, last heard). The lines are a pool sized for the visible part of the table, scrolled
-- by the mouse wheel; a line is repainted only when its values, the skin or the width changed.
-- Line shape by skin: widgets.queue.table.style (line, flat, pill), else derived from the shape of the skin.

local QueueTable = EbonAPI.QueueTable

local format, floor, max, min = string.format, math.floor, math.max, math.min
local pcall, tonumber, tostring, type, ipairs = pcall, tonumber, tostring, type, ipairs

local MARK = "\194\183"
local HEAD_GAP = 6
local PER = 3

local function word(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

local function S(key, fallback)
  local ok, found = pcall(EbonAPI.Skins.value, key)
  if ok and found ~= nil then
    return found
  end

  return fallback
end

local function shapeOf()
  local shape = S("widgets.queue.shape")
  if shape == "square" or shape == "bevel" or shape == "round" then
    return shape
  end

  local ok, corners = pcall(EbonAPI.Parameters.value, nil, "corners")
  if ok and (tonumber(corners) or 0) > 0 then
    return "round"
  end

  return S("border.style") == "TEXTURE" and "bevel" or "square"
end

local function styleOf()
  local style = S("widgets.queue.table.style")
  if style == "line" or style == "flat" or style == "pill" then
    return style
  end

  local shape = shapeOf()

  return shape == "round" and "pill" or (shape == "bevel" and "line" or "flat")
end

-- Whole seconds without a decimal ("12 s"), one decimal only when it is not zero ("7,5 s").
local function secs(n)
  n = floor((tonumber(n) or 0) * 10 + 0.5) / 10
  if n >= 60 then
    return EbonAPI.QueueParts.duration(n)
  end

  local text = format("%.1f", n)
  if text:sub(-2) == ".0" then
    text = text:sub(1, -3)
  end

  local L = EbonAPI.L

  return format(word("QUEUEVIEW_SECONDS"), (text:gsub("%.", (L and L.NUMBER_DECIMAL) or ".")))
end

local function ago(n)
  if (tonumber(n) or 0) < 0.5 then
    return EbonAPI.QueueParts.ago(n)
  end

  return secs(n)
end

local function stateOf(row)
  local QueueParts = EbonAPI.QueueParts
  local muted, slow = tonumber(row.muted), tonumber(row.slow)

  if muted and muted > 0 then
    return "warn", format(word("QUEUEVIEW_STATE_MUTED"), secs(muted))
  end

  if slow and slow > 0 then
    return "accent", format(word("QUEUEVIEW_STATE_SLOW"), secs(slow))
  end

  if row.answered == true or (type(row.answered) == "string" and row.answered ~= "") then
    return "ok", word("QUEUEVIEW_STATE_ANSWERS")
  end

  return nil, word("QUEUEVIEW_STATE_SILENT")
end

local function keysText(keys)
  keys = tonumber(keys) or 0
  if keys <= 0 then
    return MARK
  end

  return format(word(keys == 1 and "QUEUEVIEW_HOLDERS_KEY_ONE" or "QUEUEVIEW_HOLDERS_KEYS_MANY"), EbonAPI.QueueParts.number(keys))
end

local COLUMNS = {
  { id = "peer", label = "QUEUEVIEW_COL_PEER", align = "LEFT" },
  { id = "inflight", label = "QUEUEVIEW_COL_INFLIGHT", align = "LEFT", width = 90 },
  { id = "keys", label = "QUEUEVIEW_HOLDERS_KEYS", align = "RIGHT", width = 80 },
  { id = "state", label = "QUEUEVIEW_COL_STATE", align = "LEFT", width = 130 },
  { id = "heard", label = "QUEUEVIEW_HOLDERS_HEARD", align = "RIGHT", width = 80 },
}

function QueueTable.holders(parent, opts)
  opts = opts or {}

  local QueueParts, Palette, Bricks = EbonAPI.QueueParts, EbonAPI.Palette, EbonAPI.Bricks
  local frame = CreateFrame("Frame", nil, parent)
  local holders = { frame = frame, rows = {}, list = {}, offset = 0, head = {} }
  local rowHeight = tonumber(S("widgets.queue.table.row", 28)) or 28
  local inset = max(6, tonumber(S("kit.inset", 6)) or 6)
  local per = PER
  local solid = S("media.solid", "Interface\\Buttons\\WHITE8X8")

  frame:SetWidth(opts.width or 600)
  frame:SetHeight(opts.height or rowHeight * 9)
  frame:EnableMouseWheel(true)

  local head = holders.head
  for index, column in ipairs(COLUMNS) do
    head[index] = Bricks.text(frame, "small", "muted")
    head[index]:SetText(word(column.label))
    head[index]:SetJustifyH(column.align)
  end

  local rule = frame:CreateTexture(nil, "ARTWORK")
  rule:SetTexture(solid)
  Palette.paint(rule, "SetVertexColor", "borderDim")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -rowHeight)
  rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -rowHeight)

  local empty = Bricks.text(frame, "small", "muted")
  empty:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -rowHeight - 4)
  empty:SetText(MARK)

  local function visible()
    return max(1, floor(((frame:GetHeight() or 0) - rowHeight) / rowHeight))
  end

  local function widths()
    local list, fixed = {}, 0
    for index, column in ipairs(COLUMNS) do
      list[index] = column.width
      fixed = fixed + (column.width or 0)
    end

    list[1] = max(80, (frame:GetWidth() or 0) - fixed - inset * 2 - HEAD_GAP * (#COLUMNS - 1))

    return list
  end

  local function layout()
    local list = widths()
    for index in ipairs(COLUMNS) do
      local x = inset
      for i = 1, index - 1 do
        x = x + list[i] + HEAD_GAP
      end

      head[index]:ClearAllPoints()
      head[index]:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -4)
      head[index]:SetWidth(list[index])
    end

    holders.laidWidth = frame:GetWidth()
    holders.widths = list
    holders.laidStyle = nil

    return list
  end

  local function newRow(index)
    local row = CreateFrame("Frame", nil, frame)
    row:SetHeight(rowHeight - 2)
    row:EnableMouse(true)
    row:EnableMouseWheel(true)
    row.mem = {}

    row.fill = row:CreateTexture(nil, "BACKGROUND")
    row.fill:SetTexture(solid)
    row.fill:SetAllPoints(row)
    row.line = row:CreateTexture(nil, "BORDER")
    row.line:SetTexture(solid)
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.hover = row:CreateTexture(nil, "BORDER")
    row.hover:SetTexture(solid)
    row.hover:SetAllPoints(row)
    row.hover:Hide()

    row.name = Bricks.text(row, "normal", "heading")
    row.name:SetJustifyH("LEFT")
    row.pips = QueueParts.pips(row)
    row.state = QueueParts.pill(row)
    row.keys = Bricks.text(row, "normal", "text")
    row.keys:SetJustifyH("RIGHT")
    row.heard = Bricks.text(row, "small", "muted")
    row.heard:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
      self.hover:Show()
      Palette.paint(self.hover, "SetVertexColor", S("kit.table.hover", "bgSoft"))
      if opts.onEnter and self.peer ~= nil then
        opts.onEnter(self.peer)
      end
    end)
    row:SetScript("OnLeave", function(self)
      self.hover:Hide()
      if opts.onLeave then
        opts.onLeave()
      end
    end)
    row:SetScript("OnMouseWheel", function(_, delta)
      holders:Scroll(delta > 0 and -1 or 1)
    end)

    holders.rows[index] = row

    return row
  end

  local function dress(row, style, index)
    local id = style .. (index % 2)
    if row.dressed == id and row.dressedShape == shapeOf() then
      return
    end

    row.dressed, row.dressedShape = id, shapeOf()
    row.line:Hide()
    row.fill:Hide()
    row:SetBackdrop(nil)
    if style == "line" then
      Palette.paint(row.line, "SetVertexColor", "borderDim")
      row.line:Show()
    elseif style == "flat" then
      if index % 2 == 0 then
        Palette.paint(row.fill, "SetVertexColor", "bgSoft")
        row.fill:Show()
      end
    else
      local radius = max(3, min(8, tonumber(S("widgets.queue.radius")) or 6))
      row:SetBackdrop({ bgFile = solid, edgeFile = S("media.rounded", solid), edgeSize = radius,
        insets = { left = floor(radius / 4), right = floor(radius / 4), top = floor(radius / 4), bottom = floor(radius / 4) } })
      local color = EbonAPI.Palette.THEME.card or EbonAPI.Palette.THEME.bgSoft
      row:SetBackdropColor(color[1], color[2], color[3], 0.6)
      local edge = EbonAPI.Palette.THEME.borderDim or color
      row:SetBackdropBorderColor(edge[1], edge[2], edge[3], 0.6)
    end
  end

  local function paint(row, data, index, style, list)
    local mem = row.mem
    local level, text = stateOf(data)
    local inflight = max(0, tonumber(data.inflight) or 0)
    local heard = tonumber(data.heard)
    local peer = data.peer ~= nil and tostring(data.peer) or ""
    local keys = tonumber(data.keys) or 0

    row.peer = data.peer
    dress(row, style, index)

    if mem.peer ~= peer or mem.list ~= list then
      mem.peer = peer
      row.name:SetText(peer)
    end

    if mem.inflight ~= inflight or mem.style ~= style then
      mem.inflight = inflight
      row.pips:Set(max(0, per - inflight), max(per, inflight), "EbonAPI")
    end

    if mem.keys ~= keys then
      mem.keys = keys
      row.keys:SetText(keysText(keys))
    end

    if mem.text ~= text or mem.level ~= level then
      mem.text, mem.level = text, level
      row.state:Set(text, level)
    end

    local heardKey = heard and floor(heard * 10) or false
    if mem.heard ~= heardKey then
      mem.heard = heardKey
      row.heard:SetText(heard and ago(heard) or MARK)
    end

    if mem.list ~= list or mem.style ~= style then
      mem.list, mem.style = list, style
      for i, target in ipairs({ row.name, row.pips:Frame(), row.keys, row.state:Frame(), row.heard }) do
        local x = inset
        for j = 1, i - 1 do
          x = x + list[j] + HEAD_GAP
        end

        target:ClearAllPoints()
        target:SetPoint("LEFT", row, "LEFT", x, 0)
        if i ~= 2 and i ~= 4 then
          target:SetWidth(list[i])
        end
      end
    end
  end

  function holders:Redraw()
    local list = (holders.widths and holders.laidWidth == frame:GetWidth()) and holders.widths or layout()
    local style = styleOf()
    local total = #holders.list
    local shown = visible()
    holders.offset = max(0, min(holders.offset, total - shown))

    for slot = 1, min(shown, total) do
      local row = holders.rows[slot] or newRow(slot)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -rowHeight - 1 - (slot - 1) * rowHeight)
      row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -rowHeight - 1 - (slot - 1) * rowHeight)
      row:Show()
      paint(row, holders.list[holders.offset + slot], holders.offset + slot, style, list)
    end

    for slot = min(shown, total) + 1, #holders.rows do
      holders.rows[slot]:Hide()
    end

    if total == 0 then
      empty:Show()
    else
      empty:Hide()
    end
  end

  function holders:Scroll(step)
    local before = holders.offset
    holders.offset = max(0, min(holders.offset + step, #holders.list - visible()))
    if holders.offset ~= before then
      holders:Redraw()
    end
  end

  function holders:SetHolders(list)
    list = type(list) == "table" and list or {}
    holders.list = list
    holders:Redraw()
  end

  function holders:Frame()
    return frame
  end

  frame:SetScript("OnMouseWheel", function(_, delta)
    holders:Scroll(delta > 0 and -1 or 1)
  end)

  return holders
end
