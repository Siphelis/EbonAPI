EbonAPI = EbonAPI or {}
EbonAPI.Share = {}

local Share = EbonAPI.Share
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Hash = EbonAPI.Hash
local Keys = EbonAPI.Keys
local Channel = EbonAPI.Channel
local Whisper = EbonAPI.Whisper
local Handle = EbonAPI.Handle

local type, pairs, next, error, tostring, tonumber, pcall = type, pairs, next, error, tostring, tonumber, pcall
local match, gmatch, len, format, concat, sort = string.match, string.gmatch, string.len, string.format, table.concat, table.sort
local random = math.random

local NAME = "EbonAPI"
local PREFIX = "EbonAPI"
local TEXT_MAX = 32768
local JOIN_DELAY = 2
local CHANGE_DELAY = 15
local MANUAL_COOLDOWN = 30
local REPLY_MIN, REPLY_MAX = 1, 5
local ROUND_INTERVAL = 120
local PEER_TTL = 600
local FETCH_TIMEOUT = 30
local REQUEST_COOLDOWN = 10

Share.PREFIX = PREFIX
Share.TEXT_MAX = TEXT_MAX
Share.JOIN_DELAY = JOIN_DELAY
Share.CHANGE_DELAY = CHANGE_DELAY
Share.MANUAL_COOLDOWN = MANUAL_COOLDOWN
Share.REPLY_MAX = REPLY_MAX
Share.ROUND_INTERVAL = ROUND_INTERVAL
Share.FETCH_TIMEOUT = FETCH_TIMEOUT

local store = nil
local enabled = false
local ticking = false
local rounding = false
local awaitingServe = false
local announceAt = nil
local lastManual = nil
local peers = {}
local replies = {}
local fetching = {}
local recent = {}
local rules = {}

Share.sent = { lines = 0, keys = 0, data = 0 }
Share.received = 0
Share.refused = 0

local function now()
  return (GetTime and GetTime()) or 0
end

local function texts()
  if not store then
    store = DB.store("EbonAPI", { account = { shared = {} } })
  end

  local held = store.account.shared

  if type(held) ~= "table" then
    held = {}
    store.account.shared = held
  end

  return held
end

function Share.set(addon, name, state, text)
  state = Keys.check(addon, name, state, 3)

  if type(text) ~= "string" then
    error(format('EbonAPI: %s: share "%s": text must be a string, got %s', addon, name, type(text)), 2)
  end

  if len(text) > TEXT_MAX then
    error(format('EbonAPI: %s: share "%s": text is %d bytes long (maximum %d)', addon, name, len(text), TEXT_MAX), 2)
  end

  local held = texts()
  local own = held[addon]

  if not own then
    own = {}
    held[addon] = own
  end

  local changed = own[name] ~= text

  own[name] = text

  if Keys.put(addon, name, state) then
    changed = true
  end

  return changed
end

function Share.remove(addon, name)
  local held = texts()
  local own = held[addon]

  if own then
    own[name] = nil

    if next(own) == nil then
      held[addon] = nil
    end
  end

  return Keys.remove(addon, name)
end

function Share.get(addon, name)
  local own = texts()[addon]

  if not own then
    return nil, Keys.get(addon, name)
  end

  return own[name], Keys.get(addon, name)
end

local function line()
  local addons = Keys.addons()
  local out = {}

  for i = 1, #addons do
    out[i] = addons[i] .. "=" .. Keys.part(addons[i])
  end

  return concat(out, ",")
end

local function parseLine(body)
  local parts = {}

  for addon, part in gmatch(body, "([%w_]+)=([%w%-_]+)") do
    if len(part) == Hash.LENGTH then
      parts[addon] = part
    end
  end

  return parts
end

local function compare(theirs)
  local wanted, any = {}, false
  local addons = Keys.addons()
  local mine = {}

  for i = 1, #addons do
    local addon = addons[i]

    mine[addon] = Keys.part(addon)

    if not theirs[addon] then
      any = true
    end
  end

  for addon, part in pairs(theirs) do
    if mine[addon] ~= part then
      wanted[#wanted + 1] = addon
      any = true
    end
  end

  sort(wanted, Hash.before)

  return wanted, any
end

local function throttled(peer, kind)
  local key = peer .. ":" .. kind
  local current = now()
  local last = recent[key]

  if last and current - last < REQUEST_COOLDOWN then
    return true
  end

  recent[key] = current

  return false
end

local tick

local function arm()
  if not ticking then
    ticking = true
    Bus.tick("EbonAPI:share", 1, tick)
  end
end

local function idle()
  return announceAt == nil and next(replies) == nil and next(fetching) == nil
end

local function announce()
  announceAt = nil

  if not Channel.isJoined() or not Channel.say(NAME, "F", line()) then
    return false
  end

  Share.sent.lines = Share.sent.lines + 1
  awaitingServe = true
  Log.trace("share", nil, "F")

  return true
end

local function schedule(delay)
  if not announceAt then
    announceAt = now() + delay
    arm()
  end
end

local function whisperLine(peer, op)
  if not Whisper.stream(PREFIX, peer, op, nil, line()) then
    return false
  end

  Share.sent.lines = Share.sent.lines + 1

  return true
end

tick = function()
  local current = now()

  if announceAt and current >= announceAt then
    announce()
  end

  for peer, at in pairs(replies) do
    if current >= at then
      replies[peer] = nil
      whisperLine(peer, "F")
    end
  end

  for key, fetch in pairs(fetching) do
    if current - fetch.at > FETCH_TIMEOUT then
      fetching[key] = nil
      Log.trace("share", nil, "timeout", key)
    end
  end

  for key, at in pairs(recent) do
    if current - at > REQUEST_COOLDOWN then
      recent[key] = nil
    end
  end

  if idle() then
    ticking = false
    Bus.untick("EbonAPI:share")
  end
end

local round

local function armRound()
  if not rounding then
    rounding = true
    Bus.tick("EbonAPI:share-round", ROUND_INTERVAL, round)
  end
end

local function remember(sender, body)
  local parts = parseLine(body)
  local info = peers[sender]

  if not info then
    info = {}
    peers[sender] = info
    armRound()
  end

  info.parts = parts
  info.at = now()

  return parts
end

local function requestKeys(peer, addons)
  if #addons == 0 or throttled(peer, "Q") then
    return false
  end

  if not Whisper.stream(PREFIX, peer, "Q", nil, concat(addons, ",")) then
    return false
  end

  Share.sent.keys = Share.sent.keys + 1

  return true
end

local function onChannelLine(sender, body)
  local parts = remember(sender, body)
  local _, any = compare(parts)

  if any then
    replies[sender] = now() + REPLY_MIN + random() * (REPLY_MAX - REPLY_MIN)
    arm()
  end
end

local function onChannelServed(sender)
  replies[sender] = nil
end

local function onLineStream(sender, body, _, op)
  local parts = remember(sender, body)

  if op == "F" then
    if awaitingServe then
      awaitingServe = false
      Channel.say(NAME, "S", "")
    end

    whisperLine(sender, "f")
  end

  requestKeys(sender, (compare(parts)))
end

local function keysText(addon)
  local names = Keys.names(addon)
  local out = {}

  for i = 1, #names do
    out[i] = names[i] .. "=" .. Keys.get(addon, names[i])
  end

  return concat(out, ";")
end

local function onQueryStream(sender, body)
  if throttled(sender, "K") then
    return
  end

  for addon in gmatch(body, "[%w_]+") do
    if Whisper.stream(PREFIX, sender, "K", addon, keysText(addon)) then
      Share.sent.keys = Share.sent.keys + 1
    end
  end
end

local function wanted(addon, name, theirs, mine)
  local rule = rules[addon]

  if rule then
    local ok, result = pcall(rule, name, theirs, mine)

    if not ok then
      Lib.report(result)
      return false
    end

    return result and true or false
  end

  return mine == nil or tonumber(theirs) > tonumber(mine)
end

local function requestData(peer, addon, name)
  local key = addon .. "." .. name

  if fetching[key] or not Channel.whisper(PREFIX, peer, "G:" .. key) then
    return false
  end

  fetching[key] = { peer = peer, at = now() }
  arm()

  return true
end

local function onKeysStream(sender, body, addon)
  if not match(addon, "^[%w_]+$") then
    return
  end

  for name, state in gmatch(body, "([%w_]+)=(%d+)") do
    state = Keys.read(name, state)

    if state then
      local mine = Keys.get(addon, name)

      if mine ~= state and wanted(addon, name, state, mine) then
        requestData(sender, addon, name)
      end
    end
  end
end

local function onWhisper(sender, text)
  local op, rest = match(text, "^(%a):(.*)$")

  if op == "G" then
    local addon, name = match(rest, "^([%w_]+)%.([%w_]+)$")

    if not addon or throttled(sender, "G" .. rest) then
      return
    end

    local held, state = Share.get(addon, name)

    if held and state then
      if Whisper.stream(PREFIX, sender, "D", rest, state .. "|" .. held) then
        Share.sent.data = Share.sent.data + 1
      end
    else
      Channel.whisper(PREFIX, sender, "X:" .. rest)
    end
  elseif op == "X" then
    local fetch = fetching[rest]

    if fetch and fetch.peer == sender then
      fetching[rest] = nil
    end
  end
end

local function onDataStream(sender, body, id)
  local fetch = fetching[id]

  if not fetch or fetch.peer ~= sender then
    return
  end

  fetching[id] = nil

  local addon, name = match(id, "^([%w_]+)%.([%w_]+)$")
  local state, text = match(body, "^([^|]*)|(.*)$")

  if addon and state then
    state = Keys.read(name, state)
  end

  if not addon or not state or len(text) > TEXT_MAX then
    Share.refused = Share.refused + 1
    return
  end

  local held = texts()
  local own = held[addon]

  if not own then
    own = {}
    held[addon] = own
  end

  own[name] = text
  Keys.put(addon, name, state)
  Share.received = Share.received + 1
  Log.trace("share", nil, id, len(text))
  EbonAPI:Emit("SHARE_RECEIVED", addon, name, state, sender)
end

local function onKeyChanged()
  if enabled then
    schedule(CHANGE_DELAY)
  end
end

local function onJoined()
  schedule(JOIN_DELAY)
end

local function onPeerOffline(_, name)
  peers[name] = nil
  replies[name] = nil

  for key, fetch in pairs(fetching) do
    if fetch.peer == name then
      fetching[key] = nil
    end
  end
end

round = function()
  local current = now()
  local candidates = {}

  for peer, info in pairs(peers) do
    if current - info.at > PEER_TTL then
      peers[peer] = nil
    else
      local _, any = compare(info.parts)

      if any then
        candidates[#candidates + 1] = peer
      end
    end
  end

  if next(peers) == nil then
    rounding = false
    Bus.untick("EbonAPI:share-round")
  end

  if #candidates == 0 then
    return
  end

  sort(candidates)
  whisperLine(candidates[random(#candidates)], "F")
end

function Share.announce()
  local current = now()

  if lastManual and current - lastManual < MANUAL_COOLDOWN then
    return false
  end

  if not announce() then
    return false
  end

  lastManual = current

  return true
end

function Share.summary()
  local addons = Keys.addons()
  local keys = 0

  for i = 1, #addons do
    keys = keys + #Keys.names(addons[i])
  end

  return keys, #addons, Lib.count(peers), Share.received, Share.refused
end

function Share.peerCount()
  return Lib.count(peers)
end

function Share.isFetching(addon, name)
  return fetching[addon .. "." .. name] ~= nil
end

function Share.enable()
  if enabled then
    return false
  end

  enabled = true

  texts()

  Channel.on(NAME, "F", onChannelLine)
  Channel.on(NAME, "S", onChannelServed)
  Whisper.on(PREFIX, onWhisper)
  Whisper.onStream(PREFIX, "F", onLineStream)
  Whisper.onStream(PREFIX, "f", onLineStream)
  Whisper.onStream(PREFIX, "Q", onQueryStream)
  Whisper.onStream(PREFIX, "K", onKeysStream)
  Whisper.onStream(PREFIX, "D", onDataStream)

  EbonAPI:On("SHARE_KEY_CHANGED", onKeyChanged)
  EbonAPI:On("PEER_OFFLINE", onPeerOffline)
  EbonAPI:On("CHANNEL_JOINED", onJoined)

  return true
end

function Share.disable()
  if not enabled then
    return false
  end

  enabled = false

  Channel.off(NAME, "F", onChannelLine)
  Channel.off(NAME, "S", onChannelServed)
  Whisper.off(PREFIX, onWhisper)
  Whisper.offStream(PREFIX, "F", onLineStream)
  Whisper.offStream(PREFIX, "f", onLineStream)
  Whisper.offStream(PREFIX, "Q", onQueryStream)
  Whisper.offStream(PREFIX, "K", onKeysStream)
  Whisper.offStream(PREFIX, "D", onDataStream)

  EbonAPI:Off("SHARE_KEY_CHANGED", onKeyChanged)
  EbonAPI:Off("PEER_OFFLINE", onPeerOffline)
  EbonAPI:Off("CHANNEL_JOINED", onJoined)

  Bus.untick("EbonAPI:share-round")
  Bus.untick("EbonAPI:share")

  for key in pairs(peers) do peers[key] = nil end
  for key in pairs(replies) do replies[key] = nil end
  for key in pairs(fetching) do fetching[key] = nil end
  for key in pairs(recent) do recent[key] = nil end

  ticking = false
  rounding = false
  awaitingServe = false
  announceAt = nil

  return true
end

function Handle:Share(name, state, text)
  return Share.set(self.addonName, name, state, text)
end

function Handle:Unshare(name)
  return Share.remove(self.addonName, name)
end

function Handle:GetShared(name, addon)
  return Share.get(addon or self.addonName, name)
end

function Handle:SharedNames(addon)
  return Keys.names(addon or self.addonName)
end

function Handle:ShareRule(fn)
  if fn ~= nil and type(fn) ~= "function" then
    error("EbonAPI: " .. self.addonName .. ": ShareRule expects a function or nil, got " .. type(fn), 2)
  end

  rules[self.addonName] = fn

  return true
end

function Handle:SyncShares()
  return Share.announce()
end

EbonAPI:AddTeardown(function(handle)
  rules[handle.addonName] = nil
end)
