local Core = AutoCallboardCore or {}
AutoCallboardCore = Core

local type, tonumber, pairs = type, tonumber, pairs
local string = string

local trim = Core.trim
local normalizeMatchText = Core.normalizeMatchText
local compactMatchText = Core.compactMatchText
local appendUniqueNormalized = Core.appendUniqueNormalized

local CURRENT_INSTANCE_ALIASES = {
  ["utgarde keep"] = { "utgarde keep", "ingvar", "ingvar the plunderer" },
  ["utgarde pinnacle"] = { "utgarde pinnacle", "king ymiron", "ymiron" },
  ["azjol nerub"] = { "azjol nerub", "anub arak" },
  ["oculus"] = { "the oculus", "oculus", "ley guardian eregos", "eregos" },
  ["halls of lightning"] = { "halls of lightning", "loken" },
  ["halls of stone"] = { "halls of stone", "sjonnir", "sjonnir the ironshaper" },
  ["culling of stratholme"] = { "the culling of stratholme", "culling of stratholme", "mal ganis" },
  ["drak tharon keep"] = { "drak tharon keep", "prophet tharon ja", "the prophet tharon ja", "tharon ja" },
  ["gundrak"] = { "gundrak", "gal darah" },
  ["ahn kahet the old kingdom"] = { "ahn kahet", "old kingdom", "herald volazj" },
  ["ahn kahet"] = { "ahn kahet", "old kingdom", "herald volazj" },
  ["violet hold"] = { "the violet hold", "violet hold", "cyanigosa" },
  ["nexus"] = { "the nexus", "keristrasza" },
  ["trial of the champion"] = { "trial of the champion", "the black knight", "black knight" },
  ["trial of the crusader"] = { "trial of the crusader" },
  ["ruby sanctum"] = { "the ruby sanctum", "ruby sanctum", "halion" },
  ["forge of souls"] = { "the forge of souls", "forge of souls", "devourer of souls" },
  ["pit of saron"] = { "pit of saron", "overlord tyrannus", "tyrannus" },
  ["halls of reflection"] = { "halls of reflection", "escaped from arthas", "marwyn", "falric" },
  ["naxxramas"] = { "naxxramas", "kel thuzad", "kelthuzad" },
  ["eye of eternity"] = { "the eye of eternity", "eye of eternity", "malygos" },
  ["obsidian sanctum"] = { "the obsidian sanctum", "obsidian sanctum", "sartharion" },
  ["vault of archavon"] = { "vault of archavon", "toravon", "archavon", "emalon", "koralon" },
}

local MAP_FILE_INSTANCES = {
  ["nexus80"] = { "oculus" },
  ["ulduar77"] = { "halls of stone" },
  ["cotstratholme"] = { "culling of stratholme" },
  ["theargentcoliseum"] = { "trial of the champion", "trial of the crusader" },
}

for mapFile, keys in pairs(MAP_FILE_INSTANCES) do
  local merged = {}

  for i = 1, #(keys) do
    local mapped = CURRENT_INSTANCE_ALIASES[keys[i]]

    for j = 1, #(mapped) do
      merged[#(merged) + 1] = mapped[j]
    end
  end

  CURRENT_INSTANCE_ALIASES[mapFile] = merged
end

local CURRENT_INSTANCE_COMPACT_ALIASES = {}
for key, mapped in pairs(CURRENT_INSTANCE_ALIASES) do
  CURRENT_INSTANCE_COMPACT_ALIASES[compactMatchText(key)] = mapped
end

local COMPACT_ALIAS_PREFIX_MIN = 5

local function findCompactAliasByPrefix(compact)
  if compact:len() < COMPACT_ALIAS_PREFIX_MIN then
    return nil
  end

  local found

  for key, mapped in pairs(CURRENT_INSTANCE_COMPACT_ALIASES) do
    if key:len() > compact:len() and key:sub(1, compact:len()) == compact then
      if found and found ~= mapped then
        return nil
      end

      found = mapped
    end
  end

  return found
end

local function findInstanceAliases(alias)
  local mapped = CURRENT_INSTANCE_ALIASES[alias]
      or CURRENT_INSTANCE_ALIASES[(alias:gsub("^the ", "", 1))]

  if mapped then
    return mapped
  end

  local compact = compactMatchText(alias)
  if compact == "" then
    return nil
  end

  return CURRENT_INSTANCE_COMPACT_ALIASES[compact]
      or CURRENT_INSTANCE_COMPACT_ALIASES[(compact:gsub("^the", "", 1))]
      or findCompactAliasByPrefix(compact)
end

function Core.instanceCategory(instanceType)
  instanceType = normalizeMatchText(instanceType)

  if instanceType == "party" then
    return Core.CATEGORY.DUNGEON
  end

  if instanceType == "raid" then
    return Core.CATEGORY.RAID
  end

  return 0
end

local function isInstanceCategory(category)
  return category == Core.CATEGORY.DUNGEON or category == Core.CATEGORY.RAID
end

function Core.buildCurrentInstanceTarget(info)
  if type(info) ~= "table" then
    return nil
  end

  if info.builtTarget then
    return info
  end

  local category = Core.sanitizeCategory(info.category)
  if category == 0 then
    category = Core.instanceCategory(info.instanceType)
  end

  if not isInstanceCategory(category) then
    return nil
  end

  local aliases = {}
  local seen = {}
  appendUniqueNormalized(aliases, seen, info.name)
  appendUniqueNormalized(aliases, seen, info.realZoneText)
  appendUniqueNormalized(aliases, seen, info.zoneText)
  appendUniqueNormalized(aliases, seen, info.minimapZoneText)

  if type(info.names) == "table" then
    for i = 1, #(info.names) do
      appendUniqueNormalized(aliases, seen, info.names[i])
    end
  end

  if type(info.aliases) == "table" then
    for i = 1, #(info.aliases) do
      appendUniqueNormalized(aliases, seen, info.aliases[i])
    end
  end

  local originalCount = #(aliases)
  for i = 1, originalCount do
    local alias = aliases[i]
    local mappedAliases = findInstanceAliases(alias)
    if type(mappedAliases) == "table" then
      for j = 1, #(mappedAliases) do
        appendUniqueNormalized(aliases, seen, mappedAliases[j])
      end
    end
  end

  if #(aliases) == 0 then
    local zone = info.realZoneText or info.zoneText or info.name

    if type(zone) ~= "string" or trim(zone) == "" then
      zone = "-"
    end

    return nil, Core.problem("MATCHER.NO_ALIAS", { zone = zone, name = trim(info.name) })
  end

  return {
    builtTarget = true,
    instanceType = trim(info.instanceType),
    name = trim(info.name) ~= "" and trim(info.name) or aliases[1],
    category = category,
    areaId = tonumber(info.areaId),
    aliases = aliases,
  }
end

local function aliasMatchesQuestText(alias, combined, compactCombined)
  if alias == "" then
    return false
  end

  if string.find(combined, alias, 1, true) then
    return true
  end

  local isSingleWord = not string.find(alias, " ", 1, true)

  return isSingleWord and string.find(compactCombined, alias, 1, true) ~= nil
end

local function questMatchesBuiltTarget(quest, target)
  if type(quest) ~= "table" or not target then
    return false
  end

  if Core.questCategory(quest) ~= target.category then
    return false
  end

  local combined = normalizeMatchText(Core.questTitle(quest) .. " " .. Core.objectiveText(quest))
  local compactCombined = compactMatchText(combined)

  for i = 1, #(target.aliases) do
    if aliasMatchesQuestText(target.aliases[i], combined, compactCombined) then
      return true
    end
  end

  return false
end

function Core.isQuestExcluded(excluded, key)
  return type(excluded) == "table" and key ~= nil and excluded[key] == true
end

function Core.questMatchesInstanceTarget(quest, currentInstanceTarget)
  local target = Core.buildCurrentInstanceTarget(currentInstanceTarget)

  if not target then
    return false
  end

  return questMatchesBuiltTarget(quest, target)
end

function Core.wantedContracts(quests, desired, currentInstanceTarget, excluded)
  local wanted, unpaid = {}, {}

  if type(quests) ~= "table" then
    return wanted, unpaid
  end

  local target = Core.buildCurrentInstanceTarget(currentInstanceTarget)
  local taken = {}

  local function consider(quest, isWanted)
    local key = Core.questKey(quest)

    if key and isWanted and not taken[key]
        and tonumber(quest.state) == Core.STATE.AVAILABLE
        and not Core.isQuestExcluded(excluded, key) then
      taken[key] = true

      if Core.paysNothing(quest) then
        unpaid[#(unpaid) + 1] = quest
      else
        wanted[#(wanted) + 1] = quest
      end
    end
  end

  if target then
    for i = 1, #(quests) do
      consider(quests[i], questMatchesBuiltTarget(quests[i], target))
    end
  end

  if type(desired) == "table" then
    for i = 1, #(quests) do
      consider(quests[i], desired[Core.questKey(quests[i]) or ""] == true)
    end
  end

  return wanted, unpaid
end
