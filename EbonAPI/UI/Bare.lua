EbonAPI = EbonAPI or {}
EbonAPI.Bare = {}

local Bare = EbonAPI.Bare
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, lower = string.format, string.lower
local ipairs, pcall, type, tostring = ipairs, pcall, type, tostring
local S = Bricks.value

Bricks.CONTRACT.bare = { "SetFrameStyle", "Surface" }

local STYLES = EbonAPI.Kit.FRAMES

local function styleOf(self)
  local spec = self.spec or {}
  local style = lower(tostring(self.style or spec.frame or S("widgets.bare.frame")))

  return STYLES[style] and style or "flat"
end

local FUNCTIONS = {}

function FUNCTIONS:SetFrameStyle(style)
  if type(style) ~= "string" or not STYLES[lower(style)] then
    error(format("EbonAPI: bare SetFrameStyle expects flat, small or large, got %s", tostring(style)), 2)
  end

  self.style = lower(style)
  self:kitRefresh()

  return self
end

function FUNCTIONS:Surface()
  return self
end

function FUNCTIONS:kitRefresh()
  local spec = self.spec or {}
  local style = styleOf(self)
  local fill = spec.fill or S("widgets.bare.fill")
  local border = spec.border or S("widgets.bare.border")
  local size = spec.borderSize or S("widgets.bare.borderSize")

  Bricks.frame(self, style, fill, border)

  if style == "flat" then
    local solid = Bricks.media("solid")

    self:SetBackdrop({ bgFile = solid, edgeFile = solid, edgeSize = size })
    Bricks.paint(self, "SetBackdropColor", fill)
    Bricks.paint(self, "SetBackdropBorderColor", border)
  end

  if spec.width then
    self:SetWidth(spec.width)
  end

  if spec.height then
    self:SetHeight(spec.height)
  end
end

function Bare.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  for name, fn in pairs(FUNCTIONS) do
    box[name] = fn
  end

  box.spec = {}
  box:kitRefresh()

  return box
end

Bricks.register("bare", "default", Bare.build)

local function checkBare(owner, spec, level)
  if spec.frame ~= nil and (type(spec.frame) ~= "string" or not STYLES[lower(spec.frame)]) then
    error(format("EbonAPI: %s: bare frame expects flat, small or large, got %s", owner, tostring(spec.frame)), level + 1)
  end

  for _, name in ipairs({ "fill", "border" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "string" then
      error(format("EbonAPI: %s: bare %s expects a color key, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  for _, name in ipairs({ "borderSize", "width", "height" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "number" then
      error(format("EbonAPI: %s: bare %s expects a number, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end
end

local function newBare(owner, parent, spec)
  local box = Bricks.create("bare", parent)

  box.owner, box.spec = owner, spec
  box:kitRefresh()

  return box
end

Kit.addKind("bare", newBare, checkBare)
