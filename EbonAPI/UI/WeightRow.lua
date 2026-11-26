EbonAPI = EbonAPI or {}
EbonAPI.WeightRow = {}

local WeightRow = EbonAPI.WeightRow
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, max, min, floor = string.format, math.max, math.min, math.floor
local concat = table.concat
local ipairs, pairs, type, tostring, tonumber = ipairs, pairs, type, tostring, tonumber

local WIDTH, HEIGHT = 1070, 42
local STARS, STAR_SIZE, STAR_GAP = 5, 18, 2
local DISC, ICON = 30, 26
local FIELD_WIDTH, FIELD_HEIGHT = 70, 22
local STATES = { none = true, locked = true, banned = true }

local function checkSpec(owner, spec, level)
  if spec.icon ~= nil and type(spec.icon) ~= "string" and type(spec.icon) ~= "number" then
    error(format("EbonAPI: %s: weightRow icon expects a texture, got %s", owner, tostring(spec.icon)), level + 1)
  end

  if spec.name ~= nil and type(spec.name) ~= "string" then
    error(format("EbonAPI: %s: weightRow name expects a text, got %s", owner, tostring(spec.name)), level + 1)
  end

  for _, key in ipairs({ "stars", "weight" }) do
    if spec[key] ~= nil and type(spec[key]) ~= "number" then
      error(format("EbonAPI: %s: weightRow %s expects a number, got %s", owner, key, tostring(spec[key])), level + 1)
    end
  end

  if spec.scores ~= nil and type(spec.scores) ~= "table" then
    error(format("EbonAPI: %s: weightRow scores expects a table, got %s", owner, tostring(spec.scores)), level + 1)
  end

  if spec.state ~= nil and not STATES[spec.state] then
    error(format("EbonAPI: %s: weightRow state expects none, locked or banned, got %s", owner, tostring(spec.state)), level + 1)
  end

  for _, key in ipairs({ "onStars", "onWeight" }) do
    if spec[key] ~= nil and type(spec[key]) ~= "function" then
      error(format("EbonAPI: %s: weightRow %s expects a function, got %s", owner, key, tostring(spec[key])), level + 1)
    end
  end
end

local ROW = {}

function ROW:ClampStars(value)
  value = floor(tonumber(value) or 0)

  return max(0, min(STARS, value))
end

function ROW:ScoreText()
  local scores, parts = self.spec.scores, {}

  if type(scores) ~= "table" then
    return ""
  end

  for index = 1, 4 do
    parts[index] = tostring(scores[index] or 0)
  end

  return concat(parts, " - ")
end

function ROW:WeightText()
  local weight = self.spec.weight

  if type(weight) ~= "number" then
    return ""
  end

  return tostring(floor(weight))
end

function ROW:Refresh()
  local spec = self.spec
  local state = self.state or "none"
  local locked = state ~= "none"
  local filled = self:ClampStars(spec.stars)

  Bricks.frame(self, "small", "card", "borderDim")

  if spec.icon then
    self.icon:SetTexture(spec.icon)
    self.icon:Show()
  else
    self.icon:Hide()
  end

  Bricks.paint(self.ring, "SetVertexColor", "focus")

  self.name:SetText(spec.name or "")

  if state == "locked" then
    Bricks.paint(self.name, "SetTextColor", "title")
    self.tag:SetText(self.tagLocked)
    Bricks.paint(self.tag, "SetTextColor", "title")
    self.tag:Show()
  elseif state == "banned" then
    Bricks.paint(self.name, "SetTextColor", "muted")
    self.tag:SetText(self.tagBanned)
    Bricks.paint(self.tag, "SetTextColor", "muted")
    self.tag:Show()
  else
    Bricks.paint(self.name, "SetTextColor", "text")
    self.tag:SetText("")
    self.tag:Hide()
  end

  local left, bottom, right, top
  local onLeft, onBottom, onRight, onTop = Bricks.glyphCoords("starOn")
  local offLeft, offBottom, offRight, offTop = Bricks.glyphCoords("star")

  for index, star in ipairs(self.stars) do
    if index <= filled then
      left, bottom, right, top = onLeft, onBottom, onRight, onTop
      Bricks.paint(star.tex, "SetVertexColor", "title")
    else
      left, bottom, right, top = offLeft, offBottom, offRight, offTop
      Bricks.paint(star.tex, "SetVertexColor", "muted")
    end

    star.tex:SetTexCoord(left, bottom, right, top)
    star.filled = index <= filled
  end

  self.score:SetText(self:ScoreText())
  Bricks.paint(self.score, "SetTextColor", locked and "muted" or "text")

  if not self.field:HasFocus() then
    self.field:SetText(self:WeightText())
  end

  self.field:EnableMouse(not locked)
  self.field:SetAlpha(locked and 0.5 or 1)

  if locked then
    self.field:ClearFocus()
  end
end

ROW.kitRefresh = ROW.Refresh

function ROW:SetState(state)
  if not STATES[state] then
    error(format("EbonAPI: %s: weightRow state expects none, locked or banned, got %s", self.owner or "weightRow", tostring(state)), 2)
  end

  self.state = state
  self.spec.state = state
  self:Refresh()

  return self
end

function ROW:GetState()
  return self.state
end

function ROW:SetStars(value)
  self.spec.stars = self:ClampStars(value)
  self:Refresh()

  return self
end

function ROW:SetScores(scores)
  self.spec.scores = scores
  self:Refresh()

  return self
end

function ROW:SetWeight(value)
  self.spec.weight = value
  self:Refresh()

  return self
end

function ROW:GetWeight()
  return self.spec.weight
end

function ROW:SetName(text)
  self.spec.name = text
  self:Refresh()

  return self
end

function ROW:SetIcon(texture)
  self.spec.icon = texture
  self:Refresh()

  return self
end

function ROW:ApplyField()
  local text = self.field:GetText()
  local value = tonumber(text)

  if self.state ~= "none" then
    self.field:SetText(self:WeightText())

    return
  end

  if value == nil then
    self.field:SetText(self:WeightText())

    return
  end

  value = floor(value)

  if value == self.spec.weight then
    self.field:SetText(tostring(value))

    return
  end

  self.spec.weight = value
  self.field:SetText(tostring(value))

  if self.spec.onWeight then
    self.spec.onWeight(value)
  end
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

local function build(owner, parent, spec)
  local row = CreateFrame("Frame", nil, parent)

  for name, fn in pairs(ROW) do
    row[name] = fn
  end

  row.owner, row.spec = owner, spec
  row.state = spec.state or "none"
  row.tagLocked = tr("WEIGHT_ROW_LOCKED", "Locked")
  row.tagBanned = tr("WEIGHT_ROW_BANNED", "Banned")
  row:SetWidth(WIDTH)
  row:SetHeight(HEIGHT)

  row.ring = row:CreateTexture(nil, "BACKGROUND")
  row.ring:SetTexture(Bricks.media("solid"))
  row.ring:SetWidth(DISC)
  row.ring:SetHeight(DISC)
  row.ring:SetPoint("LEFT", row, "LEFT", 10, 0)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetWidth(ICON)
  row.icon:SetHeight(ICON)
  row.icon:SetPoint("CENTER", row.ring, "CENTER", 0, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.name = Bricks.text(row, "normal", "text")
  row.name:SetJustifyH("LEFT")
  row.name:SetWidth(300)
  row.name:SetHeight(HEIGHT)
  row.name:SetPoint("LEFT", row, "LEFT", 52, 0)

  row.tag = Bricks.text(row, "small", "muted")
  row.tag:SetJustifyH("LEFT")
  row.tag:SetWidth(90)
  row.tag:SetPoint("LEFT", row, "LEFT", 360, 0)

  row.stars = {}

  for index = 1, STARS do
    local star = CreateFrame("Button", nil, row)

    star:SetWidth(STAR_SIZE)
    star:SetHeight(STAR_SIZE)
    star:SetPoint("LEFT", row, "LEFT", 470 + (index - 1) * (STAR_SIZE + STAR_GAP), 0)
    star.tex = star:CreateTexture(nil, "ARTWORK")
    star.tex:SetAllPoints(star)
    star.tex:SetTexture(Bricks.media("icons"))
    star.index = index
    star:SetScript("OnClick", function(self)
      local at = self:GetParent()

      if at.spec.onStars then
        at.spec.onStars(self.index)
      end
    end)
    row.stars[index] = star
  end

  row.score = Bricks.text(row, "normal", "text")
  row.score:SetJustifyH("LEFT")
  row.score:SetWidth(220)
  row.score:SetPoint("LEFT", row, "LEFT", 700, 0)

  row.field = CreateFrame("EditBox", nil, row)
  row.field:SetWidth(FIELD_WIDTH)
  row.field:SetHeight(FIELD_HEIGHT)
  row.field:SetPoint("RIGHT", row, "RIGHT", -16, 0)
  row.field:SetAutoFocus(false)
  row.field:SetMaxLetters(6)
  row.field:SetJustifyH("CENTER")
  Bricks.font(row.field, "normal")
  Bricks.paint(row.field, "SetTextColor", "text")
  Bricks.frame(row.field, "small", "bg", "border")
  row.field:SetTextInsets(4, 4, 0, 0)
  row.field:SetScript("OnEnterPressed", function(self)
    self:GetParent():ApplyField()
    self:ClearFocus()
  end)
  row.field:SetScript("OnEditFocusLost", function(self)
    self:GetParent():ApplyField()
  end)
  row.field:SetScript("OnEscapePressed", function(self)
    self:SetText(self:GetParent():WeightText())
    self:ClearFocus()
  end)
  row.field:SetScript("OnTextChanged", function(self)
    local text = self:GetText()
    local clean = text:gsub("[^0-9]", "")

    if clean ~= text then
      self:SetText(clean)
    end
  end)

  row:Refresh()

  return row
end

Kit.addKind("weightRow", build, checkSpec)
