EbonAPI = EbonAPI or {}
EbonAPI.Round = {}

local Round = EbonAPI.Round
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format = string.format
local ipairs, pcall, type, tostring = ipairs, pcall, type, tostring
local S = Bricks.value

Bricks.CONTRACT.round = { "SetActive", "SetIcon", "SetGlyph", "SetSize" }

local FUNCTIONS = {}

local function key(name)
  return S("widgets.round." .. name)
end

function FUNCTIONS:Layout()
  local size = self.size or key("size")

  self:SetWidth(size)
  self:SetHeight(size)
  self.icon:ClearAllPoints()
  self.icon:SetPoint("CENTER", self, "CENTER", 0, 0)
  self.icon:SetWidth(size - 2 * Bricks.insetOf(self) - 2)
  self.icon:SetHeight(size - 2 * Bricks.insetOf(self) - 2)
  self.glyphText:ClearAllPoints()
  self.glyphText:SetPoint("CENTER", self, "CENTER", 0, 0)
end

function FUNCTIONS:Paint()
  local on = self.active and true or false
  local fill = on and key("activeFill") or (self.hovered and key("hover") or key("fill"))
  local border = on and key("activeBorder") or key("border")
  local ink = on and key("activeText") or key("text")

  Bricks.frame(self, "small", fill, border)
  Bricks.paint(self.glyphText, "SetTextColor", ink)

  if self.iconPath then
    -- portrait: the icon is a square game icon, cut into a disc like the other rounds (SetPortraitToTexture)
    if self.portrait and type(SetPortraitToTexture) == "function" then
      SetPortraitToTexture(self.icon, self.iconPath)
    else
      self.icon:SetTexture(self.iconPath)
    end
    self.icon:Show()
    self.glyphText:Hide()
  else
    self.icon:Hide()
    self.glyphText:SetText(self.glyph or "")
    self.glyphText:Show()
  end
end

function FUNCTIONS:SetActive(active)
  self.active = active and true or false
  self:Paint()

  return self
end

function FUNCTIONS:SetIcon(path)
  if path ~= nil and type(path) ~= "string" then
    error(format("EbonAPI: round SetIcon expects a texture path, got %s", tostring(path)), 2)
  end

  self.iconPath = path
  if path then
    self.glyph = nil
  end

  self:Paint()

  return self
end

function FUNCTIONS:SetGlyph(glyph)
  if glyph ~= nil and type(glyph) ~= "string" then
    error(format("EbonAPI: round SetGlyph expects a text, got %s", tostring(glyph)), 2)
  end

  self.glyph = glyph

  if glyph then
    self.iconPath = nil
  end

  self:Paint()

  return self
end

function FUNCTIONS:SetSize(size)
  if type(size) ~= "number" or size <= 0 then
    error(format("EbonAPI: round SetSize expects a positive number, got %s", tostring(size)), 2)
  end

  self.size = size
  self:Layout()

  return self
end

function FUNCTIONS:kitRefresh()
  local spec = self.spec or {}

  if spec.size then
    self.size = spec.size
  end

  self.active = spec.active and true or false
  self.iconPath = spec.icon
  self.portrait = spec.portrait and true or false
  self.glyph = spec.glyph
  self.tipTitle, self.tipBody = spec.label, spec.tip
  self:Layout()
  self:Paint()
end

function Round.build(parent)
  local button = CreateFrame("Button", nil, parent)

  for name, fn in pairs(FUNCTIONS) do
    button[name] = fn
  end

  button.spec = {}
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.glyphText = Bricks.text(button, "normal", key("text"))
  button.glyphText:SetJustifyH("CENTER")
  button.kitOwnTip = true
  button:EnableMouse(true)
  button:SetScript("OnEnter", function(self)
    self.hovered = true
    self:Paint()

    if self.tipTitle or self.tipBody then
      Bricks.enterTip(self)
    end
  end)
  button:SetScript("OnLeave", function(self)
    self.hovered = false
    self:Paint()
    Bricks.hideTip()
  end)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(self, mouse)
    Kit.click(self, mouse)
  end)
  button:Layout()
  button:Paint()

  return button
end

Bricks.register("round", "default", Round.build)

local function checkRound(owner, spec, level)
  for _, name in ipairs({ "icon", "glyph", "label", "tip" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "string" then
      error(format("EbonAPI: %s: round %s expects a string, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  if spec.size ~= nil and (type(spec.size) ~= "number" or spec.size <= 0) then
    error(format("EbonAPI: %s: round size expects a positive number, got %s", owner, tostring(spec.size)), level + 1)
  end

  if spec.active ~= nil and type(spec.active) ~= "boolean" then
    error(format("EbonAPI: %s: round active expects a boolean, got %s", owner, tostring(spec.active)), level + 1)
  end

  if spec.onClick ~= nil and type(spec.onClick) ~= "function" then
    error(format("EbonAPI: %s: round onClick expects a function, got %s", owner, tostring(spec.onClick)), level + 1)
  end
end

local function newRound(owner, parent, spec)
  local button = Bricks.create("round", parent)

  button.owner, button.spec = owner, spec
  button:kitRefresh()

  return button
end

Kit.addKind("round", newRound, checkRound)
