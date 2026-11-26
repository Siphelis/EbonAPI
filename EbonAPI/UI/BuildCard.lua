EbonAPI = EbonAPI or {}
EbonAPI.BuildCard = {}

local BuildCard = EbonAPI.BuildCard
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, floor = string.format, math.floor
local ipairs, type, tostring, pairs = ipairs, type, tostring, pairs

local instances = setmetatable({}, { __mode = "k" })

local WIDTH, HEIGHT = 250, 50
local ICON_COUNT, ICON_SIZE, ICON_GAP = 6, 22, 2
local AVATAR_SIZE = 32
local EDGE = 6
local SELECTED_FILL = { 0.05, 0.10, 0.25, 1 }
local SELECTED_EDGE = { 1, 0.82, 0, 1 }
local LOCK_GOLD = { 1, 0.82, 0, 1 }
local EMPTY_COLOR = { 0.4, 0.4, 0.4, 1 }
local AVATAR_COLOR = { 0.35, 0.35, 0.4, 1 }
local MISSING_COLOR = { 0.9, 0.35, 0.3, 1 }
local MISSING_KEY = "buildCard.missing"
local MISSING_DEFAULT = "il vous manque %d"
local COUNT_KEY = "buildCard.count"
local COUNT_DEFAULT = "%d Échos"

local function pick(key, fallback)
  local found = Bricks.value(key)

  if type(found) ~= "number" then
    return fallback
  end

  return found
end

local function widget(name, fallback)
  return pick("widgets.buildCard." .. name, fallback)
end

local function gold()
  return pick("palette.title", SELECTED_EDGE)
end

local function translate(key, default)
  local L = EbonAPI.L

  return (L and L[key]) or default
end

local function rgba(color, fallback)
  if type(color) == "number" then
    return floor(color / 65536) % 256 / 255, floor(color / 256) % 256 / 255, color % 256 / 255, 1
  end

  if type(color) == "table" then
    return color[1] or color.r or 1, color[2] or color.g or 1, color[3] or color.b or 1, color[4] or color.a or 1
  end

  return fallback[1], fallback[2], fallback[3], fallback[4]
end

local function checkSpec(owner, spec, level)
  for _, name in ipairs({ "name", "subtitle" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "string" then
      error(format("EbonAPI: %s: buildCard %s expects a text, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  for _, name in ipairs({ "count", "missing" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "number" then
      error(format("EbonAPI: %s: buildCard %s expects a number, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  if spec.echoes ~= nil and type(spec.echoes) ~= "table" then
    error(format("EbonAPI: %s: buildCard echoes expects a table, got %s", owner, tostring(spec.echoes)), level + 1)
  end

  if spec.onClick ~= nil and type(spec.onClick) ~= "function" then
    error(format("EbonAPI: %s: buildCard onClick expects a function, got %s", owner, tostring(spec.onClick)), level + 1)
  end

  if spec.selected ~= nil and type(spec.selected) ~= "boolean" then
    error(format("EbonAPI: %s: buildCard selected expects a boolean, got %s", owner, tostring(spec.selected)), level + 1)
  end
end

local function applyState(box)
  if box.state == "selected" then
    box:SetBackdropColor(rgba(widget("selectedFill", SELECTED_FILL), SELECTED_FILL))
    box:SetBackdropBorderColor(rgba(gold(), SELECTED_EDGE))
  else
    Bricks.frame(box, "large", "bg", "border")
  end
end

local function newIcon(box)
  local icon = CreateFrame("Frame", nil, box)

  icon:SetWidth(ICON_SIZE)
  icon:SetHeight(ICON_SIZE)
  icon.back = icon:CreateTexture(nil, "BACKGROUND")
  icon.back:SetAllPoints(icon)
  icon.back:SetTexture(Bricks.media("circle"))
    icon.pic = icon:CreateTexture(nil, "BORDER")
  icon.pic:SetPoint("TOPLEFT", icon, "TOPLEFT", 3, -3)
  icon.pic:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -3, 3)
  icon.pic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon.pic:Hide()
  icon.ring = icon:CreateTexture(nil, "ARTWORK")
  icon.ring:SetAllPoints(icon)
  icon.ring:SetTexture(Bricks.media("ring"))
  icon.ring:SetTexCoord(Bricks.caseCoords(40))
  icon.lock = icon:CreateTexture(nil, "OVERLAY")
  icon.lock:SetWidth(10)
  icon.lock:SetHeight(10)
  icon.lock:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
  icon.lock:SetTexture(Bricks.media("icons"))
  icon.lock:SetTexCoord(Bricks.glyphCoords("lock"))
  icon:Hide()

  return icon
end

local BACK_COLOR = { 0.08, 0.08, 0.1, 1 }

local function paintIcon(icon)
  icon.back:SetVertexColor(rgba(widget("back", BACK_COLOR), BACK_COLOR))
  icon.lock:SetVertexColor(rgba(gold(), LOCK_GOLD))
end

local function layoutIcons(box)
  local echoes = box.spec.echoes or {}

  for index = 1, ICON_COUNT do
    local icon, echo = box.icons[index], echoes[index]

    paintIcon(icon)

    if type(echo) == "table" then
      icon.ring:SetVertexColor(rgba(echo.color, { rgba(widget("empty", EMPTY_COLOR), EMPTY_COLOR) }))
      if echo.icon then
        icon.pic:SetTexture(echo.icon)
        icon.pic:Show()
      else
        icon.pic:Hide()
      end

      if echo.locked then
        icon.lock:Show()
      else
        icon.lock:Hide()
      end

      icon:Show()
    else
      icon:Hide()
    end
  end
end

local function layout(box)
  local spec = box.spec

  box.name:SetText(spec.name or "")

  if spec.subtitle then
    box.sub:SetText(spec.subtitle)
  elseif spec.count then
    box.sub:SetText(format(translate(COUNT_KEY, COUNT_DEFAULT), spec.count))
  else
    box.sub:SetText("")
  end

  if spec.missing and spec.missing > 0 then
    box.missing:SetText(format(translate(MISSING_KEY, MISSING_DEFAULT), spec.missing))
    box.missing:SetTextColor(rgba(widget("missing", MISSING_COLOR), MISSING_COLOR))
    box.missing:Show()
  else
    box.missing:Hide()
  end

  box.avatar:SetVertexColor(rgba(spec.classColor, { rgba(widget("avatar", AVATAR_COLOR), AVATAR_COLOR) }))
  layoutIcons(box)
  applyState(box)
end

local BOX = {}

function BOX:SetState(state)
  self.state = state == "selected" and "selected" or "normal"
  applyState(self)

  return self
end

function BOX:GetState()
  return self.state
end

function BOX:SetSpec(spec)
  self.spec = spec
  self.state = spec.selected and "selected" or "normal"
  layout(self)

  return self
end

function BOX:Refresh()
  layout(self)
end

BOX.kitRefresh = BOX.Refresh

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Bricks, "apply", function()
    for box in pairs(instances) do
      box:Refresh()
    end
  end)
end

local function build(parent, spec)
  local box = CreateFrame("Button", nil, parent)

  for name, fn in pairs(BOX) do
    box[name] = fn
  end

  box:SetWidth(WIDTH)
  box:SetHeight(HEIGHT)
  box.spec = spec or {}
  box.state = "normal"
  box.icons = {}
  instances[box] = true

  box.avatar = box:CreateTexture(nil, "ARTWORK")
  box.avatar:SetWidth(AVATAR_SIZE)
  box.avatar:SetHeight(AVATAR_SIZE)
  box.avatar:SetPoint("LEFT", box, "LEFT", EDGE, 0)
  box.avatar:SetTexture(Bricks.media("circle"))

  box.name = Bricks.text(box, "normal", "text")
  box.name:SetPoint("TOPLEFT", box, "TOPLEFT", EDGE * 2 + AVATAR_SIZE, -EDGE)
  box.name:SetPoint("RIGHT", box, "RIGHT", -EDGE, 0)
  box.name:SetJustifyH("LEFT")
  box.name:SetWordWrap(false)

  box.sub = Bricks.text(box, "small", "muted")
  box.sub:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -1)
  box.sub:SetJustifyH("LEFT")
  box.sub:SetWordWrap(false)

  box.missing = Bricks.text(box, "small", "text")
  box.missing:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -EDGE, EDGE - 2)
  box.missing:Hide()

  for index = 1, ICON_COUNT do
    local icon = newIcon(box)

    icon:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", EDGE * 2 + AVATAR_SIZE + (index - 1) * (ICON_SIZE + ICON_GAP), EDGE - 2)
    box.icons[index] = icon
  end

  box:SetScript("OnClick", function(self)
    if self.spec.onClick then
      self.spec.onClick(self.spec)
    end
  end)

  return box
end

BuildCard.build = build

local function newBuildCard(owner, parent, spec)
  local box = build(parent, spec)

  box.owner = owner
  box:SetSpec(spec)

  return box
end

Kit.addKind("buildCard", newBuildCard, checkSpec)
