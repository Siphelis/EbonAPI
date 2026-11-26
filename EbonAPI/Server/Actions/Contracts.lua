local Actions = EbonAPI.Actions

local type = type

Actions.define({
  name = "RequestContracts", cs = "REQUEST_CONTRACTS", service = { "Contracts", "Request" },
})

Actions.define({
  name = "ActOnContract", cs = "REQUEST_CONTRACT_ACTION", service = { "Contracts", "Act" },
  check = function(key, action)
    if type(key) ~= "string" or key == "" or key:find(",", 1, true) then
      return "the contract key must be a non empty string without a comma"
    end

    if action ~= "accept" and action ~= "abandon" then
      return "the action must be accept or abandon"
    end
  end,
  body = function(key, action) return key .. "," .. action end,
})

Actions.define({
  name = "BankSoul", cs = "REQUEST_SOUL_BANK", service = { "Contracts", "Bank" },
})
