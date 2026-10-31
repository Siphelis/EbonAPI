EbonAPI = EbonAPI or {}
EbonAPI.QueueTable = EbonAPI.QueueTable or {}

-- The registry tables of the send queue window. `people` is the Recipients tab: one row per recipient,
-- drawn with the QueueParts pieces. It follows the conventions of the Kit table (kit.table.*: row
-- height, sort arrow, hover) but draws its own table: its cells are not only text, and the rows are a
-- virtual list (a pool of frames for the visible rows, rebound on scroll, repainted only when changed).

local QueueTable = EbonAPI.QueueTable
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Parameters = EbonAPI.Parameters
local Bricks = EbonAPI.Bricks

local format, lower, tostring, tonumber, type, ipairs, pcall = string.format, string.lower, tostring, tonumber, type, ipairs, pcall
local floor, ceil, max, min, huge = math.floor, math.ceil, math.max, math.min, math.huge
local sort, select = table.sort, select

local THEME = Palette.THEME
local DOT = "\194\183"
local AVG_SCALE = 120

local COLUMNS = {
  { id = "who", key = "QUEUEVIEW_COL_WHO", min = 96, weight = 2 },
  { id = "lane", key = "QUEUEVIEW_COL_LANE", min = 100, weight = 2, nosort = true },
  { id = "waiting", key = "QUEUEVIEW_COL_WAITING", min = 64, right = true },
  { id = "queued", key = "QUEUEVIEW_COL_QUEUED", min = 72, right = true },
  { id = "sent", key = "QUEUEVIEW_COL_SENT", min = 130, weight = 3 },
  { id = "failed", key = "QUEUEVIEW_COL_FAILED", min = 52, right = true },
  { id = "avg", key = "QUEUEVIEW_COL_AVGMAX", min = 120, weight = 2 },
  { id = "last", key = "QUEUEVIEW_COL_LASTSHORT", min = 64, right = true },
}

local function S(key, fallback)
  local ok, found = pcall(Skins.value, key)
  if ok and found ~= nil then
    return found
  end

  return fallback
end

local function word(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

local function parts()
  return EbonAPI.QueueParts
end

local function number(n)
  n = tonumber(n)
  if not n or n ~= n or n == huge or n == -huge then
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

local function differs(mem, ...)
  local changed = false

  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if mem[i] ~= v then
      mem[i] = v
      changed = true
    end
  end

  return changed
end

local function shapeOf()
  local ok, corners = pcall(Parameters.value, nil, "corners")
  local round = ok and tonumber(corners) or 0
  local shape = S("widgets.queue.shape")
  if shape ~= "square" and shape ~= "bevel" and shape ~= "round" then
    shape = round > 0 and "round" or (S("border.style") == "TEXTURE" and "bevel" or "square")
  end

  local radius = tonumber(S("widgets.queue.radius")) or (shape == "round" and max(3, min(round, 8)) or 0)

  return shape, max(0, radius)
end

local FROM_SHAPE = { bevel = "line", round = "pill", square = "plain" }
local STYLES = { line = true, plain = true, pill = true, card = true, zebra = true }

local function styleOf()
  local shape, radius = shapeOf()
  local style = S("widgets.queue.table.style")
  if not STYLES[style] then
    style = FROM_SHAPE[shape]
  end

  local gap = tonumber(S("widgets.queue.table.gap")) or ((style == "pill" or style == "card") and 2 or 0)

  return style, max(0, gap), radius
end

local backdrops = {}

local function backdropOf(style, radius)
  local id = style .. radius
  local backdrop = backdrops[id]
  if not backdrop then
    local solid = S("media.solid", "Interface\\Buttons\\WHITE8X8")
    if style == "pill" then
      local edge = max(4, radius)
      local inset = floor(edge * 0.25)
      backdrop = { bgFile = solid, edgeFile = S("media.rounded", solid), edgeSize = edge,
        insets = { left = inset, right = inset, top = inset, bottom = inset } }
    else
      backdrop = { bgFile = solid, edgeFile = solid, edgeSize = 1 }
    end

    backdrops[id] = backdrop
  end

  return backdrop
end

local function compare(a, b, id)
  if id == "who" then
    return lower(tostring(a.who or "")), lower(tostring(b.who or ""))
  elseif id == "last" then
    return a.last ~= nil and number(a.last) or huge, b.last ~= nil and number(b.last) or huge
  elseif id == "avg" then
    return number(a.avg), number(b.avg)
  end

  return number(a[id]), number(b[id])
end

local function tipText(data)
  local queued, sent, waiting = number(data.queued), number(data.sent), number(data.waiting)
  local Q = parts()
  local text = format(word("QUEUEVIEW_TIP_PEOPLE"), Q.number(queued), Q.number(sent))
  local gap = queued - sent - waiting
  if gap > 0 then
    text = text .. "\n" .. format(word("QUEUEVIEW_TIP_GAP"), Q.number(gap))
  end

  return text
end

local function newRow(frame)
  local row = CreateFrame("Button", nil, frame.scroll.child)
  local Q = parts()
  row.fill = row:CreateTexture(nil, "BACKGROUND")
  row.fill:SetTexture(S("media.solid", "Interface\\Buttons\\WHITE8X8"))
  row.fill:SetAllPoints(row)
  row.fill:Hide()
  row.line = row:CreateTexture(nil, "BORDER")
  row.line:SetTexture(S("media.solid", "Interface\\Buttons\\WHITE8X8"))
  row.line:SetHeight(1)
  row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
  row.line:Hide()
  row.mem, row.look = {}, {}
  row.who = Bricks.text(row, "button", "text")
  row.laneDot = Q.dot(row)
  row.laneText = Bricks.text(row, "small", "muted")
  row.pill = Q.pill(row)
  row.zero = Bricks.text(row, "small", "muted")
  row.queued = Bricks.text(row, "small", "muted")
  row.bar = Q.bar(row)
  row.sent = Bricks.text(row, "small", "text")
  row.failed = Bricks.text(row, "small", "muted")
  row.avg = Bricks.text(row, "small", "muted")
  row.range = Q.range(row)
  row.last = Bricks.text(row, "small", "muted")
  row.zero:SetText(DOT)
  row:RegisterForClicks("LeftButtonUp")
  row:SetScript("OnEnter", function(self)
    self.hovered = true
    frame:PaintHover(self)

    local data = self.data
    if data then
      Bricks.tip(self, tostring(data.who or ""), tipText(data))

      if frame.onEnter then
        pcall(frame.onEnter, data.who)
      end
    end
  end)
  row:SetScript("OnLeave", function(self)
    self.hovered = false
    frame:PaintHover(self)
    Bricks.hideTip()

    if frame.onLeave then
      pcall(frame.onLeave)
    end
  end)

  return row
end

function QueueTable.people(parent, opts)
  opts = opts or {}
  local Q = parts()
  local frame = CreateFrame("Frame", nil, parent)
  local inset = tonumber(S("kit.inset", 4)) or 4
  local arrow = tonumber(S("kit.table.sort", 8)) or 8
  local headH = tonumber(S("kit.table.row", 18)) or 18
  local toolH = 24

  frame.onEnter, frame.onLeave = opts.onEnter, opts.onLeave
  frame.dests, frame.list, frame.order = {}, {}, {}
  frame.rank = {}
  frame.sortId, frame.sortDesc = "waiting", true
  frame.lane = nil
  frame.pool, frame.headers, frame.sizes, frame.xs = {}, {}, {}, {}
  frame.mem, frame.paints, frame.layoutId = {}, 0, 0
  frame:SetWidth(opts.width or (parent.GetWidth and parent:GetWidth()) or 760)
  frame:SetHeight(opts.height or 320)

  frame.tool = CreateFrame("Frame", nil, frame)
  frame.tool:SetHeight(toolH)
  frame.tool:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.tool:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.toolLabel = Bricks.text(frame.tool, "small", "muted")
  frame.toolLabel:SetPoint("LEFT", frame.tool, "LEFT", inset, 0)
  frame.chips = Q.chips(frame.tool)
  frame.chips:Frame():SetPoint("LEFT", frame.toolLabel, "RIGHT", 8, 0)
  frame.count = Bricks.text(frame.tool, "small", "muted")
  frame.count:SetPoint("RIGHT", frame.tool, "RIGHT", -inset, 0)
  frame.count:SetJustifyH("RIGHT")

  frame.head = CreateFrame("Frame", nil, frame)
  frame.head:SetHeight(headH)
  frame.head:SetPoint("TOPLEFT", frame.tool, "BOTTOMLEFT", 0, 0)
  frame.head:SetPoint("TOPRIGHT", frame.tool, "BOTTOMRIGHT", 0, 0)
  frame.rule = frame:CreateTexture(nil, "ARTWORK")
  frame.rule:SetTexture(Bricks.media("solid"))
  frame.rule:SetHeight(1)
  frame.rule:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, 0)
  frame.rule:SetPoint("TOPRIGHT", frame.head, "BOTTOMRIGHT", 0, 0)
  Palette.paint(frame.rule, "SetVertexColor", "borderDim")
  frame.scroll = Bricks.create("scroll", frame)
  frame.scroll:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, -1)
  frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  for index, column in ipairs(COLUMNS) do
    local header = Bricks.flatButton(frame.head)
    header.label:ClearAllPoints()
    header.label:SetPoint("LEFT", header, "LEFT", inset, 0)
    header.label:SetPoint("RIGHT", header, "RIGHT", -inset, 0)
    header.label:SetJustifyH(column.right and "RIGHT" or "LEFT")
    header.sort = header:CreateTexture(nil, "OVERLAY")
    header.sort:SetTexture(Bricks.media("chevron"))
    header.sort:SetWidth(arrow)
    header.sort:SetHeight(arrow)
    Palette.paint(header.sort, "SetVertexColor", "muted")
    header.sort:Hide()
    header.onClick = function()
      if not column.nosort then
        frame:SortBy(column.id)
      end
    end
    frame.headers[index] = header
  end

  local function rowStride()
    return (tonumber(S("widgets.queue.table.row", 28)) or 28) + select(2, styleOf())
  end

  local function skinSig()
    local style, gap, radius = styleOf()

    return style .. gap .. radius .. hue("text") .. hue("muted") .. hue("danger") .. hue("borderDim") .. hue("card") .. hue("rowHover") .. hue("heading")
  end

  function frame:Relayout()
    local width = self:GetWidth() or 0
    local height = self:GetHeight() or 0
    local total = max(1, width - (tonumber(S("widgets.scroll.width", 6)) or 6) - (tonumber(S("kit.gap", 2)) or 2))
    local sizes, need, sum = {}, {}, 0

    for index, column in ipairs(COLUMNS) do
      local header = self.headers[index]
      header:SetLabel(word(column.key))
      local label = ceil(header.label:GetStringWidth() or 0)
      column.label = label
      need[index] = label + arrow + 3 + inset * 2
      sizes[index] = max(column.min, need[index])
      sum = sum + sizes[index]
    end

    if sum < total then
      local weights = 0
      for _, column in ipairs(COLUMNS) do
        weights = weights + (column.weight or 0)
      end

      local extra, given, last = total - sum, 0, nil
      for index, column in ipairs(COLUMNS) do
        if column.weight then
          local share = floor(extra * column.weight / weights)
          sizes[index] = sizes[index] + share
          given, last = given + share, index
        end
      end

      sizes[last] = sizes[last] + (extra - given)
    elseif sum > total then
      local deficit = sum - total
      for index = #COLUMNS, 1, -1 do
        local cut = min(deficit, sizes[index] - need[index])
        sizes[index], deficit = sizes[index] - cut, deficit - cut
        if deficit <= 0 then
          break
        end
      end
    end

    local x = 0
    for index, column in ipairs(COLUMNS) do
      local header = self.headers[index]
      self.sizes[index], self.xs[index] = sizes[index], x
      header:SetWidth(sizes[index])
      header:SetHeight(headH)
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", self.head, "TOPLEFT", x, 0)
      header.sort:ClearAllPoints()
      if column.right then
        header.sort:SetPoint("RIGHT", header, "RIGHT", -(inset + column.label + 3), 0)
      else
        header.sort:SetPoint("LEFT", header, "LEFT", inset + column.label + 3, 0)
      end

      x = x + sizes[index]
    end

    self.total, self.viewHeight = total, max(1, height - toolH - headH - 1)
    self.layoutId = self.layoutId + 1
    self.stride = rowStride()
    self.scroll:SetView(total, self.viewHeight)
    self.mem.size = width .. "x" .. height
  end

  function frame:SortBy(id)
    for _, column in ipairs(COLUMNS) do
      if column.id == id and not column.nosort then
        if self.sortId == id then
          self.sortDesc = not self.sortDesc
        else
          self.sortId, self.sortDesc = id, id ~= "who"
        end

        self:Rebuild()

        return self
      end
    end

    return self
  end

  function frame:Rebuild()
    local list, order, dests = self.list, self.order, self.dests
    local id, desc, lane = self.sortId, self.sortDesc, self.lane
    local n = 0

    for i = 1, #list do
      list[i] = nil
    end

    for i = 1, #dests do
      local data = dests[i]
      if type(data) == "table" and (lane == nil or data.lane == lane) then
        n = n + 1
        list[n] = data
        order[data] = n
      end
    end

    sort(list, function(a, b)
      local x, y = compare(a, b, id)
      if x ~= y then
        if desc then
          return x > y
        end

        return x < y
      end

      local sa, sb = number(a.sent), number(b.sent)
      if sa ~= sb then
        return sa > sb
      end

      return order[a] < order[b]
    end)

    local rank = self.rank
    for key in pairs(rank) do
      rank[key] = nil
    end

    for i = 1, n do
      rank[list[i]] = i
    end

    self.count:SetText(format(word(n == 1 and "QUEUEVIEW_PEOPLE_ONE" or "QUEUEVIEW_PEOPLE_COUNT"), Q.number(n)))
    self:Paint()
  end

  function frame:PaintHover(row)
    if row.hovered then
      tint(row.fill, "SetVertexColor", "rowHover", 1)
      row.fill:Show()
    elseif row.look.zebra then
      tint(row.fill, "SetVertexColor", "borderDim", 0.15)
      row.fill:Show()
    else
      row.fill:Hide()
    end
  end

  local function layoutRow(row)
    local s, xs = frame.sizes, frame.xs
    local function right(cell, i)
      cell:ClearAllPoints()
      cell:SetPoint("LEFT", row, "LEFT", xs[i] + inset, 0)
      cell:SetWidth(max(1, s[i] - inset * 2))
      cell:SetHeight(14)
      cell:SetJustifyH("RIGHT")
    end

    row.who:ClearAllPoints()
    row.who:SetPoint("LEFT", row, "LEFT", xs[1] + inset, 0)
    row.who:SetWidth(max(1, s[1] - inset * 2))
    row.who:SetHeight(14)
    row.who:SetJustifyH("LEFT")
    row.laneDot:Frame():ClearAllPoints()
    row.laneDot:Frame():SetPoint("LEFT", row, "LEFT", xs[2] + inset, 0)
    row.laneText:ClearAllPoints()
    row.laneText:SetPoint("LEFT", row, "LEFT", xs[2] + inset + 14, 0)
    row.laneText:SetWidth(max(1, s[2] - inset * 2 - 14))
    row.laneText:SetHeight(14)
    row.laneText:SetJustifyH("LEFT")
    row.pill:Frame():ClearAllPoints()
    row.pill:Frame():SetPoint("RIGHT", row, "LEFT", xs[3] + s[3] - inset, 0)
    right(row.zero, 3)
    right(row.queued, 4)
    local barWidth = max(10, s[5] - inset * 3 - 44)
    row.bar:Frame():ClearAllPoints()
    row.bar:Frame():SetPoint("LEFT", row, "LEFT", xs[5] + inset, 0)
    row.bar:Frame():SetWidth(barWidth)
    row.sent:ClearAllPoints()
    row.sent:SetPoint("LEFT", row, "LEFT", xs[5] + s[5] - inset - 42, 0)
    row.sent:SetWidth(42)
    row.sent:SetHeight(14)
    row.sent:SetJustifyH("RIGHT")
    right(row.failed, 6)
    row.avg:ClearAllPoints()
    row.avg:SetPoint("TOPLEFT", row, "TOPLEFT", xs[7] + inset, -3)
    row.avg:SetWidth(max(1, s[7] - inset * 2))
    row.avg:SetHeight(13)
    row.avg:SetJustifyH("LEFT")
    row.range:Frame():ClearAllPoints()
    row.range:Frame():SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", xs[7] + inset, 3)
    row.range:Frame():SetWidth(max(10, min(AVG_SCALE, s[7] - inset * 2)))
    right(row.last, 8)
    row.layout = frame.layoutId
  end

  local function shapeRow(row, style, radius, index)
    local look = row.look
    look.style, look.zebra = style, style == "zebra" and index % 2 == 0
    row.line:Hide()
    if style == "pill" or style == "card" then
      row:SetBackdrop(backdropOf(style, radius))
      tint(row, "SetBackdropColor", "card", style == "card" and 1 or 0.5)
      tint(row, "SetBackdropBorderColor", "borderDim", 0.6)
    else
      row:SetBackdrop(nil)
      if style == "line" then
        tint(row.line, "SetVertexColor", "borderDim", 0.6)
        row.line:Show()
      end
    end

    frame:PaintHover(row)
  end

  local function paintRow(row, data, index, maxSent, sig)
    local Parts = parts()
    local style, gap, radius = styleOf()
    local waiting, queued, sent, failed = number(data.waiting), number(data.queued), number(data.sent), number(data.failed)
    local avg, peak = number(data.avg), number(data.max)
    local lastText = data.last ~= nil and Parts.ago(data.last) or DOT
    local avgText = Parts.span(avg, peak)
    local laneKey = data.lane
    local laneText = (laneKey ~= nil and laneKey ~= "") and tostring(laneKey) or word("QUEUEVIEW_LANE_UNKNOWN")

    row.data = data
    if row.layout ~= frame.layoutId then
      layoutRow(row)
    end

    if differs(row.mem, tostring(data.who or ""), laneText, laneKey, waiting, queued, sent, failed, avg, peak, lastText, maxSent, index, frame.layoutId, sig) then
      frame.paints = frame.paints + 1
      shapeRow(row, style, radius, index)
      row.who:SetText(tostring(data.who or ""))
      row.laneDot:Set(laneKey)
      row.laneText:SetText(laneText)
      if waiting > 0 then
        row.pill:Set(Parts.number(waiting), "accent")
        row.pill:Frame():Show()
        row.zero:Hide()
      else
        row.pill:Frame():Hide()
        row.zero:Show()
      end

      row.queued:SetText(Parts.number(queued))
      row.bar:Set(maxSent > 0 and sent / maxSent or 0, Parts.laneColor(laneKey))
      row.sent:SetText(Parts.number(sent))
      if failed > 0 then
        row.failed:SetText(Parts.number(failed))
        Palette.paint(row.failed, "SetTextColor", "danger")
      else
        row.failed:SetText(DOT)
        Palette.paint(row.failed, "SetTextColor", "muted")
      end

      row.avg:SetText(avgText)
      row.range:Set(avg, peak, AVG_SCALE)
      row.last:SetText(lastText)
    end
  end

  function frame:Paint()
    local list = self.list
    local n = #list
    local stride = self.stride or rowStride()
    local visible = ceil(self.viewHeight / stride)
    local poolSize = visible + 2
    local height = n * stride

    if self.mem.height ~= height or self.mem.stride ~= stride then
      self.mem.height, self.mem.stride = height, stride
      self.scroll:SetContentHeight(height)
    end

    local offset = self.scroll:Offset() or 0
    local first = max(1, floor(offset / stride) + 1)
    local sig = skinSig()
    local maxSent = 0
    for i = 1, #self.dests do
      maxSent = max(maxSent, number(type(self.dests[i]) == "table" and self.dests[i].sent))
    end

    for slot = 1, poolSize do
      local index = first + slot - 1
      local row = self.pool[((index - 1) % poolSize) + 1]
      if index <= n then
        if not row then
          row = newRow(self)
          self.pool[((index - 1) % poolSize) + 1] = row
        end

        row:SetWidth(self.total)
        row:SetHeight(stride - select(2, styleOf()))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, -((index - 1) * stride))
        row:Show()
        paintRow(row, list[index], index, maxSent, sig)
      end
    end

    for k = 1, #self.pool do
      local row = self.pool[k]
      if row.data and (not self:Holds(row.data, first, poolSize)) then
        row:Hide()
        row.data = nil
        row.mem[1] = nil
      end
    end

    for index, header in ipairs(self.headers) do
      local column = COLUMNS[index]
      if self.sortId == column.id then
        Bricks.turn(header.sort, self.sortDesc and "DOWN" or "UP")
        header.sort:Show()
      else
        header.sort:Hide()
      end
    end

    self.visible = poolSize
  end

  function frame:Holds(data, first, poolSize)
    local index = self.rank[data]
    local list = self.list

    return index ~= nil and list[index] == data and index >= first and index < first + poolSize
  end

  function frame:SetDests(dests)
    self.dests = type(dests) == "table" and dests or {}
    local counts, names, order = {}, {}, {}

    for i = 1, #self.dests do
      local data = self.dests[i]
      if type(data) == "table" then
        local lane = data.lane or ""
        if counts[lane] == nil then
          counts[lane] = 0
          order[#order + 1] = lane
        end

        counts[lane] = counts[lane] + 1
      end
    end

    if self.lane ~= nil and counts[self.lane] == nil then
      self.lane = nil
    end

    sort(order, function(a, b)
      if counts[a] ~= counts[b] then
        return counts[a] > counts[b]
      end

      return tostring(a) < tostring(b)
    end)

    local items = {}
    for i, lane in ipairs(order) do
      items[i] = { key = lane, label = (lane ~= nil and lane ~= "") and tostring(lane) or word("QUEUEVIEW_LANE_UNKNOWN"), count = counts[lane], laneKey = lane }
    end

    if self.mem.size ~= (self:GetWidth() or 0) .. "x" .. (self:GetHeight() or 0) or not self.total then
      self:Relayout()
    end

    self.toolLabel:SetText(word("QUEUEVIEW_COL_LANE"))
    self.chips:Set(items, self.lane, function(key)
      if frame.lane == key then
        frame.lane = nil
      else
        frame.lane = key
      end

      frame:Rebuild()

      if opts.onLane then
        pcall(opts.onLane, frame.lane)
      end
    end)
    self:Rebuild()

    return self
  end

  function frame:SetFilter(lane)
    self.lane = lane
    self:Rebuild()

    return self
  end

  frame.scroll:SetScript("OnVerticalScroll", function()
    if frame.total then
      frame:Paint()
    end
  end)
  frame:Relayout()

  return frame
end

-- The Addons tab, List view: one row per addon, in the order received (the sort is in the tab's tool
-- bar). Same manners as `people`: pool of visible + 2 rows rebound on scroll, repainted only when their
-- signature changes. No colour per addon: the name is plain text, the bars take the lane colour.
local LIST_COLUMNS = {
  { id = "lane", key = "QUEUEVIEW_COL_LANE", min = 130, flex = true },
  { id = "waiting", key = "QUEUEVIEW_COL_WAITING", min = 64, right = true },
  { id = "queued", key = "QUEUEVIEW_COL_QUEUED", min = 84, right = true },
  { id = "sent", key = "QUEUEVIEW_COL_SENT", min = 170 },
  { id = "failed", key = "QUEUEVIEW_COL_FAILED", min = 54, right = true },
  { id = "classes", key = "QUEUEVIEW_LIST_COL_CLASSES", min = 84 },
  { id = "avg", key = "QUEUEVIEW_COL_AVGMAX", min = 170 },
  { id = "last", key = "QUEUEVIEW_COL_LASTSHORT", min = 70, right = true },
}
local CLASSES = 7
local CLASS_KEY = { "success", "success", "success", "caution", "caution", "danger", "danger" }
local CLASS_WIDTH, CLASS_HEIGHT, CLASS_MIN = 10, 16, 0.08
local LIST_SCALE = 130

local function classTip(index, count, share)
  local label
  if index == CLASSES then
    label = format(word("QUEUEVIEW_BUCKET_OVER"), word("QUEUEVIEW_BUCKET_" .. (CLASSES - 1)))
  else
    label = format(word("QUEUEVIEW_BUCKET_UPTO"), word("QUEUEVIEW_BUCKET_" .. index))
  end

  return format(word("QUEUEVIEW_BUCKET_TIP"), label, parts().number(count), share)
end

local function donePercent(data)
  local settled = number(data.queued) - number(data.waiting)
  local done = settled > 0 and min(1, number(data.sent) / settled) or 1

  return floor(done * 100 + 0.5)
end

function QueueTable.addons(parent, opts)
  opts = opts or {}
  local Q = parts()
  local frame = CreateFrame("Frame", nil, parent)
  local inset = tonumber(S("kit.inset", 4)) or 4
  local headH = tonumber(S("kit.table.row", 18)) or 18

  frame.onEnter, frame.onLeave = opts.onEnter, opts.onLeave
  frame.lanes, frame.pool, frame.headers, frame.sizes, frame.xs = {}, {}, {}, {}, {}
  frame.mem, frame.paints, frame.layoutId = {}, 0, 0
  frame:SetWidth(opts.width or (parent.GetWidth and parent:GetWidth()) or 1000)
  frame:SetHeight(opts.height or 270)

  frame.head = CreateFrame("Frame", nil, frame)
  frame.head:SetHeight(headH)
  frame.head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.rule = frame:CreateTexture(nil, "ARTWORK")
  frame.rule:SetTexture(Bricks.media("solid"))
  frame.rule:SetHeight(1)
  frame.rule:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, 0)
  frame.rule:SetPoint("TOPRIGHT", frame.head, "BOTTOMRIGHT", 0, 0)
  Palette.paint(frame.rule, "SetVertexColor", "borderDim")
  frame.scroll = Bricks.create("scroll", frame)
  frame.scroll:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, -1)
  frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  for index, column in ipairs(LIST_COLUMNS) do
    local header = Bricks.text(frame.head, "small", "muted")
    header:SetHeight(headH)
    header:SetJustifyH(column.right and "RIGHT" or "LEFT")
    frame.headers[index] = header
  end

  local function rowStride()
    return (tonumber(S("widgets.queue.table.row", 28)) or 28) + select(2, styleOf())
  end

  local function skinSig()
    local style, gap, radius = styleOf()

    return style .. gap .. radius .. hue("text") .. hue("muted") .. hue("danger") .. hue("borderDim") .. hue("card") .. hue("rowHover") .. hue("focus")
  end

  function frame:Relayout()
    local width = self:GetWidth() or 0
    local height = self:GetHeight() or 0
    local total = max(1, width - (tonumber(S("widgets.scroll.width", 6)) or 6) - (tonumber(S("kit.gap", 2)) or 2))
    local fixed = 0
    for _, column in ipairs(LIST_COLUMNS) do
      if not column.flex then
        fixed = fixed + column.min
      end
    end

    local x = 0
    for index, column in ipairs(LIST_COLUMNS) do
      local size = column.flex and max(column.min, total - fixed) or column.min
      local header = self.headers[index]
      self.sizes[index], self.xs[index] = size, x
      header:SetText(word(column.key))
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", self.head, "TOPLEFT", x + inset, 0)
      header:SetWidth(max(1, size - inset * 2))
      x = x + size
    end

    self.total, self.viewHeight = total, max(1, height - headH - 1)
    self.layoutId = self.layoutId + 1
    self.stride = rowStride()
    self.scroll:SetView(total, self.viewHeight)
    self.mem.size = width .. "x" .. height
  end

  function frame:PaintHover(row)
    if row.hovered then
      tint(row.fill, "SetVertexColor", "rowHover", 1)
      row.fill:Show()
    elseif row.look.zebra then
      tint(row.fill, "SetVertexColor", "borderDim", 0.15)
      row.fill:Show()
    else
      row.fill:Hide()
    end
  end

  local function newListRow()
    local row = CreateFrame("Button", nil, frame.scroll.child)
    row.fill = row:CreateTexture(nil, "BACKGROUND")
    row.fill:SetTexture(S("media.solid", "Interface\\Buttons\\WHITE8X8"))
    row.fill:SetAllPoints(row)
    row.fill:Hide()
    row.line = row:CreateTexture(nil, "BORDER")
    row.line:SetTexture(S("media.solid", "Interface\\Buttons\\WHITE8X8"))
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.line:Hide()
    row.mem, row.look = {}, {}
    row.name = Bricks.text(row, "button", "text")
    row.pill = Q.pill(row)
    row.zero = Bricks.text(row, "small", "muted")
    row.zero:SetText(DOT)
    row.queued = Bricks.text(row, "small", "muted")
    row.bar = Q.bar(row)
    row.sent = Bricks.text(row, "small", "text")
    row.failed = Bricks.text(row, "small", "muted")
    row.avg = Bricks.text(row, "small", "muted")
    row.range = Q.range(row)
    row.last = Bricks.text(row, "small", "muted")
    row.columns = {}
    for i = 1, CLASSES do
      local column = CreateFrame("Frame", nil, row)
      column:EnableMouse(true)
      column.bar = column:CreateTexture(nil, "ARTWORK")
      column.bar:SetTexture(S("media.solid", "Interface\\Buttons\\WHITE8X8"))
      column.bar:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 1, 0)
      column.bar:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", -1, 0)
      column:SetScript("OnEnter", function(self)
        if self.tipText then
          Bricks.tip(self, self.tipText)
        end
      end)
      column:SetScript("OnLeave", function()
        Bricks.hideTip()
      end)
      row.columns[i] = column
    end

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnEnter", function(self)
      self.hovered = true
      frame:PaintHover(self)

      local data = self.data
      if data then
        Bricks.tip(self, tostring(data.lane or ""), format(word("QUEUEVIEW_LIST_TIP"), Q.number(donePercent(data))))

        if frame.onEnter then
          pcall(frame.onEnter, data.lane)
        end
      end
    end)
    row:SetScript("OnLeave", function(self)
      self.hovered = false
      frame:PaintHover(self)
      Bricks.hideTip()

      if frame.onLeave then
        pcall(frame.onLeave)
      end
    end)

    return row
  end

  local function layoutListRow(row)
    local s, xs = frame.sizes, frame.xs
    local function cell(target, i, justify, width, left)
      target:ClearAllPoints()
      target:SetPoint("LEFT", row, "LEFT", xs[i] + inset + (left or 0), 0)
      target:SetWidth(max(1, (width or (s[i] - inset * 2))))
      target:SetHeight(14)
      target:SetJustifyH(justify)
    end

    cell(row.name, 1, "LEFT")
    row.pill:Frame():ClearAllPoints()
    row.pill:Frame():SetPoint("RIGHT", row, "LEFT", xs[2] + s[2] - inset, 0)
    cell(row.zero, 2, "RIGHT")
    cell(row.queued, 3, "RIGHT")
    row.bar:Frame():ClearAllPoints()
    row.bar:Frame():SetPoint("LEFT", row, "LEFT", xs[4] + inset, 0)
    row.bar:Frame():SetWidth(max(10, s[4] - inset * 3 - 48))
    row.sent:ClearAllPoints()
    row.sent:SetPoint("LEFT", row, "LEFT", xs[4] + s[4] - inset - 46, 0)
    row.sent:SetWidth(46)
    row.sent:SetHeight(14)
    row.sent:SetJustifyH("RIGHT")
    cell(row.failed, 5, "RIGHT")
    for i, column in ipairs(row.columns) do
      column:ClearAllPoints()
      column:SetPoint("LEFT", row, "LEFT", xs[6] + inset + (i - 1) * CLASS_WIDTH, 0)
      column:SetWidth(CLASS_WIDTH)
      column:SetHeight(CLASS_HEIGHT)
    end

    local rangeWidth = 64
    cell(row.avg, 7, "LEFT", max(1, s[7] - inset * 2 - rangeWidth - 4))
    row.range:Frame():ClearAllPoints()
    row.range:Frame():SetPoint("RIGHT", row, "LEFT", xs[7] + s[7] - inset, 0)
    row.range:Frame():SetWidth(rangeWidth)
    cell(row.last, 8, "RIGHT")
    row.layout = frame.layoutId
  end

  local function shapeListRow(row, style, radius, index)
    local look = row.look
    look.style, look.zebra = style, style == "zebra" and index % 2 == 0
    row.line:Hide()
    if style == "pill" or style == "card" then
      row:SetBackdrop(backdropOf(style, radius))
      tint(row, "SetBackdropColor", "card", style == "card" and 1 or 0.5)
      tint(row, "SetBackdropBorderColor", "borderDim", 0.6)
    else
      row:SetBackdrop(nil)
      if style == "line" then
        tint(row.line, "SetVertexColor", "borderDim", 0.6)
        row.line:Show()
      end
    end

    frame:PaintHover(row)
  end

  local function paintListRow(row, data, index, maxSent, sig)
    local Parts = parts()
    local style, _, radius = styleOf()
    local waiting, queued, sent, failed = number(data.waiting), number(data.queued), number(data.sent), number(data.failed)
    local avg, peak = number(data.avg), number(data.max)
    local lastText = data.last ~= nil and Parts.ago(data.last) or DOT
    local buckets = type(data.buckets) == "table" and data.buckets or {}
    local b1, b2, b3, b4, b5, b6, b7 = number(buckets[1]), number(buckets[2]), number(buckets[3]), number(buckets[4]), number(buckets[5]), number(buckets[6]), number(buckets[7])

    row.data, row.index = data, index
    if row.layout ~= frame.layoutId then
      layoutListRow(row)
    end

    if differs(row.mem, tostring(data.lane or ""), waiting, queued, sent, failed, avg, peak, lastText, maxSent, index, frame.layoutId, sig, b1, b2, b3, b4, b5, b6, b7) then
      frame.paints = frame.paints + 1
      shapeListRow(row, style, radius, index)
      row.name:SetText(tostring(data.lane or ""))
      if waiting > 0 then
        row.pill:Set(Parts.number(waiting), "accent")
        row.pill:Frame():Show()
        row.zero:Hide()
      else
        row.pill:Frame():Hide()
        row.zero:Show()
      end

      row.queued:SetText(Parts.number(queued))
      row.bar:Set(maxSent > 0 and sent / maxSent or 0, Parts.laneColor(data.lane))
      row.sent:SetText(Parts.number(sent))
      if failed > 0 then
        row.failed:SetText(Parts.number(failed))
        Palette.paint(row.failed, "SetTextColor", "danger")
      else
        row.failed:SetText(DOT)
        Palette.paint(row.failed, "SetTextColor", "muted")
      end

      local top, sum = 0, 0
      for i = 1, CLASSES do
        local count = max(0, number(buckets[i]))
        top, sum = max(top, count), sum + count
      end

      for i, column in ipairs(row.columns) do
        local count = max(0, number(buckets[i]))
        local share = top > 0 and max(CLASS_MIN, count / top) or CLASS_MIN
        column.count, column.share = count, share
        column.bar:SetHeight(max(1, floor(CLASS_HEIGHT * share + 0.5)))
        tint(column.bar, "SetVertexColor", CLASS_KEY[i], 1)
        column.tipText = classTip(i, count, sum > 0 and floor(count / sum * 100 + 0.5) or 0)
      end

      row.avg:SetText(Parts.span(avg, peak))
      row.range:Set(avg, peak, LIST_SCALE)
      row.last:SetText(lastText)
    end
  end

  function frame:Paint()
    local lanes = self.lanes
    local n = #lanes
    local stride = self.stride or rowStride()
    local visible = ceil(self.viewHeight / stride)
    local poolSize = visible + 2
    local height = n * stride

    if self.mem.height ~= height or self.mem.stride ~= stride then
      self.mem.height, self.mem.stride = height, stride
      self.scroll:SetContentHeight(height)
    end

    local offset = self.scroll:Offset() or 0
    local first = max(1, floor(offset / stride) + 1)
    local sig = skinSig()
    local maxSent = 0
    for i = 1, n do
      maxSent = max(maxSent, number(type(lanes[i]) == "table" and lanes[i].sent))
    end

    for slot = 1, poolSize do
      local index = first + slot - 1
      local at = ((index - 1) % poolSize) + 1
      local row = self.pool[at]
      if index <= n then
        if not row then
          row = newListRow()
          self.pool[at] = row
        end

        row:SetWidth(self.total)
        row:SetHeight(stride - select(2, styleOf()))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, -((index - 1) * stride))
        row:Show()
        paintListRow(row, lanes[index], index, maxSent, sig)
      end
    end

    for k = 1, #self.pool do
      local row = self.pool[k]
      if row.data and (row.index < first or row.index >= first + poolSize or row.index > n or lanes[row.index] ~= row.data) then
        row:Hide()
        row.data = nil
        row.mem[1] = nil
      end
    end

    self.visible = poolSize
  end

  function frame:Frame()
    return self
  end

  function frame:SetLanes(lanes)
    local list = {}
    if type(lanes) == "table" then
      for i = 1, #lanes do
        if type(lanes[i]) == "table" then
          list[#list + 1] = lanes[i]
        end
      end
    end

    self.lanes = list
    if self.mem.size ~= (self:GetWidth() or 0) .. "x" .. (self:GetHeight() or 0) or not self.total then
      self:Relayout()
    end

    self:Paint()

    return self
  end

  frame.scroll:SetScript("OnVerticalScroll", function()
    if frame.total then
      frame:Paint()
    end
  end)
  frame:Relayout()

  return frame
end
