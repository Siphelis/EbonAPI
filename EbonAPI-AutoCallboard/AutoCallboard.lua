local ADDON_NAME = ...
local Core = AutoCallboardCore

local RT = AutoCallboardRuntime

local frame = CreateFrame("Frame")
RT.eventFrame = frame
RT.api:Track("Scheduler", frame)
local characterProfileKey
local state = RT.state

local Log = RT.Log

RT.controlCollapsedWidth = 404
RT.controlCollapsedHeight = 44

function RT.FlushQuestStateBackup()
  EbonAPIAutoCallboardQuestDB = nil
end

local function ApplyState(nextState)
  RT.PersistState(nextState)

  RT.RefreshBoardGraft()

  RT.PositionMinimapButton()

  RT.RefreshOptions()
end

function RT.SaveControlFrameShown(shown)
  if not state or state.buttonShown == shown then
    return
  end

  state.buttonShown = shown and true or false
end

local function GetCharacterProfileKey()
  local playerName = UnitName and UnitName("player") or "Unknown"
  local realmName = GetRealmName and GetRealmName() or "UnknownRealm"

  if playerName == "" then
    playerName = "Unknown"
  end

  if realmName == "" then
    realmName = "UnknownRealm"
  end

  return realmName .. "/" .. playerName
end

local function SetUpCharacter()
  characterProfileKey = GetCharacterProfileKey()
  RT.characterProfileKey = characterProfileKey

  RT.RunAccountMigration(characterProfileKey)
  RT.ApplyCharacterState()
end

local function CommitStateChange()
  RT.TouchState()
  RT.RefreshBoardGraft()
  RT.PositionMinimapButton()
  RT.RefreshOptions()
end

function RT.SetField(field, value)
  state[field] = value
  CommitStateChange()

  if field == "targetName" then
    RT.SetCallboardButtonText(value)
  elseif field == "travelEnabled" then
    RT.OnTravelEnabledChanged()
  elseif field == "travelAuto" then
    RT.OnTravelAutoChanged()
  elseif field == "questArrow" then
    RT.RefreshQuestArrow("setting")
  elseif field == "travelDefault" then
    RT.RefreshTravelSuggestion("setting", true)
  elseif field == "portalFollow" then
    RT.RefreshTravelSuggestion("setting", true)
  elseif field == "portalCount" then
    RT.LayoutMainToolbar()
  elseif field == "autoCurrentInstanceQuest" then
    RT.currentInstanceQuestSignature = nil

    RT.InvalidateInstanceTarget()
    RT.RefreshCurrentInstanceQuestTarget("setting")
  end
end

local nextTickAt
local ACTIVE_INTERVAL = 0.066
local IDLE_INTERVAL = 0.25

local UpdateBrowserAnimations = RT.UpdateBrowserAnimations

local TASKS = {
  { fn = RT.WatchDifficultyChange, every = 0.5 },
  { fn = function() return RT.WatchEternalSequence() end, every = 1 },
  { fn = function() return RT.WatchTravelSuggestion() end, every = 1 },
  { fn = function() return RT.WatchQuestArrow() end, every = 1 },
  { fn = function() return RT.ProcessRoutePlayback() end, every = 0.35 },
  { fn = function() RT.RefreshBoardStatus() end, every = 1 },
}

RT.api:Tick("overlays", 0.5, RT.SyncOverlayFrameLevels)

local function Busy()
  return RT.IsAnyBrowserAnimating()
end

local function Awake()
  return RT.IsCollectionsShown()
end

local taskNow

local function Tick()
  local now = GetTime()

  if Busy() then
    nextTickAt = nil
  else
    if nextTickAt and now < nextTickAt then
      return
    end

    nextTickAt = now + (Awake() and ACTIVE_INTERVAL or IDLE_INTERVAL)
  end

  UpdateBrowserAnimations()

  for i = 1, #(TASKS) do
    local task = TASKS[i]

    if not task.nextAt or now >= task.nextAt then
      taskNow = now
      local run = task.run
      if not run then
        local fn = task.fn
        run = function() return fn(taskNow) end
        task.run = run
      end
      local wait = RT.api:Guard("Scheduler.task", run)
      task.nextAt = now + (wait or task.every)
    end
  end

  if RT.buildsRefreshAt and now >= RT.buildsRefreshAt then
    RT.buildsRefreshAt = nil
    RT.RequestBuildsRefresh("post-connexion")
  end

  if RT.DebugTick then
    RT.DebugTick(now)
  end
end

frame:SetScript("OnUpdate", function()
  if nextTickAt and GetTime() < nextTickAt and not Busy() then
    return
  end

  RT.api:Guard("Scheduler.tick", Tick)
end)

local EVENTS = {}

local function Dispatch(event, ...)
  if RT.DebugEvent then
    RT.DebugEvent(event, ...)
  end

  local handler = EVENTS[event]
  if handler then
    handler(...)
  end
end

RT.api:TrackFunction("Events", Dispatch)

local events = RT.NewEventRelay(Dispatch)
RT.events = events

local function CreateInterface()
  if InCombatLockdown() then
    RT.api:AfterCombat(CreateInterface)
    return
  end

  RT.CreateCallboardButton()
  RT.CreateMinimapButton()
  RT.ApplyEchoBar()
  RT.InitSettingsAccess()
  RT.RestoreRouteWindow()
end

EVENTS.ADDON_LOADED = function(arg1)
  if arg1 ~= ADDON_NAME then
    return
  end

  events:Unlisten("ADDON_LOADED")
  EVENTS.ADDON_LOADED = nil

  local api = RT.api

  local function Boot(name, fn)
    return api:Guard("Boot." .. name, fn)
  end

  Boot("state", function()
    ApplyState(Core.restoreQuestState(EbonAPIAutoCallboardDB, EbonAPIAutoCallboardQuestDB))
  end)

  Boot("repair", function()
    RT.RepairKnownQuestState()
    RT.PersistState(Core.migrateLegacyPresets(state, AutoCallboardPresetsDB))
  end)
  Boot("character", SetUpCharacter)
  Boot("hooks", function()
    RT.InstallRouteRecorderHooks()
  end)
  Boot("routes", function()
    RT.ResumeRouteRecording()
    RT.ResumeRoutePlayback()
  end)
  Boot("appearance", RT.InitAppearance)
  Boot("ready", function()
    RT.api:On("READY", CreateInterface)
    RT.api:On("READY", EVENTS.ZONE_CHANGED_NEW_AREA)
  end)
  Boot("bindings", RT.RefreshBindingNames)
  Boot("version", RT.InitVersionWatch)
  Boot("share", RT.InitRouteShare)
  Boot("portals", RT.InitPortals)
  Boot("builds", RT.InitBuilds)
  Boot("board", RT.InitBoard)
  Boot("questArrow", function()
    RT.api:On("SERVER_CALLBOARD", function() RT.RefreshQuestArrow("SERVER_CALLBOARD") end)
    RT.api:On("SERVER_CALLBOARD_RESULT", function() RT.RefreshQuestArrow("SERVER_CALLBOARD_RESULT") end)
  end)

  RT.buildsRefreshAt = GetTime() + RT.buildsRefreshDelay

  Log("load", "AutoCallboard loaded")
end

EVENTS.PLAYER_REGEN_DISABLED = function()
  RT.RefreshEchoBar()
end

EVENTS.PLAYER_REGEN_ENABLED = EVENTS.PLAYER_REGEN_DISABLED

EVENTS.PLAYER_LOGOUT = function()
  RT.FlushQuestStateBackup()
end

local function RouteDialogue(source)
  RT.RecordNpcStep(source)
  RT.OnRouteDialogueOpened(source)
end

EVENTS.GOSSIP_SHOW = function()
  local npcName = GossipFrameNpcNameText and GossipFrameNpcNameText:GetText()

  if RT.IsBoardName(npcName) or RT.GetNpcBoardInfo() then
    RT.SyncOverlayFrameLevels()
    return
  end

  RouteDialogue("GOSSIP_SHOW")
end

EVENTS.QUEST_GREETING = function()
  RouteDialogue("QUEST_GREETING")
end

EVENTS.QUEST_PROGRESS = function()
  RouteDialogue("QUEST_PROGRESS")
end

EVENTS.QUEST_COMPLETE = function()
  RouteDialogue("QUEST_COMPLETE")
end

EVENTS.GOSSIP_CLOSED = function()
  RT.EndRouteNpcStep()
end

EVENTS.QUEST_DETAIL = function()
  RouteDialogue("QUEST_DETAIL")

  local acceptUntil = RT.GetPendingAcceptUntil()

  if not (RT.IsStarted() and acceptUntil and GetTime() <= acceptUntil) then
    return
  end

  if not RT.IsQuestOfferFromBoard() then
    Log("quest", "auto accept skipped source=QUEST_DETAIL reason=offer not from the board")
    return
  end

  RT.ClearPendingAcceptUntil()
  RT.AcceptCurrentQuestOffer("QUEST_DETAIL")
end

EVENTS.QUEST_ACCEPT_CONFIRM = function(_, title)
  RT.routeConfirmTitle = title
  RT.OnRouteDialogueOpened("QUEST_ACCEPT_CONFIRM", title)
end

EVENTS.QUEST_ACCEPTED = function(arg1, arg2)
  RT.ClearPendingAcceptUntil()
  RT.TrackAcceptedQuest(arg1, arg2)
end

EVENTS.QUEST_LOG_UPDATE = function()
  if not RT.IsBoardQuestPassQuiet() then
    RT.WatchRouteQuestLog()
    RT.RefreshLastAcceptedQuest()
    RT.WatchBoardQuestLog()
  end

  RT.RefreshQuestArrow("QUEST_LOG_UPDATE")
  RT.CheckEternalQuestStillActive("QUEST_LOG_UPDATE")
end

EVENTS.QUEST_FINISHED = function()
  RT.EndRouteNpcStep()
  RT.CheckEternalQuestStillActive("QUEST_FINISHED")
end

EVENTS.ZONE_CHANGED_NEW_AREA = function()
  RT.InvalidateInstanceTarget()
  RT.InvalidatePlayerMap()
  RT.LayoutRouteArrow()
  RT.RefreshQuestArrow("ZONE_CHANGED_NEW_AREA")
end

EVENTS.PLAYER_ENTERING_WORLD = EVENTS.ZONE_CHANGED_NEW_AREA

EVENTS.ZONE_CHANGED = function()
  RT.InvalidatePlayerMap()
end

EVENTS.ZONE_CHANGED_INDOORS = EVENTS.ZONE_CHANGED

EVENTS.PLAYER_DEAD = function()
  RT.StopByDeath()
end

frame:SetScript("OnEvent", function(_, event, ...)
  if RT.DebugEvent and not events:IsListening(event) then
    RT.DebugEvent(event, ...)
  end
end)

events:Listen("ADDON_LOADED")
events:Listen("PLAYER_LOGOUT")
events:Listen("QUEST_DETAIL")
events:Listen("QUEST_PROGRESS")
events:Listen("QUEST_COMPLETE")
events:Listen("QUEST_ACCEPT_CONFIRM")
events:Listen("QUEST_ACCEPTED")
events:Listen("QUEST_LOG_UPDATE")
events:Listen("QUEST_FINISHED")
events:Listen("GOSSIP_SHOW")
pcall(events.Listen, events, "QUEST_GREETING")
events:Listen("GOSSIP_CLOSED")
events:Listen("ZONE_CHANGED_NEW_AREA")
events:Listen("PLAYER_ENTERING_WORLD")
events:Listen("ZONE_CHANGED")
events:Listen("PLAYER_DEAD")
pcall(events.Listen, events, "ZONE_CHANGED_INDOORS")
