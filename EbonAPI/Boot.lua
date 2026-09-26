EbonAPI = EbonAPI or {}

local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Locale = EbonAPI.Locale
local Bridge = EbonAPI.Bridge
local Queue = EbonAPI.Queue
local Channel = EbonAPI.Channel
local Profile = EbonAPI.Profile
local Session = EbonAPI.Session
local Version = EbonAPI.Version
local Ebonhold = EbonAPI.Ebonhold
local State = EbonAPI.State
local Opcodes = EbonAPI.Opcodes
local Format = EbonAPI.Format
local Perf = EbonAPI.Perf
local L = EbonAPI.L

local tostring, tonumber, pairs = tostring, tonumber, pairs
local format, lower, match = string.format, string.lower, string.match

local ADDON_NAME = "EbonAPI"

local onAddonLoaded, onPlayerLogin

onAddonLoaded = function(name)
  if name ~= ADDON_NAME then
    return
  end

  Bus.offCore("ADDON_LOADED", onAddonLoaded)

  EbonAPIDB = EbonAPIDB or {}
  DB.attach(EbonAPIDB)

  Locale.applyPersisted()

  Log.trace("boot", ADDON_NAME, "base attachee")
end

onPlayerLogin = function()
  Bus.offCore("PLAYER_LOGIN", onPlayerLogin)

  DB.bindCharacter()
  Session.begin()
  Ebonhold.Detect()

  Bridge.enable()
  State.enable()

  Channel.enable()
  Profile.enable()
  Version.enable()

  EbonAPI._ready = true
  EbonAPI:Emit("READY", EbonAPI.version)

  Log.trace("boot", ADDON_NAME, DB.CharacterKey() or "personnage inconnu")
end

local function onEnteringWorld()
  Ebonhold.Detect()

  if not DB.CharacterKey() then
    DB.bindCharacter()
  end
end

Bus.onCore("ADDON_LOADED", onAddonLoaded)
Bus.onCore("PLAYER_LOGIN", onPlayerLogin)
Bus.onCore("PLAYER_ENTERING_WORLD", onEnteringWorld)

local function say(...)
  Log.print(ADDON_NAME, ...)
end

local function cmdStatus()
  say(format(L.STATUS_VERSION, EbonAPI.version))

  local names = EbonAPI:AddonNames()

  if #names == 0 then
    say(L.STATUS_NO_ADDONS)
  else
    say(format(L.STATUS_ADDONS, Format.list(names)))
  end

  if Bridge.seen then
    say(format(L.STATUS_BRIDGE_UP, Bridge.received, GetTime() - Bridge.lastMessageAt))
  else
    say(L.STATUS_BRIDGE_IDLE)
  end

  say(format(L.STATUS_BRIDGE_COUNTS, Bridge.sent, Bridge.queueLength(), Bridge.streamCount()))

  if Channel.isJoined() then
    say(format(L.STATUS_CHANNEL_UP, Channel.NAME, Channel.index() or 0, Channel.joinedFor() or 0))
  elseif Channel.isWanted() then
    say(format(L.STATUS_CHANNEL_DOWN, Channel.NAME, Channel.requests()))
  else
    say(format(L.STATUS_CHANNEL_OFF, Channel.NAME))
  end

  local qs, qd = Queue.sent, Queue.dropped

  say(format(L.STATUS_QUEUE, Queue.serverLength(), Queue.peerLength(), qs.channel, qs.whisper))

  local queueDrops = qd.offline + qd.full + qd.failed
  local channelDrops = Channel.droppedTotal()

  if queueDrops > 0 or channelDrops > 0 then
    say(format(L.STATUS_QUEUE_DROPS, qd.offline, qd.full, qd.failed, channelDrops))
  end

  say(format(L.STATUS_PROFILE, Profile.sent.P, Profile.sent.D, Profile.sent.X,
    Profile.received, Profile.rejected))
  say(format(L.STATUS_VERSIONS, Version.summary()))

  local drops = Bridge.drops
  local total = Bridge.droppedTotal()

  if total > 0 or State.rejected > 0 or DB.repaired > 0 then
    say(format(L.STATUS_REJECTED, total, drops.header, drops.bounds, drops.sender, drops.expired))
    say(format(L.STATUS_BODIES, State.rejected, DB.repaired))
  end

  say(Ebonhold.IsPresent() and L.STATUS_EBONHOLD_YES or L.STATUS_EBONHOLD_NO)

  local present, missing = Ebonhold.Summary()

  if #present > 0 then
    say("  " .. Format.list(present))
  end

  if #missing > 0 then
    say("  " .. Log.COLOR.MUTED .. L.NONE .. ": " .. Format.list(missing) .. "|r")
  end

  local key = DB.CharacterKey()

  say(key and format(L.STATUS_CHARACTER, key) or L.STATUS_CHARACTER_NONE)
end

local function cmdTrace(rest)
  local limit = tonumber(match(rest, "(%d+)")) or 20
  local kind = match(rest, "(%a+)")

  say(Log.dump(limit, kind))
end

local function cmdDebug(rest)
  local target, value = match(rest, "^(%S*)%s*(%S*)$")

  if target == "" then
    say(format(L.DEBUG_STATE, Log.isDebug(ADDON_NAME) and "on" or "off"))
    return
  end

  if target == "on" or target == "off" then
    value = target
    target = "*"
  end

  local enabled = value == "on" or value == "true" or value == "1"

  Log.setDebug(target == "*" and nil or target, enabled)
  say(format(L.DEBUG_SET, target, enabled and "on" or "off"))
end

local function cmdLang(rest)
  local code = Lib.trim(rest)
  local available = EbonAPI:GetAvailableLanguages()
  local codes = {}

  for index = 1, #available do
    codes[index] = available[index].code
  end

  if code == "" then
    say(format(L.LANG_CURRENT, EbonAPI:GetLanguage(), Format.list(codes)))
    return
  end

  if EbonAPI:SetLanguage(code) then
    say(format(L.LANG_SET, code))
  else
    say(format(L.LANG_UNKNOWN, code))
  end
end

local function cmdDB()
  say(DB.dump())
end

local function cmdOpcodes()
  say(Opcodes.list())
end

local function cmdSenders()
  local senders = Bridge.observedSenders()

  if Lib.isEmpty(senders) then
    say(L.SENDERS_NONE)
    return
  end

  for _, name in pairs(Lib.sortedKeys(senders)) do
    say("  " .. name .. "  x" .. senders[name])
  end

  say(format(L.SENDERS_STRICT, tostring(Bridge.isStrictSender())))
end

local function cmdPerf(rest)
  Perf.command(rest)
end

local function cmdHelp()
  say(format(L.CMD_TITLE, EbonAPI.version))
  say("  " .. L.CMD_STATUS)
  say("  " .. L.CMD_TRACE)
  say("  " .. L.CMD_DEBUG)
  say("  " .. L.CMD_LANG)
  say("  " .. L.CMD_DB)
  say("  " .. L.CMD_OPCODES)
  say("  " .. L.CMD_SENDERS)
  say("  " .. L.CMD_PERF)
end

local COMMANDS = {
  status = cmdStatus,
  trace = cmdTrace,
  debug = cmdDebug,
  lang = cmdLang,
  db = cmdDB,
  opcodes = cmdOpcodes,
  senders = cmdSenders,
  perf = cmdPerf,
  help = cmdHelp,
  [""] = cmdHelp,
}

SLASH_EBONAPI1 = "/ebonapi"
SLASH_EBONAPI2 = "/eapi"

SlashCmdList["EBONAPI"] = function(input)
  local verb, rest = match(Lib.trim(input or ""), "^(%S*)%s*(.*)$")
  local handler = COMMANDS[lower(verb)]

  if not handler then
    say(format(L.CMD_UNKNOWN, verb))
    return
  end

  Lib.safeCall(handler, rest)
end
