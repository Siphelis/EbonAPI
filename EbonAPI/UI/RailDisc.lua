local Kit = EbonAPI.Kit
local Bricks = EbonAPI.Bricks
local Palette = EbonAPI.Palette

local DEFAULT_SOLID = "Interface\\Buttons\\WHITE8X8"
local SIZE = 60
local DISC = 46
local RING = 2
local HALO = DISC + 2 * RING
local GOLD_FALLBACK = 0xFFD100
local NEUTRAL_FALLBACK = 0x808080
local EMPTY_FALLBACK = 0x0D0D0D

local ipairs, pairs, floor = ipairs, pairs, math.floor
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

local function neutralColor()
  return Palette.unpackColor(floor(general("widgets.railDisc.neutral", NEUTRAL_FALLBACK)))
end

local function emptyColor()
  return Palette.unpackColor(floor(general("widgets.railDisc.empty", EMPTY_FALLBACK)))
end

local function tr(key, fallback)
  if EbonAPI.L then
    local text = EbonAPI.L[key]

    if type(text) == "string" and text ~= "" and text ~= key then
      return text
    end
  end

  return fallback
end

local function layer(parent, drawLayer, r, g, b, path)
  local texture = parent:CreateTexture(nil, drawLayer)

  texture:SetTexture(path or solid())
  texture:SetVertexColor(r, g, b, 1)

  return texture
end

local function iconPath(self)
  local path = Kit.evaluate(self, self.spec.icon)

  if type(path) ~= "string" or path == "" then
    return nil
  end

  return EbonAPI.Lib.icon(path)
end

local function showCircle(self)
  if self.kitIconPath == nil then
    return
  end

  self.kitIconPath = nil
  self.kitDisc:SetTexture(Bricks.media("circle"))
  self.kitDisc:SetTexCoord(0, 1, 0, 1)
end

local function classRGB(color)
  local nr, ng, nb = neutralColor()

  if type(color) ~= "table" then
    return nr, ng, nb
  end

  return color.r or color[1] or nr, color.g or color[2] or ng, color.b or color[3] or nb
end

local function paint(self)
  local spec = self.spec
  local gr, gg, gb = goldColor()

  for _, edge in ipairs(self.kitRing) do
    edge:SetVertexColor(gr, gg, gb, 1)
  end

  if self.kitState == "free" then
    local er, eg, eb = emptyColor()

    showCircle(self)
    self.kitDisc:SetVertexColor(er, eg, eb, 1)
    self.kitCaption:SetText(tr("RAIL_FREE", "Libre"))
    self.kitHalo:Hide()

    return
  end

  local path = iconPath(self)

  if path then
    if self.kitIconPath ~= path then
      self.kitIconPath = path
      self.kitDisc:SetTexCoord(0, 1, 0, 1)
      SetPortraitToTexture(self.kitDisc, path)
    end

    self.kitDisc:SetVertexColor(1, 1, 1, 1)
    self.kitCaption:SetText(Kit.evaluate(self, spec.initials) or "")

    if self.kitState == "active" then
      self.kitHalo:Show()
    else
      self.kitHalo:Hide()
    end

    return
  end

  showCircle(self)

  local color = Kit.evaluate(self, spec.color)

  if color == nil then
    color = Kit.evaluate(self, spec.classColor)
  end

  local r, g, b = classRGB(color)

  self.kitDisc:SetVertexColor(r, g, b, 1)
  self.kitCaption:SetText(Kit.evaluate(self, spec.initials) or "")

  if self.kitState == "active" then
    self.kitHalo:Show()
  else
    self.kitHalo:Hide()
  end
end

local function newRailDisc(owner, parent, spec)
  local box = CreateFrame("Button", nil, parent)

  box:SetWidth(SIZE)
  box:SetHeight(SIZE)

  box.kitHalo = CreateFrame("Frame", nil, box)
  box.kitHalo:SetWidth(HALO)
  box.kitHalo:SetHeight(HALO)
  box.kitHalo:SetPoint("TOP", box, "TOP", 0, 0)

  local gr, gg, gb = goldColor()

  local top = layer(box.kitHalo, "BORDER", gr, gg, gb)

  top:SetPoint("TOPLEFT", box.kitHalo, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", box.kitHalo, "TOPRIGHT", 0, 0)
  top:SetHeight(RING)

  local bottom = layer(box.kitHalo, "BORDER", gr, gg, gb)

  bottom:SetPoint("BOTTOMLEFT", box.kitHalo, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", box.kitHalo, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(RING)

  local left = layer(box.kitHalo, "BORDER", gr, gg, gb)

  left:SetPoint("TOPLEFT", box.kitHalo, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", box.kitHalo, "BOTTOMLEFT", 0, 0)
  left:SetWidth(RING)

  local right = layer(box.kitHalo, "BORDER", gr, gg, gb)

  right:SetPoint("TOPRIGHT", box.kitHalo, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", box.kitHalo, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(RING)

  box.kitRing = { top, bottom, left, right }

  local nr, ng, nb = neutralColor()

  box.kitDisc = layer(box, "ARTWORK", nr, ng, nb, Bricks.media("circle"))
  box.kitDisc:SetWidth(DISC)
  box.kitDisc:SetHeight(DISC)
  box.kitDisc:SetPoint("TOP", box, "TOP", 0, -RING)

  box.kitCaption = box:CreateFontString(nil, "OVERLAY")
  Bricks.font(box.kitCaption, "small")
  Bricks.paint(box.kitCaption, "SetTextColor", "text")
  box.kitCaption:SetPoint("BOTTOM", box, "BOTTOM", 0, 0)

  instances[box] = true

  box:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  box:SetScript("OnClick", function(self, mouse)
    if type(self.spec.onClick) == "function" then
      self.spec.onClick(mouse)
    end
  end)

  function box:SetState(state)
    self.kitState = state
    paint(self)

    return self
  end

  function box:kitRefresh()
    if self.spec.free == nil and self.spec.active == nil then
      return
    end

    local state = "idle"

    if Kit.evaluate(self, self.spec.free) then
      state = "free"
    elseif Kit.evaluate(self, self.spec.active) then
      state = "active"
    end

    self:SetState(state)
  end

  return box
end

Kit.addKind("railDisc", newRailDisc)

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Bricks, "apply", function()
    for box in pairs(instances) do
      Bricks.font(box.kitCaption, "small")

      if box.kitState then
        paint(box)
      end
    end
  end)
end
