local Core = AutoCallboardCore or {}
AutoCallboardCore = Core

Core.PARTIAL_ALPHA = 0.45
Core.WEAK = { __mode = "k" }
local Lib = EbonAPI.Lib

local type, tonumber, tostring, pairs, ipairs = type, tonumber, tostring, pairs, ipairs
local string, table, math = string, table, math

function Core.problem(name, facts, cause)
  local RT = AutoCallboardRuntime

  if not Core.reportReady or not RT or not RT.api then
    return nil
  end

  return RT.api:Problem(name, facts, cause)
end

function Core.report(problem)
  local RT = AutoCallboardRuntime

  if problem and Core.reportReady and RT and RT.api then
    return RT.api:Report(problem)
  end
end

function Core.repaired(name, facts, old)
  local RT = AutoCallboardRuntime

  if not Core.reportReady or not RT or not RT.api then
    return nil
  end

  return RT.api:Repaired(name, facts, old)
end

local DEFAULTS = {
  targetName = "Callboard",
  autoClaim = false,
  autoCurrentInstanceQuest = false,
  travelEnabled = true,
  travelAuto = false,
  portalFollow = false,
  portalAuto = false,
  portalCount = true,
  questArrow = true,
  travelDefault = "auto",
  showOffBoard = true,
  knownQuests = {},
  desiredQuests = {},
  characterProfiles = {},
  accountProfile = {},
  routeLibrary = {},
  characterState = {},
  migratedCharacters = {},
  accountListSeeded = false,
  presetsMigrated = false,
  arrowPointUnscaled = true,
  debug = {
    enabled = false,
    mouseWatch = false,
    sniffer = false,
    maxLog = 120,
  },
  buttonShown = true,
  button = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
  },
  minimap = {
    shown = true,
    angle = 225,
  },
}

Core.CATEGORY = {
  DUNGEON = 1,
  RAID = 2,
  OPEN_WORLD = 3,
  PROFESSION = 4,
  CHALLENGE = 5,
  OTHER = 6,
  TORMENT = 7,
}

Core.CATEGORY_ORDER = {}

for _, category in ipairs(EbonAPI.State.CallboardCategories()) do
  Core.CATEGORY_ORDER[#(Core.CATEGORY_ORDER) + 1] = category.id
end

Core.STATE = EbonAPI.State.CALLBOARD_STATE
Core.CADENCE = EbonAPI.State.CALLBOARD_CADENCE

local CATEGORY_RANK = {}

for i = 1, #(Core.CATEGORY_ORDER) do
  CATEGORY_RANK[Core.CATEGORY_ORDER[i]] = i
end

local function trim(value)
  if type(value) ~= "string" then
    return ""
  end

  return Lib.trim(value)
end

local function truncateLetters(value, limit)
  if type(value) ~= "string" then
    return ""
  end

  local length = string.len(value)
  local index, letters = 1, 0

  while index <= length do
    if letters >= limit then
      return string.sub(value, 1, index - 1)
    end

    index = index + 1

    while index <= length do
      local byte = string.byte(value, index)

      if byte < 128 or byte > 191 then
        break
      end

      index = index + 1
    end

    letters = letters + 1
  end

  return value
end

Core.truncateLetters = truncateLetters

local function stripColorCodes(value)
  if type(value) ~= "string" then
    return ""
  end

  return Lib.stripColor(value)
end

local function normalizeMatchText(value)
  value = stripColorCodes(string.lower(trim(value)))
  value = value:gsub("[^%w]+", " ")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  return value
end

local function compactMatchText(value)
  return (normalizeMatchText(value):gsub(" ", ""))
end

local function hasEnabledValue(map)
  if type(map) ~= "table" then
    return false
  end

  for _, enabled in pairs(map) do
    if enabled == true then
      return true
    end
  end

  return false
end

Core.trim = trim
Core.stripColorCodes = stripColorCodes
Core.normalizeMatchText = normalizeMatchText
Core.compactMatchText = compactMatchText

local function appendUniqueNormalized(values, seen, value)
  value = normalizeMatchText(value)

  if value == "" or seen[value] then
    return
  end

  seen[value] = true
  table.insert(values, value)
end

Core.appendUniqueNormalized = appendUniqueNormalized

local function count(value)
  value = math.floor(tonumber(value) or 0)

  if value < 0 then
    return 0
  end

  return value
end

Core.count = count

function Core.sanitizeCategory(value)
  value = tonumber(value) or 0

  if value == Core.CATEGORY.CHALLENGE or CATEGORY_RANK[value] then
    return value
  end

  return 0
end

function Core.questCategory(quest)
  if type(quest) ~= "table" then
    return 0
  end

  return Core.sanitizeCategory(quest.category)
end

function Core.displayCategory(quest)
  local category = Core.questCategory(quest)

  if CATEGORY_RANK[category] then
    return category
  end

  return Core.CATEGORY.OTHER
end

function Core.categoryRank(category)
  return CATEGORY_RANK[tonumber(category) or 0] or (#(Core.CATEGORY_ORDER) + 1)
end

local function copyDefaults()
  return Lib.copyDeep(DEFAULTS)
end

function Core.defaultState()
  return copyDefaults()
end

local MERGE_NONEMPTY_STRING = { "targetName", "travelDefault" }
local MERGE_BOOLEAN = {
  "autoClaim", "autoCurrentInstanceQuest", "travelEnabled", "travelAuto", "portalFollow", "portalAuto", "portalCount", "questArrow", "showOffBoard",
  "presetsMigrated", "buttonShown",
  "accountListSeeded",
}
local MERGE_COLLECTION = {
  knownQuests = "copyQuestList",
  desiredQuests = "copyDesiredMap",
  characterProfiles = "copyCharacterProfiles",
  accountProfile = "copyAccountProfile",
  routeLibrary = "copyRouteLibrary",
  characterState = "copyCharacterStateMap",
  migratedCharacters = "copyDesiredMap",
}

local function mergeNested(saved, state, spec)
  for key, kind in pairs(spec) do
    if kind == "nonEmptyString" then
      if trim(saved[key]) ~= "" then state[key] = trim(saved[key]) end
    elseif kind == "number" then
      if type(saved[key]) == "number" then state[key] = saved[key] end
    elseif kind == "boolean" then
      if type(saved[key]) == "boolean" then state[key] = saved[key] end
    end
  end
end

Core.mergeNested = mergeNested

function Core.mergeState(saved, adopt)
  local state = copyDefaults()

  if type(saved) ~= "table" then
    if saved ~= nil then
      Core.repaired("STATE.REPAIRED", { field = "settings", setting = "settings", value = type(saved) }, saved)
    end

    return state
  end

  for _, key in ipairs(MERGE_NONEMPTY_STRING) do
    if trim(saved[key]) ~= "" then state[key] = trim(saved[key]) end
  end

  for _, key in ipairs(MERGE_BOOLEAN) do
    if type(saved[key]) == "boolean" then state[key] = saved[key] end
  end

  for key, copier in pairs(MERGE_COLLECTION) do
    if type(saved[key]) == "table" then
      state[key] = adopt and saved[key] or Core[copier](saved[key])
    end
  end

  if type(saved.debug) == "table" then
    mergeNested(saved.debug, state.debug, {
      enabled = "boolean", mouseWatch = "boolean", sniffer = "boolean",
    })

    if type(saved.debug.maxLog) == "number" and saved.debug.maxLog >= 20 then
      state.debug.maxLog = saved.debug.maxLog
    end
  end

  if type(saved.button) == "table" then
    mergeNested(saved.button, state.button, {
      point = "nonEmptyString", relativePoint = "nonEmptyString", x = "number", y = "number",
    })
  end

  state.appearance = Core.copyAppearance(saved.appearance)
  state.windowPositions = {}
  if type(saved.windowPositions) == "table" then
    for name, point in pairs(saved.windowPositions) do
      if type(name) == "string" and name:match("^AutoCallboard") then
        if type(point) == "table" then
          local copy = {}
          mergeNested(point, copy, {point = "nonEmptyString", relativePoint = "nonEmptyString", x = "number", y = "number"})
          state.windowPositions[name] = copy
        else
          Core.repaired("STATE.REPAIRED", { field = "windowPositions", setting = name, value = type(point) }, point)
        end
      end
    end
  elseif saved.windowPositions ~= nil then
    Core.repaired("STATE.REPAIRED", { field = "windowPositions", setting = "windowPositions", value = type(saved.windowPositions) }, saved.windowPositions)
  end

  local arrowPoint = state.windowPositions.AutoCallboardRouteArrow
  if arrowPoint and saved.arrowPointUnscaled ~= true then
    local factor = state.appearance.arrowScale
    if arrowPoint.x then arrowPoint.x = arrowPoint.x * factor end
    if arrowPoint.y then arrowPoint.y = arrowPoint.y * factor end
  end

  if type(saved.minimap) == "table" then
    mergeNested(saved.minimap, state.minimap, { shown = "boolean", angle = "number" })
  end

  if type(state.accountProfile) ~= "table" or type(state.accountProfile.savedSelections) ~= "table"
      or type(state.accountProfile.groups) ~= "table" then
    state.accountProfile = Core.copyAccountProfile(state.accountProfile)
  end

  return state
end

function Core.adoptState(saved)
  return Core.mergeState(saved, true)
end

function Core.questTitle(quest)
  if type(quest) ~= "table" then
    return ""
  end

  return trim(quest.title)
end

function Core.objectiveText(quest)
  if type(quest) ~= "table" then
    return ""
  end

  if type(quest.objectiveText) == "string" then
    return trim(quest.objectiveText)
  end

  return trim(quest.objectives)
end

function Core.questKey(quest)
  if type(quest) ~= "table" then
    return nil
  end

  local questID = tonumber(quest.questId or quest.id)
  if questID and questID > 0 then
    return "id:" .. tostring(math.floor(questID))
  end

  local title = Core.questTitle(quest)
  if title == "" then
    return nil
  end

  return "title:" .. title:lower()
end

function Core.outleveledAbove(quest)
  if type(quest) ~= "table" then
    return 0
  end

  return count(quest.outleveledAbove)
end

function Core.paysNothing(quest)
  if type(quest) ~= "table" then
    return false
  end

  if quest.paysNothing == true then
    return true
  end

  return Core.outleveledAbove(quest) > 0 and tonumber(quest.payPct) == 0
end

local QUEST_REWARD_FIELDS = { "ashes", "xp", "copper", "artisan", "item", "itemCount", "orbs", "shards" }

Core.questRewardFields = QUEST_REWARD_FIELDS

local indexedList, indexedMap, indexedCount

function Core.questIndexKey(quest)
  if type(quest) ~= "table" then
    return nil
  end

  if type(quest.key) == "string" and quest.key ~= "" then
    return quest.key
  end

  return Core.questKey(quest)
end

local questIndexKey = Core.questIndexKey

local function knownQuestIndex(quests)
  if type(quests) ~= "table" then
    return nil
  end

  local total = #(quests)

  if indexedList == quests and indexedCount == total then
    return indexedMap
  end

  local map = {}

  for i = 1, total do
    local key = questIndexKey(quests[i])

    if key then
      map[key] = quests[i]
    end
  end

  indexedList = quests
  indexedMap = map
  indexedCount = total

  return map
end

local function noteIndexedQuest(quests, key, quest)
  if indexedList ~= quests then
    return
  end

  indexedMap[key] = quest
  indexedCount = #(quests)
end

local function setField(target, field, value)
  if target[field] == value then
    return false
  end

  target[field] = value

  return true
end

local function copyContractFields(target, source)
  if source.category == nil then
    return false
  end

  local changed = setField(target, "category", count(source.category))
  changed = setField(target, "cadence", count(source.cadence)) or changed
  changed = setField(target, "accountWide", source.accountWide == true) or changed

  for i = 1, #(QUEST_REWARD_FIELDS) do
    local field = QUEST_REWARD_FIELDS[i]
    changed = setField(target, field, count(source[field])) or changed
  end

  local description = trim(source.description)

  if description ~= "" then
    changed = setField(target, "description", description) or changed
  end

  return changed
end

function Core.copyQuest(quest)
  if type(quest) ~= "table" then
    return nil
  end

  local key = questIndexKey(quest)

  if not key then
    return nil
  end

  local entry = {
    key = key,
    questId = count(quest.questId),
    title = trim(quest.title),
    objectiveText = Core.objectiveText(quest),
  }

  copyContractFields(entry, quest)

  return entry
end

function Core.copyQuestList(quests)
  local copy = {}

  if type(quests) ~= "table" then
    return copy
  end

  local total = 0

  for i = 1, #(quests) do
    local entry = Core.copyQuest(quests[i])
    if entry then
      total = total + 1
      copy[total] = entry
    end
  end

  if total < #(quests) then
    Core.repaired("QUESTS.REPAIRED", { field = "known", value = #(quests), kept = total }, quests)
  end

  return copy
end

function Core.mergeQuest(existing, incoming)
  local merged = Core.copyQuest(existing) or {}

  for field, value in pairs(Core.copyQuest(incoming) or {}) do
    merged[field] = value
  end

  return merged
end

function Core.copyDesiredMap(desired)
  local copy = {}

  if type(desired) ~= "table" then
    return copy
  end

  for key, value in pairs(desired) do
    if type(key) == "string" and value == true then
      copy[key] = true
    end
  end

  return copy
end

function Core.desiredQuestCount(desired)
  local total = 0

  if type(desired) == "table" then
    for _, value in pairs(desired) do
      if value == true then
        total = total + 1
      end
    end
  end

  return total
end

function Core.categoryFilterEnabled(enabledCategories, category)
  if type(enabledCategories) ~= "table" then
    return false
  end

  return enabledCategories[tonumber(category) or 0] == true
end

function Core.hasEnabledCategoryFilter(enabledCategories)
  return hasEnabledValue(enabledCategories)
end

function Core.questMatchesCategoryFilter(quest, enabledCategories)
  if not Core.hasEnabledCategoryFilter(enabledCategories) then
    return true
  end

  return Core.categoryFilterEnabled(enabledCategories, Core.displayCategory(quest))
end

function Core.hasDesiredQuests(desired)
  return hasEnabledValue(desired)
end

function Core.countDesiredKnownQuests(quests, desired)
  local knownCount = 0
  local missingCount = 0
  local missingKeys = {}

  if type(desired) ~= "table" then
    return knownCount, missingCount, missingKeys
  end

  local present = knownQuestIndex(quests)

  for key, enabled in pairs(desired) do
    if enabled == true then
      if present and present[key] then
        knownCount = knownCount + 1
      else
        missingCount = missingCount + 1

        if #(missingKeys) < 3 then
          table.insert(missingKeys, tostring(key))
        end
      end
    end
  end

  return knownCount, missingCount, missingKeys
end

function Core.questCategoryCounts(quests)
  local counts = {}

  if type(quests) ~= "table" then
    return counts
  end

  for i = 1, #(quests) do
    local category = Core.displayCategory(quests[i])
    counts[category] = (counts[category] or 0) + 1
  end

  return counts
end

function Core.questInSelection(quest, selectedKeys)
  if type(selectedKeys) ~= "table" then
    return true
  end

  return selectedKeys[questIndexKey(quest) or ""] == true
end

local function byTitle(a, b)
  return (a.title or "") < (b.title or "")
end

Core.byTitle = byTitle

function Core.captureKnownQuests(existing, quests, adopt)
  local known = (adopt and type(existing) == "table") and existing or Core.copyQuestList(existing)

  if type(quests) ~= "table" then
    return known, false
  end

  local indexByKey = knownQuestIndex(known)
  local inserted = false
  local changed = false

  for i = 1, #(quests) do
    local quest = quests[i]
    local key = Core.questKey(quest)
    local title = Core.questTitle(quest)

    if key and title ~= "" and quest.category ~= nil then
      local entry = indexByKey[key]

      if entry then
        local touched = setField(entry, "title", title)
        touched = setField(entry, "questId", count(quest.questId)) or touched
        touched = setField(entry, "objectiveText", Core.objectiveText(quest)) or touched
        touched = copyContractFields(entry, quest) or touched

        if touched then
          changed = true
          Core.onKnownQuestTouched(entry)
        end
      else
        local created = Core.copyQuest({
          key = key,
          questId = quest.questId,
          title = title,
          objectiveText = Core.objectiveText(quest),
          description = quest.description,
          category = quest.category,
          cadence = quest.cadence,
          accountWide = quest.accountWide,
          ashes = quest.ashes,
          xp = quest.xp,
          copper = quest.copper,
          artisan = quest.artisan,
          item = quest.item,
          itemCount = quest.itemCount,
          orbs = quest.orbs,
          shards = quest.shards,
        })

        table.insert(known, created)
        indexByKey[key] = created
        noteIndexedQuest(known, key, created)
        inserted = true
        changed = true
      end
    end
  end

  if inserted then
    table.sort(known, byTitle)
  end

  return known, changed
end

function Core.onKnownQuestTouched()
end

AutoCallboardCore = Core
