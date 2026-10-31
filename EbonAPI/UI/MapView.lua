EbonAPI = EbonAPI or {}
EbonAPI.MapView = {}

local MapView = EbonAPI.MapView
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit
local Treemap = EbonAPI.Treemap
local THEME = EbonAPI.Palette.THEME

local format, floor, max, min = string.format, math.floor, math.max, math.min
local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local CreateFrame = CreateFrame
local S = Bricks.value

Bricks.CONTRACT.map = { "SetItems", "SetSize", "Cells", "Refresh" }

local TONES = { accent = true, gray = true }

local function lookKey(name)
  return S("widgets.map." .. name)
end

local function colorOf(key)
  return THEME[key] or THEME.heading
end

local function mix(low, high, heat)
  heat = max(0, min(1, heat))

  return {
    low[1] + (high[1] - low[1]) * heat,
    low[2] + (high[2] - low[2]) * heat,
    low[3] + (high[3] - low[3]) * heat,
    (low[4] or 1) + ((high[4] or 1) - (low[4] or 1)) * heat,
  }
end

local function number(value)
  return type(value) == "number" and value == value
end

local BOX = {}

function BOX:Cell(index)
  local cell = self.pool[index]

  if cell then
    return cell
  end

  cell = CreateFrame("Frame", nil, self)
  cell:EnableMouse(true)
  Bricks.frame(cell, lookKey("frame"):lower(), lookKey("accent.fill"), lookKey("border"))
  cell.label = Bricks.text(cell, lookKey("label.font"), "text")
  cell.label:SetPoint("TOPLEFT", cell, "TOPLEFT", 3, -3)
  cell.label:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -3, -3)
  cell.label:SetJustifyH("LEFT")
  cell.label:SetJustifyV("TOP")

  if cell.label.SetWordWrap then
    cell.label:SetWordWrap(false)
  end

  cell:SetScript("OnEnter", function(self)
    local item = self.item

    if item then
      Bricks.tip(self, item.label, item.tip)
    end
  end)
  cell:SetScript("OnLeave", function()
    Bricks.hideTip()
  end)

  self.pool[index] = cell

  return cell
end

function BOX:Dress(cell, item, frame)
  local floorSize = lookKey("label.min")
  local shown = false

  cell.item = item
  cell:ClearAllPoints()
  cell:SetPoint("TOPLEFT", self, "TOPLEFT", frame.x, -frame.y)
  cell:SetWidth(frame.w)
  cell:SetHeight(frame.h)

  if item.tone == "gray" then
    local color = mix(colorOf(lookKey("gray.low")), colorOf(lookKey("gray.high")), number(item.heat) and item.heat or 0)

    Bricks.unpaint(cell, "SetBackdropColor")
    cell:SetBackdropColor(color[1], color[2], color[3], color[4])
    cell.color = color
  else
    Bricks.paint(cell, "SetBackdropColor", lookKey("accent.fill"))
    cell.color = colorOf(lookKey("accent.fill"))
  end

  if item.label and item.label ~= "" and frame.w > floorSize and frame.h > floorSize then
    cell.label:SetText(item.label)
    cell.label:Show()
    shown = true
  else
    cell.label:SetText("")
    cell.label:Hide()
  end

  cell.labelShown = shown
  cell:Show()
end

function BOX:Relayout()
  local width, height = floor(self:GetWidth() or 0), floor(self:GetHeight() or 0)
  local list, byId = {}, self.byId
  local used = 0

  for _, item in ipairs(self.items) do
    list[#list + 1] = { id = item.id, value = item.value }
  end

  self.frames = {}

  if width > 0 and height > 0 then
    local cells = Treemap.snap(Treemap.layout(list, width, height, lookKey("gap")))

    for _, frame in ipairs(cells) do
      local item = byId[frame.id]

      if item and frame.w > 0 and frame.h > 0 then
        used = used + 1
        self:Dress(self:Cell(used), item, frame)
        self.frames[used] = frame
      end
    end
  end

  for index = used + 1, #self.pool do
    self.pool[index].item = nil
    self.pool[index]:Hide()
  end

  self.used = used

  return self
end

function BOX:SetItems(items)
  self.items = items or {}
  self.byId = {}

  for _, item in ipairs(self.items) do
    self.byId[item.id] = item
  end

  return self:Relayout()
end

function BOX:SetSize(width, height)
  self.nativeSetWidth(self, width)
  self.nativeSetHeight(self, height)

  return self:Relayout()
end

function BOX:SetWidth(width)
  self.nativeSetWidth(self, width)

  return self:Relayout()
end

function BOX:SetHeight(height)
  self.nativeSetHeight(self, height)

  return self:Relayout()
end

function BOX:Refresh()
  return self:Relayout()
end

function BOX:Cells()
  local list = {}

  for index = 1, self.used do
    local frame, cell = self.frames[index], self.pool[index]

    list[index] = {
      id = frame.id, x = frame.x, y = frame.y, w = frame.w, h = frame.h, frame = cell,
      tone = cell.item and cell.item.tone, color = cell.color, labelShown = cell.labelShown,
    }
  end

  return list
end

function MapView.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  box.nativeSetWidth, box.nativeSetHeight = box.SetWidth, box.SetHeight

  for name, fn in pairs(BOX) do
    box[name] = fn
  end

  box.pool, box.items, box.byId, box.frames, box.used = {}, {}, {}, {}, 0

  return box
end

Bricks.register("map", "default", function(parent)
  return MapView.build(parent)
end)

local function checkMap(owner, spec, level)
  if spec.items ~= nil then
    if type(spec.items) ~= "table" then
      error(format("EbonAPI: %s: treemap items expects a list, got %s", owner, tostring(spec.items)), level + 1)
    end

    for index, item in ipairs(spec.items) do
      if type(item) ~= "table" or item.id == nil then
        error(format("EbonAPI: %s: treemap item %d expects a table with an id", owner, index), level + 1)
      end

      if item.tone ~= nil and not TONES[item.tone] then
        error(format("EbonAPI: %s: treemap tone expects accent or gray, got %s", owner, tostring(item.tone)), level + 1)
      end

      if item.heat ~= nil and not number(item.heat) then
        error(format("EbonAPI: %s: treemap heat expects a number, got %s", owner, tostring(item.heat)), level + 1)
      end
    end
  end

  for _, name in ipairs({ "width", "height" }) do
    if spec[name] ~= nil and (not number(spec[name]) or spec[name] <= 0) then
      error(format("EbonAPI: %s: treemap %s expects a positive number, got %s", owner, name, tostring(spec[name])),
        level + 1)
    end
  end
end

local function newMap(owner, parent, spec)
  local box = Bricks.create("map", parent)

  box.owner, box.spec = owner, spec

  if spec.items then
    box:SetItems(spec.items)
  end

  return box
end

Kit.addKind("treemap", newMap, checkMap)
