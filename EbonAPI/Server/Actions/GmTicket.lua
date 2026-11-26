local Actions = EbonAPI.Actions

local type = type

local MAX_LENGTH = 1990

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

Actions.define({
  name = "CreateGmTicket", cs = "REQUEST_CREATE_GM_TICKET",
  service = { "CustomTicket", "Submit" },
  check = function(text)
    if type(text) ~= "string" or trim(text) == "" then
      return "the ticket text must be a non-empty string"
    end
  end,
  body = function(text)
    return trim(text):sub(1, MAX_LENGTH)
  end,
  why = function()
    return "ProjectEbonhold could not submit the ticket (comms not ready)"
  end,
})
