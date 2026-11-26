local Actions = EbonAPI.Actions

local type, tostring = type, tostring

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function ladderTop()
  local pe = _G.ProjectEbonhold
  local top = type(pe) == "table" and pe.TormentLadderTop

  return integer(top) and top or 11
end

Actions.define({ name = "QueryTormentData", cs = "REQUEST_LFG_TORMENT_DATA" })

Actions.define({
  name = "SetFinderTier", cs = "REQUEST_LFG_TORMENT_SET",
  check = function(tier)
    if not integer(tier) or tier < 1 or tier > ladderTop() then
      return "the tier must be an integer from 1 (Normal) to " .. ladderTop()
    end
  end,
  body = function(tier) return tostring(tier) end,
})

Actions.define({
  name = "SetFinderMode", cs = "REQUEST_LFG_MODE_SET",
  check = function(mode)
    if mode ~= 0 and mode ~= 1 then
      return "the mode must be 0 (Group) or 1 (Solo)"
    end
  end,
  body = function(mode) return tostring(mode) end,
})
