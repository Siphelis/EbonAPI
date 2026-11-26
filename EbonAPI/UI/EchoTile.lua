EbonAPI = EbonAPI or {}
EbonAPI.EchoTile = {}

local EchoTile = EbonAPI.EchoTile
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit
local Palette = EbonAPI.Palette

local format, floor, min, max = string.format, math.floor, math.min, math.max
local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber

local WIDTH, HEIGHT = 60, 70
local ICON, ICON_TOP = 46, 2
local NAME_HEIGHT, NAME_TOP = 18, 50
local MARK = 14
local CROP = 0.07
local RING_FULL = 40
local STATES = { normal = true, dim = true, missing = true }

local COLORS = {
  lock = 0xFFD100,
  mark = 0x9A6B33,
  stacks = 0xC8C8C8,
  missingFill = 0x5A1414,
  missingBorder = 0xE03A3A,
  ring = 0x9D9D9D,
  selected = 0x3263CC,
}

local QUALITY = {
  [0] = 0x9D9D9D, [1] = 0xFFFFFF, [2] = 0x1EFF00, [3] = 0x0070DD, [4] = 0xA335EE, [5] = 0xFF8000, [6] = 0xE6CC80,
}

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_RING = "Interface\\AddOns\\EbonAPI\\Media\\Ring.tga"
local DEFAULT_SOLID = "Interface\\Buttons\\WHITE8X8"
local DEFAULT_ICONS = "Interface\\AddOns\\EbonAPI\\Media\\Icons.tga"

local function value(name, fallback)
  local found = Bricks.value("widgets.echoTile." .. name)

  if found == nil then
    return fallback
  end

  return found
end

local instances = setmetatable({}, { __mode = "k" })

local function general(key, fallback)
  local found = Bricks.value(key)

  if type(found) ~= "number" then
    return fallback
  end

  return found
end

local function media(key, fallback)
  local found = Bricks.media(key)

  if found == nil then
    return fallback
  end

  return found
end

local function rgb(hex)
  return Palette.unpackColor(floor(tonumber(hex) or 0))
end

local function tint(target, method, hex)
  local r, g, b = rgb(hex)

  target[method](target, r, g, b)
end

local function ringColor(quality)
  if type(quality) == "number" and QUALITY[quality] then
    return general("kit.quality." .. quality, QUALITY[quality])
  end

  return general("palette.muted", COLORS.ring)
end

local function artIndex(quality)
  local level = type(quality) == "number" and floor(quality) or 0

  return max(0, min(level - 1, 3))
end

local function skinTexture(group, quality)
  local path = value(group .. "." .. artIndex(quality))

  if type(path) == "string" and path ~= "" then
    return path
  end
end

local function paintRound(self, data, size, dim, alpha)
  local disc = size * value("discScale", 1)
  local icon = size * value("iconScale", 1)
  local ring = size * value("ringScale", 1)
  local top = ICON_TOP + (size - icon) / 2
  local discPath = skinTexture("disc", data.quality)
  local ringPath = skinTexture("ring", data.quality)

  self.disc:ClearAllPoints()
  self.disc:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
  self.disc:SetWidth(disc)
  self.disc:SetHeight(disc)

  if discPath then
    self.disc:SetTexture(discPath)
    self.disc:SetAlpha(alpha)
    self.disc:Show()
  else
    self.disc:Hide()
  end

  self.icon:ClearAllPoints()
  self.icon:SetPoint("TOP", self, "TOP", 0, -top)
  self.icon:SetWidth(icon)
  self.icon:SetHeight(icon)

  if SetPortraitToTexture then
    SetPortraitToTexture(self.icon, data.icon or DEFAULT_ICON)
  else
    self.icon:SetTexture(data.icon or DEFAULT_ICON)
    self.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
  end

  self.ring:ClearAllPoints()
  self.ring:SetPoint("CENTER", self.icon, "CENTER", 0, value("ringShift", 0))
  self.ring:SetWidth(ring)
  self.ring:SetHeight(ring)
  self.ring:SetTexCoord(0, 1, 0, 1)
  self.ring:SetVertexColor(1, 1, 1)

  if ringPath then
    self.ring:SetTexture(ringPath)
    self.ring:SetAlpha(alpha)
    self.ring:Show()
  else
    self.ring:Hide()
  end

  return disc, top
end

local function glyph(texture, name)
  texture:SetTexture(media("icons", DEFAULT_ICONS))
  texture:SetTexCoord(Bricks.glyphCoords(name))
end

local BOX = {}

function BOX:Layout()
  local data = self.data
  local state = self.state
  local dim = state == "dim"
  local missing = state == "missing"
  local round = value("round", false) == true

  self.icon = round and self.portrait or self.plain
  self.icon:Show()

  if round then
    self.plain:Hide()
  else
    self.portrait:Hide()
  end
  local size = data.size or value("icon", ICON)
  local nameHeight = value("nameHeight", NAME_HEIGHT)
  local mark = value("mark", MARK)
  local alpha = dim and value("dimAlpha", 0.55) or 1

  local named = type(data.name) == "string" and data.name ~= ""
  local width, height = value("width", WIDTH), value("height", HEIGHT)
  local nameTop = value("nameTop", NAME_TOP)
  local nameWidth = width

  if round then
    mark = min(mark, floor(size * value("markScale", 0.4)))
  elseif not named then
    width = min(width, size + 2 * ICON_TOP)
    height = min(height, size + 2 * ICON_TOP)
  end

  self:SetWidth(width)
  self:SetHeight(height)

  if round then
    paintRound(self, data, size, dim, alpha)
  else
    self.disc:Hide()
    self.icon:ClearAllPoints()
    self.icon:SetPoint("TOP", self, "TOP", 0, -ICON_TOP)
    self.icon:SetWidth(size)
    self.icon:SetHeight(size)
    self.icon:SetTexture(data.icon or DEFAULT_ICON)
    self.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
  end

  if self.icon.SetDesaturated then
    self.icon:SetDesaturated(dim)
  end

  self.icon:SetAlpha(alpha)

  if self.badge then
    if type(data.badge) == "string" then
      self.badge:ClearAllPoints()
      self.badge:SetPoint("TOPLEFT", self.icon, "TOPLEFT", 0, 0)
      self.badge:SetWidth(mark)
      self.badge:SetHeight(mark)
      self.badge:SetTexture(data.badge)
      self.badge:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)

      if self.badge.SetDesaturated then
        self.badge:SetDesaturated(dim)
      end

      self.badge:SetAlpha(dim and value("dimAlpha", 0.55) or 1)
      self.badge:Show()
    else
      self.badge:Hide()
    end
  end

  if round then
    self.ring:SetAlpha(alpha)
  elseif data.ring == true then
    self.ring:ClearAllPoints()
    self.ring:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
    self.ring:SetWidth(size + 4)
    self.ring:SetHeight(size + 4)
    self.ring:SetTexture(media("ring", DEFAULT_RING))
    self.ring:SetTexCoord(Bricks.caseCoords(RING_FULL))
    tint(self.ring, "SetVertexColor", ringColor(data.quality))
    self.ring:SetAlpha(alpha)
    self.ring:Show()
  else
    self.ring:Hide()
  end

  self.name:ClearAllPoints()
  self.name:SetPoint("TOP", self, "TOP", 0, -nameTop)
  self.name:SetWidth(nameWidth)
  self.name:SetHeight(nameHeight)
  Bricks.font(self.name, "small")

  if round and not dim and value("nameQualityColor", false) == true then
    tint(self.name, "SetTextColor", ringColor(data.quality))
  else
    Bricks.paint(self.name, "SetTextColor", dim and "muted" or "text")
  end

  self.name:SetText(data.name or "")

  self.lock:ClearAllPoints()
  self.lock:SetPoint("TOPRIGHT", self.icon, "TOPRIGHT", 2, 2)
  self.lock:SetWidth(mark)
  self.lock:SetHeight(mark)
  glyph(self.lock, "lock")
  tint(self.lock, "SetVertexColor", general("palette.title", COLORS.lock))
  if data.locked == true then
    self.lock:Show()
  else
    self.lock:Hide()
  end

  self.mark:ClearAllPoints()
  self.mark:SetPoint("BOTTOMRIGHT", self.icon, "BOTTOMRIGHT", 2, -2)
  self.mark:SetWidth(mark)
  self.mark:SetHeight(mark)
  local book = value("book")

  if round and data.markKind ~= "bag" then
    self.mark:ClearAllPoints()
    self.mark:SetPoint("BOTTOMRIGHT", self.icon, "BOTTOMRIGHT", value("bookCorner", 0), -value("bookCorner", 0))
    self.mark:SetWidth(size * value("bookScale", 0))
    self.mark:SetHeight(size * value("bookScale", 0))
    if type(book) == "string" and book ~= "" then
      self.mark:SetTexture(book)
      self.mark:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      self.mark:SetVertexColor(1, 1, 1)
    else
      book = nil
    end
  else
    glyph(self.mark, data.markKind == "bag" and "bag" or "book")
    tint(self.mark, "SetVertexColor", value("markColor", COLORS.mark))
  end

  self.mark:SetAlpha(round and alpha or 1)
  if data.marked == true and (not round or data.markKind == "bag" or book) then
    self.mark:Show()
  else
    self.mark:Hide()
  end

  local stacks = data.stacks

  self.stacks:ClearAllPoints()
  self.stacks:SetPoint("BOTTOMLEFT", self.icon, "BOTTOMLEFT", 1, 0)
  Bricks.font(self.stacks, "small")
  tint(self.stacks, "SetTextColor", value("stacksColor", COLORS.stacks))

  if type(stacks) == "number" and stacks > 0 then
    self.stacks:SetText(tostring(floor(stacks)))
    self.stacks:Show()
  else
    self.stacks:SetText("")
    self.stacks:Hide()
  end

  if missing then
    local fr, fg, fb = rgb(value("missingFill", COLORS.missingFill))
    local br, bg, bb = rgb(value("missingBorder", COLORS.missingBorder))

    self:SetBackdropColor(fr, fg, fb, 1)
    self:SetBackdropBorderColor(br, bg, bb, 1)
  else
    self:SetBackdropColor(0, 0, 0, 0)
    self:SetBackdropBorderColor(0, 0, 0, 0)
  end

  if data.selected == true then
    local sr, sg, sb = rgb(general("palette.selected", COLORS.selected))

    self:SetBackdropBorderColor(sr, sg, sb, 1)
  end

  self.tipTitle = data.tipTitle or data.name
  self.tipBody = data.tip
  self.tipFill = data.tipFill
end

BOX.kitRefresh = BOX.Layout

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Bricks, "apply", function()
    for box in pairs(instances) do
      box:Layout()
    end
  end)
end

function BOX:SetData(data)
  if type(data) == "table" then
    for name, item in pairs(data) do
      self.data[name] = item
    end
  end

  if type(self.data.badge) == "string" and not self.badge then
    self.badge = self:CreateTexture(nil, "OVERLAY", nil, 4)
  end

  self:Layout()

  return self
end

function BOX:GetData()
  return self.data
end

function BOX:SetState(name)
  if not STATES[name] then
    error(format("EbonAPI: %s: echoTile state expects normal, dim or missing, got %s", self.owner or "echoTile", tostring(name)), 2)
  end

  self.state = name
  self:Layout()

  return self
end

function BOX:GetState()
  return self.state
end

local function checkEchoTile(owner, spec, level)
  for _, name in ipairs({ "name", "tip", "tipTitle", "state", "markKind" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "string" then
      error(format("EbonAPI: %s: echoTile %s expects a text, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  if spec.tipFill ~= nil and type(spec.tipFill) ~= "function" then
    error(format("EbonAPI: %s: echoTile tipFill expects a function, got %s", owner, tostring(spec.tipFill)), level + 1)
  end

  for _, name in ipairs({ "quality", "stacks", "size" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "number" then
      error(format("EbonAPI: %s: echoTile %s expects a number, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  for _, name in ipairs({ "locked", "marked", "ring", "selected" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "boolean" then
      error(format("EbonAPI: %s: echoTile %s expects a boolean, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  for _, name in ipairs({ "onClick", "onEnter", "onLeave" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "function" then
      error(format("EbonAPI: %s: echoTile %s expects a function, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  if spec.state ~= nil and not STATES[spec.state] then
    error(format("EbonAPI: %s: echoTile state expects normal, dim or missing, got %s", owner, tostring(spec.state)), level + 1)
  end
end

local function newEchoTile(owner, parent, spec)
  local box = CreateFrame("Frame", nil, parent)

  for name, fn in pairs(BOX) do
    box[name] = fn
  end

  box.owner = owner
  box.state = spec.state or "normal"
  box.data = {}

  for _, name in ipairs({ "icon", "name", "quality", "locked", "marked", "markKind", "stacks", "tip", "tipTitle", "tipFill", "ring", "selected", "size" }) do
    box.data[name] = spec[name]
  end

  local solid = media("solid", DEFAULT_SOLID)

  box:SetBackdrop({ bgFile = solid, edgeFile = solid, edgeSize = 1 })

  box.disc = box:CreateTexture(nil, "BORDER")
  box.plain = box:CreateTexture(nil, "ARTWORK")
  box.portrait = box:CreateTexture(nil, "ARTWORK")
  box.icon = box.plain
  box.ring = box:CreateTexture(nil, "OVERLAY", nil, 2)
  box.lock = box:CreateTexture(nil, "OVERLAY", nil, 4)
  box.mark = box:CreateTexture(nil, "OVERLAY", nil, 4)
  box.name = Bricks.text(box, "small", "text")
  box.stacks = Bricks.text(box, "small", "text")
  box.name:SetJustifyH("CENTER")
  box.name:SetJustifyV("TOP")

  if box.name.SetWordWrap then
    box.name:SetWordWrap(true)
  end

  box:EnableMouse(true)
  box.kitOwnTip = true
  box:SetScript("OnEnter", function(self)
    if self.tipTitle or self.tipBody then
      Bricks.enterTip(self)
    end

    if type(self.tipFill) == "function" and GameTooltip and GameTooltip:IsOwned(self) then
      local ok, err = pcall(self.tipFill, Kit.lines(GameTooltip), self)

      if not ok and type(geterrorhandler) == "function" then
        geterrorhandler()(err)
      end

      GameTooltip:Show()
    end

    if self.spec and self.spec.onEnter then
      self.spec.onEnter(self)
    end
  end)
  box:SetScript("OnLeave", function(self)
    Bricks.hideTip()

    if self.spec and self.spec.onLeave then
      self.spec.onLeave(self)
    end
  end)
  box:SetScript("OnMouseUp", function(self, button)
    if self.spec and self.spec.onClick then
      self.spec.onClick(self, button)
    end
  end)

  instances[box] = true
  box:Layout()

  return box
end

Kit.addKind("echoTile", newEchoTile, checkEchoTile)
