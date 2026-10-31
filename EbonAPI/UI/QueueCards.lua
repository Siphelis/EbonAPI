EbonAPI = EbonAPI or {}
EbonAPI.QueueCards = EbonAPI.QueueCards or {}

-- The Addons tab of the send queue window. `lanes(parent, opts)` is the whole view: a toolbar
-- ([Cards | List], "Sort by" [Waiting | A to Z | Longest wait], "N addons"), the compact cards (five per row:
-- ring without text, name, waiting pill, histogram of the seven wait classes, three lines of figures, average
-- and maximum pills) scrolled by the Kit scroll brick, and the List view (QueueTable.addons), hidden while
-- the cards are chosen. Frames are built once and recycled; `:SetLanes(lanes)` is the only entry point: it
-- sorts a COPY of the list and repaints only what changed, in the view that is shown. Card shape:
-- widgets.cards.shape (square, bevel, round, pill, flat), with a fallback taken from the border style and
-- the corners of the skin. No colour per addon: the name takes the text colour.

local QueueCards = EbonAPI.QueueCards
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Parameters = EbonAPI.Parameters
local Bricks = EbonAPI.Bricks
local QueueParts = EbonAPI.QueueParts

local format, floor, ceil, max, min = string.format, math.floor, math.ceil, math.max, math.min
local pcall, tostring, tonumber, type, ipairs = pcall, tostring, tonumber, type, ipairs
local lower, sort = string.lower, table.sort

local THEME = Palette.THEME

local CLASSES = 7
local CLASS_KEY = { "success", "success", "success", "caution", "caution", "danger", "danger" }
local MIN_SHARE = 0.04
local HIST_W, HIST_H = 74, 38
local PAD, GAP = 7, 7
local PER_ROW, CARD_HEIGHT = 5, 103
local SCROLL_BAR = 14
local SHAPES = { square = true, bevel = true, round = true, pill = true, flat = true }
local SORTS = { "waiting", "az", "max" }
local SORT_WORD = { waiting = "QUEUEVIEW_LANES_SORT_WAITING", az = "QUEUEVIEW_LANES_SORT_AZ", max = "QUEUEVIEW_LANES_SORT_MAX" }

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

local function hide_or_show(target, on)
  if on then
    target:Show()
  else
    target:Hide()
  end
end

local function shapeOf()
  local shape = value("widgets.cards.shape")
  if SHAPES[shape] then
    return shape
  end

  local ok, corners = pcall(Parameters.value, nil, "corners")
  if ok and (tonumber(corners) or 0) > 0 then
    return "round"
  end

  return value("border.style") == "TEXTURE" and "bevel" or "square"
end

local backdrops = {}

local function backdropOf(shape)
  local backdrop = backdrops[shape]
  if not backdrop then
    local solid = value("media.solid", "Interface\\Buttons\\WHITE8X8")
    local rounded = value("media.rounded", solid)
    if shape == "round" then
      backdrop = { bgFile = solid, edgeFile = rounded, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } }
    elseif shape == "pill" then
      backdrop = { bgFile = solid, edgeFile = rounded, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
    elseif shape == "flat" then
      backdrop = { bgFile = solid }
    elseif shape == "bevel" then
      backdrop = { bgFile = solid, edgeFile = solid, edgeSize = 2, insets = { left = 2, right = 2, top = 2, bottom = 2 } }
    else
      backdrop = { bgFile = solid, edgeFile = solid, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
    end

    backdrops[shape] = backdrop
  end

  return backdrop
end

local function classLabel(index)
  return word("QUEUEVIEW_BUCKET_" .. index)
end

local function classTip(index, count, share)
  local label
  if index == CLASSES then
    label = format(word("QUEUEVIEW_BUCKET_OVER"), classLabel(CLASSES - 1))
  else
    label = format(word("QUEUEVIEW_BUCKET_UPTO"), classLabel(index))
  end

  return format(word("QUEUEVIEW_BUCKET_TIP"), label, QueueParts.number(count), share)
end

local function ringSize()
  return tonumber(value("widgets.queue.ring.compact", 22)) or 22
end

local function newColumn(card, holder, index)
  local column = CreateFrame("Frame", nil, holder)
  column:EnableMouse(true)
  column.bar = column:CreateTexture(nil, "ARTWORK")
  column.bar:SetTexture(value("media.solid", "Interface\\Buttons\\WHITE8X8"))
  column.bar:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 1, 0)
  column.bar:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", -1, 0)
  column.index = index
  column:SetScript("OnEnter", function(self)
    if self.tipText then
      Bricks.tip(self, self.tipText)
    end
  end)
  column:SetScript("OnLeave", function()
    Bricks.hideTip()
  end)

  return column
end

local function newCard(owner, index)
  local card = CreateFrame("Frame", nil, owner.child)
  card.index, card.mem, card.paints = index, {}, 0
  card:EnableMouse(true)
  card:SetScript("OnEnter", function(self)
    if self.tipLines then
      Bricks.tip(self, self.tipLines[1], table.concat(self.tipLines, "\n", 2))
    end
  end)
  card:SetScript("OnLeave", function()
    Bricks.hideTip()
  end)

  card.ring = QueueParts.ring(card)
  card.ring:Frame():SetWidth(ringSize())
  card.ring:Frame():SetHeight(ringSize())
  card.ring:Frame():SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -PAD)
  card.name = Bricks.text(card, "normal", "text")
  card.name:SetPoint("LEFT", card.ring:Frame(), "RIGHT", 6, 0)
  card.name:SetJustifyH("LEFT")
  if card.name.SetWordWrap then
    card.name:SetWordWrap(false)
  end

  card.pill = QueueParts.pill(card)
  card.pill:Frame():SetPoint("RIGHT", card, "TOPRIGHT", -PAD, -(PAD + ringSize() / 2))

  card.hist = CreateFrame("Frame", nil, card)
  card.hist:SetWidth(HIST_W)
  card.hist:SetHeight(HIST_H)
  card.columns = {}
  for i = 1, CLASSES do
    card.columns[i] = newColumn(card, card.hist, i)
  end

  card.lines = {}
  for i = 1, 3 do
    local line = Bricks.text(card, "small", "text")
    line:SetJustifyH("LEFT")
    if line.SetWordWrap then
      line:SetWordWrap(false)
    end
    card.lines[i] = line
  end

  card.avgPill = QueueParts.pill(card)
  card.maxPill = QueueParts.pill(card)

  return card
end

local function layout(card, width)
  if card.mem.width == width then
    return
  end

  card.mem.width = width
  card:SetWidth(width)
  card:SetHeight(CARD_HEIGHT)
  card.name:SetWidth(max(10, width - PAD * 2 - ringSize() - 6 - 40))

  local top = PAD + ringSize() + PAD
  card.hist:ClearAllPoints()
  card.hist:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -top)
  local slot = HIST_W / CLASSES
  for i, column in ipairs(card.columns) do
    column:ClearAllPoints()
    column:SetPoint("BOTTOMLEFT", card.hist, "BOTTOMLEFT", (i - 1) * slot, 0)
    column:SetWidth(slot)
    column:SetHeight(HIST_H)
  end

  local left = PAD + HIST_W + 8
  for i, line in ipairs(card.lines) do
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", card, "TOPLEFT", left, -(top + 1 + (i - 1) * 13))
    line:SetWidth(max(10, width - left - PAD))
  end

  card.avgPill:Frame():ClearAllPoints()
  card.avgPill:Frame():SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", PAD, PAD)
  card.maxPill:Frame():ClearAllPoints()
  card.maxPill:Frame():SetPoint("LEFT", card.avgPill:Frame(), "RIGHT", 6, 0)
end

local function signature(lane, look)
  local b = lane.buckets or {}

  return format("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s", tostring(lane.lane), tostring(lane.waiting), tostring(lane.queued),
    tostring(lane.sent), tostring(lane.failed), lane.last ~= nil and QueueParts.ago(lane.last) or "", tostring(lane.avg), tostring(lane.max),
    tostring(b[1]), tostring(b[2]), tostring(b[3]), tostring(b[4]), tostring(b[5]), tostring(b[6]) .. "," .. tostring(b[7]) .. look)
end

local function paintShape(card, shape)
  card:SetBackdrop(backdropOf(shape))
  tint(card, "SetBackdropColor", "card", shape == "flat" and 0.6 or 0.9)
  if shape == "flat" or shape == "pill" then
    tint(card, "SetBackdropBorderColor", "card", 0)
  elseif shape == "bevel" then
    card:SetBackdropBorderColor(0, 0, 0, 1)
  else
    tint(card, "SetBackdropBorderColor", "borderDim", 1)
  end

  card.shape = shape
end

local function paintCard(card, lane, shape)
  local queued, waiting, sent, failed = num(lane.queued), num(lane.waiting), num(lane.sent), num(lane.failed)
  local settled = queued - waiting
  local done = settled > 0 and min(1, sent / settled) or 1
  local percent = floor(done * 100 + 0.5)

  if card.shape ~= shape then
    paintShape(card, shape)
  end

  card.ring:Set(done, "")
  card.fraction = done
  Palette.paint(card.name, "SetTextColor", "text")
  card.name:SetText(tostring(lane.lane or ""))

  if waiting > 0 then
    card.pill:Set(QueueParts.number(waiting), "accent")
    card.pill:Frame():Show()
  else
    card.pill:Frame():Hide()
  end

  card.lines[1]:SetText(format(word("QUEUEVIEW_LANES_QUEUED"), QueueParts.number(queued)))
  card.lines[2]:SetText(format(word("QUEUEVIEW_LANES_SENT"), QueueParts.number(sent)))
  card.lines[3]:SetText(format(word(failed <= 1 and "QUEUEVIEW_LANES_FAILED_ONE" or "QUEUEVIEW_LANES_FAILED_MANY"), QueueParts.number(failed)))
  Palette.paint(card.lines[1], "SetTextColor", "text")
  Palette.paint(card.lines[2], "SetTextColor", "text")
  Palette.paint(card.lines[3], "SetTextColor", failed > 0 and "danger" or "text")

  local buckets = lane.buckets or {}
  local top, sum = 0, 0
  for i = 1, CLASSES do
    local count = max(0, num(buckets[i]))
    top, sum = max(top, count), sum + count
  end

  for i, column in ipairs(card.columns) do
    local count = max(0, num(buckets[i]))
    local share = top > 0 and max(MIN_SHARE, count / top) or MIN_SHARE
    column.count, column.share = count, share
    column.bar:SetHeight(max(1, share * HIST_H))
    tint(column.bar, "SetVertexColor", CLASS_KEY[i], 1)
    column.tipText = classTip(i, count, sum > 0 and floor(count / sum * 100 + 0.5) or 0)
  end

  card.avgLevel = QueueParts.level(lane.avg, QueueParts.LIMITS.average)
  card.maxLevel = QueueParts.level(lane.max, QueueParts.LIMITS.wait)
  card.avgPill:Set(format(word("QUEUEVIEW_LANES_AVG"), QueueParts.seconds(lane.avg)), card.avgLevel)
  card.maxPill:Set(format(word("QUEUEVIEW_LANES_MAX"), QueueParts.seconds(lane.max)), card.maxLevel)

  card.tipLines = {
    tostring(lane.lane or ""),
    format(word("QUEUEVIEW_LANES_TIP_DONE"), percent, QueueParts.number(waiting)),
    format(word("QUEUEVIEW_LANES_TIP_TOTALS"), QueueParts.number(queued), QueueParts.number(sent), QueueParts.number(failed)),
    format(word("QUEUEVIEW_LANES_TIP_LAST"), lane.last ~= nil and QueueParts.ago(lane.last) or word("QUEUEVIEW_NONE")),
    format(word("QUEUEVIEW_LANES_TIP_WAIT"), QueueParts.seconds(lane.avg), QueueParts.seconds(lane.max)),
  }
  card.paints = card.paints + 1
end

-- Sorted COPY of the lanes (the list received is never modified); stable: ties keep the order received.
local function sorted(lanes, key)
  local list = {}
  for _, lane in ipairs(lanes or {}) do
    if type(lane) == "table" then
      list[#list + 1] = { lane = lane, index = #list + 1, name = lower(tostring(lane.lane or "")) }
    end
  end

  sort(list, function(a, b)
    local x, y = a.lane, b.lane
    if key == "az" then
      if a.name ~= b.name then
        return a.name < b.name
      end
    elseif key == "max" then
      if num(x.max) ~= num(y.max) then
        return num(x.max) > num(y.max)
      end
    else
      if num(x.waiting) ~= num(y.waiting) then
        return num(x.waiting) > num(y.waiting)
      end

      if num(x.max) ~= num(y.max) then
        return num(x.max) > num(y.max)
      end
    end

    return a.index < b.index
  end)

  for i, entry in ipairs(list) do
    list[i] = entry.lane
  end

  return list
end

EbonAPI.QueueCards.sorted = sorted

function QueueCards.lanes(parent, opts)
  opts = opts or {}

  local view = { parent = parent, cards = {}, mem = {}, mode = "cards", sort = "waiting", buttons = {}, lanes = {}, ordered = {} }

  local bar = CreateFrame("Frame", nil, parent)
  bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  view.bar = bar

  local last
  local function segment(group, key, textKey, onClick)
    local button = Bricks.create("button", bar)
    button:SetLabel(word(textKey))
    button:SetPadding(10)
    button:Fit()
    button.textKey2 = textKey
    button.onClick = function()
      onClick(key)
    end
    if last and last.group == group then
      button:SetPoint("LEFT", last, "RIGHT", 0, 0)
    elseif last then
      button:SetPoint("LEFT", last, "RIGHT", 6, 0)
    else
      button:SetPoint("LEFT", bar, "LEFT", 0, 0)
    end

    button.group = group
    last = button
    view.buttons[key] = button

    return button
  end

  segment("mode", "cards", "QUEUEVIEW_LANES_CARDS", function(key)
    view:SetMode(key)
  end)
  segment("mode", "list", "QUEUEVIEW_LANES_LIST", function(key)
    view:SetMode(key)
  end)

  view.sortLabel = Bricks.text(bar, "small", "muted")
  view.sortLabel:SetText(word("QUEUEVIEW_LANES_SORT"))
  view.sortLabel:SetPoint("LEFT", last, "RIGHT", 14, 0)
  last = nil
  for i, key in ipairs(SORTS) do
    local button = segment("sort", key, SORT_WORD[key], function(chosen)
      view:SetSort(chosen)
    end)
    if i == 1 then
      button:ClearAllPoints()
      button:SetPoint("LEFT", view.sortLabel, "RIGHT", 8, 0)
    end
  end

  view.count = Bricks.text(bar, "small", "muted")
  view.count:SetPoint("RIGHT", bar, "RIGHT", -PAD, 0)
  view.count:SetJustifyH("RIGHT")

  local barHeight = max(1, floor(view.buttons.cards:GetHeight() or 0))
  bar:SetHeight(barHeight)
  local topOffset = barHeight + 6

  local scroll = Bricks.create("scroll", parent)
  scroll:SetMode("VERTICAL")
  scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -topOffset)
  scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  view.scroll, view.child = scroll, scroll.child

  if EbonAPI.QueueTable and EbonAPI.QueueTable.addons then
    view.list = EbonAPI.QueueTable.addons(parent, { width = num(opts.width) > 0 and opts.width or 1000, height = max(1, num(opts.height) - topOffset) })
    local frame = view.list:Frame()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -topOffset)
    frame:Hide()
  end

  local function sizeOf()
    local width = parent.GetWidth and parent:GetWidth() or 0
    if not width or width < 10 then
      width = num(opts.width)
    end

    local height = parent.GetHeight and parent:GetHeight() or 0
    if not height or height < 10 then
      height = num(opts.height)
    end

    return max(1, floor(width)), max(1, floor(height) - topOffset)
  end

  local function refreshButtons()
    view.buttons.cards:SetSelected(view.mode == "cards")
    view.buttons.list:SetSelected(view.mode == "list")
    for _, key in ipairs(SORTS) do
      view.buttons[key]:SetSelected(view.sort == key)
    end
  end

  local function paintCards(list, width, height)
    local shape = shapeOf()
    local look = format("%s|%s|%s|%s|%s", shape, hue("card"), hue("borderDim"), hue("muted"), hue("text"))
    local count = #list
    local usable = max(1, width - SCROLL_BAR)
    local cardWidth = floor((usable - (PER_ROW - 1) * GAP) / PER_ROW)

    if view.mem.width ~= usable or view.mem.height ~= height or view.mem.count ~= count then
      view.mem.width, view.mem.height, view.mem.count = usable, height, count
      view.mem.laid = nil
      scroll:SetView(usable, height)
    end

    for i = 1, count do
      if not view.cards[i] then
        view.cards[i] = newCard(view, i)
        view.mem.laid = nil
      end
    end

    if not view.mem.laid then
      view.mem.laid = true
      local rows = ceil(count / PER_ROW)
      for i = 1, count do
        local card = view.cards[i]
        layout(card, cardWidth)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", view.child, "TOPLEFT", ((i - 1) % PER_ROW) * (cardWidth + GAP), -floor((i - 1) / PER_ROW) * (CARD_HEIGHT + GAP))
      end

      scroll:SetContentHeight(max(1, rows * (CARD_HEIGHT + GAP) - GAP))
    end

    for i, card in ipairs(view.cards) do
      local lane = list[i]
      hide_or_show(card, lane ~= nil)
      if lane then
        local sig = signature(lane, look)
        if card.mem.sig ~= sig then
          card.mem.sig = sig
          paintCard(card, lane, shape)
        end
      end
    end
  end

  -- Paints the view that is shown with the sorted list; the other one is fed when it is chosen.
  function view:Apply()
    local width, height = sizeOf()
    local count = #self.ordered

    local text = format(word(count == 1 and "QUEUEVIEW_LANES_COUNT_ONE" or "QUEUEVIEW_LANES_COUNT_MANY"), count)
    if self.mem.countText ~= text then
      self.mem.countText = text
      self.count:SetText(text)
    end

    if self.mem.shownMode ~= self.mode then
      self.mem.shownMode = self.mode
      hide_or_show(scroll, self.mode == "cards")
      if self.list then
        hide_or_show(self.list:Frame(), self.mode == "list")
      end
    end

    if self.mode == "list" and self.list then
      local frame = self.list:Frame()
      if self.mem.listW ~= width or self.mem.listH ~= height then
        self.mem.listW, self.mem.listH = width, height
        frame:SetWidth(width)
        frame:SetHeight(height)
      end

      self.list:SetLanes(self.ordered)
    elseif self.mode == "cards" then
      paintCards(self.ordered, width, height)
    end
  end

  function view:SetMode(mode)
    if mode ~= "cards" and mode ~= "list" then
      return
    end

    self.mode = mode
    refreshButtons()
    self:Apply()
  end

  function view:SetSort(key)
    if not SORT_WORD[key] then
      return
    end

    self.sort = key
    self.ordered = sorted(self.lanes, key)
    refreshButtons()
    self:Apply()
  end

  function view:SetLanes(lanes)
    self.lanes = lanes or {}
    self.ordered = sorted(self.lanes, self.sort)
    self:Apply()
  end

  refreshButtons()

  return view
end
