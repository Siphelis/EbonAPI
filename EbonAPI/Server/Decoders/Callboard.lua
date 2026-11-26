
local Decoders = EbonAPI.Decoders

local gmatch, tonumber, type = string.gmatch, tonumber, type

local split = Decoders.split

local function quest(section)
  local f, count = split(section, "~")

  if count < 18 then
    return nil, count
  end

  local q = {
    questId = tonumber(f[1]) or 0,
    category = tonumber(f[2]) or 0,
    cadence = tonumber(f[3]) or 0,
    done = tonumber(f[4]) or 0,
    max = tonumber(f[5]) or 1,
    state = tonumber(f[6]) or 0,
    ashes = tonumber(f[7]) or 0,
    xp = tonumber(f[8]) or 0,
    copper = tonumber(f[9]) or 0,
    artisan = tonumber(f[10]) or 0,
    item = tonumber(f[11]) or 0,
    itemCount = tonumber(f[12]) or 0,
    orbs = tonumber(f[13]) or 0,
    shards = tonumber(f[14]) or 0,
    accountWide = (tonumber(f[15]) or 0) == 1,
    featured = (tonumber(f[16]) or 0) == 1,
    title = f[17] or "",
    objectives = f[18] or "",
    description = f[19] or "",
    outleveledAbove = tonumber(f[20]) or 0,
    payPct = tonumber(f[21]),
    level = tonumber(f[22]),
    minLevel = tonumber(f[23]),
    maxLevel = tonumber(f[24]),
    poiArea = tonumber(f[25]) or 0,
    poiX = tonumber(f[26]) or 0,
    poiY = tonumber(f[27]) or 0,
    cost = tonumber(f[28]) or 0,
  }

  q.paysNothing = q.payPct == nil and q.outleveledAbove > 0
  q.payPct = q.payPct or (q.paysNothing and 0 or 100)

  if q.questId == 0 then
    return nil, count
  end

  return q, count
end

Decoders.register(1240, {
  name = "SEND_CALLBOARD_DATA",
  family = "Callboard",
  mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    if body == "" then
      return { enabled = false }
    end

    local sections, total = split(body, "|")
    local h = split(sections[1], ",")
    local board = {
      enabled = true,
      dailyResetIn = tonumber(h[1]) or 0,
      weeklyResetIn = tonumber(h[2]) or 0,
      highestIlvl = tonumber(h[3]) or 0,
      equippedIlvl = tonumber(h[4]) or 0,
      cacheProgress = tonumber(h[5]) or 0,
      cacheRequired = tonumber(h[6]) or 1,
      cachesOpened = tonumber(h[7]) or 0,
      startValley = tonumber(h[8]) or 0,
      elixirPending = tonumber(h[9]) == 1,
      elixirAshes = tonumber(h[10]) or 0,
      elixirShards = tonumber(h[11]) or 0,
      quests = {},
      byId = {},
      byCategory = {},
      claimable = 0,
      skipped = 0,
      fields = 0,
    }

    for i = 2, total do
      local q, count = quest(sections[i])

      if count > board.fields then
        board.fields = count
      end

      if q then
        board.quests[#board.quests + 1] = q

        if not board.byId[q.questId] then
          board.byId[q.questId] = q
        end

        local list = board.byCategory[q.category]

        if not list then
          list = {}
          board.byCategory[q.category] = list
        end

        list[#list + 1] = q

        if q.state == 2 and q.cost == 0 then
          board.claimable = board.claimable + 1
        end
      else
        board.skipped = board.skipped + 1
      end
    end

    return board
  end,
})

Decoders.register(1241, {
  name = "SEND_CALLBOARD_RESULT",
  family = "Callboard",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local f = split(body, "~")
    local result = { ok = f[1] == "OK", op = f[2] or "" }

    if result.op == "accept" then
      if result.ok then
        result.questId = tonumber(f[3]) or 0
      else
        result.reason = f[3] or ""
        result.questId = tonumber(f[4]) or 0
      end
    elseif result.op == "claim" then
      if result.ok then
        result.count = tonumber(f[3]) or 0
        result.ashes = tonumber(f[4]) or 0
        result.xp = tonumber(f[5]) or 0
        result.copper = tonumber(f[6]) or 0
        result.artisan = tonumber(f[7]) or 0
        result.caches = {}
        result.items = {}

        for entry in gmatch(f[8] or "", "%d+") do
          result.caches[#result.caches + 1] = tonumber(entry)
        end

        for entry, amount in gmatch(f[9] or "", "(%d+):(%d+)") do
          result.items[#result.items + 1] = { entry = tonumber(entry), count = tonumber(amount) }
        end

        result.orbs = tonumber(f[10]) or 0
        result.shards = tonumber(f[11]) or 0
        result.outleveled = tonumber(f[12]) or 0
      else
        result.reason = f[3] or ""
        result.questId = tonumber(f[4]) or 0
      end
    elseif result.op == "startzone" then
      if result.ok then
        result.zone = tonumber(f[3]) or 0
      else
        result.reason = f[3] or ""
        result.zone = tonumber(f[4]) or 0
      end
    end

    return result
  end,
})
