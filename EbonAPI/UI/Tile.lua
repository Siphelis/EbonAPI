EbonAPI = EbonAPI or {}
EbonAPI.Tile = {}

local Tile = EbonAPI.Tile
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, max, min, ceil = string.format, math.max, math.min, math.ceil
local lower = string.lower
local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local S = Bricks.value
local PAD, SPACE = EbonAPI.Tiles.PAD, EbonAPI.Tiles.SPACE

Bricks.CONTRACT.tile = { "SetItem", "GetItem", "SetWidth", "Refresh", "PreferredHeight" }

Tile.looks = {}

local LEVELS = { warn = "gauge.warn", bad = "gauge.bad" }

local function tileKey(name)
  return S("widgets.tile." .. name)
end

local function checkItem(owner, item, level)
  if type(item) ~= "table" then
    error(format("EbonAPI: %s: tile expects a table, got %s", owner, type(item)), level + 1)
  end

  for _, name in ipairs({ "label", "value", "sub", "tip" }) do
    if item[name] ~= nil and type(item[name]) ~= "string" then
      error(format("EbonAPI: %s: tile %s expects a text, got %s", owner, name, tostring(item[name])), level + 1)
    end
  end

  if item.level ~= nil and item.level ~= "ok" and not LEVELS[item.level] then
    error(format("EbonAPI: %s: tile level expects ok, warn or bad, got %s", owner, tostring(item.level)), level + 1)
  end

  if item.gauge ~= nil and type(item.gauge) ~= "number" then
    error(format("EbonAPI: %s: tile gauge expects a number, got %s", owner, tostring(item.gauge)), level + 1)
  end

  if item.accent ~= nil and type(item.accent) ~= "boolean" then
    error(format("EbonAPI: %s: tile accent expects a boolean, got %s", owner, tostring(item.accent)), level + 1)
  end
end

local lineHeight = EbonAPI.Tiles.lineHeight

local BOX = {}

function BOX:Metrics()
  local labelRole, valueRole, subRole = tileKey("label.font"), tileKey("value.font"), tileKey("sub.font")
  local inset = Bricks.insetOf(self) + PAD
  local first = ceil(S("fonts." .. labelRole .. ".size"))
  local second = ceil(S("fonts." .. valueRole .. ".size"))
  local third = ceil(S("fonts." .. subRole .. ".size"))
  local gauge = tileKey("gauge.height")

  return inset, first, second, third, gauge
end

function BOX:PreferredHeight()
  local inset, first, second, third, gauge = self:Metrics()
  local need = inset * 2 + first + second + third + gauge + SPACE * 3

  return max(tileKey("height"), need)
end

function BOX:Layout()
  local item = self.item or {}
  local labelRole, valueRole, subRole = tileKey("label.font"), tileKey("value.font"), tileKey("sub.font")
  local border = item.accent and tileKey("accent") or tileKey("border")
  local width = self.boxWidth or tileKey("width")

  Bricks.frame(self, lower(tileKey("frame")), tileKey("fill"), border)
  self.borderKey = border

  Bricks.font(self.label, labelRole)
  Bricks.font(self.value, valueRole)
  Bricks.font(self.sub, subRole)
  Bricks.paint(self.label, "SetTextColor", "muted")
  Bricks.paint(self.value, "SetTextColor", "text")
  Bricks.paint(self.sub, "SetTextColor", "muted")
  self.label:SetText(item.label or "")
  self.value:SetText(item.value or "")
  self.sub:SetText(item.sub or "")

  local inset, first, second, third, gaugeHeight = self:Metrics()
  local height = self:PreferredHeight()
  local inner = max(1, width - inset * 2)

  self.nativeSetWidth(self, width)
  self:SetHeight(height)

  self.label:ClearAllPoints()
  self.label:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
  self.label:SetWidth(inner)
  self.label:SetHeight(first)
  self.value:ClearAllPoints()
  self.value:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -(inset + first + SPACE))
  self.value:SetWidth(inner)
  self.value:SetHeight(second)
  self.sub:ClearAllPoints()
  self.sub:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -(inset + first + second + SPACE * 2))
  self.sub:SetWidth(inner)
  self.sub:SetHeight(third)

  self.back:ClearAllPoints()
  self.back:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", inset, inset)
  self.back:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
  self.back:SetHeight(gaugeHeight)
  Bricks.paint(self.back, "SetVertexColor", tileKey("gauge.back"))

  local share = item.gauge

  self.gaugeInner = inner

  if share == nil then
    self.back:Hide()
    self.fill:Hide()
    self.share = nil
  else
    share = max(0, min(1, share))
    self.share = share
    self.back:Show()
    self.fill:ClearAllPoints()
    self.fill:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", inset, inset)
    self.fill:SetHeight(gaugeHeight)
    Bricks.paint(self.fill, "SetVertexColor", tileKey(LEVELS[item.level] or "gauge.fill"))

    if share * inner < 1 then
      self.fill:Hide()
    else
      self.fill:SetWidth(share * inner)
      self.fill:Show()
    end
  end

  EbonAPI.Tiles.setTip({ item = item, frame = self })
end

function BOX:SetItem(item)
  checkItem(self.owner or "tile", item, 2)

  local merged = {}

  for name, value in pairs(item) do
    merged[name] = value
  end

  self.item = merged
  self:Layout()

  return self
end

function BOX:GetItem()
  return self.item
end

function BOX:SetWidth(width)
  self.boxWidth = width
  self.nativeSetWidth(self, width)

  if self.item then
    self:Layout()
  end

  return self
end

function BOX:Refresh()
  self:Layout()
end

BOX.kitRefresh = BOX.Refresh

function Tile.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  box.nativeSetWidth = box.SetWidth

  for name, fn in pairs(BOX) do
    box[name] = fn
  end

  box.item = {}
  box.back = box:CreateTexture(nil, "ARTWORK")
  box.back:SetTexture(Bricks.media("solid"))
  box.fill = box:CreateTexture(nil, "OVERLAY")
  box.fill:SetTexture(Bricks.media("solid"))
  box.label = Bricks.text(box, tileKey("label.font"), "muted")
  box.value = Bricks.text(box, tileKey("value.font"), "text")
  box.sub = Bricks.text(box, tileKey("sub.font"), "muted")

  for _, fs in ipairs({ box.label, box.value, box.sub }) do
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")

    if fs.SetWordWrap then
      fs:SetWordWrap(false)
    end
  end

  box:EnableMouse(true)
  box:SetScript("OnEnter", function(self)
    Bricks.enterTip(self)
  end)
  box:SetScript("OnLeave", function()
    Bricks.hideTip()
  end)
  box.kitOwnTip = true
  box:Layout()

  return box
end

Tile.looks.default = {}

Bricks.register("tile", "default", Tile.build)

local function checkTile(owner, spec, level)
  checkItem(owner, spec, level + 1)
end

local function newTile(owner, parent, spec)
  local box = Bricks.create("tile", parent)

  box.owner, box.spec = owner, spec

  if spec.width then
    box.boxWidth = spec.width
  end

  box:SetItem(spec)

  return box
end

Kit.addKind("tile", newTile, checkTile)
