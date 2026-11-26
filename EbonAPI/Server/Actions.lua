EbonAPI = EbonAPI or {}
EbonAPI.Actions = {}

local Actions = EbonAPI.Actions
local Ebonhold = EbonAPI.Ebonhold
local Bridge = EbonAPI.Bridge
local Decoders = EbonAPI.Decoders
local Opcodes = EbonAPI.Opcodes
local Problems = EbonAPI.Problems
local Bus = EbonAPI.Bus
local Lib = EbonAPI.Lib

local type, tostring, pcall, pairs, select = type, tostring, pcall, pairs, select
local sort, remove, concat = table.sort, table.remove, table.concat
local gsub, sub = string.gsub, string.sub

local WINDOW = 30
local UPLOAD_ANSWER = 541
local TICK = "EbonAPI:actions"

Actions.WINDOW = WINDOW

Problems.declare("EbonAPI", "EBONAPI", {
  ["ACTION.BAD_ARGS"] = { class = "echec", key = "action" },
  ["ACTION.REFUSED"] = { class = "refus", key = "action" },
  ["ACTION.NOT_SENT"] = { class = "echec", key = "action" },
  ["ACTION.NO_DECODER"] = { class = "echec", key = "action" },
})

local specs = {}

local function probe(fn, ...)
  local ok, value = pcall(fn, ...)

  if ok then
    return value
  end
end

local function fail(code, facts, cause)
  return { sent = false, problem = Problems.report(Problems.new("EbonAPI", code, facts, cause)) }
end

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function enqueue(cs, body)
  local number = type(cs) == "number" and cs or Opcodes.numberCS(cs) or Ebonhold.OpcodeCS(cs)

  if not integer(number) then
    return false, "unknown opcode " .. tostring(cs)
  end

  local ok, queued = pcall(Bridge.send, number, body or "")

  if not ok then
    return false, tostring(queued)
  end

  if not queued then
    return false, "the queue refused the message"
  end

  return true
end

function Actions.send(cs, body)
  if type(cs) ~= "string" and type(cs) ~= "number" then
    return fail("ACTION.BAD_ARGS", { action = "send", reason = "the client message must be a CS name or number" })
  end

  if body ~= nil and type(body) ~= "string" then
    return fail("ACTION.BAD_ARGS", { action = "send", reason = "the body must be a string" })
  end

  local ok, reason = enqueue(cs, body)

  if not ok then
    return fail("ACTION.NOT_SENT", { action = "send", reason = reason })
  end

  return { sent = true, via = "queue" }
end

local function execute(spec, ...)
  local action = spec.name

  if spec.check then
    local ok, reason = pcall(spec.check, ...)

    if not ok then
      reason = "argument check failed: " .. tostring(reason)
    end

    if reason then
      return fail("ACTION.BAD_ARGS", { action = action, reason = tostring(reason) })
    end
  end

  local state

  if spec.prepare then
    local ok, prepared, reason = pcall(spec.prepare, ...)

    if not ok then
      return fail("ACTION.BAD_ARGS", { action = action, reason = tostring(prepared) })
    end

    if not prepared then
      return fail("ACTION.NO_DECODER", { action = action, reason = tostring(reason) })
    end

    state = prepared
  end

  local outcome = nil
  local fn = spec.service and Ebonhold.ServiceFunction(spec.service[1], spec.service[2])
  local refusal = not spec.service and spec.why and probe(spec.why, ...)

  if type(refusal) == "string" then
    outcome = fail("ACTION.REFUSED", { action = action, reason = refusal })
  elseif fn then
    local reason = spec.guard and probe(spec.guard, ...)

    if type(reason) == "string" then
      outcome = fail("ACTION.REFUSED", { action = action, service = spec.service[2], reason = reason })
    else
      local ok, result
      if spec.callArgs then
        ok, result = pcall(function(...) return fn(spec.callArgs(...)) end, ...)
      else
        ok, result = pcall(fn, ...)
      end

      if not ok then
        outcome = fail("ACTION.NOT_SENT", { action = action, reason = "ProjectEbonhold raised: " .. tostring(result) })
      elseif result == false then
        local why = spec.why and probe(spec.why, ...)

        outcome = fail("ACTION.REFUSED", {
          action = action, service = spec.service[2],
          reason = type(why) == "string" and why or "ProjectEbonhold refused the request",
        })
      else
        outcome = { sent = true, via = "service" }
      end
    end
  else
    local okb, body = true, ""

    if spec.body then
      okb, body = pcall(spec.body, ...)
    end

    if not okb or type(body) ~= "string" then
      outcome = fail("ACTION.BAD_ARGS", { action = action, reason = "body not built: " .. tostring(body) })
    else
      local ok, reason = enqueue(spec.cs, body)

      if ok then
        outcome = { sent = true, via = "queue" }
      else
        outcome = fail("ACTION.NOT_SENT", { action = action, reason = reason })
      end
    end
  end

  if spec.settle then
    pcall(spec.settle, state, outcome.sent)
  end

  return outcome
end

function Actions.define(spec)
  if type(spec) ~= "table" or type(spec.name) ~= "string" or not spec.name:match("^%u%w*$") then
    return nil, "spec.name must be a name starting with an uppercase letter"
  end

  if specs[spec.name] then
    return nil, "action " .. spec.name .. " already defined"
  end

  if type(spec.cs) ~= "string" or Opcodes.numberCS(spec.cs) == nil then
    return nil, "spec.cs must be a name of the CS catalogue"
  end

  for _, key in pairs({ "check", "body", "callArgs", "guard", "why", "prepare", "settle" }) do
    if spec[key] ~= nil and type(spec[key]) ~= "function" then
      return nil, "spec." .. key .. " must be a function"
    end
  end

  if spec.service ~= nil and (type(spec.service) ~= "table" or type(spec.service[1]) ~= "string"
      or type(spec.service[2]) ~= "string") then
    return nil, "spec.service must be { owner, name }"
  end

  specs[spec.name] = spec

  local function action(...)
    return execute(spec, ...)
  end

  Actions[spec.name] = action

  return action
end

function Actions.list()
  local names = {}

  for name in pairs(specs) do
    names[#names + 1] = name
  end

  sort(names)

  return names
end

function Actions.cs(name)
  return specs[name] and specs[name].cs or nil
end

local function perks()
  local pe = _G.ProjectEbonhold

  return type(pe) == "table" and type(pe.Perks) == "table" and pe.Perks or {}
end

local function runData()
  local ok, data = pcall(function() return _G.ProjectEbonhold.PlayerRunService.GetCurrentData() end)

  return ok and type(data) == "table" and data or {}
end

local function spellCheck(spellId)
  if not integer(spellId) or spellId <= 0 then
    return "the spell id must be a positive integer"
  end
end

Actions.spellCheck = spellCheck

function Actions.spellBody(spellId) return tostring(spellId) end

local function indexCheck(index)
  if not integer(index) or index < 0 or index > 2 then
    return "the card index must be 0, 1 or 2"
  end
end

Actions.define({
  name = "RerollEchoes", cs = "REQUEST_REROLL", service = { "PerkService", "RequestReroll" },
  why = function() if perks().pendingReroll then return "a reroll is already in flight" end end,
})

Actions.define({
  name = "LockEcho", cs = "REQUEST_LOCK_PERK", service = { "PerkService", "LockPerk" },
  check = spellCheck, body = Actions.spellBody,
})

Actions.define({
  name = "UnlockEcho", cs = "REQUEST_UNLOCK_PERK", service = { "PerkService", "UnlockPerk" },
  check = spellCheck, body = Actions.spellBody,
})

local function cardRefusal(index, pending, label)
  local p = perks()

  if pending then
    return label .. " already in flight"
  end

  local choice = type(p.currentChoice) == "table" and p.currentChoice[index + 1]

  if type(choice) == "table" and choice.isGuaranteed then
    return "the guaranteed card cannot be " .. label
  end
end

Actions.define({
  name = "BanishEcho", cs = "REQUEST_BANISH_PERK", service = { "PerkService", "BanishPerk" },
  check = indexCheck, body = function(index) return tostring(index) end,
  why = function(index)
    local reason = cardRefusal(index, perks().pendingBanishIndex, "banish")

    if reason then
      return reason
    end

    local pe = _G.ProjectEbonhold

    if not (type(pe.Constants) == "table" and pe.Constants.ENABLE_BANISH_SYSTEM) then
      return "the banish system is disabled"
    end

    if (runData().remainingBanishes or 0) <= 0 then
      return "no banish left"
    end
  end,
})

Actions.define({
  name = "FreezeEcho", cs = "REQUEST_FREEZE_PERK", service = { "PerkService", "FreezePerk" },
  check = indexCheck, body = function(index) return tostring(index) end,
  why = function(index)
    local reason = cardRefusal(index, perks().pendingFreezeIndex, "freeze")

    if reason then
      return reason
    end

    local data = runData()

    if (data.totalFreezes or 0) - (data.usedFreezes or 0) <= 0 then
      return "no freeze left"
    end
  end,
})

local waiters = {}
local subscribed = false
local onUpload

local function now()
  return (GetTime and GetTime()) or 0
end

local function stopListening()
  if subscribed then
    Decoders.unsubscribe(UPLOAD_ANSWER, onUpload)
    subscribed = false
  end

  Bus.untick(TICK)
end

local function deliver(waiter, result)
  for index = 1, #waiters do
    if waiters[index] == waiter then
      remove(waiters, index)
      break
    end
  end

  if #waiters == 0 then
    stopListening()
  end

  Lib.safeCall(waiter.onResult, result)
end

onUpload = function(value)
  if type(value) ~= "table" or value.op ~= "upload" then
    return
  end

  local waiter = waiters[1]

  if waiter then
    deliver(waiter, {
      ok = value.ok == true, status = value.status, op = value.op, slot = value.slot, skipped = value.skipped,
      reason = value.reason, late = false,
    })
  end
end

local function sweep()
  local current = now()
  local late = {}

  for index = 1, #waiters do
    if waiters[index].deadline <= current then
      late[#late + 1] = waiters[index]
    end
  end

  for index = 1, #late do
    deliver(late[index], {
      ok = false, status = "TIMEOUT", op = "upload", reason = "no answer in " .. WINDOW .. " s", late = true,
    })
  end
end

local function sanitize(name)
  name = gsub(tostring(name or ""), "[|;:,]", "")
  name = gsub(name, "^%s+", "")
  name = gsub(name, "%s+$", "")

  return sub(name, 1, 32)
end

Actions.sanitize = sanitize

local function wishlistCheck(name, echoes, options)
  if type(name) ~= "string" then
    return "the name must be a string"
  end

  if type(echoes) ~= "table" or #echoes == 0 then
    return "the list of echoes must not be empty"
  end

  for index = 1, #echoes do
    local echo = echoes[index]

    if type(echo) ~= "table" or not integer(echo.spellId) or echo.spellId <= 0 then
      return "echo " .. index .. " has no valid spellId"
    end

    if echo.stacks ~= nil and (not integer(echo.stacks) or echo.stacks < 1) then
      return "echo " .. index .. " has an invalid stacks count"
    end
  end

  if options ~= nil and type(options) ~= "table" then
    return "options must be a table"
  end

  local slot = options and options.slot

  if slot ~= nil and (not integer(slot) or slot < 0) then
    return "the slot must be an integer of 0 or more (0 = new wishlist)"
  end

  if options and options.onResult ~= nil and type(options.onResult) ~= "function" then
    return "onResult must be a function"
  end
end

Actions.define({
  name = "CreateWishlist", cs = "REQUEST_PERK_LOADOUT_UPLOAD", service = { "PerkService", "UploadServerBuildSlot" },
  check = wishlistCheck,
  callArgs = function(name, echoes, options) return options and options.slot or 0, name, echoes end,
  body = function(name, echoes, options)
    local parts = {}

    for index = 1, #echoes do
      local echo = echoes[index]

      parts[index] = echo.spellId .. "." .. (echo.stacks or 1) .. "." .. ((echo.avoid or echo.locked) and 1 or 0)
    end

    return (options and options.slot or 0) .. "|" .. sanitize(name) .. "|" .. concat(parts, ",")
  end,
  why = function()
    local p = perks()

    if p.pendingBuildSlotRequest and now() - (p.pendingBuildSlotRequestAt or 0) <= 3 then
      return "ProjectEbonhold is busy with another build action (guard of 3 s)"
    end
  end,
  prepare = function(name, echoes, options)
    local onResult = options and options.onResult

    if not onResult then
      return {}
    end

    if not Decoders.has(UPLOAD_ANSWER) then
      return nil, "no decoder for SS 541: the answer could not be reported"
    end

    local waiter = { onResult = onResult, deadline = now() + WINDOW }

    waiters[#waiters + 1] = waiter

    if not subscribed then
      subscribed = Decoders.subscribe(UPLOAD_ANSWER, onUpload) and true or false
    end

    Bus.tick(TICK, 1, sweep)

    return { waiter = waiter }
  end,
  settle = function(state, sent)
    if state and state.waiter and not sent then
      for index = 1, #waiters do
        if waiters[index] == state.waiter then
          remove(waiters, index)
          break
        end
      end

      if #waiters == 0 then
        stopListening()
      end
    end
  end,
})

Actions.define({
  name = "ToggleTome", cs = "REQUEST_TOME_TOGGLE", service = { "PerkService", "ToggleTomeEcho" },
  check = function(spellId, options)
    local bad = spellCheck(spellId)

    if bad then
      return bad
    end

    if options ~= nil and type(options) ~= "table" then
      return "options must be a table"
    end
  end,
  callArgs = function(spellId) return spellId end,
  body = function(spellId, options)
    if not (options and integer(options.tome) and options.tome > 0 and type(options.enable) == "boolean") then
      error("without ProjectEbonhold's service, options = { tome = tome spell id, enable = bool } is required")
    end

    return options.tome .. "|" .. (options.enable and 1 or 0)
  end,
  why = function(spellId)
    if (UnitLevel and UnitLevel("player") or 1) ~= 1 then
      return "tomes can be enabled or disabled at level 1 only"
    end

    return "the spell is not a tome echo"
  end,
})

local function memoryRefusal()
  local choices = perks().currentChoice

  if type(choices) ~= "table" or #choices == 0 then
    return "no echo choice on the table"
  end

  if not Ebonhold.HasMemoryCard() then
    return "no memory card on the table"
  end

  return nil
end

Actions.define({
  name = "DrawMemory", cs = "REQUEST_PERK_MEMORY_DRAW",
  why = memoryRefusal,
})

Actions.define({
  name = "RerollWithOrb", cs = "REQUEST_ORB_REROLL", service = { "OrbService", "RerollOffer" },
  guard = function()
    local can = Ebonhold.ServiceFunction("OrbService", "CanRerollOffer")

    if can and not can() then
      return "no orb offer on the table or no orb in hand"
    end
  end,
})
