EbonAPI = EbonAPI or {}
EbonAPI.Ebonhold = {}

local Ebonhold = EbonAPI.Ebonhold
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Handle = EbonAPI.Handle

local type, tostring, pairs = type, tostring, pairs

local function root()
  local pe = _G.ProjectEbonhold

  if type(pe) == "table" then
    return pe
  end

  return nil
end

local function service(name)
  local pe = root()

  if not pe then
    return nil
  end

  local entry = pe[name]

  if type(entry) == "table" then
    return entry
  end

  return nil
end

function Ebonhold.IsPresent()
  return root() ~= nil
end

function Ebonhold.Raw()
  return root()
end

function Ebonhold.Objectives()
  return service("ObjectivesService")
end

function Ebonhold.ObjectivesUI()
  return service("ObjectivesUI")
end

function Ebonhold.Checkpoints()
  return service("CheckpointService")
end

function Ebonhold.Hardmode()
  return service("HardmodeService")
end

function Ebonhold.Perks()
  return service("PerkService")
end

function Ebonhold.PerkDatabase()
  return service("PerkDatabase")
end

function Ebonhold.PlayerRun()
  return service("PlayerRunService")
end

function Ebonhold.SkillTree()
  return service("SkillTree")
end

function Ebonhold.WorldMapBounds()
  return service("WorldMapBounds")
end

function Ebonhold.Orbs()
  return service("OrbService")
end

function Ebonhold.PerkUI()
  return service("PerkUI")
end

function Ebonhold.EchoJournal()
  return service("EchoJournal")
end

function Ebonhold.PerkDropSources()
  return service("PerkDropSources")
end

function Ebonhold.PerkDropSourceByGroup()
  return service("PerkDropSourceByGroup")
end

function Ebonhold.OptionsService()
  local svc = _G.ProjectEbonholdOptionsService

  if type(svc) == "table" then
    return svc
  end

  return nil
end

function Ebonhold.PerkFrame()
  return _G.ProjectEbonholdPerkFrame
end

function Ebonhold.SkillTreeImportButton()
  return _G.skillTreeImportButton
end

function Ebonhold.CanRequestLoadout()
  local pe = root()

  return pe ~= nil and type(pe.RequestLoadoutFromServer) == "function"
end

function Ebonhold.RequestLoadout()
  local pe = root()

  if not pe or type(pe.RequestLoadoutFromServer) ~= "function" then
    return false
  end

  return Lib.safeCall(pe.RequestLoadoutFromServer)
end

function Ebonhold.CurrentHardmodeTier()
  local pe = root()

  if not pe then
    return nil
  end

  return pe.currentHardmodeTier
end

function Ebonhold.SkillTreeFrame()
  return _G.skillTreeFrame
end

function Ebonhold.TalentDatabase()
  local db = _G.TalentDatabase

  if type(db) == "table" and type(db[0]) == "table" and type(db[0].nodes) == "table" then
    return db
  end

  return nil
end

function Ebonhold.Utils()
  local utils = _G.utils

  if type(utils) == "table" and utils.EncodeVarInt and utils.Base64Encode then
    return utils
  end

  return nil
end

function Ebonhold.PublishedRunData()
  local published = _G.EbonholdPlayerRunData

  if type(published) == "table" and next(published) ~= nil then
    return published
  end

  return nil
end

function Ebonhold.PublishedIntensity()
  local published = _G.EbonholdIntensityData

  if type(published) == "table" then
    return published
  end

  return nil
end

function Ebonhold.OpcodeCS(name)
  local pe = root()

  if not pe or type(pe.CS) ~= "table" then
    return nil
  end

  return pe.CS[name]
end

function Ebonhold.SendToServer(opcodeName, body)
  local pe = root()

  if not pe or type(pe.sendToServer) ~= "function" then
    return false, "no_send"
  end

  local opcode = Ebonhold.OpcodeCS(opcodeName)

  if opcode == nil then
    return false, "no_opcode"
  end

  local ok = Lib.safeCall(pe.sendToServer, opcode, body)

  if ok then
    Log.trace("send", "EbonAPI", "PE:" .. tostring(opcodeName))
  end

  return ok
end

local hooked = {}

function Ebonhold.Hook(path, key, wrapper)
  local target

  if path == nil then
    target = root()
    path = "ProjectEbonhold"
  elseif type(path) == "string" then
    target = service(path)
  else
    target = path
  end

  if type(target) ~= "table" or type(target[key]) ~= "function" then
    return false
  end

  local marker = tostring(path) .. "." .. tostring(key)

  if hooked[marker] then
    return false
  end

  local original = target[key]

  target[key] = function(...)
    return wrapper(original, ...)
  end

  hooked[marker] = true

  return true
end

function Ebonhold.IsHooked(path, key)
  if path == nil then
    path = "ProjectEbonhold"
  end

  return hooked[tostring(path) .. "." .. tostring(key)] == true
end

local PROBES = {
  ProjectEbonhold = Ebonhold.IsPresent,
  Objectives = Ebonhold.Objectives,
  Checkpoints = Ebonhold.Checkpoints,
  Hardmode = Ebonhold.Hardmode,
  Perks = Ebonhold.Perks,
  PerkDatabase = Ebonhold.PerkDatabase,
  PerkUI = Ebonhold.PerkUI,
  Orbs = Ebonhold.Orbs,
  EchoJournal = Ebonhold.EchoJournal,
  PlayerRun = Ebonhold.PlayerRun,
  SkillTree = Ebonhold.SkillTree,
  SkillTreeFrame = Ebonhold.SkillTreeFrame,
  TalentDatabase = Ebonhold.TalentDatabase,
  Utils = Ebonhold.Utils,
  RequestLoadout = Ebonhold.CanRequestLoadout,
}

function Ebonhold.Detect()
  for name, probe in pairs(PROBES) do
    EbonAPI:RegisterFeature(name, Lib.safeGet(probe) and true or false)
  end

  EbonAPI:RegisterFeature("sendToServer",
    root() ~= nil and type(root().sendToServer) == "function")

  return EbonAPI:Features()
end

function Ebonhold.Summary()
  local features = EbonAPI:Features()
  local present = {}
  local missing = {}

  for _, name in pairs(Lib.sortedKeys(features)) do
    if features[name] then
      present[#present + 1] = name
    else
      missing[#missing + 1] = name
    end
  end

  return present, missing
end

function Handle:Ebonhold()
  return Ebonhold
end
