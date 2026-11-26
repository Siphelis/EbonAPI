local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local Localized = RT.Localized
local state = RT.state

local ADDON_TITLE = RT.ADDON_TITLE
local GEAR_TEXTURE = "Interface\\WorldMap\\Gear_64Grey"

local controlFrame
local button
local minimapButton

local PositionMinimapButton
local UpdateStartButtons

local Log = RT.Log

local function SetButtonEnabled(target, enabled)
  if not target then
    return
  end

  enabled = enabled and true or false
  target:SetDisabledState(not enabled)

  if not (target.secure and InCombatLockdown()) then
    if enabled then
      target:Enable()
    else
      target:Disable()
    end
  end

  Skin.RefreshButtonIcon(target)
end

RT.SetButtonEnabled = SetButtonEnabled

function RT.RefreshUpdateNotice()
  if not controlFrame or not controlFrame.updateButton then
    return false
  end

  RT.LayoutMainToolbar()

  return controlFrame.updateButton:IsShown() and true or false
end

function RT.SyncOverlayFrameLevels()
  local referenceFrame = RT.GetBoardWindow()
  local referenceLevel = 20

  if referenceFrame and referenceFrame.GetFrameLevel then
    referenceLevel = referenceFrame:GetFrameLevel() or referenceLevel
  end

  if referenceLevel == RT.lastOverlayReferenceLevel then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  RT.lastOverlayReferenceLevel = referenceLevel

  if controlFrame then
    if controlFrame.SetFrameStrata then
      controlFrame:SetFrameStrata("HIGH")
    end
    if controlFrame.SetFrameLevel then
      controlFrame:SetFrameLevel(referenceLevel + 20)
    end
  end
end

local function RefreshStartButtonMacroState(target)
  if not target or not target._acbStartToggle or not target.SetAttribute then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  RT.ApplySecureMacroButtonAttributes(target, "", "start")
end

local function UpdateStartButtonState(target, canStart)
  if not target then
    return
  end

  if RT.IsStarted() then
    Skin.SetButtonSelected(target, true)
    target:SetText(L.BUTTON_STOP)
    SetButtonEnabled(target, true)
    RefreshStartButtonMacroState(target)
    return
  end

  Skin.SetButtonSelected(target, false)
  target:SetText(L.BUTTON_START)
  SetButtonEnabled(target, canStart)
  RefreshStartButtonMacroState(target)
end

RT.UpdateStartButtonState = UpdateStartButtonState

UpdateStartButtons = function()
  local available = RT.IsBoardAvailable()

  if controlFrame and controlFrame.startButton then
    UpdateStartButtonState(controlFrame.startButton, available)
  end

  UpdateStartButtonState(RT.boardStartButton, available)
end

RT.UpdateStartButtons = UpdateStartButtons

function RT.ApplySecureMacroButtonAttributes(target, macroText, label)
  if not target then
    return
  end

  macroText = macroText or ""

  if InCombatLockdown and InCombatLockdown() then
    Log("summon", "deferred secure ", label, " update in combat")
    return
  end

  if target._acbSecureType == "macro" and target._acbSecureMacroText == macroText then
    return
  end

  target:SetAttribute("type", "macro")
  target:SetAttribute("macrotext", macroText)
  target._acbSecureType = "macro"
  target._acbSecureMacroText = macroText
  Log("summon", "secure ", label, " macro set to ", macroText)
end

function RT.ConfigureStartButton(target)
  if not target then
    return
  end

  target._acbStartToggle = true
  RT.ApplySecureMacroButtonAttributes(target, "", "start")
  target:SetScript("PostClick", function()
    if RT.IsStarted() then
      RT.Stop()
    else
      RT.Start()
    end
    end)
end

function RT.SetControlFrameSize(width, height)
  if not controlFrame then
    return
  end

  local centerX = controlFrame:GetCenter()
  local top = controlFrame:GetTop()

  Skin.SizeWindow(controlFrame, width, height)

  if centerX and top then
    controlFrame:ClearAllPoints()
    controlFrame:SetPoint("TOP", UIParent, "BOTTOMLEFT", centerX, top)
  end
end

local function SavedButtonPoint()
  local saved = state.button

  if type(saved) ~= "table" or not saved.point then
    return nil
  end

  return { saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0 }
end

PositionMinimapButton = function()
  if minimapButton then
    minimapButton:Refresh()
  end
end

function RT.SetMinimapShown(shown)
  if not state then
    return
  end

  state.minimap.shown = shown and true or false
  PositionMinimapButton()
  RT.RefreshOptions()
end

local function MinimapTip(lines)
  lines:Add(L.MINIMAP_TOOLTIP_LEFT_CLICK, "text")
  lines:Add(L.MINIMAP_TOOLTIP_RIGHT_CLICK, "text")
  lines:Add(L.MINIMAP_TOOLTIP_DRAG, "muted")
end

local function CreateMinimapButton()
  if minimapButton then
    PositionMinimapButton()
    return
  end

  minimapButton = Skin.Named(RT.api:MinimapButton({
    text = function() return L.ADDON_NAME_TOOLTIP end,
    tip = MinimapTip,
    hidden = function() return not state.minimap.shown end,
    angle = state.minimap.angle,
    onClick = function(_, mouseButton)
      if mouseButton == "RightButton" then
        RT.ShowSettings()
        return
      end

      if controlFrame and controlFrame:IsShown() then
        controlFrame:Hide()
      elseif controlFrame then
        RT.SaveControlFrameShown(true)
        controlFrame:Show()
      end
    end,
  }), "AutoCallboardMinimapButton")
end

local function StartMovingButton(self)
  if IsShiftKeyDown() and not InCombatLockdown() and not RT.IsInterfaceLocked() then
    controlFrame:StartMoving()
  end
end

local function StopMovingButton(self)
  local stop = controlFrame:GetScript("OnDragStop")

  if stop then
    stop(controlFrame)
  end
end

local function MakeActionButton(name, text, point, relativeTo, relativePoint, x, y, onClick, secure, tipKey)
  local actionButton = Skin.MakeButton(controlFrame.content, {
    name = name,
    secure = secure,
    text = text,
    tipKey = tipKey,
    point = { point, relativeTo, relativePoint, x, y },
    onClick = onClick,
  })
  actionButton:RegisterForDrag("LeftButton")
  actionButton:SetScript("OnDragStart", StartMovingButton)
  actionButton:SetScript("OnDragStop", StopMovingButton)

  return actionButton
end

local function CreateControlFrame()
  controlFrame = Skin.Window("AutoCallboardFrame", {
    title = ADDON_TITLE,
    noEsc = true,
    movable = true,
    point = SavedButtonPoint(),
    width = RT.controlCollapsedWidth,
    height = RT.controlCollapsedHeight,
    buttons = {
      { text = "?", onClick = function() RT.ShowAddonHelp("about") end, tipTitle = "UI_HELP" },
      { icon = GEAR_TEXTURE, onClick = function() RT.ShowSettings() end, tipTitle = "UI_SETTINGS" },
    },
  })
  RT.controlFrame = controlFrame
  controlFrame.helpButton = controlFrame.headButtons[1]
  controlFrame.settingsButton = controlFrame.headButtons[2]
  RT.SyncOverlayFrameLevels()
  controlFrame:HookScript("OnShow", function()
    RT.SaveControlFrameShown(true)
    RT.SyncOverlayFrameLevels()
    end)
  controlFrame:HookScript("OnHide", function()
    RT.SaveControlFrameShown(false)

    if RT.HideDebugWindow then
      RT.HideDebugWindow()
    end
    end)
end

local function CreateUpdateButton()
  controlFrame.updateButton = Skin.MakeButton(controlFrame.content, {
    name = "AutoCallboardUpdateButton",
    textKey = "UPDATE_BUTTON",
    onClick = function() RT.OpenUpdatePage() end,
    tip = function()
      local version, installed = RT.GetAvailableUpdate()
      local tip = RT.LinkTip()

      if version then
        GameTooltip:AddLine(string.format(L.UPDATE_VERSIONS, version, installed), 1, 1, 1)
      end

      if tip then
        GameTooltip:AddLine(tip, 1, 1, 1, true)
      end
    end,
  })
  controlFrame.updateButton:Hide()
end

local function CreateHeaderButtons()
  controlFrame.closeButton.onClick = function()
    controlFrame:Hide()
  end
end

local function CreateCallboardLabelButton(anchor)
  button = Skin.MakeButton(controlFrame.content, {
    name = "AutoCallboardButton",
    text = state.targetName,
    point = { "LEFT", anchor, "RIGHT", 5, 0 },
    onClick = function() RT.ToggleBoardWindow() end,
  })
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnDragStart", StartMovingButton)
  button:SetScript("OnDragStop", StopMovingButton)
  Skin.HoverTip(button, "ADDON_NAME_TOOLTIP", nil, function()
    GameTooltip:AddLine(L.CALLBOARD_BUTTON_WINDOW_HINT, 1, 1, 1, true)
    GameTooltip:AddLine(L.CALLBOARD_BUTTON_DRAG_HINT, 0.8, 0.8, 0.8)
    end)
end

local function CreateToolbar()
  local content = controlFrame.content
  local buildsButton = Skin.MakeButton(content, {
    name = "AutoCallboardBuildsButton",
    textKey = "BUTTON_BUILDS",
    points = { { "TOPLEFT", content, "TOPLEFT", 0, 0 } },
    onClick = function() RT.ToggleBuildsWindow() end,
    tipKey = "BUILDS_BUTTON_TOOLTIP",
    tip = function()
      local activeBuild = EbonAPI.State.activeBuild()
      if activeBuild then
        GameTooltip:AddLine(string.format(L.BUILDS_BUTTON_ACTIVE, RT.BuildLabel(activeBuild)), 1, 1, 1)
      end
      end,
  })
  controlFrame.buildsButton = buildsButton

  CreateCallboardLabelButton(buildsButton)

  local mainStartButton = MakeActionButton("AutoCallboardStartButton", L.BUTTON_START, "LEFT", button, "RIGHT", 5, 0, nil, true)
  controlFrame.startButton = mainStartButton
  RT.ConfigureStartButton(mainStartButton)
  UpdateStartButtonState(mainStartButton, RT.IsBoardAvailable())
end

local function CreateCallboardButton()
  CreateControlFrame()
  CreateHeaderButtons()
  CreateUpdateButton()
  CreateToolbar()

  if state.buttonShown then
    controlFrame:Show()
  else
    controlFrame:Hide()
  end
end

RT.CreateCallboardButton = CreateCallboardButton
RT.CreateMinimapButton = CreateMinimapButton

RT.PositionMinimapButton = function(...)
  return PositionMinimapButton(...)
end

RT.SetCallboardButtonText = function(text)
  if button then
    button:SetText(text)
  end
end
