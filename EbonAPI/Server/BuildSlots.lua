EbonAPI = EbonAPI or {}
EbonAPI.BuildSlots = {}

local BuildSlots = EbonAPI.BuildSlots
local Lib = EbonAPI.Lib
local Ebonhold = EbonAPI.Ebonhold

local type, pairs = type, pairs

local function perkService()
  local service = Ebonhold.Service("PerkService")

  if type(service) ~= "table" then
    return nil
  end

  return service
end

function BuildSlots.GetServerSlots()
  local service = perkService()

  if not service or type(service.GetServerBuildSlots) ~= "function" then
    return nil
  end

  local raw = service.GetServerBuildSlots()

  if type(raw) ~= "table" then
    return nil
  end

  local copy = {}

  for slot, entry in pairs(raw) do
    if type(entry) == "table" then
      copy[slot] = {
        slot = entry.slot,
        name = entry.name,
        echoes = Lib.copyDeep(entry.echoes),
        verified = entry.verified,
        missing = Lib.copyDeep(entry.missing),
      }
    end
  end

  return copy
end

function BuildSlots.Export(loadout)
  if not loadout then
    return ""
  end

  local service = perkService()

  if not service or type(service.ExportEchoLoadout) ~= "function" then
    return nil
  end

  return service.ExportEchoLoadout(loadout)
end

EbonAPI:On("SERVER_BUILDS", function()
  EbonAPI:Emit("BUILD_SLOTS_CHANGED")
end)
