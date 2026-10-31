EbonAPI = EbonAPI or {}
EbonAPI.Stacked = EbonAPI.Stacked or {}

-- The "stacked" Kit type: bars over time, each bar a stack of one segment per module (detail of an addon on the
-- Performances page: 26 slices of 5 s, one segment per module, the rest folded into an "Others" segment).
--
-- Data contract (api:Create("stacked", parent, spec), then frame:SetSeries(data), or spec.series = a table or a
-- function returning one, read on Refresh and on a skin change):
--   data = {
--     slices  = { { { module = "EbonAPI", value = 12.5 }, { module = "AutoCallboard", value = 3 }, ... }, ... },
--               oldest slice first; one bar per slice; a segment { others = true, value = n } is the "Others" segment.
--     ceiling = optional number: fixed top of the scale. Without it the scale is the highest total of the slices
--               drawn (auto scale on the visible maximum). Bars above a fixed ceiling are clamped to the track.
--     labels  = optional { unit = "ms/s", first = "2:10 ago", last = "now" }: the top of the scale is written as
--               "<max> <unit>" at the top left; first and last go under the first and the last bar.
--     modules = optional list of module names fixing the order of the colors (otherwise the order of first
--               appearance in the slices). The first N modules (N = number of kit.chart.series.sN keys of the skin,
--               at most 5) take the series colors; every other module is folded into the "Others" segment.
--     tips    = optional list (one entry per slice) of { title = text, body = text } or a function
--               (index, slice) returning title, body; shown on the bar's hover. The caller supplies the text.
--   }
-- Segments are stacked bottom-up in the color order, "Others" last (top). The sum of the segment heights of a bar is
-- exactly the bar height. Nothing runs while idle: the frame draws on SetSeries, Refresh and a skin change.
-- Skin keys: kit.chart.series.s1..s5 and kit.chart.others (colors 0xRRGGBB), plus the kit.chart.* keys of the chart.
-- Useful fields for tests and legends: frame.bars[i] (the bar frame, bar.segs[j] its textures, bar.total),
-- frame:Modules() (the colored module names in order), frame:ColorOf(module) (r, g, b of its segment).

local Stacked = EbonAPI.Stacked
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit
local Palette = EbonAPI.Palette
local Lib = EbonAPI.Lib

local format, max, min = string.format, math.max, math.min
local ipairs, pcall, type, tostring, tonumber = ipairs, pcall, type, tostring, tonumber
local S = Bricks.value
local MAX_SERIES = 5

Bricks.CONTRACT.stacked = { "SetSeries", "Modules", "ColorOf" }

local function seriesCount()
  local count = 0

  for index = 1, MAX_SERIES do
    if S("kit.chart.series.s" .. index) then
      count = index
    end
  end

  return count
end

local function colorOf(index)
  local value = index and S("kit.chart.series.s" .. index) or S("kit.chart.others")

  if type(value) ~= "number" then
    return 0.5, 0.5, 0.5
  end

  return Palette.unpackColor(value)
end

local function number(value)
  value = tonumber(value) or 0

  return value > 0 and value or 0
end

local function shown(value)
  if value >= 10 or value == 0 then
    return format("%.0f", value)
  end

  return format("%.1f", value)
end

-- Reads the data: color order of the modules, then per slice the amount of each colored module and of "Others".
local function digest(data, count)
  local order, index = {}, {}

  local function note(name)
    if name ~= nil and not index[name] and #order < count then
      order[#order + 1] = name
      index[name] = #order
    end
  end

  for _, name in ipairs(data.modules or {}) do
    note(name)
  end

  for _, slice in ipairs(data.slices or {}) do
    for _, part in ipairs(slice) do
      if not part.others then
        note(part.module)
      end
    end
  end

  local rows, top = {}, 0

  for position, slice in ipairs(data.slices or {}) do
    local row = { parts = {}, others = 0, total = 0 }

    for _, part in ipairs(slice) do
      local value = number(part.value)
      local slot = (not part.others) and index[part.module] or nil

      if slot then
        row.parts[slot] = (row.parts[slot] or 0) + value
      else
        row.others = row.others + value
      end

      row.total = row.total + value
    end

    rows[position] = row
    top = max(top, row.total)
  end

  return order, rows, top
end

local function build(parent)
  local frame = CreateFrame("Frame", nil, parent)

  frame:SetWidth(S("page.unit") * 2)
  frame:SetHeight(S("kit.chart.height"))
  Bricks.frame(frame, "flat", S("kit.chart.background"), S("kit.chart.border"))
  frame.bars = {}
  frame.data = { slices = {} }
  frame.order = {}
  frame.top = Bricks.text(frame, S("kit.chart.font"), S("kit.chart.value"))
  frame.first = Bricks.text(frame, S("kit.chart.font"), S("kit.chart.label"))
  frame.last = Bricks.text(frame, S("kit.chart.font"), S("kit.chart.label"))

  function frame:SetSeries(data)
    self.data = type(data) == "table" and data or { slices = {} }
    self:kitDraw()

    return self
  end

  function frame:Modules()
    local list = {}

    for position, name in ipairs(self.order) do
      list[position] = name
    end

    return list
  end

  function frame:ColorOf(module)
    for position, name in ipairs(self.order) do
      if name == module then
        return colorOf(position)
      end
    end

    return colorOf(nil)
  end

  function frame:kitBar(position)
    local bar = self.bars[position]

    if not bar then
      bar = CreateFrame("Frame", nil, self)
      bar:EnableMouse(true)
      bar:SetScript("OnEnter", Bricks.enterTip)
      bar:SetScript("OnLeave", Bricks.hideTip)
      bar.segs = {}
      self.bars[position] = bar
    end

    return bar
  end

  function frame:kitDraw()
    local data = self.data
    local count = seriesCount()
    local order, rows, top = digest(data, count)
    local inset, gap = S("border.size") + 1, 1
    local line = S("kit.chart.line")
    local width, height = self:GetWidth() - inset * 2, self:GetHeight() - inset * 2
    local track = max(1, height - line * 2)
    local labels = data.labels or {}
    local ceiling = tonumber(data.ceiling)
    local scale = (ceiling and ceiling > 0) and ceiling or top
    local barWidth = #rows > 0 and max(1, (width - gap * (#rows - 1)) / #rows) or 0

    self.order = order
    self.scale = scale
    self.top:ClearAllPoints()
    self.top:SetPoint("TOPLEFT", self, "TOPLEFT", inset + 2, -inset)
    self.top:SetText(scale > 0 and (shown(scale) .. (labels.unit and (" " .. labels.unit) or "")) or "")
    self.first:ClearAllPoints()
    self.first:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", inset + 2, inset)
    self.first:SetText(labels.first or "")
    self.last:ClearAllPoints()
    self.last:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset - 2, inset)
    self.last:SetText(labels.last or "")

    for position, row in ipairs(rows) do
      local bar = self:kitBar(position)
      local ratio = scale > 0 and min(1, row.total / scale) or 0
      local barHeight = track * ratio
      local base, used = 0, 0
      local segment = 0

      bar:ClearAllPoints()
      bar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", inset + (position - 1) * (barWidth + gap), inset + line)
      bar:SetWidth(barWidth)
      bar:SetHeight(max(1, barHeight))
      bar.total = barHeight
      bar.sum = row.total

      local function put(color, value)
        segment = segment + 1

        local texture = bar.segs[segment]

        if not texture then
          texture = bar:CreateTexture(nil, "ARTWORK")
          texture:SetTexture(Bricks.media("solid"))
          bar.segs[segment] = texture
        end

        local size = row.total > 0 and barHeight * value / row.total or 0

        texture:ClearAllPoints()
        texture:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, base)
        texture:SetWidth(barWidth)
        texture:SetHeight(size)
        texture:SetVertexColor(colorOf(color))
        texture.module = color and order[color] or nil
        texture.others = color == nil
        base = base + size

        if size > 0 then
          texture:Show()
        else
          texture:Hide()
        end
      end

      for slot = 1, #order do
        local value = row.parts[slot]

        if value and value > 0 then
          put(slot, value)
        end
      end

      if row.others > 0 then
        put(nil, row.others)
      end

      for extra = segment + 1, #bar.segs do
        bar.segs[extra]:Hide()
      end

      local tip, title, body = data.tips, nil, nil

      if type(tip) == "function" then
        local ok, one, two = pcall(tip, position, data.slices[position])

        if ok then
          title, body = one, two
        else
          Lib.report(one, "EbonAPI")
        end
      elseif type(tip) == "table" and type(tip[position]) == "table" then
        title, body = tip[position].title, tip[position].body
      end

      bar.tipTitle, bar.tipBody = title, body
      bar:Show()
    end

    for position = #rows + 1, #self.bars do
      self.bars[position]:Hide()
    end
  end

  function frame:kitRefresh()
    local source = self.spec and self.spec.series

    if type(source) == "function" then
      local ok, result = pcall(source, self)

      if ok then
        source = result
      else
        Lib.report(result, self.owner or "EbonAPI")
        source = nil
      end
    end

    if type(source) == "table" then
      self.data = source
    end

    self:kitDraw()
  end

  return frame
end

Bricks.register("stacked", "default", build)

local function checkStacked(owner, spec, level)
  local series = spec.series

  if series ~= nil and type(series) ~= "table" and type(series) ~= "function" then
    error(format("EbonAPI: %s: stacked series expects a table or a function, got %s", owner, tostring(series)),
      level + 1)
  end
end

local function newStacked(owner, parent, spec)
  local frame = Bricks.create("stacked", parent)

  frame.owner, frame.spec = owner, spec

  if spec.width then
    frame:SetWidth(spec.width)
  end

  if spec.height then
    frame:SetHeight(spec.height)
  end

  if spec.series ~= nil then
    frame:kitRefresh()
  end

  return frame
end

Kit.addKind("stacked", newStacked, checkStacked)
