local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime

local Log = RT.Log

local function NormalizeQuestTitle(title)
  title = Core.stripColorCodes(tostring(title or ""):lower())
  title = title:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  return title
end

function RT.GetQuestLogEntryInfo(index)
  if not GetQuestLogTitle then
    return nil
  end

  local title, _, _, _, isHeader, isCollapsed, isComplete, _, questID = GetQuestLogTitle(index)
  if not title then
    return nil
  end

  questID = tonumber(questID)
  if questID and questID <= 0 then
    questID = nil
  end

  return {
    title = title,
    isHeader = isHeader,
    isCollapsed = isCollapsed,
    isComplete = isComplete,
    questID = questID,
  }
end

function RT.FindQuestLogIndexByID(questID, preferredIndex)
  questID = tonumber(questID) or 0
  if questID <= 0 or not GetNumQuestLogEntries then
    return nil
  end

  if preferredIndex then
    local preferredEntry = RT.GetQuestLogEntryInfo(preferredIndex)
    if preferredEntry and not preferredEntry.isHeader and tonumber(preferredEntry.questID) == questID then
      return preferredIndex, preferredEntry
    end
  end

  for i = 1, GetNumQuestLogEntries() do
    local entry = RT.GetQuestLogEntryInfo(i)
    if entry and not entry.isHeader and tonumber(entry.questID) == questID then
      return i, entry
    end
  end

  return nil
end

function RT.QuestLogTitles()
  local titles = {}

  if not GetNumQuestLogEntries then
    return titles
  end

  for i = 1, GetNumQuestLogEntries() do
    local entry = RT.GetQuestLogEntryInfo(i)
    local questID = entry and not entry.isHeader and tonumber(entry.questID)

    if questID and questID > 0 and titles[questID] == nil then
      titles[questID] = entry.title or false
    end
  end

  return titles
end

function RT.QuestShareLabel(quest)
  if not quest then
    return L.QUEST_FALLBACK_LABEL
  end

  local questID = tonumber(quest.questID) or tonumber(quest.questId) or 0
  local title = tostring(quest.title or "")
  if title ~= "" and questID > 0 then
    return tostring(questID) .. " " .. title
  end

  if questID > 0 then
    return tostring(questID)
  end

  if title ~= "" then
    return title
  end

  return L.QUEST_FALLBACK_LABEL
end

function RT.ShareQuestLogIndex(index, quest, source)
  if not index then
    RT.api:Report(RT.api:Problem("SHARE.QUEST_NOT_IN_LOG", { quest = RT.QuestShareLabel(quest) }))
  elseif not SelectQuestLogEntry then
    RT.api:Report(RT.api:Problem("SHARE.UNAVAILABLE", { api = "SelectQuestLogEntry" }))
  end

  if not index or not SelectQuestLogEntry then
    Log("quest", "share blocked source=", source, " reason=missing SelectQuestLogEntry")
    return false, L.SHARE_LOG_UNAVAILABLE
  end

  if not QuestLogPushQuest then
    RT.api:Report(RT.api:Problem("SHARE.UNAVAILABLE", { api = "QuestLogPushQuest" }))
    Log("quest", "share blocked source=", source, " reason=missing QuestLogPushQuest")
    return false, L.SHARE_PUSH_UNAVAILABLE
  end

  local previousIndex = GetQuestLogSelection and GetQuestLogSelection() or nil
  SelectQuestLogEntry(index)

  if GetQuestLogPushable and not GetQuestLogPushable() then
    if previousIndex then
      SelectQuestLogEntry(previousIndex)
    end

    RT.api:Report(RT.api:Problem("SHARE.NOT_SHAREABLE", { quest = RT.QuestShareLabel(quest) }))
    Log("quest", "share skipped source=", source, " quest=", RT.QuestShareLabel(quest), " reason=not pushable")
    return false, string.format(L.SHARE_NOT_SHAREABLE, RT.QuestShareLabel(quest))
  end

  QuestLogPushQuest()

  if previousIndex then
    SelectQuestLogEntry(previousIndex)
  end

  Log("quest", "shared source=", source, " quest=", RT.QuestShareLabel(quest), " index=", index)
  return true
end

function RT.ShareAcceptedQuest(source)
  if not RT.lastAcceptedQuest then
    RT.api:Report(RT.api:Problem("SHARE.NO_ACCEPTED_QUEST"))
    Log("quest", "share skipped source=", source, " reason=no accepted quest")
    return false
  end

  local lastAcceptedQuest = RT.lastAcceptedQuest
  local index, entry = RT.FindQuestLogIndexByID(lastAcceptedQuest.questID, lastAcceptedQuest.questLogIndex)
  if entry and entry.title and entry.title ~= "" then
    lastAcceptedQuest.title = entry.title
  end

  if not index then
    RT.api:Report(RT.api:Problem("SHARE.QUEST_NOT_IN_LOG", { quest = RT.QuestShareLabel(lastAcceptedQuest) }))
    Log("quest", "share skipped source=", source, " quest=", RT.QuestShareLabel(lastAcceptedQuest), " reason=not in log yet")
    return false
  end

  local shared, message = RT.ShareQuestLogIndex(index, {
      questID = lastAcceptedQuest.questID,
      title = lastAcceptedQuest.title,
    }, source)

  if shared then
    RT.SetQuestStatus("SHARE_ACCEPTED_QUEST", RT.QuestShareLabel(lastAcceptedQuest))
  end

  return shared, message
end

function RT.TrackAcceptedQuest(arg1, arg2)
  local first = tonumber(arg1)
  local second = tonumber(arg2)
  local questLogIndex = second and first or nil
  local questID = second
  local entry

  if questLogIndex then
    entry = RT.GetQuestLogEntryInfo(questLogIndex)
  elseif first then
    local possibleEntry = RT.GetQuestLogEntryInfo(first)
    if possibleEntry and tonumber(possibleEntry.questID) and tonumber(possibleEntry.questID) ~= first then
      questLogIndex = first
      questID = tonumber(possibleEntry.questID)
      entry = possibleEntry
    else
      questID = first
    end
  end

  if (not questID or questID <= 0) and entry and tonumber(entry.questID) then
    questID = tonumber(entry.questID)
  end

  if not questID or questID <= 0 then
    RT.api:Reject("SHARE.ACCEPTED_QUEST_ID_UNKNOWN", { first = tostring(arg1), second = tostring(arg2) })
    Log("quest", "accepted quest id unavailable arg1=", arg1, " arg2=", arg2)
    RT.lastAcceptedQuest = nil
    RT.UpdateShareButtonState()
    return
  end

  RT.lastAcceptedQuest = {
    questID = questID,
    questLogIndex = questLogIndex,
    title = entry and entry.title or "",
    acceptedAt = GetTime(),
  }

  Log("quest", "accepted ", RT.QuestShareLabel(RT.lastAcceptedQuest), " index=", questLogIndex or "unknown")
  RT.UpdateShareButtonState()

  RT.HandleEternalQuest()
end

function RT.RefreshLastAcceptedQuest()
  local accepted = RT.lastAcceptedQuest
  if not accepted or accepted.title ~= "" then
    return
  end

  local index, entry = RT.FindQuestLogIndexByID(accepted.questID, accepted.questLogIndex)
  if not entry then
    return
  end

  accepted.questLogIndex = index
  accepted.title = entry.title or ""
end

function RT.GetQuestOfferTitle()
  if GetTitleText then
    local ok, value = pcall(GetTitleText)
    if ok and type(value) == "string" and value ~= "" then
      return value
    end
  end

  if QuestTitleText and QuestTitleText.GetText then
    return QuestTitleText:GetText() or ""
  end

  return ""
end

function RT.IsQuestOfferFromPlayer()
  return (RT.SafeCall(UnitIsPlayer, "questnpc") or RT.SafeCall(UnitIsUnit, "questnpc", "player")) and true or false
end

function RT.IsQuestOfferFromNpc()
  local guid = RT.SafeCall(UnitGUID, "questnpc") or RT.SafeCall(UnitGUID, "npc")

  return RT.ExtractBoardObjectIdFromGuid(guid) ~= nil
end

function RT.IsQuestOfferFromBoard()
  local guid = RT.SafeCall(UnitGUID, "questnpc") or RT.SafeCall(UnitGUID, "npc")

  return RT.IsKnownBoardObjectId(RT.ExtractBoardObjectIdFromGuid(guid)) == true
end

function RT.AcceptCurrentQuestOffer(source)
  if AcceptQuest then
    AcceptQuest()
  elseif QuestFrameAcceptButton then
    QuestFrameAcceptButton:Click()
  else
    RT.api:Report(RT.api:Problem("SHARE.ACCEPT_UNAVAILABLE"))
    Log("quest", "auto accept blocked source=", source, " reason=no accept API")
    return false
  end

  return true
end

RT.NormalizeQuestTitle = NormalizeQuestTitle
