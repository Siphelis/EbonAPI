EbonAPI = EbonAPI or {}
EbonAPI.Zoom = {}

local Zoom = EbonAPI.Zoom
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, floor, min, max = string.format, math.floor, math.min, math.max
local ipairs, pcall, type, tostring = ipairs, pcall, type, tostring
local S = Bricks.value

local SIGNS = { minus = "-", plus = "+" }
local PERCENT = "%d %%"

Bricks.CONTRACT.zoom = { "SetValue", "Value", "SetRange" }

local FUNCTIONS = {}

local function clamp(self, value)
  return min(max(value, self.min), self.max)
end

function FUNCTIONS:Layout()
  local height, gap = S("widgets.zoom.height"), S("widgets.zoom.gap")

  self:SetHeight(height)
  self.minus:ClearAllPoints()
  self.minus:SetPoint("LEFT", self, "LEFT", 0, 0)
  self.plus:ClearAllPoints()
  self.plus:SetPoint("RIGHT", self, "RIGHT", 0, 0)
  self.readout:ClearAllPoints()
  self.readout:SetPoint("LEFT", self.minus, "RIGHT", gap, 0)
  self.readout:SetPoint("RIGHT", self.plus, "LEFT", -gap, 0)
  self:SetWidth(self.minus:GetWidth() + self.plus:GetWidth() + 2 * gap + self.readoutWidth)
end

function FUNCTIONS:Update()
  self.readout:SetText(format(PERCENT, floor(self.current * 100 + 0.5)))
  self.minus:SetDisabledState(self.current <= self.min)
  self.plus:SetDisabledState(self.current >= self.max)
end

function FUNCTIONS:SetValue(value)
  if type(value) ~= "number" then
    error(format("EbonAPI: zoom SetValue expects a number, got %s", tostring(value)), 2)
  end

  self.current = clamp(self, value)
  self:Update()
end

function FUNCTIONS:Value()
  return self.current
end

function FUNCTIONS:SetRange(low, high, step)
  if type(low) ~= "number" or type(high) ~= "number" or low > high then
    error(format("EbonAPI: zoom SetRange expects min <= max numbers, got %s, %s", tostring(low), tostring(high)), 2)
  end

  self.min, self.max = low, high
  self.step = step or self.step
  self.current = clamp(self, self.current)
  self:Update()
end

function FUNCTIONS:Step(direction)
  local before = self.current
  local value = direction > 0 and before * self.step or before / self.step

  self.current = clamp(self, value)
  self:Update()

  if self.current ~= before and self.spec and type(self.spec.onChange) == "function" then
    pcall(self.spec.onChange, self.current)
  end
end

function FUNCTIONS:kitRefresh()
  local spec = self.spec or {}

  self.min = spec.min or self.min
  self.max = spec.max or self.max
  self.step = spec.step or self.step

  if spec.value ~= nil then
    self.current = clamp(self, spec.value)
  end

  self:Update()
  self:Layout()
end

function Zoom.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  for name, fn in pairs(FUNCTIONS) do
    box[name] = fn
  end

  box.min, box.max, box.step, box.current = 0, 1, 1, 0
  Bricks.frame(box, "flat", S("widgets.zoom.fill"), S("widgets.zoom.border"))
  box.readout = Bricks.text(box, "small", S("widgets.zoom.text"))
  box.readout:SetJustifyH("CENTER")
  box.readout:SetText(format(PERCENT, 100))
  box.readoutWidth = 0

  return box
end

Bricks.register("zoom", "default", Zoom.build)

local function checkZoom(owner, spec, level)
  for _, name in ipairs({ "value", "min", "max", "step" }) do
    local item = spec[name]

    if item ~= nil and type(item) ~= "number" then
      error(format("EbonAPI: %s: zoom %s expects a number, got %s", owner, name, tostring(item)), level + 1)
    end
  end

  if spec.min and spec.max and spec.min > spec.max then
    error(format("EbonAPI: %s: zoom min %s is above max %s", owner, spec.min, spec.max), level + 1)
  end

  if spec.step ~= nil and spec.step <= 0 then
    error(format("EbonAPI: %s: zoom step expects a number above 0, got %s", owner, spec.step), level + 1)
  end

  if spec.onChange ~= nil and type(spec.onChange) ~= "function" then
    error(format("EbonAPI: %s: zoom onChange expects a function, got %s", owner, tostring(spec.onChange)), level + 1)
  end
end

local function newZoom(owner, parent, spec)
  local box = Bricks.create("zoom", parent)
  local height = S("widgets.zoom.height")

  box.owner, box.spec = owner, spec
  box.minus = Kit.create(owner, "button", box, {
    text = SIGNS.minus, width = height, centerTight = true,
    onClick = function()
      box:Step(-1)
    end,
  })
  box.plus = Kit.create(owner, "button", box, {
    text = SIGNS.plus, width = height, centerTight = true,
    onClick = function()
      box:Step(1)
    end,
  })
  box.readoutWidth = spec.width and (spec.width - 2 * height - 2 * S("widgets.zoom.gap")) or 4 * height

  return box
end

Kit.addKind("zoom", newZoom, checkZoom)
