EbonAPI = EbonAPI or {}

local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit
local Palette = EbonAPI.Palette

local type, ipairs, pairs = type, ipairs, pairs
local floor = math.floor

local HEIGHT = 26
local LABEL_X = 4
local VALUE_X = 110
local LABEL_WIDTH = 100
local EDGE = 1
local MARGIN = 4
local NONE_KEY = "AFFIX_ROW_NONE"
local NONE = "none"

local function tr(key, fallback)
  if EbonAPI.L then
    local text = EbonAPI.L[key]

    if type(text) == "string" and text ~= "" and text ~= key then
      return text
    end
  end

  return fallback
end
local FALLBACK = {
  ["palette.text"] = 0xFFFFFF,
  ["palette.title"] = 0xFFD100,
  ["kit.affix.none"] = 0x808080,
  ["kit.category.offensive"] = 0xE05A4E,
  ["kit.category.defensive"] = 0x4A9BE0,
  ["kit.category.resource"] = 0x4CC26A,
  ["kit.category.utility"] = 0xF08A28,
  ["kit.category.mobility"] = 0xB06AE0,
}

local CATEGORIES = { offensive = true, defensive = true, resource = true, utility = true, mobility = true }

local instances = setmetatable({}, { __mode = "k" })

local function rgb(key)
  local found = Bricks.value(key)

  if type(found) ~= "number" then
    found = FALLBACK[key]
  end

  return Palette.unpackColor(floor(found))
end

local function categoryColor(category)
  if type(category) == "table" then
    return category[1], category[2], category[3]
  end

  if CATEGORIES[category] then
    return rgb("kit.category." .. category)
  end

  return rgb("palette.text")
end

local function check(owner, spec, level)
  for _, name in ipairs({ "label", "value", "none" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "string" then
      error(("EbonAPI: %s: affixSlot %s expects a string, got %s"):format(owner, name, type(spec[name])), level + 1)
    end
  end

  if spec.slot ~= nil and type(spec.slot) ~= "number" then
    error(("EbonAPI: %s: affixSlot slot expects a number, got %s"):format(owner, type(spec.slot)), level + 1)
  end
end

local function edge(frame, point, relative, w, h)
  local line = frame:CreateTexture(nil, "OVERLAY")

  line:SetTexture(Bricks.media("solid"))
  line:SetVertexColor(rgb("palette.title"))
  line:SetPoint(point, frame, point, 0, 0)

  if w then
    line:SetWidth(w)
  else
    line:SetPoint(relative[1], frame, relative[1], 0, 0)
    line:SetPoint(relative[2], frame, relative[2], 0, 0)
  end

  if h then
    line:SetHeight(h)
  end

  line:Hide()

  return line
end

local function build(owner, parent, spec)
  local row = CreateFrame("Frame", nil, parent)

  row:SetHeight(HEIGHT)
  row:SetWidth(spec.width or 280)
  row:EnableMouse(true)
  row.slot = spec.slot

  row.name = Bricks.text(row, "normal", "text")
  row.name:SetPoint("LEFT", row, "LEFT", LABEL_X, 0)
  row.name:SetWidth(LABEL_WIDTH)
  row.name:SetJustifyH("LEFT")

  row.affix = Bricks.text(row, "normal", "text")
  row.affix:SetPoint("LEFT", row, "LEFT", VALUE_X, 0)
  row.affix:SetPoint("RIGHT", row, "RIGHT", -MARGIN, 0)
  row.affix:SetJustifyH("LEFT")

  for _, fs in ipairs({ row.name, row.affix }) do
    fs:SetHeight(HEIGHT)

    if fs.SetWordWrap then
      fs:SetWordWrap(false)
    end
  end

  instances[row] = true

  row.edges = {
    edge(row, "TOP", { "LEFT", "RIGHT" }, nil, EDGE),
    edge(row, "BOTTOM", { "LEFT", "RIGHT" }, nil, EDGE),
    edge(row, "LEFT", { "TOP", "BOTTOM" }, EDGE, nil),
    edge(row, "RIGHT", { "TOP", "BOTTOM" }, EDGE, nil),
  }

  function row:SetHover(on)
    for _, line in ipairs(self.edges) do
      if on then
        line:Show()
      else
        line:Hide()
      end
    end
  end

  row:HookScript("OnEnter", function(self)
    self:SetHover(true)
  end)
  row:HookScript("OnLeave", function(self)
    self:SetHover(false)
  end)

  function row:kitRefresh()
    local current = self.spec
    local text
    local r, g, b

    self.slot = current.slot
    self.name:SetText(current.label or "")
    self.name:SetTextColor(rgb("palette.text"))

    if current.value ~= nil and current.value ~= "" then
      text = current.value
      r, g, b = categoryColor(current.category)
    else
      text = current.none or tr(NONE_KEY, NONE)
      r, g, b = rgb("kit.affix.none")
    end

    self.affix:SetText(text)
    self.affix:SetTextColor(r, g, b)

    for _, line in ipairs(self.edges) do
      line:SetVertexColor(rgb("palette.title"))
    end
  end

  return row
end

Kit.addKind("affixSlot", build, check)

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Bricks, "apply", function()
    for row in pairs(instances) do
      if row.spec then
        row:kitRefresh()
      end
    end
  end)
end
