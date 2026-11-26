local Core = AutoCallboardCore
local RT = AutoCallboardRuntime

RT.state = RT.state or Core.defaultState()

function RT.TouchState()
  RT.stateRevision = (RT.stateRevision or 0) + 1
end

local state = RT.state

function RT.PersistState(nextState)
  local adopted = Core.adoptState(nextState)

  for key in pairs(state) do
    state[key] = nil
  end

  for key, value in pairs(adopted) do
    state[key] = value
  end

  EbonAPIAutoCallboardDB = state

  RT.stateRevision = (RT.stateRevision or 0) + 1
end

function RT.RepairKnownQuestState()
  if not state then
    return
  end

  local found = state.knownQuests

  if type(found) ~= "table" and found ~= nil then
    Core.repaired("QUESTS.REPAIRED", { field = "known", value = type(found), kept = 0 }, found)
  end

  if type(state.knownQuests) ~= "table" then
    state.knownQuests = {}
    RT.TouchState()
    return
  end

  state.knownQuests = Core.copyQuestList(state.knownQuests)
  RT.TouchState()
end
