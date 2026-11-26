EbonAPI = EbonAPI or {}
EbonAPI.Parameters = {}

local Parameters = EbonAPI.Parameters
local Catalog = EbonAPI.Catalog
local Skins = EbonAPI.Skins
local DB = EbonAPI.DB
local Handle = EbonAPI.Handle

local pairs, ipairs, tostring, error, type = pairs, ipairs, tostring, error, type
local format, concat = string.format, table.concat

local Problems = EbonAPI.Problems

Problems.declare("EbonAPI", "EBONAPI", {
  ["PARAMETER.DROPPED"] = { class = "reparation", key = "parameter" },
})

local LIST = Catalog.PLAYER

local BY_NAME = {}
local NAMES = {}

for index, entry in ipairs(LIST) do
  BY_NAME[entry.key] = entry
  NAMES[index] = entry.key
end

Parameters.NAMES = NAMES

local own = {}
local store = nil
local checked = nil

local function problem(name, value)
  local entry = BY_NAME[name]

  if not entry then
    return format('unknown parameter "%s" (known: %s)', tostring(name), concat(NAMES, ", "))
  end

  if value == nil then
    return nil, entry
  end

  return Catalog.problem(entry, value), entry
end

Parameters.problem = problem

local function held()
  if not DB.isAttached() then
    return nil
  end

  if not store then
    store = DB.store("EbonAPI", { account = { parameters = {}, statusLine = { showSpeed = false, showFps = false } } })
  end

  local values = store.account.parameters

  if type(values) ~= "table" then
    values = {}
    store.account.parameters = values
  end

  if values ~= checked then
    checked = values

    for name, value in pairs(values) do
      local reason = problem(name, value)

      if reason then
        values[name] = nil
        Problems.repaired("EbonAPI", "PARAMETER.DROPPED", { parameter = name, value = value, reason = reason }, value)
      end
    end
  end

  return values
end

function Parameters.entry(name)
  return BY_NAME[name]
end

function Parameters.default(name)
  return BY_NAME[name] and Skins.value(name)
end

function Parameters.player(name)
  local values = held()

  return values and values[name]
end

function Parameters.value(addon, name)
  local chosen = Parameters.player(name)

  if chosen ~= nil then
    return chosen
  end

  if addon then
    local mine = own[addon]

    if mine and mine[name] ~= nil then
      return mine[name]
    end
  end

  return Parameters.default(name)
end

function Parameters.all(addon)
  local out = {}

  for _, name in ipairs(NAMES) do
    out[name] = Parameters.value(addon, name)
  end

  return out
end

function Parameters.setPlayer(name, value)
  local reason = problem(name, value)

  if reason then
    error("EbonAPI: " .. reason, 2)
  end

  local values = held()

  if not values then
    return false
  end

  if values[name] == value then
    return false
  end

  values[name] = value
  EbonAPI:Emit("PARAMETER_CHANGED", name, Parameters.value(nil, name))

  return true
end

function Parameters.resetPlayer()
  local values = held()
  local changed = 0

  if not values then
    return changed
  end

  for _, name in ipairs(NAMES) do
    if values[name] ~= nil then
      values[name] = nil
      changed = changed + 1
      EbonAPI:Emit("PARAMETER_CHANGED", name, Parameters.default(name))
    end
  end

  return changed
end

local STATUS_NAMES = { showSpeed = true, showFps = true }

local function statusLine()
  if not held() then
    return nil
  end

  local line = store.account.statusLine

  return type(line) == "table" and line or nil
end

function Parameters.statusShown(name)
  local line = statusLine()

  return line ~= nil and line[name] == true
end

function Parameters.setStatusShown(name, value)
  if not STATUS_NAMES[name] then
    error(format('EbonAPI: unknown status display "%s"', tostring(name)), 2)
  end

  local line = statusLine()
  local shown = value and true or false

  if not line or line[name] == shown then
    return false
  end

  line[name] = shown
  EbonAPI:Emit("PARAMETER_CHANGED", name, shown)

  return true
end

function Parameters.backgroundAnimations()
  if not held() then
    return true
  end

  return store.account.backgroundAnimations ~= false
end

function Parameters.setBackgroundAnimations(value)
  if not held() then
    return false
  end

  local shown = value and true or false

  if Parameters.backgroundAnimations() == shown then
    return false
  end

  store.account.backgroundAnimations = shown
  EbonAPI:Emit("PARAMETER_CHANGED", "backgroundAnimations", shown)

  return true
end

function EbonAPI:GetBackgroundAnimations()
  return Parameters.backgroundAnimations()
end

function Handle:GetBackgroundAnimations()
  return Parameters.backgroundAnimations()
end

function Parameters.huntAnimation()
  if not held() then
    return true
  end

  return store.account.huntAnimation ~= false
end

function Parameters.setHuntAnimation(value)
  if not held() then
    return false
  end

  local shown = value and true or false

  if Parameters.huntAnimation() == shown then
    return false
  end

  store.account.huntAnimation = shown
  EbonAPI:Emit("PARAMETER_CHANGED", "huntAnimation", shown)

  return true
end

function EbonAPI:GetHuntAnimation()
  return Parameters.huntAnimation()
end

function Handle:GetHuntAnimation()
  return Parameters.huntAnimation()
end

function Parameters.prestigeAnimation()
  if not held() then
    return true
  end

  return store.account.prestigeAnimation ~= false
end

function Parameters.setPrestigeAnimation(value)
  if not held() then
    return false
  end

  local shown = value and true or false

  if Parameters.prestigeAnimation() == shown then
    return false
  end

  store.account.prestigeAnimation = shown
  EbonAPI:Emit("PARAMETER_CHANGED", "prestigeAnimation", shown)

  return true
end

function EbonAPI:GetPrestigeAnimation()
  return Parameters.prestigeAnimation()
end

function Handle:GetPrestigeAnimation()
  return Parameters.prestigeAnimation()
end

function Parameters.setOwn(addon, name, value)
  local mine = own[addon]

  if not mine then
    mine = {}
    own[addon] = mine
  end

  mine[name] = value
end

function EbonAPI:GetParameter(name)
  if not BY_NAME[name] then
    error("EbonAPI: " .. problem(name), 2)
  end

  return Parameters.value(nil, name)
end

function Handle:GetParameter(name)
  if not BY_NAME[name] then
    error("EbonAPI: " .. self.addonName .. ": " .. problem(name), 2)
  end

  return Parameters.value(self.addonName, name)
end

function Handle:GetParameters()
  return Parameters.all(self.addonName)
end

function Handle:SetParameter(name, value)
  local reason = problem(name, value)

  if reason then
    error("EbonAPI: " .. self.addonName .. ": " .. reason, 2)
  end

  Parameters.setOwn(self.addonName, name, value)

  return Parameters.value(self.addonName, name)
end
