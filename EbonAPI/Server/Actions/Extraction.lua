local Actions = EbonAPI.Actions

local type, tostring = type, tostring

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function itemCheck(bag, slot)
  if not integer(bag) or bag < 0 then
    return "the bag must be an integer of 0 or more"
  end

  if not integer(slot) or slot < 0 then
    return "the slot must be an integer of 0 or more"
  end
end

local function itemBody(bag, slot)
  return tostring(bag) .. "," .. tostring(slot)
end

local function upgradeCheck(bag, slot, target)
  local problem = itemCheck(bag, slot)

  if problem then
    return problem
  end

  if target ~= nil and (not integer(target) or target < 1 or target > 4) then
    return "the target bracket must be an integer from 1 to 4, or nil for the server's default"
  end
end

local function upgradeBody(bag, slot, target)
  local body = itemBody(bag, slot)

  if target then
    body = body .. "," .. tostring(target)
  end

  return body
end

local spellCheck = EbonAPI.Actions.spellCheck

Actions.define({ name = "ExtractAffix", cs = "REQUEST_AFFIX_EXTRACTION", check = itemCheck, body = itemBody })

Actions.define({ name = "QueryExtractionCost", cs = "REQUEST_AFFIX_EXTRACTION_INFO", check = itemCheck, body = itemBody })

Actions.define({
  name = "ApplyAffix", cs = "REQUEST_AFFIX_APPLY",
  check = function(spellId, bag, slot) return spellCheck(spellId) or itemCheck(bag, slot) end,
  body = function(spellId, bag, slot) return tostring(spellId) .. "," .. tostring(bag) .. "," .. tostring(slot) end,
})

Actions.define({ name = "ListLearnedAffixes", cs = "REQUEST_LEARNED_AFFIXES" })

Actions.define({
  name = "QueryApplyCost", cs = "REQUEST_AFFIX_APPLY_INFO",
  check = spellCheck, body = EbonAPI.Actions.spellBody,
})

Actions.define({ name = "QueryLegendaryUpgrade", cs = "REQUEST_LEGENDARY_UPGRADE_INFO", check = upgradeCheck, body = upgradeBody })

Actions.define({ name = "UpgradeLegendary", cs = "REQUEST_LEGENDARY_UPGRADE", check = upgradeCheck, body = upgradeBody })
