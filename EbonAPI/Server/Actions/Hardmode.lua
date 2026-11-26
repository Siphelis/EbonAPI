local Actions = EbonAPI.Actions

local type = type
local tostring = tostring

local function ladderTop()
  local pe = _G.ProjectEbonhold

  if type(pe) == "table" and type(pe.TormentTierData) == "table" then
    return #pe.TormentTierData
  end
end

Actions.define({
  name = "RequestHardmodeData", cs = "REQUEST_HARDMODE_DATA",
  service = { "HardmodeService", "RequestHardmodeData" },
})

Actions.define({
  name = "SetDifficultyTier", cs = "REQUEST_HARDMODE_SET_DIFFICULTY",
  service = { "HardmodeService", "SetDifficulty" },
  check = function(tier)
    if type(tier) ~= "number" or tier ~= tier or tier % 1 ~= 0 or tier < 1 then
      return "the tier must be an integer from 1 (Normal)"
    end

    local top = ladderTop()

    if top and tier > top then
      return "the tier is above the top of the ladder (" .. tostring(top) .. ")"
    end
  end,
  body = function(tier)
    return tostring(tier)
  end,
})
