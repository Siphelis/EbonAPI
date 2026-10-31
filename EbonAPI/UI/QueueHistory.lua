EbonAPI = EbonAPI or {}
EbonAPI.QueueStrips = EbonAPI.QueueStrips or {}

-- The History tab of the send queue window: four heat strips of 150 cells (two seconds each, the
-- larger of the two), an axis, then ten thumbnails of 30 seconds. `:SetHistory(Queue.history(300))`
-- repaints only the cells, texts and bars whose values changed; nothing is created after the build.

local QueueStrips = EbonAPI.QueueStrips
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Bricks = EbonAPI.Bricks
local QueueParts = EbonAPI.QueueParts

local floor, ceil, max, min, format = math.floor, math.ceil, math.max, math.min, string.format
local pcall, tonumber, tostring, type = pcall, tonumber, tostring, type

local THEME = Palette.THEME
local NBSP = "\194\160"
local CELLS, SECONDS, TILES, STEP, BARS = 150, 300, 10, 30, 6
-- top of the flow text in a thumbnail: it takes two lines (in, then out), the thumbnail is raised to hold them
local FLOW_Y = 58
local SERIES = {
  { id = "len", title = "QUEUEVIEW_HIST_LEN", scale = 500, color = "heading", kind = "number" },
  { id = "ins", title = "QUEUEVIEW_HIST_IN", scale = 50, color = "focus", kind = "rate" },
  { id = "outs", title = "QUEUEVIEW_HIST_OUT", scale = 25, color = "success", kind = "rate" },
  { id = "peak", title = "QUEUEVIEW_HIST_WAIT", scale = 60, color = "caution", kind = "seconds" },
}

local function word(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

local function S(key, fallback)
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

local function sig(key)
  local color = THEME[key] or THEME.text

  return color[1] + color[2] * 1000 + color[3] * 1000000
end

local function tint(target, method, key, alpha)
  local color = THEME[key] or THEME.text
  target[method](target, color[1], color[2], color[3], alpha or 1)
end

local function relative(t)
  if t == 0 then
    return word("QUEUEVIEW_HIST_NOW")
  end

  local s = -t
  if s < 60 then
    return format(word("QUEUEVIEW_HIST_AGO_S"), s)
  end

  if s % 60 == 0 then
    return format(word("QUEUEVIEW_HIST_AGO_M"), floor(s / 60))
  end

  return format(word("QUEUEVIEW_HIST_AGO_MS"), floor(s / 60), s % 60)
end

local function shown(kind, v)
  if kind == "number" then
    return QueueParts.number(v)
  elseif kind == "seconds" then
    return QueueParts.seconds(v)
  end

  return QueueParts.decimal(v, 1)
end

local function box(frame, shape, bgKey, edgeKey)
  local solid = S("media.solid", "Interface\\Buttons\\WHITE8X8")
  local id = shape .. solid
  if frame.stripShape ~= id then
    if shape == "round" then
      frame:SetBackdrop({ bgFile = solid, edgeFile = S("media.rounded", solid), edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    else
      frame:SetBackdrop({ bgFile = solid, edgeFile = solid, edgeSize = 1 })
    end
    frame.stripShape = id
  end

  tint(frame, "SetBackdropColor", bgKey, 1)
  tint(frame, "SetBackdropBorderColor", edgeKey, 1)
end

-- The value of second `i` (1 to 300, oldest first) of a series, zero before the history starts.
local function at(list, n, i)
  local real = i - (SECONDS - n)
  if real < 1 then
    return 0
  end

  return num(list and list[real])
end

function QueueStrips.history(parent, opts)
  opts = opts or {}

  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local strip = { frame = frame, stats = { paints = 0 }, rows = {}, tiles = {}, data = {}, mem = {} }
  local solid = S("media.solid", "Interface\\Buttons\\WHITE8X8")

  function strip:Frame()
    return frame
  end

  local function tip(row, index)
    local line = strip.rows[row]
    if not line or not GameTooltip then
      return
    end

    GameTooltip:SetOwner(line.heat, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(strip:TipText(row, index), 1, 1, 1)
    GameTooltip:Show()
  end

  function strip:TipText(row, index)
    local line = self.rows[row]
    local v = line and line.values[index] or 0

    return format(word("QUEUEVIEW_HIST_TIP"), relative((index - 1) * 2 - (SECONDS - 2)), shown("rate", v))
  end

  for r, spec in ipairs(SERIES) do
    local line = { spec = spec, values = {}, cells = {}, alphas = {}, mem = {} }
    line.name = Bricks.text(frame, "small", "muted")
    line.name:SetJustifyH("LEFT")
    line.value = Bricks.text(frame, "normal", "title")
    line.value:SetJustifyH("LEFT")
    line.heat = CreateFrame("Frame", nil, frame)
    line.heat:EnableMouse(true)
    for g = 1, CELLS do
      local cell = line.heat:CreateTexture(nil, "ARTWORK")
      cell:SetTexture(solid)
      cell:SetAlpha(0)
      line.cells[g], line.alphas[g], line.values[g] = cell, 0, 0
    end

    line.heat:SetScript("OnEnter", function(self)
      self.hover = true
      self:SetScript("OnUpdate", function(this)
        local cw = line.cellWidth
        local left = this:GetLeft()
        if not cw or cw <= 0 or not left or not GetCursorPosition then
          return
        end

        local x = GetCursorPosition() / this:GetEffectiveScale() - left - (line.inset or 1)
        local index = max(1, min(CELLS, floor(x / cw) + 1))
        if line.tipIndex ~= index then
          line.tipIndex = index
          tip(r, index)
        end
      end)
    end)
    line.heat:SetScript("OnLeave", function(self)
      self.hover = nil
      line.tipIndex = nil
      self:SetScript("OnUpdate", nil)
      if GameTooltip then
        GameTooltip:Hide()
      end
    end)

    strip.rows[r] = line
  end

  strip.axis = {}
  for i = 1, 6 do
    strip.axis[i] = Bricks.text(frame, "small", "muted")
    strip.axis[i]:SetText(i == 1 and format(word("QUEUEVIEW_HIST_AGO_M"), 5) or (i == 6 and word("QUEUEVIEW_HIST_NOW") or format(word("QUEUEVIEW_HIST_AXIS"), 6 - i)))
  end

  for j = 1, TILES do
    local tile = CreateFrame("Frame", nil, frame)
    tile.when = Bricks.text(tile, "small", "muted")
    tile.when:SetJustifyH("LEFT")
    tile.avg = Bricks.text(tile, "normal", "title")
    tile.avg:SetJustifyH("LEFT")
    tile.flow = Bricks.text(tile, "small", "muted")
    tile.flow:SetJustifyH("LEFT")
    tile.flow:SetJustifyV("TOP")
    tile.mem = {}
    tile.bars, tile.heights = {}, {}
    for k = 1, BARS do
      local bar = tile:CreateTexture(nil, "ARTWORK")
      bar:SetTexture(solid)
      bar:Hide()
      tile.bars[k], tile.heights[k] = bar, 0
    end

    strip.tiles[j] = tile
  end

  function strip:Layout(width)
    local labelW = tonumber(S("widgets.strip.label", 84)) or 84
    local rowH = tonumber(S("widgets.strip.height", 26)) or 26
    local gapRow = tonumber(S("widgets.strip.gap", 6)) or 6
    local tileH = tonumber(S("widgets.strip.tile", 74)) or 74
    local sample = self.tiles[1].flow
    local ok, _, size = pcall(sample.GetFont, sample)
    local line = ceil(ok and tonumber(size) or 11) + 1
    tileH = max(tileH, FLOW_Y + 2 * line + 4)
    local shape = S("widgets.strip.shape", "bevel")
    if shape ~= "round" then
      shape = "square"
    end

    local key = width .. ":" .. labelW .. ":" .. rowH .. ":" .. gapRow .. ":" .. tileH .. ":" .. shape
    if self.mem.layout == key then
      return
    end

    self.mem.layout = key
    self.shape = shape
    self.width = width
    local inset = shape == "round" and 3 or 1
    local heatW = max(CELLS, width - labelW - 10)
    local cw = (heatW - inset * 2) / CELLS

    for r, line in ipairs(self.rows) do
      local y = -(r - 1) * (rowH + gapRow)
      line.name:ClearAllPoints()
      line.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y - 1)
      line.name:SetWidth(labelW)
      line.value:ClearAllPoints()
      line.value:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y - 14)
      line.value:SetWidth(labelW)
      line.heat:ClearAllPoints()
      line.heat:SetPoint("TOPLEFT", frame, "TOPLEFT", labelW + 10, y)
      line.heat:SetSize(heatW, rowH)
      line.cellWidth, line.inset = cw, inset
      for g = 1, CELLS do
        local cell = line.cells[g]
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", line.heat, "TOPLEFT", inset + (g - 1) * cw, -inset)
        cell:SetSize(cw, rowH - inset * 2)
      end

      line.mem.box = nil
    end

    local axisY = -4 * (rowH + gapRow) + gapRow - 2
    local span = heatW / 5
    for i, text in ipairs(self.axis) do
      text:ClearAllPoints()
      if i == 1 then
        text:SetPoint("TOPLEFT", frame, "TOPLEFT", labelW + 10, axisY)
      elseif i == 6 then
        text:SetPoint("TOPRIGHT", frame, "TOPLEFT", labelW + 10 + heatW, axisY)
      else
        text:SetPoint("TOP", frame, "TOPLEFT", labelW + 10 + (i - 1) * span, axisY)
      end
    end

    local tilesY = axisY - 20
    local gap = 6
    local tileW = max(20, (width - gap * (TILES - 1)) / TILES)
    local barW = max(2, min(10, floor((tileW - 12 - (BARS - 1) * 2) / BARS)))
    for j, tile in ipairs(self.tiles) do
      tile:ClearAllPoints()
      tile:SetPoint("TOPLEFT", frame, "TOPLEFT", (j - 1) * (tileW + gap), tilesY)
      tile:SetSize(tileW, tileH)
      tile.when:ClearAllPoints()
      tile.when:SetPoint("TOPLEFT", tile, "TOPLEFT", 6, -5)
      tile.when:SetWidth(tileW - 8)
      for k, bar in ipairs(tile.bars) do
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 6 + (k - 1) * (barW + 2), tileH - 42)
        bar:SetWidth(barW)
      end

      tile.avg:ClearAllPoints()
      tile.avg:SetPoint("TOPLEFT", tile, "TOPLEFT", 6, -45)
      tile.avg:SetWidth(tileW - 8)
      tile.flow:ClearAllPoints()
      tile.flow:SetPoint("TOPLEFT", tile, "TOPLEFT", 6, -FLOW_Y)
      tile.flow:SetWidth(tileW - 8)
      tile.flow:SetHeight(2 * line)
      tile.mem.box = nil
      tile.mem.heights = nil
    end

    self.height = -tilesY + tileH
  end

  function strip:SetHistory(history)
    self.data.last = history

    local width = frame:GetWidth()
    if not width or width < 50 then
      width = parent and parent.GetWidth and parent:GetWidth()
    end

    if not width or width < 50 then
      width = opts.width or 900
    end

    self:Layout(floor(width))

    local stats = self.stats
    local capacity = num(opts.capacity)
    if capacity <= 0 then
      capacity = SERIES[1].scale
    end

    local n = history and floor(num(history.seconds)) or 0
    n = max(0, min(n, SECONDS))
    local shape = self.shape
    local solidKey = S("media.solid", "Interface\\Buttons\\WHITE8X8")
    local lists = history or {}

    for r, line in ipairs(self.rows) do
      local spec = line.spec
      local scale = r == 1 and capacity or spec.scale
      local list = lists[spec.id]
      local colorSig = sig(spec.color)

      local paintBox = line.mem.box ~= shape .. sig("bg") .. sig("borderDim") .. solidKey
      if paintBox then
        line.mem.box = shape .. sig("bg") .. sig("borderDim") .. solidKey
        box(line.heat, shape, "bg", "borderDim")
        stats.paints = stats.paints + 1
      end

      local recolor = line.mem.color ~= colorSig
      line.mem.color = colorSig
      if line.mem.name ~= word(spec.title) then
        line.mem.name = word(spec.title)
        line.name:SetText(line.mem.name)
        stats.paints = stats.paints + 1
      end

      for g = 1, CELLS do
        local i = (g - 1) * 2 + 1
        local v = max(at(list, n, i), at(list, n, i + 1))
        line.values[g] = v

        local alpha = min(1, 0.07 + v / scale * 0.93)
        alpha = floor(alpha * 100 + 0.5) / 100
        local cell = line.cells[g]
        if recolor then
          tint(cell, "SetVertexColor", spec.color, 1)
        end

        if line.alphas[g] ~= alpha then
          line.alphas[g] = alpha
          cell:SetAlpha(alpha)
          stats.paints = stats.paints + 1
        end
      end

      local current = at(list, n, SECONDS)
      local text = shown(spec.kind, current)
      if line.mem.text ~= text then
        line.mem.text = text
        line.value:SetText(text)
        stats.paints = stats.paints + 1
      end

      if line.tipIndex then
        tip(r, line.tipIndex)
      end
    end

    for j, tile in ipairs(self.tiles) do
      local e = j * STEP
      local s = e - STEP
      local ins, outs, total = 0, 0, 0
      local lenList = lists.len
      for i = s + 1, e do
        ins = ins + at(lists.ins, n, i)
        outs = outs + at(lists.outs, n, i)
        total = total + at(lenList, n, i)
      end

      local when = relative(e - SECONDS)
      local avg = QueueParts.number(total / STEP)
      local flow = format(word("QUEUEVIEW_HIST_FLOW"), QueueParts.decimal(ins / STEP, 1), QueueParts.decimal(outs / STEP, 1))
      local boxKey = shape .. sig("card") .. sig("borderDim") .. solidKey

      if tile.mem.box ~= boxKey then
        tile.mem.box = boxKey
        box(tile, shape, "card", "borderDim")
        stats.paints = stats.paints + 1
      end

      if tile.mem.when ~= when then
        tile.mem.when = when
        tile.when:SetText(when)
        stats.paints = stats.paints + 1
      end

      if tile.mem.avg ~= avg then
        tile.mem.avg = avg
        tile.avg:SetText(avg)
        stats.paints = stats.paints + 1
      end

      if tile.mem.flow ~= flow then
        tile.mem.flow = flow
        tile.flow:SetText(flow)
        stats.paints = stats.paints + 1
      end

      local barColor = sig("heading")
      local recolor = tile.mem.barColor ~= barColor
      tile.mem.barColor = barColor
      local room = 22
      for k, bar in ipairs(tile.bars) do
        local len = at(lenList, n, s + (k - 1) * 5 + 1)
        local h = max(1, floor(min(1, len / capacity) * room + 0.5))
        if recolor then
          tint(bar, "SetVertexColor", "heading", 1)
        end

        if tile.heights[k] ~= h then
          tile.heights[k] = h
          bar:SetHeight(h)
          stats.paints = stats.paints + 1
        end

        bar:Show()
      end
    end
  end

  frame:SetScript("OnSizeChanged", function()
    if strip.data.last then
      strip:SetHistory(strip.data.last)
    end
  end)

  return strip
end
