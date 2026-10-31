EbonAPI = EbonAPI or {}
EbonAPI.QueueCards = EbonAPI.QueueCards or {}

-- The Fetch tab of the send queue window: a row of six figures, the slot of the holders table on the left
-- (filled by EbonAPI.QueueTable.holders), one card per request in flight on the right. Cards are pooled,
-- repainted only when their values, the palette or the card shape of the skin changed.
-- Shape: widgets.cards.shape (square, bevel, round, pill, flat, line; frame and glass kept for the Kit).

local QueueCards = EbonAPI.QueueCards

local format, floor, ceil, max, min = string.format, math.floor, math.ceil, math.max, math.min
local pcall, tostring, tonumber, type, ipairs, setmetatable = pcall, tostring, tonumber, type, ipairs, setmetatable
local concat = table.concat

local WAIT_LIMITS = { 10, 20 }
local MAX_VISIBLE = 8
local SHAPES = {
  square = { bg = "card", bgAlpha = 0.9, edge = "borderDim", edgeAlpha = 1, size = 1, inset = 1 },
  bevel = { bg = "card", bgAlpha = 0.9, edge = "borderDim", edgeAlpha = 1, size = 2, inset = 2, black = true },
  frame = { bg = "card", bgAlpha = 0.9, edge = "border", edgeAlpha = 1, size = 2 },
  line = { bg = "card", bgAlpha = 0.6, edge = "heading", edgeAlpha = 0.8, size = 1 },
  glass = { bg = "card", bgAlpha = 0.35, edge = "borderDim", edgeAlpha = 0.5, size = 1 },
  pill = { bg = "card", bgAlpha = 0.8, edge = "card", edgeAlpha = 0, size = 8, rounded = true },
  flat = { bg = "card", bgAlpha = 1, edge = "card", edgeAlpha = 0, size = 1 },
  round = { bg = "card", bgAlpha = 1, edge = "borderDim", edgeAlpha = 1, size = 8, rounded = true },
}

local function value(key, fallback)
  local ok, found = pcall(EbonAPI.Skins.value, key)
  if ok and found ~= nil then
    return found
  end

  return fallback
end

local NOTHING = ""

local function word(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

local function num(n)
  n = tonumber(n)
  if not n or n ~= n or n == math.huge or n == -math.huge then
    return 0
  end

  return n
end

local function hue(key)
  local color = EbonAPI.Palette.THEME[key] or EbonAPI.Palette.THEME.text

  return color[1] + color[2] * 1000 + color[3] * 1000000
end

local function tint(target, method, key, alpha)
  local color = EbonAPI.Palette.THEME[key] or EbonAPI.Palette.THEME.text
  target[method](target, color[1], color[2], color[3], alpha or 1)
end

local backdrops = {}

local function backdropOf(name)
  local spec = SHAPES[name]
  local backdrop = backdrops[name]

  if not backdrop then
    local solid = value("media.solid", "Interface\\Buttons\\WHITE8X8")
    local inset = spec.inset or (spec.rounded and floor(spec.size * 0.25) or 0)

    backdrop = {
      bgFile = solid, edgeFile = spec.rounded and value("media.rounded", solid) or solid, edgeSize = spec.size,
      insets = { left = inset, right = inset, top = inset, bottom = inset },
    }
    backdrops[name] = backdrop
  end

  return backdrop
end

local function shapeName()
  local name = value("widgets.cards.shape", "bevel")

  return SHAPES[name] and name or "bevel"
end

local function paintFrame(frame, name)
  local spec = SHAPES[name]

  if frame.cardShape ~= name then
    frame:SetBackdrop(backdropOf(name))
    frame.cardShape = name
  end

  tint(frame, "SetBackdropColor", spec.bg, spec.bgAlpha)
  if spec.black then
    frame:SetBackdropBorderColor(0, 0, 0, 1)
  else
    tint(frame, "SetBackdropBorderColor", spec.edge, spec.edgeAlpha)
  end
end

local function shapeSignature(name)
  local spec = SHAPES[name]

  return name .. hue(spec.bg) .. "|" .. hue(spec.edge)
end

local function newCard(owner)
  local Parts = EbonAPI.QueueParts
  local Bricks = EbonAPI.Bricks
  local frame = CreateFrame("Frame", nil, owner.scroll.child)
  local card = { frame = frame, mem = "" }

  card.key = Bricks.text(frame, "normal", "text")
  card.key:SetJustifyH("LEFT")
  if card.key.SetWordWrap then
    card.key:SetWordWrap(false)
  end

  card.limit = Bricks.text(frame, "small", "muted")
  card.age = Bricks.text(frame, "normal", "text")
  card.peer = Bricks.text(frame, "small", "muted")
  card.peer:SetJustifyH("LEFT")
  card.queued = Parts.pill(frame)
  card.bar = Parts.bar(frame)

  return card
end

local function placeCard(card, pad)
  local frame = card.frame

  card.limit:ClearAllPoints()
  card.limit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad)
  card.age:ClearAllPoints()
  card.age:SetPoint("RIGHT", card.limit, "LEFT", -4, 0)
  card.queued.frame:ClearAllPoints()
  card.queued.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad + 2)
  card.key:ClearAllPoints()
  card.key:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
  card.key:SetPoint("RIGHT", card.age, "LEFT", -6, 0)
  card.peer:ClearAllPoints()
  card.peer:SetPoint("TOPLEFT", card.key, "BOTTOMLEFT", 0, -3)
  card.bar.frame:ClearAllPoints()
  card.bar.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, pad)
  card.bar.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
end

local function paintCard(owner, card, row, width, height, pad, name)
  local Parts = EbonAPI.QueueParts
  local queued = row.queued and true or false
  local age = queued and 0 or max(0, num(row.age))
  local limit = max(1, num(row.limit))
  local level = Parts.level(age, WAIT_LIMITS)
  local ageText = queued and "" or Parts.seconds(age)
  local key, peer = tostring(row.key or ""), tostring(row.peer or "")
  local sig = concat({ key, peer, tostring(queued), ageText, limit, level, width, height, pad, shapeSignature(name) }, "|")

  if card.mem == sig then
    return
  end

  card.mem = sig
  card.frame:SetWidth(width)
  card.frame:SetHeight(height)
  paintFrame(card.frame, name)
  placeCard(card, pad)
  card.key:SetText(key)
  card.peer:SetText(format(word("QUEUEVIEW_FETCH_AT"), peer))

  if queued then
    card.age:SetText(NOTHING)
    card.limit:SetText(NOTHING)
    card.queued:Set(word("QUEUEVIEW_QUEUED"))
    card.queued.frame:Show()
    card.bar.frame:Hide()
  else
    card.age:SetText(ageText)
    card.limit:SetText(format(word("QUEUEVIEW_FETCH_OF"), NOTHING, Parts.seconds(limit)))
    card.queued.frame:Hide()
    card.bar.frame:Show()
    card.bar:Set(age / limit, Parts.levelColor(level))
  end
end

local function figures(summary)
  local Parts = EbonAPI.QueueParts
  local n = Parts.number

  return {
    format(word("QUEUEVIEW_FETCH_LIVE"), n(summary.live), n(summary.window)),
    format(word("QUEUEVIEW_FETCH_PER_PEER"), n(summary.perPeer)),
    format(word("QUEUEVIEW_FETCH_WAITING"), n(summary.waiting)),
    format(word("QUEUEVIEW_FETCH_DELAYED"), n(summary.delayed)),
    format(word("QUEUEVIEW_FETCH_LATE"), n(summary.late)),
    format(word("QUEUEVIEW_FETCH_TIMEOUT"), n(summary.timeout)),
  }
end

local function layout(self)
  local root = self.root
  local width, height = root:GetWidth() or 0, root:GetHeight() or 0
  local parent = self.parent

  if width <= 1 then
    width = parent:GetWidth() or 0
  end

  if height <= 1 then
    height = parent:GetHeight() or 0
  end

  width, height = floor(width), floor(height)

  local gap = tonumber(value("widgets.cards.gap", 6)) or 6
  local pad = tonumber(value("widgets.cards.pad", 8)) or 8
  local cardHeight = pad * 2 + 38
  local count = #self.flights
  local x, y, rowHeight = 0, 0, 0

  for index, pill in ipairs(self.pills) do
    local frame = pill.frame
    local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0

    if x > 0 and x + w > width then
      x, y = 0, y + rowHeight + gap
      rowHeight = 0
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
    x = x + w + gap
    rowHeight = max(rowHeight, h)
  end

  local top = y + rowHeight + gap
  local column = max(1, floor((width - gap) / 2))
  local viewWidth = max(1, width - column - gap)
  local head = (self.head:GetStringHeight() or 12) + 4
  local viewHeight = max(1, height - top - head)
  local room = (tonumber(value("widgets.scroll.width", 12)) or 12) + (tonumber(value("kit.gap", 6)) or 6)
  local cardWidth = max(1, viewWidth - room)
  local content = count > 0 and count * cardHeight + (count - 1) * gap or 0
  local name = shapeName()
  local sig = concat({ width, height, top, count, pad, gap, name, shapeSignature(name) }, "|")

  if self.layoutSig == sig then
    return
  end

  self.layoutSig = sig
  self.slot:ClearAllPoints()
  self.slot:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -top)
  self.slot:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0)
  self.slot:SetWidth(column)
  self.head:ClearAllPoints()
  self.head:SetPoint("TOPLEFT", root, "TOPLEFT", column + gap, -top)
  self.scroll:ClearAllPoints()
  self.scroll:SetPoint("TOPLEFT", root, "TOPLEFT", column + gap, -(top + head))
  self.scroll:SetWidth(viewWidth)
  self.scroll:SetHeight(viewHeight)
  self.scroll:SetView(viewWidth, viewHeight)
  self.scroll:SetContentWidth(viewWidth)
  self.scroll:SetContentHeight(max(content, 1))
  self.geometry = { width = cardWidth, height = cardHeight, pad = pad, gap = gap, name = name, view = viewHeight }

  for index, card in ipairs(self.cards) do
    card.frame:ClearAllPoints()
    card.frame:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, -((index - 1) * (cardHeight + gap)))
    card.mem = ""
  end
end

local function paintFlights(self)
  local geometry = self.geometry

  if not geometry then
    return
  end

  for index, row in ipairs(self.flights) do
    local card = self.cards[index]

    if not card then
      card = newCard(self)
      self.cards[index] = card
      card.frame:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0,
        -((index - 1) * (geometry.height + geometry.gap)))
    end

    card.frame:Show()
    paintCard(self, card, row, geometry.width, geometry.height, geometry.pad, geometry.name)
  end

  for index = #self.flights + 1, #self.cards do
    self.cards[index].frame:Hide()
  end

  if #self.flights == 0 then
    self.empty:Show()
  else
    self.empty:Hide()
  end
end

function QueueCards.fetch(parent, opts)
  opts = opts or {}

  local Parts = EbonAPI.QueueParts
  local Bricks = EbonAPI.Bricks
  local root = CreateFrame("Frame", nil, parent)
  local widget = setmetatable({ root = root, parent = parent, pills = {}, cards = {}, flights = {}, mem = "" },
    { __index = { Frame = function(self) return self.root end } })

  root:SetAllPoints(parent)

  widget.slot = opts.holdersSlot or CreateFrame("Frame", nil, root)
  widget.slot:SetParent(root)
  widget.head = Bricks.text(root, "normal", "heading")
  widget.head:SetJustifyH("LEFT")
  widget.title = word("QUEUEVIEW_FETCH_FLIGHTS")
  widget.head:SetText(widget.title)
  widget.scroll = Bricks.create("scroll", root)
  widget.scroll:SetMode("VERTICAL")
  widget.empty = Bricks.text(widget.scroll.child, "small", "muted")
  widget.empty:SetPoint("TOPLEFT", widget.scroll.child, "TOPLEFT", 0, -4)
  widget.empty:SetText(word("QUEUEVIEW_FETCH_NONE"))

  for index = 1, 6 do
    widget.pills[index] = Parts.pill(root)
  end

  root:SetScript("OnSizeChanged", function()
    layout(widget)
    paintFlights(widget)
  end)

  function widget:SetFetch(view, holders, flights)
    local summary = view
    if type(view) == "table" and (view.flights or view.holders) then
      summary, flights = view.fetch or view, view.flights
    end

    summary = type(summary) == "table" and summary or {}
    self.flights = type(flights) == "table" and flights or {}

    local texts = figures(summary)
    local title = word("QUEUEVIEW_FETCH_FLIGHTS")
    local sig = concat(texts, "|") .. "|" .. title .. "|" .. shapeSignature("line")

    if self.mem ~= sig then
      self.mem = sig
      self.layoutSig = nil
      self.head:SetText(title)

      for index, pill in ipairs(self.pills) do
        pill:Set(texts[index])
      end
    end

    layout(self)
    paintFlights(self)
  end

  function widget:Holders()
    return self.slot
  end

  return widget
end
