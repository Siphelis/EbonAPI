local Actions = EbonAPI.Actions

local type = type

Actions.define({ name = "RequestXpAuraState", cs = "REQUEST_XP_AURA_BONUS_STATE" })

Actions.define({
  name = "SetXpAuraBonus", cs = "REQUEST_XP_AURA_BONUS_SET",
  check = function(enabled)
    if type(enabled) ~= "boolean" then
      return "enabled must be a boolean"
    end
  end,
  body = function(enabled)
    return enabled and "0" or "1"
  end,
})
