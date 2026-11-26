local _, ns = ...

local Delays = {}
ns.PrioritiesTabDelays = Delays

local OWNER = "EbonBuilds"
local MIN, MAX, STEP = 0.1, 3, 0.1
local DEFAULTS = { evalDelay = 2, toastDuration = 3 }

local tx = ns.PrioritiesState.Text

local function settings()
  local db = EbonAPIEbonBuildsDB
  if not db then return nil end
  db.globalSettings = db.globalSettings or {}
  return db.globalSettings
end

local function read(key)
  local store = settings()
  local value = store and store[key]
  if type(value) ~= "number" then return DEFAULTS[key] end
  return value
end

local function write(key, value)
  local store = settings()
  if not store or type(value) ~= "number" then return end
  if value < MIN or value > MAX then return end
  if store[key] == value then return end
  store[key] = value
end

local function rangeSpec(key, labelKey, width)
  return {
    width = width,
    text = function() return tx(labelKey) end,
    min = MIN,
    max = MAX,
    step = STEP,
    get = function() return read(key) end,
    onChange = function(_, value) write(key, value) end,
  }
end

function Delays.Build(parent, width, height)
  local column = EbonAPI.Kit.create(OWNER, "bar", parent, { layout = "VERTICAL", width = width, height = height })
  column:Add("range", rangeSpec("evalDelay", "prio.delay.action", width))
  column:Add("range", rangeSpec("toastDuration", "prio.delay.toast", width))

  local function refresh()
    column:Refresh()
  end

  Delays.Refresh = refresh
  return column, refresh
end
