local Core = AutoCallboardCore
local RT = AutoCallboardRuntime

local API = AutoCallboardAPI or {}
AutoCallboardAPI = API

API.version = 1

function API.GetInstanceQuest(areaId, questType)
  local target = RT.BuildRequestedInstanceTarget(areaId, questType)
  local known = RT.state and RT.state.knownQuests

  if not target then
    RT.api:Reject("API.BAD_ARGUMENT", { areaId = tostring(areaId), questType = tostring(questType) })

    return nil
  end

  if type(known) ~= "table" then
    return nil
  end

  local found

  for i = 1, #(known) do
    local quest = known[i]

    if Core.questMatchesInstanceTarget(quest, target) then
      if RT.GetBoardQuest(quest.questId) then
        found = quest
        break
      end

      found = found or quest
    end
  end

  if not found then
    return nil
  end

  return tonumber(found.questId) or 0, Core.questTitle(found)
end

function API.SetRequestedInstance(areaId, questType, name)
  return RT.SetRequestedInstance(areaId, questType, name)
end

function API.ClearRequestedInstance()
  RT.SetRequestedInstance(nil)
end

function API.GetRequestedInstance()
  local request = RT.requestedInstance

  if not request then
    return nil
  end

  return request.areaId, request.questType, request.name
end
