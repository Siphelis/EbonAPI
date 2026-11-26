EbonAPI = EbonAPI or {}
EbonAPI.EchoCatalog = {}

local EchoCatalog = EbonAPI.EchoCatalog
local Ebonhold = EbonAPI.Ebonhold
local Handle = EbonAPI.Handle
local Problems = EbonAPI.Problems

local type, next, pairs = type, next, pairs

Problems.declare("EbonAPI", "EBONAPI", {
  ["ECHOES.CATALOG_MISSING"] = { class = "echec" },
})

local missingOpen = false

function EchoCatalog.Database()
  local database = Ebonhold.PerkDatabase()

  if type(database) ~= "table" or next(database) == nil then
    if not missingOpen then
      Problems.report(Problems.new("EbonAPI", "ECHOES.CATALOG_MISSING", { reason = "source_missing" }))
      missingOpen = true
    end

    return nil, "source_missing"
  end

  if missingOpen then
    missingOpen = false
    Problems.restore("EbonAPI", "ECHOES.CATALOG_MISSING")
  end

  return database
end

function EchoCatalog.Entry(spellId)
  if type(spellId) ~= "number" then
    return nil
  end

  local database = EchoCatalog.Database()

  if not database then
    return nil
  end

  return database[spellId]
end

function EchoCatalog.Count()
  local database = EchoCatalog.Database()
  local count = 0

  if not database then
    return count
  end

  for _ in pairs(database) do
    count = count + 1
  end

  return count
end

function Handle:EchoCatalog()
  return EchoCatalog
end

local ipairs = ipairs
local sort = table.sort

local QUALITY_SUFFIXES = {
  " %- Common$", " %- Uncommon$", " %- Rare$", " %- Epic$", " %- Legendary$",
}

local CLASS_BITS = {
  WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
  DEATHKNIGHT = 32, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024,
}

local sortedIds, sortedSource
local groupsCache, namesCache, qualitiesCache

local function stripQuality(text)
  for _, pattern in ipairs(QUALITY_SUFFIXES) do
    local stripped = text:match("^(.+)" .. pattern)

    if stripped then
      return stripped
    end
  end

  return text
end

local function idsOf(database)
  if sortedSource ~= database then
    local ids = {}

    for spellId in pairs(database) do
      if type(spellId) == "number" then
        ids[#ids + 1] = spellId
      end
    end

    sort(ids)
    sortedIds, sortedSource = ids, database
  end

  return sortedIds
end

local function groupsOf(database)
  if groupsCache and groupsCache.source == database then
    return groupsCache
  end

  local keys, members = {}, {}

  for _, spellId in ipairs(idsOf(database)) do
    local group = database[spellId].groupId
    local key = (type(group) == "number" and group > 0) and group or spellId
    local list = members[key]

    keys[spellId] = key

    if not list then
      list = {}
      members[key] = list
    end

    list[#list + 1] = spellId
  end

  groupsCache = { source = database, keys = keys, members = members }

  return groupsCache
end

local function namesOf(database)
  if namesCache and namesCache.source == database then
    return namesCache
  end

  local names, nameOf, variants = {}, {}, {}

  for _, spellId in ipairs(idsOf(database)) do
    local data = database[spellId]
    local raw = data.comment

    if type(raw) == "string" and raw ~= "" then
      local name = stripQuality(raw)
      local quality = data.quality
      local mask = data.classMask or 0
      local existing = names[name]

      nameOf[spellId] = name

      if not existing then
        existing = {
          spellId = spellId,
          quality = quality,
          qualities = {},
          families = data.families or {},
          classMask = mask,
          spellIds = {},
        }
        names[name] = existing
        variants[name] = {}
      else
        existing.classMask = bit.bor(existing.classMask, mask)

        if quality > existing.quality then
          existing.spellId = spellId
          existing.quality = quality
          existing.families = data.families or {}
        end
      end

      existing.qualities[quality] = true

      if not existing.spellIds[quality] then
        existing.spellIds[quality] = spellId
      end

      variants[name][#variants[name] + 1] = spellId
    end
  end

  for _, list in pairs(variants) do
    sort(list, function(a, b)
      local qa, qb = database[a].quality, database[b].quality

      if qa ~= qb then
        return qa < qb
      end

      return a < b
    end)
  end

  namesCache = { source = database, names = names, nameOf = nameOf, variants = variants }

  return namesCache
end

function EchoCatalog.StripQuality(text)
  if type(text) ~= "string" then
    return nil, "not_a_string"
  end

  return stripQuality(text)
end

local NAME_PREFIXES = { "tome of ", "codex of ", "scroll of ", "manual of ", "grimoire of ", "libram of ", "tablet of " }
local NAME_QUALITY_SUFFIXES = { " - common", " - uncommon", " - rare", " - epic", " - legendary" }

function EchoCatalog.NormalizeName(text)
  if type(text) ~= "string" then
    return nil, "not_a_string"
  end

  local name = text:lower()

  for _, prefix in ipairs(NAME_PREFIXES) do
    if name:sub(1, #prefix) == prefix then
      name = name:sub(#prefix + 1)
      break
    end
  end

  for _, suffix in ipairs(NAME_QUALITY_SUFFIXES) do
    if name:sub(-#suffix) == suffix then
      name = name:sub(1, -(#suffix + 1))
      break
    end
  end

  return name
end

function EchoCatalog.BaseName(spellId)
  if type(spellId) ~= "number" then
    return nil
  end

  local database, reason = EchoCatalog.Database()

  if not database then
    return nil, reason
  end

  local data = database[spellId]
  local raw = data and data.comment

  if type(raw) ~= "string" or raw == "" then
    return nil
  end

  return stripQuality(raw)
end

function EchoCatalog.GroupKey(spellId)
  if type(spellId) ~= "number" then
    return nil
  end

  local database, reason = EchoCatalog.Database()

  if not database then
    return spellId, reason
  end

  return groupsOf(database).keys[spellId] or spellId
end

function EchoCatalog.HasGroup(spellId)
  if type(spellId) ~= "number" then
    return nil
  end

  local database, reason = EchoCatalog.Database()

  if not database then
    return false, reason
  end

  local data = database[spellId]
  local group = data and data.groupId

  return type(group) == "number" and group > 0
end

function EchoCatalog.GroupMembers(key)
  if type(key) ~= "number" then
    return nil
  end

  local database, reason = EchoCatalog.Database()

  if not database then
    return nil, reason
  end

  return groupsOf(database).members[key]
end

function EchoCatalog.ClassBit(token)
  return CLASS_BITS[token]
end

function EchoCatalog.GroupSpell(key, classToken)
  if type(key) ~= "number" then
    return nil
  end

  local database, reason = EchoCatalog.Database()

  if not database then
    return nil, reason
  end

  local list = groupsOf(database).members[key]

  if not list then
    return key
  end

  local bitValue = classToken and CLASS_BITS[classToken]

  for i = 1, #list do
    local mask = database[list[i]].classMask or 0

    if not bitValue or mask == 0 or bit.band(mask, bitValue) ~= 0 then
      return list[i]
    end
  end

  return list[1]
end

function EchoCatalog.Names()
  local database, reason = EchoCatalog.Database()

  if not database then
    return nil, reason
  end

  return namesOf(database).names
end

function EchoCatalog.NameKey(spellId)
  if type(spellId) ~= "number" then
    return nil
  end

  local database, reason = EchoCatalog.Database()

  if not database then
    return nil, reason
  end

  return namesOf(database).nameOf[spellId]
end

function EchoCatalog.Variants(spellId)
  if type(spellId) ~= "number" then
    return nil
  end

  local database, reason = EchoCatalog.Database()

  if not database then
    return nil, reason
  end

  local cache = namesOf(database)
  local name = cache.nameOf[spellId]

  return name and cache.variants[name]
end

function EchoCatalog.NameList()
  local database, reason = EchoCatalog.Database()

  if not database then
    return nil, reason
  end

  local cache = namesOf(database)

  if not cache.list then
    local list = {}

    for name, entry in pairs(cache.names) do
      list[#list + 1] = {
        spellId = entry.spellId,
        name = name,
        lname = name:lower(),
        quality = entry.quality,
        qualities = entry.qualities,
        families = entry.families,
        classMask = entry.classMask,
        spellIds = entry.spellIds,
      }
    end

    sort(list, function(a, b)
      return a.name < b.name
    end)

    cache.list = list
  end

  return cache.list
end

function EchoCatalog.QualityList()
  local database, reason = EchoCatalog.Database()

  if not database then
    return nil, reason
  end

  if qualitiesCache and qualitiesCache.source == database then
    return qualitiesCache.list
  end

  local list = {}

  for _, spellId in ipairs(idsOf(database)) do
    local data = database[spellId]
    local raw = data.comment

    if type(raw) == "string" and raw ~= "" then
      local name = stripQuality(raw)

      list[#list + 1] = {
        spellId = spellId,
        name = name,
        lname = name:lower(),
        quality = data.quality,
        classMask = data.classMask or 0,
      }
    end
  end

  sort(list, function(a, b)
    if a.name ~= b.name then
      return a.name < b.name
    end

    if a.quality ~= b.quality then
      return a.quality < b.quality
    end

    return a.spellId < b.spellId
  end)

  qualitiesCache = { source = database, list = list }

  return list
end

function EchoCatalog.Description(spellId, stacks)
  if type(spellId) ~= "number" then
    return nil
  end

  local utils = Ebonhold.Utils()

  if not utils or type(utils.GetSpellDescription) ~= "function" then
    return nil
  end

  local ok, text = pcall(utils.GetSpellDescription, spellId, 4000, stacks or 1)

  if ok and type(text) == "string" and text ~= "" then
    return text
  end

  return nil
end
