EbonAPI = EbonAPI or {}
EbonAPI.Legacy = {}

local Legacy = EbonAPI.Legacy
local Channel = EbonAPI.Channel
local Version = EbonAPI.Version
local Share = EbonAPI.Share

local Whisper = EbonAPI.Whisper

local match, sub = string.match, string.sub

-- The 2.2 clients announce themselves with a beacon (op B) or a parts line (op F) whose fingerprints
-- are computed another way: they are never compared and never answered, and nothing is sent to
-- them (our lines travel under other ops, which they drop unseen). What they carry is counted
-- (Share.ignore, shown in the diagnostics). Only the versions they announce are still read.
-- Retire this module when no 2.2 client is left.
local NAME = "EbonAPI"
local OLD_BEACON, OLD_LINE, OLD_VERSIONS = "B", "F", "V"

local enabled = false

-- The old clients learn that an update exists from a versions line (op V) on the channel; they drop
-- our ops. So the first old peer heard after we joined the channel gets ONE versions line, broadcast
-- (never a whisper, never the parts or the fingerprint), then at most one every RELAY_EVERY seconds,
-- and only when an old peer not seen since the last line has appeared. The peers seen are capped.
-- The line starts with RELAY_MARK, a segment without "=" that the old reader skips (pattern
-- "([%w_]+)=([^,]+)") and that lets our own kind recognise the line and stay quiet.
local RELAY_EVERY = 600
local RELAY_PEERS_MAX = 64
local RELAY_MARK = "~,"

local RELAY_DELAY_MAX = 20
local RELAY_TIMER = "EbonAPI.Legacy.relay"

local seen = {}
local seenCount = 0
local fresh = false
local relayedAt = nil
local pending = false

local function forgetSeen()
  for name in pairs(seen) do
    seen[name] = nil
  end

  seenCount = 0
end

local function cancelPending()
  if pending then
    EbonAPI.Bus.untick(RELAY_TIMER)
    pending = false
  end
end

local function forgetPeers()
  cancelPending()
  forgetSeen()

  fresh = false
  relayedAt = nil
end

local function windowOpen()
  return not relayedAt or GetTime() - relayedAt >= RELAY_EVERY
end

-- Runs when the delay is over: the full test again, since a line from another new client may have
-- been heard meanwhile (it sets relayedAt and clears fresh).
local function send()
  pending = false

  if not enabled or not fresh or not windowOpen() then
    return false
  end

  local versions = Version.line()

  if not versions or not Channel.say(NAME, OLD_VERSIONS, RELAY_MARK .. versions) then
    return false
  end

  -- "not seen since the last line": the next line is owed only to peers heard after this one.
  forgetSeen()

  fresh = false
  relayedAt = GetTime()

  return true
end

-- Every new client hears the same old peer at the same moment; each would send the same line. A
-- random delay lets the first one send and the others hear it (onOldVersions) and stay quiet.
local function relay(sender)
  if not seen[sender] and seenCount < RELAY_PEERS_MAX then
    seen[sender] = true
    seenCount = seenCount + 1
    fresh = true
  end

  if not fresh or pending or not windowOpen() then
    return false
  end

  pending = true
  EbonAPI.Bus.after(RELAY_TIMER, math.random(RELAY_DELAY_MAX), send)

  return true
end

local function onJoined()
  forgetPeers()
end

local function onOldBeacon(sender, body)
  local versions = match(body, "^([^;]*);")

  if versions then
    Version.onBeacon(sender, versions)
  end

  Share.ignore(sender)
  relay(sender)
end

local function onOldStream(sender)
  Share.ignore(sender)
end

local function onOldLine(sender)
  Share.ignore(sender)
  relay(sender)
end

local function onOldVersions(sender, body)
  if sub(body, 1, #RELAY_MARK) == RELAY_MARK then
    -- Another new client has just told the old ones: owe nothing for the peers heard so far.
    -- (Our own line never comes back: Net/Channel.lua drops sender == myName.)
    relayedAt = GetTime()
    fresh = false

    return
  end

  Version.onBeacon(sender, body)
  Share.ignore(sender)
  relay(sender)
end

Legacy.onBeacon = onOldBeacon
Legacy.onLine = onOldLine
Legacy.onVersions = onOldVersions
Legacy.RELAY_EVERY = RELAY_EVERY
Legacy.RELAY_PEERS_MAX = RELAY_PEERS_MAX

function Legacy.enable()
  if enabled then
    return false
  end

  enabled = true

  forgetPeers()
  EbonAPI:On("CHANNEL_JOINED", onJoined)

  Channel.on(NAME, OLD_BEACON, onOldBeacon)
  Channel.on(NAME, OLD_LINE, onOldLine)
  Channel.on(NAME, OLD_VERSIONS, onOldVersions)
  Whisper.onStream(NAME, "F", onOldStream)
  Whisper.onStream(NAME, "f", onOldStream)
  Whisper.onStream(NAME, "B", onOldStream)

  return true
end

function Legacy.disable()
  if not enabled then
    return false
  end

  enabled = false

  EbonAPI:Off("CHANNEL_JOINED", onJoined)
  forgetPeers()

  Channel.off(NAME, OLD_BEACON, onOldBeacon)
  Channel.off(NAME, OLD_LINE, onOldLine)
  Channel.off(NAME, OLD_VERSIONS, onOldVersions)
  Whisper.offStream(NAME, "F", onOldStream)
  Whisper.offStream(NAME, "f", onOldStream)
  Whisper.offStream(NAME, "B", onOldStream)

  return true
end
