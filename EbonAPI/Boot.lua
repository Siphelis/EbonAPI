EbonAPI = EbonAPI or {}

local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Locale = EbonAPI.Locale
local Bridge = EbonAPI.Bridge
local Channel = EbonAPI.Channel
local Profile = EbonAPI.Profile
local Session = EbonAPI.Session
local Version = EbonAPI.Version
local Share = EbonAPI.Share
local Ebonhold = EbonAPI.Ebonhold
local State = EbonAPI.State
local Skins = EbonAPI.Skins
local Bricks = EbonAPI.Bricks
local Window = EbonAPI.Window

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
  Skins.resolve()
  Bricks.apply()

  Log.trace("boot", ADDON_NAME, "database attached")
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
  Share.enable()
  Window.install()

  EbonAPI._ready = true
  EbonAPI:Emit("READY", EbonAPI.version)

  Log.trace("boot", ADDON_NAME, DB.CharacterKey() or "character unknown")
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
