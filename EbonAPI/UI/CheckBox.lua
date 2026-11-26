local Kit = EbonAPI.Kit
local Bricks = EbonAPI.Bricks
local Palette = EbonAPI.Palette

local DEFAULT_SOLID = "Interface\\Buttons\\WHITE8X8"
local SIDE = 11
local GAP = 4
local EDGE = 1
local MARK_INSET = 2
local HOVER = 0.2
local DISABLED_ALPHA = 0.45
local GOLD_FALLBACK = 0xFFD100
local FILL_FALLBACK = 0x0D0D0D

local min, max, ipairs, pairs, floor = math.min, math.max, ipairs, pairs, math.floor
local type = type

local instances = setmetatable({}, { __mode = "k" })

local function general(key, fallback)
  local found = Bricks.value(key)

  if type(found) ~= "number" then
    return fallback
  end

  return found
end

local function solid()
  return Bricks.media("solid") or DEFAULT_SOLID
end

local function goldColor()
  return Palette.unpackColor(floor(general("palette.title", GOLD_FALLBACK)))
end

local function fillColor()
  return Palette.unpackColor(floor(general("widgets.checkBox.fill", FILL_FALLBACK)))
end

local function lift(value, amount)
  return min(1, value + amount)
end

local function layer(parent, drawLayer, r, g, b)
  local texture = parent:CreateTexture(nil, drawLayer)

  texture:SetTexture(solid())
  texture:SetVertexColor(r, g, b, 1)

  return texture
end

local function newSquare(box)
  local square = CreateFrame("Frame", nil, box)

  square:SetWidth(SIDE)
  square:SetHeight(SIDE)
  square:SetPoint("LEFT", box, "LEFT", 0, 0)

  local fr, fg, fb = fillColor()
  local gr, gg, gb = goldColor()

  local fill = layer(square, "BACKGROUND", fr, fg, fb)

  fill:SetAllPoints(square)

  local top = layer(square, "BORDER", gr, gg, gb)

  top:SetPoint("TOPLEFT", square, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", square, "TOPRIGHT", 0, 0)
  top:SetHeight(EDGE)

  local bottom = layer(square, "BORDER", gr, gg, gb)

  bottom:SetPoint("BOTTOMLEFT", square, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", square, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(EDGE)

  local left = layer(square, "BORDER", gr, gg, gb)

  left:SetPoint("TOPLEFT", square, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", square, "BOTTOMLEFT", 0, 0)
  left:SetWidth(EDGE)

  local right = layer(square, "BORDER", gr, gg, gb)

  right:SetPoint("TOPRIGHT", square, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", square, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(EDGE)

  local mark = layer(square, "ARTWORK", gr, gg, gb)

  mark:SetPoint("TOPLEFT", square, "TOPLEFT", MARK_INSET, -MARK_INSET)
  mark:SetPoint("BOTTOMRIGHT", square, "BOTTOMRIGHT", -MARK_INSET, MARK_INSET)

  return fill, { top, bottom, left, right }, mark
end

local function paint(self)
  local amount = self.kitHover and HOVER or 0
  local gr, gg, gb = goldColor()
  local fr, fg, fb = fillColor()

  for _, edge in ipairs(self.kitEdges) do
    edge:SetVertexColor(lift(gr, amount), lift(gg, amount), lift(gb, amount), 1)
  end

  self.kitMark:SetVertexColor(lift(gr, amount), lift(gg, amount), lift(gb, amount), 1)
  self.kitFill:SetVertexColor(lift(fr, amount), lift(fg, amount), lift(fb, amount), 1)

  if self.checked then
    self.kitMark:Show()
  else
    self.kitMark:Hide()
  end
end

local function newCheckBox(owner, parent, spec)
  local box = CreateFrame("Button", nil, parent)

  box.kitFill, box.kitEdges, box.kitMark = newSquare(box)
  box.label = Bricks.text(box, "small", "text")
  box.label:SetPoint("LEFT", box, "LEFT", SIDE + GAP, 0)

  instances[box] = true

  box:RegisterForClicks("LeftButtonUp")

  box:SetScript("OnClick", function(self)
    if self.kitOff then
      return
    end

    self:SetChecked(not self.checked)

    if type(self.spec.onChange) == "function" then
      self.spec.onChange(self.checked)
    end
  end)

  box:SetScript("OnEnter", function(self)
    if self.kitOff then
      return
    end

    self.kitHover = true
    paint(self)
  end)

  box:SetScript("OnLeave", function(self)
    self.kitHover = false
    paint(self)
  end)

  function box:SetChecked(value)
    self.checked = value and true or false
    paint(self)

    return self
  end

  function box:GetChecked()
    return self.checked and true or false
  end

  function box:SetDisabledState(disabled)
    self.kitOff = disabled and true or false
    self:SetAlpha(self.kitOff and DISABLED_ALPHA or 1)

    return self
  end

  local initial = spec.value

  if initial == nil then
    initial = spec.checked
  end

  box:SetChecked(initial)

  function box:kitRefresh()
    local value = Kit.evaluate(self, self.spec.get)

    if value == nil and not self.kitDone then
      value = self.spec.value

      if value == nil then
        value = self.spec.checked
      end
    end

    self.kitDone = true

    if self.spec.get or value ~= nil then
      self:SetChecked(value)
    end

    local text = Kit.textOf(self) or ""

    self.label:SetText(text)

    if not self.spec.width then
      local width = SIDE

      if text ~= "" then
        width = SIDE + GAP + self.label:GetStringWidth()
      end

      self:SetWidth(width)
    end

    if not self.spec.height then
      self:SetHeight(max(SIDE, self.label:GetStringHeight()))
    end

    self:SetDisabledState(Kit.evaluate(self, self.spec.enabled) == false)
  end

  return box
end

Kit.addKind("checkBox", newCheckBox)

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Bricks, "apply", function()
    for box in pairs(instances) do
      Bricks.font(box.label, "small")
      paint(box)
    end
  end)
end
