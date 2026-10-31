EbonAPI = EbonAPI or {}
EbonAPI.QueueBand = EbonAPI.QueueBand or {}

-- The band of five tiles of the send-queue window: balance over 10 s, wait of what left, oldest waiting,
-- total since the start, send rate. It is the synthesis brick of the skin, forced to one row.
-- build(parent, opts) makes it; band:Refresh(snap) takes the summary of Queue.view() and repaints only
-- the tiles whose numbers changed.

local QueueBand = EbonAPI.QueueBand
local Bricks = EbonAPI.Bricks
local Parts = EbonAPI.QueueParts
local Tiles = EbonAPI.Tiles

local format, floor = string.format, math.floor
local ipairs, pcall, tonumber, type = ipairs, pcall, tonumber, type

QueueBand.COLUMNS = 5
QueueBand.GAP = 7

-- Skin forms that show the sub-text on a single line: both lines are joined with a separator there.
local ONE_LINE = { cards = true }

local function S(key, fallback)
  local ok, value = pcall(Bricks.value, key)

  if ok and value ~= nil then
    return value
  end

  return fallback
end

local function num(value)
  value = tonumber(value)

  if value == nil or value ~= value or value == 1 / 0 or value == -1 / 0 then
    return 0
  end

  return value
end

local function one(value)
  return Parts.decimal(floor(num(value) * 10 + 0.5) / 10, 1)
end

local function signed(value)
  value = floor(num(value) * 10 + 0.5) / 10

  return (value < 0 and "-" or "+") .. Parts.decimal(value < 0 and -value or value, 1)
end

local function lines(first, second)
  if ONE_LINE[S("widgets.synthesis.brick", "default")] then
    return first .. " · " .. second
  end

  return first .. "\n" .. second
end

-- split = true: the two sub-lines stay apart (item.sub, item.sub2) for the four-line cards of the block row.
local function items(snap, split)
  local L = EbonAPI.L
  local lines = split and function(first, second)
    return first .. "\n" .. second
  end or lines

  local rate = snap.rate or {}
  local sent = snap.sent or {}
  local dropped = snap.dropped or {}
  local in10, out10, in60, out60 = num(rate.in10), num(rate.out10), num(rate.in60), num(rate.out60)
  local net10, net60 = in10 - out10, in60 - out60
  local wait10, wait60, peak10, peak60 = num(rate.wait10), num(rate.wait60), num(rate.peak10), num(rate.peak60)
  local oldest, drain, interval = num(snap.oldest), num(snap.drain), num(snap.interval)
  local pace = interval > 0 and 1 / interval or 0
  local total = num(sent.whisper) + num(sent.channel) + num(sent.server)
  local failed = num(dropped.failed)
  local millis = Parts.number(interval * 1000)
  local drainText = Parts.number(drain)
  local paceText = one(pace)

  local list = {
    {
      id = "flow", label = L.QUEUEVIEW_BAND_FLOW, level = Parts.level(net10, Parts.LIMITS.flow),
      value = format(L.QUEUEVIEW_BAND_FLOW_VALUE, signed(net10)),
      sub = lines(format(L.QUEUEVIEW_BAND_FLOW_1, one(in10), one(out10)),
        format(L.QUEUEVIEW_BAND_FLOW_2, one(in60), one(out60), signed(net60))),
      tip = format(L.QUEUEVIEW_BAND_FLOW_TIP, one(in10), one(out10), signed(net10), one(in60), one(out60), signed(net60)),
    },
    {
      id = "wait", label = L.QUEUEVIEW_BAND_WAIT, level = Parts.level(wait10, Parts.LIMITS.average),
      value = Parts.seconds(wait10),
      sub = lines(format(L.QUEUEVIEW_BAND_WAIT_1, Parts.seconds(peak10)),
        format(L.QUEUEVIEW_BAND_WAIT_2, one(wait60), Parts.seconds(peak60))),
      tip = format(L.QUEUEVIEW_BAND_WAIT_TIP, Parts.seconds(wait10), Parts.seconds(peak10), Parts.seconds(wait60),
        Parts.seconds(peak60)),
    },
    {
      id = "oldest", label = L.QUEUEVIEW_BAND_OLDEST, level = Parts.level(oldest, Parts.LIMITS.wait),
      value = Parts.seconds(oldest),
      sub = lines(format(L.QUEUEVIEW_BAND_OLDEST_1, drainText), format(L.QUEUEVIEW_BAND_OLDEST_2, paceText)),
      tip = format(L.QUEUEVIEW_BAND_OLDEST_TIP, Parts.seconds(oldest), drainText, paceText),
    },
    {
      id = "total", label = L.QUEUEVIEW_BAND_TOTAL, level = failed > 0 and "warn" or "info",
      value = format(L.QUEUEVIEW_BAND_TOTAL_VALUE, Parts.number(total)),
      sub = lines(format(L.QUEUEVIEW_BAND_TOTAL_1, Parts.number(num(sent.channel)), Parts.number(num(sent.server))),
        format(L.QUEUEVIEW_BAND_TOTAL_2, Parts.number(num(dropped.offline)), Parts.number(num(dropped.full)),
          Parts.number(failed))),
      tip = format(L.QUEUEVIEW_BAND_TOTAL_TIP, Parts.number(num(sent.whisper)), Parts.number(num(sent.channel)),
        Parts.number(num(sent.server)), Parts.number(num(dropped.full)), Parts.number(num(dropped.offline)), Parts.number(failed)),
    },
    {
      id = "pace", label = L.QUEUEVIEW_BAND_PACE, level = "info",
      value = format(L.QUEUEVIEW_BAND_PACE_VALUE, paceText),
      sub = lines(format(L.QUEUEVIEW_BAND_PACE_1, millis), L.QUEUEVIEW_BAND_PACE_2),
      tip = format(L.QUEUEVIEW_BAND_PACE_TIP, paceText, millis),
    },
  }

  if split then
    for _, item in ipairs(list) do
      local first, second = item.sub:match("^(.-)\n(.*)$")

      item.sub, item.sub2 = first or item.sub, second or ""
    end
  end

  return list
end

local function same(a, b)
  return a.label == b.label and a.value == b.value and a.sub == b.sub and a.sub2 == b.sub2 and a.level == b.level
    and a.tip == b.tip
end

-- The four-line card (box.arrange, called by Tiles after the look painted the tile): label, value, sub-line 1 and
-- sub-line 2 stacked from the top, each with its own size from the skin; the look keeps the frame and the marker.
local PAD, SPACE = 4, 3
local ROLES = { "label", "value", "sub1", "sub2" }
local SIZES = { label = 10.5, value = 20, sub1 = 11.5, sub2 = 10.5 }

local function setSize(fs, role, size)
  Bricks.font(fs, role)

  local ok, file, _, flags = pcall(fs.GetFont, fs)

  if ok and file then
    fs:SetFont(file, size, flags)
  end
end

local function paintSub2(tile)
  if tile.sub2 then
    tile.sub2:SetText(tile.item and tile.item.sub2 or "")
  end
end

-- The marker stands in front of the label, on its line (the label row keeps its room): the look of a skin may centre
-- it in the height of the tile.
local function anchorMarker(tile)
  local marker, spot = tile.marker, tile.spot

  if not marker or not spot or not marker:IsShown() then
    return
  end

  marker:ClearAllPoints()
  marker:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", spot.x + floor((spot.width - marker:GetWidth()) / 2),
    -(spot.y + floor((spot.height - marker:GetHeight()) / 2)))
end

local function arrange(box, tile, width, height)
  local frame = tile.frame
  local labelRole = S("widgets.synthesis.label.font", "small")
  local valueRole = S("widgets.synthesis.value.font", "normal")

  if not tile.sub2 then
    tile.sub2 = Bricks.text(frame, labelRole, "muted")
    tile.sub2:SetJustifyH("LEFT")
    tile.sub2:SetJustifyV("TOP")
  end

  -- a skin look may size the tile to its text (flow looks): the cards of the block row are columns of equal width
  frame:SetWidth(width)
  frame:SetHeight(height)
  tile.label:Show()
  tile.value:Show()
  tile.sub:Show()

  -- what the look of a skin leaves on its tile: the text fields may be centred
  for _, fs in ipairs({ tile.label, tile.value, tile.sub }) do
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
  end

  local size = {}

  for _, name in ipairs(ROLES) do
    size[name] = num(S("widgets.queue.band." .. name .. ".size", SIZES[name]))
  end

  setSize(tile.label, labelRole, size.label)
  setSize(tile.value, valueRole, size.value)
  setSize(tile.sub, labelRole, size.sub1)
  setSize(tile.sub2, labelRole, size.sub2)
  Bricks.paint(tile.sub2, "SetTextColor", "muted")
  paintSub2(tile)

  local inset = Bricks.insetOf(frame) + PAD
  local inner = math.max(1, width - inset * 2)

  -- Optional hook of the look (look.card(tile, size, line, inset)): it hides or resizes what it added to its tile
  -- (blocks, tokens, separators) for the four-line card, and may set tile.markerSize. A look without the hook is
  -- left as it is.
  if type(box.look) == "table" and type(box.look.card) == "function" then
    box.look.card(tile, size, math.ceil(size.label), inset)
  end

  local marker = tile.markerSize or math.ceil(size.label)
  local rows = {
    { fs = tile.label, name = "label", x = inset + marker + SPACE, w = inner - marker - SPACE },
    { fs = tile.value, name = "value", x = inset, w = inner },
    { fs = tile.sub, name = "sub1", x = inset, w = inner },
    { fs = tile.sub2, name = "sub2", x = inset, w = inner },
  }
  local used = 0

  for _, row in ipairs(rows) do
    row.h = math.ceil(size[row.name])
    used = used + row.h
  end

  local spare = height - inset * 2 - used
  local gap = math.max(1, math.min(SPACE * 2, floor(spare / 3)))
  local y = inset

  tile.rows, tile.sizes = {}, size

  for _, row in ipairs(rows) do
    -- the last line may wrap on a second one in the room left under it
    local wrapped = row.name == "sub2" and height - inset - y >= row.h * 2

    row.fs:ClearAllPoints()
    row.fs:SetPoint("TOPLEFT", frame, "TOPLEFT", row.x, -y)
    row.fs:SetWidth(math.max(1, row.w))
    row.fs:SetHeight(wrapped and row.h * 2 or row.h)

    if row.fs.SetWordWrap then
      row.fs:SetWordWrap(wrapped)
    end

    tile.rows[row.name] = { top = y, height = row.h }
    y = y + row.h + gap
  end

  tile.spot = { x = inset, y = inset, width = marker, height = rows[1].h }
  anchorMarker(tile)
end

-- The number takes the colour of its level; the neutral tiles keep the skin's colour.
local function colour(tile)
  local level = tile.item.level
  local key = (level == "ok" or level == "warn" or level == "bad") and Parts.levelColor(level) or "text"

  Bricks.paint(tile.value, "SetTextColor", key)
  tile.band = key
end

local function tiles(band)
  local group = band.box.groups and band.box.groups[1]

  return group and group.tiles or {}
end

function QueueBand.build(parent, opts)
  opts = opts or {}

  local box = Bricks.create("synthesis", parent)
  local band = { box = box, frame = box, shown = nil }

  -- The bag-slot look (Azeroth) puts a 40 px square at the top of the tile, over the four text lines of the card:
  -- the band keeps the default look there.
  if S("widgets.synthesis.brick", "default") == "slots" then
    box.look = Tiles.looks.default
  end

  box.columns = opts.columns or QueueBand.COLUMNS
  -- Fixed gap of 7 between the cards: a skin lookup under widgets.queue.* would inherit the table's own gap (1).
  box.gap = QueueBand.GAP

  if opts.onSelect then
    box.onSelect = opts.onSelect
  end

  function band:SetWidth(width)
    self.box:SetWidth(width)

    for _, tile in ipairs(tiles(self)) do
      colour(tile)
    end

    return self.box:GetHeight()
  end

  function band:Height()
    return self.box:GetHeight()
  end

  -- The cards of the block row: h high, four text lines each. Without this call the band keeps the skin's height.
  function band:SetHeight(height)
    height = num(height)

    if height <= 0 then
      return self.box:GetHeight()
    end

    self.height = height
    self.box.fixedHeight = height
    self.box.arrange = arrange
    self.shown = nil

    if self.last then
      self:Refresh(self.last)
    end

    if self.box.boxWidth then
      return self:SetWidth(self.box.boxWidth)
    end

    return self.box:GetHeight()
  end

  function band:Refresh(snap)
    snap = type(snap) == "table" and snap or {}
    self.last = snap

    local list = items(snap, self.height ~= nil)
    local current = tiles(self)

    if self.shown == nil or #current ~= #list then
      self.box:SetGroups({ { id = "band", items = list } }, nil)
      self.shown = list

      for _, tile in ipairs(tiles(self)) do
        colour(tile)
      end

      return true
    end

    local changed = false

    for index, item in ipairs(list) do
      local tile, old = current[index], current[index].item

      if not same(item, old) then
        tile.item = item
        self.box.look.update(self.box, tile, old)
        anchorMarker(tile)

        if item.tip ~= old.tip then
          Tiles.setTip(tile)
        end

        paintSub2(tile)
        colour(tile)
        changed = true
      end
    end

    self.shown = list

    return changed
  end

  return band
end

return QueueBand
