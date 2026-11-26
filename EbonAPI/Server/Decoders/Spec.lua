
local tonumber, type, sub, match, gmatch = tonumber, type, string.sub, string.match, string.gmatch

EbonAPI.Decoders.register(1300, {
  name = "SEND_SPEC_TALENTS", family = "Spec", mode = "event",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "empty"
    end

    local spec, list = match(body, "^(%d+)|(.*)$")

    if not spec then
      return nil, "no_spec"
    end

    local ranks, count = {}, 0

    for id, rank in gmatch(list, "(%d+):(%d+)") do
      id = tonumber(id)

      if ranks[id] == nil then
        count = count + 1
      end

      ranks[id] = tonumber(rank)
    end

    return { specIndex = tonumber(spec), ranks = ranks, count = count }
  end,
})

EbonAPI.Decoders.register(1301, {
  name = "SEND_TALENT_PLAN_RESULT", family = "Spec", mode = "event",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "empty"
    end

    local reason = match(body, "^FAIL,(%a+)")

    if reason then
      local id = match(body, "^FAIL,%a+,(%d+)")

      return { ok = false, reason = reason, talentId = tonumber(id) }
    end

    if body == "OK" or sub(body, 1, 3) == "OK," then
      return { ok = true }
    end

    return nil, "bad_result"
  end,
})
