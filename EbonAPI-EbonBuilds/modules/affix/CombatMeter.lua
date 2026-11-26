EbonBuilds.CombatMeter = {}

local CombatMeter = EbonBuilds.CombatMeter

local floor = math.floor
local GetTime = GetTime
local UnitGUID = UnitGUID

local MAX_COMBATS = 10
local MIN_DURATION = 5000
local CURRENT = MAX_COMBATS + 1
local SPELL_MIN = 150000
local SPELL_MAX = 199999

local F_DUR, F_SWING, F_SPELL, F_PERIODIC = 1, 2, 3, 4
local F_SCHOOL = 4
local F_PET, F_HITS, F_CRITS = 12, 13, 14
local F_NORMAL_DMG, F_NORMAL_HITS, F_CRIT_DMG = 15, 16, 17
local F_CASTS, F_TAKEN_PHYS, F_TAKEN_MAGIC = 18, 19, 20
local F_HEAL_DONE, F_HEAL_TAKEN, F_ABSORB = 21, 22, 23
local FIELDS = 23

local KIND_SWING, KIND_SPELL, KIND_PERIODIC = 1, 2, 3

local slots = {}
for i = 1, CURRENT do
    local s = {}
    for f = 1, FIELDS do s[f] = 0 end
    slots[i] = s
end

local spells = {}
local sums = {}
for f = 1, FIELDS do sums[f] = 0 end

local out = {
    combats = 0, durationMs = 0,
    dmg = 0, dmgSwing = 0, dmgSpell = 0, dmgPeriodic = 0,
    dmgPhys = 0, dmgHoly = 0, dmgFire = 0, dmgNature = 0,
    dmgFrost = 0, dmgShadow = 0, dmgArcane = 0,
    petDmg = 0, hits = 0, crits = 0, critPct = 0,
    avgNormal = 0, avgCrit = 0, casts = 0,
    takenPhys = 0, takenMagic = 0,
    healDone = 0, healTaken = 0, absorb = 0,
}


local mine = {}
local playerGUID = nil
local petGUID = nil
local inCombat = false
local startTime = 0
local count = 0
local head = 1

local function ClearSlot(s)
    for f = 1, FIELDS do s[f] = 0 end
end

local function SetGUIDs(player, pet)
    if playerGUID then mine[playerGUID] = nil end
    if petGUID then mine[petGUID] = nil end
    playerGUID = player
    petGUID = pet
    if petGUID then mine[petGUID] = 2 end
    if playerGUID then mine[playerGUID] = 1 end
end

local function SchoolField(school)
    if not school or school < 1 then return F_SCHOOL + 1 end
    local bit = 1
    for k = 1, 7 do
        if school % (bit * 2) >= bit then return F_SCHOOL + k end
        bit = bit * 2
    end
    return F_SCHOOL + 1
end

local function RecordSpell(id, amount)
    local rec = spells[id]
    if not rec then
        rec = { d = {}, t = {} }
        for i = 1, CURRENT do rec.d[i] = 0; rec.t[i] = 0 end
        spells[id] = rec
    end
    rec.d[CURRENT] = rec.d[CURRENT] + amount
    rec.t[CURRENT] = rec.t[CURRENT] + 1
end

local function Damage(sm, dm, kind, spellId, amount, school, crit)
    amount = amount or 0
    local cur = slots[CURRENT]
    if sm == 1 then
        local f = F_SWING
        if kind == KIND_SPELL then f = F_SPELL elseif kind == KIND_PERIODIC then f = F_PERIODIC end
        cur[f] = cur[f] + amount
        local sf = SchoolField(school)
        cur[sf] = cur[sf] + amount
        cur[F_HITS] = cur[F_HITS] + 1
        if crit then
            cur[F_CRITS] = cur[F_CRITS] + 1
            cur[F_CRIT_DMG] = cur[F_CRIT_DMG] + amount
        else
            cur[F_NORMAL_HITS] = cur[F_NORMAL_HITS] + 1
            cur[F_NORMAL_DMG] = cur[F_NORMAL_DMG] + amount
        end
        if spellId and spellId >= SPELL_MIN and spellId <= SPELL_MAX then
            RecordSpell(spellId, amount)
        end
    elseif sm == 2 then
        cur[F_PET] = cur[F_PET] + amount
    end
    if dm == 1 then
        local tf = F_TAKEN_MAGIC
        if school == 1 then tf = F_TAKEN_PHYS end
        cur[tf] = cur[tf] + amount
    end
end

local function Heal(sm, dm, amount)
    amount = amount or 0
    local cur = slots[CURRENT]
    if sm == 1 then cur[F_HEAL_DONE] = cur[F_HEAL_DONE] + amount end
    if dm == 1 then cur[F_HEAL_TAKEN] = cur[F_HEAL_TAKEN] + amount end
end

function CombatMeter.OnCombatLog(timestamp, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
    local sm = mine[srcGUID]
    local dm = mine[dstGUID]
    if not sm and not dm then return end
    if not inCombat then return end
    if sub == "SWING_DAMAGE" then
        Damage(sm, dm, KIND_SWING, nil, a1, a3, a7)
    elseif sub == "SPELL_DAMAGE" or sub == "RANGE_DAMAGE" then
        Damage(sm, dm, KIND_SPELL, a1, a4, a6, a10)
    elseif sub == "SPELL_PERIODIC_DAMAGE" then
        Damage(sm, dm, KIND_PERIODIC, a1, a4, a6, a10)
    elseif sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
        Heal(sm, dm, a4)
    elseif sub == "SPELL_MISSED" then
        if dm == 1 and a4 == "ABSORB" then
            local cur = slots[CURRENT]
            cur[F_ABSORB] = cur[F_ABSORB] + (a5 or 0)
        end
    elseif sub == "SPELL_CAST_SUCCESS" then
        if sm == 1 then
            local cur = slots[CURRENT]
            cur[F_CASTS] = cur[F_CASTS] + 1
        end
    end
end

function CombatMeter.OnRegenDisabled()
    local g = UnitGUID("player")
    if g ~= playerGUID then SetGUIDs(g, petGUID) end
    ClearSlot(slots[CURRENT])
    for _, rec in pairs(spells) do
        rec.d[CURRENT] = 0
        rec.t[CURRENT] = 0
    end
    inCombat = true
    startTime = GetTime()
end

function CombatMeter.OnRegenEnabled()
    if not inCombat then return end
    inCombat = false
    local dur = floor((GetTime() - startTime) * 1000)
    if dur < MIN_DURATION then return end
    local cur = slots[CURRENT]
    cur[F_DUR] = dur
    local slot = slots[head]
    for f = 1, FIELDS do slot[f] = cur[f] end
    for _, rec in pairs(spells) do
        rec.d[head] = rec.d[CURRENT]
        rec.t[head] = rec.t[CURRENT]
    end
    head = head % MAX_COMBATS + 1
    if count < MAX_COMBATS then count = count + 1 end
end

function CombatMeter.OnPetChanged()
    SetGUIDs(playerGUID, UnitGUID("pet"))
end

local function PerMinute(total, dur)
    return floor(total * 60000 / dur)
end

function CombatMeter.Read()
    for f = 1, FIELDS do sums[f] = 0 end
    for i = 1, MAX_COMBATS do
        local s = slots[i]
        for f = 1, FIELDS do sums[f] = sums[f] + s[f] end
    end
    local dur = sums[F_DUR]
    out.combats = count
    out.durationMs = dur
    if dur <= 0 then
        out.dmg, out.dmgSwing, out.dmgSpell, out.dmgPeriodic = 0, 0, 0, 0
        out.dmgPhys, out.dmgHoly, out.dmgFire, out.dmgNature = 0, 0, 0, 0
        out.dmgFrost, out.dmgShadow, out.dmgArcane = 0, 0, 0
        out.petDmg, out.hits, out.crits, out.critPct = 0, 0, 0, 0
        out.avgNormal, out.avgCrit, out.casts = 0, 0, 0
        out.takenPhys, out.takenMagic = 0, 0
        out.healDone, out.healTaken, out.absorb = 0, 0, 0
        out.combats = 0
        return out
    end
    out.dmg = PerMinute(sums[F_SWING] + sums[F_SPELL] + sums[F_PERIODIC], dur)
    out.dmgSwing = PerMinute(sums[F_SWING], dur)
    out.dmgSpell = PerMinute(sums[F_SPELL], dur)
    out.dmgPeriodic = PerMinute(sums[F_PERIODIC], dur)
    out.dmgPhys = PerMinute(sums[F_SCHOOL + 1], dur)
    out.dmgHoly = PerMinute(sums[F_SCHOOL + 2], dur)
    out.dmgFire = PerMinute(sums[F_SCHOOL + 3], dur)
    out.dmgNature = PerMinute(sums[F_SCHOOL + 4], dur)
    out.dmgFrost = PerMinute(sums[F_SCHOOL + 5], dur)
    out.dmgShadow = PerMinute(sums[F_SCHOOL + 6], dur)
    out.dmgArcane = PerMinute(sums[F_SCHOOL + 7], dur)
    out.petDmg = PerMinute(sums[F_PET], dur)
    out.hits = sums[F_HITS]
    out.crits = sums[F_CRITS]
    out.critPct = 0
    if out.hits > 0 then out.critPct = floor(out.crits * 100 / out.hits) end
    out.avgNormal = 0
    if sums[F_NORMAL_HITS] > 0 then out.avgNormal = floor(sums[F_NORMAL_DMG] / sums[F_NORMAL_HITS]) end
    out.avgCrit = 0
    if out.crits > 0 then out.avgCrit = floor(sums[F_CRIT_DMG] / out.crits) end
    out.casts = PerMinute(sums[F_CASTS], dur)
    out.takenPhys = PerMinute(sums[F_TAKEN_PHYS], dur)
    out.takenMagic = PerMinute(sums[F_TAKEN_MAGIC], dur)
    out.healDone = PerMinute(sums[F_HEAL_DONE], dur)
    out.healTaken = PerMinute(sums[F_HEAL_TAKEN], dur)
    out.absorb = PerMinute(sums[F_ABSORB], dur)
    return out
end

function CombatMeter.ReadSpell(spellId)
    local rec = spellId and spells[spellId]
    if not rec then return 0, 0 end
    local dur, d, t = 0, 0, 0
    for i = 1, MAX_COMBATS do
        dur = dur + slots[i][F_DUR]
        d = d + rec.d[i]
        t = t + rec.t[i]
    end
    if dur <= 0 then return 0, 0 end
    return PerMinute(d, dur), PerMinute(t, dur)
end

function CombatMeter.HasEnoughData()
    return count >= 1
end

function CombatMeter.Reset()
    for i = 1, CURRENT do ClearSlot(slots[i]) end
    for _, rec in pairs(spells) do
        for i = 1, CURRENT do
            rec.d[i] = 0
            rec.t[i] = 0
        end
    end
    count = 0
    head = 1
    inCombat = false
end

function CombatMeter.Init()
    SetGUIDs(UnitGUID("player"), UnitGUID("pet"))
    EbonBuilds.Events.On("COMBAT_LOG_EVENT_UNFILTERED", CombatMeter.OnCombatLog, "CombatMeter")
    EbonBuilds.Events.On("PLAYER_REGEN_DISABLED", CombatMeter.OnRegenDisabled, "CombatMeter")
    EbonBuilds.Events.On("PLAYER_REGEN_ENABLED", CombatMeter.OnRegenEnabled, "CombatMeter")
    EbonBuilds.Events.On("UNIT_PET", function(unit)
        if unit == "player" then CombatMeter.OnPetChanged() end
    end, "CombatMeterPet")
end
