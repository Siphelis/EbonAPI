EbonAPI = EbonAPI or {}
EbonAPI.Queue = {}

local Queue = EbonAPI.Queue
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus

local type, pairs, next, error, tostring = type, pairs, next, error, tostring
local match, gsub, find, lower = string.match, string.gsub, string.find, string.lower

local SEND_INTERVAL = 0.15
local PEER_CAP = 500
local OFFLINE_HOLD = 60

Queue.SEND_INTERVAL = SEND_INTERVAL
Queue.PEER_CAP = PEER_CAP
Queue.OFFLINE_HOLD = OFFLINE_HOLD

local senders = {}
local gates = {}

local sPayload = {}
local sFirst, sLast = 1, 0

local pKind, pA, pB, pC, pDone = {}, {}, {}, {}, {}
local pFirst, pLast = 1, 0
local pLive = 0

local offlineUntil = {}
local recentWhisper = {}
local watching = false

Queue.sent = { server = 0, channel = 0, whisper = 0 }
Queue.dropped = { offline = 0, full = 0, failed = 0 }

local sent = Queue.sent
local dropped = Queue.dropped

local function now()
  return (GetTime and GetTime()) or 0
end

local function baseName(name)
  if type(name) ~= "string" then
    return nil
  end

  name = match(name, "^([^%-]+)") or name

  if name == "" then
    return nil
  end

  return name
end

Queue.baseName = baseName

function Queue.register(kind, fn, ready)
  if type(kind) ~= "string" or type(fn) ~= "function" then
    error("EbonAPI.Queue.register expects a kind and a function", 2)
  end

  senders[kind] = fn
  gates[kind] = ready
end

local function rawWhisper(prefix, target, text)
  if not SendAddonMessage then
    return false
  end

  SendAddonMessage(prefix, text, "WHISPER", target)

  return true
end

local offlineTemplate, offlinePattern

local function offlinePlayer(message)
  local template = ERR_CHAT_PLAYER_NOT_FOUND_S

  if type(template) ~= "string" or type(message) ~= "string"
    or not find(template, "%s", 1, true) then
    return nil
  end

  if template ~= offlineTemplate then
    local escaped = gsub(template, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")

    offlineTemplate, offlinePattern = template, (gsub(escaped, "%%%%s", "(.+)"))
  end

  return baseName(match(message, offlinePattern))
end

local onSystem

local function unwatch()
  if watching then
    watching = false
    Bus.offCore("CHAT_MSG_SYSTEM", onSystem)
  end
end

local function watch()
  if not watching then
    watching = true
    Bus.onCore("CHAT_MSG_SYSTEM", onSystem)
  end
end

local function settle(dones, count)
  for index = 1, count do
    Lib.safeCall(dones[index], false)
  end
end

local function purgeWhispers(target)
  local removed = 0
  local dones, count = {}, 0

  for index = pFirst, pLast do
    if pKind[index] == "whisper" and pB[index] == target then
      if pDone[index] then
        count = count + 1
        dones[count] = pDone[index]
      end

      pKind[index] = false
      pA[index], pB[index], pC[index], pDone[index] = nil, nil, nil, nil
      pLive = pLive - 1
      removed = removed + 1
    end
  end

  settle(dones, count)

  return removed
end

onSystem = function(message)
  local current = now()
  local alive = false

  for name, at in pairs(recentWhisper) do
    if current - at > OFFLINE_HOLD then
      recentWhisper[name] = nil
    else
      alive = true
    end
  end

  if not alive then
    unwatch()
    return
  end

  local name = offlinePlayer(message)

  if not name or not recentWhisper[name] then
    return
  end

  recentWhisper[name] = nil
  offlineUntil[name] = current + OFFLINE_HOLD

  local removed = purgeWhispers(name)

  dropped.offline = dropped.offline + removed

  Log.trace("offline", nil, name, removed, current)
  EbonAPI:Emit("PEER_OFFLINE", name, removed)
end

function Queue.isOffline(target)
  local until_ = offlineUntil[target]

  if not until_ then
    return false
  end

  if now() >= until_ then
    offlineUntil[target] = nil
    return false
  end

  return true
end

local function dispatch(kind, a, b, c)
  local fn = senders[kind]
  local ok = fn ~= nil and fn(a, b, c)

  if ok then
    sent[kind] = (sent[kind] or 0) + 1
    Log.trace("send", nil, kind, a)
  else
    dropped.failed = dropped.failed + 1
    Log.trace("fail", nil, kind, a)
    EbonAPI:Emit("SEND_FAILED", kind, a, b)
  end

  return ok
end

local function popServer()
  local payload = sPayload[sFirst]

  sPayload[sFirst] = nil
  sFirst = sFirst + 1

  if sFirst > sLast then
    sFirst, sLast = 1, 0
  end

  return payload
end

local function takePeer()
  while pFirst <= pLast and not pKind[pFirst] do
    pKind[pFirst] = nil
    pFirst = pFirst + 1
  end

  if pFirst > pLast then
    pFirst, pLast = 1, 0
    return nil
  end

  for index = pFirst, pLast do
    local kind = pKind[index]

    if kind then
      local ready = gates[kind]

      if not ready or ready() then
        local a, b, c, done = pA[index], pB[index], pC[index], pDone[index]

        pKind[index], pA[index], pB[index], pC[index], pDone[index] = false, nil, nil, nil, nil
        pLive = pLive - 1

        return kind, a, b, c, done
      end
    end
  end

  return nil
end

local function drain()
  if sFirst <= sLast then
    dispatch("server", popServer())
  else
    local kind, a, b, c, done = takePeer()

    if kind then
      if kind == "whisper" then
        recentWhisper[b] = now()
        watch()
      end

      local ok = dispatch(kind, a, b, c)

      if done then
        Lib.safeCall(done, ok and true or false)
      end
    elseif pLive > 0 then
      Bus.untick("EbonAPI:queue")
      return
    end
  end

  if sFirst > sLast and pLive == 0 then
    Bus.untick("EbonAPI:queue")
  end
end

local function arm()
  Bus.tick("EbonAPI:queue", SEND_INTERVAL, drain)
end

function Queue.wake()
  if sFirst <= sLast or pLive > 0 then
    arm()
  end
end

function Queue.pushServer(payload)
  sLast = sLast + 1
  sPayload[sLast] = payload

  arm()

  return true
end

function Queue.room()
  return PEER_CAP - pLive
end

function Queue.push(kind, a, b, c, done)
  if type(kind) ~= "string" or not senders[kind] then
    error("EbonAPI.Queue.push: unknown kind " .. tostring(kind), 2)
  end

  if pLive >= PEER_CAP then
    dropped.full = dropped.full + 1
    return false
  end

  if kind == "whisper" and Queue.isOffline(b) then
    dropped.offline = dropped.offline + 1
    return false
  end

  pLast = pLast + 1
  pKind[pLast], pA[pLast], pB[pLast], pC[pLast], pDone[pLast] = kind, a, b, c, done
  pLive = pLive + 1

  arm()

  return true
end

function Queue.serverLength()
  return sLast - sFirst + 1
end

function Queue.peerLength()
  return pLive
end

function Queue.length()
  return Queue.serverLength() + pLive
end

function Queue.clear()
  for index = sFirst, sLast do
    sPayload[index] = nil
  end

  local dones, count = {}, 0

  for index = pFirst, pLast do
    if pKind[index] and pDone[index] then
      count = count + 1
      dones[count] = pDone[index]
    end

    pKind[index], pA[index], pB[index], pC[index], pDone[index] = nil, nil, nil, nil, nil
  end

  sFirst, sLast = 1, 0
  pFirst, pLast = 1, 0
  pLive = 0

  Bus.untick("EbonAPI:queue")

  settle(dones, count)
end

Queue.register("whisper", rawWhisper)
