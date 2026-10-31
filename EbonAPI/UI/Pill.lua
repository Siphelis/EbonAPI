EbonAPI = EbonAPI or {}
EbonAPI.Pill = {}

local Pill = EbonAPI.Pill
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, lower, ceil = string.format, string.lower, math.ceil
local ipairs, pcall, type, tostring = ipairs, pcall, type, tostring
local S = Bricks.value

Bricks.CONTRACT.pill = { "SetState", "Level", "TextWidth" }

local LEVELS = { ok = true, warn = true, bad = true, info = true }
local ORDER = { "ok", "warn", "bad", "info" }

Pill.levels = ORDER

local function margin()
  return ceil(S("widgets.pill.height") / 2)
end

local FUNCTIONS = {}

function FUNCTIONS:SetState(level, text)
  if not LEVELS[level] then
    error(format("EbonAPI: pill SetState expects ok, warn, bad or info, got %s", tostring(level)), 2)
  end

  text = text ~= nil and tostring(text) or ""
  self.level = level
  self.label:SetText(text)
  Bricks.paint(self.label, "SetTextColor", S("widgets.pill." .. level))

  if text == "" then
    self:Hide()

    return
  end

  self:SetWidth(self:TextWidth() + 2 * margin())
  self:Show()
end

function FUNCTIONS:Level()
  return self.level
end

function FUNCTIONS:TextWidth()
  return ceil(self.label:GetStringWidth() or 0)
end

function FUNCTIONS:kitRefresh()
  local spec = self.spec or {}
  local level, text = spec.level, spec.text

  if type(level) == "function" then
    local ok, value = pcall(level, self)

    level = ok and value or nil
  end

  if type(text) == "function" then
    local ok, value = pcall(text, self)

    text = ok and value or nil
  end

  if text == nil and spec.key then
    local L = EbonAPI.L

    text = (L and L[spec.key]) or spec.key
  end

  if text == nil and spec.level == nil then
    return
  end

  if text == nil then
    text = self.label:GetText()
  end

  self:SetState(LEVELS[level] and level or self.level, text)
end

function Pill.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  for name, fn in pairs(FUNCTIONS) do
    box[name] = fn
  end

  box.level = "info"
  box:SetHeight(S("widgets.pill.height"))
  Bricks.frame(box, lower(S("widgets.pill.frame")), S("widgets.pill.fill"), S("widgets.pill.border"))
  box.label = Bricks.text(box, S("widgets.pill.font"), S("widgets.pill.info"))
  box.label:SetPoint("CENTER", box, "CENTER", 0, 0)
  box.label:SetJustifyH("CENTER")
  box:SetWidth(2 * margin())
  box:Hide()

  return box
end

Bricks.register("pill", "default", Pill.build)

local function checkPill(owner, spec, level)
  local value = spec.level

  if value ~= nil and type(value) ~= "function" and not LEVELS[value] then
    error(format("EbonAPI: %s: pill level expects ok, warn, bad or info, got %s", owner, tostring(value)), level + 1)
  end

  for _, name in ipairs({ "text", "key" }) do
    local item = spec[name]

    if item ~= nil and type(item) ~= "string" and (name == "key" or type(item) ~= "function") then
      error(format("EbonAPI: %s: pill %s expects a string%s, got %s", owner, name,
        name == "text" and " or a function" or "", tostring(item)), level + 1)
    end
  end
end

local function newPill(owner, parent, spec)
  local box = Bricks.create("pill", parent)

  box.owner, box.spec = owner, spec

  return box
end

Kit.addKind("pill", newPill, checkPill)
