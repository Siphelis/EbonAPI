EbonAPI = EbonAPI or {}
EbonAPI.TipCard = {}

local TipCard = EbonAPI.TipCard
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, lower, ceil = string.format, string.lower, math.ceil
local ipairs, type, tostring = ipairs, type, tostring
local S = Bricks.value

Bricks.CONTRACT.tipcard = { "Show", "Hide", "IsShown" }

local FUNCTIONS = {}

local function pad()
  return S("widgets.tipcard.padding")
end

local function lineAt(self, index)
  local row = self.rows[index]

  if not row then
    row = {
      left = Bricks.text(self, "small", "widgets.tipcard.text"),
      right = Bricks.text(self, "small", "widgets.tipcard.muted"),
    }
    row.left:SetJustifyH("LEFT")
    row.right:SetJustifyH("RIGHT")
    self.rows[index] = row
  end

  return row
end

function FUNCTIONS:Fill(data)
  data = data or {}

  local inner = S("widgets.tipcard.width") - 2 * pad()
  local top = -pad()
  local used = 0

  self.title:SetWidth(inner)
  self.title:SetText(data.title or "")
  self.title:ClearAllPoints()
  self.title:SetPoint("TOPLEFT", self, "TOPLEFT", pad(), top)

  if data.title and data.title ~= "" then
    used = ceil(self.title:GetStringHeight() or 0) + pad() / 2
    self.title:Show()
  else
    self.title:Hide()
  end

  self.body:SetWidth(inner)
  self.body:SetText(data.body or "")
  self.body:ClearAllPoints()
  self.body:SetPoint("TOPLEFT", self, "TOPLEFT", pad(), top - used)

  if data.body and data.body ~= "" then
    used = used + ceil(self.body:GetStringHeight() or 0) + pad() / 2
    self.body:Show()
  else
    self.body:Hide()
  end

  local lines = data.lines or {}

  local gap = pad() / 2

  for index, line in ipairs(lines) do
    local row = lineAt(self, index)
    local left, right = line[1] or "", line[2] or ""

    row.right:SetWidth(inner)
    row.right:SetText(right)

    local rightWidth = 0

    if right ~= "" then
      rightWidth = math.min(ceil(row.right:GetStringWidth() or 0), inner - gap)
    end

    row.right:SetWidth(rightWidth)
    row.right:ClearAllPoints()
    row.right:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad(), top - used)

    row.left:SetWidth(rightWidth > 0 and inner - rightWidth - gap or inner)
    row.left:SetText(left ~= "" and left or " ")
    row.left:ClearAllPoints()
    row.left:SetPoint("TOPLEFT", self, "TOPLEFT", pad(), top - used)

    row.left:Show()
    row.right:Show()
    used = used + math.max(ceil(row.left:GetStringHeight() or 0), ceil(row.right:GetStringHeight() or 0)) + 2
  end

  for index = #lines + 1, #self.rows do
    self.rows[index].left:Hide()
    self.rows[index].right:Hide()
  end

  self:SetWidth(S("widgets.tipcard.width"))
  self:SetHeight(used + 2 * pad())
end

function FUNCTIONS:Show(anchor, data)
  if anchor == nil then
    self.kitShow(self)

    return
  end

  self:Fill(data)
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", anchor, "TOPRIGHT", pad(), 0)
  self.anchor = anchor
  self.kitShow(self)
end

function FUNCTIONS:Hide()
  self.anchor = nil
  self.kitHide(self)
end

function FUNCTIONS:IsShown()
  return self.kitIsShown(self) and true or false
end

function TipCard.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  box.kitShow, box.kitHide, box.kitIsShown = box.Show, box.Hide, box.IsShown

  for name, fn in pairs(FUNCTIONS) do
    box[name] = fn
  end

  Bricks.frame(box, lower(S("widgets.tipcard.frame")), S("widgets.tipcard.fill"), S("widgets.tipcard.border"))
  box:SetFrameStrata("TOOLTIP")
  box.rows = {}
  box.title = Bricks.text(box, "normal", S("widgets.tipcard.title"))
  box.title:SetJustifyH("LEFT")
  box.body = Bricks.text(box, "small", S("widgets.tipcard.text"))
  box.body:SetJustifyH("LEFT")
  box:SetWidth(S("widgets.tipcard.width"))
  box.kitHide(box)

  return box
end

Bricks.register("tipcard", "default", TipCard.build)

local function checkTipCard(owner, spec, level)
  for name in pairs(spec) do
    if type(name) == "string" and name ~= "kind" and name ~= "name" and name ~= "key" and name ~= "id"
      and not name:find("^on%u") and name ~= "visible" and name ~= "hidden" and name ~= "shortcut"
      and name ~= "menu" and name ~= "tip" and name ~= "tipTitle" and name ~= "tipBody" then
      error(format("EbonAPI: %s: tipcard has no spec field %s", owner, tostring(name)), level + 1)
    end
  end
end

local function newTipCard(owner, parent, spec)
  local box = Bricks.create("tipcard", parent)

  box.owner, box.spec = owner, spec

  return box
end

Kit.addKind("tipcard", newTipCard, checkTipCard)
