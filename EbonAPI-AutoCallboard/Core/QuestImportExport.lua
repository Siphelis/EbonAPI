local Core = AutoCallboardCore or {}
AutoCallboardCore = Core

local type, tostring, pairs = type, tostring, pairs
local table = table

local byTitle = Core.byTitle

local function Report(name, facts)
  return Core.report(Core.problem(name, facts))
end

function Core.mergeKnownQuestLists(existing, incoming)
  local merged = Core.copyQuestList(existing)
  local indexByKey = {}

  for i = 1, #(merged) do
    indexByKey[merged[i].key] = i
  end

  local cleanIncoming = Core.copyQuestList(incoming)

  if type(incoming) == "table" and #(cleanIncoming) < #(incoming) then
    for i = 1, #(incoming) do
      if type(incoming[i]) == "table" and not Core.copyQuest(incoming[i]) then
        Report("QUESTCODE.KEY_MISSING", { title = tostring(incoming[i].title or "") })
      end
    end
  end

  for i = 1, #(cleanIncoming) do
    local quest = cleanIncoming[i]
    local existingIndex = indexByKey[quest.key]

    if existingIndex then
      merged[existingIndex] = Core.mergeQuest(merged[existingIndex], quest)
    else
      table.insert(merged, quest)
      indexByKey[quest.key] = #(merged)
    end
  end

  table.sort(merged, byTitle)

  return merged
end

function Core.questStateBackup(currentState)
  local state = Core.mergeState(currentState)

  return {
    schemaVersion = 1,
    knownQuests = state.knownQuests,
    desiredQuests = state.desiredQuests,
    characterProfiles = state.characterProfiles,
  }
end

function Core.restoreQuestState(savedState, questBackup)
  local state = Core.mergeState(savedState)

  if type(questBackup) ~= "table" then
    return state
  end

  local backup = Core.questStateBackup(questBackup)
  state.knownQuests = Core.mergeKnownQuestLists(backup.knownQuests, state.knownQuests)

  if not Core.hasDesiredQuests(state.desiredQuests) then
    state.desiredQuests = Core.copyDesiredMap(backup.desiredQuests)
  end

  local currentProfiles = Core.copyCharacterProfiles(state.characterProfiles)
  state.characterProfiles = Core.copyCharacterProfiles(backup.characterProfiles)
  for profileKey, profile in pairs(currentProfiles) do
    state.characterProfiles[profileKey] = Core.copyCharacterProfile(profile)
  end

  return state
end
