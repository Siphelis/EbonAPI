
local Decoders = EbonAPI.Decoders

local tonumber, type = tonumber, type
local sub, gmatch = string.sub, string.gmatch

local split = Decoders.split

Decoders.register(9, {
  name = "SEND_INSTANCE_ENTERED",
  family = "Instance",
  mode = "event",
  decode = function(body)
    local id = type(body) == "string" and tonumber(body) or nil

    if not id then
      return nil, "not a number"
    end

    return { dungeonId = id }
  end,
})

Decoders.register(10, {
  name = "SEND_INSTANCE_ENCOUNTERS_COMPLETED",
  family = "Instance",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not a string"
    end

    local encounters = {}

    for item in gmatch(body, "([^,]+)") do
      local id = tonumber(item)

      if id then
        encounters[#encounters + 1] = id
      end
    end

    return { encounters = encounters }
  end,
})

Decoders.register(11, {
  name = "SEND_INSTANCE_ENCOUNTERS_HIDE",
  family = "Instance",
  mode = "event",
  decode = function(body)
    return { raw = body }
  end,
})

Decoders.register(950, {
  name = "SEND_RAID_BOSS_OVERFLOW_HEALTH",
  family = "Instance",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not a string"
    end

    local clear = sub(body, 1, 1) == "*"

    if clear then
      body = sub(body, 2)
    end

    local entries = {}

    for guid, pool in gmatch(body, "([^:;]+):(%d+)") do
      entries[#entries + 1] = { guid = guid, pool = tonumber(pool) }
    end

    return { clear = clear, entries = entries }
  end,
})

Decoders.register(1293, {
  name = "SEND_INSTANCE_TRACKER",
  family = "Instance",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not a string"
    end

    if body == "" then
      return { hidden = true }
    end

    local f = split(body, "|")
    local bosses = {}

    if f[9] and f[9] ~= "" then
      for _, item in ipairs(split(f[9], ";")) do
        local parts = split(item, "~")

        if parts[1] and parts[1] ~= "" then
          bosses[#bosses + 1] = { name = parts[1], dead = parts[2] == "1", looted = parts[3] == "1" }
        end
      end
    end

    if #bosses == 0 then
      return { hidden = true }
    end

    local shards = tonumber(f[5]) or 0

    return {
      name = f[1] or "",
      raid = f[2] == "1",
      torment = tonumber(f[3]) or 0,
      cleared = f[4] == "1",
      soulShards = shards,
      alreadyPaid = shards == -1,
      orbs = tonumber(f[6]) or 0,
      cacheItem = tonumber(f[7]) or 0,
      cacheItemLevel = tonumber(f[8]) or 0,
      bosses = bosses,
    }
  end,
})
