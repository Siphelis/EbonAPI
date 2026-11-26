local Actions = EbonAPI.Actions

local type, tostring = type, tostring

Actions.define({
  name = "UnlearnEcho", cs = "REQUEST_UNLEARN_SPELL_ECHOES", service = { "SpellUnlearnService", "RequestUnlearn" },
  check = function(spellId)
    if type(spellId) ~= "number" or spellId ~= spellId or spellId % 1 ~= 0 or spellId <= 0 then
      return "the spell id must be a positive integer"
    end
  end,
  body = function(spellId) return tostring(spellId) end,
})
