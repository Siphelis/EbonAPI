EbonAPI = EbonAPI or {}
EbonAPI.Perf = {}

local Perf = EbonAPI.Perf
local Log = EbonAPI.Log
local DB = EbonAPI.DB
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local type, tostring, ipairs, pcall = type, tostring, ipairs, pcall
local format, concat, sort, remove = string.format, table.concat, table.sort, table.remove

local MAX_REPORTS = 20

local tracked = {}
local functions = {}
local baseline = {}
local since = (GetTime and GetTime()) or 0

local function now()
  return (GetTime and GetTime()) or 0
end

local function uiKB()
  local ok, kb = pcall(collectgarbage, "count")

  return ok and kb or 0
end

local function listFor(registry, owner)
  local list = registry[owner]

  if not list then
    list = {}
    registry[owner] = list
  end

  return list
end

function Perf.track(owner, name, frame)
  if type(frame) ~= "table" then
    return false
  end

  local list = listFor(tracked, owner)

  list[#list + 1] = { name = tostring(name), frame = frame }

  return true
end

function Perf.trackFunction(owner, name, fn)
  if type(fn) ~= "function" then
    return false
  end

  local list = listFor(functions, owner)

  list[#list + 1] = { name = tostring(name), fn = fn }

  return true
end

local function profiling()
  return GetCVar ~= nil and GetCVar("scriptProfile") == "1" and GetAddOnCPUUsage ~= nil
end

local function memoryKB(owner)
  if not UpdateAddOnMemoryUsage or not GetAddOnMemoryUsage then
    return nil
  end

  UpdateAddOnMemoryUsage()

  return GetAddOnMemoryUsage(owner)
end

local function running(owner)
  local names = {}
  local list = tracked[owner]

  if list then
    for i = 1, #list do
      local entry = list[i]
      local frame = entry.frame

      if frame.GetScript and frame:GetScript("OnUpdate") and frame.IsVisible and frame:IsVisible() then
        names[#names + 1] = entry.name
      end
    end
  end

  return names
end

local function costs(owner)
  local rows = {}
  local frames = tracked[owner]
  local fns = functions[owner]

  if GetFrameCPUUsage and frames then
    for i = 1, #frames do
      local entry = frames[i]
      local ms, calls = GetFrameCPUUsage(entry.frame, false)

      if ms and ms > 0 then
        rows[#rows + 1] = { name = entry.name, ms = ms, calls = calls or 0 }
      end
    end
  end

  if GetFunctionCPUUsage and fns then
    for i = 1, #fns do
      local entry = fns[i]
      local ms, calls = GetFunctionCPUUsage(entry.fn, true)

      if ms and ms > 0 then
        rows[#rows + 1] = { name = "on " .. entry.name, ms = ms, calls = calls or 0 }
      end
    end
  end

  sort(rows, function(a, b)
    return a.ms > b.ms
  end)

  return rows
end

local function save(owner, label, lines)
  if not DB.isAttached() then
    return
  end

  local store = DB.store("EbonAPI", { account = { perfReports = {} } })
  local reports = store.account.perfReports

  if type(reports[owner]) ~= "table" then
    reports[owner] = {}
  end

  local list = reports[owner]

  list[#list + 1] = { at = (date and date("%Y-%m-%d %H:%M:%S")) or "", label = label, lines = lines }

  while #list > MAX_REPORTS do
    remove(list, 1)
  end
end

function Perf.sample(owner)
  local sample = {
    owner = owner,
    window = now() - since,
    memory = memoryKB(owner),
    ui = uiKB(),
    running = running(owner),
  }

  if sample.memory and baseline[owner] then
    sample.delta = sample.memory - baseline[owner]
  end

  if profiling() then
    UpdateAddOnCPUUsage()

    local total = 0

    for i = 1, GetNumAddOns() do
      total = total + (GetAddOnCPUUsage(i) or 0)
    end

    sample.cpu = { ms = GetAddOnCPUUsage(owner) or 0, total = total, rows = costs(owner) }
  end

  return sample
end

function Perf.describe(sample)
  local lines = {}

  if sample.memory then
    lines[#lines + 1] = format(L.PERF_MEMORY, sample.memory, sample.ui)

    if sample.delta then
      lines[#lines + 1] = format(L.PERF_SINCE_RESET, sample.delta, sample.window)
    end
  else
    lines[#lines + 1] = L.PERF_MEMORY_UNAVAILABLE
  end

  if #sample.running > 0 then
    lines[#lines + 1] = format(L.PERF_RUNNING, #sample.running, concat(sample.running, ", "))
  else
    lines[#lines + 1] = L.PERF_RUNNING_NONE
  end

  local cpu = sample.cpu

  if cpu then
    lines[#lines + 1] = format(L.PERF_CPU, cpu.ms, sample.window, sample.window > 0 and cpu.ms / sample.window or 0,
      cpu.total > 0 and cpu.ms / cpu.total * 100 or 0)

    for i = 1, #cpu.rows do
      local row = cpu.rows[i]

      lines[#lines + 1] = format(L.PERF_COST, row.name, row.ms, row.calls)
    end
  else
    lines[#lines + 1] = L.PERF_CPU_OFF
  end

  return lines
end

function Perf.lines(owner)
  return Perf.describe(Perf.sample(owner))
end

function Perf.measure(owner, label)
  local sample = Perf.sample(owner)
  local lines = Perf.describe(sample)

  save(owner, label, lines)

  return lines, sample
end

function Perf.report(owner, label)
  local lines = Perf.measure(owner, label)

  Log.print(owner, label and format(L.PERF_TITLE_LABEL, label) or L.PERF_TITLE)

  for i = 1, #lines do
    Log.print(owner, lines[i])
  end

  return lines
end

function Perf.reset(owner)
  if ResetCPUUsage then
    ResetCPUUsage()
  end

  since = now()
  baseline[owner] = memoryKB(owner)

  return true
end

function Perf.gc(owner)
  local before = memoryKB(owner)

  pcall(collectgarbage, "collect")

  return before, memoryKB(owner)
end

function Perf.describeGc(before, after)
  if before and after then
    return format(L.PERF_GC, before, after, before - after)
  end

  return L.PERF_MEMORY_UNAVAILABLE
end

function Perf.owners()
  local names = EbonAPI:AddonNames()

  names[#names + 1] = "EbonAPI"

  return names
end

function Perf.summarySample()
  local rows = {}

  for _, owner in ipairs(Perf.owners()) do
    rows[#rows + 1] = { owner = owner, memory = memoryKB(owner), running = #running(owner) }
  end

  return rows
end

function Perf.describeSummary(rows)
  local lines = {}

  for _, row in ipairs(rows) do
    lines[#lines + 1] = format(L.PERF_SUMMARY, row.owner,
      row.memory and format("%.0f", row.memory) or L.UNKNOWN, row.running)
  end

  return lines
end

function Perf.summary()
  return Perf.describeSummary(Perf.summarySample())
end

function Handle:Track(name, frame)
  return Perf.track(self.addonName, name, frame)
end

function Handle:TrackFunction(name, fn)
  return Perf.trackFunction(self.addonName, name, fn)
end

function Handle:Perf(label)
  return Perf.report(self.addonName, label)
end
