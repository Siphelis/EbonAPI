
local tonumber, type, ipairs, match = tonumber, type, ipairs, string.match
local MODE_SOLO = 1

local split = EbonAPI.Decoders.split

local function anyNumber(f, last)
  for i = 1, last do
    if tonumber(f[i]) then
      return true
    end
  end

  return false
end

EbonAPI.Decoders.register(1250, {
  name = "SEND_LFG_TORMENT_DATA", family = "DungeonFinder", mode = "event",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "empty"
    end

    local f = split(body, "|")

    if not anyNumber(f, 7) then
      return nil, "no_number"
    end

    return {
      selected = tonumber(f[1]) or 1,
      maxQueueable = tonumber(f[2]) or 1,
      maxTier = tonumber(f[3]),
      minGroupSize = tonumber(f[4]) or 2,
      firstRunDone = f[5] == "1",
      release = tonumber(f[6]),
      mode = tonumber(f[7]) or MODE_SOLO,
      weeklyCacheDone = f[8] == "1",
      weeklyResetIn = tonumber(f[9]) or 0,
    }
  end,
})

EbonAPI.Decoders.register(1251, {
  name = "SEND_LFG_TORMENT_RESULT", family = "DungeonFinder", mode = "event",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "empty"
    end

    local status, payload = match(body, "^(%a+),(.*)$")

    if not status then
      if match(body, "^%d+$") then
        return nil, "echo"
      end

      return nil, "no_status"
    end

    if status == "OK" then
      return { ok = true, status = status, tier = tonumber(payload) }
    end

    return { ok = false, status = status, reason = payload }
  end,
})

EbonAPI.Decoders.register(1252, {
  name = "SEND_LFG_QUEUE_STATE", family = "DungeonFinder", mode = "event",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "empty"
    end

    local f = split(body, "|")

    if not anyNumber(f, 7) then
      return nil, "no_number"
    end

    return {
      players = tonumber(f[1]) or 0,
      secondsLeft = tonumber(f[2]) or -1,
      min = tonumber(f[3]),
      max = tonumber(f[4]),
      proposed = f[5] == "1",
      tier = tonumber(f[6]) or 1,
      mode = tonumber(f[7]) or MODE_SOLO,
    }
  end,
})

EbonAPI.Decoders.register(1268, {
  name = "SEND_LFG_TIER_COUNTS", family = "DungeonFinder", mode = "state",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "empty"
    end

    local waiting = {}

    for tier, count in ipairs(split(body, "|")) do
      waiting[tier] = tonumber(count) or 0
    end

    return { waiting = waiting }
  end,
})
