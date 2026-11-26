EbonAPI = EbonAPI or {}
EbonAPI.ClientData = {}

local ClientData = EbonAPI.ClientData
local EchoCatalog = EbonAPI.EchoCatalog
local Handle = EbonAPI.Handle

local type, ipairs, floor = type, ipairs, math.floor

local CLASS_TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles"
local FAMILY_ART = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\"

local CLASS_ORDER = {
  { token = "WARRIOR", label = "Warrior", specs = {
    { "Arms", "Interface\\Icons\\Ability_Rogue_Eviscerate" },
    { "Fury", "Interface\\Icons\\Ability_Warrior_InnerRage" },
    { "Protection", "Interface\\Icons\\INV_Shield_06" } } },
  { token = "PALADIN", label = "Paladin", specs = {
    { "Holy", "Interface\\Icons\\Spell_Holy_HolyBolt" },
    { "Protection", "Interface\\Icons\\Spell_Holy_DevotionAura" },
    { "Retribution", "Interface\\Icons\\Spell_Holy_AuraOfLight" } } },
  { token = "HUNTER", label = "Hunter", specs = {
    { "Beast Mastery", "Interface\\Icons\\Ability_Hunter_BeastTaming" },
    { "Marksmanship", "Interface\\Icons\\Ability_Marksmanship" },
    { "Survival", "Interface\\Icons\\Ability_Hunter_SwiftStrike" } } },
  { token = "ROGUE", label = "Rogue", specs = {
    { "Assassination", "Interface\\Icons\\Ability_Rogue_Eviscerate" },
    { "Combat", "Interface\\Icons\\Ability_BackStab" },
    { "Subtlety", "Interface\\Icons\\Ability_Stealth" } } },
  { token = "PRIEST", label = "Priest", specs = {
    { "Discipline", "Interface\\Icons\\Spell_Holy_WordFortitude" },
    { "Holy", "Interface\\Icons\\Spell_Holy_GuardianSpirit" },
    { "Shadow", "Interface\\Icons\\Spell_Shadow_ShadowWordPain" } } },
  { token = "DEATHKNIGHT", label = "Death Knight", specs = {
    { "Blood", "Interface\\Icons\\Spell_Deathknight_BloodPresence" },
    { "Frost", "Interface\\Icons\\Spell_Deathknight_FrostPresence" },
    { "Unholy", "Interface\\Icons\\Spell_Deathknight_UnholyPresence" } } },
  { token = "SHAMAN", label = "Shaman", specs = {
    { "Elemental", "Interface\\Icons\\Spell_Nature_Lightning" },
    { "Enhancement", "Interface\\Icons\\Spell_Nature_LightningShield" },
    { "Restoration", "Interface\\Icons\\Spell_Nature_MagicImmunity" } } },
  { token = "MAGE", label = "Mage", specs = {
    { "Arcane", "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    { "Fire", "Interface\\Icons\\Spell_Fire_FireBolt02" },
    { "Frost", "Interface\\Icons\\Spell_Frost_FrostBolt02" } } },
  { token = "WARLOCK", label = "Warlock", specs = {
    { "Affliction", "Interface\\Icons\\Spell_Shadow_DeathCoil" },
    { "Demonology", "Interface\\Icons\\Spell_Shadow_Metamorphosis" },
    { "Destruction", "Interface\\Icons\\Spell_Shadow_RainOfFire" } } },
  { token = "DRUID", label = "Druid", specs = {
    { "Balance", "Interface\\Icons\\Spell_Nature_StarFall" },
    { "Feral Combat", "Interface\\Icons\\Ability_Racial_BearForm" },
    { "Restoration", "Interface\\Icons\\Spell_Nature_HealingTouch" } } },
}

local QUALITY_DATA = {
  { name = "Common", hex = "ffffff" },
  { name = "Uncommon", hex = "19ff19" },
  { name = "Rare", hex = "0066ff" },
  { name = "Epic", hex = "cc66ff" },
  { name = "Legendary", hex = "ff8000" },
}

local FAMILY_DATA = {
  { key = "Tank", icon = FAMILY_ART .. "tank" },
  { key = "Survivability", icon = FAMILY_ART .. "survivability" },
  { key = "Healer", icon = FAMILY_ART .. "healer" },
  { key = "Caster", icon = FAMILY_ART .. "caster_dps" },
  { key = "Melee", icon = FAMILY_ART .. "melee_dps" },
  { key = "Ranged", icon = FAMILY_ART .. "ranged_dps" },
  { key = "No family" },
}

local FAMILY_ALIASES = {
  ["Caster DPS"] = "Caster",
  ["Melee DPS"] = "Melee",
  ["Ranged DPS"] = "Ranged",
}

local classes, classByToken, specByKey, qualities, families, writtenLanguage

local function specName(spec)
  local L = EbonAPI.L
  local text = L and L["SPEC_" .. spec.class .. "_" .. spec.index]

  if type(text) == "string" and text ~= "" then
    return text
  end

  return spec.english
end

local function clientColor(token)
  local colors = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[token]

  if type(colors) == "table" and type(colors.r) == "number" and type(colors.g) == "number"
    and type(colors.b) == "number" then
    return colors.r, colors.g, colors.b
  end

  return 0.5, 0.5, 0.5
end

local function clientCoords(token)
  local source = type(CLASS_ICON_TCOORDS) == "table" and CLASS_ICON_TCOORDS[token]

  if type(source) == "table" and type(source[1]) == "number" and type(source[2]) == "number"
    and type(source[3]) == "number" and type(source[4]) == "number" then
    return { source[1], source[2], source[3], source[4] }
  end

  return { 0, 1, 0, 1 }
end

local function clientName(token)
  local names = type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE[token]

  if type(names) == "string" and names ~= "" then
    return names
  end

  return token
end

local function build()
  classes, classByToken, specByKey = {}, {}, {}

  for index, data in ipairs(CLASS_ORDER) do
    local r, g, b = clientColor(data.token)
    local card = {
      token = data.token,
      index = index,
      name = clientName(data.token),
      r = r,
      g = g,
      b = b,
      bit = EchoCatalog.ClassBit(data.token),
      texture = CLASS_TEXTURE,
      coords = clientCoords(data.token),
      specs = {},
    }

    for specIndex, entry in ipairs(data.specs) do
      local key = data.label .. " - " .. entry[1]
      local spec = {
        class = data.token,
        index = specIndex,
        key = key,
        icon = entry[2],
        english = entry[1],
      }

      spec.name = specName(spec)
      card.specs[specIndex] = spec
      specByKey[key] = spec
    end

    classes[index] = card
    classByToken[data.token] = card
  end
end

local function currentLanguage()
  local Locale = EbonAPI.Locale

  if type(Locale) == "table" and type(Locale.current) == "function" then
    return Locale.current()
  end

  return nil
end

local function ready()
  if not classes then
    build()
  end

  local language = currentLanguage()

  if language ~= nil and language == writtenLanguage then
    return
  end

  for _, card in ipairs(classes) do
    for _, spec in ipairs(card.specs) do
      spec.name = specName(spec)
    end
  end

  writtenLanguage = language
end

function ClientData.Classes()
  ready()
  return classes
end

function ClientData.Class(token)
  if type(token) ~= "string" then
    return nil
  end

  ready()
  return classByToken[token]
end

function ClientData.Spec(token, index)
  local card = ClientData.Class(token)

  if not card or type(index) ~= "number" then
    return nil
  end

  return card.specs[index]
end

function ClientData.SpecByKey(key)
  if type(key) ~= "string" then
    return nil
  end

  ready()
  return specByKey[key]
end

local function buildQualities()
  qualities = {}

  for index, data in ipairs(QUALITY_DATA) do
    local name = type(_G) == "table" and _G["ITEM_QUALITY" .. index .. "_DESC"]
    local hex = data.hex

    qualities[index] = {
      index = index - 1,
      name = (type(name) == "string" and name ~= "") and name or data.name,
      r = tonumber(hex:sub(1, 2), 16) / 255,
      g = tonumber(hex:sub(3, 4), 16) / 255,
      b = tonumber(hex:sub(5, 6), 16) / 255,
      hex = hex,
    }
  end
end

function ClientData.Qualities()
  if not qualities then
    buildQualities()
  end

  return qualities
end

function ClientData.Quality(q)
  if type(q) ~= "number" or q ~= floor(q) or q < 0 or q > 4 then
    return nil
  end

  return ClientData.Qualities()[q + 1]
end

function ClientData.Families()
  if not families then
    families = {}

    for index, data in ipairs(FAMILY_DATA) do
      families[index] = { key = data.key, icon = data.icon }
    end
  end

  return families
end

function ClientData.Family(raw)
  if raw == nil or raw == "None" then
    return "No family"
  end

  return FAMILY_ALIASES[raw] or raw
end

function Handle:ClientData()
  return ClientData
end
