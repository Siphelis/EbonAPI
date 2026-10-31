EbonAPI = EbonAPI or {}
EbonAPI.QueueStrips = EbonAPI.QueueStrips or {}

-- The strips of the send queue window. activity: the Recent sends tab, one row per recipient with a strip of
-- 30 cells (10 s each, the last one is the current slice). Rows are a pool sized by the view, repainted only
-- when a value changed.

local QueueStrips = EbonAPI.QueueStrips
local QueueParts = EbonAPI.QueueParts
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Bricks = EbonAPI.Bricks

local format, floor, ceil, max, min = string.format, math.floor, math.ceil, math.max, math.min
local pcall, tonumber, tostring, type, ipairs, sort = pcall, tonumber, tostring, type, ipairs, table.sort

local THEME = Palette.THEME
local CELLS = 30
local SLICE = 10
local RANGE_SCALE = 120
local ALL = 0
local COLUMNS = {
  { id = "who", key = "QUEUEVIEW_COL_WHO", width = 150 },
  { id = "strip", key = "QUEUEVIEW_STRIP_BAND" },
  { id = "waiting", key = "QUEUEVIEW_COL_WAITING", width = 78, right = true },
  { id = "sent", key = "QUEUEVIEW_COL_SENT", width = 70, right = true },
  { id = "avg", key = "QUEUEVIEW_STRIP_AVG", width = 140 },
  { id = "last", key = "QUEUEVIEW_STRIP_LAST", width = 70, right = true },
}

local function word(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

local function value(key, fallback)
  local ok, found = pcall(Skins.value, key)
  if ok and found ~= nil then
    return found
  end

  return fallback
end

local function num(n)
  n = tonumber(n)
  if not n or n ~= n or n == math.huge or n == -math.huge then
    return 0
  end

  return n
end

local function hue(key)
  local color = THEME[key] or THEME.text

  return color[1] + color[2] * 1000 + color[3] * 1000000
end

local function tint(target, method, key, alpha)
  local color = THEME[key] or THEME.text
  target[method](target, color[1], color[2], color[3], alpha or 1)
end

local function opacity(v)
  v = num(v)
  if v <= 0 then
    return 0.08
  end

  return min(1, 0.18 + v / 90 * 0.82)
end

QueueStrips.opacity = opacity

local function sliceTip(i, n)
  local label = i >= CELLS and word("QUEUEVIEW_STRIP_NOW") or format(word("QUEUEVIEW_STRIP_AGO"), (CELLS - i) * SLICE < 60 and format(word("QUEUEVIEW_SECONDS"), QueueParts.number((CELLS - i) * SLICE)) or QueueParts.duration((CELLS - i) * SLICE))
  n = floor(num(n) + 0.5)

  return format(word(n >= 2 and "QUEUEVIEW_STRIP_TIP" or "QUEUEVIEW_STRIP_TIP_ONE"), label, n)
end

QueueStrips.sliceTip = sliceTip

local function hasSend(bins)
  if type(bins) ~= "table" then
    return false
  end

  for i = 1, CELLS do
    if num(bins[i]) > 0 then
      return true
    end
  end

  return false
end

local function sortValue(d, id)
  if id == "who" then
    return string.lower(tostring(d.who or ""))
  end

  return num(d[id])
end

local function newRow(self)
  local row = CreateFrame("Button", nil, self.scroll.child)
  local inset = value("kit.inset", 6)

  row:SetHeight(self.rowHeight)
  row.fill = row:CreateTexture(nil, "BACKGROUND")
  row.fill:SetTexture(Bricks.media("solid"))
  row.fill:SetAllPoints(row)
  row.fill:Hide()
  row.dot = QueueParts.dot(row)
  row.dot:Frame():SetPoint("LEFT", row, "LEFT", inset, 0)
  row.name = Bricks.text(row, "small", "text")
  row.name:SetHeight(self.rowHeight)
  if row.name.SetWordWrap then
    row.name:SetWordWrap(false)
  end

  row.name:SetJustifyH("LEFT")
  row.cells = {}
  for i = 1, CELLS do
    local cell = row:CreateTexture(nil, "ARTWORK")

    cell:SetTexture(Bricks.media("solid"))
    row.cells[i] = cell
  end

  row.vals = {}
  row.pill = QueueParts.pill(row)
  row.zero = Bricks.text(row, "small", "muted")
  row.zero:SetText("·")
  row.sent = Bricks.text(row, "small", "text")
  row.sent:SetJustifyH("RIGHT")
  row.span = Bricks.text(row, "small", "muted")
  row.span:SetJustifyH("LEFT")
  row.range = QueueParts.range(row)
  row.last = Bricks.text(row, "small", "muted")
  row.last:SetJustifyH("RIGHT")
  row.cache = {}
  row:EnableMouse(true)
  row:SetScript("OnEnter", function(r)
    r.hovered = true
    tint(r.fill, "SetVertexColor", value("kit.table.hover", "rowHover"))
    r.fill:Show()
    if self.opts.onEnter and r.who ~= nil then
      pcall(self.opts.onEnter, r.who)
    end

    r:SetScript("OnUpdate", function(rr)
      self:HoverCell(rr)
    end)
  end)
  row:SetScript("OnLeave", function(r)
    r.hovered = false
    r.hoverCell = nil
    r.fill:Hide()
    r:SetScript("OnUpdate", nil)
    Bricks.hideTip()
    if self.opts.onLeave then
      pcall(self.opts.onLeave)
    end
  end)

  return row
end

local function place(row, self)
  local x = self.cols
  local inset = value("kit.inset", 6)

  row:SetWidth(self.total)
  row.name:ClearAllPoints()
  row.name:SetPoint("LEFT", row, "LEFT", inset + 14, 0)
  row.name:SetWidth(max(1, x[1] - inset * 2 - 14))
  for i = 1, CELLS do
    local cell = row.cells[i]

    cell:ClearAllPoints()
    cell:SetPoint("LEFT", row, "LEFT", x[1] + inset + (i - 1) * (self.cellWidth + self.gap), 0)
    cell:SetWidth(self.cellWidth)
    cell:SetHeight(self.cellHeight)
  end

  row.pill:Frame():ClearAllPoints()
  row.pill:Frame():SetPoint("RIGHT", row, "LEFT", x[3] - inset, 0)
  row.zero:ClearAllPoints()
  row.zero:SetPoint("RIGHT", row, "LEFT", x[3] - inset, 0)
  row.sent:ClearAllPoints()
  row.sent:SetPoint("RIGHT", row, "LEFT", x[4] - inset, 0)
  row.span:ClearAllPoints()
  row.span:SetPoint("TOPLEFT", row, "TOPLEFT", x[4] + inset, -3)
  row.range:Frame():SetWidth(max(20, self.avgWidth - inset * 2))
  row.range:Frame():ClearAllPoints()
  row.range:Frame():SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x[4] + inset, 3)
  row.last:ClearAllPoints()
  row.last:SetPoint("RIGHT", row, "LEFT", x[6] - inset, 0)
  row.geo = self.geo
  row.cache.avg = nil
end

local function bind(self, row, d, index)
  local geo, shape = self.geo, self.shape

  if row.geo ~= geo then
    place(row, self)
    row.pos = nil
    row.shape = nil
  end

  if row.pos ~= index then
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, -(index - 1) * self.rowHeight)
    row.pos = index
  end

  local c = row.cache
  local changed = false
  local lane = d.lane
  local key = QueueParts.laneColor(lane)
  local color = hue(key)
  local waiting = floor(num(d.waiting) + 0.5)
  local sent = floor(num(d.sent) + 0.5)
  local ago = QueueParts.ago(num(d.last))
  local avg, maximum = num(d.avg), num(d.max)

  if row.who ~= d.who then
    row.who = d.who
    row.name:SetText(tostring(d.who or ""))
    changed = true
  end

  row.dot:Set(lane)
  if row.shape ~= shape then
    row.shape = shape
    local texture = shape == "round" and value("media.circle", "Interface\\AddOns\\EbonAPI\\Media\\Circle") or Bricks.media("solid")
    for i = 1, CELLS do
      row.cells[i]:SetTexture(texture)
      row.vals[i] = nil
    end

    changed = true
  end

  local bins = d.bins
  local source = type(bins) == "table" and bins or nil
  local recolor = c.hue ~= color
  for i = 1, CELLS do
    local v = source and num(source[i]) or 0
    if recolor or row.vals[i] ~= v then
      row.vals[i] = v
      tint(row.cells[i], "SetVertexColor", key, opacity(v))
      changed = true
    end
  end

  c.hue = color
  if c.waiting ~= waiting then
    c.waiting = waiting
    if waiting > 0 then
      row.pill:Set(QueueParts.number(waiting), "accent")
      row.pill:Frame():Show()
      row.zero:Hide()
    else
      row.pill:Frame():Hide()
      row.zero:Show()
    end

    changed = true
  end

  if c.sent ~= sent then
    c.sent = sent
    row.sent:SetText(QueueParts.number(sent))
    changed = true
  end

  if c.avg ~= avg or c.max ~= maximum then
    c.avg, c.max = avg, maximum
    row.span:SetText(QueueParts.span(avg, maximum))
    row.range:Set(avg, maximum, RANGE_SCALE)
    changed = true
  end

  if c.ago ~= ago then
    c.ago = ago
    row.last:SetText(ago)
    changed = true
  end

  row.data = d
  row:Show()
  if changed then
    self.repaints = self.repaints + 1
  end
end

local function arrangeHeaders(self)
  local x = 0

  for i, column in ipairs(COLUMNS) do
    local header = self.headers[i]
    local w = self.cols[i] - x

    header:SetWidth(w)
    header:SetHeight(self.headHeight)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", self.head, "TOPLEFT", x, 0)
    header:SetLabel(word(column.key))
    x = x + w
  end
end

local function sorting(self)
  for i, column in ipairs(COLUMNS) do
    local arrow = self.headers[i].sort

    if self.sortId == column.id then
      Bricks.turn(arrow, self.sortDesc and "DOWN" or "UP")
      arrow:Show()
    else
      arrow:Hide()
    end
  end
end

function QueueStrips.activity(parent, opts)
  opts = opts or {}
  local frame = CreateFrame("Frame", nil, parent)
  local inset = value("kit.inset", 6)
  local arrow = value("kit.table.sort", 8)

  frame.opts = opts
  frame.rowHeight = 28
  frame.headHeight = 22
  frame.gap = 1
  frame.cellHeight = 14
  frame.pool = {}
  frame.list = {}
  frame.all = {}
  frame.counts = {}
  frame.repaints = 0
  frame.sortId, frame.sortDesc = "last", false
  frame.shape = "square"
  frame.geo = 0
  frame.total, frame.cellWidth, frame.avgWidth = 0, 4, 140
  frame.cols = { 150, 150, 228, 298, 438, 508 }

  frame.chips = QueueParts.chips(frame)
  frame.chips:Frame():SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.count = Bricks.text(frame, "small", "muted")
  frame.count:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -4)
  frame.head = CreateFrame("Frame", nil, frame)
  frame.head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -28)
  frame.head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -28)
  frame.head:SetHeight(frame.headHeight)
  frame.rule = frame:CreateTexture(nil, "ARTWORK")
  frame.rule:SetTexture(Bricks.media("solid"))
  frame.rule:SetHeight(1)
  frame.rule:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, 0)
  frame.rule:SetPoint("TOPRIGHT", frame.head, "BOTTOMRIGHT", 0, 0)
  Palette.paint(frame.rule, "SetVertexColor", "borderDim")
  frame.scroll = Bricks.create("scroll", frame)
  frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(28 + frame.headHeight + 1))
  frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  frame.empty = Bricks.text(frame, "normal", "muted")
  frame.empty:SetPoint("CENTER", frame.scroll, "CENTER", 0, 0)
  frame.empty:SetText(word("QUEUEVIEW_STRIP_EMPTY"))
  frame.empty:Hide()
  frame.headers = {}

  for i, column in ipairs(COLUMNS) do
    local header = Bricks.flatButton(frame.head)

    header.label:ClearAllPoints()
    header.label:SetPoint("LEFT", header, "LEFT", inset, 0)
    header.label:SetPoint("RIGHT", header, "RIGHT", -(arrow + inset * 2), 0)
    header.label:SetJustifyH(column.right and "RIGHT" or "LEFT")
    header.sort = header:CreateTexture(nil, "OVERLAY")
    header.sort:SetTexture(Bricks.media("chevron"))
    header.sort:SetWidth(arrow)
    header.sort:SetHeight(arrow)
    header.sort:SetPoint("RIGHT", header, "RIGHT", -inset, 0)
    Palette.paint(header.sort, "SetVertexColor", "muted")
    header.sort:Hide()
    header.onClick = function()
      if column.id ~= "strip" then
        frame:SortBy(column.id)
      end
    end

    frame.headers[i] = header
  end

  function frame:Frame()
    return self
  end

  function frame:Geometry()
    local width = self:GetWidth() or 0
    if width <= 0 then
      width = 700
    end

    local bar = value("widgets.scroll.width", 8)
    local total = max(300, floor(width - bar))
    local fixed = 0
    for _, column in ipairs(COLUMNS) do
      fixed = fixed + (column.width or 0)
    end

    local strip = min(CELLS * 16, max(CELLS * 3, total - fixed))
    local shape = value("widgets.strip.shape", "bevel")
    shape = shape == "round" and "round" or "square"
    local gap = shape == "round" and 1 or self.gap
    local cell = max(2, floor((strip - (CELLS - 1) * gap) / CELLS))
    local stripWidth = cell * CELLS + (CELLS - 1) * gap
    local x1 = COLUMNS[1].width
    local x2 = x1 + stripWidth + inset * 2
    local x3 = x2 + COLUMNS[3].width
    local x4 = x3 + COLUMNS[4].width
    local x5 = x4 + COLUMNS[5].width
    local x6 = x5 + COLUMNS[6].width
    local stamp = total .. "|" .. cell .. "|" .. shape .. "|" .. x2
    if self.stamp == stamp then
      return false
    end

    self.stamp = stamp
    self.total, self.cellWidth, self.shape, self.gap = total, cell, shape, gap
    self.avgWidth = COLUMNS[5].width
    self.cols = { x1, x2, x3, x4, x5, x6 }
    self.geo = self.geo + 1

    return true
  end

  function frame:Visible()
    local height = (self:GetHeight() or 0) - 28 - self.headHeight - 1

    if height <= 0 then
      height = 20 * self.rowHeight
    end

    return height
  end

  function frame:Paint()
    local list = self.list
    local offset = floor(max(0, num(self.scroll:GetVerticalScroll())) / self.rowHeight)
    local need = min(#list, ceil(self:Visible() / self.rowHeight) + 2)

    for i = 1, need do
      if not self.pool[i] then
        self.pool[i] = newRow(self)
      end
    end

    for i = 1, #self.pool do
      local row = self.pool[i]
      local index = offset + i
      local d = i <= need and list[index] or nil

      if d then
        bind(self, row, d, index)
      else
        if row.hovered then
          row.hovered = false
          Bricks.hideTip()
        end

        row:Hide()
        row.who, row.pos = nil, nil
      end
    end
  end

  function frame:Layout()
    local moved = self:Geometry()

    if moved then
      arrangeHeaders(self)
    end

    self.scroll:SetView(self.total, self:Visible())

    return moved
  end

  function frame:SetDests(dests)
    local all = self.all
    local list = self.list
    local total = 0
    local counts = {}
    local order = {}

    for i = #all, 1, -1 do
      all[i] = nil
    end

    for i = #list, 1, -1 do
      list[i] = nil
    end

    for _, d in ipairs(dests or {}) do
      total = total + 1
      if hasSend(d.bins) then
        all[#all + 1] = d
        if d.lane ~= nil then
          if not counts[d.lane] then
            counts[d.lane] = 0
            order[#order + 1] = d.lane
          end

          counts[d.lane] = counts[d.lane] + 1
        end
      end
    end

    local pick = self.lane
    if pick ~= nil and not counts[pick] then
      pick = nil
      self.lane = nil
    end

    for _, d in ipairs(all) do
      if pick == nil or d.lane == pick then
        list[#list + 1] = d
      end
    end

    local id, descending = self.sortId, self.sortDesc
    local rank = {}
    for i, d in ipairs(list) do
      rank[d] = i
    end

    sort(list, function(a, b)
      local x, y = sortValue(a, id), sortValue(b, id)
      if descending then
        x, y = y, x
      end

      if x ~= y then
        return x < y
      end

      local lx, ly = num(a.last), num(b.last)
      if lx ~= ly then
        return lx < ly
      end

      return rank[a] < rank[b]
    end)

    sort(order)
    local items = { { key = ALL, label = word("QUEUEVIEW_STRIP_ALL"), count = #all } }
    for _, lane in ipairs(order) do
      items[#items + 1] = { key = lane, label = tostring(lane), count = counts[lane], laneKey = lane }
    end

    self.chips:Set(items, pick == nil and ALL or pick, self.onPick)
    self.last = dests

    local mark = #list .. "/" .. total
    if self.mark ~= mark then
      self.mark = mark
      self.count:SetText(format(word("QUEUEVIEW_STRIP_COUNT"), #list, total))
    end

    self:Layout()
    sorting(self)
    if #list == 0 then
      self.empty:Show()
    else
      self.empty:Hide()
    end

    self.scroll:SetContentHeight(#list * self.rowHeight)
    self:Paint()

    return self
  end

  function frame.onPick(key)
    frame.lane = (key ~= ALL and key ~= frame.lane) and key or nil
    if frame.opts.onLane then
      pcall(frame.opts.onLane, frame.lane)
    end

    if frame.last then
      frame:SetDests(frame.last)
    end
  end

  function frame:SortBy(id)
    if self.sortId == id then
      self.sortDesc = not self.sortDesc
    else
      self.sortId, self.sortDesc = id, false
    end

    if self.last then
      self:SetDests(self.last)
    end

    return self
  end

  function frame:CellTip(row, i)
    local d = row.data
    local bins = d and d.bins

    return sliceTip(i, type(bins) == "table" and bins[i] or 0)
  end

  function frame:HoverCell(row)
    local x = GetCursorPosition and GetCursorPosition()
    local left = row:GetLeft()
    local scale = row:GetEffectiveScale()

    if not x or not left or not scale or scale == 0 then
      return
    end

    local offset = x / scale - left - self.cols[1] - inset
    local step = self.cellWidth + self.gap
    local i = floor(offset / step) + 1

    if offset < 0 or i < 1 or i > CELLS then
      if row.hoverCell then
        row.hoverCell = nil
        Bricks.hideTip()
      end

      return
    end

    if row.hoverCell ~= i then
      row.hoverCell = i
      Bricks.tip(row, self:CellTip(row, i))
    end
  end

  frame.scroll:HookScript("OnVerticalScroll", function()
    if frame.list[1] then
      frame:Paint()
    end
  end)
  frame:SetScript("OnSizeChanged", function(self)
    if self.last and self:Layout() then
      self:Paint()
    end
  end)

  return frame
end
