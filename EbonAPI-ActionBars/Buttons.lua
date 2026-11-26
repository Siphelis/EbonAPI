local _, ns = ...

local Buttons = {}
ns.Buttons = Buttons

local PREFIX = "EbonAPIActionBars_"
local COUNT = 12
local RANGE_INTERVAL = 0.2
local ATTRIBUTES = { "type", "spell", "item", "macrotext", "pet" }

local registry = {}
local bars = {}

local TINTS = {
  usable = HIGHLIGHT_FONT_COLOR,
  unusable = GRAY_FONT_COLOR,
  noMana = GRAY_FONT_COLOR,
  rangeOut = RED_FONT_COLOR,
}

local templateSize

local function ButtonSize()
  local reference = _G.ActionButton1
  local width = reference and reference:GetWidth()

  if width and width > 0 then
    return width
  end

  return templateSize
end

local function Dress(button)
  local dragon = _G.DragonUI

  if type(dragon) ~= "table" or dragon.playerOff or type(dragon.SkinIconButton) ~= "function" then
    return
  end

  if type(dragon.IsModuleEnabled) == "function" and not dragon:IsModuleEnabled("buttons") then
    return
  end

  dragon.SkinIconButton(button, button.icon)
end

local function Tint(button, state)
  local color = TINTS[state]

  button.icon:SetVertexColor(color.r, color.g, color.b)

  if state == "rangeOut" then
    button.keybind:SetTextColor(color.r, color.g, color.b)
  else
    button.keybind:SetTextColor(unpack(button.keybindColor))
  end
end

function Buttons.FrameName(barId, index)
  if index == nil then
    return PREFIX .. tostring(barId)
  end
  return PREFIX .. tostring(barId) .. "_" .. tostring(index)
end

local function FindSpellBookIndex(name)
  local found
  local i = 1
  while true do
    local spellName = GetSpellName(i, "spell")
    if not spellName then
      break
    end
    if spellName == name then
      found = i
    end
    i = i + 1
  end
  return found
end

local function FindCompanionIndex(kind, spellId)
  for i = 1, GetNumCompanions(kind) do
    local _, _, id = GetCompanionInfo(kind, i)
    if id == spellId then
      return i
    end
  end
end

local function Pickup(content)
  if not content then
    return
  end
  local kind = content.type
  if kind == "spell" then
    local index = FindSpellBookIndex(content.name)
    if index then
      PickupSpell(index, "spell")
    end
  elseif kind == "item" then
    PickupItem(content.id)
  elseif kind == "macro" then
    PickupMacro(content.name)
  elseif kind == "companion" then
    local index = FindCompanionIndex(content.kind, content.id)
    if index then
      PickupCompanion(content.kind, index)
    end
  end
end

local function ReadCursor()
  local kind, a, b = GetCursorInfo()
  if kind == "spell" then
    local name = GetSpellName(a, b)
    if not name then
      return nil
    end
    local link = GetSpellLink(a, b)
    local id = link and tonumber(link:match("spell:(%d+)"))
    return { type = "spell", name = name, id = id }
  elseif kind == "item" then
    local name = GetItemInfo(a)
    return { type = "item", id = a, name = name }
  elseif kind == "macro" then
    local name, icon, body = GetMacroInfo(a)
    if not name then
      return nil
    end
    return { type = "macro", name = name, body = body, icon = icon }
  elseif kind == "companion" then
    local _, name, spellId, icon = GetCompanionInfo(b, a)
    if not name then
      return nil
    end
    return { type = "companion", kind = b, id = spellId, name = name, icon = icon }
  end
end

local function Resolve(content)
  if not content then
    return nil
  end
  local kind = content.type
  if kind == "spell" then
    return "spell", content.name, GetSpellTexture(content.name)
  elseif kind == "item" then
    return "item", content.id, GetItemIcon(content.id)
  elseif kind == "companion" then
    local name = GetSpellInfo(content.id) or content.name
    return "spell", name, content.icon or GetSpellTexture(name)
  elseif kind == "macro" then
    local spell = GetMacroSpell(content.name)
    if spell then
      return "spell", spell, GetSpellTexture(spell) or content.icon
    end
    local item = GetMacroItem(content.name)
    if item then
      return "item", item, content.icon
    end
    return nil, nil, content.icon
  end
end

local RefreshButton
local Evaluate

local active = {}
local activeCount = 0

local function RebuildActive()
  for index = 1, activeCount do
    active[index] = nil
  end
  activeCount = 0
  for index = 1, #registry do
    local button = registry[index]
    if button.refKind then
      local bar = bars[button.barId]
      if bar and bar:IsShown() then
        activeCount = activeCount + 1
        active[activeCount] = button
      end
    end
  end
end

local dragGrid = 0

local function ShowAllSlots()
  if GetCVar("alwaysShowActionBars") == "1" or ALWAYS_SHOW_MULTIBARS == "1" or ALWAYS_SHOW_MULTIBARS == 1 then
    return true
  end
  if SpellBookFrame and SpellBookFrame:IsShown() then
    return true
  end
  if dragGrid > 0 then
    return true
  end
  local dragon = _G.DragonUI
  return type(dragon) == "table" and dragon.EditorMode ~= nil and dragon.EditorMode:IsActive() == true
end

local function UpdateGrid(barId)
  local frame, data = bars[barId], ns.Bars.Find(barId)
  if not frame or not data then
    return
  end
  local all = ShowAllSlots()
  local included = {}
  for position = 1, data.shown do
    included[data.order[position]] = true
  end
  for index, button in ipairs(frame.buttons) do
    if included[index] and (all or button.content) then
      button:Show()
    else
      button:Hide()
    end
  end
end

local function UpdateAllGrids()
  for barId in pairs(bars) do
    UpdateGrid(barId)
  end
end

function Buttons.RefreshGrid()
  ns.Bars.Queue(UpdateAllGrids)
end

local function ApplyNow(button, content)
  if content ~= nil and not ns.Bars.IsValidType(content.type) then
    return
  end
  for _, attribute in ipairs(ATTRIBUTES) do
    button:SetAttribute(attribute, nil)
  end
  if content then
    local kind = content.type
    if kind == "spell" or kind == "companion" then
      button:SetAttribute("type", "spell")
      button:SetAttribute("spell", kind == "spell" and content.name or GetSpellInfo(content.id) or content.name)
    elseif kind == "item" then
      button:SetAttribute("type", "item")
      button:SetAttribute("item", "item:" .. tostring(content.id))
    elseif kind == "macro" then
      button:SetAttribute("type", "macro")
      button:SetAttribute("macrotext", content.body)
    end
  end
  button.content = content
  local hadContent = button.refKind ~= nil
  RefreshButton(button)
  if hadContent ~= (button.refKind ~= nil) then
    RebuildActive()
  end
  UpdateGrid(button.barId)
  Evaluate()
end

function Buttons.Apply(button, content)
  ns.Bars.Queue(ApplyNow, button, content)
end

local function UpdateState(button, out)
  local icon = button.icon
  if not button.content or not button.icon:IsShown() then
    return
  end
  local usable, noMana = true, false
  if button.refKind == "spell" then
    usable, noMana = IsUsableSpell(button.ref)
  elseif button.refKind == "item" then
    usable = IsUsableItem(button.ref) and GetItemCount(button.ref) > 0
  end
  local state, desaturated = "usable", false
  if out then
    state = "rangeOut"
  elseif noMana then
    state = "noMana"
  elseif not usable then
    state, desaturated = "unusable", true
  end
  Tint(button, state)
  icon:SetDesaturated(desaturated)
  button.out = out
end

local function RangeOut(button)
  local result
  if button.refKind == "spell" then
    result = IsSpellInRange(button.ref, "target")
  elseif button.refKind == "item" then
    result = IsItemInRange(button.ref, "target")
  end
  return result == 0
end

local function RefreshCooldown(button)
  local kind, ref = button.refKind, button.ref
  local start, duration, enable = 0, 0, 0
  if kind == "spell" then
    start, duration, enable = GetSpellCooldown(ref)
  elseif kind == "item" then
    start, duration, enable = GetItemCooldown(ref)
  end
  CooldownFrame_SetTimer(button.cooldown, start or 0, duration or 0, enable or 0)
end

local function RefreshCount(button)
  if button.refKind == "item" then
    button.count:SetText(GetItemCount(button.ref, nil, true))
  else
    button.count:SetText("")
  end
end

RefreshButton = function(button)
  local content = button.content
  local kind, ref, texture = Resolve(content)
  button.refKind, button.ref = kind, ref
  if not content then
    button.icon:Hide()
    button.count:SetText("")
    CooldownFrame_SetTimer(button.cooldown, 0, 0, 0)
    Tint(button, "usable")
    return
  end
  button.icon:SetTexture(texture)
  button.icon:Show()
  RefreshCooldown(button)
  RefreshCount(button)
  UpdateState(button, RangeOut(button))
end

local function Tooltip(button)
  local content = button.content
  if not content then
    return
  end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  local kind = content.type
  if kind == "spell" then
    local index = FindSpellBookIndex(content.name)
    if index then
      GameTooltip:SetSpell(index, "spell")
    end
  elseif kind == "item" then
    GameTooltip:SetHyperlink("item:" .. tostring(content.id))
  elseif kind == "companion" then
    GameTooltip:SetHyperlink("spell:" .. tostring(content.id))
  elseif kind == "macro" then
    GameTooltip:SetText(content.name)
  end
  GameTooltip:Show()
end

local function SetContent(button, content)
  ns.Bars.SetSlot(button.barId, button.index, content)
  ApplyNow(button, content)
end

local function RefuseInCombat()
  if EbonAPI.Lib.errorsShown() then
    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1, 1.0)
  end
end

local function Drop(button)
  if InCombatLockdown() then
    RefuseInCombat()
    return false
  end
  local incoming = ReadCursor()
  if not incoming then
    return false
  end
  local previous = button.content
  ClearCursor()
  Pickup(previous)
  SetContent(button, incoming)
  return true
end

local function Remove(button)
  local previous = button.content
  if not previous then
    return
  end
  if InCombatLockdown() then
    RefuseInCombat()
    return
  end
  Pickup(previous)
  SetContent(button, nil)
end

local function CreateButton(parent, barId, index)
  local name = Buttons.FrameName(barId, index)
  local button = CreateFrame("CheckButton", name, parent, "ActionButtonTemplate, SecureActionButtonTemplate")
  button.barId, button.index = barId, index
  templateSize = templateSize or button:GetWidth()
  button:RegisterForClicks("AnyUp")
  button:RegisterForDrag("LeftButton")

  button.icon = _G[name .. "Icon"]
  button.icon:Hide()
  button.cooldown = _G[name .. "Cooldown"]
  button.count = _G[name .. "Count"]
  button.keybind = _G[name .. "HotKey"]
  button.keybindColor = { button.keybind:GetTextColor() }

  Dress(button)

  button:SetScript("OnDragStart", Remove)
  button:SetScript("OnReceiveDrag", Drop)
  button:SetScript("OnEnter", Tooltip)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  registry[#registry + 1] = button
  return button
end

local function BarShown(bar)
  RebuildActive()
  for index = 1, #bar.buttons do
    local button = bar.buttons[index]
    if button.refKind then
      RefreshButton(button)
    end
  end
  Evaluate()
end

local function BarHidden()
  RebuildActive()
  Evaluate()
end

function Buttons.Build(barId, parent)
  if bars[barId] then
    return bars[barId]
  end
  if InCombatLockdown() then
    return nil
  end
  local bar = CreateFrame("Frame", Buttons.FrameName(barId), parent or UIParent)
  bar.buttons = {}
  for index = 1, COUNT do
    local button = CreateButton(bar, barId, index)
    bar.buttons[index] = button
    ApplyNow(button, ns.Bars.GetSlot(barId, index))
  end
  bar:SetScript("OnShow", BarShown)
  bar:SetScript("OnHide", BarHidden)
  bars[barId] = bar
  RebuildActive()
  Evaluate()
  Buttons.Refresh(barId)
  return bar
end

local function KeybindText(button)
  local key = GetBindingKey("CLICK " .. button:GetName() .. ":LeftButton")
  if not key then
    return ""
  end
  return GetBindingText(key, "KEY_", true)
end

local function ApplyLayout(barId)
  local frame, data = bars[barId], ns.Bars.Find(barId)
  if not frame or not data then
    return
  end
  local size = ButtonSize()
  local columns = math.min(data.columns, data.shown)
  local rows = math.ceil(data.shown / data.columns)
  frame:SetScale(data.scale)
  frame:SetSize(columns * size + (columns - 1) * data.spacing, rows * size + (rows - 1) * data.spacing)
  for _, button in ipairs(frame.buttons) do
    button:ClearAllPoints()
    button:Hide()
  end
  for position = 1, data.shown do
    local button = frame.buttons[data.order[position]]
    local column = (position - 1) % data.columns
    local row = math.floor((position - 1) / data.columns)
    button:SetSize(size, size)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", column * (size + data.spacing), -row * (size + data.spacing))
    button.keybind:SetText(data.showKeybind and KeybindText(button) or "")
  end
  UpdateGrid(barId)
  if data.visible and not data.hidden then
    frame:Show()
  else
    frame:Hide()
  end
end

function Buttons.Refresh(barId)
  if not bars[barId] then
    return
  end
  ns.Bars.Queue(ApplyLayout, barId)
end

local events = CreateFrame("Frame")
local passFrame = CreateFrame("Frame")
local PART_COOLDOWN, PART_USABLE, PART_COUNT, PART_ALL = 1, 2, 3, 4
local EVENT_PARTS = {
  SPELL_UPDATE_COOLDOWN = PART_COOLDOWN,
  ACTIONBAR_UPDATE_COOLDOWN = PART_COOLDOWN,
  BAG_UPDATE_COOLDOWN = PART_COOLDOWN,
  SPELL_UPDATE_USABLE = PART_USABLE,
  ACTIONBAR_UPDATE_USABLE = PART_USABLE,
  BAG_UPDATE = PART_COUNT,
  UPDATE_MACROS = PART_ALL,
  SPELLS_CHANGED = PART_ALL,
  COMPANION_UPDATE = PART_ALL,
  PLAYER_ENTERING_WORLD = PART_ALL,
}
local pendingCooldown, pendingUsable, pendingCount, pendingAll = false, false, false, false
local passArmed = false

local function RunPass()
  passFrame:SetScript("OnUpdate", nil)
  passArmed = false
  local all, cooldown, usable, count = pendingAll, pendingCooldown, pendingUsable, pendingCount
  pendingAll, pendingCooldown, pendingUsable, pendingCount = false, false, false, false
  if all then
    for index = 1, activeCount do
      RefreshButton(active[index])
    end
    Evaluate()
    return
  end
  for index = 1, activeCount do
    local button = active[index]
    local countNow = count and button.refKind == "item"
    if cooldown then
      RefreshCooldown(button)
    end
    if countNow then
      RefreshCount(button)
    end
    if usable or countNow then
      UpdateState(button, button.out)
    end
  end
end

local function NotePart(part)
  if part == PART_ALL then
    pendingAll = true
  elseif part == PART_COOLDOWN then
    pendingCooldown = true
  elseif part == PART_USABLE then
    pendingUsable = true
  else
    pendingCount = true
  end
  if not passArmed then
    passArmed = true
    passFrame:SetScript("OnUpdate", RunPass)
  end
end
for _, name in ipairs({
  "SPELL_UPDATE_COOLDOWN",
  "SPELL_UPDATE_USABLE",
  "BAG_UPDATE",
  "BAG_UPDATE_COOLDOWN",
  "ACTIONBAR_UPDATE_USABLE",
  "ACTIONBAR_UPDATE_COOLDOWN",
  "UPDATE_MACROS",
  "SPELLS_CHANGED",
  "COMPANION_UPDATE",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_TARGET_CHANGED",
  "ACTIONBAR_SHOWGRID",
  "ACTIONBAR_HIDEGRID",
}) do
  events:RegisterEvent(name)
end

local function RangeScan()
  for index = 1, activeCount do
    local button = active[index]
    local out = RangeOut(button)
    if out ~= button.out then
      UpdateState(button, out)
    end
  end
end

local elapsedTotal = 0
local function RangeUpdate(_, elapsed)
  elapsedTotal = elapsedTotal + elapsed
  if elapsedTotal < RANGE_INTERVAL then
    return
  end
  elapsedTotal = 0
  RangeScan()
end

local function AnyBarWithContent()
  for _, bar in pairs(bars) do
    if bar:IsShown() then
      for _, button in ipairs(bar.buttons) do
        if button.refKind then
          return true
        end
      end
    end
  end
  return false
end

local ranging = false

Evaluate = function(targetChanged)
  local wanted = UnitExists("target") and AnyBarWithContent() or false
  if wanted == ranging then
    if wanted and targetChanged == true then
      elapsedTotal = 0
      RangeScan()
    end
    return
  end
  ranging = wanted
  elapsedTotal = 0
  if wanted then
    events:SetScript("OnUpdate", RangeUpdate)
    RangeScan()
  else
    events:SetScript("OnUpdate", nil)
    for index = 1, activeCount do
      local button = active[index]
      if button.out then
        UpdateState(button, false)
      end
    end
  end
end

events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_TARGET_CHANGED" then
    Evaluate(true)
  elseif event == "ACTIONBAR_SHOWGRID" then
    dragGrid = dragGrid + 1
    Buttons.RefreshGrid()
  elseif event == "ACTIONBAR_HIDEGRID" then
    dragGrid = math.max(dragGrid - 1, 0)
    Buttons.RefreshGrid()
  else
    local part = EVENT_PARTS[event]
    if part then
      NotePart(part)
    end
  end
end)

for _, name in ipairs({ "MultiActionBar_ShowAllGrids", "MultiActionBar_HideAllGrids" }) do
  if type(_G[name]) == "function" then
    hooksecurefunc(name, Buttons.RefreshGrid)
  end
end

hooksecurefunc("SetCVar", function(name)
  if name == "alwaysShowActionBars" then
    Buttons.RefreshGrid()
  end
end)
