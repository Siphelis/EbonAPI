EbonAPI = EbonAPI or {}
EbonAPI.QueueParts = {}

-- The common pieces of the send queue window: the formats (pure functions) and the small drawn
-- pieces (pill, pips, bar, range, dot, ring, chips). A drawn piece is built once on a parent, then
-- `:Set(...)` redraws it only when its values, the palette or the shape of the skin changed.
-- Shapes: widgets.queue.shape (square, bevel, round), widgets.queue.radius, widgets.queue.gap; each key
-- has a fallback taken from the border style and the corners of the skin, so every skin renders.

local QueueParts = EbonAPI.QueueParts
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Parameters = EbonAPI.Parameters
local Bricks = EbonAPI.Bricks

local format, gsub, floor, ceil, max, min = string.format, string.gsub, math.floor, math.ceil, math.max, math.min
local pcall, tostring, tonumber, type, ipairs, setmetatable = pcall, tostring, tonumber, type, ipairs, setmetatable

local THEME = Palette.THEME
local NBSP = "\194\160"
local PIPS = 16
local RING_STEPS = 40

QueueParts.LIMITS = { wait = { 10, 30 }, average = { 5, 20 }, flow = { 1, 3 }, range = { 30, 60 } }

local LEVEL_COLOR = { ok = "success", warn = "caution", bad = "danger" }
local LEVEL_FILL = { ok = "success", warn = "caution", bad = "danger", accent = "heading" }

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

local function round1(n)
  return floor(num(n) * 10 + 0.5) / 10
end

function QueueParts.number(n)
  n = floor(num(n) + 0.5)

  local text, count = format("%.0f", n < 0 and -n or n), 1

  while count > 0 do
    text, count = gsub(text, "^(%d+)(%d%d%d)", "%1" .. NBSP .. "%2")
  end

  return (n < 0 and "-" or "") .. text
end

local function separator()
  local L = EbonAPI.L

  return (L and L.NUMBER_DECIMAL) or "."
end

function QueueParts.decimal(n, digits)
  local text = format("%." .. floor(num(digits)) .. "f", num(n))

  return (gsub(text, "%.", separator()))
end

local function trimmed(n)
  local text = format("%.1f", round1(n))
  if text:sub(-2) == ".0" then
    text = text:sub(1, -3)
  end

  return (gsub(text, "%.", separator()))
end

function QueueParts.seconds(n)
  return format(word("QUEUEVIEW_SECONDS"), QueueParts.decimal(round1(n), 1))
end

function QueueParts.duration(s)
  s = max(0, num(s))
  if round1(s) < 60 then
    return QueueParts.seconds(s)
  end

  local minutes = floor(s / 60 + 0.5)
  if minutes < 60 then
    return format(word("QUEUEVIEW_MINUTES"), QueueParts.number(minutes))
  end

  local hours, rest = floor(minutes / 60), minutes % 60
  if rest == 0 then
    return format(word("QUEUEVIEW_HOURS"), QueueParts.number(hours))
  end

  return format(word("QUEUEVIEW_HOURS_MINUTES"), QueueParts.number(hours), rest)
end

function QueueParts.ago(s)
  if num(s) < 0.5 then
    return word("QUEUEVIEW_NOW")
  end

  return QueueParts.duration(s)
end

function QueueParts.span(a, b)
  a, b = max(0, num(a)), max(0, num(b))
  if round1(a) < 60 and round1(b) < 60 then
    return format(word("QUEUEVIEW_SPAN"), trimmed(a), format(word("QUEUEVIEW_SECONDS"), trimmed(b)))
  end

  return format(word("QUEUEVIEW_SPAN"), QueueParts.duration(a), QueueParts.duration(b))
end

function QueueParts.level(n, limits)
  n = num(n)
  limits = limits or QueueParts.LIMITS.wait
  if n >= limits[2] then
    return "bad"
  elseif n >= limits[1] then
    return "warn"
  end

  return "ok"
end

function QueueParts.levelColor(level)
  return LEVEL_COLOR[level] or "text"
end

-- No colour per addon: every lane takes the accent.
function QueueParts.laneColor(lane)
  return "focus"
end

local function pipCount(left, total)
  total = max(0, floor(num(total) + 0.5))
  local n = min(PIPS, total)
  if n == 0 then
    return 0, 0
  end

  left = min(total, max(0, num(left)))

  return min(n, max(0, floor((total - left) / total * n + 0.5))), n
end

function QueueParts.heldText(held, secs)
  local name = word("QUEUEVIEW_HELD_WORD_" .. tostring(held))
  if held == "offline" then
    return format("%s %s", name, format(word("QUEUEVIEW_SECONDS"), QueueParts.number(secs)))
  end

  return format("%s %s", name, QueueParts.seconds(secs))
end

local function hue(key)
  local color = THEME[key] or THEME.text

  return color[1] + color[2] * 1000 + color[3] * 1000000
end

local function tint(target, method, key, alpha)
  local color = THEME[key] or THEME.text
  target[method](target, color[1], color[2], color[3], alpha or 1)
end

local function same(mem, a, b, c, d, e, f)
  if mem.a == a and mem.b == b and mem.c == c and mem.d == d and mem.e == e and mem.f == f then
    return true
  end

  mem.a, mem.b, mem.c, mem.d, mem.e, mem.f = a, b, c, d, e, f

  return false
end

local function media(key, fallback)
  return value("media." .. key, fallback)
end

local function look()
  local ok, corners = pcall(Parameters.value, nil, "corners")
  local round = ok and tonumber(corners) or 0
  local shape = value("widgets.queue.shape")
  if shape ~= "square" and shape ~= "bevel" and shape ~= "round" then
    shape = round > 0 and "round" or (value("border.style") == "TEXTURE" and "bevel" or "square")
  end

  local radius = tonumber(value("widgets.queue.radius")) or (shape == "round" and max(3, min(round, 8)) or 0)
  local gap = tonumber(value("widgets.queue.gap")) or 1

  return shape, max(0, radius), max(0, gap)
end

local FRAME = { Frame = function(self) return self.frame end }

local function piece(t)
  return setmetatable(t, { __index = FRAME })
end

local backdrops = {}

local function backdropOf(shape, radius, edgeOnly)
  local id = shape .. radius .. (edgeOnly and "e" or "f")
  local backdrop = backdrops[id]
  if not backdrop then
    local solid = media("solid", "Interface\\Buttons\\WHITE8X8")
    if shape == "round" then
      local edge = max(4, radius)
      local inset = floor(edge * 0.25)
      backdrop = {
        bgFile = (not edgeOnly) and solid or nil, edgeFile = media("rounded", solid), edgeSize = edge,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
      }
    else
      backdrop = { bgFile = (not edgeOnly) and solid or nil, edgeFile = solid, edgeSize = 1 }
    end

    backdrops[id] = backdrop
  end

  return backdrop
end

local function shape_frame(frame, shape, radius, edgeOnly)
  local id = shape .. radius .. (edgeOnly and "e" or "f")
  if frame.queueShape ~= id then
    frame:SetBackdrop(backdropOf(shape, radius, edgeOnly))
    frame.queueShape = id
  end
end

local function hide_or_show(target, on)
  if on then
    target:Show()
  else
    target:Hide()
  end
end

local function shine(frame, on)
  if on and not frame.shine then
    local texture = frame:CreateTexture(nil, "ARTWORK")

    texture:SetTexture(media("solid", "Interface\\Buttons\\WHITE8X8"))
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    texture:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.16)
    frame.shine = texture
  end

  if frame.shine then
    hide_or_show(frame.shine, on)
  end
end

local function edgeColor(frame, shape, key, alpha)
  if shape == "bevel" then
    frame:SetBackdropBorderColor(0, 0, 0, 1)
  else
    tint(frame, "SetBackdropBorderColor", key, alpha)
  end
end

function QueueParts.pill(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local pill = piece({ frame = frame, mem = {} })
  pill.text = Bricks.text(frame, "small", "text")
  pill.text:SetPoint("CENTER", frame, "CENTER", 0, 0)

  function pill:SetWidth(width)
    self.fixed = tonumber(width)
    self.mem.a = nil
    if self.fixed then
      frame:SetWidth(self.fixed)
    end
  end

  function pill:Set(text, level)
    text = text == nil and "" or tostring(text)
    local key = LEVEL_FILL[level]
    local shape, radius = look()
    if same(self.mem, text, level, shape, radius, hue(key or "muted"), self.fixed) then
      return
    end

    shape_frame(frame, shape, radius)
    tint(frame, "SetBackdropColor", key or "muted", 0.2)
    edgeColor(frame, shape, key or "muted", 0.5)
    shine(frame, shape == "bevel")
    Palette.paint(self.text, "SetTextColor", key or "muted")
    self.text:SetText(text)
    self.shape = shape
    frame:SetHeight(tonumber(value("widgets.queue.pill.height")) or 16)
    frame:SetWidth(self.fixed or ceil((self.text:GetStringWidth() or 0) + (tonumber(value("widgets.queue.pill.pad")) or 6) * 2))
  end

  return pill
end

function QueueParts.dot(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local dot = piece({ frame = frame, mem = {} })
  local size = tonumber(value("widgets.queue.dot.size")) or 8
  frame:SetWidth(size)
  frame:SetHeight(size)
  dot.texture = frame:CreateTexture(nil, "ARTWORK")

  function dot:Set(lane)
    local key = "muted"
    local shape = look()
    if same(self.mem, key, shape, hue(key)) then
      return
    end

    local texture = self.texture
    texture:ClearAllPoints()
    if shape == "round" then
      frame:SetBackdrop(nil)
      frame.queueShape = "none"
      texture:SetTexture(media("circle", "Interface\\AddOns\\EbonAPI\\Media\\Circle"))
      texture:SetAllPoints(frame)
    elseif shape == "bevel" then
      shape_frame(frame, "bevel", 0, true)
      frame:SetBackdropBorderColor(0, 0, 0, 1)
      texture:SetTexture(media("solid", "Interface\\Buttons\\WHITE8X8"))
      texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
      texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    else
      frame:SetBackdrop(nil)
      frame.queueShape = "none"
      texture:SetTexture(media("solid", "Interface\\Buttons\\WHITE8X8"))
      texture:SetAllPoints(frame)
    end

    tint(texture, "SetVertexColor", key)
    self.shape, self.key = shape, key
  end

  return dot
end

local function pipPiece(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local pips = piece({ frame = frame, mem = {}, steps = {} })
  local solid = media("solid", "Interface\\Buttons\\WHITE8X8")
  for i = 1, PIPS do
    local step = frame:CreateTexture(nil, "ARTWORK")
    step:SetTexture(solid)
    step:SetWidth(4)
    step:SetHeight(10)
    step:SetPoint("LEFT", frame, "LEFT", (i - 1) * 5, 0)
    pips.steps[i] = step
  end

  frame:SetHeight(10)
  frame:SetWidth(PIPS * 5 - 1)

  function pips:Set(left, total, lane)
    local on, n = pipCount(left, total)
    local key = QueueParts.laneColor(lane)
    if same(self.mem, on, n, key, hue(key), hue("muted")) then
      return
    end

    for i, step in ipairs(self.steps) do
      if i > n then
        step:Hide()
      else
        step:Show()
        if i <= on then
          tint(step, "SetVertexColor", key, 1)
        else
          tint(step, "SetVertexColor", "muted", 0.35)
        end
      end
    end

    frame:SetWidth(max(1, n * 5 - 1))
    self.on, self.n = on, n
  end

  return pips
end

-- One name, two uses: pips(left, total) counts the steps, pips(parent) builds the piece.
function QueueParts.pips(first, total)
  if type(first) == "table" then
    return pipPiece(first)
  end

  return pipCount(first, total)
end

local function fillBar(bar)
  local frame, fill = bar.frame, bar.fill
  local inset = bar.inset or 1
  local width = max(0, (frame:GetWidth() or 0) - inset * 2)
  local filled = floor(width * (bar.fraction or 0) + 0.5)
  fill:ClearAllPoints()
  fill:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
  fill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
  fill:SetWidth(max(1, filled))
  hide_or_show(fill, filled > 0)
  bar.filled = filled
end

function QueueParts.bar(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local bar = piece({ frame = frame, mem = {}, fraction = 0 })
  frame:SetWidth(tonumber(value("widgets.queue.bar.width")) or 60)
  bar.fill = frame:CreateTexture(nil, "ARTWORK")
  bar.fill:SetTexture(media("solid", "Interface\\Buttons\\WHITE8X8"))
  frame:SetScript("OnSizeChanged", function()
    fillBar(bar)
  end)


  function bar:Set(fraction, colorKey)
    fraction = min(1, max(0, num(fraction)))
    local shape, radius = look()
    local key = THEME[colorKey] and colorKey or "heading"
    if same(self.mem, fraction, key, shape, radius, hue(key), frame:GetWidth()) then
      return
    end

    shape_frame(frame, shape, radius)
    tint(frame, "SetBackdropColor", shape == "bevel" and "shadow" or "borderDim", shape == "bevel" and 0.6 or 0.5)
    edgeColor(frame, shape, "borderDim", 0.5)
    tint(self.fill, "SetVertexColor", key)
    if self.fill.SetGradientAlpha and shape == "bevel" then
      local color = THEME[key]
      self.fill:SetGradientAlpha("VERTICAL", color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 1,
        min(1, color[1] * 1.2), min(1, color[2] * 1.2), min(1, color[3] * 1.2), 1)
    end

    frame:SetHeight(tonumber(value("widgets.queue.bar.height")) or (shape == "bevel" and 8 or 6))
    self.inset = shape == "round" and max(1, floor(radius / 3)) or 1
    self.fraction, self.shape = fraction, shape
    fillBar(self)
  end

  return bar
end

function QueueParts.range(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local range = piece({ frame = frame, mem = {} })
  local solid = media("solid", "Interface\\Buttons\\WHITE8X8")
  frame:SetWidth(tonumber(value("widgets.queue.range.width")) or 80)
  frame:SetHeight(10)
  range.track = frame:CreateTexture(nil, "BACKGROUND")
  range.track:SetTexture(solid)
  range.track:SetPoint("LEFT", frame, "LEFT", 0, 0)
  range.track:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  range.track:SetHeight(4)
  tint(range.track, "SetVertexColor", "borderDim", 0.6)
  range.fill = frame:CreateTexture(nil, "ARTWORK")
  range.fill:SetTexture(solid)
  range.fill:SetHeight(4)
  range.mark = frame:CreateTexture(nil, "OVERLAY")
  range.mark:SetTexture(solid)
  range.mark:SetWidth(2)
  range.mark:SetHeight(10)

  function range:Set(avg, maximum, scale)
    avg, maximum = max(0, num(avg)), max(0, num(maximum))
    maximum = max(avg, maximum)
    scale = num(scale)
    if scale <= 0 then
      scale = max(maximum, 1)
    end

    local key = LEVEL_COLOR[QueueParts.level(maximum, QueueParts.LIMITS.range)]
    local width = frame:GetWidth() or 0
    if same(self.mem, avg, maximum, scale, hue(key), width, hue("text")) then
      return
    end

    local from = floor(min(1, avg / scale) * width + 0.5)
    local to = floor(min(1, maximum / scale) * width + 0.5)
    self.fill:ClearAllPoints()
    self.fill:SetPoint("LEFT", frame, "LEFT", from, 0)
    self.fill:SetWidth(max(1, to - from))
    tint(self.fill, "SetVertexColor", key, 0.6)
    self.mark:ClearAllPoints()
    self.mark:SetPoint("LEFT", frame, "LEFT", min(max(0, width - 2), from), 0)
    tint(self.mark, "SetVertexColor", "text")
    self.color, self.from, self.to = key, from, to
  end

  return range
end

local function ringCoords(step)
  local Views = EbonAPI.SavesViews
  if Views and Views.ringCoords then
    return Views.ringCoords(step)
  end

  return 0, 1, 0, 1
end

function QueueParts.ring(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local ring = piece({ frame = frame, mem = {} })
  local size = tonumber(value("widgets.queue.ring.size")) or 36
  local texture = media("ring", "Interface\\AddOns\\EbonAPI\\Media\\Ring.tga")
  frame:SetWidth(size)
  frame:SetHeight(size)
  ring.track = frame:CreateTexture(nil, "ARTWORK")
  ring.track:SetTexture(texture)
  ring.track:SetAllPoints(frame)
  ring.track:SetTexCoord(ringCoords(RING_STEPS))
  tint(ring.track, "SetVertexColor", "muted", 0.3)
  ring.arc = frame:CreateTexture(nil, "OVERLAY")
  ring.arc:SetTexture(texture)
  ring.arc:SetAllPoints(frame)
  ring.text = Bricks.text(frame, "small", "text")
  ring.text:SetPoint("CENTER", frame, "CENTER", 0, 0)

  function ring:Set(fraction, text, colorKey)
    fraction = min(1, max(0, num(fraction)))
    text = text == nil and "" or tostring(text)
    local key = THEME[colorKey] and colorKey or tostring(value("widgets.queue.ring.color", "success"))
    local step = floor(fraction * RING_STEPS + 0.5)
    if same(self.mem, step, text, key, hue(key), hue("muted")) then
      return
    end

    tint(self.track, "SetVertexColor", "muted", 0.3)
    tint(self.arc, "SetVertexColor", key)
    self.arc:SetTexCoord(ringCoords(step))
    hide_or_show(self.arc, step > 0)
    self.text:SetText(text)
    self.step = step
  end

  return ring
end

local function newChip(owner)
  local button = CreateFrame("Button", nil, owner.frame)
  local chip = { button = button }
  chip.dot = QueueParts.dot(button)
  chip.dot:Frame():SetPoint("LEFT", button, "LEFT", 8, 0)
  chip.label = Bricks.text(button, "small", "text")
  chip.count = Bricks.text(button, "small", "muted")
  button:SetScript("OnClick", function()
    if owner.onPick and chip.key ~= nil then
      owner.onPick(chip.key)
    end
  end)

  return chip
end

function QueueParts.chips(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local chips = piece({ frame = frame, mem = {}, pool = {} })
  frame:SetHeight(22)

  function chips:Set(list, activeKey, onPick)
    list = list or {}
    self.onPick = onPick
    local shape, radius, gap = look()
    local signature = {}
    for i, item in ipairs(list) do
      signature[i] = tostring(item.key) .. "|" .. tostring(item.label) .. "|" .. tostring(item.count) .. "|" .. tostring(item.laneKey)
    end

    local sig = table.concat(signature, ";")
    if same(self.mem, sig, activeKey, shape, radius, hue("focus"), hue("borderDim")) then
      return self.width
    end

    local x = 0
    for i, item in ipairs(list) do
      local chip = self.pool[i]
      if not chip then
        chip = newChip(self)
        self.pool[i] = chip
      end

      local button = chip.button
      local active = activeKey ~= nil and item.key == activeKey
      chip.key = item.key
      chip.dot:Set(item.laneKey)
      chip.label:SetText(tostring(item.label or ""))
      chip.count:SetText(item.count ~= nil and QueueParts.number(item.count) or "")
      chip.label:ClearAllPoints()
      chip.label:SetPoint("LEFT", button, "LEFT", 22, 0)
      chip.count:ClearAllPoints()
      chip.count:SetPoint("LEFT", chip.label, "RIGHT", 6, 0)
      shape_frame(button, shape, radius)
      tint(button, "SetBackdropColor", active and "focus" or "card", active and 0.2 or 0)
      edgeColor(button, shape, active and "focus" or "borderDim", 1)
      local width = ceil(22 + (chip.label:GetStringWidth() or 0) + (item.count ~= nil and 6 + (chip.count:GetStringWidth() or 0) or 0) + 8)
      button:SetHeight(22)
      button:SetWidth(width)
      button:ClearAllPoints()
      button:SetPoint("LEFT", frame, "LEFT", x, 0)
      button:Show()
      x = x + width + 6 + gap
    end

    for i = #list + 1, #self.pool do
      self.pool[i].button:Hide()
      self.pool[i].key = nil
    end

    self.width, self.shape, self.active = max(0, x - 6 - gap), shape, activeKey
    frame:SetWidth(max(1, self.width))

    return self.width
  end

  return chips
end
