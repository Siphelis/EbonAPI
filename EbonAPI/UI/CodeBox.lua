EbonAPI = EbonAPI or {}

local Kit = EbonAPI.Kit
local Bricks = EbonAPI.Bricks
local Palette = EbonAPI.Palette

local max, floor = math.max, math.floor
local type, tostring, pairs, tonumber = type, tostring, pairs, tonumber

local SOLID = "Interface\\Buttons\\WHITE8X8"
local PAD = 6
local FOOTER = 14
local FILL = { 0, 0, 0, 1 }
local GOLD = { 1, 0.82, 0, 1 }
local WHITE = { 1, 1, 1, 1 }

local instances = setmetatable({}, { __mode = "k" })

local function color(key, fallback)
  local found = Bricks.value("palette." .. key)

  if type(found) ~= "number" then
    return fallback
  end

  local r, g, b = Palette.unpackColor(floor(tonumber(found) or 0))

  return { r, g, b, fallback[4] }
end

local function solid()
  return Bricks.media("solid") or SOLID
end

local function localized(owner, key)
  local texts = EbonAPI.Locale.get(owner)

  return texts and texts[key] or key
end

local function valueOf(box, value)
  if type(value) == "function" then
    return value(box)
  end

  return value
end

local function paintBorder(box, tint)
  box:SetBackdropBorderColor(tint[1], tint[2], tint[3], tint[4])
end

local function paintBox(box)
  local fill = color("bg", FILL)

  box:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
  paintBorder(box, box.focused and color("text", WHITE) or color("title", GOLD))
end

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Bricks, "apply", function()
    for box in pairs(instances) do
      paintBox(box)
    end
  end)
end

local function newCodeBox(owner, parent, spec)
  local box = CreateFrame("Frame", nil, parent)

  box.owner, box.spec = owner, spec
  box.readOnly = spec.readOnly and true or false
  box.kitText = ""

  box:SetWidth(spec.width or 600)
  box:SetHeight(spec.height or 250)
  box:SetBackdrop({ bgFile = solid(), edgeFile = solid(), edgeSize = 1 })
  box.focused = false
  instances[box] = true
  paintBox(box)
  box:EnableMouse(true)

  local showCopy = box.readOnly or spec.copyHint and true or false
  local footer = showCopy and FOOTER or 0

  local scroll = CreateFrame("ScrollFrame", nil, box)
  scroll:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -PAD)
  scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -PAD, PAD + footer)
  scroll:EnableMouse(true)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  Bricks.font(edit, "normal")
  Bricks.paint(edit, "SetTextColor", "text")
  edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  edit:SetWidth(max(1, scroll:GetWidth()))
  edit:SetHeight(max(1, scroll:GetHeight()))
  scroll:SetScrollChild(edit)

  local measure = box:CreateFontString(nil, "ARTWORK")
  Bricks.font(measure, "normal")
  measure:SetJustifyH("LEFT")
  measure:Hide()

  local hint = Bricks.text(box, "small", "muted")
  hint:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  hint:SetJustifyH("LEFT")

  local copy = Bricks.text(box, "small", "muted")
  copy:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", PAD, 3)
  copy:SetJustifyH("LEFT")

  if showCopy then
    local label = type(spec.copyHint) == "string" and spec.copyHint or localized(owner, "Ctrl+C to copy")
    copy:SetText(label)
    copy:Show()
  else
    copy:Hide()
  end

  local function fit()
    local text = box.kitText or ""
    local width = max(1, scroll:GetWidth())

    measure:SetWidth(width)
    measure:SetText(text)

    if text == "" then
      hint:Show()
    else
      hint:Hide()
    end

    edit:SetWidth(width)
    edit:SetHeight(max(scroll:GetHeight(), measure:GetStringHeight() + PAD))
  end

  local function selectAll()
    edit:SetFocus()
    edit:HighlightText(0, edit:GetNumLetters())
  end

  box.restoring = false

  edit:SetScript("OnTextChanged", function(self, userInput)
    if box.restoring then
      return
    end

    if box.readOnly then
      if userInput then
        box.restoring = true
        self:SetText(box.kitText)
        box.restoring = false
        self:HighlightText(0, self:GetNumLetters())
      end

      return
    end

    box.kitText = self:GetText() or ""
    fit()

    if userInput and spec.onChange then
      spec.onChange(box.kitText)
    end
  end)

  edit:SetScript("OnEditFocusGained", function(self)
    box.focused = true
    paintBox(box)
    self:HighlightText(0, self:GetNumLetters())
  end)

  edit:SetScript("OnEditFocusLost", function(self)
    box.focused = false
    paintBox(box)
    self:HighlightText(0, 0)
  end)

  edit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  scroll:SetScript("OnMouseUp", selectAll)
  scroll:SetScript("OnSizeChanged", fit)

  function box:SetText(text)
    self.kitText = text ~= nil and tostring(text) or ""
    self.restoring = true
    edit:SetText(self.kitText)
    self.restoring = false
    fit()
  end

  function box:GetText()
    return self.kitText
  end

  function box:SelectAll()
    selectAll()
  end

  function box:kitRefresh()
    if not self.kitDone or type(self.spec.text) == "function" then
      local text = valueOf(self, self.spec.text)

      self:SetText(text ~= nil and tostring(text) or self.kitText)
    end

    self.kitDone = true

    local shown = valueOf(self, self.spec.hint)

    hint:SetText(shown ~= nil and localized(self.owner, tostring(shown)) or "")
    fit()
  end

  return box
end

Kit.addKind("codeBox", newCodeBox)
