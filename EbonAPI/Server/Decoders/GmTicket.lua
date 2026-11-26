
local type, tonumber = type, tonumber
local match = string.match

local function decodeResult(body)
  if type(body) ~= "string" then
    return nil, "not_a_string"
  end

  local status, detail = match(body, "^([^,]+),?(.*)$")

  if not status then
    return nil, "bad_format"
  end

  local value = { ok = status == "OK", status = status }

  if value.ok then
    value.ticketId = tonumber(detail)
  else
    value.reason = detail ~= "" and detail or status
  end

  return value
end

EbonAPI.Decoders.register(520, { name = "SEND_GM_TICKET_CREATE_RESULT", family = "GmTicket", mode = "event", decode = decodeResult })
