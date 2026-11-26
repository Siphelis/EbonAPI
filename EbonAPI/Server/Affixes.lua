EbonAPI = EbonAPI or {}
EbonAPI.Affixes = {}

local Affixes = EbonAPI.Affixes
local Bus = EbonAPI.Bus

local type, pairs, tonumber, strsplit, gsub, concat = type, pairs, tonumber, strsplit, string.gsub, table.concat
local sub = string.sub

local MIN_ENCHANT = 10000
local CHANGE_ID = "affixes-changed"
local CHANGE_DELAY = 0.2
local OPCODE_LEARNED = 513

local learnedReceived = false
local learnedSpells = nil
local learnedFamilies = {}
local linePrefixes = {}
local bagSignature = nil

local function database()
  local pe = _G.ProjectEbonhold
  local db = pe and pe.AffixDatabase

  if type(db) ~= "table" then
    return nil
  end

  return db
end

local function resolve(index, key)
  local db = database()
  local ref = db and db[index] and db[index][key]

  if not ref or not db.families then
    return nil
  end

  local family = db.families[ref.familyId]

  if not family then
    return nil
  end

  return { familyId = ref.familyId, rank = ref.rank, family = family, entry = family.ranks and family.ranks[ref.rank] }
end

local function enchantOf(link)
  if type(link) ~= "string" then
    return nil
  end

  local field = select(8, strsplit(":", link))
  local enchantId = tonumber(field)

  if not enchantId or enchantId < MIN_ENCHANT then
    return nil
  end

  return enchantId
end

local function describe(link)
  local enchantId = enchantOf(link)

  if not enchantId then
    return nil
  end

  local found = resolve("byEnchant", enchantId)

  if not found then
    return nil
  end

  return {
    familyId = found.familyId,
    rank = found.rank,
    enchantId = enchantId,
    spellId = found.entry and found.entry.spellId,
    family = found.family,
    entry = found.entry,
  }
end

function Affixes.GetFamilies()
  local db = database()

  return db and db.families or nil
end

function Affixes.GetBySpell(spellId)
  return resolve("bySpell", spellId)
end

function Affixes.GetByEnchant(enchantId)
  return resolve("byEnchant", enchantId)
end

local scratch = { name = nil, familyName = nil }

local function service()
  local value = _G.ExtractionService

  return type(value) == "table" and value or nil
end

function Affixes.GetFamilyName(family)
  local original = type(family) == "table" and family.name

  if type(original) ~= "string" then
    return nil
  end

  local source = service()

  if source and type(source.DisplayName) == "function" then
    scratch.name = original
    scratch.familyName = original

    local ok, translated = pcall(source.DisplayName, scratch)

    scratch.name = nil
    scratch.familyName = nil

    if ok and type(translated) == "string" and translated ~= "" then
      return translated
    end
  end

  return original
end

local function hasMarkers(text)
  return type(text) == "string" and text:find("@value@", 1, true) ~= nil
end

local function templateOf(entry)
  local original = entry.text
  local source = service()

  if source and type(source.DisplayText) == "function" then
    local ok, translated = pcall(source.DisplayText, entry)

    if ok and type(translated) == "string" and translated ~= "" and (hasMarkers(translated) or not hasMarkers(original)) then
      return translated
    end
  end

  return original
end

function Affixes.RenderText(entry, twoHanded)
  if type(entry) ~= "table" or type(entry.text) ~= "string" then
    return nil
  end

  local template = templateOf(entry)
  local ui = _G.ExtractionUI
  local render = type(ui) == "table" and ui.RenderAffixText

  if type(render) == "function" then
    local rendered = render(template, twoHanded)

    if rendered then
      return rendered
    end
  end

  local text = gsub(template, "@value@(.-)@value@", "%1")

  return (gsub(text, "@range@(.-)@range@", "%1"))
end

function Affixes.AllowedCategories(equipLoc)
  local source = EbonAPI.AffixSlots

  if type(source) ~= "table" then
    return nil
  end

  return source[equipLoc]
end

function Affixes.GetEquipped()
  local result = {}

  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    local info = link and describe(link)

    if info then
      result[slot] = { slot = slot, itemLink = link, familyId = info.familyId, rank = info.rank, enchantId = info.enchantId, spellId = info.spellId }
    end
  end

  return result
end

function Affixes.GetBagged()
  local result = {}

  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local link = GetContainerItemLink(bag, slot)
      local info = link and describe(link)

      if info then
        result[#result + 1] = { bag = bag, slot = slot, itemLink = link, familyId = info.familyId, rank = info.rank, enchantId = info.enchantId, spellId = info.spellId }
      end
    end
  end

  return result
end

function Affixes.IsLearnedReceived()
  return learnedReceived
end

function Affixes.GetLearned()
  if not learnedReceived then
    return nil
  end

  local result = {}

  for index = 1, #learnedSpells do
    local found = resolve("bySpell", learnedSpells[index])

    if found and found.entry then
      result[#result + 1] = { familyId = found.familyId, rank = found.rank, spellId = found.entry.spellId, enchantId = found.entry.enchantId }
    end
  end

  return result
end

function Affixes.GetFromLink(link)
  local info = describe(link)

  if not info then
    return nil
  end

  local family = info.family

  return {
    familyId = info.familyId,
    rank = info.rank,
    enchantId = info.enchantId,
    spellId = info.spellId,
    name = family and Affixes.GetFamilyName(family),
    text = Affixes.RenderText(info.entry),
  }
end

function Affixes.GetEffect(enchantId)
  return EbonAPI.AffixEffects and EbonAPI.AffixEffects[enchantId]
end

local PREFIX_LENGTH = 24
local MAX_SCAN = 6

local function normalize(text)
  if type(text) ~= "string" then
    return ""
  end

  text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = gsub(text, "|r", "")
  text = gsub(text, "@value@", "")
  text = gsub(text, "@range@", "")

  return (gsub(text, "[%d%p%s]", ""))
end

local function prefixesFor(enchantId)
  local cached = linePrefixes[enchantId]

  if cached then
    return cached
  end

  local found = resolve("byEnchant", enchantId)
  local entry = found and found.entry

  if not entry or type(entry.text) ~= "string" then
    return nil
  end

  local list = {}
  local sources = { entry.text }
  local service = _G.ExtractionService
  local display = type(service) == "table" and type(service.DisplayText) == "function" and service.DisplayText(entry)

  if type(display) == "string" and display ~= "" then
    sources[#sources + 1] = display
  end

  for index = 1, #sources do
    local prefix = sub(normalize(sources[index]), 1, PREFIX_LENGTH)

    if prefix ~= "" then
      list[#list + 1] = prefix
    end
  end

  if #list == 0 then
    return nil
  end

  linePrefixes[enchantId] = list

  return list
end

function Affixes.IsLearned(enchantId)
  if not learnedReceived or type(enchantId) ~= "number" then
    return false
  end

  local found = resolve("byEnchant", enchantId)

  return found ~= nil and learnedFamilies[found.familyId] == true
end

local function matches(prefixes, current)
  local flat = normalize(current)

  for position = 1, #prefixes do
    if flat:find(prefixes[position], 1, true) then
      return true
    end
  end

  return false
end

function Affixes.FindTooltipLine(tooltip, enchantId, hint, name)
  name = name or (tooltip and tooltip:GetName())

  if not name then
    return nil
  end

  local prefixes = prefixesFor(enchantId)

  if not prefixes then
    return nil
  end

  if hint then
    local line = _G[name .. "TextLeft" .. hint]
    local current = line and line:GetText()

    if current and matches(prefixes, current) then
      return line, current, hint
    end
  end

  local last = tooltip:NumLines()

  if last > MAX_SCAN + 1 then
    last = MAX_SCAN + 1
  end

  for index = 2, last do
    local line = _G[name .. "TextLeft" .. index]
    local current = line and line:GetText()

    if current and matches(prefixes, current) then
      return line, current, index
    end
  end

  return nil
end

local function changed()
  Bus.after(CHANGE_ID, CHANGE_DELAY, function()
    EbonAPI:Emit("AFFIXES_CHANGED")
  end)
end

local function signature()
  local parts = {}

  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      parts[#parts + 1] = GetContainerItemLink(bag, slot) or ""
    end
  end

  return concat(parts, "|")
end

local function onBagUpdate()
  local current = signature()

  if current == bagSignature then
    return
  end

  bagSignature = current
  changed()
end

Bus.on("PLAYER_EQUIPMENT_CHANGED", changed)
Bus.on("BAG_UPDATE", onBagUpdate)

local function subscribeLearned()
  local Decoders = EbonAPI.Decoders

  if not (Decoders and Decoders.subscribe) then
    return false
  end

  return Decoders.subscribe(OPCODE_LEARNED, function(value)
    learnedSpells = type(value) == "table" and value.spellIds or {}
    learnedFamilies = {}
    for index = 1, #learnedSpells do
      local found = resolve("bySpell", learnedSpells[index])
      if found then
        learnedFamilies[found.familyId] = true
      end
    end
    learnedReceived = true
    changed()
  end)
end

local function onPlayerLogin()
  if subscribeLearned() then
    return
  end

  Bus.after("affixes-learned-sub", 1, function()
    subscribeLearned()
  end)
end

Bus.on("PLAYER_LOGIN", onPlayerLogin, "EbonAPI.Affixes")
