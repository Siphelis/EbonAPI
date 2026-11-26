local _, ns = ...

local Editor = {}
ns.Editor = Editor

local FADED_ALPHA = 0.4
local STAGGER_START = 120

local movers = {}
local addButton
local addCounter
local section
local sectionGeometry
local reported = false
local hooked = false
local inSet = false
local present = {}
local T = ns.L

local function pe()
  local addon = _G.DragonUI

  if type(addon) ~= "table" or not addon.EditorMode or not addon.EditorSettings or not addon.RegisterEditableFrame then
    return nil
  end

  return addon
end

local findBar = ns.Bars.Find

local function refreshBar(id)
  local frame = ns.Buttons.Build(id)

  if not frame then
    return
  end

  ns.Buttons.Refresh(id)

  local mover = movers[id]

  if mover then
    mover:SetSize(frame:GetWidth() * frame:GetScale(), frame:GetHeight() * frame:GetScale())
  end
end

local function fade(id)
  local mover = movers[id]
  local bar = findBar(id)

  if mover and bar then
    mover:SetAlpha((bar.hidden or bar.visible == false) and FADED_ALPHA or 1)
  end
end

local function setLayout(id, key, value)
  ns.Bars.SetLayout(id, { [key] = value })
  refreshBar(id)
  fade(id)
end

local function isReversed(bar)
  return bar.order and bar.order[1] == ns.Bars.SLOT_COUNT
end

local function setting(kind, id, key, labelKey, fields)
  fields.type = kind
  fields.key = ns.Buttons.FrameName(id) .. "." .. key
  fields.label = function() return T(labelKey) end

  return fields
end

local function slider(id, key, labelKey, min, max, step, format)
  return setting("slider", id, key, labelKey, {
    min = min,
    max = max,
    step = step,
    format = format,
    get = function()
      local bar = findBar(id)
      return bar and bar[key] or min
    end,
    set = function(value)
      local snapped = math.floor(value / step + 0.5) * step
      setLayout(id, key, math.min(max, math.max(min, snapped)))
    end,
  })
end

local function check(id, key, labelKey)
  return setting("checkbox", id, key, labelKey, {
    get = function()
      local bar = findBar(id)
      return bar and bar[key] and true or false
    end,
    set = function(value)
      setLayout(id, key, value and true or false)
      if key == "visible" and value then
        ns.Bars.Show(id)
      end
    end,
  })
end

local function widgetsOf(addon)
  local profile = addon.db and addon.db.profile

  return profile and profile.widgets
end

local function unregister(addon, id)
  local name = ns.Buttons.FrameName(id)
  local mover = movers[id]
  local widgets = widgetsOf(addon)

  movers[id] = nil

  if widgets then
    widgets[name] = nil
  end
  addon.EditableFrames[name] = nil
  addon.EditorSettings.frames[name] = nil

  if mover then
    if addon.selectedEditorFrame == mover and addon.DeselectEditorFrame then
      addon.DeselectEditorFrame()
    end

    addon.ShowUIFrame(mover)
    mover:Hide()
  end
end

local function removeRow(id)
  return setting("button", id, "remove", "Remove bar", {
    onClick = function()
      ns.Bars.Remove(id)
      Editor.Sync()
    end,
  })
end

local function defaultPoint(mover, position)
  mover:ClearAllPoints()
  mover:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, STAGGER_START + (position - 1) * mover:GetHeight())
end

local function placeMover(addon, id, mover, position)
  local widgets = widgetsOf(addon)
  local saved = widgets and widgets[ns.Buttons.FrameName(id)]

  if type(saved) == "table" and (saved.anchor or saved.posX or saved.posY) then
    local point = saved.anchor or "CENTER"

    mover:ClearAllPoints()
    mover:SetPoint(point, UIParent, point, saved.posX or 0, saved.posY or 0)
  else
    defaultPoint(mover, position)
  end
end

local function placeAll()
  local addon = pe()

  if not addon then
    return
  end

  for id, mover in pairs(movers) do
    local _, position = findBar(id)

    if position then
      placeMover(addon, id, mover, position)
    end
  end
end

local function register(addon, id)
  local bar, position = findBar(id)
  local frame = ns.Buttons.Build(id)

  if not bar or not frame then
    return
  end

  local name = ns.Buttons.FrameName(id)

  if type(addon.L) == "table" then
    rawset(addon.L, name, string.format(T("Action bar %d"), id))
  end

  local mover = addon.CreateUIFrame(frame:GetWidth() * frame:GetScale(), frame:GetHeight() * frame:GetScale(), name)

  movers[id] = mover
  placeMover(addon, id, mover, position)

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", mover, "CENTER", 0, 0)

  addon:RegisterEditableFrame({
    name = name,
    frame = mover,
    configPath = { "widgets", name },
    editorVisible = function() return findBar(id) ~= nil end,
    hasTarget = function() return findBar(id) ~= nil end,
    resetPosition = function()
      local _, current = findBar(id)
      local widgets = widgetsOf(addon)

      if widgets then
        widgets[name] = nil
      end

      defaultPoint(mover, current or position)
    end,
    module = Editor,
  })

  local reversedItems = {
    { value = "normal", text = T("Normal order") },
    { value = "reversed", text = T("Reversed order") },
  }

  addon.EditorSettings.Register(name, {
    title = function() return string.format(T("Action bar %d"), id) end,
    settings = {
      slider(id, "scale", "Scale", 0.5, 2.0, 0.01, "%.2f"),
      slider(id, "spacing", "Spacing", 0, 20, 1, "%d"),
      slider(id, "columns", "Columns", 1, 12, 1, "%d"),
      slider(id, "shown", "Shown buttons", 1, 12, 1, "%d"),
      setting("dropdown", id, "order", "Button order", {
        items = reversedItems,
        get = function()
          local current = findBar(id)
          return current and isReversed(current) and "reversed" or "normal"
        end,
        set = function(value)
          setLayout(id, "order", ns.Bars.OrderList(value == "reversed"))
        end,
      }),
      check(id, "showKeybind", "Show keybind text"),
      check(id, "visible", "Visible"),
      removeRow(id),
    },
  })

  fade(id)
end

function Editor.UpdateAddButton()
  if not addButton then
    return
  end

  local count = ns.Bars.Count()

  addCounter:SetText(string.format(T("%d / %d"), count, ns.Bars.MAX_BARS))

  if count >= ns.Bars.MAX_BARS then
    addButton:Disable()
  else
    addButton:Enable()
  end
end

function Editor.Sync()
  local addon = pe()

  if not addon then
    return
  end

  local bars = ns.Bars.GetData().bars
  local changed = false

  wipe(present)

  for position = 1, #bars do
    local id = bars[position].id
    present[id] = true

    if not movers[id] then
      register(addon, id)
      changed = movers[id] ~= nil or changed
    else
      fade(id)
    end
  end

  for id in pairs(movers) do
    if not present[id] then
      unregister(addon, id)
      changed = true
    end
  end

  Editor.UpdateAddButton()

  if changed then
    addon.EditorSettings.SyncFrames()
    addon.EditorSettings.Rebuild()
  end
end

local function reportMissing(what)
  if reported then
    return
  end

  reported = true

  local problems = EbonAPI and EbonAPI.Problems

  if problems and problems.foreign then
    problems.foreign(ns.Bars.OWNER, "Edit Mode panel of ProjectEbonhold: missing " .. what .. ", the action bars section is not created")
  end
end

local function pointOffsets(frame)
  local _, _, _, x, y = frame:GetPoint(1)

  return x or 0, y or 0
end

local function firstFontString(frame)
  local regions = { frame:GetRegions() }

  for index = 1, #regions do
    if regions[index]:GetObjectType() == "FontString" then
      return regions[index]
    end
  end

  return nil
end

local function readGeometry(panel)
  local geometry = {}
  local reference = panel.wholeUI
  local title = reference and reference.new and firstFontString(reference)

  if title then
    geometry.titleX, geometry.titleY = pointOffsets(title)
    geometry.rowY = select(2, pointOffsets(reference.new))
    geometry.checkHeight = reference.new:GetHeight()
    geometry.height = reference:GetHeight()
  else
    geometry.checkHeight = panel.showGrid:GetHeight()
    geometry.titleX = pointOffsets(panel.showGrid)
    geometry.rowY = -geometry.checkHeight
    geometry.titleY = geometry.rowY / 4
    geometry.height = -geometry.rowY + geometry.checkHeight - geometry.titleY
  end

  geometry.leftX, geometry.resetY = pointOffsets(panel.resetAll)
  geometry.resetHeight = panel.resetAll:GetHeight()
  geometry.counterGap = -select(1, pointOffsets(panel.revert))

  return geometry
end

local function placeSection(panel, height)
  if inSet then
    return
  end

  inSet = true

  local bottom = sectionGeometry.resetY + sectionGeometry.resetHeight + sectionGeometry.resetY

  section:ClearAllPoints()
  section:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, bottom)
  section:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, bottom)
  panel:SetHeight(height + sectionGeometry.height + sectionGeometry.resetY)
  inSet = false
end

local function buildSection()
  local panel = _G.EbonholdEditModePanel

  if section then
    return
  end

  if not panel then
    if InCombatLockdown() then
      return
    end

    return reportMissing("EbonholdEditModePanel")
  end

  local required = { "delete", "showGrid", "resetAll", "save", "revert" }

  for index = 1, #required do
    if not panel[required[index]] then
      return reportMissing("panel." .. required[index])
    end
  end

  local labelText = _G[panel.showGrid:GetName() .. "Text"]
  local deleteText = panel.delete:GetFontString()

  if not labelText or not deleteText then
    return reportMissing("button or label text")
  end

  sectionGeometry = readGeometry(panel)

  local geometry = sectionGeometry
  local frame = CreateFrame("Frame", nil, panel)

  section = frame
  frame:SetHeight(geometry.height)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", geometry.titleX, geometry.titleY)
  title:SetText(T("Action bars"))

  local buttonHeight = panel.delete:GetHeight()
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

  button:SetNormalFontObject(panel.delete:GetNormalFontObject())
  button:SetDisabledFontObject(panel.delete:GetDisabledFontObject())
  button:SetHighlightFontObject(panel.delete:GetHighlightFontObject())
  button:SetText(T("Add bar"))

  local margin = panel.delete:GetWidth() - deleteText:GetStringWidth()
  local width = math.max(panel.delete:GetWidth(), button:GetFontString():GetStringWidth() + margin)

  button:SetSize(width, buttonHeight)
  button:SetPoint("TOPLEFT", frame, "TOPLEFT", geometry.leftX, geometry.rowY - (geometry.checkHeight - buttonHeight) / 2)
  button:SetScript("OnClick", function()
    PlaySound("igMainMenuOptionCheckBoxOn")
    ns.Bars.Create()
    Editor.Sync()
  end)

  local counter = frame:CreateFontString(nil, "OVERLAY")

  counter:SetFontObject(labelText:GetFontObject())
  counter:SetPoint("LEFT", button, "RIGHT", geometry.counterGap, 0)

  addButton = button
  addCounter = counter

  frame:SetScript("OnShow", Editor.UpdateAddButton)
  hooksecurefunc(panel, "SetHeight", placeSection)
  placeSection(panel, panel:GetHeight())
  Editor.UpdateAddButton()
end

local function hookEnter()
  local manager = ProjectEbonhold and ProjectEbonhold.EditMode

  if not manager or type(manager.Enter) ~= "function" then
    return reportMissing("ProjectEbonhold.EditMode.Enter")
  end

  hooksecurefunc(manager, "Enter", buildSection)

  if _G.EbonholdEditModePanel then
    buildSection()
  end
end

function Editor.Init()
  local addon = pe()

  if not addon or addButton or hooked then
    return
  end

  hooked = true

  if addon.ModuleRegistry and addon.ModuleRegistry.Register then
    addon.ModuleRegistry:Register(ns.Bars.OWNER, Editor, ns.Bars.OWNER, "", {
      isEnabled = function() return true end,
      lifecycle = { refresh = function() ns.Bars.Queue(placeAll) end },
    })
  end

  for _, name in ipairs({ "ShowMovers", "HideMovers" }) do
    if type(addon.EditorMode[name]) == "function" then
      hooksecurefunc(addon.EditorMode, name, ns.Buttons.RefreshGrid)
    end
  end

  hookEnter()
  Editor.Sync()
end
