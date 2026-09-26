EbonAPI = EbonAPI or {}
EbonAPI.Perf = {}

local Perf = EbonAPI.Perf
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local DB = EbonAPI.DB
local Format = EbonAPI.Format
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local type, tostring, ipairs, pcall = type, tostring, ipairs, pcall
local format, match, lower, concat, sort, remove = string.format, string.match, string.lower, table.concat, table.sort, table.remove

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

function Perf.lines(owner)
  local lines = {}
  local window = now() - since
  local mem = memoryKB(owner)

  if mem then
    lines[#lines + 1] = format(L.PERF_MEMORY, mem, uiKB())

    if baseline[owner] then
      lines[#lines + 1] = format(L.PERF_SINCE_RESET, mem - baseline[owner], window)
    end
  else
    lines[#lines + 1] = L.PERF_MEMORY_UNAVAILABLE
  end

  local live = running(owner)

  if #live > 0 then
    lines[#lines + 1] = format(L.PERF_RUNNING, #live, concat(live, ", "))
  else
    lines[#lines + 1] = L.PERF_RUNNING_NONE
  end

  if profiling() then
    UpdateAddOnCPUUsage()

    local ms = GetAddOnCPUUsage(owner) or 0
    local total = 0

    for i = 1, GetNumAddOns() do
      total = total + (GetAddOnCPUUsage(i) or 0)
    end

    lines[#lines + 1] = format(L.PERF_CPU, ms, window, window > 0 and ms / window or 0,
      total > 0 and ms / total * 100 or 0)

    local rows = costs(owner)

    for i = 1, #rows do
      lines[#lines + 1] = format("  %-30s %9.1f ms %8d calls", rows[i].name, rows[i].ms, rows[i].calls)
    end
  else
    lines[#lines + 1] = L.PERF_CPU_OFF
  end

  return lines
end

function Perf.report(owner, label)
  local lines = Perf.lines(owner)

  Log.print(owner, "perf" .. (label and (' "' .. label .. '"') or ""))

  for i = 1, #lines do
    Log.print(owner, lines[i])
  end

  save(owner, label, lines)

  return lines
end

function Perf.reset(owner)
  if ResetCPUUsage then
    ResetCPUUsage()
  end

  since = now()
  baseline[owner] = memoryKB(owner)
  Log.print(owner, format(L.PERF_RESET, owner))
end

function Perf.gc(owner)
  local before = memoryKB(owner)

  pcall(collectgarbage, "collect")

  local after = memoryKB(owner)

  if before and after then
    Log.print(owner, format(L.PERF_GC, before, after, before - after))
  else
    Log.print(owner, L.PERF_MEMORY_UNAVAILABLE)
  end
end

function Perf.owners()
  local names = EbonAPI:AddonNames()

  names[#names + 1] = "EbonAPI"

  return names
end

local function resolveOwner(word)
  word = lower(word)

  for _, name in ipairs(Perf.owners()) do
    if lower(name) == word then
      return name
    end
  end

  return nil
end

function Perf.summary()
  local lines = {}

  for _, owner in ipairs(Perf.owners()) do
    local mem = memoryKB(owner)

    lines[#lines + 1] = format(L.PERF_SUMMARY, owner, mem and format("%.0f", mem) or "?", #running(owner))
  end

  return lines
end

function Perf.command(rest)
  local first, arg = match(Lib.trim(rest or ""), "^(%S*)%s*(.*)$")

  if first == "" then
    local lines = Perf.summary()

    for i = 1, #lines do
      Log.print("EbonAPI", lines[i])
    end

    return
  end

  local owner = resolveOwner(first)

  if not owner then
    Log.print("EbonAPI", format(L.PERF_UNKNOWN, first, Format.list(Perf.owners())))
    return
  end

  arg = Lib.trim(arg)

  if arg == "reset" then
    Perf.reset(owner)
  elseif arg == "gc" then
    Perf.gc(owner)
  else
    Perf.report(owner, arg ~= "" and arg or nil)
  end
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
