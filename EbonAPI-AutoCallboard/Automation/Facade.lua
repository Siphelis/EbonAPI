local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local state = RT.state


function RT.IsWanted(key)
  return type(key) == "string" and state.desiredQuests[key] == true
end

function RT.SetWanted(key, wanted)
  return RT.SetWantedKeys({ key }, wanted)
end

function RT.GetWantedState(keys)
  local total, wanted = 0, 0

  if type(keys) == "table" then
    for i = 1, #(keys) do
      total = total + 1

      if RT.IsWanted(keys[i]) then
        wanted = wanted + 1
      end
    end
  end

  if wanted == 0 then
    return "none"
  end

  return wanted == total and "all" or "some"
end

function RT.GetKnownOffBoard(category)
  local known = state.knownQuests
  local board = RT.GetBoard()
  local list = {}

  category = tonumber(category)

  if type(known) ~= "table" or not category then
    return list
  end

  for i = 1, #(known) do
    local quest = known[i]

    if Core.displayCategory(quest) == category then
      local posted = board and board.byId[tonumber(quest.questId) or 0]

      if not posted or posted.state == Core.STATE.EXHAUSTED then
        list[#(list) + 1] = quest
      end
    end
  end

  table.sort(list, Core.byTitle)

  return list
end

function RT.LoadCollection(id)
  local selection = RT.noneSelectionEntry

  if id ~= nil then
    selection = Core.findSelection(RT.GetAccountProfile(), id)

    if not selection or RT.IsSelectionDifficultyLocked(selection) then
      return false
    end
  end

  RT.LoadSelectionPreset(selection)

  return true
end

local PLACE_STOPS = { far = true, dead = true }

function RT.CanActAtBoard()
  if RT.GetBoardProblem() or PLACE_STOPS[RT.GetBoardStop()] then
    return nil
  end

  return RT.GetBoardAccess()
end
