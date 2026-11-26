local Actions = EbonAPI.Actions

local type, pairs, ipairs = type, pairs, ipairs
local concat, format = table.concat, string.format

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function mask(value)
  return integer(value) and value >= 0 and value <= 4294967295
end

local function ids(list)
  if list == nil then
    return ""
  end

  local out = {}

  for _, id in ipairs(list) do
    out[#out + 1] = format("%d", id)
  end

  return concat(out, ",")
end

local function idList(list, label)
  if list == nil then
    return nil
  end

  if type(list) ~= "table" then
    return label .. " must be a list of item ids"
  end

  for _, id in ipairs(list) do
    if not integer(id) or id <= 0 then
      return label .. " must hold positive integer item ids"
    end
  end
end

local function noArguments() end

local LOOT_FIELDS = { "on", "minQuality", "classMask", "destroy", "destroyMaxQuality", "destroyClassMask" }

local function knownLoot()
  local state = EbonAPI.Decoders.get(1270)

  return type(state) == "table" and type(state.loot) == "table" and state.loot or nil
end

Actions.define({
  name = "RequestToolbeltState", cs = "REQUEST_TOOLBELT_STATE", service = { "ToolbeltService", "Request" },
})

Actions.define({
  name = "OpenToolbeltBank", cs = "REQUEST_TOOLBELT_OPEN_BANK", service = { "ToolbeltService", "OpenBank" },
})

Actions.define({
  name = "SellToolbeltItems", cs = "REQUEST_TOOLBELT_SELL", service = { "ToolbeltService", "Sell" },
  callArgs = noArguments,
  guard = function(rules)
    if rules ~= nil then
      return "ToolbeltService.Sell takes no rules and sells with the ProjectEbonhold options: call it without rules"
    end
  end,
  check = function(rules)
    if rules == nil then
      return nil
    end

    if type(rules) ~= "table" then
      return "the rules must be a table { quality, types, all, never, always }"
    end

    if rules.quality ~= nil and (not integer(rules.quality) or rules.quality < 0 or rules.quality > 15) then
      return "quality must be a mask of 1 (poor), 2 (common), 4 (uncommon), 8 (rare)"
    end

    if rules.types ~= nil and not mask(rules.types) then
      return "types must be a mask of 2 to the power of the item class"
    end

    if rules.all ~= nil and type(rules.all) ~= "boolean" then
      return "all must be a boolean"
    end

    return idList(rules.never, "never") or idList(rules.always, "always")
  end,
  body = function(rules)
    if type(rules) ~= "table" then
      return ""
    end

    return format("q:%d|t:%d|all:%d|never:%s|always:%s",
      rules.quality or 0, rules.types or 0, rules.all and 1 or 0, ids(rules.never), ids(rules.always))
  end,
  why = function() return "nothing left to sell, or the items were already sent" end,
})

Actions.define({
  name = "RepairToolbelt", cs = "REQUEST_TOOLBELT_REPAIR", service = { "ToolbeltService", "Repair" },
})

Actions.define({
  name = "OpenToolbeltMail", cs = "REQUEST_TOOLBELT_OPEN_MAIL", service = { "ToolbeltService", "OpenMailbox" },
})

Actions.define({
  name = "SetToolbeltLoot", cs = "REQUEST_TOOLBELT_LOOT_SET", service = { "ToolbeltService", "SetLoot" },
  check = function(fields)
    if type(fields) ~= "table" then
      return "the fields must be a table { on, minQuality, classMask, destroy, destroyMaxQuality, destroyClassMask }"
    end

    if fields.on ~= nil and type(fields.on) ~= "boolean" then
      return "on must be a boolean"
    end

    if fields.destroy ~= nil and type(fields.destroy) ~= "boolean" then
      return "destroy must be a boolean"
    end

    for _, key in pairs({ "minQuality", "destroyMaxQuality" }) do
      local value = fields[key]

      if value ~= nil and (not integer(value) or value < 0) then
        return key .. " must be an item quality of 0 or more"
      end
    end

    for _, key in pairs({ "classMask", "destroyClassMask" }) do
      if fields[key] ~= nil and not mask(fields[key]) then
        return key .. " must be an integer mask from 0 to 4294967295"
      end
    end

    if not EbonAPI.Ebonhold.ServiceFunction("ToolbeltService", "SetLoot") and not knownLoot() then
      for _, key in pairs(LOOT_FIELDS) do
        if fields[key] == nil then
          return key .. " is required: ProjectEbonhold keeps the other settings, but its toolbelt state is not known yet (no SS 1270 received)"
        end
      end
    end
  end,
  body = function(fields)
    local loot = knownLoot() or {}

    local function pick(key)
      if fields[key] ~= nil then
        return fields[key]
      end

      return loot[key]
    end

    return format("on:%d|q:%d|t:%d|d:%d|dq:%d|dt:%d",
      pick("on") and 1 or 0,
      pick("minQuality"),
      pick("classMask"),
      pick("destroy") and 1 or 0,
      pick("destroyMaxQuality"),
      pick("destroyClassMask"))
  end,
})

Actions.define({
  name = "SetWaystone", cs = "REQUEST_WAYSTONE_SET", service = { "ToolbeltService", "SetWaystone" },
  check = function(slot, checkpointId)
    if not integer(slot) or slot < 0 then
      return "the slot must be a non-negative integer"
    end

    if checkpointId ~= nil and (not integer(checkpointId) or checkpointId < 0) then
      return "the checkpoint id must be a non-negative integer (0 clears the slot)"
    end
  end,
  body = function(slot, checkpointId) return format("%d:%d", slot, checkpointId or 0) end,
})

Actions.define({
  name = "OpenToolbeltAuction", cs = "REQUEST_TOOLBELT_OPEN_AUCTION", service = { "ToolbeltService", "OpenAuctionHouse" },
})

Actions.define({
  name = "OpenToolbeltGuildBank", cs = "REQUEST_TOOLBELT_GUILD_BANK", service = { "ToolbeltService", "OpenGuildBank" },
})

Actions.define({
  name = "PlaceToolbeltForge", cs = "REQUEST_TOOLBELT_FORGE", service = { "ToolbeltService", "PlaceForge" },
})

Actions.define({
  name = "OpenToolbeltMerchant", cs = "REQUEST_TOOLBELT_OPEN_MERCHANT", service = { "ToolbeltService", "OpenMerchant" },
})
