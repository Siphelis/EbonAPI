
local Decoders = EbonAPI.Decoders

local tonumber, type = tonumber, type
local match, gmatch = string.match, string.gmatch

local split = Decoders.split

Decoders.register(12, {
  name = "SEND_JUNK_SOLD",
  family = "RunDeath",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not a string"
    end

    local sold, copper = match(body, "^(%d+)|(%d+)$")

    if sold then
      return { sold = tonumber(sold), copper = tonumber(copper) }
    end

    return { raw = body }
  end,
})

local RUN_FIELDS = {
  "soulPoints", "soulPointsMax", "acceptedRezs", "acceptedRezsMax", "countCanSelfRezs", "selfRezsMax",
  "classRezs", "classRezsMax", "avoidedFatalAttacks", "avoidedFatalAttacksMax", "nbResetAvoided",
  "costNextReset", "usedRerolls", "totalRerolls", "remainingBanishes", "catchupMultiplierPct",
  "usedFreezes", "totalFreezes", "hasReachedMaxLevel", "soulShards", "soulShardsBonusPct",
  "paidRezAvailable", "costNextResetShards", "banksUsedWeek", "banksMaxWeek",
}

local RUN_COUNTS = { [14] = true, [15] = true, [16] = true, [18] = true, [19] = true, [20] = true, [21] = true, [25] = true }

Decoders.register(13, {
  name = "SEND_PLAYER_RUN_DATA",
  family = "RunDeath",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not a string"
    end

    local fields = split(body, ";")
    local count = #fields

    if not RUN_COUNTS[count] then
      return nil, "unsupported field count " .. count
    end

    if count ~= 25 then
      for index = 1, count do
        if fields[index] == "" then
          return nil, "empty field " .. index
        end
      end
    end

    local data = {}

    for index = 1, #RUN_FIELDS do
      data[RUN_FIELDS[index]] = tonumber(fields[index]) or 0
    end

    if count == 14 then
      data.remainingBanishes = 1
    end

    data.hasReachedMaxLevel = data.hasReachedMaxLevel == 1
    data.paidRezAvailable = data.paidRezAvailable == 1
    data.fieldCount = count

    return data
  end,
})

Decoders.register(14, {
  name = "SEND_PLAYER_SOUL_POINTS_MULTIPLIER",
  family = "RunDeath",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "empty body"
    end

    local value = tonumber(body)

    if not value then
      return nil, "not a number"
    end

    return { multiplier = value }
  end,
})

Decoders.register(15, {
  name = "SEND_PLAYER_UPDATED_COMMITTED_SOUL_POINTS",
  family = "RunDeath",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not a string"
    end

    local nums = {}

    for digits in gmatch(body, "(%d+)") do
      nums[#nums + 1] = tonumber(digits)
    end

    if not (nums[1] and nums[2]) then
      return nil, "need spendable and committed"
    end

    local data = { spendable = nums[1], committed = nums[2] }

    if nums[8] then
      data.pools = {
        shard = { spendable = nums[3], banked = nums[4] },
        essence = { spendable = nums[5], banked = nums[6] },
        artisan = { spendable = nums[7], banked = nums[8] },
      }
    end

    return data
  end,
})

Decoders.register(21, {
  name = "SEND_PLAYER_ITEMS_SAVED",
  family = "RunDeath",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not a string"
    end

    local items = {}

    for chunk in gmatch(body, "([^;]+)") do
      local guid, entry, count = match(chunk, "^([^,]+),([^,]+),([^,]+)$")
      entry, count = tonumber(entry), tonumber(count)

      if guid and entry and count then
        items[#items + 1] = { guid = guid, entry = entry, count = count }
      end
    end

    return { items = items }
  end,
})

Decoders.register(900, {
  name = "SEND_PLAYER_IS_BLOCKED",
  family = "RunDeath",
  mode = "event",
  decode = function(body)
    return { raw = body }
  end,
})
