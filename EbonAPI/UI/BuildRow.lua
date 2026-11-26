EbonAPI = EbonAPI or {}
EbonAPI.BuildRow = {}

local BuildRow = EbonAPI.BuildRow
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit
local Palette = EbonAPI.Palette

local format, max, floor = string.format, math.max, math.floor
local ipairs, pairs, type, tostring, tonumber = ipairs, pairs, type, tostring, tonumber

local HEIGHT, DISC, ECHO, GAP, SLOTS = 50, 32, 22, 4, 6
local DEFAULT_WIDTH = 1200
local instances = setmetatable({}, { __mode = "k" })

local function hex(key, fallback)
  local found = Bricks.value(key)

  if type(found) ~= "number" then
    return fallback
  end

  return found
end

local function paint(key, fallback, alpha)
  local r, g, b = Palette.unpackColor(floor(tonumber(hex(key, fallback)) or 0))

  return { r, g, b, alpha }
end

local function gold()
  return paint("palette.title", 0xFFD100, 1)
end

local function neutral()
  return paint("widgets.buildRow.neutral", 0x737380, 1)
end

local function fillNormal()
  return paint("widgets.buildRow.fillNormal", 0x141724, 0.9)
end

local function fillSelected()
  return paint("widgets.buildRow.fillSelected", 0x1A295C, 1)
end

local function edgeNormal()
  return paint("widgets.buildRow.edgeNormal", 0x594D1F, 1)
end

local function solid()
  return Bricks.media("solid")
end

local MISSING_KEY = "BUILD_ROW_MISSING"
local MISSING_FALLBACK = "missing %d"

local function tr(key, fallback)
  if EbonAPI.L then
    local text = EbonAPI.L[key]

    if type(text) == "string" and text ~= "" and text ~= key then
      return text
    end
  end

  return fallback
end

local function checkSpec(owner, spec, level)
  if type(spec) ~= "table" then
    error(format("EbonAPI: %s: buildRow expects a table, got %s", owner, type(spec)), level + 1)
  end

  if spec.missing ~= nil and type(spec.missing) ~= "number" then
    error(format("EbonAPI: %s: buildRow missing expects a number, got %s", owner, tostring(spec.missing)), level + 1)
  end

  if spec.echoes ~= nil and type(spec.echoes) ~= "table" then
    error(format("EbonAPI: %s: buildRow echoes expects a list, got %s", owner, tostring(spec.echoes)), level + 1)
  end

  if spec.onClick ~= nil and type(spec.onClick) ~= "function" then
    error(format("EbonAPI: %s: buildRow onClick expects a function, got %s", owner, tostring(spec.onClick)), level + 1)
  end
end

local function color(value)
  if type(value) == "table" then
    return value[1] or value.r or 1, value[2] or value.g or 1, value[3] or value.b or 1, value[4] or value.a or 1
  end

  local tint = neutral()

  return tint[1], tint[2], tint[3], tint[4]
end

local function edge(frame, tint)
  frame.top:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
  frame.bottom:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
  frame.left:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
  frame.right:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
end

local function addEdge(frame, layer)
  frame.top = frame:CreateTexture(nil, layer)
  frame.top:SetTexture(solid())
  frame.top:SetHeight(1)
  frame.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.bottom = frame:CreateTexture(nil, layer)
  frame.bottom:SetTexture(solid())
  frame.bottom:SetHeight(1)
  frame.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  frame.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  frame.left = frame:CreateTexture(nil, layer)
  frame.left:SetTexture(solid())
  frame.left:SetWidth(1)
  frame.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  frame.right = frame:CreateTexture(nil, layer)
  frame.right:SetTexture(solid())
  frame.right:SetWidth(1)
  frame.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
end

local ROW = {}

function ROW:Layout()
  local width = self.rowWidth or DEFAULT_WIDTH

  self.nativeSetWidth(self, width)
  self:SetHeight(HEIGHT)

  local selected = self.state == "selected"
  local fill = selected and fillSelected() or fillNormal()

  self.back:SetVertexColor(fill[1], fill[2], fill[3], fill[4])
  edge(self, selected and gold() or edgeNormal())

  local data = self.data or {}

  self.disc:SetVertexColor(color(data.classColor))

  local text = paint("palette.text", 0xFFFFFF, 1)
  local missingTint = paint("widgets.buildRow.missing", 0xE6594D, 1)
  local holeTint = paint("widgets.buildRow.hole", 0x0D0D14, 1)
  local lockTint = gold()

  self.initials:SetTextColor(text[1], text[2], text[3], text[4])
  self.missing:SetTextColor(missingTint[1], missingTint[2], missingTint[3], missingTint[4])
  self.initials:SetText(data.initials or "")
  self.name:SetText(data.player or data.name or "")

  local right = 10

  if type(data.missing) == "number" and data.missing > 0 then
    self.missing:SetText(format(data.missingText or tr(MISSING_KEY, MISSING_FALLBACK), data.missing))
    self.missing:Show()
    right = right + max(1, self.missing:GetStringWidth() or 0) + 10
  else
    self.missing:SetText("")
    self.missing:Hide()
  end

  local strip = SLOTS * ECHO + (SLOTS - 1) * GAP

  for index = 1, SLOTS do
    local slot = self.slots[index]
    local echo = data.echoes and data.echoes[index]

    slot:ClearAllPoints()
    slot:SetPoint("LEFT", self, "RIGHT", -(right + strip) + (index - 1) * (ECHO + GAP), 0)

    if echo then
      slot.ring:SetVertexColor(color(echo.color))
      slot.hole:SetVertexColor(holeTint[1], holeTint[2], holeTint[3], holeTint[4])
      slot.lock:SetVertexColor(lockTint[1], lockTint[2], lockTint[3], lockTint[4])
      if echo.locked then
        slot.lock:Show()
      else
        slot.lock:Hide()
      end

      slot:Show()
    else
      slot:Hide()
    end
  end

  self.name:ClearAllPoints()
  self.name:SetPoint("LEFT", self, "LEFT", 10 + DISC + 10, 0)
  self.name:SetWidth(max(1, width - (10 + DISC + 10) - (right + strip + 10)))
end

function ROW:SetData(data)
  checkSpec("buildRow", data or {}, 2)

  local merged = {}

  for key, value in pairs(data or {}) do
    merged[key] = value
  end

  self.data = merged
  self.onClick = merged.onClick or self.onClick

  if merged.selected ~= nil then
    self.state = merged.selected and "selected" or "normal"
  end

  self:Layout()

  return self
end

function ROW:SetState(state)
  self.state = state == "selected" and "selected" or "normal"
  self:Layout()

  return self
end

function ROW:GetState()
  return self.state
end

function ROW:SetWidth(width)
  self.rowWidth = width
  self.nativeSetWidth(self, width)
  self:Layout()

  return self
end

function ROW:Refresh()
  self:Layout()
end

ROW.kitRefresh = ROW.Refresh

function ROW:PreferredHeight()
  return HEIGHT
end

local function newSlot(parent)
  local slot = CreateFrame("Frame", nil, parent)

  slot:SetWidth(ECHO)
  slot:SetHeight(ECHO)
  slot.ring = slot:CreateTexture(nil, "ARTWORK")
  slot.ring:SetTexture(Bricks.media("circle"))
  slot.ring:SetAllPoints(slot)
  slot.hole = slot:CreateTexture(nil, "OVERLAY")
  slot.hole:SetTexture(Bricks.media("circle"))
  slot.hole:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -3)
  slot.hole:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -3, 3)
  slot.lock = slot:CreateTexture(nil, "OVERLAY")
  slot.lock:SetTexture(solid())
  slot.lock:SetWidth(6)
  slot.lock:SetHeight(6)
  slot.lock:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 1, 1)
  slot.lock:Hide()

  return slot
end

function BuildRow.build(parent)
  local row = CreateFrame("Button", nil, parent)

  row.nativeSetWidth = row.SetWidth

  for name, fn in pairs(ROW) do
    row[name] = fn
  end

  row.state = "normal"
  row.data = {}
  row.back = row:CreateTexture(nil, "BACKGROUND")
  row.back:SetTexture(solid())
  row.back:SetAllPoints(row)
  addEdge(row, "BORDER")

  row.disc = row:CreateTexture(nil, "ARTWORK")
  row.disc:SetTexture(Bricks.media("circle"))
  row.disc:SetWidth(DISC)
  row.disc:SetHeight(DISC)
  row.disc:SetPoint("LEFT", row, "LEFT", 10, 0)

  row.initials = Bricks.text(row, "small", "text")
  row.initials:SetPoint("CENTER", row.disc, "CENTER", 0, 0)

  row.name = Bricks.text(row, "normal", "text")
  row.name:SetJustifyH("LEFT")

  if row.name.SetWordWrap then
    row.name:SetWordWrap(false)
  end

  row.missing = Bricks.text(row, "small", "muted")
  row.missing:SetPoint("RIGHT", row, "RIGHT", -10, 0)
  row.missing:SetJustifyH("RIGHT")

  row.slots = {}

  for index = 1, SLOTS do
    row.slots[index] = newSlot(row)
  end

  row:RegisterForClicks("LeftButtonUp")
  row:SetScript("OnClick", function(self)
    if self.onClick then
      self.onClick(self, self.data)
    end
  end)
  row:Layout()
  instances[row] = true

  return row
end

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Bricks, "apply", function()
    for row in pairs(instances) do
      row:Layout()
    end
  end)
end

local function newRow(owner, parent, spec)
  local row = BuildRow.build(parent)

  row.owner, row.spec = owner, spec
  row.rowWidth = spec.width or DEFAULT_WIDTH
  row.onClick = spec.onClick
  row.state = spec.selected and "selected" or "normal"
  row:SetData(spec)

  return row
end

Kit.addKind("buildRow", newRow, checkSpec)
