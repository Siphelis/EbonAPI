local Actions = EbonAPI.Actions

local type, tostring, pairs, concat, sort = type, tostring, pairs, table.concat, table.sort

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function ranksCheck(nodeRanks)
  if type(nodeRanks) ~= "table" then
    return "nodeRanks must be a table { [nodeId] = rank }"
  end

  for nodeId, rank in pairs(nodeRanks) do
    if not integer(nodeId) or nodeId <= 0 then
      return "a node id must be a positive integer"
    end

    if not integer(rank) or rank < 0 then
      return "a rank must be an integer of 0 or more"
    end
  end
end

local function nodesBody(nodeRanks)
  local ids = {}

  for nodeId, rank in pairs(nodeRanks) do
    if rank > 0 then
      ids[#ids + 1] = nodeId
    end
  end

  sort(ids)

  local parts = {}

  for index = 1, #ids do
    parts[index] = ids[index] .. ":" .. nodeRanks[ids[index]]
  end

  return concat(parts, ",")
end

local function nameCheck(name, forbidden)
  if type(name) ~= "string" or name == "" then
    return "the name must be a non empty string"
  end

  if name:find(forbidden) then
    return "the name must not contain a separator of the message"
  end
end

Actions.define({ name = "RequestSkillLoadouts", cs = "REQUEST_LOADOUTS" })

Actions.define({
  name = "CreateSkillLoadout", cs = "REQUEST_CREATE_LOADOUT",
  check = function(name, spendablePoints, nodeRanks)
    local bad = nameCheck(name, ",")

    if bad then
      return bad
    end

    if not integer(spendablePoints) or spendablePoints < 0 then
      return "the spendable points must be an integer of 0 or more"
    end

    return ranksCheck(nodeRanks)
  end,
  body = function(name, spendablePoints, nodeRanks)
    return name .. "," .. tostring(spendablePoints) .. "," .. nodesBody(nodeRanks)
  end,
})

Actions.define({
  name = "UpdateSkillLoadout", cs = "REQUEST_LOADOUT_UPDATE",
  check = function(loadoutId, name, nodeRanks)
    if not integer(loadoutId) or loadoutId < 0 then
      return "the loadout id must be an integer of 0 or more"
    end

    return nameCheck(name, "[|,]") or ranksCheck(nodeRanks)
  end,
  body = function(loadoutId, name, nodeRanks)
    return tostring(loadoutId) .. "|" .. name .. "|" .. nodesBody(nodeRanks)
  end,
})
