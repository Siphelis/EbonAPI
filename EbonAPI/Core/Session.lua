EbonAPI = EbonAPI or {}
EbonAPI.Session = {}

local Session = EbonAPI.Session
local DB = EbonAPI.DB
local Bus = EbonAPI.Bus

local type, tonumber = type, tonumber

local GAP = 600

Session.GAP = GAP

local fresh = false
local decided = false

local function clock()
  return (type(time) == "function" and time()) or 0
end

local function scope()
  return DB.store("EbonAPI", { character = { session = 0 } }).char
end

function Session.begin()
  local char = scope()

  if not char then
    fresh, decided = false, false
    return false
  end

  local stamp = clock()

  fresh = stamp - (tonumber(char.session) or 0) >= GAP
  decided = true
  char.session = stamp

  return fresh
end

function Session.touch()
  local char = DB.isAttached() and scope()

  if char then
    char.session = clock()
  end
end

function Session.isNew()
  if not decided then
    return Session.begin()
  end

  return fresh
end

Bus.onCore("PLAYER_LOGOUT", Session.touch)
