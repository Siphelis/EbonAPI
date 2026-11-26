EbonAPI = EbonAPI or {}
EbonAPI.Counter = {}

local Counter = EbonAPI.Counter
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, lower, ceil = string.format, string.lower, math.ceil
local ipairs, type, tostring = ipairs, type, tostring
local S = Bricks.value
local Palette = EbonAPI.Palette

local DOT_TEXTURE = "Interface\\Minimap\\UI-Minimap-Background"
local TOKENS = { "gold", "silver", "copper", "ash", "shard", "essence", "artisan" }
local KNOWN = {}

for _, name in ipairs(TOKENS) do
  KNOWN[name] = true
end

Bricks.CONTRACT.counter = { "SetValue", "SetToken", "Value", "PreferredWidth" }

Counter.tokens = TOKENS

local function pad()
  return ceil(S("widgets.counter.height") / 4)
end

local FUNCTIONS = {}

-- Side of the icon when one is set: the counter height minus widgets.counter.inset on each side.
local function iconSize()
  return S("widgets.counter.height") - 2 * S("widgets.counter.inset")
end

local function markSize(self)
  return self.icon and iconSize() or S("widgets.counter.dot")
end

function FUNCTIONS:Layout()
  self:SetHeight(S("widgets.counter.height"))
  self.dot:SetSize(markSize(self), markSize(self))
  self.dot:ClearAllPoints()
  self.dot:SetPoint("LEFT", self, "LEFT", pad(), 0)
  self.text:ClearAllPoints()
  self.text:SetPoint("LEFT", self.dot, "RIGHT", pad(), 0)
  self:SetWidth(self:PreferredWidth())
end

function FUNCTIONS:SetToken(name)
  if not KNOWN[name] then
    error(format("EbonAPI: counter SetToken expects one of %s, got %s", table.concat(TOKENS, ", "), tostring(name)), 2)
  end

  local key = S("widgets.counter.token." .. name)

  self.token = name

  if not self.icon then
    Bricks.paint(self.dot, "SetVertexColor", key)
  end

  Bricks.paint(self, "SetBackdropBorderColor", key)
end

-- SetIcon(texture): shows a texture path in place of the coloured dot (the border keeps the token colour);
-- SetIcon(nil) brings the dot back.
function FUNCTIONS:SetIcon(texture)
  if texture ~= nil and type(texture) ~= "string" then
    error(format("EbonAPI: counter SetIcon expects a texture path or nil, got %s", tostring(texture)), 2)
  end

  self.icon = texture

  if texture then
    self.dot:SetTexture(texture)
    local trim = S("widgets.counter.trim")
    local tr, tg, tb = Palette.unpackColor(S("widgets.counter.tint"))

    self.dot:SetTexCoord(trim, 1 - trim, trim, 1 - trim)
    self.dot:SetVertexColor(tr, tg, tb, 1)
  else
    self.dot:SetTexture(DOT_TEXTURE)
    self.dot:SetTexCoord(0, 1, 0, 1)
    self:SetToken(self.token)
  end

  self:Layout()
end

function FUNCTIONS:SetValue(value)
  value = value ~= nil and tostring(value) or ""
  self.current = value
  self.text:SetText(value)
  self:SetWidth(self:PreferredWidth())
end

function FUNCTIONS:Value()
  return self.current
end

function FUNCTIONS:PreferredWidth()
  return 3 * pad() + markSize(self) + ceil(self.text:GetStringWidth() or 0)
end

function FUNCTIONS:SetTip(title, body)
  self.tipTitle, self.tipBody = title, body
end

function FUNCTIONS:kitRefresh()
  local spec = self.spec or {}
  local value = spec.value

  if type(value) == "function" then
    value = value(self)
  end

  if spec.token ~= nil then
    self:SetToken(spec.token)
  end

  if spec.icon ~= nil or self.icon ~= nil then
    self:SetIcon(spec.icon)
  end

  self:SetTip(spec.label, spec.tip)

  if value ~= nil then
    self:SetValue(value)
  end

  self:Layout()
end

function Counter.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  for name, fn in pairs(FUNCTIONS) do
    box[name] = fn
  end

  Bricks.frame(box, lower(S("widgets.counter.frame")), S("widgets.counter.fill"), S("widgets.counter.token.gold"))
  box.dot = box:CreateTexture(nil, "ARTWORK")
  box.dot:SetTexture(DOT_TEXTURE)
  box.text = Bricks.text(box, S("widgets.counter.font"), S("widgets.counter.text"))
  box.text:SetJustifyH("LEFT")
  box.current = ""
  box:SetToken("gold")
  box:Layout()
  box:EnableMouse(true)
  box:SetScript("OnEnter", function(self)
    Bricks.enterTip(self)
  end)
  box:SetScript("OnLeave", function()
    Bricks.hideTip()
  end)
  box.kitOwnTip = true

  return box
end

Bricks.register("counter", "default", Counter.build)

local function checkCounter(owner, spec, level)
  if spec.token ~= nil and not KNOWN[spec.token] then
    error(format("EbonAPI: %s: counter token expects one of %s, got %s", owner, table.concat(TOKENS, ", "),
      tostring(spec.token)), level + 1)
  end

  for _, name in ipairs({ "label", "tip", "icon" }) do
    local item = spec[name]

    if item ~= nil and type(item) ~= "string" then
      error(format("EbonAPI: %s: counter %s expects a string, got %s", owner, name, tostring(item)), level + 1)
    end
  end

  local value = spec.value

  if value ~= nil and type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "function" then
    error(format("EbonAPI: %s: counter value expects a string, a number or a function, got %s", owner,
      tostring(value)), level + 1)
  end
end

local function newCounter(owner, parent, spec)
  local box = Bricks.create("counter", parent)

  box.owner, box.spec = owner, spec

  return box
end

Kit.addKind("counter", newCounter, checkCounter)
