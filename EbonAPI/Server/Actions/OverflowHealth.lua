local Actions = EbonAPI.Actions

local type = type

Actions.define({
  name = "RequestOverflowHealth", cs = "REQUEST_OVERFLOW_HEALTH",
  check = function(guid)
    if type(guid) ~= "string" or not guid:match("^[0-9A-Fa-f]+$") and not guid:match("^0[xX][0-9A-Fa-f]+$") then
      return "the guid must be a hexadecimal string"
    end
  end,
  body = function(guid)
    local key = guid:upper()

    if key:sub(1, 2) == "0X" then
      key = key:sub(3)
    end

    return key
  end,
})
