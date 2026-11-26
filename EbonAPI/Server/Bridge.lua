EbonAPI = EbonAPI or {}
EbonAPI.Bridge = {}

local Bridge = EbonAPI.Bridge
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local Queue = EbonAPI.Queue
local Listeners = EbonAPI.Listeners
local Assembler = EbonAPI.Assembler
local Handle = EbonAPI.Handle
local Problems = EbonAPI.Problems
local Opcodes = EbonAPI.Opcodes
local CS, SS = EbonAPI.CS, EbonAPI.SS

local type, tonumber, tostring, error, pairs, next = type, tonumber, tostring, error, pairs, next
local match, byte, len, sub, format = string.match, string.byte, string.len, string.sub, string.format
local random = math.random

local PREFIX = "AAM0x9"
local MAX_PAYLOAD = 240
local MAX_CHUNKS = 400
local SLICE_SIZE = 180
local MAX_SENT_CHUNKS = 4095
local STREAM_TIMEOUT = 20
local STREAM_SWEEP = 2
local AT = 64
local ANSWER_TIMEOUT = 10
local FRESH = 10
local ANSWER_TICK = "EbonAPI:answers"
local ECHO_DISCOVERY = 530
local ECHO_TTL = 30
local ECHO_MAX = 4096

local ANSWERS = {
  [CS.REFRESH_PERKS] = ECHO_DISCOVERY,
  [CS.REFRESH_BUILDS] = SS.BUILD_LIST,
}

Problems.declare("EbonAPI", "EBONAPI", {
  ["SERVER.NO_ANSWER"] = { class = "echec", key = "request" },
  ["BRIDGE.DROPPED"] = { class = "rejet" },
})

Bridge.PREFIX = PREFIX
Bridge.MAX_PAYLOAD = MAX_PAYLOAD
Bridge.MAX_CHUNKS = MAX_CHUNKS
Bridge.SLICE_SIZE = SLICE_SIZE
Bridge.MAX_SENT_CHUNKS = MAX_SENT_CHUNKS
Bridge.STREAM_TIMEOUT = STREAM_TIMEOUT

local listeners = {}
local throttles = {}
local senders = {}
local enabled = false
local strictSender = true

Bridge.received = 0
Bridge.sent = 0
Bridge.lastMessageAt = 0
Bridge.seen = false
Bridge.drops = { header = 0, bounds = 0, sender = 0, expired = 0 }
Bridge.echoes = 0

local drops = Bridge.drops
local waiting = {}
local received = {}

local function drop(reason, opcode, sample, sender)
  drops[reason] = drops[reason] + 1

  Problems.reject("EbonAPI", "BRIDGE.DROPPED", {
    reason = reason, opcode = opcode or "none", sample = sample and sub(sample, 1, 60), sender = sender,
  })
end

local function now()
  return (GetTime and GetTime()) or 0
end

local streams = Assembler.new("EbonAPI:streams", STREAM_TIMEOUT, STREAM_SWEEP, MAX_CHUNKS, function(opcode, id, record)
  drop("expired", opcode, "stream " .. tostring(id) .. " " .. record.count .. "/" .. record.total)
  EbonAPI:Emit("STREAM_TIMEOUT", opcode, id, record.count, record.total)
end)

local echoText, echoSeq, echoAt, echoLive = {}, {}, {}, {}
local echoHead, echoTail, echoNext = 1, 0, 0

local function echoPurge(current)
  while echoHead <= echoTail do
    local payload = echoText[echoHead]

    if echoTail - echoHead + 1 <= ECHO_MAX and current - echoAt[echoHead] <= ECHO_TTL then
      break
    end

    local list = echoLive[payload]

    if list and list[1] == echoSeq[echoHead] then
      table.remove(list, 1)

      if not list[1] then
        echoLive[payload] = nil
      end
    end

    echoText[echoHead], echoSeq[echoHead], echoAt[echoHead] = nil, nil, nil
    echoHead = echoHead + 1
  end
end

local function echoNote(payload, current)
  echoPurge(current)

  echoNext = echoNext + 1
  echoTail = echoTail + 1
  echoText[echoTail], echoSeq[echoTail], echoAt[echoTail] = payload, echoNext, current

  local list = echoLive[payload]

  if not list then
    list = {}
    echoLive[payload] = list
  end

  list[#list + 1] = echoNext
  echoPurge(current)
end

local function echoTake(payload)
  echoPurge(now())

  local list = echoLive[payload]

  if not list then
    return false
  end

  table.remove(list, 1)

  if not list[1] then
    echoLive[payload] = nil
  end

  return true
end

if hooksecurefunc and SendAddonMessage and UnitName then
  hooksecurefunc("SendAddonMessage", function(prefix, payload, kind, target)
    if prefix == PREFIX and kind == "WHISPER" and type(payload) == "string" and target and target == UnitName("player") then
      echoNote(payload, now())
    end
  end)
end

local function checkListener(opcode, fn, label)
  if type(opcode) ~= "number" then
    error(label .. " expects a numeric opcode, got " .. type(opcode), 3)
  end

  if type(fn) ~= "function" then
    error(label .. " expects a function for opcode " .. opcode .. ", got " .. type(fn), 3)
  end
end

local function add(opcode, fn)
  local list = listeners[opcode]

  if not list then
    list = Listeners.new()
    listeners[opcode] = list
  end

  return list:add(fn)
end

function Bridge.on(opcode, fn)
  checkListener(opcode, fn, "EbonAPI.Bridge.on")

  return add(opcode, fn)
end

function Bridge.off(opcode, fn)
  local list = listeners[opcode]

  if not list or not list:remove(fn) then
    return false
  end

  if list.n == 0 then
    listeners[opcode] = nil
  end

  return true
end

function Bridge.listenerCount(opcode)
  local list = listeners[opcode]

  return list and list.n or 0
end

local function complete(opcode, body, sender, distribution, at)
  at = at or now()

  Bridge.seen = true
  Bridge.received = Bridge.received + 1
  Bridge.lastMessageAt = at
  received[opcode] = at

  Log.trace("recv", nil, opcode, len(body), at)

  if waiting[opcode] then
    waiting[opcode] = nil

    if not next(waiting) then
      Bus.untick(ANSWER_TICK)
    end
  end

  local list = listeners[opcode]

  if list then
    list:fire(body, opcode, sender, distribution)
  end

  EbonAPI:Emit("SERVER_MESSAGE", opcode, body, sender)
end

local function ingest(payload, distribution, sender)
  local opcodeText, rest = match(payload, "^(%d+)\t?(.*)$")

  if not opcodeText then
    drop("header", nil, payload, sender)
    return
  end

  local opcode = tonumber(opcodeText)

  if byte(rest, 1) ~= AT then
    complete(opcode, rest, sender, distribution)
    return
  end

  local id, indexText, totalText, slice = match(rest, "^@(%x+)\t(%x+)/(%x+)\t?(.*)$")

  if not id then
    complete(opcode, rest, sender, distribution)
    return
  end

  local current = now()
  local body, state = streams:add(opcode, id, tonumber(indexText, 16), tonumber(totalText, 16), slice, current)

  if state == "bounds" then
    drop("bounds", opcode, rest, sender)
    return
  end

  if body then
    complete(opcode, body, sender, distribution, current)
  end
end

local function onAddonMessage(prefix, payload, distribution, sender)
  if prefix ~= PREFIX or type(payload) ~= "string" then
    return
  end

  if sender then
    senders[sender] = (senders[sender] or 0) + 1
  end

  if strictSender then
    local me = UnitName and UnitName("player")

    if (distribution and distribution ~= "WHISPER") or (me and sender and sender ~= me) then
      drop("sender", tonumber(match(payload, "^(%d+)")), payload, sender)
      return
    end
  end

  if sender and UnitName and sender == UnitName("player") and echoTake(payload) then
    Bridge.echoes = Bridge.echoes + 1
    return
  end

  ingest(payload, distribution, sender)
end

function Bridge.setStrictSender(value)
  strictSender = value and true or false

  return strictSender
end

function Bridge.isStrictSender()
  return strictSender
end

function Bridge.observedSenders()
  return senders
end

local function sweepAnswers(every)
  local current = now()

  for answer, request in pairs(waiting) do
    if request.deadline <= current then
      waiting[answer] = nil

      Problems.report(Problems.new("EbonAPI", "SERVER.NO_ANSWER", {
        request = Opcodes.describe(request.opcode), seconds = ANSWER_TIMEOUT,
        expected = Opcodes.describe(answer),
      }))
    end
  end

  if not next(waiting) then
    Bus.untick(ANSWER_TICK)
  end
end

local function blocked(opcode)
  local answer = ANSWERS[opcode]

  if not answer then
    return false
  end

  local current = now()
  local last = received[answer]

  if last and current - last < FRESH then
    return true
  end

  local request = waiting[answer]

  return request ~= nil and request.deadline > current
end

local function await(opcode)
  local answer = ANSWERS[opcode]

  if not answer or blocked(opcode) then
    return
  end

  waiting[answer] = { opcode = opcode, deadline = now() + ANSWER_TIMEOUT }
  Bus.tick(ANSWER_TICK, 1, sweepAnswers)
end

local notifyQueued
local notifyLogical
local slices = {}
local liveIds = {}

local function rawSend(payload)
  if not SendAddonMessage or not UnitName then
    return false
  end

  local me = UnitName("player")

  if not me or me == "" then
    return false
  end

  SendAddonMessage(PREFIX, payload, "WHISPER", me)

  Bridge.sent = Bridge.sent + 1

  local slice = slices[payload]

  if slice then
    slices[payload] = nil

    if slice.last then
      liveIds[slice.id] = nil
      await(slice.opcode)
      notifyLogical(slice.opcode, slice.body)
    end
  else
    await(tonumber(match(payload, "^(%d+)")))
    notifyQueued(payload)
  end

  return true
end

Queue.register("server", rawSend)

local function enqueue(opcode, body)
  if type(opcode) ~= "number" then
    error("EbonAPI.Bridge.send expects a numeric opcode, got " .. type(opcode), 3)
  end

  if type(body) == "number" then
    body = tostring(body)
  end

  if body ~= nil and type(body) ~= "string" then
    error("EbonAPI.Bridge.send expects a string body, got " .. type(body), 3)
  end

  local text = body or ""
  local payload = text == "" and tostring(opcode) or opcode .. "\t" .. text

  if len(payload) <= MAX_PAYLOAD then
    return payload
  end

  local total = math.ceil(len(text) / SLICE_SIZE)

  if total > MAX_SENT_CHUNKS then
    error("EbonAPI.Bridge.send: body of " .. len(text) .. " bytes for opcode " .. opcode
      .. " needs " .. total .. " chunks, the limit is " .. MAX_SENT_CHUNKS
      .. " chunks (" .. MAX_SENT_CHUNKS * SLICE_SIZE .. " bytes)", 3)
  end

  return nil, text, total
end

local function pushChunks(opcode, text, total)
  if Queue.serverLength() == 0 then
    for payload in pairs(slices) do
      slices[payload] = nil
    end

    for id in pairs(liveIds) do
      liveIds[id] = nil
    end
  end

  local id = format("%04X", random(0, 65535))

  while liveIds[id] do
    id = format("%04X", random(0, 65535))
  end

  local payloads = {}

  for index = 1, total do
    local from = (index - 1) * SLICE_SIZE + 1

    payloads[index] = format("%s\t@%s\t%03X/%03X\t%s", tostring(opcode), id, index, total,
      sub(text, from, from + SLICE_SIZE - 1))
  end

  liveIds[id] = true

  for index = 1, total do
    slices[payloads[index]] = { id = id, opcode = opcode, body = text, last = index == total }
    Queue.pushServer(payloads[index])
  end

  return true
end

local function submit(opcode, body)
  local payload, text, total = enqueue(opcode, body)

  if payload then
    return Queue.pushServer(payload)
  end

  return pushChunks(opcode, text, total)
end

function Bridge.send(opcode, body)
  if blocked(opcode) then
    return false
  end

  return submit(opcode, body)
end

function Bridge.request(opcode, body, minInterval)
  minInterval = Lib.num(minInterval, 0)

  if minInterval <= 0 then
    return Bridge.send(opcode, body)
  end

  local payload, text, total = enqueue(opcode, body)

  if blocked(opcode) then
    return false
  end

  local key = tostring(opcode) .. "\t" .. tostring(body or "")
  local current = now()

  for held, expiry in pairs(throttles) do
    if expiry <= current then
      throttles[held] = nil
    end
  end

  if throttles[key] then
    return false
  end

  throttles[key] = current + minInterval

  local queued

  if payload then
    queued = Queue.pushServer(payload)
  else
    queued = pushChunks(opcode, text, total)
  end

  return queued
end

local clientListeners = {}
local wrapped, wrapper, original
local generation = 0

local pcall, rawget, _G = pcall, rawget, _G

local function emitClient(opcode, body, origin)
  EbonAPI:Emit("CLIENT_MESSAGE", opcode, body, origin)
end

local function notifyClient(opcode, body, origin)
  local list = clientListeners[opcode]

  if list then
    list:fire(body, opcode, origin)
  end

  emitClient(opcode, body, origin)
end

notifyLogical = function(opcode, body)
  notifyClient(opcode, body, "queue")
end

notifyQueued = function(payload)
  local opcode, body = match(payload, "^(%d+)\t(.*)$")

  if not opcode then
    opcode, body = match(payload, "^(%d+)$"), ""
  end

  notifyClient(tonumber(opcode), body, "queue")
end

function Bridge.onClient(opcode, fn)
  checkListener(opcode, fn, "EbonAPI.Bridge.onClient")

  local list = clientListeners[opcode]

  if not list then
    list = Listeners.new()
    clientListeners[opcode] = list
  end

  return list:add(fn)
end

function Bridge.offClient(opcode, fn)
  local list = clientListeners[opcode]

  if not list or not list:remove(fn) then
    return false
  end

  if list.n == 0 then
    clientListeners[opcode] = nil
  end

  return true
end

function Bridge.clientListenerCount(opcode)
  local list = clientListeners[opcode]

  return list and list.n or 0
end

local function afterSend(opcode, body, ...)
  if type(opcode) == "number" then
    pcall(notifyClient, opcode, body == nil and "" or body, "service")
  end

  return ...
end

function Bridge.wrapClient()
  local pe = rawget(_G, "ProjectEbonhold")

  if wrapped or type(pe) ~= "table" or type(pe.sendToServer) ~= "function" then
    return false
  end

  local inner = pe.sendToServer
  generation = generation + 1

  local mine = generation

  original = inner

  wrapper = function(opcode, body, ...)
    if not wrapped or generation ~= mine then
      return inner(opcode, body, ...)
    end

    return afterSend(opcode, body, inner(opcode, body, ...))
  end

  pe.sendToServer = wrapper
  wrapped = true

  return true
end

function Bridge.unwrapClient()
  if not wrapped then
    return false
  end

  local pe = rawget(_G, "ProjectEbonhold")

  wrapped = false

  if type(pe) == "table" and pe.sendToServer == wrapper then
    pe.sendToServer = original
  end

  wrapper, original = nil, nil

  return true
end

function Bridge.isClientWrapped()
  return wrapped == true
end

function Bridge.queueLength()
  return Queue.serverLength()
end

function Bridge.enable()
  if enabled then
    return false
  end

  enabled = true

  Bridge.wrapClient()

  Bus.onCore("CHAT_MSG_ADDON", onAddonMessage)

  if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(PREFIX)
  end

  return true
end

function Bridge.disable()
  if not enabled then
    return false
  end

  enabled = false

  Bus.offCore("CHAT_MSG_ADDON", onAddonMessage)
  streams:clear()

  for answer in pairs(waiting) do
    waiting[answer] = nil
  end

  for answer in pairs(received) do
    received[answer] = nil
  end

  Bus.untick(ANSWER_TICK)

  return true
end

function Bridge.isEnabled()
  return enabled
end

function Bridge.streamCount()
  return streams:count()
end

function Bridge.droppedTotal()
  return drops.header + drops.bounds + drops.sender + drops.expired
end

function Handle:OnServer(opcode, fn)
  checkListener(opcode, fn, "EbonAPI: " .. self.addonName .. ": api:OnServer")

  if not add(opcode, fn) then
    return false
  end

  local owned = self._bridge

  if not owned then
    owned = {}
    self._bridge = owned
  end

  owned[#owned + 1] = opcode
  owned[#owned + 1] = fn

  return true
end

function Handle:OffServer(opcode, fn)
  local owned = self._bridge

  if not owned then
    return false
  end

  for index = #owned - 1, 1, -2 do
    if owned[index] == opcode and owned[index + 1] == fn then
      table.remove(owned, index + 1)
      table.remove(owned, index)

      return Bridge.off(opcode, fn)
    end
  end

  return false
end

function Handle:SendServer(opcode, body)
  return Bridge.send(opcode, body)
end

function Handle:RequestServer(opcode, body, minInterval)
  return Bridge.request(opcode, body, minInterval)
end

EbonAPI:AddTeardown(function(handle)
  local owned = handle._bridge

  if not owned then
    return
  end

  for index = #owned - 1, 1, -2 do
    Bridge.off(owned[index], owned[index + 1])
    owned[index + 1] = nil
    owned[index] = nil
  end
end)

function Handle:OnClient(opcode, fn)
  checkListener(opcode, fn, "EbonAPI: " .. self.addonName .. ": api:OnClient")

  if not Bridge.onClient(opcode, fn) then
    return false
  end

  local owned = self._bridgeClient

  if not owned then
    owned = {}
    self._bridgeClient = owned
  end

  owned[#owned + 1] = opcode
  owned[#owned + 1] = fn

  return true
end

function Handle:OffClient(opcode, fn)
  local owned = self._bridgeClient

  if not owned then
    return false
  end

  for index = #owned - 1, 1, -2 do
    if owned[index] == opcode and owned[index + 1] == fn then
      table.remove(owned, index + 1)
      table.remove(owned, index)

      return Bridge.offClient(opcode, fn)
    end
  end

  return false
end

EbonAPI:AddTeardown(function(handle)
  local owned = handle._bridgeClient

  if not owned then
    return
  end

  for index = #owned - 1, 1, -2 do
    Bridge.offClient(owned[index], owned[index + 1])
    owned[index + 1] = nil
    owned[index] = nil
  end
end)

local function onPeLoaded(name)
  if name == "ProjectEbonhold" then
    Bridge.wrapClient()
    Bus.offCore("ADDON_LOADED", onPeLoaded)
  end
end

if not Bridge.wrapClient() then
  Bus.onCore("ADDON_LOADED", onPeLoaded)
end
