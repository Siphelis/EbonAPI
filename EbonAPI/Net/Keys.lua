EbonAPI = EbonAPI or {}
EbonAPI.Keys = {}

local Keys = EbonAPI.Keys
local DB = EbonAPI.DB
local Hash = EbonAPI.Hash
local Handle = EbonAPI.Handle

local type, pairs, next, error, tonumber = type, pairs, next, error, tonumber
local byte, sub, len, find, match, format = string.byte, string.sub, string.len, string.find, string.match, string.format
local concat, sort = table.concat, table.sort
local floor = math.floor

local NAME_MAX = 32
local PACKETS = 16
local WHOLE_MAX = 9007199254740991
local WHOLE_TEXT = format("%.0f", WHOLE_MAX)

Keys.NAME_MAX = NAME_MAX
Keys.PACKETS = PACKETS
Keys.STATE_MAX = WHOLE_MAX

local NAME_ALLOWED = 'letters, digits and "_"'

local store = nil
local cachedBase = nil
local global = nil
local parts = {}
local packets = {}
local packetNumber = {}
local sumHi, sumLo = {}, {}
local addonList = nil
local EMPTY = {}

do
  local zero = Hash.encode64(0, 0)

  for packet = 1, PACKETS do
    EMPTY[packet] = zero
  end
end

local function base()
  if not store then
    store = DB.store("EbonAPI", { account = { keys = {} } })
  end

  local held = store.account.keys

  if type(held) ~= "table" then
    held = {}
    store.account.keys = held
  end

  if held ~= cachedBase then
    cachedBase = held
    parts = {}
    packets = {}
    sumHi, sumLo = {}, {}
    addonList = nil
    global = nil
  end

  return held
end

local function packetOf(name)
  local packet = packetNumber[name]

  if not packet then
    local _, lo = Hash.fnv64(name)

    packet = lo % PACKETS
    packetNumber[name] = packet
  end

  return packet
end

Keys.packetOf = packetOf

-- Fingerprints are sums: a key weighs fnv64(name "=" state), a packet is the sum (modulo 2^64) of
-- its keys, an addon the sum of its packets. A sum does not depend on the order of its terms, so
-- put and remove update it by taking the old line out and putting the new one in (O(1)), and
-- nothing is sorted. The sums of an addon are built once (O(keys)) when first asked for.
local function sumsOf(addon, own)
  local hi, lo = sumHi[addon], sumLo[addon]

  if hi then
    return hi, lo
  end

  hi, lo = {}, {}

  for packet = 1, PACKETS do
    hi[packet], lo[packet] = 0, 0
  end

  for name, state in pairs(own) do
    local at = packetOf(name) + 1
    local kHi, kLo = Hash.fnv64(name .. "=" .. state)

    hi[at], lo[at] = Hash.add(hi[at], lo[at], kHi, kLo)
  end

  sumHi[addon], sumLo[addon] = hi, lo

  return hi, lo
end

-- One key went from old to new (either may be nil): update the sums that exist, drop what depends on them.
local function touch(addon, name, old, new)
  local hi, lo = sumHi[addon], sumLo[addon]
  local at = packetOf(name) + 1

  if hi then
    if old then
      local kHi, kLo = Hash.fnv64(name .. "=" .. old)

      hi[at], lo[at] = Hash.sub(hi[at], lo[at], kHi, kLo)
    end

    if new then
      local kHi, kLo = Hash.fnv64(name .. "=" .. new)

      hi[at], lo[at] = Hash.add(hi[at], lo[at], kHi, kLo)
    end
  end

  local cached = packets[addon]

  if cached then
    cached[at] = false
  end

  parts[addon] = nil
  global = nil
end

local function offender(text, pattern)
  local at = find(text, pattern)
  local char = match(text, "^[\192-\255][\128-\191]*", at) or sub(text, at, at)

  if char == " " then
    return "a space"
  end

  local code = byte(char)

  if code < 32 or code == 127 then
    return format("a control character (byte %d)", code)
  end

  return format('the character "%s"', char)
end

local function nameProblem(name)
  if type(name) ~= "string" then
    return "share key name must be a string, got " .. type(name)
  end

  if name == "" then
    return "share key name is empty"
  end

  if find(name, "[^%w_]") then
    return format('share key "%s" contains %s (allowed: %s)', name, offender(name, "[^%w_]"), NAME_ALLOWED)
  end

  if len(name) > NAME_MAX then
    return format('share key "%s" is %d characters long (maximum %d)', name, len(name), NAME_MAX)
  end

  return nil
end

local function readState(name, state)
  local value, shown

  if type(state) == "number" then
    value, shown = state, format("%.17g", state)
  elseif type(state) == "string" then
    value, shown = match(state, "^%d+$") and tonumber(state), '"' .. state .. '"'
  else
    return nil, format('share key "%s": state must be a whole number, got %s', name, type(state))
  end

  if not value or value ~= floor(value) or value < 0 or value > WHOLE_MAX then
    return nil, format('share key "%s": state %s is not a whole number (0 to %s)', name, shown, WHOLE_TEXT)
  end

  return format("%.0f", value)
end

function Keys.read(name, state)
  local problem = nameProblem(name)

  if problem then
    return nil, problem
  end

  return readState(name, state)
end

function Keys.check(addon, name, state, level)
  local normalized, problem = Keys.read(name, state)

  if problem then
    error("EbonAPI: " .. addon .. ": " .. problem, level or 2)
  end

  return normalized
end

function Keys.put(addon, name, state)
  local held = base()
  local own = held[addon]

  if not own then
    own = {}
    held[addon] = own
    addonList = nil
  end

  local old = own[name]

  if old == state then
    return false
  end

  own[name] = state
  touch(addon, name, old, state)

  EbonAPI:Emit("SHARE_KEY_CHANGED", addon, name, state)

  return true
end

function Keys.set(addon, name, state)
  return Keys.put(addon, name, Keys.check(addon, name, state, 3))
end

function Keys.remove(addon, name)
  local held = base()
  local own = held[addon]
  local old = own and own[name]

  if old == nil then
    return false
  end

  own[name] = nil
  touch(addon, name, old, nil)

  if next(own) == nil then
    held[addon] = nil
    sumHi[addon], sumLo[addon], packets[addon], parts[addon] = nil, nil, nil, nil
    addonList = nil
  end

  EbonAPI:Emit("SHARE_KEY_CHANGED", addon, name, nil)

  return true
end

function Keys.get(addon, name)
  local own = base()[addon]

  return own and own[name]
end

local function sortedNames(map)
  local names = {}

  for name in pairs(map) do
    names[#names + 1] = name
  end

  sort(names, Hash.before)

  return names
end

function Keys.names(addon)
  local own = base()[addon]

  if not own then
    return {}
  end

  return sortedNames(own)
end

function Keys.part(addon)
  local own = base()[addon]

  if not own then
    return nil
  end

  local cached = parts[addon]

  if cached then
    return cached
  end

  local hi, lo = sumsOf(addon, own)
  local sHi, sLo = 0, 0

  for packet = 1, PACKETS do
    sHi, sLo = Hash.add(sHi, sLo, hi[packet], lo[packet])
  end

  cached = Hash.encode64(sHi, sLo)
  parts[addon] = cached

  return cached
end

-- The 16 packet fingerprints, 11 characters each. Read only: the table is kept.
function Keys.packets(addon)
  local own = base()[addon]

  if not own then
    return EMPTY
  end

  local hi, lo = sumsOf(addon, own)
  local cached = packets[addon]

  if not cached then
    cached = {}
    packets[addon] = cached
  end

  for packet = 1, PACKETS do
    if not cached[packet] then
      cached[packet] = Hash.encode64(hi[packet], lo[packet])
    end
  end

  return cached
end

function Keys.count(addon)
  local own = base()[addon]
  local count = 0

  if own then
    for _ in pairs(own) do
      count = count + 1
    end
  end

  return count
end

function Keys.namesIn(addon, wanted)
  local own = base()[addon]
  local names = {}

  if not own then
    return names
  end

  for name in pairs(own) do
    if wanted[packetOf(name)] then
      names[#names + 1] = name
    end
  end

  sort(names, Hash.before)

  return names
end

-- Read only: the sorted list lives until an addon appears or goes away.
function Keys.addons()
  local held = base()

  if not addonList then
    addonList = sortedNames(held)
  end

  return addonList
end

function Keys.fingerprint()
  local addons = Keys.addons()
  local out = {}

  for index = 1, #addons do
    out[index] = Keys.part(addons[index])
  end

  return concat(out), addons
end

function Keys.globalDigest()
  if not global then
    global = Hash.digest((Keys.fingerprint()))
  end

  return global
end

function Handle:SetShareKey(name, state)
  return Keys.set(self.addonName, name, state)
end

function Handle:RemoveShareKey(name)
  return Keys.remove(self.addonName, name)
end

function Handle:GetShareKey(name, addon)
  return Keys.get(addon or self.addonName, name)
end
