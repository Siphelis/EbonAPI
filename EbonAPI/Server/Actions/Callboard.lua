local Actions = EbonAPI.Actions

local type, tostring = type, tostring

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

Actions.define({
  name = "RequestCallboard", cs = "REQUEST_CALLBOARD_DATA", service = { "Callboard", "Request" },
})

Actions.define({
  name = "AcceptCallboardQuest", cs = "REQUEST_CALLBOARD_ACCEPT", service = { "Callboard", "Accept" },
  check = function(questId)
    if not integer(questId) or questId <= 0 then
      return "the quest id must be a positive integer"
    end
  end,
  body = function(questId) return tostring(questId) end,
})

Actions.define({
  name = "ClaimCallboardQuest", cs = "REQUEST_CALLBOARD_CLAIM", service = { "Callboard", "Claim" },
  check = function(questId)
    if questId ~= nil and (not integer(questId) or questId < 0) then
      return "the quest id must be an integer of 0 or more (0 or nil = every finished quest)"
    end
  end,
  callArgs = function(questId) return questId or 0 end,
  body = function(questId) return tostring(questId or 0) end,
})

Actions.define({
  name = "ChooseCallboardStartZone", cs = "REQUEST_CALLBOARD_START_ZONE", service = { "Callboard", "ChooseStartZone" },
  check = function(zone)
    if not integer(zone) or zone < 1 or zone > 8 then
      return "the start zone must be an integer from 1 to 8"
    end
  end,
  body = function(zone) return tostring(zone) end,
})
