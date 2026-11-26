
local type, tonumber = type, tonumber
local gmatch, gsub, sub = string.gmatch, string.gsub, string.sub

local function decodeCheckpoints(body)
  if type(body) ~= "string" then
    return nil, "not_a_string"
  end

  local discovered, dungeon = {}, {}

  for raw in gmatch(body, "([^;]+)") do
    local token = gsub(raw, "%s+", "")
    local viaGroup = sub(token, 1, 1) == "g"
    local id = tonumber(viaGroup and sub(token, 2) or token)

    if id then
      if viaGroup then
        dungeon[id] = true
      else
        discovered[id] = true
      end
    end
  end

  return { discovered = discovered, dungeon = dungeon }
end

EbonAPI.Decoders.register(800, { name = "SEND_CHECKPOINTS_DATA", family = "Checkpoints", mode = "event", decode = decodeCheckpoints })
