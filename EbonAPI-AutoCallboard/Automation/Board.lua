local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local state = RT.state

local Log = RT.Log

local REQUEST_INTERVAL = 10
local RESET_MARGIN = 0.5

local board
local boardEnabled = true
local revision = 0
local reportedComplete = {}

function RT.GetBoardService()
  local Ebonhold = EbonAPI.Ebonhold

  if type(Ebonhold.Callboard) == "function" then
    return Ebonhold.Callboard()
  end

  return Ebonhold.Service("Callboard")
end

function RT.GetBoardProblem()
  if not RT.GetBoardService() then
    return "STATUS_BOARD_UNAVAILABLE"
  end

  if EbonAPI.State.CallboardProblem() then
    return "STATUS_BOARD_UNREADABLE"
  end

  return nil
end

function RT.IsBoardAvailable()
  return RT.GetBoardProblem() == nil
end

function RT.GetBoard()
  return board
end

function RT.IsBoardEnabled()
  return boardEnabled
end

function RT.GetBoardRevision()
  return revision
end

function RT.GetBoardQuest(questId)
  return board and board.byId[tonumber(questId) or 0] or nil
end

local function Send(name, ...)
  local service = RT.GetBoardService()

  if not service or type(service[name]) ~= "function" or not RT.IsBoardAvailable() then
    return false
  end

  service[name](...)

  return true
end

local lastRequestAt

function RT.RequestBoard(source, now)
  local at = GetTime()

  if not now and lastRequestAt and at - lastRequestAt < REQUEST_INTERVAL then
    return false
  end

  if not Send("Request") then
    return false
  end

  lastRequestAt = at
  Log("board", "board requested source=", source)

  return true
end

function RT.SendBoardAccept(questId)
  return Send("Accept", questId)
end

function RT.SendBoardClaim(questId)
  return Send("Claim", questId or 0)
end

local function ScheduleReset()
  local resetIn = Core.boardResetIn(board, GetTime())

  if not resetIn then
    RT.api:CancelAfter("boardReset")
    return
  end

  RT.api:After("boardReset", resetIn + RESET_MARGIN, function()
    Log("board", "board reset")
    RT.OnBoardReset()
    RT.RequestBoard("reset", true)
  end)
end

local function LearnBoard()
  local known, changed = Core.captureKnownQuests(state.knownQuests, board.quests, true)
  state.knownQuests = known

  if changed then
    RT.TouchState()
  end
end

local function ForgetReported()
  for questId in pairs(reportedComplete) do
    local quest = board and board.byId[questId]

    if not quest or quest.state ~= Core.STATE.ACCEPTED then
      reportedComplete[questId] = nil
    end
  end
end

local function OnBoard(_, received, problem)
  board = Core.boardView(received)
  boardEnabled = board ~= nil or problem ~= nil
  revision = revision + 1
  ForgetReported()

  Log("board", "board received contracts=", board and #(board.quests) or (problem and "not recognized") or "off",
    " claimable=", board and board.claimable or 0, problem and (" problem=" .. problem) or "")

  if board then
    LearnBoard()
  end

  ScheduleReset()
  RT.OnBoardChanged()
end

local function OnBoardResult(_, result)
  if type(result) ~= "table" then
    return
  end

  Log("board", "result op=", result.op, " ok=", tostring(result.ok), " reason=", tostring(result.reason),
    " quest=", tostring(result.questId))
  RT.OnBoardResult(result)
end

local PASS_DELAY = 0.3
local PASS_QUIET = 0.5
local PASS_EVERY = 5

local passing = false
local passPending = false
local passScheduled = false
local quietUntil = 0
local lastPassAt

local function IsOn(value)
  return value == 1 or value == true
end

local function CompleteInQuestLog()
  local complete, seen, collapsed = {}, {}, 0

  if not GetNumQuestLogEntries or not GetQuestLogTitle then
    return complete, seen, collapsed
  end

  for i = 1, GetNumQuestLogEntries() do
    local _, _, _, _, isHeader, isCollapsed, isComplete, _, questId = GetQuestLogTitle(i)

    if isHeader then
      if IsOn(isCollapsed) then
        collapsed = collapsed + 1
      end
    elseif tonumber(questId) then
      seen[tonumber(questId)] = true

      if IsOn(isComplete) then
        complete[tonumber(questId)] = true
      end
    end
  end

  return complete, seen, collapsed
end

local function ClaimReported(complete)
  for i = 1, #(board.accepted) do
    local questId = board.accepted[i].questId

    if not reportedComplete[questId] and complete[questId] then
      reportedComplete[questId] = RT.RequestBoard("contract complete") or nil
    end
  end
end

local function HeaderIndexes()
  local list = {}

  for i = 1, GetNumQuestLogEntries() do
    local _, _, _, _, isHeader = GetQuestLogTitle(i)

    if isHeader then
      list[#list + 1] = i
    end
  end

  return list
end

local function ReadWithHeadersOpen()
  local selectedId

  if GetQuestLogSelection then
    local selected = GetQuestLogSelection()

    if selected and selected > 0 then
      local _, _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(selected)
      selectedId = not isHeader and tonumber(questId) or nil
    end
  end

  local opened = {}
  local rank = 0
  local index = 1

  while index <= GetNumQuestLogEntries() do
    local _, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)

    if isHeader then
      rank = rank + 1

      if IsOn(isCollapsed) then
        opened[rank] = true
        ExpandQuestHeader(index)
      end
    end

    index = index + 1
  end

  local ok, complete = pcall(CompleteInQuestLog)

  local headers = HeaderIndexes()

  for position = #headers, 1, -1 do
    if opened[position] then
      CollapseQuestHeader(headers[position])
    end
  end

  if selectedId and SelectQuestLogEntry then
    for i = 1, GetNumQuestLogEntries() do
      local _, _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)

      if not isHeader and tonumber(questId) == selectedId then
        if GetQuestLogSelection() ~= i then
          SelectQuestLogEntry(i)
        end

        break
      end
    end
  end

  return ok and complete or nil
end

local function RunQuestPass()
  if not passPending or passing or not board then
    return
  end

  if InCombatLockdown() or (WorldMapFrame and WorldMapFrame:IsShown()) then
    return
  end

  local now = GetTime()

  if lastPassAt and now - lastPassAt < PASS_EVERY then
    return
  end

  lastPassAt = now
  passPending = false
  passing = true
  quietUntil = GetTime() + PASS_QUIET

  local ok, complete = pcall(ReadWithHeadersOpen)

  passing = false
  quietUntil = GetTime() + PASS_QUIET

  Log("board", "quest log pass headers open ok=", tostring(ok))

  if ok and complete then
    ClaimReported(complete)
  end
end

local function RequestQuestPass()
  passPending = true

  if not passScheduled then
    passScheduled = true

    RT.api:After("boardQuestPass", PASS_DELAY, function()
      passScheduled = false
      RunQuestPass()
    end)
  end
end

function RT.IsBoardQuestPassQuiet()
  return passing or GetTime() < quietUntil
end

function RT.ResumeBoardQuestPass()
  if passPending and not passScheduled then
    RunQuestPass()
  end
end

function RT.WatchBoardQuestLog()
  if not board or RT.IsBoardQuestPassQuiet() then
    return
  end

  local complete, seen, collapsed
  local hidden = false

  for i = 1, #(board.accepted) do
    local questId = board.accepted[i].questId

    if not reportedComplete[questId] then
      if not complete then
        complete, seen, collapsed = CompleteInQuestLog()
      end

      if complete[questId] then
        reportedComplete[questId] = RT.RequestBoard("contract complete") or nil
      elseif not seen[questId] then
        hidden = true
      end
    end
  end

  if hidden and collapsed and collapsed > 0 then
    RequestQuestPass()
  end
end

function RT.GetBoardSummary()
  if not board then
    return nil
  end

  return { accepted = #(board.accepted), claimable = board.claimable, resetIn = Core.boardResetIn(board, GetTime()) }
end

function RT.InitBoard()
  if RT.GetBoardProblem() == "STATUS_BOARD_UNAVAILABLE" then
    Log("board", "ProjectEbonhold has no Hero's Call Board")
    return
  end

  RT.api:On("SERVER_CALLBOARD", OnBoard)
  RT.api:On("SERVER_CALLBOARD_RESULT", OnBoardResult)
  RT.api:Tick("board", 0.25, function()
    RT.WatchBoard()
    RT.ResumeBoardQuestPass()
  end)
  RT.api:On("EBONHOLD_READY", function() RT.RequestBoard("login") end)
end
