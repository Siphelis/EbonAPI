
local tonumber, type = tonumber, type

local function notString(body)
  if type(body) ~= "string" then
    return "body is not a string"
  end
end

EbonAPI.Decoders.register(500, {
  name = "SEND_HARDMODE_DATA", family = "Hardmode",
  mode = "state",
  decode = function(body)
    local bad = notString(body)

    if bad then return nil, bad end
    if body == "" then return nil, "empty body (ignored by PE)" end

    return { tier = tonumber(body) or 1 }
  end,
})

EbonAPI.Decoders.register(501, {
  name = "SEND_HARDMODE_SET_RESULT", family = "Hardmode", mode = "event",
  decode = function(body)
    local bad = notString(body)

    if bad then return nil, bad end
    if body == "" then return nil, "empty body (ignored by PE)" end

    local status, payload = body:match("^(%a+),(.+)$")

    if status == "OK" then
      return { ok = true, tier = tonumber(payload) or 1 }
    end

    return { ok = false, reason = payload }
  end,
})

EbonAPI.Decoders.register(502, {
  name = "SEND_HARDCORE_TIER_UNLOCKED", family = "Hardmode", mode = "event",
  decode = function(body)
    local bad = notString(body)

    if bad then return nil, bad end
    if body == "" then return nil, "empty body (ignored by PE)" end

    local ranks = {}

    for rank in string.gmatch(body, "%d+") do
      ranks[#ranks + 1] = tonumber(rank)
    end

    if #ranks == 0 then return nil, "no rank (ignored by PE)" end

    return { ranks = ranks }
  end,
})

EbonAPI.Decoders.register(503, {
  name = "SEND_INSTANCE_TORMENT", family = "Hardmode", mode = "event",
  decode = function(body)
    local bad = notString(body)

    if bad then return nil, bad end

    local tier = tonumber(body) or 0

    return { tier = tier, foreign = tier > 0 }
  end,
})

EbonAPI.Decoders.register(504, {
  name = "SEND_HARDMODE_GM_STATE", family = "Hardmode", mode = "event",
  decode = function(body)
    local bad = notString(body)

    if bad then return nil, bad end

    return { state = tonumber(body) or 0 }
  end,
})
