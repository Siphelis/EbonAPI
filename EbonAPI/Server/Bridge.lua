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

local type, tonumber, tostring, error, pairs = type, tonumber, tostring, error, pairs
local match, byte, len = string.match, string.byte, string.len

local PREFIX = "AAM0x9"
local MAX_PAYLOAD = 240
local MAX_CHUNKS = 400
local STREAM_TIMEOUT = 20
local STREAM_SWEEP = 2
local AT = 64

Bridge.PREFIX = PREFIX
Bridge.MAX_PAYLOAD = MAX_PAYLOAD
Bridge.MAX_CHUNKS = MAX_CHUNKS
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

local drops = Bridge.drops

local function now()
  return (GetTime and GetTime()) or 0
end

local streams = Assembler.new("EbonAPI:streams", STREAM_TIMEOUT, STREAM_SWEEP, MAX_CHUNKS, function(opcode, id, record)
  drops.expired = drops.expired + 1
  EbonAPI:Emit("STREAM_TIMEOUT", opcode, id, record.count, record.total)
end)

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

  Log.trace("recv", nil, opcode, len(body), at)

  local list = listeners[opcode]

  if list then
    list:fire(body, opcode, sender, distribution)
  end

  EbonAPI:Emit("SERVER_MESSAGE", opcode, body, sender)
end

local function ingest(payload, distribution, sender)
  local opcodeText, rest = match(payload, "^(%d+)\t?(.*)$")

  if not opcodeText then
    drops.header = drops.header + 1
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
    drops.bounds = drops.bounds + 1
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
      drops.sender = drops.sender + 1
      return
    end
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

  return true
end

Queue.register("server", rawSend)

local function build(opcode, body)
  if type(opcode) ~= "number" then
    error("EbonAPI.Bridge.send expects a numeric opcode, got " .. type(opcode), 3)
  end

  local payload

  if body == nil or body == "" then
    payload = tostring(opcode)
  else
    payload = opcode .. "\t" .. body
  end

  if len(payload) > MAX_PAYLOAD then
    error("EbonAPI.Bridge.send: payload of " .. len(payload) .. " bytes for opcode "
      .. opcode .. ", the limit is " .. MAX_PAYLOAD, 3)
  end

  return payload
end

function Bridge.send(opcode, body)
  return Queue.pushServer(build(opcode, body))
end

function Bridge.request(opcode, body, minInterval)
  minInterval = Lib.num(minInterval, 0)

  if minInterval <= 0 then
    return Bridge.send(opcode, body)
  end

  local payload = build(opcode, body)
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

  return Queue.pushServer(payload)
end

function Bridge.queueLength()
  return Queue.serverLength()
end

function Bridge.enable()
  if enabled then
    return false
  end

  enabled = true

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
