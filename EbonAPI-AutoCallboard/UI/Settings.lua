local RT, Core, Skin, L = AutoCallboardRuntime, AutoCallboardCore, AutoCallboardSkin, AutoCallboardLocale
local buttons
local ACTIONS = {
  builds = {"BUTTON_BUILDS", "ToggleBuildsWindow"}, callboard = {"ADDON_NAME_TOOLTIP"}, start = {"BUTTON_START", "Start"},
  eternals = {"UI_ETERNALS", "ShowSettings", 1},
  settings = {"UI_SETTINGS", "ShowSettings"}, instance = {"AUTO_CURRENT_INSTANCE_LABEL", "ToggleInstanceMode"},
  routes = {"BUTTON_ROUTES", "ToggleRouteWindow"},
}
local PAGES = {"general", "appearance", "toolbar"}
local LOOK = {background = true, accent = true, scale = true, opacity = true, locked = true}
local ARROW_FIELDS = {"arrowScale", "arrowFont", "arrowSkin"}
local layoutWaiter, lookWaiting, setting
local RUN_SPEED = 7
local TOOLBAR_WRAP, TOOLBAR_GAP, STATUS_GAP, STATUS_ROOM = 620, 5, 5, 20
local speedText, speedShown, fpsText, fpsShown, fpsDue
local SPEED_INTERVAL, FPS_INTERVAL, FPS_GATE = 0.2, 0.5, 0.4

local function Config() return RT.state.appearance end
local function Character()
  local entry = RT.EnsureCharacterState()
  if not entry.mainBar then entry.mainBar = Core.copyToolbar() end
  return entry
end
local function Label(key) return key == "callboard" and "Callboard" or L[ACTIONS[key][1]] end
local function Invoke(key)
  local action = ACTIONS[key]
  if key == "start" and RT.IsStarted() then RT.Stop()
  elseif action[2] then RT[action[2]](action[3]) end
end
function RT.ToggleInstanceMode()
  RT.SetField("autoCurrentInstanceQuest", not RT.state.autoCurrentInstanceQuest)
end

function RT.InterfaceParameter(name)
  return RT.api:GetParameter(name)
end
function RT.IsInterfaceLocked()
  return RT.InterfaceParameter("locked") and true or false
end

local function SpeedOn() return EbonAPI.Parameters.statusShown("showSpeed") end
local function FpsOn() return EbonAPI.Parameters.statusShown("showFps") end

local function SyncStatusTask()
  local frame = RT.controlFrame
  local interval = frame and frame:IsVisible() and (SpeedOn() and SPEED_INTERVAL or (FpsOn() and FPS_INTERVAL))
  if interval then RT.api:Tick("speed", interval, RT.RefreshSpeedDisplay) else RT.api:Untick("speed") end
end

local function RefreshFpsDisplay()
  if not FpsOn() then fpsText:Hide(); fpsDue = nil; return end
  fpsText:Show()
  if not fpsText:IsVisible() then return end
  local now = GetTime()
  if fpsDue and now < fpsDue then return end
  fpsDue = now + FPS_GATE
  local value = math.floor(GetFramerate() + 0.5)
  if value == fpsShown then return end
  fpsShown = value
  fpsText:SetText(string.format(L.FPS_VALUE, value))
end

function RT.RefreshSpeedDisplay()
  if not speedText then return end
  RefreshFpsDisplay()
  if not SpeedOn() then speedText:Hide(); return end
  speedText:Show()
  if not speedText:IsVisible() then return end
  local percent = math.floor(GetUnitSpeed("player") / RUN_SPEED * 100 + 0.5)
  if percent == speedShown then return end
  speedShown = percent
  speedText:SetText(string.format(L.SPEED_VALUE, percent))
end

local function WidestText(fontString, ...)
  if not fontString then return 0 end
  local widest = 0
  for index = 1, select("#", ...) do
    widest = math.max(widest, Skin.TextWidth(fontString, (select(index, ...))))
  end
  return widest
end

local function StatusLineWidth()
  local speedWidth = SpeedOn() and WidestText(speedText, string.format(L.SPEED_VALUE, 888)) or 0
  local fpsWidth = FpsOn() and WidestText(fpsText, string.format(L.FPS_VALUE, 888)) or 0
  return speedWidth + fpsWidth + ((speedWidth > 0 and fpsWidth > 0) and TOOLBAR_GAP or 0)
end

function RT.LayoutMainToolbar()
  local frame = RT.controlFrame
  if not buttons then return end
  if InCombatLockdown() then
    if not layoutWaiter then
      layoutWaiter = true
      RT.api:AfterCombat(function()
        layoutWaiter = nil
        RT.LayoutMainToolbar()
      end)
    end
    return
  end
  local order = Character().mainBar
  local width, x, y, rowHeight = 0, 0, 0, 0
  local content = frame.content
  local function PlaceButton(button)
    local size = button:GetWidth()
    if x > 0 and x + size > TOOLBAR_WRAP then y, x, rowHeight = y + rowHeight + TOOLBAR_GAP, 0, 0 end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    button:Show()
    x = x + size + TOOLBAR_GAP
    rowHeight = math.max(rowHeight, button:GetHeight())
    width = math.max(width, x - TOOLBAR_GAP)
  end
  for _, button in pairs(buttons) do button:Hide() end
  for _, key in ipairs(order) do
    local button = buttons[key]
    if not button then
      button = Skin.MakeButton(content, {textKey = ACTIONS[key][1], onClick = function() Invoke(key) end})
      buttons[key] = button
    end
    PlaceButton(button)
  end
  if frame.updateButton then
    if RT.GetAvailableUpdate() then
      PlaceButton(frame.updateButton)
    else
      frame.updateButton:Hide()
    end
  end
  local counter = RT.PortalCountButton(content)
  if counter then
    PlaceButton(counter)
  end
  local bottom = y + rowHeight
  local statusRoom = (SpeedOn() or FpsOn()) and STATUS_ROOM or 0
  RT.SetControlFrameSize(width, bottom + statusRoom)
  local room = math.max(width, Skin.WindowSize(frame), StatusLineWidth())
  RT.controlCollapsedWidth = room
  RT.controlCollapsedHeight = bottom + statusRoom
  speedText:ClearAllPoints()
  speedText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(bottom + STATUS_GAP))
  fpsText:ClearAllPoints()
  fpsText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(bottom + STATUS_GAP))
  RT.SetControlFrameSize(room, RT.controlCollapsedHeight)
  SyncStatusTask()
  RT.RefreshSpeedDisplay()
  RT.RefreshSpeedDisplay()
end

function RT.RefreshOptions()
  if not setting then RT.api:RefreshOptions() end
end

local function T(key) return function() return L[key] end end
local function Setter(fn)
  return function(info, ...)
    setting = true
    RT.api:Guard("Settings.set", fn, info, ...)
    setting = false
    RT.TouchState()
  end
end
local function Toggle(order, key, tipKey, get, set, disabled)
  return {type = "toggle", order = order, name = T(key), desc = tipKey and T(tipKey) or nil,
    get = get, set = Setter(function(_, value) set(value and true or false) end), disabled = disabled}
end
local function Field(field)
  return function() return RT.state[field] and true or false end, function(value) RT.SetField(field, value) end
end
local function Defaults(set)
  return {type = "execute", order = 1000, name = T("UI_DEFAULTS"), func = Setter(set)}
end

local function GeneralPage()
  local instanceGet, instanceSet = Field("autoCurrentInstanceQuest")
  local claimGet, claimSet = Field("autoClaim")
  local questArrowGet, questArrowSet = Field("questArrow")
  local portalFollowGet, portalFollowSet = Field("portalFollow")
  local portalAutoGet, portalAutoSet = Field("portalAuto")
  local portalCountGet, portalCountSet = Field("portalCount")
  return {type = "group", order = 1, name = T("UI_GENERAL"), args = {
    instance = Toggle(1, "AUTO_CURRENT_INSTANCE_LABEL", "AUTO_CURRENT_INSTANCE_TOOLTIP", instanceGet, instanceSet),
    echoBar = Toggle(2, "ECHO_BAR_LABEL", "ECHO_BAR_TOOLTIP", function() return RT.IsEchoBarEnabled() end, RT.SetEchoBarEnabled),
    echoOrientation = {type = "select", order = 3, name = T("ECHO_BAR_ORIENTATION_LABEL"), desc = T("ECHO_BAR_ORIENTATION_TOOLTIP"),
      values = function() return {H = L.ECHO_BAR_HORIZONTAL, V = L.ECHO_BAR_VERTICAL} end, sorting = {"H", "V"},
      get = function() return RT.GetEchoBarOrientation() end,
      set = Setter(function(_, value) if value ~= RT.GetEchoBarOrientation() then RT.ToggleEchoBarOrientation() end end),
      disabled = function() return not RT.IsEchoBarEnabled() end},
    minimap = Toggle(4, "MINIMAP_BUTTON_LABEL", "MINIMAP_BUTTON_TOOLTIP",
      function() return RT.state.minimap.shown and true or false end, RT.SetMinimapShown),
    travel = Toggle(5, "TRAVEL_LABEL", "TRAVEL_TOOLTIP", function() return RT.state.travelEnabled and true or false end, RT.SetTravelEnabled),
    travelAuto = Toggle(6, "TRAVEL_AUTO_LABEL", "TRAVEL_AUTO_TOOLTIP", function() return RT.state.travelAuto and true or false end,
      RT.SetTravelAutoEnabled, function() return not RT.state.travelEnabled end),
    portalFollow = Toggle(10, "PORTAL_FOLLOW_LABEL", "PORTAL_FOLLOW_TOOLTIP", portalFollowGet, portalFollowSet, function() return not RT.state.travelEnabled end),
    portalAuto = Toggle(12, "PORTAL_AUTO_LABEL", "PORTAL_AUTO_TOOLTIP", portalAutoGet, portalAutoSet),
    portalCount = Toggle(13, "PORTAL_COUNT_LABEL", "PORTAL_COUNT_TOOLTIP", portalCountGet, portalCountSet),
    travelDefault = {type = "select", order = 7, name = T("TRAVEL_DEFAULT_LABEL"), desc = T("TRAVEL_DEFAULT_TOOLTIP"),
      values = function() local values = RT.TravelDefaultChoices() return values end,
      sorting = select(2, RT.TravelDefaultChoices()),
      get = function() return RT.state.travelDefault or Core.TRAVEL_DEFAULT_AUTO end,
      set = Setter(function(_, value) RT.SetTravelDefault(value) end),
      disabled = function() return not RT.state.travelEnabled end},
    claim = Toggle(8, "UI_AUTO_CLAIM", "UI_AUTO_CLAIM_TOOLTIP", claimGet, claimSet),
    eternals = Toggle(9, "UI_ETERNALS", nil, function() return RT.IsEternalsEnabled() end, RT.SetEternalsEnabled),
    questArrow = Toggle(11, "QUEST_ARROW_LABEL", "QUEST_ARROW_TOOLTIP", questArrowGet, questArrowSet),
  }}
end

local function ArrowChanged()
  RT.LayoutRouteArrow()
  RT.OnArrowSkinChanged()
  RT.RefreshArrowGallery()
end
local function AppearancePage()
  return {type = "group", order = 2, name = T("UI_APPEARANCE"), args = {
    arrowScale = {type = "range", order = 1, name = T("UI_ARROW_SCALE"), min = 0.25, max = 2, step = 0.05, isPercent = true,
      get = function() return Config().arrowScale end,
      set = Setter(function(_, value) Config().arrowScale = value; RT.LayoutRouteArrow() end)},
    arrowFont = {type = "select", order = 2, name = T("UI_ARROW_FONT"),
      values = function()
        local values = {}
        for _, size in ipairs(Core.ARROW_FONT_SIZES) do values[size] = tostring(size) end
        return values
      end, sorting = Core.ARROW_FONT_SIZES,
      get = function() return Config().arrowFont end,
      set = Setter(function(_, value) Config().arrowFont = value; RT.LayoutRouteArrow() end)},
    gallery = {type = "execute", order = 3, name = T("ARROW_GALLERY_OPEN"), func = function() RT.ToggleArrowGallery() end},
    defaults = Defaults(function()
      local fresh = Core.copyAppearance()
      for _, key in ipairs(ARROW_FIELDS) do Config()[key] = fresh[key] end
      ArrowChanged()
    end),
  }}
end

local function Sequence()
  local sequence, selected, position = {}, {}, {}
  for _, key in ipairs(Character().mainBar) do sequence[#sequence + 1], selected[key] = key, true end
  for _, key in ipairs(Core.TOOLBAR_ACTIONS) do if not selected[key] then sequence[#sequence + 1] = key end end
  for index, key in ipairs(sequence) do position[key] = index end
  return sequence, selected, position
end
local function SaveToolbar(list)
  Character().mainBar = Core.copyToolbar(list)
  RT.LayoutMainToolbar()
end
local function Move(key, delta)
  local list = Core.copyToolbar(Character().mainBar)
  for index, value in ipairs(list) do
    if value == key and list[index + delta] then
      list[index], list[index + delta] = list[index + delta], list[index]
      SaveToolbar(list)
      return
    end
  end
end
local function ToolbarPage()
  local args = {defaults = Defaults(function() SaveToolbar(Core.copyToolbar()) end)}
  local function Order(offset)
    return function(info) local _, _, position = Sequence() return position[info.arg] * 3 + offset end
  end
  local function Stuck(delta)
    return function(info)
      local _, selected = Sequence()
      local list = Character().mainBar
      if not selected[info.arg] then return true end
      return (delta < 0 and list[1] == info.arg) or (delta > 0 and list[#list] == info.arg)
    end
  end
  local function Alone(info)
    local list = Character().mainBar
    return #list == 1 and list[1] == info.arg
  end
  for _, key in ipairs(Core.TOOLBAR_ACTIONS) do
    args["action_" .. key] = {type = "toggle", arg = key, order = Order(0),
      name = function(info) return Label(info.arg) end,
      desc = function(info) return Alone(info) and L.TOOLBAR_KEEP_ONE or nil end,
      disabled = Alone,
      get = function(info) local _, selected = Sequence() return selected[info.arg] == true end,
      set = Setter(function(info, value)
        local list = Core.copyToolbar(Character().mainBar)
        if value then
          list[#list + 1] = info.arg
        else
          for index, known in ipairs(list) do if known == info.arg then table.remove(list, index) break end end
        end
        SaveToolbar(list)
      end)}
    args["up_" .. key] = {type = "execute", arg = key, arrow = "UP", order = Order(1), name = T("UI_UP"),
      disabled = Stuck(-1), func = Setter(function(info) Move(info.arg, -1) end)}
    args["down_" .. key] = {type = "execute", arg = key, arrow = "DOWN", order = Order(2), name = T("UI_DOWN"),
      disabled = Stuck(1), func = Setter(function(info) Move(info.arg, 1) end)}
  end
  return {type = "group", order = 3, name = T("UI_TOOLBAR"), columns = 3, align = "CENTER", args = args}
end

function RT.RegisterOptions()
  RT.api:Options({type = "group", name = RT.ADDON_TITLE, args = {
    general = GeneralPage(),
    appearance = AppearancePage(),
    toolbar = ToolbarPage(),
    help = {type = "group", order = 4, name = T("UI_HELP"), args = RT.HelpOptions()},
  }})
end

function RT.ShowSettings(page)
  RT.api:OpenOptions(PAGES[page] or page)
end

function RT.ApplyWindowScale()
  Skin.ScaleRoots(RT.InterfaceParameter("scale"))
  RT.LayoutRouteArrow()
  RT.RefreshRouteArrowLock()
  RT.OnArrowSkinChanged()
  RT.RefreshArrowGallery()
end
function RT.ApplyLook()
  if not InCombatLockdown() then RT.ApplyWindowScale() return end
  if lookWaiting then return end
  lookWaiting = true
  RT.api:AfterCombat(function()
    lookWaiting = false
    RT.ApplyWindowScale()
  end)
end
function RT.InitAppearance()
  RT.state.appearance = Core.copyAppearance(RT.state.appearance)
  RT.api:On("PARAMETER_CHANGED", function(_, name)
    if LOOK[name] then RT.ApplyLook() end
    if name == "showSpeed" or name == "showFps" then
      SyncStatusTask()
      RT.RefreshSpeedDisplay()
      RT.LayoutMainToolbar()
    end
  end)
  RT.api:On("READY", function() RT.ApplyLook() end)
end
function RT.InitSettingsAccess()
  local frame = RT.controlFrame
  buttons = {builds = frame.buildsButton, callboard = AutoCallboardButton, start = frame.startButton}
  speedText = frame.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  speedText:SetJustifyH("RIGHT")
  Skin.MutedText(speedText)
  fpsText = frame.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  fpsText:SetJustifyH("LEFT")
  Skin.MutedText(fpsText)
  local function SyncVisibility()
    SyncStatusTask()
    RT.RefreshSpeedDisplay()
  end
  frame:HookScript("OnShow", SyncVisibility)
  frame:HookScript("OnHide", SyncVisibility)
  RT.api:On("READY", function() RT.LayoutMainToolbar() end)
  RT.LayoutMainToolbar()
  RT.RegisterOptions()
end
