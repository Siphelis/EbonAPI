EbonAPI = EbonAPI or {}
EbonAPI.Choice = {}

local Choice = EbonAPI.Choice
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, floor, max, min = string.format, math.floor, math.max, math.min
local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local S = Bricks.value

Bricks.CONTRACT.choice = { "SetItems", "SetValue", "GetValue", "SetCount", "SetWidth", "Relayout" }

local SHAPES = { segment = true, chips = true }

local function key(shape, name)
  return S("widgets.choice." .. shape .. "." .. name)
end

local function validItems(owner, items, level)
  if type(items) ~= "table" then
    error(format("EbonAPI: %s: choice items expects a list, got %s", owner, tostring(items)), level + 1)
  end

  local seen = {}

  for index, item in ipairs(items) do
    if type(item) ~= "table" then
      error(format("EbonAPI: %s: choice item %d expects a table, got %s", owner, index, tostring(item)), level + 1)
    end

    if type(item.id) ~= "string" and type(item.id) ~= "number" then
      error(format("EbonAPI: %s: choice item %d id expects a string or a number, got %s", owner, index,
        tostring(item.id)), level + 1)
    end

    if seen[item.id] then
      error(format("EbonAPI: %s: choice item id %s is used twice", owner, tostring(item.id)), level + 1)
    end

    seen[item.id] = true

    if type(item.text) ~= "string" then
      error(format("EbonAPI: %s: choice item %d text expects a string, got %s", owner, index, tostring(item.text)),
        level + 1)
    end

    if item.count ~= nil and type(item.count) ~= "number" then
      error(format("EbonAPI: %s: choice item %d count expects a number, got %s", owner, index, tostring(item.count)),
        level + 1)
    end
  end
end

local function checkChoice(owner, spec, level)
  if not SHAPES[spec.shape] then
    error(format("EbonAPI: %s: choice shape expects segment or chips, got %s", owner, tostring(spec.shape)), level + 1)
  end

  validItems(owner, spec.items, level + 1)

  if spec.onChange ~= nil and type(spec.onChange) ~= "function" then
    error(format("EbonAPI: %s: onChange expects a function, got %s", owner, tostring(spec.onChange)), level + 1)
  end

  if spec.value ~= nil then
    local found = false

    for _, item in ipairs(spec.items) do
      found = found or item.id == spec.value
    end

    if not found then
      error(format("EbonAPI: %s: choice value %s is not one of the items", owner, tostring(spec.value)), level + 1)
    end
  end
end

local BOX = {}

function BOX:Shape()
  return (self.spec and self.spec.shape) or "segment"
end

function BOX:Pad(shape)
  local size = S("fonts." .. S("widgets.choice.font") .. ".size")

  return floor(size / 2) + Bricks.insetOf(self.chips[1] or self)
end

function BOX:Paint(chip)
  local shape = self:Shape()
  local selected = self.value ~= nil and chip.id == self.value

  Bricks.frame(chip, key(shape, "frame"):lower(), selected and key(shape, "selected") or key(shape, "fill"),
    key(shape, "border"))
  chip.selected = selected

  -- Same pair as the selected state of a Bricks button (fill "selected", text "selectedText").
  Bricks.paint(chip.label, "SetTextColor", selected and "selectedText" or "text")
end

function BOX:Chip(index)
  local chip = self.chips[index]

  if chip then
    return chip
  end

  local role = S("widgets.choice.font")
  local shape = self:Shape()

  chip = CreateFrame("Button", nil, self)
  chip.label = Bricks.text(chip, role, "text")
  chip.label:SetJustifyH("CENTER")

  if shape == "chips" then
    chip.count = Bricks.text(chip, role, key("chips", "count"))
    chip.count:SetJustifyH("LEFT")
  end

  chip:SetScript("OnClick", function(button)
    self:Pick(button.id)
  end)

  self.chips[index] = chip

  return chip
end

function BOX:Pick(id)
  if id == nil or id == self.value then
    return
  end

  self:SetValue(id)

  local fn = self.spec and self.spec.onChange

  if fn then
    fn(id)
  end
end

function BOX:Fill()
  local items = self.items

  for index, item in ipairs(items) do
    local chip = self:Chip(index)

    chip.id = item.id
    chip.label:SetText(item.text)

    if chip.count then
      chip.count:SetText(item.count ~= nil and tostring(item.count) or "")
    end

    chip:Show()
    self:Paint(chip)
  end

  for index = #items + 1, #self.chips do
    self.chips[index].id = nil
    self.chips[index]:Hide()
  end
end

-- Slack added to the measured text, in pixels, in case the font draws a little wider than it measures.
local SLACK = 2

function BOX:Natural(chip, item, pad)
  -- A label that was given a width earlier measures only its wrapped line: free it before measuring.
  chip.label:SetWidth(0)

  local width = math.ceil(chip.label:GetStringWidth()) + 2 * pad + SLACK

  if chip.count and item.count ~= nil then
    width = width + chip.count:GetStringWidth() + key("chips", "gap")
  end

  return width
end

function BOX:Place(chip, x, y, width, height, pad, item)
  chip:ClearAllPoints()
  chip:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
  chip:SetWidth(width)
  chip:SetHeight(height)
  chip.label:ClearAllPoints()
  chip.label:SetWidth(max(1, width - 2 * pad))

  if chip.count and item.count ~= nil then
    local countWidth = chip.count:GetStringWidth()
    local labelWidth = max(1, min(chip.label:GetStringWidth(), width - 2 * pad - countWidth - key("chips", "gap")))

    chip.label:SetWidth(labelWidth)
    chip.label:SetJustifyH("LEFT")
    chip.label:SetPoint("LEFT", chip, "LEFT", pad, 0)
    chip.count:ClearAllPoints()
    chip.count:SetPoint("LEFT", chip.label, "RIGHT", key("chips", "gap"), 0)
    chip.count:SetWidth(max(1, countWidth + 1))
    chip.count:Show()
  else
    chip.label:SetPoint("CENTER", chip, "CENTER", 0, 0)
    chip.label:SetJustifyH("CENTER")

    if chip.count then
      chip.count:Hide()
    end
  end
end

function BOX:Relayout()
  local shape = self:Shape()
  local items = self.items
  local gap, height = key(shape, "gap"), key(shape, "height")
  local count = #items

  self.rows = 0

  if count == 0 then
    self.nativeSetHeight(self, height)
    self.rows = 1

    return self
  end

  local pad = self:Pad(shape)
  local natural = {}
  local total = 0

  for index, item in ipairs(items) do
    natural[index] = self:Natural(self.chips[index], item, pad)
    total = total + natural[index]
  end

  local width = self.boxWidth
  local needed = total + gap * (count - 1)

  if shape == "segment" then
    -- Equal segments, each as wide as the widest label needs: the need wins over the width asked for.
    local widest = 0

    for index = 1, count do
      widest = max(widest, natural[index])
    end

    needed = widest * count + gap * (count - 1)
  end

  if not width or (shape == "segment" and width < needed) then
    width = needed
    self.nativeSetWidth(self, width)
  else
    self.nativeSetWidth(self, width)
  end

  if shape == "segment" then
    local each = max(1, floor((width - gap * (count - 1)) / count))

    for index, item in ipairs(items) do
      self:Place(self.chips[index], (index - 1) * (each + gap), 0, each, height, pad, item)
    end

    self.rows = 1
    self.nativeSetHeight(self, height)

    return self
  end

  local x, row = 0, 0

  for index, item in ipairs(items) do
    local chipWidth = min(natural[index], width)

    if x > 0 and x + chipWidth > width then
      x, row = 0, row + 1
    end

    self:Place(self.chips[index], x, row * (height + gap), chipWidth, height, pad, item)
    x = x + chipWidth + gap
  end

  self.rows = row + 1
  self.nativeSetHeight(self, self.rows * height + row * gap)

  return self
end

function BOX:SetWidth(width)
  self.boxWidth = width
  self.nativeSetWidth(self, width)

  return self:Relayout()
end

function BOX:SetItems(items)
  validItems(self.owner or "EbonAPI", items, 2)

  self.items = items

  local keep = false

  for _, item in ipairs(items) do
    keep = keep or item.id == self.value
  end

  if not keep then
    self.value = nil
  end

  self:Fill()

  return self:Relayout()
end

function BOX:SetValue(id)
  self.value = id

  for index = 1, #self.items do
    self:Paint(self.chips[index])
  end

  return self
end

function BOX:GetValue()
  return self.value
end

function BOX:SetCount(id, count)
  for index, item in ipairs(self.items) do
    if item.id == id then
      item.count = count

      local chip = self.chips[index]

      if chip.count then
        chip.count:SetText(count ~= nil and tostring(count) or "")
      end

      return self:Relayout()
    end
  end

  return self
end

function BOX:kitRefresh()
  if self.items then
    self:Fill()
    self:Relayout()
  end
end

function Choice.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  box.nativeSetHeight, box.nativeSetWidth = box.SetHeight, box.SetWidth

  for name, fn in pairs(BOX) do
    box[name] = fn
  end

  box.chips, box.items, box.rows = {}, {}, 0

  return box
end

Bricks.register("choice", "default", function(parent)
  return Choice.build(parent)
end)

local function newChoice(owner, parent, spec)
  local box = Bricks.create("choice", parent)

  box.owner, box.spec = owner, spec
  box.value = spec.value
  box.items = spec.items
  box:Fill()
  box:Relayout()

  return box
end

Kit.addKind("choice", newChoice, checkChoice)
