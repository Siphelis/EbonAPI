EbonAPI = EbonAPI or {}
EbonAPI.Decoders = {}

local Decoders = EbonAPI.Decoders
local Bridge = EbonAPI.Bridge
local Listeners = EbonAPI.Listeners
local Problems = EbonAPI.Problems
local Handle = EbonAPI.Handle
local fanout = EbonAPI.fanout
local report = EbonAPI.Lib.report

local type, pcall, error = type, pcall, error
local sub = string.sub
local find = string.find

local entries = {}

function Decoders.split(text, sep)
  local out, n, start = {}, 0, 1

  while true do
    local at = find(text, sep, start, true)

    n = n + 1

    if not at then
      out[n] = sub(text, start)

      return out, n
    end

    out[n] = sub(text, start, at - 1)
    start = at + 1
  end
end

local function reject(entry, opcode, reason, body)
  Problems.reject("EbonAPI", "SERVER.BODY_REJECTED", {
    opcode = opcode, reason = reason, field = entry.spec.name,
    sample = type(body) == "string" and sub(body, 1, 60) or type(body),
  })
end

local function run(entry, opcode, body)
  local ok, value, reason = pcall(entry.spec.decode, body, opcode)

  if not ok then
    report(value)

    return nil
  end

  if value == nil then
    reject(entry, opcode, reason or "rejected", body)
  end

  return value
end

local function publish(entry, opcode, value, body)
  local subs = entry.subs

  subs.busy = subs.busy + 1
  fanout(subs.fns, subs.owners, subs.n, value, opcode, body)
  subs.busy = subs.busy - 1
end

local function onEvent(entry, opcode, body)
  local value = run(entry, opcode, body)

  if value ~= nil then
    publish(entry, opcode, value, body)
  end
end

function Decoders.register(opcode, spec)
  if type(opcode) ~= "number" then
    error("EbonAPI.Decoders.register expects a numeric opcode, got " .. type(opcode), 2)
  end

  if type(spec) ~= "table" or type(spec.decode) ~= "function" then
    error("EbonAPI.Decoders.register expects a spec with a decode function for opcode " .. opcode, 2)
  end

  local mode = spec.mode or "event"

  if mode ~= "event" and mode ~= "state" then
    error("EbonAPI.Decoders.register: mode must be 'event' or 'state' (opcode " .. opcode .. ")", 2)
  end

  if entries[opcode] then
    return false
  end

  local entry = {
    spec = spec, mode = mode, subs = Listeners.new(), listening = false,
    raw = nil, cached = false, value = nil,
  }

  if mode == "state" then
    entry.listener = function(body)
      entry.raw = body
      entry.cached = false
      entry.value = nil

      if entry.subs.n > 0 then
        local value = run(entry, opcode, body)

        entry.value = value
        entry.cached = true

        if value ~= nil then
          publish(entry, opcode, value, body)
        end
      end
    end

    entry.listening = true
    Bridge.on(opcode, entry.listener)
  else
    entry.listener = function(body)
      return onEvent(entry, opcode, body)
    end
  end

  entries[opcode] = entry

  return true
end

function Decoders.subscribe(opcode, fn)
  if type(opcode) ~= "number" or type(fn) ~= "function" then
    error("EbonAPI.Decoders.subscribe expects (opcode, function)", 2)
  end

  local entry = entries[opcode]

  if not entry or not entry.subs:add(fn) then
    return false
  end

  if not entry.listening then
    entry.listening = true
    Bridge.on(opcode, entry.listener)
  end

  return true
end

function Decoders.unsubscribe(opcode, fn)
  local entry = entries[opcode]

  if not entry or not entry.subs:remove(fn) then
    return false
  end

  if entry.mode == "event" and entry.subs.n == 0 and entry.listening then
    entry.listening = false
    Bridge.off(opcode, entry.listener)
  end

  return true
end

function Decoders.get(opcode)
  local entry = entries[opcode]

  if not entry or entry.mode ~= "state" or entry.raw == nil then
    return nil
  end

  if not entry.cached then
    entry.value = run(entry, opcode, entry.raw)
    entry.cached = true
  end

  return entry.value, entry.raw
end

function Decoders.raw(opcode)
  local entry = entries[opcode]

  return entry and entry.raw or nil
end

function Decoders.decode(opcode, body)
  local entry = entries[opcode]

  if not entry then
    return nil, "no_decoder"
  end

  local ok, value, reason = pcall(entry.spec.decode, body, opcode)

  if not ok then
    return nil, "error"
  end

  return value, reason
end

function Decoders.has(opcode)
  return entries[opcode] ~= nil
end

function Handle:SubscribeServer(opcode, fn)
  if not Decoders.subscribe(opcode, fn) then
    return false
  end

  local owned = self._decoders

  if not owned then
    owned = {}
    self._decoders = owned
  end

  owned[#owned + 1] = opcode
  owned[#owned + 1] = fn

  return true
end

function Handle:UnsubscribeServer(opcode, fn)
  local owned = self._decoders

  if not owned then
    return false
  end

  for index = #owned - 1, 1, -2 do
    if owned[index] == opcode and owned[index + 1] == fn then
      table.remove(owned, index + 1)
      table.remove(owned, index)

      return Decoders.unsubscribe(opcode, fn)
    end
  end

  return false
end

function Handle:ServerState(opcode)
  return Decoders.get(opcode)
end

EbonAPI:AddTeardown(function(handle)
  local owned = handle._decoders

  if not owned then
    return
  end

  for index = #owned - 1, 1, -2 do
    Decoders.unsubscribe(owned[index], owned[index + 1])
    owned[index + 1] = nil
    owned[index] = nil
  end
end)
