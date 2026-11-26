
local EbonAPI = EbonAPI
local register = EbonAPI.Decoders.register

register(1200, {
  name = "SEND_PRESTIGE_DATA", family = "Prestige", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end
    if body == "" then return nil, "empty" end

    local t, c, b, s, e = string.match(body, "^(%d+);(%d+);([%d%.%-]+);(%d+);(%d+)$")

    if t then
      return { form = "A", totalPrestiges = tonumber(t), committedSoulAshes = tonumber(c),
               prestigeBonusPct = tonumber(b), soulShards = tonumber(s), essenceFromShards = tonumber(e) }
    end

    t, c, b = string.match(body, "^(%d+);(%d+);([%d%.%-]+)$")

    if t then
      return { form = "B", totalPrestiges = tonumber(t), committedSoulAshes = tonumber(c), prestigeBonusPct = tonumber(b) }
    end

    t, c = string.match(body, "^(%d+);(%d+)$")

    if t then
      return { form = "C", totalPrestiges = tonumber(t), committedSoulAshes = tonumber(c) }
    end

    t = string.match(body, "^(%d+)$")

    if t then return { form = "D", totalPrestiges = tonumber(t) } end

    return nil, "bad_form"
  end,
})

register(1201, {
  name = "SEND_PRESTIGE_RESULT", family = "Prestige", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end
    if body == "" then return nil, "empty" end

    local status, payload = string.match(body, "^(%a+),(.*)$")

    if status == "OK" then
      local total = tonumber(payload)

      if not total then return nil, "bad_total" end

      return { ok = true, totalPrestiges = total }
    elseif status == "FAIL" then
      return { ok = false, reason = payload }
    end

    return nil, "bad_status"
  end,
})

register(1210, {
  name = "SEND_XP_AURA_BONUS_STATE", family = "Prestige", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    return { bonusesOff = (body == "1") }
  end,
})
