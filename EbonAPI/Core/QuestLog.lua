EbonAPI = EbonAPI or {}
EbonAPI.QuestLog = { TIMEOUT = 3, FOLD_AT = 10 }

local QuestLog = EbonAPI.QuestLog
local Lib = EbonAPI.Lib
local Bus = EbonAPI.Bus
local Handle = EbonAPI.Handle

local type, pairs, ipairs, next, pcall, tostring = type, pairs, ipairs, next, pcall, tostring
local sort = table.sort

local WAIT_ID = "EbonAPI.QuestLog.wait"

local Problems = EbonAPI.Problems

Problems.declare("EbonAPI", "EBONAPI", {
  ["QUESTLOG.ABANDON_BUSY"] = { class = "refus" },
  ["QUESTLOG.ABANDON_EMPTY"] = { class = "refus" },
  ["QUESTLOG.ABANDON_UNCONFIRMED"] = { class = "refus" },
  ["QUESTLOG.ABANDON_MISSING"] = { class = "refus" },
  ["QUESTLOG.ABANDON_NOT_STARTED"] = { class = "refus" },
})

-- The quest log of the game is read and driven here, never by name: a quest is its questID (9th return of
-- GetQuestLogTitle), a category is its rank (n-th header of a reading). Titles are only displayed.

local checked = {}
local expected = {}
local turnedIn = {}
local run = nil

QuestLog.last = nil
QuestLog.count = nil
QuestLog.reading = false
QuestLog.dialog = nil
QuestLog.onChange = nil

local function changed()
  local fn = QuestLog.onChange

  if type(fn) == "function" then
    Lib.safeCall(fn)
  end
end

local function total()
  if type(GetNumQuestLogEntries) ~= "function" then
    return 0, 0
  end

  local entries, quests = GetNumQuestLogEntries()

  return entries or 0, quests or 0
end

local function indexOf(questID)
  for index = 1, (total()) do
    local _, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(index)

    if not isHeader and id == questID then
      return index
    end
  end

  return nil
end

local function selectedID()
  local selection = GetQuestLogSelection and GetQuestLogSelection() or 0

  if selection and selection > 0 then
    local _, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(selection)

    if not isHeader then
      return id
    end
  end

  return nil
end

local function reselect(questID)
  local index = questID and indexOf(questID)

  if index then
    SelectQuestLogEntry(index)
  end
end

local function expandCollapsed()
  local collapsed = {}

  for index = 1, (total()) do
    local _, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)

    if isHeader and isCollapsed then
      collapsed[#collapsed + 1] = index
    end
  end

  for position = #collapsed, 1, -1 do
    ExpandQuestHeader(collapsed[position])
  end
end

local function readOpen()
  local categories = {}
  local current = { rank = 0, title = "", collapsed = false, quests = {} }
  local rank = 0

  for index = 1, (total()) do
    local title, level, _, _, isHeader, _, isComplete, isDaily, questID = GetQuestLogTitle(index)

    if isHeader then
      if current.rank > 0 or #current.quests > 0 then
        categories[#categories + 1] = current
      end

      rank = rank + 1
      current = { rank = rank, title = title or "", collapsed = false, quests = {} }
    elseif questID then
      current.quests[#current.quests + 1] = {
        questID = questID,
        title = title or "",
        level = level,
        complete = (isComplete and isComplete > 0) and true or false,
        daily = isDaily and true or false,
      }
    end
  end

  if current.rank > 0 or #current.quests > 0 then
    categories[#categories + 1] = current
  end

  return categories
end

-- Collapsed state of every category, by rank (1 = first header).
local function collapsedRanks()
  local wasCollapsed, rank = {}, 0

  for index = 1, (total()) do
    local _, _, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)

    if isHeader then
      rank = rank + 1
      wasCollapsed[rank] = isCollapsed and true or false
    end
  end

  return wasCollapsed
end

-- Closes again the categories that were collapsed, by rank, from the bottom up.
local function recollapse(wasCollapsed)
  local headers = {}

  for index = 1, (total()) do
    local _, _, _, _, isHeader = GetQuestLogTitle(index)

    if isHeader then
      headers[#headers + 1] = index
    end
  end

  for position = #headers, 1, -1 do
    if wasCollapsed[position] then
      CollapseQuestHeader(headers[position])
    end
  end
end

-- Reads the whole log, collapsed categories included: they are opened, read, then closed again by rank,
-- from the bottom up. While it runs, `reading` keeps the decoration of the log from reading again.
function QuestLog.read()
  if QuestLog.reading then
    return QuestLog.last or {}
  end

  QuestLog.reading = true

  local ok, result = pcall(function()
    local selected = selectedID()
    local wasCollapsed = collapsedRanks()

    expandCollapsed()

    local categories = readOpen()

    for _, category in ipairs(categories) do
      category.collapsed = wasCollapsed[category.rank] or false
    end

    recollapse(wasCollapsed)
    reselect(selected)

    return categories
  end)

  if not ok then
    QuestLog.reading = false
    Problems.bug("EbonAPI", "questlog.read", tostring(result))

    return QuestLog.last or {}
  end

  local present = {}

  for _, category in ipairs(result) do
    for _, quest in ipairs(category.quests) do
      present[quest.questID] = true
    end
  end

  for questID in pairs(checked) do
    if not present[questID] then
      checked[questID] = nil
    end
  end

  QuestLog.last = result
  QuestLog.reading = false
  QuestLog.count = select(2, total())

  return result
end

local function onQuestLogUpdate()
  if not QuestLog.reading then
    QuestLog.last = nil
  end
end

Bus.on("QUEST_LOG_UPDATE", onQuestLogUpdate)

local function known()
  return QuestLog.last or QuestLog.read()
end

local function presentSet()
  local present = {}

  for _, category in ipairs(known()) do
    for _, quest in ipairs(category.quests) do
      present[quest.questID] = quest
    end
  end

  return present
end

function QuestLog.isChecked(questID)
  return checked[questID] == true
end

function QuestLog.checkedList()
  local list = {}

  for _, category in ipairs(known()) do
    for _, quest in ipairs(category.quests) do
      if checked[quest.questID] then
        list[#list + 1] = quest.questID
      end
    end
  end

  return list
end

function QuestLog.check(ids, on)
  local present = presentSet()

  for _, questID in ipairs(ids or {}) do
    if present[questID] then
      checked[questID] = (on ~= false) and true or nil
    end
  end

  changed()
end

function QuestLog.clear()
  for questID in pairs(checked) do
    checked[questID] = nil
  end

  changed()
end

function QuestLog.isAbandoning()
  return run ~= nil
end

function QuestLog.progress()
  if not run then
    return nil
  end

  return run.pos, #run.ids
end

local function collapseAgain(r)
  local headerOf, current = {}, nil

  for index = 1, (total()) do
    local _, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)

    if isHeader then
      current = index
    elseif questID and current then
      headerOf[questID] = current
    end
  end

  local seen, targets = {}, {}

  for _, ids in ipairs(r.collapsed) do
    for _, questID in ipairs(ids) do
      local header = headerOf[questID]

      if header then
        if not seen[header] then
          seen[header] = true
          targets[#targets + 1] = header
        end

        break
      end
    end
  end

  sort(targets, function(a, b)
    return a > b
  end)

  for _, header in ipairs(targets) do
    CollapseQuestHeader(header)
  end
end

local function updateBoard()
  Lib.safeCall(function()
    EbonAPI.Actions.RequestCallboard()
  end)
end

local function signal(code, facts)
  Problems.report(Problems.new("EbonAPI", code, facts))
end

local function refuse(reason)
  signal(reason == "busy" and "QUESTLOG.ABANDON_BUSY" or "QUESTLOG.ABANDON_EMPTY")

  return false, reason
end

local function hasCollapsed(ranks)
  for _, collapsed in pairs(ranks) do
    if collapsed then
      return true
    end
  end

  return false
end

local function stillListed(questID, entry, force)
  if indexOf(questID) then
    return true
  end

  local wasCollapsed = collapsedRanks()

  if not hasCollapsed(wasCollapsed) then
    return false
  end

  local entries, quests = total()
  local signature = entries .. ":" .. quests

  if not force and entry.hidden == signature then
    return nil
  end

  local wasReading = QuestLog.reading
  QuestLog.reading = true

  local selected = selectedID()
  local ok, found = pcall(function()
    expandCollapsed()

    return indexOf(questID) ~= nil
  end)

  Lib.safeCall(recollapse, wasCollapsed)
  Lib.safeCall(reselect, selected)
  QuestLog.reading = wasReading

  if not ok then
    Problems.bug("EbonAPI", "questlog.presence", tostring(found))

    return nil
  end

  if found then
    entry.hidden = signature
  end

  return found
end

local function finish()
  local r = run

  run = nil

  Lib.safeCall(collapseAgain, r)
  Lib.safeCall(reselect, r.selected)

  if #r.abandoned > 0 then
    PlaySound("igQuestLogAbandonQuest")
    updateBoard()
  end

  QuestLog.read()
  EbonAPI:Emit("QUESTS_ABANDON_DONE", r.abandoned, r.failed)
  changed()
end

local advance, onLogUpdate

local function waitId(questID)
  return WAIT_ID .. "." .. questID
end

local function resolve(questID, gone)
  local entry = expected[questID]

  if not entry then
    return
  end

  Bus.untick(waitId(questID))

  if gone then
    expected[questID] = nil

    if not next(expected) then
      Bus.off("QUEST_LOG_UPDATE", onLogUpdate)
    end
  else
    entry.late = true
  end

  local r = run
  local batched = r ~= nil and r.waiting == questID
  local handedIn = gone and turnedIn[questID] == true

  if gone then
    turnedIn[questID] = nil
  end

  if batched then
    r.waiting = nil

    if not handedIn then
      local list = gone and r.abandoned or r.failed
      list[#list + 1] = questID
    end
  end

  if gone then
    checked[questID] = nil
    QuestLog.last = nil

    if not handedIn then
      EbonAPI:Emit("QUEST_ABANDONED", questID, entry.title)
    end
  else
    signal("QUESTLOG.ABANDON_UNCONFIRMED", { quest = entry.title })
  end

  if batched then
    advance()
  elseif gone then
    updateBoard()
    changed()
  end
end

onLogUpdate = function()
  if QuestLog.reading then
    return
  end

  local pending = {}

  for questID in pairs(expected) do
    pending[#pending + 1] = questID
  end

  for _, questID in ipairs(pending) do
    local entry = expected[questID]

    if entry and stillListed(questID, entry, false) == false then
      resolve(questID, true)
    end
  end
end

local function expire(questID)
  local entry = expected[questID]

  if entry then
    resolve(questID, stillListed(questID, entry, true) == false)
  end
end

local function expect(questID, title)
  turnedIn[questID] = nil
  expected[questID] = { title = run and run.titles[questID] or title or "" }

  Bus.on("QUEST_LOG_UPDATE", onLogUpdate)
  Bus.after(waitId(questID), QuestLog.TIMEOUT, function()
    expire(questID)
  end)
end

Bus.on("QUEST_TURNED_IN", function(questID)
  if type(questID) == "number" then
    turnedIn[questID] = true
  end
end)

if type(hooksecurefunc) == "function" and type(GetQuestReward) == "function" then
  hooksecurefunc("GetQuestReward", function()
    local questID = selectedID()

    if questID then
      turnedIn[questID] = true
    end
  end)
end

local function hookAbandon()
  local nativeSet, nativeAbandon = SetAbandonQuest, AbandonQuest

  if type(nativeSet) ~= "function" or type(nativeAbandon) ~= "function" then
    Problems.bug("EbonAPI", "questlog.hook", "SetAbandonQuest or AbandonQuest is missing")

    return
  end

  local targetID, targetTitle = nil, nil

  local function retain()
    targetID, targetTitle = selectedID(), nil

    if targetID then
      targetTitle = GetQuestLogTitle(GetQuestLogSelection())
    end
  end

  local function register()
    local questID, title = targetID, targetTitle

    targetID, targetTitle = nil, nil

    if questID then
      expect(questID, title)
    end
  end

  SetAbandonQuest = function(...)
    Lib.safeCall(retain)

    return nativeSet(...)
  end

  AbandonQuest = function(...)
    Lib.safeCall(register)

    return nativeAbandon(...)
  end
end

hookAbandon()

advance = function()
  local r = run

  if not r or r.waiting then
    return
  end

  while run == r and r.pos < #r.ids do
    r.pos = r.pos + 1
    changed()

    if run ~= r then
      return
    end

    local questID = r.ids[r.pos]
    local index = indexOf(questID)

    if not index then
      expandCollapsed()
      index = indexOf(questID)
    end

    if index then
      r.waiting = questID
      SelectQuestLogEntry(index)
      SetAbandonQuest()
      AbandonQuest()

      if run ~= r or r.waiting ~= questID or (expected[questID] and not expected[questID].late) then
        return
      end

      r.waiting = nil
      r.failed[#r.failed + 1] = questID
      signal("QUESTLOG.ABANDON_NOT_STARTED", { quest = r.titles[questID] or "" })
    else
      signal("QUESTLOG.ABANDON_MISSING", { quest = r.titles[questID] or "" })
    end
  end

  if run == r then
    finish()
  end
end

function QuestLog.cancelAbandon()
  if not run then
    return false
  end

  run.waiting = nil
  finish()

  return true
end

local function start(ids, titles)
  if run then
    return refuse("busy")
  end

  local selected = selectedID()
  local categories = QuestLog.read()
  local collapsed = {}

  for _, category in ipairs(categories) do
    if category.collapsed then
      local ids = {}

      for _, quest in ipairs(category.quests) do
        ids[#ids + 1] = quest.questID
      end

      collapsed[#collapsed + 1] = ids
    end
  end

  run = { ids = ids, titles = titles, pos = 0, abandoned = {}, failed = {}, selected = selected, collapsed = collapsed }

  expandCollapsed()
  changed()
  advance()

  return true
end

-- Sum of the "a/b" numbers of the objectives of a quest, or nil when it has none (a number is looked for, never a word).
local function progressOf(index)
  if type(GetNumQuestLeaderBoards) ~= "function" or type(GetQuestLogLeaderBoard) ~= "function" then
    return nil
  end

  local have, need, found = 0, 0, false

  for objective = 1, (GetNumQuestLeaderBoards(index) or 0) do
    local text = GetQuestLogLeaderBoard(objective, index)
    local a, b = tostring(text or ""):match("(%d+)/(%d+)")

    if a then
      have, need, found = have + a, need + b, true
    end
  end

  return found and { have, need } or nil
end

-- What the confirmation shows about one quest, read while its category is open.
local function readQuest(quest)
  local index = indexOf(quest.questID)
  local item = { questID = quest.questID, title = quest.title, level = quest.level, done = quest.complete }

  if not index then
    return item
  end

  local _, level, _, _, _, _, isComplete = GetQuestLogTitle(index)

  item.level = level or item.level
  item.done = (isComplete and isComplete > 0) and true or false
  item.failed = (isComplete and isComplete < 0) and true or false
  item.progress = (not item.done and not item.failed) and progressOf(index) or nil

  SelectQuestLogEntry(index)
  SetAbandonQuest()

  item.items = GetAbandonQuestItems() or nil

  return item
end

-- The checked quests by category, in the order of the log. With `deep`, each quest is read in the log itself.
local function confirmModel(wanted, deep)
  local wantedSet, categories = {}, {}

  for _, questID in ipairs(wanted) do
    wantedSet[questID] = true
  end

  for _, category in ipairs(known()) do
    local quests = {}

    for _, quest in ipairs(category.quests) do
      if wantedSet[quest.questID] then
        quests[#quests + 1] = deep and readQuest(quest) or {
          questID = quest.questID, title = quest.title, level = quest.level, done = quest.complete,
        }
      end
    end

    if #quests > 0 then
      categories[#categories + 1] = { rank = category.rank, title = category.title, quests = quests }
    end
  end

  return { count = #wanted, categories = categories }
end

function QuestLog.abandon(ids, skipConfirm)
  if run then
    return refuse("busy")
  end

  local present = presentSet()
  local wanted, titles, seen = {}, {}, {}

  for _, questID in ipairs(ids or {}) do
    local quest = present[questID]

    if quest and not seen[questID] then
      seen[questID] = true
      wanted[#wanted + 1] = questID
      titles[questID] = quest.title
    end
  end

  if #wanted == 0 then
    return refuse("empty")
  end

  if skipConfirm then
    return start(wanted, titles)
  end

  local model

  -- Every checked quest is read, those of collapsed categories too: they are opened, then closed again.
  if QuestLog.reading then
    model = confirmModel(wanted, false)
  else
    QuestLog.reading = true

    local selected = selectedID()
    local wasCollapsed = collapsedRanks()

    Lib.safeCall(function()
      expandCollapsed()
      model = confirmModel(wanted, true)
    end)

    Lib.safeCall(function()
      recollapse(wasCollapsed)
    end)

    reselect(selected)
    QuestLog.reading = false
    model = model or confirmModel(wanted, false)
  end

  QuestLog.dialog = EbonAPI.QuestLogConfirm.open(model, function()
    start(wanted, titles)
  end)

  return true, nil
end

function Handle:QuestLog()
  return QuestLog.read()
end

function Handle:CheckedQuests()
  return QuestLog.checkedList()
end

function Handle:CheckQuests(ids, on)
  QuestLog.check(ids, on)
end

function Handle:IsAbandoning()
  return QuestLog.isAbandoning()
end

function Handle:AbandonQuests(ids, skipConfirm)
  return QuestLog.abandon(ids, skipConfirm)
end

function Handle:CancelAbandon()
  return QuestLog.cancelAbandon()
end
