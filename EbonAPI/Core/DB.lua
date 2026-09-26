EbonAPI = EbonAPI or {}
EbonAPI.DB = {}

local DB = EbonAPI.DB
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Handle = EbonAPI.Handle

local type, pairs, error = type, pairs, error
local setmetatable, pcall = setmetatable, pcall

DB.SCHEMA_VERSION = 1
DB.repaired = 0

local root = nil
local characterKey = nil
local characterName = nil
local stores = {}

function DB.ResolveCharacter()
  if not UnitName then
    return nil
  end

  local name = UnitName("player")

  if not name or name == "" or name == UNKNOWNOBJECT then
    return nil
  end

  characterName = name
  characterKey = name .. "-" .. ((GetRealmName and GetRealmName()) or "")

  return characterKey
end

function DB.CharacterKey()
  return characterKey
end

function DB.CharacterName()
  return characterName
end

local function ensureTable(container, key)
  if type(container[key]) ~= "table" then
    if container[key] ~= nil then
      DB.repaired = DB.repaired + 1
      Log.trace("repair", "EbonAPI", key)
    end

    container[key] = {}
  end

  return container[key]
end

local function shape(db)
  local shared = ensureTable(db, "shared")

  ensureTable(shared, "account")
  ensureTable(shared, "characters")
  ensureTable(db, "addons")
  ensureTable(db, "migrations")

  if type(db.version) ~= "number" then
    db.version = DB.SCHEMA_VERSION
  end

  return db
end

function DB.attach(saved)
  root = shape(type(saved) == "table" and saved or {})

  for _, store in pairs(stores) do
    store:Rebind()
  end

  return root
end

function DB.root()
  if not root then
    DB.attach(_G.EbonAPIDB or {})
    _G.EbonAPIDB = root
  end

  return root
end

function DB.isAttached()
  return root ~= nil
end

function DB.bindCharacter()
  if not DB.ResolveCharacter() then
    return false
  end

  for _, store in pairs(stores) do
    store:Rebind()
  end

  return true
end

local Store = {}
Store.__index = Store

local function bucketFor(owner)
  local db = DB.root()

  if owner == nil then
    return db.shared
  end

  local bucket = ensureTable(db.addons, owner)

  ensureTable(bucket, "account")
  ensureTable(bucket, "characters")

  return bucket
end

function Store:Rebind()
  local bucket = bucketFor(self.owner)
  local defaults = self.defaults

  self.bucket = bucket
  self.account = Lib.applyDefaults(bucket.account, defaults.account)

  if characterKey then
    local entry = ensureTable(bucket.characters, characterKey)

    Lib.applyDefaults(entry, defaults.character)
    self.char = entry
  else
    self.char = nil
  end

  return self
end

function Store:CharacterKeys()
  return Lib.sortedKeys(self.bucket.characters)
end

function Store:CharacterAt(key)
  return self.bucket.characters[key]
end

function Store:ResetCharacter()
  if not characterKey then
    return false
  end

  self.bucket.characters[characterKey] = {}
  self:Rebind()

  return true
end

local function markerKey(owner, key, perCharacter)
  local base = (owner or "shared") .. "/" .. key

  if perCharacter then
    return base .. "@" .. (characterKey or "?")
  end

  return base
end

local function migrate(store, key, legacy, fn, perCharacter)
  if type(key) ~= "string" then
    error("EbonAPI: la clef de migration doit etre une chaine, recu " .. type(key), 3)
  end

  if type(fn) ~= "function" then
    error("EbonAPI: la migration '" .. key .. "' attend une fonction, recu " .. type(fn), 3)
  end

  if perCharacter and not characterKey then
    return false
  end

  local migrations = DB.root().migrations
  local marker = markerKey(store.owner, key, perCharacter)

  if migrations[marker] then
    return false
  end

  local ok, result = pcall(fn, store, legacy, characterName, characterKey)

  if not ok then
    Log.error(store.owner, "migration '" .. key .. "' interrompue: " .. tostring(result))
    return false
  end

  if result == nil then
    return false
  end

  migrations[marker] = true

  return true, result
end

function Store:MigrateOnce(key, legacy, fn)
  return migrate(self, key, legacy, fn, false)
end

function Store:MigrateOncePerCharacter(key, legacy, fn)
  return migrate(self, key, legacy, fn, true)
end

function Store:IsMigrated(key, perCharacter)
  return DB.root().migrations[markerKey(self.owner, key, perCharacter)] == true
end

function DB.store(owner, defaults)
  if defaults ~= nil and type(defaults) ~= "table" then
    error("EbonAPI: les defauts de '" .. (owner or "shared") .. "' doivent etre une table, recu "
      .. type(defaults), 3)
  end

  local key = owner or "*shared*"
  local existing = stores[key]

  if existing then
    if defaults then
      Lib.applyDefaults(existing.defaults.account, defaults.account or {})
      Lib.applyDefaults(existing.defaults.character, defaults.character or {})
      existing:Rebind()
    end

    return existing
  end

  defaults = defaults or {}

  local store = setmetatable({
    owner = owner,
    defaults = {
      account = defaults.account or {},
      character = defaults.character or {},
    },
  }, Store)

  stores[key] = store
  store:Rebind()

  return store
end

function DB.shared()
  return DB.store(nil, nil)
end

function DB.dump()
  local db = DB.root()
  local lines = {
    "EbonAPIDB schema=" .. db.version .. "  personnage=" .. (characterKey or "non resolu"),
  }

  for _, name in pairs(Lib.sortedKeys(db.addons)) do
    local bucket = db.addons[name]

    lines[#lines + 1] = "  " .. name
      .. "  compte=" .. Lib.count(bucket.account) .. " cles"
      .. "  personnages=" .. Lib.count(bucket.characters)
  end

  local markers = Lib.count(db.migrations)

  if markers > 0 then
    lines[#lines + 1] = "  migrations posees: " .. markers
  end

  if DB.repaired > 0 then
    lines[#lines + 1] = "  entrees reparees au chargement: " .. DB.repaired
  end

  return table.concat(lines, "\n")
end

function Handle:DB(defaults)
  local store = self._store

  if not store then
    store = DB.store(self.addonName, defaults)
    self._store = store
  elseif defaults then
    DB.store(self.addonName, defaults)
  end

  return store
end
