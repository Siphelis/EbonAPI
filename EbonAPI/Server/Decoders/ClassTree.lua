
local EbonAPI = EbonAPI
local register = EbonAPI.Decoders.register

local function numbers(part)
  if string.find(part, "[^%d,%s;]") then return nil end

  local list, n = {}, 0

  for token in string.gmatch(part, "%d+") do
    n = n + 1
    list[n] = tonumber(token)
  end

  return list
end

register(1230, {
  name = "SEND_CLASS_TREE_DATA", family = "ClassTree", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    local bar = string.find(body, "|", 1, true)
    local ashesPart, ownedPart

    if bar then
      ashesPart, ownedPart = string.sub(body, 1, bar - 1), string.sub(body, bar + 1)
    else
      ashesPart, ownedPart = body, ""
    end

    local ashes, owned = numbers(ashesPart), numbers(ownedPart)

    if not ashes or not owned then return nil, "bad_token" end

    return { ashes = ashes, owned = owned }
  end,
})

register(1231, {
  name = "SEND_CLASS_NODE_RESULT", family = "ClassTree", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    local status, a, b = string.match(body, "^(%u+),([^,]*),?(.*)$")

    if status == "OK" then
      local nodeId = tonumber(a)

      if not nodeId then return nil, "bad_node" end

      return { ok = true, nodeId = nodeId, pool = tonumber(b) }
    elseif status == "FAIL" then
      return { ok = false, reason = a, nodeId = tonumber(b) }
    end

    return nil, "echo_or_unknown"
  end,
})

register(1232, {
  name = "SEND_CLASS_LEVEL_UP", family = "ClassTree", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    local classId, level, ashes = string.match(body, "^(%d+),(%d+),(%d+)")

    if not classId then return nil, "bad_format" end

    return { classId = tonumber(classId), level = tonumber(level), ashes = tonumber(ashes) }
  end,
})

register(1233, {
  name = "SEND_CLASS_TREE_PROGRESS", family = "ClassTree", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    local classId, ashes = string.match(body, "^(%d+),(%d+)")

    if not classId then return nil, "bad_format" end

    return { classId = tonumber(classId), ashes = tonumber(ashes) }
  end,
})
