EbonAPI = EbonAPI or {}
EbonAPI.Channel = {}

local Channel = EbonAPI.Channel
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local Queue = EbonAPI.Queue
local Listeners = EbonAPI.Listeners
local Assembler = EbonAPI.Assembler
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local type, tonumber, tostring, error, pcall = type, tonumber, tostring, error, pcall
local match, find, lower, len, format = string.match, string.find, string.lower, string.len, string.format
local ceil = math.ceil

local NAME = "ebonapi"
local TAG = "EA1"
local LINE_MAX = 255
local PACKET_MAX = 16
local ASSEMBLY_TIMEOUT = 30
local ASSEMBLY_SWEEP = 5
local JOIN_TICK = 1
local JOIN_RETRY = 10
local JOIN_WARN = 3

Channel.NAME = NAME
Channel.TAG = TAG
Channel.LINE_MAX = LINE_MAX
Channel.PACKET_MAX = PACKET_MAX
Channel.ASSEMBLY_TIMEOUT = ASSEMBLY_TIMEOUT

Channel.LETTERS = {
  AutoCallboard = "A",
  EbonBuilds = "B",
  SkillTreeAutoLoad = "S",
  EbonStat = "G",
  EbonAPI = "E",
}

local listeners = {}
local wanted = false
local enabled = false
local joined = false
local index = nil
local joinAttempts = 0
local joinedAt = nil
local warned = false
local serial = 0
local baseName = Queue.baseName

Channel.received = 0
Channel.drops = { tag = 0, bounds = 0, expired = 0, own = 0 }

local drops = Channel.drops

local function now()
  return (GetTime and GetTime()) or 0
end

local function myName()
  return (UnitName and UnitName("player")) or ""
end

local streams = Assembler.new("EbonAPI:assembly", ASSEMBLY_TIMEOUT, ASSEMBLY_SWEEP, PACKET_MAX, function()
  drops.expired = drops.expired + 1
end)

local function keyFor(letter, op)
  return letter .. ":" .. op
end

function Channel.on(letter, op, fn)
  if type(letter) ~= "string" or not match(letter, "^%u$") then
    error("EbonAPI.Channel.on attend une lettre d'addon, recu " .. tostring(letter), 2)
  end

  if type(op) ~= "string" or not match(op, "^%w+$") then
    error("EbonAPI.Channel.on attend une op alphanumerique, recu " .. tostring(op), 2)
  end

  if type(fn) ~= "function" then
    error("EbonAPI.Channel.on attend une fonction pour " .. letter .. ":" .. op .. ", recu " .. type(fn), 2)
  end

  local key = keyFor(letter, op)
  local list = listeners[key]

  if not list then
    list = Listeners.new()
    listeners[key] = list
  end

  return list:add(fn)
end

function Channel.off(letter, op, fn)
  local key = keyFor(letter, op)
  local list = listeners[key]

  if not list or not list:remove(fn) then
    return false
  end

  if list.n == 0 then
    listeners[key] = nil
  end

  return true
end

function Channel.listenerCount(letter, op)
  local list = listeners[keyFor(letter, op)]

  return list and list.n or 0
end

local function hide(name)
  if not ChatFrame_RemoveChannel then
    return
  end

  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]

    if frame then
      pcall(ChatFrame_RemoveChannel, frame, name)
    end
  end
end

local function resolve(name)
  if GetChannelName then
    local id = GetChannelName(name)

    if type(id) == "number" and id > 0 then
      return id
    end
  end

  if GetChannelList then
    local list = { GetChannelList() }

    for i = 1, #list, 2 do
      local id, found = tonumber(list[i]), list[i + 1]

      if id and id > 0 and type(found) == "string" and lower(found) == name then
        return id
      end
    end
  end

  return nil
end

local onChannelMessage
local tryJoin

local function lose()
  if not joined then
    return
  end

  joined = false
  index = nil
  joinedAt = nil
  joinAttempts = 0
  EbonAPI:ClearSticky("CHANNEL_JOINED")
  Log.trace("chan", nil, "lost")
  EbonAPI:Emit("CHANNEL_LOST")

  if enabled and wanted and not tryJoin() then
    Bus.tick("EbonAPI:channel", JOIN_TICK, tryJoin)
  end
end

tryJoin = function()
  local id = resolve(NAME)

  if id then
    index = id

    if not joined then
      joined = true
      joinedAt = now()
      hide(NAME)
      Bus.untick("EbonAPI:channel")
      Bus.onCore("CHAT_MSG_CHANNEL", onChannelMessage)
      Log.trace("chan", nil, "joined", id)
      EbonAPI:Emit("CHANNEL_JOINED", id)
      Queue.wake()
    end

    return true
  end

  if joinAttempts % JOIN_RETRY == 0 and JoinChannelByName then
    pcall(JoinChannelByName, NAME)
    joinAttempts = joinAttempts + 1

    if not warned and joinAttempts > JOIN_RETRY * JOIN_WARN then
      warned = true
      Log.warn("EbonAPI", format(L.CHANNEL_JOIN_SLOW, NAME, ceil(joinAttempts / JOIN_RETRY)))
    end

    return tryJoin()
  end

  joinAttempts = joinAttempts + 1

  return false
end

local function ours(channelString, channelBase)
  if type(channelBase) == "string" and channelBase ~= "" then
    return lower(channelBase) == NAME
  end

  return type(channelString) == "string" and find(lower(channelString), NAME, 1, true) ~= nil
end

local function onNotice(kind, _, _, channelString, _, _, _, _, channelBase)
  if not ours(channelString, channelBase) then
    return
  end

  if kind == "YOU_LEFT" or kind == "SUSPENDED" then
    lose()
  elseif kind == "YOU_JOINED" and wanted and not joined then
    tryJoin()
  end
end

local function recheck()
  if not wanted then
    return
  end

  if not joined then
    if enabled and not tryJoin() then
      Bus.tick("EbonAPI:channel", JOIN_TICK, tryJoin)
    end

    return
  end

  local id = resolve(NAME)

  if id then
    index = id
  else
    lose()
  end
end

function Channel.require()
  if wanted then
    return joined
  end

  wanted = true

  if enabled and not joined then
    if not tryJoin() then
      Bus.tick("EbonAPI:channel", JOIN_TICK, tryJoin)
    end
  end

  return joined
end

function Channel.enable()
  if enabled then
    return false
  end

  enabled = true

  Bus.onCore("CHAT_MSG_CHANNEL_NOTICE", onNotice)
  Bus.onCore("CHANNEL_UI_UPDATE", recheck)
  Bus.onCore("PLAYER_ENTERING_WORLD", recheck)

  if wanted and not joined and not tryJoin() then
    Bus.tick("EbonAPI:channel", JOIN_TICK, tryJoin)
  end

  return true
end

function Channel.disable()
  if not enabled then
    return false
  end

  enabled = false

  if joined then
    joined = false
    index = nil
    joinedAt = nil
    Bus.offCore("CHAT_MSG_CHANNEL", onChannelMessage)
  end

  joinAttempts = 0
  warned = false

  Bus.offCore("CHAT_MSG_CHANNEL_NOTICE", onNotice)
  Bus.offCore("CHANNEL_UI_UPDATE", recheck)
  Bus.offCore("PLAYER_ENTERING_WORLD", recheck)
  Bus.untick("EbonAPI:channel")
  streams:clear()

  return true
end

function Channel.isWanted()
  return wanted
end

function Channel.isJoined()
  return joined
end

function Channel.index()
  return index
end

function Channel.joinedFor()
  if not joinedAt then
    return nil
  end

  return now() - joinedAt
end

function Channel.requests()
  return ceil(joinAttempts / JOIN_RETRY)
end

local function deliver(letter, op, sender, body, at)
  Channel.received = Channel.received + 1
  Log.trace("chan", nil, letter .. ":" .. op, len(body), at)

  local list = listeners[keyFor(letter, op)]

  if list then
    list:fire(sender, body, letter, op)
  end
end

local function fromOurChannel(channelIndex, channelString, channelBase)
  if channelIndex ~= nil and channelIndex == index then
    return true
  end

  if not ours(channelString, channelBase) then
    return false
  end

  if type(channelIndex) == "number" and channelIndex > 0 then
    index = channelIndex
  end

  return true
end

onChannelMessage = function(text, sender, _, channelString, _, _, _, channelIndex, channelBase)
  if not fromOurChannel(channelIndex, channelString, channelBase) then
    return
  end

  if type(text) ~= "string" then
    return
  end

  local start = find(text, "EA1:", 1, true)

  if not start then
    drops.tag = drops.tag + 1
    return
  end

  local letter, op, number, k, n, body = match(text, "^(%u):(%w+):(%d+)%.(%d+)/(%d+):(.*)$", start + 4)

  if not letter then
    drops.tag = drops.tag + 1
    return
  end

  sender = baseName(sender)

  if not sender or sender == myName() then
    drops.own = drops.own + 1
    return
  end

  local at = now()

  if k == "1" and n == "1" then
    deliver(letter, op, sender, body, at)
    return
  end

  local whole, state = streams:add(sender, letter .. ":" .. op .. ":" .. number, tonumber(k), tonumber(n), body, at)

  if state == "bounds" then
    drops.bounds = drops.bounds + 1
    return
  end

  if whole then
    deliver(letter, op, sender, whole, at)
  end
end

function Channel.streamCount()
  return streams:count()
end

local function channelReady()
  if not joined then
    return false
  end

  local id = resolve(NAME)

  if id then
    index = id
    return true
  end

  lose()

  return false
end

local function rawChannel(text)
  if not SendChatMessage or not index then
    return false
  end

  return (pcall(SendChatMessage, text, "CHANNEL", nil, index))
end

local slices = {}

function Channel.say(letter, op, body, done)
  if type(letter) ~= "string" or not match(letter, "^%u$") then
    error("EbonAPI.Channel.say attend une lettre d'addon, recu " .. tostring(letter), 2)
  end

  if type(op) ~= "string" or not match(op, "^%w+$") then
    error("EbonAPI.Channel.say attend une op alphanumerique, recu " .. tostring(op), 2)
  end

  body = body or ""

  if type(body) ~= "string" then
    error("EbonAPI.Channel.say attend un corps texte pour " .. letter .. ":" .. op .. ", recu " .. type(body), 2)
  end

  if find(body, "|", 1, true) then
    error("EbonAPI.Channel.say: le corps de " .. letter .. ":" .. op .. " contient '|'", 2)
  end

  Channel.require()

  if not joined then
    return false
  end

  local number = serial % 999999 + 1
  local head = TAG .. ":" .. letter .. ":" .. op .. ":" .. number .. "."
  local budget = LINE_MAX - len(head) - 6

  if budget < 1 then
    error("EbonAPI.Channel.say: op trop longue pour " .. letter .. ":" .. op, 2)
  end

  local length = len(body)
  local total = PACKET_MAX + 1

  if ceil(length / budget) <= PACKET_MAX then
    local _, count = Lib.splitUtf8(body, budget, slices)

    total = count
  end

  if total > PACKET_MAX then
    error("EbonAPI.Channel.say: corps de " .. length .. " caracteres pour " .. letter .. ":"
      .. op .. ", la limite est " .. (PACKET_MAX * budget), 2)
  end

  if Queue.room() < total then
    return false
  end

  serial = number

  for packet = 1, total do
    Queue.push("channel", head .. packet .. "/" .. total .. ":" .. slices[packet], nil, nil,
      packet == total and done or nil)
  end

  return true
end

function Channel.whisper(prefix, target, text)
  if type(prefix) ~= "string" or prefix == "" then
    error("EbonAPI.Channel.whisper attend un prefixe, recu " .. tostring(prefix), 2)
  end

  local room = LINE_MAX - len(prefix) - 1

  if type(text) ~= "string" or len(text) > room then
    error("EbonAPI.Channel.whisper: texte absent ou au-dela de " .. room .. " octets pour le prefixe " .. prefix, 2)
  end

  target = baseName(target)

  if not target then
    return false
  end

  return Queue.push("whisper", prefix, target, text)
end

function Channel.whisperAll(prefix, target, parts, count)
  count = count or #parts

  if count == 0 then
    return true
  end

  target = baseName(target)

  if not target or Queue.isOffline(target) or Queue.room() < count then
    return false
  end

  for i = 1, count do
    Channel.whisper(prefix, target, parts[i])
  end

  return true
end

function Channel.droppedTotal()
  return drops.tag + drops.bounds + drops.expired
end

function Handle:ChannelLetter()
  return Channel.LETTERS[self.addonName]
end

function Handle:OnChannel(letter, op, fn)
  if not Channel.on(letter, op, fn) then
    return false
  end

  Channel.require()

  local owned = self._channel

  if not owned then
    owned = {}
    self._channel = owned
  end

  owned[#owned + 1] = letter
  owned[#owned + 1] = op
  owned[#owned + 1] = fn

  return true
end

function Handle:OffChannel(letter, op, fn)
  local owned = self._channel

  if owned then
    for i = #owned - 2, 1, -3 do
      if owned[i] == letter and owned[i + 1] == op and owned[i + 2] == fn then
        table.remove(owned, i + 2)
        table.remove(owned, i + 1)
        table.remove(owned, i)
      end
    end
  end

  return Channel.off(letter, op, fn)
end

function Handle:Say(op, body)
  local letter = Channel.LETTERS[self.addonName]

  if not letter then
    error("EbonAPI: " .. self.addonName .. " n'a pas de lettre sur le canal commun", 2)
  end

  return Channel.say(letter, op, body)
end

function Handle:Whisper(prefix, target, text)
  return Channel.whisper(prefix, target, text)
end

function Handle:WhisperAll(prefix, target, parts, count)
  return Channel.whisperAll(prefix, target, parts, count)
end

function Handle:IsChannelJoined()
  return joined
end

EbonAPI:AddTeardown(function(handle)
  local owned = handle._channel

  if not owned then
    return
  end

  for i = #owned - 2, 1, -3 do
    Channel.off(owned[i], owned[i + 1], owned[i + 2])
    owned[i + 2], owned[i + 1], owned[i] = nil, nil, nil
  end
end)

Queue.register("channel", rawChannel, channelReady)

EbonAPI:DeclareSticky("CHANNEL_JOINED")
