local Actions = EbonAPI.Actions

local type, tostring = type, tostring

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local CLASS_TOKENS = {
  WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
  DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

local function playerClassId()
  local _, token = UnitClass("player")

  return CLASS_TOKENS[token] or 0
end

local function trialCheck(trial)
  if trial ~= 1 and trial ~= 3 then
    return "the trial must be 1 (Champion) or 3 (Crusader)"
  end
end

Actions.define({ name = "QueryTrialState", cs = "REQUEST_TRIAL_STATE", service = { "Trials", "RequestState" } })

Actions.define({
  name = "StartTrial", cs = "REQUEST_TRIAL_START", service = { "Trials", "Start" },
  check = trialCheck, body = function(trial) return tostring(trial) end,
})

Actions.define({ name = "RetryTrial", cs = "REQUEST_TRIAL_RETRY", service = { "Trials", "Retry" } })

Actions.define({ name = "LeaveTrial", cs = "REQUEST_TRIAL_LEAVE", service = { "Trials", "Leave" } })

Actions.define({
  name = "QueryTrialBoard", cs = "REQUEST_TRIAL_LEADERBOARD", service = { "Trials", "RequestBoard" },
  check = function(trial, classId)
    local bad = trialCheck(trial)

    if bad then
      return bad
    end

    if classId ~= nil and (not integer(classId) or classId < 0 or classId > 11) then
      return "the class id must be an integer from 0 to 11"
    end
  end,
  body = function(trial, classId)
    if trial == 1 then
      local id = classId or playerClassId()

      if id > 0 then
        return tostring(trial) .. "|" .. tostring(id)
      end
    end

    return tostring(trial)
  end,
})
