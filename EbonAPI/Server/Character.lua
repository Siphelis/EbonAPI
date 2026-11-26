EbonAPI = EbonAPI or {}
EbonAPI.Character = {}

local Character = EbonAPI.Character
local Lib = EbonAPI.Lib
local Bus = EbonAPI.Bus

local cache = nil
local dirty = true

local OWNER = "EbonAPI.Character"

local function rating(constant, fallback)
  return GetCombatRating(constant or fallback) or 0
end

local function build()
  local stats = {}

  stats.level = UnitLevel("player")
  local _, classToken = UnitClass("player")
  stats.classToken = classToken

  local _, strength = UnitStat("player", 1)
  local _, agility = UnitStat("player", 2)
  local _, stamina = UnitStat("player", 3)
  local _, intellect = UnitStat("player", 4)
  local _, spirit = UnitStat("player", 5)
  stats.strength = strength
  stats.agility = agility
  stats.stamina = stamina
  stats.intellect = intellect
  stats.spirit = spirit

  local apBase, apPos, apNeg = UnitAttackPower("player")
  stats.attackPower = (apBase or 0) + (apPos or 0) + (apNeg or 0)
  local rapBase, rapPos, rapNeg = UnitRangedAttackPower("player")
  stats.rangedAttackPower = (rapBase or 0) + (rapPos or 0) + (rapNeg or 0)

  local spellPower = {}
  for school = 1, 7 do
    spellPower[school] = GetSpellBonusDamage(school)
  end
  stats.spellPower = spellPower

  local _, effectiveArmor = UnitArmor("player")
  stats.armor = effectiveArmor
  stats.health = UnitHealthMax("player")
  stats.power = UnitPowerMax and UnitPowerMax("player", 0) or UnitManaMax("player")
  stats.powerType = UnitPowerType("player")

  stats.critMelee = GetCritChance()
  stats.critRanged = GetRangedCritChance()
  stats.critSpell = GetSpellCritChance(2)
  stats.critRatingMelee = rating(CR_CRIT_MELEE, 9)
  stats.critRatingRanged = rating(CR_CRIT_RANGED, 10)
  stats.critRatingSpell = rating(CR_CRIT_SPELL, 11)

  local hasteConstant = CR_HASTE_MELEE or 18
  stats.hasteRating = GetCombatRating(hasteConstant) or 0
  stats.hastePercent = GetCombatRatingBonus(hasteConstant)

  local hitConstant = CR_HIT_MELEE or 6
  stats.hitRating = GetCombatRating(hitConstant) or 0
  stats.hitPercent = GetCombatRatingBonus(hitConstant)

  local expertiseConstant = CR_EXPERTISE or 24
  stats.expertiseRating = GetCombatRating(expertiseConstant) or 0
  stats.expertisePercent = GetExpertise()

  local armorPenConstant = CR_ARMOR_PENETRATION or 25
  stats.armorPenRating = GetCombatRating(armorPenConstant) or 0
  stats.armorPenPercent = GetArmorPenetration()

  stats.defenseRating = GetCombatRating(2) or 0
  stats.resilienceRating = GetCombatRating(17) or 0

  local minMain, maxMain, minOff, maxOff = UnitDamage("player")
  local mainSpeed, offSpeed = UnitAttackSpeed("player")
  stats.melee = {
    min = minMain or 0,
    max = maxMain or 0,
    speed = mainSpeed or 0,
    offMin = minOff or 0,
    offMax = maxOff or 0,
    offSpeed = offSpeed or 0,
  }

  local rangedSpeed, minRanged, maxRanged = UnitRangedDamage("player")
  stats.ranged = {
    min = minRanged or 0,
    max = maxRanged or 0,
    speed = rangedSpeed or 0,
  }

  local mainHandLink = GetInventoryItemLink("player", 16)
  local equipSlot = nil
  if mainHandLink then
    equipSlot = select(9, GetItemInfo(mainHandLink))
  end
  stats.twoHanded = equipSlot == "INVTYPE_2HWEAPON"
  stats.titanGrip = (IsSpellKnown and IsSpellKnown(46917)) and true or false

  return stats
end

local function markDirty()
  dirty = true
end

function Character.GetStats()
  if dirty or not cache then
    cache = build()
    dirty = false
  end

  return Lib.copyDeep(cache)
end

local EVENTS = {
  "UNIT_STATS",
  "UNIT_AURA",
  "UNIT_DAMAGE",
  "UNIT_ATTACK_SPEED",
  "UNIT_ATTACK_POWER",
  "UNIT_MAXHEALTH",
  "UNIT_MAXPOWER",
  "UNIT_LEVEL",
  "PLAYER_LEVEL_UP",
  "PLAYER_EQUIPMENT_CHANGED",
  "COMBAT_RATING_UPDATE",
  "SPELLS_CHANGED",
}

for i = 1, #EVENTS do
  Bus.on(EVENTS[i], markDirty, OWNER)
end
