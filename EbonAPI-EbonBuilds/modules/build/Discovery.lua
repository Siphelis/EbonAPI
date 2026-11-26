local _, ns = ...

EbonBuilds.Discovery = {}
local Discovery = EbonBuilds.Discovery

local pairs, type = pairs, type

local snapshot

local function ReadCatalog()
  local api = ns.api
  if not api then return nil end
  local state = api:State()
  if type(state) ~= "table" or type(state.GetCatalog) ~= "function" then return nil end
  return state.GetCatalog()
end

local function ReadDatabase()
  local catalog = EbonAPI and EbonAPI.EchoCatalog
  if type(catalog) ~= "table" or type(catalog.Database) ~= "function" then return nil end
  local database = catalog.Database()
  if type(database) ~= "table" then return nil end
  return database
end

function Discovery.Refresh()
  local catalog = ReadCatalog()
  if type(catalog) ~= "table" then
    snapshot = false
    return false
  end
  snapshot = type(catalog.counts) == "table" and catalog.counts or {}
  return true
end

function Discovery.State(spellId)
  if snapshot == nil then Discovery.Refresh() end
  if snapshot == false then return "unknown" end
  local count = snapshot[spellId]
  if type(count) == "number" and count >= 1 then return "found" end
  return "notFound"
end

function Discovery.Counts()
  if snapshot == nil then Discovery.Refresh() end
  if snapshot == false then return nil, "UNKNOWN" end
  local database = ReadDatabase()
  if not database then return nil, "UNKNOWN" end
  local found, total = 0, 0
  for _, count in pairs(snapshot) do
    if type(count) == "number" and count >= 1 then found = found + 1 end
  end
  for _ in pairs(database) do total = total + 1 end
  return found, total
end
