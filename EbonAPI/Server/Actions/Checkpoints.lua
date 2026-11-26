local Actions = EbonAPI.Actions

local type = type
local tostring = tostring

local function positive(value)
  return type(value) == "number" and value == value and value % 1 == 0 and value > 0
end

Actions.define({
  name = "RequestCheckpoints", cs = "REQUEST_CHECKPOINTS_DATA",
  service = { "CheckpointService", "RequestCheckpoints" },
})

Actions.define({
  name = "UseCheckpoint", cs = "REQUEST_USE_CHECKPOINT",
  service = { "CheckpointService", "UseCheckpoint" },
  check = function(checkpointId)
    if not positive(checkpointId) then
      return "the checkpoint id must be a positive integer"
    end
  end,
  body = function(checkpointId)
    return tostring(checkpointId)
  end,
})

Actions.define({ name = "CancelCheckpoint", cs = "REQUEST_CANCEL_CHECKPOINT" })
