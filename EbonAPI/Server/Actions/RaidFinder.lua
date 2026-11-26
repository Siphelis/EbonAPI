local Actions = EbonAPI.Actions

local type, tostring, ipairs = type, tostring, ipairs
local concat = table.concat

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

Actions.define({
  name = "RequestRaidFinderData", cs = "REQUEST_RAID_FINDER_DATA",
})

Actions.define({
  name = "SetRaidFinderRoles", cs = "REQUEST_RAID_FINDER_ROLES",
  check = function(mask)
    if not integer(mask) or mask < 0 or mask > 14 or mask % 2 ~= 0 then
      return "the roles mask must be the sum of 2 (tank), 4 (healer) and 8 (damage)"
    end
  end,
  body = function(mask) return tostring(mask) end,
})

Actions.define({
  name = "JoinRaidFinder", cs = "REQUEST_RAID_FINDER_JOIN",
  check = function(maps, tier)
    local list = type(maps) == "table" and maps or { maps }

    if #list == 0 then
      return "at least one map id is needed"
    end

    for _, mapId in ipairs(list) do
      if not integer(mapId) or mapId <= 0 then
        return "each map id must be a positive integer"
      end
    end

    if not integer(tier) or tier < 0 then
      return "the tier must be a non-negative integer"
    end
  end,
  body = function(maps, tier)
    local list = type(maps) == "table" and maps or { maps }
    local out = {}

    for index, mapId in ipairs(list) do
      out[index] = tostring(mapId)
    end

    return concat(out, ",") .. "|" .. tostring(tier)
  end,
})

Actions.define({
  name = "LeaveRaidFinder", cs = "REQUEST_RAID_FINDER_LEAVE",
})

Actions.define({
  name = "AnswerRaidFinder", cs = "REQUEST_RAID_FINDER_ANSWER",
  check = function(accept)
    if type(accept) ~= "boolean" then
      return "accept must be true (enter the raid) or false (leave the queue)"
    end
  end,
  body = function(accept) return accept and "1" or "0" end,
})

Actions.define({
  name = "SearchRaidFinderReplacements", cs = "REQUEST_RAID_FINDER_SEARCH",
  check = function(start)
    if type(start) ~= "boolean" then
      return "start must be true (start the search) or false (stop it)"
    end
  end,
  body = function(start) return start and "1" or "0" end,
})

Actions.define({
  name = "TeleportRaidFinder", cs = "REQUEST_RAID_FINDER_TELEPORT",
  check = function(into)
    if type(into) ~= "boolean" then
      return "into must be true (into the raid) or false (out of the raid)"
    end
  end,
  body = function(into) return into and "1" or "0" end,
})
