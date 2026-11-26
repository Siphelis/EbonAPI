local _, ns = ...

ns.PrioritiesState = ns.PrioritiesState or {}

local State = ns.PrioritiesState

local type, tostring, pcall = type, tostring, pcall

local TABS = { weights = true, automation = true, wishes = true, delays = true }
local FILTERS = { all = true, modified = true, wanted = true, banned = true }
local SORTS = { name = true, weight = true }

local data = {
  buildId = nil,
  echoId = nil,
  tab = "weights",
  filter = "all",
  sort = "name",
  search = "",
}

local listeners = {}

local function emit(key)
  local snapshot = {}
  for i = 1, #listeners do snapshot[i] = listeners[i] end
  for i = 1, #snapshot do
    local fn = snapshot[i]
    local alive = false
    for j = 1, #listeners do
      if listeners[j] == fn then alive = true break end
    end
    if alive then pcall(fn, key) end
  end
end

local function buildExists(id)
  local Build = ns.Build
  if not Build or type(Build.Get) ~= "function" then return false end
  return Build.Get(id) ~= nil
end

function State.Text(key)
  local text = ns.L and ns.L[key]
  if type(text) == "string" then return text end
  return key
end

function State.State()
  return data
end

function State.Build()
  if data.buildId == nil then return nil end
  return ns.Build.Get(data.buildId)
end

function State.SelectBuild(id)
  local new
  if id ~= nil and id ~= data.buildId and buildExists(id) then new = id end
  if data.buildId == new then return end
  data.buildId = new
  emit("build")
end

function State.SelectEcho(spellId)
  local new = nil
  if spellId ~= nil and spellId ~= data.echoId then new = spellId end
  if data.echoId == new then return end
  data.echoId = new
  emit("echo")
end

function State.SetTab(name)
  if not TABS[name] or data.tab == name then return end
  data.tab = name
  emit("tab")
end

function State.SetFilter(name)
  if not FILTERS[name] or data.filter == name then return end
  data.filter = name
  emit("filter")
end

function State.SetSort(name)
  if not SORTS[name] or data.sort == name then return end
  data.sort = name
  emit("sort")
end

function State.SetSearch(text)
  text = text == nil and "" or tostring(text)
  if data.search == text then return end
  data.search = text
  emit("search")
end

function State.Changed()
  emit("data")
end

function State.Subscribe(fn)
  if type(fn) ~= "function" then return function() end end
  listeners[#listeners + 1] = fn
  return function()
    for i = 1, #listeners do
      if listeners[i] == fn then
        table.remove(listeners, i)
        return
      end
    end
  end
end
