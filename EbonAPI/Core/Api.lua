EbonAPI = EbonAPI or {}

local Lib = EbonAPI.Lib

local type, pairs, tostring = type, pairs, tostring
local setmetatable, pcall, error = setmetatable, pcall, error
local report = Lib.report

EbonAPI.name = "EbonAPI"
EbonAPI.MAJOR = 1
EbonAPI.MINOR = 0
EbonAPI.PATCH = 0
EbonAPI.version = "1.0.0"

local NAME_MAX = 32

EbonAPI.NAME_MAX = NAME_MAX

local runFns, runIndex, runCount

local function runner(...)
  while runIndex <= runCount do
    local index = runIndex
    runIndex = index + 1

    runFns[index](...)
  end
end

function EbonAPI.fanout(fns, count, ...)
  if count == 0 then
    return 0
  end

  local savedFns, savedIndex, savedCount = runFns, runIndex, runCount

  runFns, runIndex, runCount = fns, 1, count

  while runIndex <= runCount do
    local ok, err = pcall(runner, ...)

    if ok then
      break
    end

    report(err)
  end

  runFns, runIndex, runCount = savedFns, savedIndex, savedCount

  return count
end

local fanout = EbonAPI.fanout

local events = {}
local sticky = {}
local stickyValues = {}

function EbonAPI:DeclareSticky(event)
  sticky[event] = true
end

local function listFor(event)
  local list = events[event]

  if not list then
    list = { n = 0, fns = {}, owners = {}, busy = 0 }
    events[event] = list
  end

  return list
end

local function mutable(list)
  if list.busy > 0 then
    local fns, owners = {}, {}
    local oldFns, oldOwners = list.fns, list.owners

    for index = 1, list.n do
      fns[index] = oldFns[index]
      owners[index] = oldOwners[index]
    end

    list.fns, list.owners = fns, owners
  end

  return list
end

local function subscribe(owner, event, fn)
  if type(event) ~= "string" then
    error("EbonAPI: the event name must be a string, got " .. type(event), 3)
  end

  if type(fn) ~= "function" then
    error("EbonAPI: the callback for '" .. event .. "' must be a function, got " .. type(fn), 3)
  end

  local list = listFor(event)
  local fns, owners = list.fns, list.owners

  for index = 1, list.n do
    if fns[index] == fn and owners[index] == owner then
      return false
    end
  end

  mutable(list)

  local n = list.n + 1
  list.n = n
  list.fns[n] = fn
  list.owners[n] = owner

  if sticky[event] then
    local held = stickyValues[event]

    if held then
      local ok, err = pcall(fn, event, held[1], held[2], held[3], held[4], held[5], held[6])

      if not ok then
        report(err)
      end
    end
  end

  return true
end

local function unsubscribe(owner, event, fn)
  local list = events[event]

  if not list or list.n == 0 then
    return false
  end

  local removed = false

  for index = list.n, 1, -1 do
    if list.owners[index] == owner and (fn == nil or list.fns[index] == fn) then
      mutable(list)

      local fns, owners, n = list.fns, list.owners, list.n

      for slide = index, n - 1 do
        fns[slide] = fns[slide + 1]
        owners[slide] = owners[slide + 1]
      end

      fns[n] = nil
      owners[n] = nil
      list.n = n - 1
      removed = true
    end
  end

  return removed
end

local function unsubscribeAll(owner)
  for event in pairs(events) do
    unsubscribe(owner, event, nil)
  end
end

function EbonAPI:Emit(event, a, b, c, d, e, f)
  if sticky[event] then
    local held = stickyValues[event]

    if not held then
      held = {}
      stickyValues[event] = held
    end

    held[1], held[2], held[3], held[4], held[5], held[6] = a, b, c, d, e, f
  end

  local list = events[event]

  if not list then
    return 0
  end

  local count = list.n

  if count == 0 then
    return 0
  end

  list.busy = list.busy + 1

  local served = fanout(list.fns, count, event, a, b, c, d, e, f)

  list.busy = list.busy - 1

  return served
end

function EbonAPI:On(event, fn)
  return subscribe(self, event, fn)
end

function EbonAPI:Off(event, fn)
  return unsubscribe(self, event, fn)
end

function EbonAPI:LastValue(event)
  local held = stickyValues[event]

  if not held then
    return nil
  end

  return held[1], held[2], held[3], held[4], held[5], held[6]
end

function EbonAPI:ClearSticky(event)
  if event == nil then
    for key in pairs(stickyValues) do
      stickyValues[key] = nil
    end

    return
  end

  stickyValues[event] = nil
end

local features = {}

function EbonAPI:RegisterFeature(name, available)
  local value = available and true or false

  if features[name] == value then
    return
  end

  features[name] = value
  self:Emit("FEATURE_CHANGED", name, value)
end

function EbonAPI:HasFeature(name)
  return features[name] == true
end

function EbonAPI:Features()
  return Lib.copyShallow(features)
end

local Handle = {}
Handle.__index = Handle

EbonAPI.Handle = Handle
EbonAPI._addons = {}

EbonAPI._teardowns = {}

function EbonAPI:AddTeardown(fn)
  self._teardowns[#self._teardowns + 1] = fn
end

function Handle:On(event, fn)
  return subscribe(self, event, fn)
end

function Handle:Off(event, fn)
  return unsubscribe(self, event, fn)
end

function Handle:OffAll()
  unsubscribeAll(self)

  local teardowns = EbonAPI._teardowns

  for index = 1, #teardowns do
    teardowns[index](self)
  end
end

function Handle:Emit(event, a, b, c, d, e, f)
  return EbonAPI:Emit(event, a, b, c, d, e, f)
end

function Handle:LastValue(event)
  return EbonAPI:LastValue(event)
end

function Handle:HasFeature(name)
  return EbonAPI:HasFeature(name)
end

function Handle:IsReady()
  return EbonAPI._ready == true
end

function Handle:GetName()
  return self.addonName
end

local function versionRefusal(name, major, minor)
  if DEFAULT_CHAT_FRAME then
    local COLOR = EbonAPI.Log.COLOR

    DEFAULT_CHAT_FRAME:AddMessage(COLOR.ERROR .. "[EbonAPI]" .. COLOR.RESET .. " " .. string.format(EbonAPI.L.VERSION_TOO_OLD,
      EbonAPI.version, name, tostring(major) .. "." .. tostring(minor)))
  end
end

local CONNECTION = { icon = "string", url = "string", updates = "boolean", version = "string" }

local function connectionProblem(name, info)
  if type(info) ~= "table" then
    return "the fourth argument must be a table (icon, updates, url, version), got " .. type(info)
  end

  for key, value in pairs(info) do
    local kind = CONNECTION[key]

    if not kind then
      return 'unknown connection option "' .. tostring(key) .. '" (known: icon, updates, url, version)'
    end

    if type(value) ~= kind or value == "" then
      return 'connection option "' .. key .. '" expects a ' .. (kind == "string" and "non-empty text" or kind)
        .. ", got " .. type(value)
    end
  end

  if info.updates then
    local version = info.version or (GetAddOnMetadata and GetAddOnMetadata(name, "Version"))

    if not EbonAPI.Version.parse(version) then
      return "updates needs a version, from the version option or ## Version in the .toc, got " .. tostring(version)
    end
  end

  return nil
end

local function connect(handle, name, info)
  if info.url then
    handle.link = info.url
  end

  if info.icon then
    handle.icon = info.icon
  end

  if info.updates then
    EbonAPI.Version.register(name, info.version or GetAddOnMetadata(name, "Version"), handle.link)
  end
end

function EbonAPI:NewAddon(name, needMajor, needMinor, info)
  if type(name) ~= "string" or name == "" then
    error("EbonAPI:NewAddon expects a non-empty addon name, got " .. type(name), 2)
  end

  if string.find(name, "[^%w_]") or string.len(name) > NAME_MAX then
    error('EbonAPI:NewAddon: addon name "' .. name .. '" must be 1 to ' .. NAME_MAX
      .. ' letters, digits or "_"', 2)
  end

  if info ~= nil then
    local problem = connectionProblem(name, info)

    if problem then
      error('EbonAPI:NewAddon: "' .. name .. '": ' .. problem, 2)
    end
  end

  needMajor = needMajor or self.MAJOR
  needMinor = needMinor or 0

  if needMajor > self.MAJOR or (needMajor == self.MAJOR and needMinor > self.MINOR) then
    versionRefusal(name, needMajor, needMinor)
    return nil
  end

  local handle = self._addons[name]
  local fresh = handle == nil

  if fresh then
    handle = setmetatable({ addonName = name }, Handle)
    self._addons[name] = handle
  end

  if info ~= nil then
    connect(handle, name, info)
  end

  if fresh then
    if self._consumerHook then
      self._consumerHook(name)
    end

    self:Emit("ADDON_CONNECTED", name)
  end

  return handle
end

function EbonAPI:AddonLink(name)
  local handle = self._addons[name]

  return handle and handle.link
end

function Handle:Link()
  return self.link
end

function EbonAPI:AddonIcon(name)
  local handle = self._addons[name]

  return handle and Lib.icon(handle.icon)
end

function Handle:Icon()
  return Lib.icon(self.icon)
end

function EbonAPI:AddonNames()
  return Lib.sortedKeys(self._addons)
end

EbonAPI._ready = false

function EbonAPI:IsReady()
  return self._ready == true
end

function EbonAPI:GetVersion()
  return self.version, self.MAJOR, self.MINOR, self.PATCH
end

EbonAPI:DeclareSticky("READY")
EbonAPI:DeclareSticky("LANGUAGE_CHANGED")
