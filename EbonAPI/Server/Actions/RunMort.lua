local Actions = EbonAPI.Actions

local type, tostring, ipairs = type, tostring, ipairs
local concat, sort = table.concat, table.sort

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function positive(value)
  return integer(value) and value > 0
end

local function mask(value)
  return integer(value) and value >= 0
end

local function idList(list)
  if list == nil then
    return nil
  end

  if type(list) ~= "table" then
    return "an item id list must be a table"
  end

  for _, id in ipairs(list) do
    if not positive(id) then
      return "an item id must be a positive integer"
    end
  end
end

local function sortedIds(list)
  local copy = {}

  for _, id in ipairs(list or {}) do
    copy[#copy + 1] = tostring(id)
  end

  sort(copy, function(a, b) return tonumber(a) < tonumber(b) end)

  return concat(copy, ",")
end

Actions.define({
  name = "SellJunkItems", cs = "REQUEST_SELL_JUNK_ITEMS",
  check = function(rules)
    if rules == nil then
      return
    end

    if type(rules) ~= "table" then
      return "the sell rules must be a table"
    end

    if rules.qualities ~= nil and not mask(rules.qualities) then
      return "qualities must be a non-negative integer mask"
    end

    if rules.classes ~= nil and not mask(rules.classes) then
      return "classes must be a non-negative integer mask"
    end

    if rules.all ~= nil and type(rules.all) ~= "boolean" then
      return "all must be a boolean"
    end

    return idList(rules.never) or idList(rules.always)
  end,
  body = function(rules)
    rules = rules or {}

    return "q:" .. tostring(rules.qualities or 0) .. "|t:" .. tostring(rules.classes or 0)
      .. "|all:" .. (rules.all and "1" or "0") .. "|never:" .. sortedIds(rules.never)
      .. "|always:" .. sortedIds(rules.always)
  end,
})

Actions.define({
  name = "SellItemOnDeath", cs = "REQUEST_DEATH_SELL_ITEM",
  check = function(bag, slot, entry)
    if not integer(bag) or bag < 0 then
      return "the bag must be an integer of 0 or more"
    end

    if not positive(slot) then
      return "the slot must be a positive integer"
    end

    if not positive(entry) then
      return "the item entry must be a positive integer"
    end
  end,
  body = function(bag, slot, entry)
    return tostring(bag) .. "," .. tostring(slot) .. "," .. tostring(entry)
  end,
})

Actions.define({
  name = "PayForResurrection", cs = "REQUEST_AVOID_RESET_WITH_SOUL_POINTS",
  service = { "PlayerRunService", "AvoidResetWithSoulPoints" },
})

Actions.define({ name = "RequestRunData", cs = "REQUEST_PLAYER_RUN_DATA" })

Actions.define({ name = "RequestSoulPointsBonus", cs = "REQUEST_PLAYER_SOUL_POINTS_ADDITIONAL_PCT" })

Actions.define({
  name = "RecoverSavedItem", cs = "REQUEST_PLAYER_ADD_ITEM_ITEM_SAVED",
  service = { "KnowledgeBaseService", "RecoverItem" },
  check = function(guid)
    if type(guid) ~= "string" or guid == "" then
      return "the item guid must be a non-empty string"
    end
  end,
  body = function(guid)
    return guid
  end,
  why = function()
    return "the item guid was refused as empty"
  end,
})

Actions.define({
  name = "RequestSavedItems", cs = "REQUEST_PLAYER_ITEMS_SAVED",
  service = { "KnowledgeBaseService", "RequestSavedItems" },
})

local function acceptDeathBody(entries)
  local parts = {}

  for _, id in ipairs(entries or {}) do
    parts[#parts + 1] = tostring(id)
  end

  return concat(parts, ",")
end

Actions.define({
  name = "AcceptDeath", cs = "REQUEST_ACCEPT_DEATH",
  service = { "PlayerRunService", "AcceptDeath" },
  check = function(entries)
    return idList(entries)
  end,
  body = acceptDeathBody,
  callArgs = acceptDeathBody,
})

Actions.define({ name = "UnlockPlayer", cs = "REQUEST_UNLOCK_PLAYER" })
