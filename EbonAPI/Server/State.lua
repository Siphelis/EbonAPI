EbonAPI = EbonAPI or {}
EbonAPI.State = {}

local State = EbonAPI.State
local Lib = EbonAPI.Lib
local Bridge = EbonAPI.Bridge
local CS, SS = EbonAPI.CS, EbonAPI.SS

local Handle = EbonAPI.Handle
local L = EbonAPI.L
local Problems = EbonAPI.Problems

local type, tonumber, pairs, next = type, tonumber, pairs, next
local match, gmatch, format, upper, sub, find = string.match, string.gmatch, string.format, string.upper, string.sub, string.find
local max = math.max

State.MAX_ASH = "18446744073709551615"

local MAX_ASH = State.MAX_ASH
local MAX_ASH_DIGITS = #MAX_ASH

local function readAsh(text)
  local digits = match(text, "^0*(%d+)$")

  if not digits then
    return nil
  end

  local length = #digits

  if length > MAX_ASH_DIGITS or (length == MAX_ASH_DIGITS and digits > MAX_ASH) then
    return nil
  end

  return tonumber(digits)
end

State.RUN_FIELDS = {
  "soulPoints",
  "soulPointsMax",
  "acceptedRezs",
  "acceptedRezsMax",
  "selfRezs",
  "selfRezsMax",
  "classRezs",
  "classRezsMax",
  "avoidedFatalAttacks",
  "avoidedFatalAttacksMax",
  "nbResetAvoided",
  "costNextReset",
  "usedRerolls",
  "totalRerolls",
  "remainingBanishes",
  "catchupMultiplierPct",
  "usedFreezes",
  "totalFreezes",
  "hasReachedMaxLevel",
}

State.RUN_FIELDS_REQUIRED = 14

local RUN_FIELDS = State.RUN_FIELDS

local run = nil
local ash = nil
local pools = nil
local multiplier = 0
local builds = nil
local activeDesign = 0
local loadout = nil

local runFields = {}
local publishedRun = {}

local DERIVED = {
  { "countCanAcceptedRezs", "acceptedRezsMax", "acceptedRezs" },
  { "countCanSelfRezs", "selfRezsMax", "selfRezs" },
  { "countCanClassRezs", "classRezsMax", "classRezs" },
  { "countCanAvoidFatalAttacks", "avoidedFatalAttacksMax", "avoidedFatalAttacks" },
  { "remainingRerolls", "totalRerolls", "usedRerolls" },
  { "remainingFreezes", "totalFreezes", "usedFreezes" },
}

State.rejected = 0

local function reject(opcode, reason, field, body)
  State.rejected = State.rejected + 1

  Problems.reject("EbonAPI", "SERVER.BODY_REJECTED", {
    opcode = opcode, reason = reason, field = field,
    sample = type(body) == "string" and sub(body, 1, 60) or type(body),
  })
end

local function derive(data)
  for index = 1, #DERIVED do
    local entry = DERIVED[index]

    if data[entry[1]] == nil then
      data[entry[1]] = max(0, Lib.num(data[entry[2]]) - Lib.num(data[entry[3]]))
    end
  end
end

function State.parseRun(body)
  local fields, count = Lib.split(body, ";", runFields)

  if count < State.RUN_FIELDS_REQUIRED then
    reject(SS.PLAYER_RUN_DATA, "too_few_fields", "fields", body)
    return nil
  end

  if tonumber(fields[1]) == nil then
    reject(SS.PLAYER_RUN_DATA, "not_a_number", RUN_FIELDS[1], body)
    return nil
  end

  local data = {}

  for index = 1, #RUN_FIELDS do
    data[RUN_FIELDS[index]] = tonumber(fields[index]) or 0
  end

  if count < 15 then
    data.remainingBanishes = 1
  end

  data.hasReachedMaxLevel = data.hasReachedMaxLevel == 1
  data.fieldCount = count

  derive(data)

  return data
end

local function readPools(texts, first)
  if not texts[first + 5] then
    return nil
  end

  local function pair(index)
    return { spendable = tonumber(texts[index]), banked = tonumber(texts[index + 1]) }
  end

  return { shard = pair(first), essence = pair(first + 2), artisan = pair(first + 4) }
end

function State.parseBank(body)
  if type(body) ~= "string" then
    reject(SS.COMMITTED_SOUL_POINTS, "not_a_string", "body", body)
    return nil
  end

  local spendable, committed = match(body, "^(%d+),(%d+)")

  if not spendable then
    reject(SS.COMMITTED_SOUL_POINTS, "bad_format", "spendable,committed", body)
    return nil
  end

  spendable, committed = readAsh(spendable), readAsh(committed)

  if not (spendable and committed) then
    reject(SS.COMMITTED_SOUL_POINTS, "out_of_range", "spendable,committed", body)
    return nil
  end

  local texts = {}

  for number in gmatch(body, "(%d+)") do
    texts[#texts + 1] = number
  end

  return spendable, committed, readPools(texts, 3)
end

local function setPools(held)
  pools = held
  EbonAPI:Emit("SERVER_POOLS", Lib.copyDeep(pools))
end

local function setAsh(spendable, committed, source)
  if spendable == nil then
    return nil, false
  end

  local changed = ash == nil or ash.spendable ~= spendable or ash.committed ~= committed

  ash = ash or {}
  ash.spendable = spendable
  ash.committed = committed
  ash.source = source
  ash.at = (GetTime and GetTime()) or 0

  return ash, changed
end

local function readMemory(text)
  local memory = {}

  for id, stacks, remaining in gmatch(text or "", "(%d+)%.(%d+)%.(%d+)") do
    memory[#memory + 1] = { spellId = tonumber(id), stacks = tonumber(stacks), remaining = tonumber(remaining) }
  end

  return memory
end

local function readBuild(row)
  local slotText, name, kind, info, echoes, memory = match(row, "^(%d+)|([^|]*)|([01])|([%d%.]+)|([^|]*)|?(.*)$")
  local slot = tonumber(slotText)

  if not slot then
    return nil
  end

  local missing, remaining, total = match(info, "^(%d+)%.?(%d*)%.?(%d*)$")

  return {
    slot = slot,
    name = name,
    kind = kind == "0" and "wishlist" or "live",
    missing = tonumber(missing) or 0,
    memoryRemaining = tonumber(remaining) or 0,
    memoryTotal = tonumber(total) or 0,
    echoes = echoes,
    memory = readMemory(memory),
  }
end

function State.parseBuildList(body)
  if type(body) ~= "string" then
    reject(SS.BUILD_LIST, "not_a_string", "body", body)
    return nil
  end

  if body == "" then
    return { enabled = false, active = 1, design = 0, maxSlots = 0, unlocked = 0, prices = {}, slots = {} }
  end

  local parsed = { enabled = true, slots = {}, prices = {} }
  local first = true

  for chunk in gmatch(body, "[^;]+") do
    if first then
      local active, design, maxSlots, unlocked, prices = match(chunk, "^(%d+)|(%d+)|(%d+)|(%d+)|(.*)$")

      if not active then
        reject(SS.BUILD_LIST, "bad_format", "header", body)
        return nil
      end

      parsed.active = tonumber(active)
      parsed.design = tonumber(design)
      parsed.maxSlots = tonumber(maxSlots)
      parsed.unlocked = tonumber(unlocked)

      for price in gmatch(prices, "[^%.]+") do
        parsed.prices[#parsed.prices + 1] = tonumber(price) or 0
      end

      first = false
    else
      local build = readBuild(chunk)

      if build then
        parsed.slots[build.slot] = build
      end
    end
  end

  if first then
    reject(SS.BUILD_LIST, "empty", "header", body)
    return nil
  end

  return parsed
end

function State.BuildEchoes(build)
  if type(build) ~= "table" then
    return nil
  end

  local list = build.list

  if list then
    return list
  end

  list = {}

  for entry in gmatch(build.echoes or "", "[^,]+") do
    local id, stacks, locked = match(entry, "^(%d+)%.(%d+)%.(%d+)$")

    if id then
      list[#list + 1] = { spellId = tonumber(id), stacks = tonumber(stacks), locked = locked == "1" }
    end
  end

  build.list = list

  return list
end

function State.sortedBuilds()
  local sorted = {}

  if not builds or type(builds.slots) ~= "table" then
    return sorted
  end

  for slot, build in pairs(builds.slots) do
    if type(build) == "table" and tonumber(slot) then
      sorted[#sorted + 1] = build
    end
  end

  table.sort(sorted, function(a, b)
    return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0)
  end)

  return sorted
end

function State.activeBuild()
  local slot = builds and tonumber(builds.active)

  if not slot or not builds or type(builds.slots) ~= "table" then
    return nil, slot
  end

  return builds.slots[slot], slot
end

function State.parseLoadouts(body)
  if type(body) ~= "string" then
    reject(SS.SEND_LOADOUTS, "not_a_string", "body", body)
    return nil
  end

  local globalPart, loadoutsPart = match(body, "^([^_]+)_?(.*)$")

  if not globalPart then
    reject(SS.SEND_LOADOUTS, "bad_format", "global", body)
    return nil
  end

  local result = { nodes = {}, count = 0 }
  local texts = {}

  for number in gmatch(globalPart, "(%d+)") do
    texts[#texts + 1] = number
  end

  if not texts[10] then
    reject(SS.SEND_LOADOUTS, "bad_format", "header", body)
    return nil
  end

  local selectedId = tonumber(texts[1])
  local spendable, committed = readAsh(texts[2]), readAsh(texts[3])

  if spendable and committed then
    result.spendable = spendable
    result.committed = committed
  else
    reject(SS.SEND_LOADOUTS, "out_of_range", "spendable,committed", body)
  end

  result.pools = readPools(texts, 5)

  if not loadoutsPart or loadoutsPart == "" then
    return result
  end

  local exact, fallback

  for loadoutString in gmatch(loadoutsPart, "([^;]+)") do
    local parts = {}

    for part in gmatch(loadoutString, "([^,]+)") do
      parts[#parts + 1] = part
    end

    if #parts >= 3 then
      local id = tonumber(parts[1])

      if id then
        result.count = result.count + 1

        if selectedId and id == selectedId then
          exact = exact or parts
        elseif id == 0 and not fallback then
          fallback = parts
        end
      end
    end
  end

  local chosen = exact or fallback

  if not chosen then
    return result
  end

  local name = chosen[2]

  if type(name) ~= "string" or name == "" or match(name, "|") then
    reject(SS.SEND_LOADOUTS, "bad_name", "name", body)
    return result
  end

  result.id = tonumber(chosen[1])
  result.name = name

  for index = 4, #chosen do
    local nodeId, rank = match(chosen[index], "^(%d+):(%d+)$")

    nodeId = tonumber(nodeId)
    rank = tonumber(rank)

    if nodeId and rank and rank > 0 then
      result.nodes[nodeId] = rank
    end
  end

  return result
end

local function fromPublished(source)
  for key in pairs(publishedRun) do
    publishedRun[key] = nil
  end

  for key, value in pairs(source) do
    publishedRun[key] = value
  end

  derive(publishedRun)

  return publishedRun
end

function State.GetRun()
  if run then
    return run
  end

  local published = EbonAPI.Ebonhold.PublishedRunData()

  if published then
    return fromPublished(published)
  end

  local service = EbonAPI.Ebonhold.PlayerRun()

  if service and type(service.GetCurrentData) == "function" then
    local data = Lib.safeGet(service.GetCurrentData)

    if type(data) == "table" and next(data) ~= nil then
      return fromPublished(data)
    end
  end

  return nil
end

function State.GetAsh()
  return ash
end

function State.GetPools()
  return Lib.copyDeep(pools)
end

function State.GetMultiplier()
  return multiplier
end

function State.GetBuilds()
  return builds
end

function State.GetLoadout()
  return loadout
end

function State.RunAshes()
  local data = State.GetRun()

  if not data then
    return nil
  end

  return Lib.int(data.soulPoints), Lib.int(data.soulPointsMax)
end

function State.snapshot(name)
  if name == "run" then return Lib.copyDeep(State.GetRun()) end
  if name == "ash" then return Lib.copyDeep(ash) end
  if name == "pools" then return Lib.copyDeep(pools) end
  if name == "builds" then return Lib.copyDeep(builds) end
  if name == "loadout" then return Lib.copyDeep(loadout) end

  return nil
end

function State.HasServer()
  return EbonAPI.Ebonhold.IsPresent() or Bridge.seen
end

local function onRunData(body)
  local data = State.parseRun(body)

  if not data then
    return
  end

  run = data
  EbonAPI:Emit("SERVER_RUN_DATA", Lib.copyDeep(data))
end

local function onBank(body)
  if body == "" then
    return
  end

  local spendable, committed, bankPools = State.parseBank(body)

  if not spendable then
    return
  end

  local held, changed = setAsh(spendable, committed, SS.COMMITTED_SOUL_POINTS)

  if changed then
    EbonAPI:Emit("SERVER_ASH", Lib.copyDeep(held))
  end

  if bankPools then
    setPools(bankPools)
  end
end

local function onMultiplier(body)
  if body == "" then
    return
  end

  local value = tonumber(body)

  if not value then
    reject(SS.SOUL_POINTS_MULTIPLIER, "not_a_number", "multiplier", body)
    return
  end

  multiplier = value
  EbonAPI:Emit("SERVER_MULTIPLIER", multiplier)
end

local function onBuildList(body)
  local parsed = State.parseBuildList(body)

  if not parsed then
    return
  end

  builds = parsed
  activeDesign = parsed.design or 0
  EbonAPI:Emit("SERVER_BUILDS", builds)
end

local function onBuildActive(body)
  local slotText, designText = match(tostring(body), "^(%d+)|(%d+)$")
  local slot = tonumber(slotText)

  if not slot then
    reject(SS.BUILD_ACTIVE, "bad_format", "slot,design", body)
    return
  end

  if not builds then
    return
  end

  if not builds.slots[slot] then
    reject(SS.BUILD_ACTIVE, "unknown_slot", "slot", body)
    return
  end

  activeDesign = tonumber(designText) or activeDesign or 0
  builds = Lib.copyDeep(builds)
  builds.active = slot
  builds.design = activeDesign
  EbonAPI:Emit("SERVER_BUILD_ACTIVE", slot, builds, activeDesign)
end

local function onLoadouts(body)
  local parsed = State.parseLoadouts(body)

  if not parsed then
    return
  end

  loadout = parsed

  if parsed.spendable then
    local held, changed = setAsh(parsed.spendable, parsed.committed, SS.SEND_LOADOUTS)

    if changed then
      EbonAPI:Emit("SERVER_ASH", Lib.copyDeep(held))
    end
  end

  if parsed.pools then
    setPools(parsed.pools)
  end

  EbonAPI:Emit("SERVER_LOADOUT", loadout)
end

Problems.declare("EbonAPI", "EBONAPI", {
  ["SERVER.BUILD_REFUSED"] = { class = "refus", key = "reason" },
  ["SERVER.TREE_REFUSED"] = { class = "echec" },
  ["SERVER.PICK_REFUSED"] = { class = "echec" },
  ["SERVER.FREEZE_REFUSED"] = { class = "echec" },
  ["SERVER.PRESTIGE_REFUSED"] = { class = "refus", key = "reason" },
  ["SERVER.BODY_REJECTED"] = { class = "rejet" },
  ["ECHOES.CLIENT_BODY"] = { class = "rejet" },
})

local BUILD_REASONS = {
  disabled = "DISABLED", slot = "SLOT", empty = "EMPTY", level = "LEVEL", combat = "COMBAT", dead = "DEAD",
  rolls = "ROLLS", locked = "LOCKED", max = "MAX", money = "MONEY", designed = "DESIGNED", invalid = "INVALID",
  full = "FULL", norecover = "NORECOVER", occupied = "OCCUPIED", overbudget = "OVERBUDGET", same = "SAME",
  recoverable = "RECOVERABLE",
}

local BUILD_VARIANT = { empty = "save", level = "save", full = "recover", overbudget = "recover" }

local PRESTIGE_REASONS = { gate = "GATE", combat = "COMBAT", dead = "DEAD" }

local function why(prefix, suffix, reason)
  local text = suffix and L[prefix .. suffix]

  return text or format(L.PROBLEM_SERVER_REASON_UNKNOWN, reason)
end

local function refuse(code, facts)
  local problem = Problems.new("EbonAPI", code, facts)

  Problems.report(problem)

  return problem
end

local function result(kind, problem)
  EbonAPI:Emit("SERVER_RESULT", kind, problem == nil, problem)
end

local function onBuildAck(body)
  local status, op, reason = match(tostring(body), "^([^,]+),([^,]+),(.*)$")

  if status == "OK" then
    result("build")
  elseif status == "FAIL" then
    local suffix = BUILD_REASONS[reason]

    if suffix and BUILD_VARIANT[reason] == op then
      suffix = suffix .. "_" .. upper(op)
    end

    result("build", refuse("SERVER.BUILD_REFUSED", {
      op = op, reason = reason, why = why("PROBLEM_SERVER_BUILD_REFUSED_", suffix, reason),
    }))
  else
    reject(SS.SEND_PERK_LOADOUT_RESULT, "bad_status", "status", body)
  end
end

local function flagResult(body, name, opcode, code)
  local flag = match(tostring(body), "^([01])$")

  if flag == "1" then
    result(name)
  elseif flag == "0" then
    result(name, refuse(code))
  else
    reject(opcode, "bad_flag", "flag", body)
  end
end

local function onTreeResult(body)
  flagResult(body, "tree", SS.SKILL_TREE_UPDATE_SPELL_CAST_RESULT, "SERVER.TREE_REFUSED")
end

local pendingPick
local pendingFacts
local pickCaller
local offerAt
local offerBody
local sentAt

local function nowMs()
  return (GetTime and GetTime()) or 0
end

local function sinceMs(from)
  if not from then
    return "unknown"
  end

  return math.floor((nowMs() - from) * 1000)
end

local function onOfferSeen(body)
  offerAt = nowMs()
  offerBody = type(body) == "string" and sub(body, 1, 200) or type(body)
end

local function pickContext(spellId)
  local facts = { spell = spellId, emitter = pickCaller or "PE" }
  local ok, perks = pcall(function() return _G.ProjectEbonhold.Perks end)

  pickCaller = nil
  perks = ok and type(perks) == "table" and perks or {}

  local ids, present = {}, "no"
  local choices = perks.currentChoice

  if type(choices) == "table" then
    for index = 1, #choices do
      local choice = choices[index]
      local id = type(choice) == "table" and choice.spellId or nil

      if id ~= nil then
        ids[#ids + 1] = tostring(id)

        if id == spellId then
          present = "yes"
        end
      end
    end
  end

  facts.offer = #ids > 0 and table.concat(ids, ",") or "none"
  facts.inOffer = present
  facts.pendingReroll = tostring(perks.pendingReroll)
  facts.pendingBanishIndex = tostring(perks.pendingBanishIndex)
  facts.pendingFreezeIndex = tostring(perks.pendingFreezeIndex)
  facts.offerToSendMs = sinceMs(offerAt)
  facts.offerBody = tostring(offerBody)

  local draw = perks.currentSpecDraw
  facts.specDraw = tostring(type(draw) == "table" and draw.chosen or nil)

  local okOrb, orbOffer = pcall(function() return _G.ProjectEbonhold.OrbService.IsOfferPending() end)
  facts.orbOffer = okOrb and tostring(orbOffer) or "nil"

  facts.pendingRolls = tostring(perks.pendingRollsCount)

  facts.card = "none"

  if type(choices) == "table" then
    for index = 1, #choices do
      local choice = choices[index]

      if type(choice) == "table" and choice.spellId == spellId then
        facts.card = format("quality=%s,isFrozen=%s,isCarried=%s,isGuaranteed=%s,memoryRemaining=%s",
          tostring(choice.quality), tostring(choice.isFrozen), tostring(choice.isCarried),
          tostring(choice.isGuaranteed), tostring(choice.memoryRemaining))
        break
      end
    end
  end

  local okAuto, autoAccept = pcall(function() return _G.ProjectEbonholdOptionsService:GetSetting("autoAcceptLoadoutEchoes") end)
  facts.peAutoAccept = okAuto and tostring(autoAccept) or "nil"

  return facts
end

function State.notePickCaller(caller)
  pickCaller = caller
end

local function rejectClient(opcode, reason, field, body)
  State.rejected = State.rejected + 1

  Problems.reject("EbonAPI", "ECHOES.CLIENT_BODY", {
    opcode = opcode, reason = reason, field = field,
    sample = type(body) == "string" and sub(body, 1, 60) or type(body),
  })
end

local function onPickSent(body)
  local spellId = match(tostring(body), "^(%d+)$")

  spellId = spellId and tonumber(spellId)

  if not spellId or spellId <= 0 then
    rejectClient(CS.REQUEST_PLAYER_PERK_SELECTION, "not_a_spell_id", "spellId", body)
    return
  end

  pendingPick = spellId
  pendingFacts = pickContext(spellId)
  sentAt = nowMs()
end

local function onOrbSpent(body)
  local orbText, idsText = match(tostring(body), "^(%d+)|(%d+[%d,]*)$")
  local orbs = orbText and tonumber(orbText)
  local spellIds = {}

  if orbs and orbs > 0 and not find(idsText, ",,", 1, true) and sub(idsText, -1) ~= "," then
    for id in gmatch(idsText, "%d+") do
      id = tonumber(id)

      if id <= 0 then
        spellIds = nil
        break
      end

      spellIds[#spellIds + 1] = id
    end
  else
    spellIds = nil
  end

  if not spellIds then
    rejectClient(CS.REQUEST_ORB_CONSUME, "bad_spend_body", "orbs|spellIds", body)
    return
  end

  EbonAPI:Emit("CLIENT_ORB_SPEND", { orbs = orbs, spellIds = spellIds, total = orbs * #spellIds })
end

local function onPickResult(body)
  local count = match(tostring(body), "^(%d+)$")

  if not count then
    reject(SS.PLAYER_PERK_SELECTION_RESULT, "not_a_number", "count", body)
    return
  end

  count = tonumber(count)

  local spellId = pendingPick
  local facts = pendingFacts
  local sent = sentAt

  pendingPick = nil
  pendingFacts = nil
  sentAt = nil

  if count > 0 then
    result("pick")
  else
    facts = facts or { spell = spellId or "unknown", emitter = "unrecorded" }
    facts.sendToResultMs = sinceMs(sent)

    result("pick", refuse("SERVER.PICK_REFUSED", facts))
  end

  EbonAPI:Emit("SERVER_PICK_RESULT", { ok = count > 0, count = count, spellId = spellId })
end

local function onFreezeResult(body)
  flagResult(body, "freeze", SS.FREEZE_PERK_RESULT, "SERVER.FREEZE_REFUSED")
end

local function onPrestigeResult(body)
  local status, reason = match(tostring(body), "^(%a+),(.*)$")

  if status == "OK" then
    result("prestige")
  elseif status == "FAIL" then
    result("prestige", refuse("SERVER.PRESTIGE_REFUSED", {
      reason = reason, why = why("PROBLEM_SERVER_PRESTIGE_REFUSED_", PRESTIGE_REASONS[reason], reason),
    }))
  else
    reject(SS.PRESTIGE_RESULT, "bad_status", "status", body)
  end
end

local callboard = nil
local callboardEnabled = nil
local callboardProblem = nil
local callboardWidth = 0
local headerFields = {}
local contractFields = {}
local resultFields = {}
local find, len = string.find, string.len
local ipairs, tostring = ipairs, tostring

local CALLBOARD_CATEGORIES = {
  { id = 3, name = "Open World", icon = "Interface\\Icons\\INV_Misc_Map_01" },
  { id = 1, name = "Dungeons", icon = "Interface\\Icons\\INV_Misc_Key_04" },
  { id = 2, name = "Raids", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
  { id = 4, name = "Profession", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
  { id = 6, name = "Other", icon = "Interface\\Icons\\INV_Misc_Note_01" },
  { id = 7, name = "Torment", icon = "Interface\\Icons\\Spell_Shadow_SoulLeech_3" },
}

State.CALLBOARD_STATE = { AVAILABLE = 0, ACCEPTED = 1, COMPLETE = 2, EXHAUSTED = 3 }
State.CALLBOARD_CADENCE = { DAILY = 0, WEEKLY = 1, ONCE = 2 }

local KNOWN_CATEGORY, KNOWN_STATE, KNOWN_CADENCE = {}, {}, {}

for _, category in ipairs(CALLBOARD_CATEGORIES) do
  KNOWN_CATEGORY[category.id] = true
end

for _, value in pairs(State.CALLBOARD_STATE) do
  KNOWN_STATE[value] = true
end

for _, value in pairs(State.CALLBOARD_CADENCE) do
  KNOWN_CADENCE[value] = true
end

local BOARD_HEADER = 7
local BOARD_REQUIRED = 27
local BOARD_FIELDS = 28

local CONTRACT_FIELD = {
  "n", "n", "n", "n", "n", "n", "n", "n", "n", "n", "n", "n", "n", "n", "flag", "flag", "title", "text", "text", "n",
  "n", "int", "n", "n", "n", "num", "num",
}

local function whole(value)
  return find(value, "^%d+$") ~= nil
end

local function signedInt(value)
  return find(value, "^%-?%d+$") ~= nil
end

local function decimal(value)
  return find(value, "^%-?%d+$") ~= nil or find(value, "^%-?%d+%.%d+$") ~= nil
end

local function fieldProblem(kind, value)
  if kind == "n" then
    if not whole(value) then
      return "is not a whole number"
    end
  elseif kind == "int" then
    if not signedInt(value) then
      return "is not a whole number"
    end
  elseif kind == "num" then
    if not decimal(value) then
      return "is not a number"
    end
  elseif kind == "flag" then
    if value ~= "0" and value ~= "1" then
      return "is not 0 or 1"
    end
  elseif kind == "title" then
    if value == "" or whole(value) then
      return "is not a title"
    end
  elseif whole(value) then
    return "is a number, not a text"
  end

  return nil
end

local function readFields(body, first, last, tilde)
  local fields = contractFields
  local count = 0
  local start = first

  while true do
    if tilde and tilde < start then
      tilde = find(body, "~", start, true)
    end

    local stop = tilde and tilde <= last and tilde or nil

    count = count + 1

    if count <= BOARD_FIELDS then
      fields[count] = sub(body, start, (stop or last + 1) - 1)
    end

    if not stop then
      break
    end

    start = stop + 1
  end

  for index = count + 1, BOARD_FIELDS do
    fields[index] = nil
  end

  return count, tilde
end

local function readContract(fields, count)
  if count < BOARD_REQUIRED then
    return nil, count .. (count == 1 and " field, " or " fields, ") .. BOARD_REQUIRED .. " expected"
  end

  for index = 1, BOARD_REQUIRED do
    local problem = fieldProblem(CONTRACT_FIELD[index], fields[index])

    if problem then
      return nil, "field " .. index .. " " .. problem
    end
  end

  local questId = tonumber(fields[1])

  if questId == 0 then
    return nil
  end

  local category, cadence, state = tonumber(fields[2]), tonumber(fields[3]), tonumber(fields[6])

  if not KNOWN_CATEGORY[category] or not KNOWN_CADENCE[cadence] or not KNOWN_STATE[state] then
    return false
  end

  local payPct, outleveledAbove = tonumber(fields[21]), tonumber(fields[20])

  return {
    paysNothing = payPct == 0 and outleveledAbove > 0,
    questId = questId,
    category = category,
    cadence = cadence,
    done = tonumber(fields[4]),
    max = tonumber(fields[5]),
    state = state,
    ashes = tonumber(fields[7]),
    xp = tonumber(fields[8]),
    copper = tonumber(fields[9]),
    artisan = tonumber(fields[10]),
    item = tonumber(fields[11]),
    itemCount = tonumber(fields[12]),
    orbs = tonumber(fields[13]),
    shards = tonumber(fields[14]),
    accountWide = fields[15] == "1",
    featured = fields[16] == "1",
    title = fields[17],
    objectives = fields[18],
    description = fields[19],
    outleveledAbove = tonumber(fields[20]),
    payPct = tonumber(fields[21]),
    level = tonumber(fields[22]),
    minLevel = tonumber(fields[23]),
    maxLevel = tonumber(fields[24]),
    poiArea = tonumber(fields[25]),
    poiX = tonumber(fields[26]),
    poiY = tonumber(fields[27]),
    cost = tonumber(fields[28]) or 0,
  }
end

function State.parseCallboard(body, now)
  if type(body) ~= "string" or body == "" then
    return nil
  end

  local length = len(body)
  local bar = find(body, "|", 1, true)
  local header, width = Lib.split(sub(body, 1, (bar or length + 1) - 1), ",", headerFields)

  if width < BOARD_HEADER then
    return nil, "header: " .. width .. " fields, " .. BOARD_HEADER .. " expected"
  end

  for index = 1, BOARD_HEADER do
    if not whole(header[index]) then
      return nil, "header: field " .. index .. " is not a whole number"
    end
  end

  local board = {
    receivedAt = Lib.num(now),
    dailyResetIn = tonumber(header[1]),
    weeklyResetIn = tonumber(header[2]),
    highestIlvl = tonumber(header[3]),
    equippedIlvl = tonumber(header[4]),
    cacheProgress = tonumber(header[5]),
    cacheRequired = tonumber(header[6]),
    cachesOpened = tonumber(header[7]),
    startValley = tonumber(header[8]) or 0,
    elixirPending = header[9] == "1",
    elixirAshes = tonumber(header[10]) or 0,
    elixirShards = tonumber(header[11]) or 0,
    quests = {},
    byId = {},
    byCategory = {},
    claimable = 0,
    skipped = 0,
    fields = 0,
  }
  local quests, byId, byCategory = board.quests, board.byId, board.byCategory
  local tilde = 0
  local rank = 0

  while bar do
    local first = bar + 1

    bar = find(body, "|", first, true)
    rank = rank + 1

    local last = (bar or length + 1) - 1
    local count

    count, tilde = readFields(body, first, last, tilde)

    local contract, problem = readContract(contractFields, count)

    if problem then
      return nil, "contract " .. rank .. ": " .. problem
    end

    board.fields = max(board.fields, count)

    if contract == false then
      board.skipped = board.skipped + 1
    elseif contract and not byId[contract.questId] then
      local list = byCategory[contract.category]

      if not list then
        list = {}
        byCategory[contract.category] = list
      end

      quests[#quests + 1] = contract
      byId[contract.questId] = contract
      list[#list + 1] = contract

      if contract.state == State.CALLBOARD_STATE.COMPLETE and contract.cost == 0 then
        board.claimable = board.claimable + 1
      end
    end
  end

  return board
end

local CLAIM_FIELDS = 12
local CLAIM_NUMBERS = { 3, 4, 5, 6, 7, 10, 11, 12 }

function State.parseCallboardResult(body)
  if type(body) ~= "string" then
    return nil
  end

  local fields, count = Lib.split(body, "~", resultFields)
  local status, op = fields[1], fields[2]

  if (status ~= "OK" and status ~= "FAIL") or (op ~= "accept" and op ~= "claim" and op ~= "startzone") then
    return nil
  end

  local result = { ok = status == "OK", op = op }

  if op == "startzone" then
    if result.ok then
      result.zone = tonumber(fields[3]) or 0
    else
      result.reason = fields[3] or ""
      result.zone = tonumber(fields[4]) or 0
    end
  elseif not result.ok then
    if count < 4 or not whole(fields[4]) then
      return nil
    end

    result.reason = fields[3]
    result.questId = tonumber(fields[4])
  elseif op == "accept" then
    if count < 3 or not whole(fields[3]) then
      return nil
    end

    result.questId = tonumber(fields[3])
  else
    if count < CLAIM_FIELDS or not find(fields[8], "^[%d,]*$") or not find(fields[9], "^[%d:,]*$") then
      return nil
    end

    for _, index in ipairs(CLAIM_NUMBERS) do
      if not whole(fields[index]) then
        return nil
      end
    end

    result.count = tonumber(fields[3])
    result.ashes = tonumber(fields[4])
    result.xp = tonumber(fields[5])
    result.copper = tonumber(fields[6])
    result.artisan = tonumber(fields[7])
    result.caches = {}
    result.items = {}
    result.orbs = tonumber(fields[10])
    result.shards = tonumber(fields[11])
    result.outleveled = tonumber(fields[12])

    for cache in gmatch(fields[8], "%d+") do
      result.caches[#result.caches + 1] = tonumber(cache)
    end

    for entry, amount in gmatch(fields[9], "(%d+):(%d+)") do
      result.items[#result.items + 1] = { entry = tonumber(entry), count = tonumber(amount) }
    end
  end

  return result
end


function State.GetCallboard()
  return callboard
end

function State.CallboardEnabled()
  return callboardEnabled
end

function State.CallboardProblem()
  return callboardProblem
end

function State.CallboardResets(now)
  if not callboard then
    return nil
  end

  local elapsed = Lib.num(now, (GetTime and GetTime()) or 0) - callboard.receivedAt

  return max(0, callboard.dailyResetIn - elapsed), max(0, callboard.weeklyResetIn - elapsed)
end

local function copyCategories(source)
  local list = {}

  for _, entry in ipairs(source) do
    local id = type(entry) == "table" and tonumber(entry.id)

    if id then
      list[#list + 1] = {
        id = id,
        name = type(entry.name) == "string" and entry.name or "",
        icon = type(entry.icon) == "string" and entry.icon or nil,
      }
    end
  end

  return list
end

function State.CallboardCategories()
  local service = EbonAPI.Ebonhold.Callboard()
  local own = service and service.CATEGORIES

  if type(own) == "table" then
    local list = copyCategories(own)

    if #list > 0 then
      return list
    end
  end

  return copyCategories(CALLBOARD_CATEGORIES)
end

local mapAreaZone
local function mapAreaZones()
  if mapAreaZone then
    return mapAreaZone
  end

  if WorldMapFrame and WorldMapFrame:IsShown() then
    return nil
  end

  local zones = {}

  for c = 1, 4 do
    for i, name in ipairs({ GetMapZones(c) }) do
      SetMapZoom(c, i)
      zones[GetCurrentMapAreaID() - 1] = name
    end
  end

  SetMapToCurrentZone()
  mapAreaZone = zones
  return zones
end

function State.CallboardZone(contract)
  local objectives = contract

  if type(contract) == "table" then
    objectives = contract.objectives

    local area = contract.poiArea
    local zones = type(area) == "number" and area > 0 and mapAreaZones()
    local name = zones and zones[area]

    if name then
      return name
    end
  end

  if type(objectives) ~= "string" then
    return nil
  end

  local zone = match(objectives, " in (.-)%.?%s*$")

  if zone == "" then
    return nil
  end

  return zone
end


local function onCallboard(body)
  if type(body) ~= "string" then
    State.rejected = State.rejected + 1
    return
  end

  if body == "" and callboard then
    return
  end

  local board, problem = State.parseCallboard(body, (GetTime and GetTime()) or 0)

  if problem then
    State.rejected = State.rejected + 1
    EbonAPI.Log.trace("callboard", "EbonAPI", "board not recognized", problem)
  elseif board and board.fields > BOARD_FIELDS and board.fields ~= callboardWidth then
    EbonAPI.Log.trace("callboard", "EbonAPI", "fields left out", board.fields .. " fields, " .. BOARD_FIELDS .. " read")
  end

  if board then
    callboardWidth = board.fields
  end

  callboard, callboardProblem = board, problem
  callboardEnabled = body ~= ""

  EbonAPI:Emit("SERVER_CALLBOARD", Lib.copyDeep(callboard), problem)
end

local function onCallboardResult(body)
  local result = State.parseCallboardResult(body)

  if not result then
    State.rejected = State.rejected + 1
    EbonAPI.Log.trace("callboard", "EbonAPI", "answer not recognized", body)
    return
  end

  EbonAPI:Emit("SERVER_CALLBOARD_RESULT", result)
end



local wired = false

local unwatchEchoes
function State.enable()
  if wired then
    return false
  end

  wired = true

  Bridge.on(SS.PLAYER_RUN_DATA, onRunData)
  Bridge.on(SS.COMMITTED_SOUL_POINTS, onBank)
  Bridge.on(SS.SOUL_POINTS_MULTIPLIER, onMultiplier)
  Bridge.on(SS.BUILD_LIST, onBuildList)
  Bridge.on(SS.BUILD_ACTIVE, onBuildActive)
  Bridge.on(SS.SEND_LOADOUTS, onLoadouts)
  Bridge.on(SS.SEND_PERK_LOADOUT_RESULT, onBuildAck)
  Bridge.on(SS.SKILL_TREE_UPDATE_SPELL_CAST_RESULT, onTreeResult)
  Bridge.on(SS.PLAYER_PERK_SELECTION_RESULT, onPickResult)
  Bridge.on(SS.PLAYER_PERK_CHOICE, onOfferSeen)
  Bridge.on(SS.FREEZE_PERK_RESULT, onFreezeResult)
  Bridge.on(SS.PRESTIGE_RESULT, onPrestigeResult)
  Bridge.on(SS.SEND_CALLBOARD_DATA, onCallboard)
  Bridge.on(SS.SEND_CALLBOARD_RESULT, onCallboardResult)
  Bridge.onClient(CS.REQUEST_PLAYER_PERK_SELECTION, onPickSent)
  Bridge.onClient(CS.REQUEST_ORB_CONSUME, onOrbSpent)

  return true
end

function State.disable()
  if not wired then
    return false
  end

  wired = false
  unwatchEchoes()

  Bridge.off(SS.PLAYER_RUN_DATA, onRunData)
  Bridge.off(SS.COMMITTED_SOUL_POINTS, onBank)
  Bridge.off(SS.SOUL_POINTS_MULTIPLIER, onMultiplier)
  Bridge.off(SS.BUILD_LIST, onBuildList)
  Bridge.off(SS.BUILD_ACTIVE, onBuildActive)
  Bridge.off(SS.SEND_LOADOUTS, onLoadouts)
  Bridge.off(SS.SEND_PERK_LOADOUT_RESULT, onBuildAck)
  Bridge.off(SS.SKILL_TREE_UPDATE_SPELL_CAST_RESULT, onTreeResult)
  Bridge.off(SS.PLAYER_PERK_SELECTION_RESULT, onPickResult)
  Bridge.off(SS.PLAYER_PERK_CHOICE, onOfferSeen)
  Bridge.off(SS.FREEZE_PERK_RESULT, onFreezeResult)
  Bridge.off(SS.PRESTIGE_RESULT, onPrestigeResult)
  Bridge.off(SS.SEND_CALLBOARD_DATA, onCallboard)
  Bridge.off(SS.SEND_CALLBOARD_RESULT, onCallboardResult)
  Bridge.offClient(CS.REQUEST_PLAYER_PERK_SELECTION, onPickSent)
  Bridge.offClient(CS.REQUEST_ORB_CONSUME, onOrbSpent)
  pendingPick = nil
  pendingFacts = nil
  sentAt = nil
  pickCaller = nil

  return true
end
local echoSubs = {}

local function echoOp(name)
  return EbonAPI.SS[name]
end

local function splitPerks(value)
  local owned, locked = {}, {}

  for _, perk in ipairs(value.perks or {}) do
    if perk.locked then
      locked[#locked + 1] = perk
    else
      owned[#owned + 1] = perk
    end
  end

  return { maxSlots = value.maxSlots, owned = owned, locked = locked }
end

local echoEvents = {
  SEND_PLAYER_PERK_CHOICE = { event = "SERVER_OFFER", shape = function(value) return value end },
  SEND_PLAYER_PERK_GRANTED = { event = "SERVER_PERKS", shape = splitPerks },
  SEND_ORB_CHARGES = { event = "SERVER_ORBS", shape = function(value) return value end },
  SEND_ECHO_DISCOVERY = { event = "SERVER_CATALOG", shape = function(value) return value end },
}

local function watchEcho(name)
  local opcode = echoOp(name)
  local spec = echoEvents[name]

  if not opcode or not spec or echoSubs[name] or not EbonAPI.Decoders then
    return false
  end

  local function onValue(value)
    if type(value) == "table" then
      EbonAPI:Emit(spec.event, Lib.copyDeep(spec.shape(value)))
    end
  end

  if not EbonAPI.Decoders.subscribe(opcode, onValue) then
    return false
  end

  echoSubs[name] = onValue

  local current = EbonAPI.Decoders.get(opcode)

  if current ~= nil then
    onValue(current)
  end

  return true
end

unwatchEchoes = function()
  for name, fn in pairs(echoSubs) do
    EbonAPI.Decoders.unsubscribe(echoOp(name), fn)
    echoSubs[name] = nil
  end
end

local function echoValue(name)
  watchEcho(name)

  local opcode = echoOp(name)
  local value = opcode and EbonAPI.Decoders and EbonAPI.Decoders.get(opcode)

  if type(value) ~= "table" then
    return nil
  end

  return value
end

function State.WatchEchoes()
  for name in pairs(echoEvents) do
    watchEcho(name)
  end

  return true
end

function State.GetOffer()
  local value = echoValue("SEND_PLAYER_PERK_CHOICE")

  return value and Lib.copyDeep(value) or nil
end

function State.GetOwned()
  local value = echoValue("SEND_PLAYER_PERK_GRANTED")

  if not value then return nil end

  local split = splitPerks(value)

  return Lib.copyDeep({ maxSlots = split.maxSlots, perks = split.owned })
end

function State.GetLocked()
  local value = echoValue("SEND_PLAYER_PERK_GRANTED")

  if not value then return nil end

  local split = splitPerks(value)

  return Lib.copyDeep({ maxSlots = split.maxSlots, perks = split.locked })
end

function State.GetPending()
  local value = echoValue("SEND_PLAYER_PERK_CHOICE")

  return value and value.pendingRolls or nil
end

function State.GetOrbs()
  local value = echoValue("SEND_ORB_CHARGES")

  return value and Lib.copyDeep(value) or nil
end

function State.GetCatalog()
  local value = echoValue("SEND_ECHO_DISCOVERY")

  return value and Lib.copyDeep(value) or nil
end

function State.IsEchoDiscoveryReceived()
  return State.GetCatalog() ~= nil
end

function State.GetEchoDiscovery(spellId)
  local catalog = State.GetCatalog()

  if not catalog then
    return nil
  end

  local discovered = false

  for _, entry in ipairs(catalog.entries) do
    if entry.spellId == spellId then
      discovered = true
      break
    end
  end

  return {
    discovered = discovered,
    count = catalog.counts[spellId] or 0,
    enabled = not catalog.disabled[spellId],
  }
end

function State.GetAutoAcceptLoadoutEchoes()
  local service = Lib.safeGet(EbonAPI.Ebonhold.OptionsService)

  if type(service) ~= "table" or type(service.GetSetting) ~= "function" then
    return nil
  end

  local value = Lib.safeGet(service.GetSetting, service, "autoAcceptLoadoutEchoes")

  return value and true or false
end


function State.reset()
  run, ash, pools, builds, loadout = nil, nil, nil, nil, nil
  multiplier = 0
  callboard, callboardEnabled, callboardProblem, callboardWidth = nil, nil, nil, 0
  pendingPick = nil

  EbonAPI:ClearSticky("SERVER_RUN_DATA")
  EbonAPI:ClearSticky("SERVER_ASH")
  EbonAPI:ClearSticky("SERVER_POOLS")
  EbonAPI:ClearSticky("SERVER_MULTIPLIER")
  EbonAPI:ClearSticky("SERVER_BUILDS")
  EbonAPI:ClearSticky("SERVER_BUILD_ACTIVE")
  EbonAPI:ClearSticky("SERVER_LOADOUT")
  EbonAPI:ClearSticky("SERVER_CALLBOARD")
  unwatchEchoes()
  EbonAPI:ClearSticky("SERVER_OFFER")
  EbonAPI:ClearSticky("SERVER_PERKS")
  EbonAPI:ClearSticky("SERVER_ORBS")
  EbonAPI:ClearSticky("SERVER_CATALOG")
end

EbonAPI:DeclareSticky("SERVER_RUN_DATA")
EbonAPI:DeclareSticky("SERVER_ASH")
EbonAPI:DeclareSticky("SERVER_POOLS")
EbonAPI:DeclareSticky("SERVER_MULTIPLIER")
EbonAPI:DeclareSticky("SERVER_BUILDS")
EbonAPI:DeclareSticky("SERVER_BUILD_ACTIVE")
EbonAPI:DeclareSticky("SERVER_LOADOUT")
EbonAPI:DeclareSticky("SERVER_CALLBOARD")
EbonAPI:DeclareSticky("SERVER_OFFER")
EbonAPI:DeclareSticky("SERVER_PERKS")
EbonAPI:DeclareSticky("SERVER_ORBS")
EbonAPI:DeclareSticky("SERVER_CATALOG")

function State.GetPendingPick()
  return pendingPick
end

function Handle:State()
  return State
end
