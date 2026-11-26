local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local state = RT.state

local Log = RT.Log

local PENDING_TIMEOUT = 5
local FRESH_BOARD_TIMEOUT = 3

local SESSION_STOPS = {
  far = "BOARD_REFUSED_FAR",
  dead = "BOARD_REFUSED_DEAD",
  full = "BOARD_REFUSED_FULL",
  cannot = "BOARD_REFUSED_CANNOT",
}

local RESET_EXCLUSIONS = { exhausted = true, inlog = true, notoffered = true, unknown = true }

local TRANSIENT = { BOARD_ACCEPTING = true, BOARD_CLAIMING = true }

local armed = false
local session
local excluded = {}
local readOnlyNoted = false
local closedAt = 0
local statusKey, statusArgs

local function StatusText()
  local text = L[statusKey] or ""

  if statusArgs.n > 0 then
    return string.format(text, unpack(statusArgs, 1, statusArgs.n))
  end

  return text
end

local function SetQuestStatus(key, ...)
  statusKey = key
  statusArgs = { n = select("#", ...), ... }

  Log("board", StatusText())
  RT.RefreshBoardGraft()
end

local function CountDesiredQuests()
  return Core.desiredQuestCount(state and state.desiredQuests)
end

local function NewSession(access)
  local board = RT.GetBoard()

  session = {
    access = access,
    fresh = board ~= nil and board.receivedAt > closedAt,
    freshUntil = GetTime() + FRESH_BOARD_TIMEOUT,
    asked = {},
    refused = {},
    claimSent = {},
    reported = {},
    taken = 0,
  }
end

local function EndSession(newVisit)
  local stop = session and session.stopped and SESSION_STOPS[session.stopped]

  session = nil

  if TRANSIENT[statusKey] or (newVisit and stop and statusKey == stop) then
    statusKey = nil
    RT.RefreshBoardGraft()
  end
end

local function SessionExclusions()
  local merged = {}

  for key in pairs(excluded) do
    merged[key] = true
  end

  for key in pairs(session.refused) do
    merged[key] = true
  end

  for key in pairs(session.asked) do
    merged[key] = true
  end

  return merged
end

local function NothingWanted()
  return CountDesiredQuests() == 0 and not RT.RefreshCurrentInstanceQuestTarget("status")
end

local function DoneStatus()
  local unpaid = session.unpaid

  if session.skipped then
    SetQuestStatus("BOARD_REFUSED_SKIPPED", session.skipped)
  elseif session.taken > 0 then
    SetQuestStatus("BOARD_DONE_TAKEN", session.taken)
  elseif unpaid then
    SetQuestStatus("BOARD_OUTLEVELED", Core.questTitle(unpaid), Core.outleveledAbove(unpaid))
  elseif NothingWanted() then
    SetQuestStatus("BOARD_WAITING_NOTHING")
  else
    SetQuestStatus("BOARD_DONE_NONE")
  end
end

local function NextContract(board, source)
  local target = RT.RefreshCurrentInstanceQuestTarget(source)
  local wanted, unpaid = Core.wantedContracts(board.quests, state.desiredQuests, target, SessionExclusions())

  session.unpaid = unpaid[1]
  session.target = RT.instanceTargetSignature

  for i = 1, #(wanted) do
    local quest = wanted[i]

    if not RT.FindQuestLogIndexByID(quest.questId) then
      return quest
    end

  end

  return nil
end

local function ForgetAsked(board)
  local offered = {}

  for i = 1, #(board.quests) do
    local quest = board.quests[i]

    if tonumber(quest.state) == Core.STATE.AVAILABLE then
      offered[Core.questKey(quest) or ""] = true
    end
  end

  for key in pairs(session.asked) do
    if not offered[key] then
      session.asked[key] = nil
    end
  end
end

local function JournalQuests()
  local _, quests = GetNumQuestLogEntries()

  return quests or 0
end

local function LiftStop()
  local reason = session.stopped

  if not reason then
    return
  end

  local lifted = false

  if reason == "dead" then
    lifted = session.stoppedDead == true and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
  elseif reason == "full" then
    lifted = JournalQuests() < (session.stoppedQuests or 0)
  end

  if lifted then
    session.stopped = nil
    session.stoppedQuests = nil
    session.done = nil

    if statusKey == SESSION_STOPS[reason] then
      statusKey = nil
      RT.RefreshBoardGraft()
    end
  end
end

local function HasUnclaimed(board)
  local sent = session.claimSent

  for i = 1, #(board.ready) do
    if not sent[board.ready[i].questId] then
      return true
    end
  end

  return false
end

local function ForgetClaimed(board)
  local sent = session.claimSent
  local ready = {}

  for i = 1, #(board.ready) do
    ready[board.ready[i].questId] = true
  end

  for questId in pairs(sent) do
    if not ready[questId] then
      sent[questId] = nil
    end
  end
end

local function Claim(board, source)
  for i = 1, #(board.ready) do
    session.claimSent[board.ready[i].questId] = true
  end

  session.pending = { op = "claim", at = GetTime() }
  RT.SendBoardClaim(0)
  SetQuestStatus("BOARD_CLAIMING")
  Log("board", "claim all source=", source)
end

local function Accept(quest, source)
  local key = Core.questKey(quest)

  session.asked[key] = true
  session.pending = {
    op = "accept",
    questId = quest.questId,
    key = key,
    title = Core.questTitle(quest),
    at = GetTime(),
  }
  session.done = nil
  RT.SendBoardAccept(quest.questId)
  RT.ArmQuestAccept()
  SetQuestStatus("BOARD_ACCEPTING", Core.questTitle(quest))
  Log("board", "accept ", quest.questId, " source=", source)
end

function RT.EvaluateBoard(source)
  local board = RT.GetBoard()

  if not session or not board or session.stopped or session.pending then
    return false
  end

  local now = GetTime()

  if (not session.fresh and now < session.freshUntil) or (session.awaitingBoard and now < session.awaitingBoard) then
    return false
  end

  if state.autoClaim and board.claimable > 0 and HasUnclaimed(board) then
    Claim(board, source)
    return true
  end

  if not armed then
    return false
  end

  if session.done and source == "watch" and not RT.instanceTargetDirty
      and session.target == RT.instanceTargetSignature then
    return false
  end

  local quest = NextContract(board, source)

  if quest then
    Accept(quest, source)
    return true
  end

  if not session.done then
    session.done = true
    DoneStatus()
  end

  return false
end

function RT.OnBoardChanged()
  local board = RT.GetBoard()

  RT.OnBoardAbandonStep()

  if session then
    session.fresh = true
    session.awaitingBoard = nil

    if board then
      ForgetClaimed(board)
      ForgetAsked(board)
    end
  end

  RT.RefreshBoardGraft()
  RT.RefreshTravelSuggestion("board", true)
  RT.EvaluateBoard("board")
end

local boardLot

local function BoardLotNext()
  while boardLot and #boardLot.queue > 0 do
    local questId = table.remove(boardLot.queue, 1)

    if RT.SendBoardAccept(questId) then
      boardLot.pending = questId
      RT.ArmQuestAccept()
      Log("board", "lot accept ", questId)

      return
    end
  end

  boardLot = nil
end

function RT.AcceptBoardLot(ids)
  if boardLot or RT.IsStarted() or (session and session.pending) or type(ids) ~= "table" or #ids == 0 then
    return false
  end

  local queue = {}

  for i = 1, #ids do
    queue[i] = ids[i]
  end

  boardLot = { queue = queue, pending = nil }
  BoardLotNext()

  return true
end

function RT.OnBoardResult(result)
  if boardLot and result.op == "accept" and result.questId == boardLot.pending then
    boardLot.pending = nil
    BoardLotNext()

    return
  end

  local pending = session and session.pending

  if not pending or result.op ~= pending.op
      or (pending.op == "accept" and result.questId ~= pending.questId) then
    return
  end

  session.pending = nil

  if result.ok then
    session.awaitingBoard = GetTime() + FRESH_BOARD_TIMEOUT

    if pending.op == "accept" then
      session.taken = session.taken + 1
      session.skipped = nil
      SetQuestStatus("BOARD_TAKEN", pending.title)
    else
      session.asked = {}
      SetQuestStatus("BOARD_CLAIMED", result.count)
    end

    return
  end

  local reason = result.reason

  if session.access == "remote" and not session.reported[reason] then
    session.reported[reason] = true
    Core.report(Core.problem(reason == "far" and "BOARD.REMOTE_FAR" or "BOARD.REMOTE_REFUSED", {
      op = pending.op,
      reason = tostring(reason),
      questId = pending.questId or 0,
    }))
  end

  if SESSION_STOPS[reason] then
    session.stopped = reason
    session.stoppedQuests = JournalQuests()
    session.stoppedDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") and true or false
    session.asked[pending.key or ""] = nil
    SetQuestStatus(SESSION_STOPS[reason])
  elseif pending.op == "claim" then
    SetQuestStatus("BOARD_CLAIM_REFUSED")
  else
    if RESET_EXCLUSIONS[reason] then
      excluded[pending.key] = true
    else
      session.refused[pending.key] = true
    end

    session.skipped = pending.title
    SetQuestStatus("BOARD_REFUSED_SKIPPED", pending.title)
  end

  Log("board", pending.op, " refused reason=", reason)
  RT.EvaluateBoard("result")
end

function RT.OnBoardReset()
  excluded = {}

  if session then
    session.asked = {}
    session.refused = {}
    session.claimSent = {}
    session.done = nil
    session.skipped = nil
  end
end

function RT.WatchBoard()
  local access = RT.GetBoardAccess()

  if not access then
    if session then
      Log("board", "board left")
      EndSession()
    end

    closedAt = GetTime()

    local shown = RT.IsBoardWindowShown()

    if armed and shown and not readOnlyNoted then
      SetQuestStatus("BOARD_READ_ONLY")
    end

    readOnlyNoted = shown

    return
  end

  local dialogue = RT.GetNpcBoardInfo() ~= nil

  if session and dialogue and not session.dialogue then
    Log("board", "board talked to again")
    EndSession(true)
  end

  if not session then
    NewSession(access)
    Log("board", "board open access=", access)

    if not session.fresh and not RT.IsBoardWindowShown() then
      RT.RequestBoard("board open")
    end
  end

  session.access = access
  session.dialogue = dialogue

  if not dialogue then
    closedAt = GetTime()
  end

  local pending = session.pending

  if pending and GetTime() - pending.at > PENDING_TIMEOUT then
    Log("board", "no answer to ", pending.op, ", moving on")
    session.pending = nil
    session.done = nil

    if TRANSIENT[statusKey] then
      statusKey = nil
      RT.RefreshBoardGraft()
    end
  end

  LiftStop()
  RT.EvaluateBoard("watch")
end

function RT.Start()
  armed = true

  if session then
    session.stopped = nil
    session.done = nil
  end

  local problem = RT.GetBoardProblem()

  if problem then
    SetQuestStatus(problem)
  elseif session then
    RT.EvaluateBoard("start")
  elseif NothingWanted() then
    SetQuestStatus("BOARD_WAITING_NOTHING")
  elseif RT.HasRemoteBoard() then
    return RT.UpdateStartButtons()
  else
    SetQuestStatus(RT.IsBoardWindowShown() and "BOARD_READ_ONLY" or "BOARD_WAITING")
  end

  RT.UpdateStartButtons()
end

function RT.Stop()
  armed = false

  if session then
    session.pending = nil
  end

  RT.ClearPendingAcceptUntil()
  SetQuestStatus("BOARD_STOPPED")
  RT.UpdateStartButtons()
end

function RT.IsStarted()
  return armed
end

function RT.GetBoardStop()
  return session and session.stopped or nil
end

function RT.SetWantedKeys(keys, wanted)
  if type(keys) ~= "table" then
    return false
  end

  local desired = state.desiredQuests
  local changed = false

  wanted = wanted and true or false

  for i = 1, #(keys) do
    local key = keys[i]

    if type(key) == "string" and key ~= "" and (desired[key] == true) ~= wanted then
      desired[key] = wanted or nil
      changed = true

      if wanted then
        excluded[key] = nil
      end
    end
  end

  if not changed then
    return false
  end

  local entry = RT.EnsureCharacterState()
  if entry and entry.desiredQuests ~= desired then
    entry.desiredQuests = desired
  end

  RT.TouchState()

  if session then
    session.done = nil
  end

  RT.EvaluateBoard("toggle")
  RT.RefreshBoardGraft()

  return true
end

function RT.ToggleDesiredQuest(key)
  if type(key) ~= "string" or key == "" then
    return
  end

  RT.SetWantedKeys({ key }, state.desiredQuests[key] ~= true)
end

local function KeyForAbandoned(questId)
  questId = tonumber(questId) or 0

  if questId <= 0 then
    return nil
  end

  if RT.GetBoardQuest(questId) then
    return Core.questKey({ questId = questId })
  end

  local board = RT.GetBoard()
  local lists = { board and board.quests, state and state.knownQuests }

  for i = 1, 2 do
    local list = lists[i]

    if type(list) == "table" then
      for j = 1, #(list) do
        local quest = list[j]

        if type(quest) == "table" and tonumber(quest.questId or quest.id) == questId then
          return Core.questKey({ questId = questId })
        end
      end
    end
  end

  Log("quest", "abandoned quest is not a known contract id=", questId)

  return nil
end

local expectedAbandon = {}

local function WantedKeyOf(questId)
  local lists = { RT.GetBoard() and RT.GetBoard().quests, state and state.knownQuests }

  for i = 1, 2 do
    local list = lists[i]

    if type(list) == "table" then
      for j = 1, #(list) do
        local quest = list[j]

        if type(quest) == "table" and tonumber(quest.questId or quest.id) == questId then
          return Core.questIndexKey(quest)
        end
      end
    end
  end

  return Core.questKey({ questId = questId })
end

function RT.ExpectBoardAbandon(ids)
  expectedAbandon = {}

  for i = 1, #ids do
    expectedAbandon[ids[i]] = true
  end
end

local abandonLot

local function TitleOf(questId)
  local lists = { RT.GetBoard() and RT.GetBoard().quests, state and state.knownQuests }

  for i = 1, 2 do
    local list = lists[i]

    if type(list) == "table" then
      for j = 1, #(list) do
        local quest = list[j]

        if type(quest) == "table" and tonumber(quest.questId or quest.id) == questId then
          return quest.title
        end
      end
    end
  end

  return tostring(questId)
end

local function AbandonLotNext()
  local lot = abandonLot

  while lot and #lot.queue > 0 do
    local questId = table.remove(lot.queue, 1)

    if RT.FindQuestLogIndexByID(questId) then
      lot.pending = questId
      ProjectEbonhold.Callboard.Abandon(questId)
      Log("board", "lot abandon ", questId)

      return
    end
  end

  abandonLot = nil

  if lot and #lot.keys > 0 then
    RT.SetWantedKeys(lot.keys, false)
  end
end

function RT.OnBoardAbandonStep()
  local lot = abandonLot
  local questId = lot and lot.pending

  if not questId or RT.FindQuestLogIndexByID(questId) then
    return
  end

  local posted = RT.GetBoardQuest(questId)

  if posted and posted.state == Core.STATE.ACCEPTED then
    return
  end

  lot.pending = nil
  lot.keys[#lot.keys + 1] = WantedKeyOf(questId)
  AbandonLotNext()
end

function RT.AbandonBoardLot(ids, category)
  local confirm = EbonAPI and EbonAPI.QuestLogConfirm
  local callboard = ProjectEbonhold and ProjectEbonhold.Callboard

  if type(ids) ~= "table" or #ids == 0 or not confirm or not callboard or type(callboard.Abandon) ~= "function" then
    return false
  end

  local items, queue = {}, {}

  for i = 1, #ids do
    queue[i] = ids[i]
    items[i] = { questID = ids[i], title = TitleOf(ids[i]) }
  end

  confirm.open({
    count = #items,
    categories = { { title = RT.GetQuestCategoryName(category), quests = items } },
  }, function()
    abandonLot = { queue = queue, keys = {} }
    AbandonLotNext()
  end)

  return true
end

function RT.NoteQuestAbandoned(title, questId)
  local key = KeyForAbandoned(questId)

  if not key or excluded[key] then
    return
  end

  excluded[key] = true
  Log("quest", "abandoned contract left out until the reset key=", key)
end

local function SelectedQuest()
  local index = GetQuestLogSelection and RT.SafeCall(GetQuestLogSelection)
  local entry = tonumber(index) and index > 0 and RT.GetQuestLogEntryInfo(index)

  if not entry or entry.isHeader or not entry.questID then
    return nil
  end

  return { questId = entry.questID, title = entry.title }
end

function RT.InstallAbandonQuestHook()
  if RT.abandonQuestHooked or type(hooksecurefunc) ~= "function" then
    return
  end

  local function capture()
    if not GetAbandonQuestName then
      return
    end

    local ok, name = pcall(GetAbandonQuestName)
    if ok and type(name) == "string" and name ~= "" then
      RT.abandonQuestCandidate = name
      return name
    end
  end

  local setHooked = true

  if type(SetAbandonQuest) == "function" then
    setHooked = pcall(hooksecurefunc, "SetAbandonQuest", function()
      capture()
      RT.abandonQuestSelected = SelectedQuest()
    end)
  end

  if type(AbandonQuest) ~= "function" then
    return
  end

  local hooked = pcall(hooksecurefunc, "AbandonQuest", function()
    RT.api:Guard("abandon.hook", function()
      local name = capture()
      local selected = RT.abandonQuestSelected

      RT.NoteQuestAbandoned(RT.abandonQuestCandidate or (selected and selected.title), selected and selected.questId)

      local id = selected and tonumber(selected.questId)

      if id and expectedAbandon[id] then
        expectedAbandon[id] = nil
        RT.SetWantedKeys({ WantedKeyOf(id) }, false)
      end

      RT.abandonQuestCandidate = nil
      RT.abandonQuestSelected = nil
    end)
  end)

  RT.abandonQuestHooked = hooked

  if not hooked or not setHooked then
    RT.api:Degrade(RT.api:Problem("ROLL.ABANDON_HOOK_FAILED", { ["function"] = hooked and "SetAbandonQuest" or "AbandonQuest" }))
  else
    RT.api:Restore("ROLL.ABANDON_HOOK_FAILED")
  end

  if not hooked then
    Log("quest", "AbandonQuest hook refused, abandoned contracts may be taken again")
  end
end

function RT.GetBoardStatusText()
  local problem = RT.GetBoardProblem()

  if problem then
    return L[problem]
  end

  if not RT.IsBoardEnabled() then
    return L.STATUS_BOARD_DISABLED
  end

  local summary = RT.GetBoardSummary()
  local text

  if summary then
    text = string.format(L.STATUS_BOARD_SUMMARY, CountDesiredQuests(), summary.accepted, summary.claimable)

    if summary.resetIn then
      text = text .. string.format(L.STATUS_BOARD_RESET_SUFFIX, RT.FormatDuration(summary.resetIn))
    end
  else
    text = string.format(L.STATUS_BOARD_IDLE, CountDesiredQuests())
  end

  if statusKey then
    return StatusText() .. "  |  " .. text
  end

  return text
end

RT.CountDesiredQuests = CountDesiredQuests
RT.SetQuestStatus = SetQuestStatus
