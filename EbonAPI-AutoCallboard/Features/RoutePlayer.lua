local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local L = AutoCallboardLocale

local Log = RT.Log

local ACTION_INTERVAL = 0.35
local BLOCK_TIMEOUT = 12
local DIFFICULTY_GRACE = 3

local queue = {}
local queueAt
local blockDeadline
local consumed = {}
local cursor = 0
local runStart = 1
local pendingDifficulty
local pendingDifficultyUntil

local function Reset()
  queue = {}
  queueAt = nil
  blockDeadline = nil
  pendingDifficulty = nil
  pendingDifficultyUntil = nil
end

function RT.ResetRoutePlayback()
  Reset()
  consumed = {}
  cursor = 0
  runStart = 1
end

function RT.RouteLiveSignature(source, title)
  title = title or RT.RouteWindowTitle(source)

  if title then
    return Core.routeSignature({ kind = "quest", title = title })
  end

  local guid = UnitGUID and UnitGUID("npc") or nil
  local npcId = RT.ExtractBoardObjectIdFromGuid(guid)

  local available, active = RT.ReadLiveGossipQuests()

  return Core.routeSignature({
    kind = "npc",
    npcId = npcId,
    available = available,
    active = active,
  }), npcId
end

function RT.PlayerFaction()
  if not UnitFactionGroup then
    return nil
  end

  return (UnitFactionGroup("player"))
end

local function SignatureMatches(stepSignature, signature)
  if stepSignature == signature then
    return true
  end

  return stepSignature == Core.ROUTE_WINDOW_SIGNATURE and string.sub(signature, 1, 6) == "quest:"
end

function RT.MatchRouteStep(route, signature)
  if type(route) ~= "table" or type(route.steps) ~= "table" or signature == "" then
    return nil
  end

  local fallback

  for index = 1, #(route.steps) do
    local step = route.steps[index]
    local stepSignature = Core.routeSignature(step)
    local taken = stepSignature == Core.ROUTE_WINDOW_SIGNATURE and RT.FindQuestLogIndexByID(step.questId)

    if SignatureMatches(stepSignature, signature) and not consumed[index] and not taken then
      if index > cursor then
        return index
      end

      if not fallback then
        fallback = index
      end
    end
  end

  return fallback
end

local function RouteName()
  local route = RT.GetActiveRoute()

  return route and route.name and tostring(route.name) or "?"
end

local function ApplyTier(tier)
  tier = Core.sanitizeDifficulty(tier)

  local current = RT.GetCurrentDifficulty()

  if not tier or not current or current == tier then
    return
  end

  if not RT.CanApplyDifficulty(tier) then
    local name = UnitAffectingCombat and UnitAffectingCombat("player") and "PLAYER.DIFFICULTY_IN_COMBAT"
      or "PLAYER.DIFFICULTY_NOT_RESTING"

    RT.api:Report(RT.api:Problem(name, { tier = Core.difficultyLabel(tier), route = RouteName() }))
    return
  end

  local _, refused = RT.ApplyListDifficulty(tier, "route")

  if refused then
    return
  end

  pendingDifficulty = tier
  pendingDifficultyUntil = GetTime() + DIFFICULTY_GRACE
end

local function ApplyStepDifficulty(step)
  ApplyTier(step and step.difficulty)
end

local function CheckPendingDifficulty()
  if not pendingDifficulty then
    return
  end

  if RT.GetCurrentDifficulty() == pendingDifficulty then
    pendingDifficulty = nil
    pendingDifficultyUntil = nil
    return
  end

  if GetTime() > (pendingDifficultyUntil or 0) then
    local current = RT.GetCurrentDifficulty()

    RT.api:Report(RT.api:Problem("PLAYER.DIFFICULTY_NOT_APPLIED", {
      tier = Core.difficultyLabel(pendingDifficulty),
      current = current and Core.difficultyLabel(current) or "unknown",
      route = RouteName(),
    }))
    pendingDifficulty = nil
    pendingDifficultyUntil = nil
  end
end

local ACTION_CALLS = {
  gossip = { GossipFrame = "SelectGossipOption" },
  available = { GossipFrame = "SelectGossipAvailableQuest", QuestFrameGreetingPanel = "SelectAvailableQuest" },
  active = { GossipFrame = "SelectGossipActiveQuest", QuestFrameGreetingPanel = "SelectActiveQuest" },
  accept = { QuestFrameDetailPanel = "AcceptQuest" },
  complete = { QuestFrameProgressPanel = "CompleteQuest" },
  turnin = { QuestFrameRewardPanel = "GetQuestReward" },
}

local function OffersItsQuest(action)
  local title = RT.NormalizeQuestTitle(action.title)

  return title == "" or RT.NormalizeQuestTitle(RT.GetQuestOfferTitle()) == title
end

local function BindAcceptTitle(action, title)
  if action and action.kind == "accept" and RT.NormalizeQuestTitle(action.title) == ""
      and type(title) == "string" and title ~= "" then
    action.title = title
  end
end

local function PickedQuestTitle(action)
  local available = RT.ReadLiveGossipQuests()
  local picked = available[tonumber(action.index) or 0]

  return picked and picked.title
end

local function LeftToPlayer(action)
  if action.kind == "confirm" then
    return StaticPopup_Visible and (StaticPopup_Visible("QUEST_ACCEPT") or StaticPopup_Visible("QUEST_ACCEPT_LOG_FULL")) and true or false
  end

  if action.kind ~= "accept" or not RT.FrameIsVisibleOrShown(QuestFrameDetailPanel) then
    return false
  end

  if RT.IsQuestOfferFromPlayer() or not OffersItsQuest(action) then
    return true
  end

  return not action.anyGiver and not RT.IsQuestOfferFromNpc()
end

local function ReadyCall(action)
  if action.kind == "confirm" or LeftToPlayer(action) then
    return nil
  end

  for frameName, call in pairs(ACTION_CALLS[action.kind] or {}) do
    if RT.FrameIsVisibleOrShown(_G[frameName]) then
      return call
    end
  end

  return nil
end

local function AlreadyDone(action)
  if action.kind ~= "accept" and action.kind ~= "confirm" then
    return false
  end

  return RT.RouteQuestIdByTitle(action.title) ~= nil
    or (action.questId ~= nil and RT.FindQuestLogIndexByID(action.questId) ~= nil)
end

local function RunAction(action, call)
  local argument = action.kind == "turnin" and (action.reward or 0) or action.index
  local ok, failure = pcall(_G[call], argument)

  Log("route", "played ", tostring(action.kind), " ", tostring(argument), " ok=", tostring(ok))

  if not ok then
    RT.api:Report(RT.api:Problem("PLAYER.ACTION_CALL_FAILED", {
      what = action.kind,
      position = action.step,
      argument = tostring(argument),
      detail = string.sub(tostring(failure), 1, 120),
      route = RouteName(),
    }))
  end

  return ok
end

function RT.QueueRouteBlock(route, index)
  local step = route.steps[index]
  local signature = Core.routeSignature(step)

  if not step or signature == "" then
    return false
  end

  if #(step.actions) > 0 then
    Reset()
  end

  ApplyStepDifficulty(step)

  local anyGiver = signature == Core.ROUTE_WINDOW_SIGNATURE or (type(step.item) == "string" and step.item ~= "")
  local offered = RT.FrameIsVisibleOrShown(QuestFrameDetailPanel) and RT.GetQuestOfferTitle() or nil

  for i = 1, #(step.actions) do
    local queued = Core.copyRouteAction(step.actions[i])

    if queued then
      queued.step = index

      queued.anyGiver = anyGiver
      BindAcceptTitle(queued, offered)
      table.insert(queue, queued)
    end
  end

  local last = RT.QueueTravelRun(route, index + 1)

  consumed[index] = true
  cursor = math.max(cursor, index, last)
  RT.RememberRouteCursor()
  queueAt = GetTime()
  blockDeadline = GetTime() + BLOCK_TIMEOUT

  RT.PointRouteArrowAtNextStep(route, index)
  Log("route", "block ", tostring(index), " queued with ", tostring(#(queue)), " actions")
  RT.RefreshRoutePanel()

  return true
end

function RT.QueueTravelRun(route, from)
  local index = tonumber(from) or 1
  local last = index - 1

  while true do
    local step = route.steps[index]

    if not step or step.kind ~= "travel" then
      break
    end

    table.insert(queue, {
      kind = "travel",
      checkpoint = step.checkpoint,
      checkpointName = step.checkpointName,
      difficulty = step.difficulty,
      step = index,
    })

    consumed[index] = true
    last = index
    index = index + 1
  end

  if #(queue) > 0 then
    queueAt = queueAt or GetTime()
    blockDeadline = blockDeadline or (GetTime() + BLOCK_TIMEOUT)
  end

  return last
end

function RT.BeginRoutePlaybackRun(route, from)
  if type(route) ~= "table" or type(route.steps) ~= "table" then
    RT.api:Report(RT.api:Problem("PLAYER.ROUTE_INVALID", {
      route = type(route) == "table" and tostring(route.name) or tostring(route),
    }))
    RT.StopRoutePlayback("invalid_route")
    return nil, "invalid_route"
  end

  local start = math.max(1, math.floor(tonumber(from) or 1))

  RT.SetRouteCursor(start - 1, start)
  Reset()

  if runStart == 1 then
    ApplyTier(route.difficulty)
  end

  cursor = math.max(cursor, RT.QueueTravelRun(route, runStart))
  RT.RememberRouteCursor()
  RT.PointRouteArrowAtNextStep(route, cursor)
end

function RT.RouteCurrentBlock()
  local route = RT.IsPlayingRoute() and RT.GetActiveRoute()

  if not route then
    return nil
  end

  local index = queue[1] and queue[1].step or (cursor + 1)

  if index > #(route.steps) then
    return nil
  end

  return index
end

function RT.SkipRouteBlock()
  local current = RT.RouteCurrentBlock()

  if not current then
    return false
  end

  return RT.StartRoutePlayback("skip", nil, current + 1)
end

function RT.PointRouteArrowAtNextStep(route, index)
  if type(route) ~= "table" or type(route.steps) ~= "table" then
    return
  end

  for i = (tonumber(index) or 0) + 1, #(route.steps) do
    local step = route.steps[i]

    if step.kind ~= "travel" and not consumed[i] and step.map and step.map ~= "" and step.x and step.y then
      RT.SetRouteArrowTarget(step)
      return
    end
  end

  RT.ClearRouteArrowTarget()
end

function RT.PlayRouteQuestChange(change)
  local route = RT.GetActiveRoute()
  local index = route and RT.MatchRouteStep(route, Core.routeSignature(change))

  if index then
    RT.QueueRouteBlock(route, index)
  end
end

function RT.OnRouteDialogueOpened(source, title)
  if not RT.IsPlayingRoute() then
    return
  end

  if #(queue) > 0 then
    return
  end

  local route = RT.GetActiveRoute()

  if not route then
    return
  end

  local signature = RT.RouteLiveSignature(source, title)
  local index = RT.MatchRouteStep(route, signature)

  if not index then
    Log("route", "ignored, no block matches ", tostring(signature), " source=", tostring(source))
    return
  end

  RT.QueueRouteBlock(route, index)
end

local function WaitsForPlayer(route)
  for index = 1, #(route.steps) do
    if route.steps[index].kind ~= "travel" then
      return true
    end
  end

  return false
end

local function FinishRoute()
  local route = RT.GetActiveRoute()

  if route and RT.IsRouteLooping() and WaitsForPlayer(route) and RT.StartRoutePlayback("loop", route.id, 1) then
    return
  end

  RT.StopRoutePlayback("end")
end

function RT.ProcessRoutePlayback()
  if not RT.IsPlayingRoute() then
    return 1
  end

  CheckPendingDifficulty()

  if #(queue) == 0 then
    if not pendingDifficulty and not RT.RouteCurrentBlock() then
      FinishRoute()
    end

    return 0.5
  end

  local now = GetTime()

  if blockDeadline and now > blockDeadline then
    Log("route", "block timed out with ", tostring(#(queue)), " actions left")
    RT.api:Report(RT.api:Problem("PLAYER.BLOCK_TIMEOUT", {
      position = queue[1].step,
      what = queue[1].kind,
      left = #(queue),
      route = RouteName(),
    }))
    Reset()
    RT.StopRoutePlayback("timeout")
    return 1
  end

  if queueAt and now < queueAt then
    return ACTION_INTERVAL
  end

  local action = queue[1]
  local call = action.kind == "travel" or ReadyCall(action)

  if not call and not AlreadyDone(action) then
    if LeftToPlayer(action) then
      blockDeadline = now + BLOCK_TIMEOUT
    end

    return ACTION_INTERVAL
  end

  table.remove(queue, 1)
  queueAt = now + ACTION_INTERVAL

  if action.kind == "travel" then
    ApplyTier(action.difficulty)
    RT.UseRouteCheckpoint(action.checkpoint, action.checkpointName)
  elseif call then
    if action.kind == "available" then
      BindAcceptTitle(queue[1], PickedQuestTitle(action))
    end

    RunAction(action, call)
  end

  if #(queue) == 0 then
    blockDeadline = nil
  else
    blockDeadline = now + BLOCK_TIMEOUT
  end

  if RT.RouteCurrentBlock() ~= action.step then
    RT.RefreshRoutePanel()
  end

  return ACTION_INTERVAL
end

function RT.UseRouteCheckpoint(checkpointId, recordedName)
  local recorded = tonumber(checkpointId)
  checkpointId = Core.resolveCheckpointId(recorded)

  local service = EbonAPI.Ebonhold.Service("CheckpointService")

  if not checkpointId or not service or type(service.UseCheckpoint) ~= "function" then
    return false
  end

  local known, checkpoints = pcall(service.GetCheckpoints)

  if known and type(checkpoints) == "table" and Core.countUnlockedCheckpoints(checkpoints) > 0 then
    local found

    for i = 1, #(checkpoints) do
      if tonumber(checkpoints[i].id) == checkpointId then
        found = found or checkpoints[i]

        if Core.travelCheckpointUsable(checkpoints[i]) then
          found = checkpoints[i]
          break
        end
      end
    end

    local refusal = not found and L.ROUTE_CHECKPOINT_RETIRED
        or not Core.travelCheckpointUsable(found) and L.ROUTE_CHECKPOINT_LOCKED

    if refusal then
      RT.api:Report(RT.api:Problem("PLAYER.CHECKPOINT_LOCKED", {
        checkpoint = checkpointId,
        place = Core.routeCheckpointName(recorded, recordedName),
        position = queue[1] and queue[1].step or cursor,
        route = RouteName(),
      }))
      RT.StopRoutePlayback("checkpoint")
      return false
    end
  end

  local used = EbonAPI.Ebonhold.UseCheckpoint(checkpointId)

  Log("route", "checkpoint ", tostring(checkpointId), " ok=", tostring(used and true or false))

  if not used then
    RT.StopRoutePlayback("checkpoint_failed")
    return false
  end

  return true
end

function RT.RouteCursor()
  return cursor
end

function RT.SetRouteCursor(index, start)
  cursor = tonumber(index) or 0
  runStart = math.max(1, math.floor(tonumber(start) or 1))
  consumed = {}

  for skipped = 1, runStart - 1 do
    consumed[skipped] = true
  end
end

local function RememberCursor()
  RT.StoreRouteCursor(cursor, runStart)
end

RT.RememberRouteCursor = RememberCursor
