EbonAPI = EbonAPI or {}
EbonAPI.Perf = {}

local Perf = EbonAPI.Perf
local Log = EbonAPI.Log
local DB = EbonAPI.DB
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local type, tostring, ipairs, pcall = type, tostring, ipairs, pcall
local sort = table.sort


local function now()
  return (GetTime and GetTime()) or 0
end

local tracked = {}
local functions = {}
local started = now()
local cpuSince = started

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

local function register(registry, owner, name, field, target)
  local list = listFor(registry, owner)

  name = tostring(name)

  for i = 1, #list do
    if list[i][field] == target then
      list[i].name = name

      return true
    end
  end

  list[#list + 1] = { name = name, [field] = target }

  return true
end

function Perf.track(owner, name, frame)
  if type(frame) ~= "table" then
    return false
  end

  return register(tracked, owner, name, "frame", frame)
end

function Perf.trackFunction(owner, name, fn)
  if type(fn) ~= "function" then
    return false
  end

  return register(functions, owner, name, "fn", fn)
end

local function profiling()
  return GetCVar ~= nil and GetCVar("scriptProfile") == "1" and GetAddOnCPUUsage ~= nil
end

-- Session meter: while the session instrument runs (metered = true), each refresh of the profiler or memory counters made
-- from this file is timed with debugprofilestop (one test of a local variable otherwise). The time is summed, never kept
-- per call.
local clock = nil
local metered = false
local refreshCpuMs, refreshCpuCalls, refreshMemMs, refreshMemCalls, refreshAll = 0, 0, 0, 0, 0

local function refreshCpu()
  if not metered then
    return UpdateAddOnCPUUsage()
  end

  local t0 = clock()

  UpdateAddOnCPUUsage()

  local spent = clock() - t0

  refreshCpuMs, refreshCpuCalls, refreshAll = refreshCpuMs + spent, refreshCpuCalls + 1, refreshAll + spent

  return spent
end

-- Last real UpdateAddOnMemoryUsage call (seconds, now()); nil until the first one.
local lastMemoryRefreshAt = nil

-- throttled: skip the costly global sweep unless LIMITS.memoryEvery seconds elapsed since the last real one
-- (the first call always refreshes). Callers that need exact figures pass nothing (always fresh).
local function refreshMemory(throttled)
  if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
    local at = now()

    if throttled and lastMemoryRefreshAt and at - lastMemoryRefreshAt < Perf.LIMITS.memoryEvery then
      return
    end

    lastMemoryRefreshAt = at

    if not metered then
      return UpdateAddOnMemoryUsage()
    end

    local t0 = clock()

    UpdateAddOnMemoryUsage()

    local spent = clock() - t0

    refreshMemMs, refreshMemCalls, refreshAll = refreshMemMs + spent, refreshMemCalls + 1, refreshAll + spent
  end
end

-- The client wants the FOLDER of an addon, not the name it gave to NewAddon: a module's folder differs from its
-- logical name. Resolved at call time from the module list; any other owner is already a folder.
function Perf.addonFolder(owner)
  local loader = EbonAPI.ModuleLoader

  if loader and loader.list then
    for _, module in ipairs(loader.list()) do
      if module.key == owner then
        return module.name
      end
    end
  end

  return owner
end

function Perf.owners()
  local names = EbonAPI:AddonNames()

  names[#names + 1] = "EbonAPI"

  if not IsAddOnLoaded or not GetNumAddOns or not GetAddOnInfo then
    return names
  end

  -- Every other loaded addon of the client, by folder; a module is already there under its logical name.
  local known = {}
  local others = {}

  for _, name in ipairs(names) do
    known[name] = true
  end

  for _, module in ipairs(EbonAPI.ModuleLoader and EbonAPI.ModuleLoader.list and EbonAPI.ModuleLoader.list() or {}) do
    known[module.name] = true
  end

  for index = 1, GetNumAddOns() do
    local folder = GetAddOnInfo(index)

    if folder and not known[folder] and IsAddOnLoaded(index) then
      known[folder] = true
      others[#others + 1] = folder
    end
  end

  sort(others)

  for _, folder in ipairs(others) do
    names[#names + 1] = folder
  end

  return names
end

function Handle:Track(name, frame)
  return Perf.track(self.addonName, name, frame)
end

function Handle:TrackFunction(name, fn)
  return Perf.trackFunction(self.addonName, name, fn)
end

local PerfData = EbonAPI.PerfData
local gsub = string.gsub

local OWN_FOLDER = "EbonAPI"
local TOTAL_KEY = "@total"

local watchers = {}
local commonOwner = {}
local lastMs = nil
local lastAt = nil
local peaks = {}
local memRef = {}
local memRefAt = nil
-- Last real memory reading per folder and its time: growth is the delta between two real refreshes, not a fixed origin.
local prevMem = {}
local prevMemAt = nil
local lastGrowth = {}
local scratchCpu = {}
local scratchDeps = {}
local scratchAttach = {}
local depsPool = {}
-- Rows of the live snapshot, reused tick after tick (PerfData.group copies them; nothing keeps a reference).
local rowPool = {}
local depsKnown = {}

local function clear(t)
  for k in pairs(t) do
    t[k] = nil
  end
end

local function plain(text)
  text = gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")

  return (gsub(text, "|r", ""))
end

local function fillAttach()
  clear(scratchAttach)

  local loader = EbonAPI.ModuleLoader

  if loader and loader.list then
    for _, module in ipairs(loader.list()) do
      if module.name and module.name ~= OWN_FOLDER then
        scratchAttach[module.name] = OWN_FOLDER
      end
    end
  end

  return scratchAttach
end

local function dependenciesOf(index, folder)
  if not GetAddOnDependencies then
    return nil
  end

  local list = depsPool[folder]

  if list and depsKnown[folder] then
    return list
  end

  if not list then
    list = {}
    depsPool[folder] = list
  end

  clear(list)

  local packed = { GetAddOnDependencies(index) }

  for i = 1, #packed do
    if type(packed[i]) == "string" and packed[i] ~= "" then
      list[#list + 1] = packed[i]
    end
  end

  -- The dependencies of a folder never change during the game: kept by FOLDER. The only caller got `folder` from
  -- GetAddOnInfo(index) in the same pass, so no second read of the addon list is needed.
  if folder then
    depsKnown[folder] = true
  end

  return list
end

local function isWatching()
  return next(watchers) ~= nil
end

function Perf.watch(enabled, owner)
  if owner == nil then
    owner = commonOwner
  end

  if enabled then
    watchers[owner] = true
  elseif watchers[owner] then
    watchers[owner] = nil
  else
    return isWatching()
  end

  if enabled or not isWatching() then
    lastMs = nil
    lastAt = nil
    clear(peaks)
  end

  return isWatching()
end

function Perf.status()
  return { profiling = profiling() and true or false, elapsed = now() - cpuSince }
end

function Perf.resetAll(keepGrowth)
  if ResetCPUUsage then
    ResetCPUUsage()
  end

  cpuSince = now()
  lastMs = nil
  lastAt = nil
  clear(peaks)
  clear(memRef)

  if not keepGrowth then
    clear(prevMem)
    clear(lastGrowth)
    prevMemAt = nil
  end

  refreshMemory()

  if GetNumAddOns and GetAddOnInfo and GetAddOnMemoryUsage then
    for index = 1, GetNumAddOns() do
      local folder = GetAddOnInfo(index)

      if folder then
        memRef[folder] = GetAddOnMemoryUsage(index)
      end
    end
  end

  memRefAt = now()

  return true
end

function Perf.gcAll()
  local before = uiKB()

  pcall(collectgarbage, "collect")

  return before, uiKB()
end

function Perf.snapshot(opts)
  opts = opts or {}

  local t = now()
  local prof = profiling() and true or false
  local window = t - cpuSince
  local flat = {}
  local totalMs, totalKB, ownMs, ownKB, loaded = 0, 0, 0, 0, 0

  if prof then
    refreshCpu()
  end

  local memBefore = lastMemoryRefreshAt

  if opts.memory then
    refreshMemory(not opts.freshMemory)
  end

  -- A real refresh happened (or no reference yet): only then is growth recomputed; otherwise the last value stays.
  local seeding = prevMemAt == nil
  local realRefresh = GetAddOnMemoryUsage ~= nil and (seeding or lastMemoryRefreshAt ~= memBefore)
  local memDelta = (not seeding and realRefresh) and t - prevMemAt or 0

  local readMemory = GetAddOnMemoryUsage ~= nil
  local fresh = memRefAt == nil
  local memWindow = memRefAt and t - memRefAt or 0

  local attach = fillAttach()

  clear(scratchCpu)
  clear(scratchDeps)

  for index = 1, (GetNumAddOns and GetNumAddOns() or 0) do
    local folder, title = GetAddOnInfo(index)

    if folder and IsAddOnLoaded(index) then
      local ms = prof and (GetAddOnCPUUsage(index) or 0) or nil
      local kb = readMemory and (GetAddOnMemoryUsage(index) or 0) or 0
      local own = folder == OWN_FOLDER or attach[folder] ~= nil
      local growth = nil

      if fresh then
        memRef[folder] = kb
      end

      if realRefresh then
        if memDelta > 0 and prevMem[folder] then
          lastGrowth[folder] = (kb - prevMem[folder]) / memDelta
        end

        prevMem[folder] = kb
      end

      growth = lastGrowth[folder]

      loaded = loaded + 1
      totalKB = totalKB + kb

      if ms then
        totalMs = totalMs + ms
        scratchCpu[folder] = ms
      end

      scratchDeps[folder] = dependenciesOf(index, folder)
      local n = #flat + 1
      local row = rowPool[n]

      if not row then
        row = {}
        rowPool[n] = row
      end

      row.id = folder
      row.title = plain(title ~= "" and title or folder)
      row.kind = "addon"
      row.core = false
      row.own = own
      row.ms = ms
      row.rate = (ms and window > 0) and ms / window or nil
      row.memKB = kb
      row.growth = growth
      row.count = 1
      row.share = nil
      row.peak = nil
      flat[n] = row
    end
  end

  if fresh then
    memRefAt = t
  end

  if realRefresh then
    prevMemAt = t
  end

  local total = nil

  for i = 1, #flat do
    local row = flat[i]

    if row.ms then
      row.share = totalMs > 0 and row.ms / totalMs or 0
    end

    if row.own then
      ownKB = ownKB + row.memKB

      if row.ms then
        ownMs = ownMs + row.ms
      end
    end
  end

  if prof and isWatching() then
    scratchCpu[TOTAL_KEY] = totalMs
    lastMs, peaks = PerfData.fold(lastMs, scratchCpu, lastAt and t - lastAt or 0, peaks)
    lastAt = t

    for i = 1, #flat do
      flat[i].peak = peaks[flat[i].id]
    end

    total = peaks[TOTAL_KEY]
  end

  local fps, latency

  if type(GetFramerate) == "function" then
    fps = GetFramerate()
  end

  if type(GetNetStats) == "function" then
    local _, _, ping = GetNetStats()

    latency = ping
  end

  return {
    at = t,
    window = window,
    profiling = prof,
    fps = fps,
    latency = latency,
    totals = {
      ms = prof and totalMs or nil,
      rate = (prof and window > 0) and totalMs / window or nil,
      peak = total,
      memKB = totalKB,
      uiKB = uiKB(),
      loaded = loaded,
      ownMs = prof and ownMs or nil,
      ownRate = (prof and window > 0) and ownMs / window or nil,
      ownShare = (prof and totalMs > 0) and ownMs / totalMs or nil,
      ownKB = ownKB,
    },
    rows = PerfData.group(flat, scratchDeps, attach),
  }
end

Perf.LIMITS = {
  sampleEvery = 5,
  -- Pace (seconds) of the data tick while the Performances page is shown (live values); nothing ticks when it is closed.
  liveEvery = 1,
  historySlices = 26,
  piecesKept = 25,
  unattributedKept = 25,
  instrumentSub = 32,
  instrumentUnitLoops = 2000,
  instrumentCalibrationLoops = 20000,
  -- Pace (seconds) of the recording of a "Measure" session: at each tick the CPU counter of every addon and the Lua heap
  -- are read. The addon list is fixed at the start of the session; the buffers are allocated once, sized from the duration.
  recordEvery = 0.5,
  -- Pace (seconds) of the memory read per addon (UpdateAddOnMemoryUsage costs about 29 ms per call): read at the start,
  -- at the end and every memoryEvery seconds in between.
  memoryEvery = 30,
}

local LIMITS = Perf.LIMITS

local SAMPLE_TICKER = "perf.sample"
local RECORD_TICKER = "perf.record"
local PHASE_ARMED, PHASE_RUNNING, PHASE_SCANNING, PHASE_DONE, PHASE_INTERRUPTED =
  "armed", "running", "scanning", "done", "interrupted"
local PIECE_REST = "rest"
local PIECE_ANALYSIS = "function"
local STATE_IDLE = "idle"
local CVAR = "scriptProfile"
local ON, OFF = "1", "0"

local memoryAccount = {}
local runStart = nil
local runLastMs = nil
local runLastAt = nil
local runPeaks = {}
local runGrowth = {}
local scratchRun = {}
local blocked = nil
local pending = nil
local hist = { slices = {}, prevMs = {}, prevMem = {}, prevAt = nil }

function Perf.eachTracked(fn)
  for owner, list in pairs(tracked) do
    for i = 1, #list do
      fn(owner, list[i].name, "frame", list[i].frame)
    end
  end

  for owner, list in pairs(functions) do
    for i = 1, #list do
      fn(owner, list[i].name, "function", list[i].fn)
    end
  end
end

local function account()
  if DB.isAttached() then
    local store = DB.store("EbonAPI", { account = {} })

    return store.account
  end

  return memoryAccount
end

local function inCombat()
  return InCombatLockdown ~= nil and InCombatLockdown() and true or false
end

local function say(text)
  Log.trace("print", "EbonAPI", text)
end

local function writeProfiler(value)
  if inCombat() then
    return false
  end

  return (pcall(SetCVar, CVAR, value))
end

local Instr = { active = false }

-- Recorder of a "Measure" session (read through Perf.recording()). Flat preallocated buffers, nothing created per tick:
--   n, index[a], folder[a]   addon list fixed at the start (a = 1..n)
--   count, at[s], heap[s]    sample s: time (GetTime) and Lua heap in KB; cpu[(s - 1) * n + a] = cumulative ms of addon a
--   memCount, memAt[m]       memory sample m: time; mem[(m - 1) * n + a] = KB of addon a
--   cap, memCap              buffer sizes in samples; dropped = ticks lost beyond cap; startAt = time of sample 1
--   calibrated               true when the calibration of the instrument was done before the first sample
local Rec = { active = false, n = 0, count = 0, memCount = 0, cap = 0, memCap = 0, dropped = 0, index = {}, folder = {},
  at = {}, heap = {}, cpu = {}, memAt = {}, mem = {} }

local function stopSampling()
  Rec.active = false
  Instr.stop()
  -- Every exit of a session (end, interruption, failure, clear) passes here: share timing is only on during a session.
  if EbonAPI.Share and EbonAPI.Share.setTiming then
    EbonAPI.Share.setTiming(false)
  end

  EbonAPI.Bus.untick(SAMPLE_TICKER)
  EbonAPI.Bus.untick(RECORD_TICKER)
end

local function clearHistory()
  clear(hist.slices)
  clear(hist.prevMs)
  clear(hist.prevMem)
  hist.prevAt = nil
end

local function clearRun()
  stopSampling()
  clearHistory()
  Rec.release()
  runStart = nil
  runLastMs = nil
  runLastAt = nil
  clear(runPeaks)
  clear(runGrowth)
end

function Perf.run()
  local data = account().perfRun
  local state = STATE_IDLE

  if type(data) == "table" and data.phase then
    state = data.phase

    if state == PHASE_INTERRUPTED then
      state = STATE_IDLE
    end
  end

  local seen = type(data) == "table" and data or {}

  return {
    state = state,
    interrupted = seen.phase == PHASE_INTERRUPTED,
    started = runStart,
    duration = seen.duration,
    profilerByAddon = seen.profilerByAddon and true or false,
    scan = seen.scan and true or false,
    restore = seen.restore and true or false,
    blocked = blocked,
    pending = pending,
    elapsed = runStart and now() - runStart or nil,
  }
end

function Perf.last()
  local runs = account().perfRuns

  return type(runs) == "table" and runs[1] or nil
end

-- The recorded sessions of this game session, most recent first (no bound: they are erased at the next load, see PURGED_KEYS).
function Perf.runs()
  local runs = account().perfRuns

  return type(runs) == "table" and runs or {}
end

-- Size in bytes of a value as the game writes it in SavedVariables (one line per field, tabs, "-- [i]" after each
-- element of a sequence). Counted, not built (measuring helper, nothing in the addon bounds the sessions with it).
function Perf.weight(value, depth)
  local kind = type(value)

  if kind == "string" then
    return #string.format("%q", value)
  elseif kind == "number" or kind == "boolean" then
    return #tostring(value)
  elseif kind ~= "table" then
    return 0
  end

  depth = depth or 0

  local pad = depth + 1
  local sequence = #value
  local bytes = 3 + depth

  for index = 1, sequence do
    bytes = bytes + pad + Perf.weight(value[index], depth + 1) + 8 + #tostring(index)
  end

  for key, item in pairs(value) do
    if not (type(key) == "number" and key >= 1 and key <= sequence) then
      local name = type(key) == "string" and string.format("[%q]", key) or "[" .. tostring(key) .. "]"

      bytes = bytes + pad + #name + 3 + Perf.weight(item, depth + 1) + 2
    end
  end

  return bytes
end

-- Puts a finished session first. No bound on the number or the weight: every "Measure" is added and written with the
-- SavedVariables at the reload or logout; the next load erases them all (Perf.PURGED_KEYS, Perf.purgeLegacy).
function Perf.keepRun(entry)
  local acc = account()

  if type(acc.perfRuns) ~= "table" then
    acc.perfRuns = {}
  end

  table.insert(acc.perfRuns, 1, entry)

  return entry
end

-- Seconds left in the running session (nil outside a running session).
function Perf.remaining()
  local data = account().perfRun

  if not runStart or type(data) ~= "table" or data.phase ~= PHASE_RUNNING then
    return nil
  end

  local left = (data.duration or 0) - (now() - runStart)

  return left > 0 and left or 0
end

-- Rolling history of the session, built on demand from the slices kept while sampling (one per sample, at most
-- LIMITS.historySlices). Per addon FOLDER, oldest first, missing slices read 0: cpu = ms/s, mem = KB at the end of
-- the slice, rate = KB/s net memory change. kbs = KB/s net change of ALL addons (garbage collection included).
local function buildHistory(slices)
  local out = { step = LIMITS.sampleEvery, count = #slices, kbs = {}, cpu = {}, mem = {}, rate = {} }

  for i = 1, #slices do
    local slice = slices[i]

    out.kbs[i] = slice.kbs

    for _, field in ipairs({ "cpu", "mem", "rate" }) do
      for folder in pairs(slice[field]) do
        if out[field][folder] == nil then
          out[field][folder] = {}

          for k = 1, #slices do
            out[field][folder][k] = 0
          end
        end
      end
    end
  end

  for i = 1, #slices do
    for _, field in ipairs({ "cpu", "mem", "rate" }) do
      for folder, series in pairs(out[field]) do
        series[i] = slices[i][field][folder] or 0
      end
    end
  end

  return out
end

function Perf.history()
  if runStart then
    return buildHistory(hist.slices)
  end

  local last = Perf.last()

  return PerfData.entryHistory(last, LIMITS.sampleEvery, LIMITS.historySlices)
end

-- One history slice per sample, from the cumulative CPU just read into scratchRun and the memory just refreshed.
local function recordSlice(t)
  local dt = hist.prevAt and t - hist.prevAt or 0

  if dt > 0 then
    local slice = { cpu = {}, mem = {}, rate = {}, kbs = 0 }

    for folder, ms in pairs(scratchRun) do
      if folder ~= TOTAL_KEY then
        slice.cpu[folder] = math.max(0, ms - (hist.prevMs[folder] or 0)) / dt
      end
    end

    for folder, kb in pairs(hist.nowMem) do
      local change = (kb - (hist.prevMem[folder] or kb)) / dt

      slice.mem[folder] = kb
      slice.rate[folder] = change
      slice.kbs = slice.kbs + change
    end

    hist.slices[#hist.slices + 1] = slice

    while #hist.slices > LIMITS.historySlices do
      table.remove(hist.slices, 1)
    end
  end

  clear(hist.prevMs)
  clear(hist.prevMem)

  for folder, ms in pairs(scratchRun) do
    hist.prevMs[folder] = ms
  end

  for folder, kb in pairs(hist.nowMem) do
    hist.prevMem[folder] = kb
  end

  hist.prevAt = t
end

local function sampleRun()
  if not profiling() then
    return
  end

  local t = now()

  refreshCpu()
  refreshMemory()
  clear(scratchRun)

  hist.nowMem = hist.nowMem or {}
  clear(hist.nowMem)

  local totalMs = 0
  local memWindow = memRefAt and t - memRefAt or 0

  for index = 1, (GetNumAddOns and GetNumAddOns() or 0) do
    local folder = GetAddOnInfo(index)

    if folder and IsAddOnLoaded(index) then
      local ms = GetAddOnCPUUsage(index) or 0

      totalMs = totalMs + ms
      scratchRun[folder] = ms

      if GetAddOnMemoryUsage then
        hist.nowMem[folder] = GetAddOnMemoryUsage(index) or 0
      end

      if GetAddOnMemoryUsage and memRef[folder] and memWindow > 0 then
        local rate = ((GetAddOnMemoryUsage(index) or 0) - memRef[folder]) / memWindow

        if runGrowth[folder] == nil or rate > runGrowth[folder] then
          runGrowth[folder] = rate
        end
      end
    end
  end

  scratchRun[TOTAL_KEY] = totalMs
  recordSlice(t)
  runLastMs, runPeaks = PerfData.fold(runLastMs, scratchRun, runLastAt and t - runLastAt or 0, runPeaks)
  runLastAt = t
end


-- Session instrument: while a session runs, the OnEvent and OnUpdate scripts of the Bus frame are swapped for a wrapper
-- that times each call with debugprofilestop (inclusive time: the internal events and the module subscribers are inside
-- the piece of the triggering event). Outside a session nothing is installed, nothing is allocated. The Bus
-- subscription tables are never touched.
-- Nesting: a reentrancy counter, no stack. A wrapper entered while another one is running (depth > 0) times nothing: the
-- time stays with the outer call and the session counts it in "nested". The Bus frame never gets OnUpdate during an
-- OnEvent and the wrapper has no pcall: a depth above 0 at the ENTRY of the OnUpdate wrapper is a leak (a call raised);
-- it is set back to 0 and counted in "leaks"; the error itself goes up as usual.
-- Time spent in the refreshes of the profiler counters made by this file (refreshCpu / refreshMemory) is taken out of
-- the piece of the call that contains them and reported in a piece of its own.
local OVERFLOW_KEY = "?"
local EVENT_ADDON, EVENT_CHANNEL = "CHAT_MSG_ADDON", "CHAT_MSG_CHANNEL"
local PIECE_BUS_EVENT, PIECE_BUS_TICK, PIECE_COST, PIECE_REFRESH = "bus_event", "bus_tick", "instrument", "refresh"
local TICK_LABEL = "Bus OnUpdate (tickers)"
local strbyte, select = string.byte, select

local depth, nested, leaks = 0, 0, 0
local wraps = 0
local origEvent, origUpdate = nil, nil
local instrEvents = {}
local tickSlot = { ms = 0, calls = 0 }
local channelSlot = { ms = 0, calls = 0 }
local otherChannelSlot = { ms = 0, calls = 0 }
local channelNumber = nil
local flowPrefix = nil
local samplesOpen, samplesTotal = 0, 0
local queueAtStart = { server = 0, channel = 0, whisper = 0 }
local lastInstr = nil
local refusedReason = nil

-- CHAT_MSG_ADDON of the EbonAPI prefix (the flow whispers): sub-key = first byte of the text (a number, no string made).
local function flowSlot(row, byte)
  local flow = row.flow

  if not flow then
    flow = {}
    row.flow = flow
    row.flowN = 0
  end

  local key = byte or OVERFLOW_KEY
  local slot = flow[key]

  if slot then
    return slot
  end

  if row.flowN >= LIMITS.instrumentSub then
    key = OVERFLOW_KEY
    slot = flow[key]
  end

  if not slot then
    slot = { ms = 0, calls = 0 }
    flow[key] = slot
    row.flowN = row.flowN + 1
  end

  return slot
end

local function slotFor(event, ...)
  if event == EVENT_CHANNEL then
    -- the channel number is compared to the one of EbonAPI read when the session began: nothing is made, no text is read
    local number = select(8, ...)

    if channelNumber ~= nil and number == channelNumber then
      return channelSlot
    end

    return otherChannelSlot
  end

  local row = instrEvents[event]

  if not row then
    row = { ms = 0, calls = 0, n = 0 }
    instrEvents[event] = row
  end

  if event ~= EVENT_ADDON then
    return row
  end

  local key, text = ...

  if key == flowPrefix then
    return flowSlot(row, type(text) == "string" and strbyte(text, 1) or nil)
  end

  local sub = row.sub

  if not sub then
    sub = {}
    row.sub = sub
  end

  local slot = sub[key]

  if slot then
    return slot
  end

  local kind = type(key)

  if kind ~= "string" or row.n >= LIMITS.instrumentSub then
    key = OVERFLOW_KEY
    slot = sub[key]
  end

  if not slot then
    slot = { ms = 0, calls = 0 }
    sub[key] = slot
    row.n = row.n + 1
  end

  return slot
end

local function finish(slot, t0, refreshed, ...)
  local own = clock() - t0 - (refreshAll - refreshed)

  slot.ms = slot.ms + (own > 0 and own or 0)
  slot.calls = slot.calls + 1
  wraps = wraps + 1
  depth = 0

  return ...
end

local function wrapEvent(self, event, ...)
  if depth > 0 then
    nested = nested + 1

    return origEvent(self, event, ...)
  end

  depth = 1

  local slot = slotFor(event, ...)

  return finish(slot, clock(), refreshAll, origEvent(self, event, ...))
end

local function wrapUpdate(self, elapsed)
  if depth > 0 then
    depth = 0
    leaks = leaks + 1
  end

  depth = 1

  return finish(tickSlot, clock(), refreshAll, origUpdate(self, elapsed))
end

local function noop() end

-- Cost of one wrapped call, measured by running the real wrapper on an empty function.
local function measureUnit()
  local keep = origEvent
  local n = LIMITS.instrumentUnitLoops

  origEvent = noop

  local t0 = clock()

  for _ = 1, n do
    wrapEvent(nil, "PERF_PROBE")
  end

  local spent = clock() - t0

  origEvent = keep
  instrEvents.PERF_PROBE = nil
  wraps, depth, nested, leaks = 0, 0, 0, 0

  return spent / n, n
end

-- A loop of clock reads against the rise of the profiler counter of EbonAPI: tells how the profiler reads our own time.
-- The first refresh is timed alone: if the loop that follows shows a rise of the counter beyond the loop itself that is
-- at least half of that refresh, the game bills the refreshes to EbonAPI (true); a rise that does not even show a
-- tenth of it says false; a refresh too short to be told apart from the noise of the loop, or anything in between,
-- says nil (undecidable, never a zero).
local function calibrate()
  if not (profiling() and UpdateAddOnCPUUsage and GetAddOnCPUUsage) then
    return { possible = false }
  end

  local n = LIMITS.instrumentCalibrationLoops

  local update = refreshCpu()
  local before = GetAddOnCPUUsage(OWN_FOLDER) or 0
  local t0 = clock()

  for _ = 1, n do
    clock()
  end

  local loop = clock() - t0

  refreshCpu()

  local delta = (GetAddOnCPUUsage(OWN_FOLDER) or 0) - before
  local verdict = nil

  if type(update) == "number" and update > 0 and update >= loop * 0.25 then
    local excess = delta - loop

    if excess >= update * 0.5 then
      verdict = true
    elseif excess <= update * 0.1 then
      verdict = false
    end
  end

  return { possible = true, loops = n, loopMs = loop, cpuDeltaMs = delta, updateMs = update,
    updateBilled = verdict }
end

local function queueSent(into)
  local sent = EbonAPI.Queue and EbonAPI.Queue.sent

  into.server, into.channel, into.whisper = sent and sent.server or 0, sent and sent.channel or 0,
    sent and sent.whisper or 0
end

-- Cumulative counters of the share channel, read once at the start and once at the end of a session (never per sample).
-- A missing function leaves its fields nil. Only counts: the ignored player names are never read.
local shareAtStart = {}

local function shareRead(into)
  local share = EbonAPI.Share

  into.keys, into.ms, into.ignored, into.players = nil, nil, nil, nil

  if share and share.receiveStats then
    local received = share.receiveStats()

    if type(received) == "table" then
      into.keys, into.ms = received.keys, received.ms
    end
  end

  if share and share.ignoredStats then
    into.ignored, into.players = share.ignoredStats()
  end
end

local function shareDelta(from, to)
  if type(from) == "number" and type(to) == "number" then
    return to - from
  end

  return nil
end

function Instr.start()
  Instr.stop()
  lastInstr = nil
  refusedReason = nil

  local frame = EbonAPI.Bus and EbonAPI.Bus.frame

  clock = debugprofilestop

  -- Every refusal leaves a raw code in totals.instrument.instrumentRefused (never translated text).
  if type(clock) ~= "function" then
    refusedReason = "noClock"
  elseif type(frame) ~= "table" then
    refusedReason = "noFrame"
  elseif not frame.GetScript then
    refusedReason = "noGetScript"
  elseif not profiling() then
    refusedReason = "noProfiler"
  end

  if refusedReason then
    return false
  end

  origEvent, origUpdate = frame:GetScript("OnEvent"), frame:GetScript("OnUpdate")

  if not origEvent or not origUpdate then
    refusedReason = origEvent and "noOnUpdate" or "noOnEvent"
    origEvent, origUpdate = nil, nil

    return false
  end

  clear(instrEvents)
  tickSlot.ms, tickSlot.calls = 0, 0
  channelSlot.ms, channelSlot.calls = 0, 0
  otherChannelSlot.ms, otherChannelSlot.calls = 0, 0
  wraps, depth, nested, leaks = 0, 0, 0, 0
  refreshCpuMs, refreshCpuCalls, refreshMemMs, refreshMemCalls, refreshAll = 0, 0, 0, 0, 0
  samplesOpen, samplesTotal = 0, 0

  local unit, unitLoops = measureUnit()
  local channel = EbonAPI.Channel

  channelNumber = channel and channel.index and channel.index() or nil
  flowPrefix = EbonAPI.Share and EbonAPI.Share.PREFIX or "EbonAPI"
  queueSent(queueAtStart)
  shareRead(shareAtStart)
  metered = true
  Instr.unit, Instr.unitLoops, Instr.calibration = unit, unitLoops, calibrate()
  Instr.frame = frame
  frame:SetScript("OnEvent", wrapEvent)
  frame:SetScript("OnUpdate", wrapUpdate)
  Instr.active = true

  return true
end

-- One look at the main window of EbonAPI per sample (Window.frame is the existing read accessor of the window).
local function noteWindow()
  local window = EbonAPI.Window
  local main = window and window.frame and window.frame()

  samplesTotal = samplesTotal + 1

  if main and main:IsShown() then
    samplesOpen = samplesOpen + 1
  end
end

local function flowLabel(byte)
  if type(byte) == "number" and byte >= 33 and byte <= 126 then
    return EVENT_ADDON .. " [" .. flowPrefix .. " " .. string.char(byte) .. "]"
  end

  return EVENT_ADDON .. " [" .. flowPrefix .. " " .. tostring(byte) .. "]"
end

local function collect()
  local pieces, generic = {}, {}

  local function add(label, kind, slot, key)
    if slot.calls > 0 then
      pieces[#pieces + 1] = { label = label, kind = kind, ms = slot.ms, calls = slot.calls, count = 1 }

      if key == OVERFLOW_KEY then
        generic[#generic + 1] = { label = label, calls = slot.calls }
      end
    end
  end

  for event, row in pairs(instrEvents) do
    if row.sub or row.flow then
      for key, slot in pairs(row.sub or {}) do
        add(event .. " [" .. tostring(key) .. "]", PIECE_BUS_EVENT, slot, key)
      end

      for key, slot in pairs(row.flow or {}) do
        add(key == OVERFLOW_KEY and (event .. " [" .. flowPrefix .. " " .. OVERFLOW_KEY .. "]") or flowLabel(key),
          PIECE_BUS_EVENT, slot, key)
      end
    else
      add(event, PIECE_BUS_EVENT, row)
    end
  end

  add(EVENT_CHANNEL .. " [~channel " .. tostring(channelNumber) .. "]", PIECE_BUS_EVENT,
    channelSlot)
  add(EVENT_CHANNEL .. " [~channelOther]", PIECE_BUS_EVENT, otherChannelSlot)
  add(TICK_LABEL, PIECE_BUS_TICK, tickSlot)

  return pieces, generic
end

function Instr.stop()
  if not Instr.active then
    return
  end

  Instr.active = false
  metered = false

  local frame = Instr.frame

  if frame:GetScript("OnEvent") == wrapEvent then
    frame:SetScript("OnEvent", origEvent)
  end

  if frame:GetScript("OnUpdate") == wrapUpdate then
    frame:SetScript("OnUpdate", origUpdate)
  end

  local pieces, generic = collect()
  local sent = {}

  queueSent(sent)

  for field, value in pairs(sent) do
    sent[field] = value - queueAtStart[field]
  end

  local shareNow = {}

  shareRead(shareNow)

  lastInstr = { shareKeys = shareDelta(shareAtStart.keys, shareNow.keys), shareMs = shareDelta(shareAtStart.ms, shareNow.ms),
    shareIgnored = shareDelta(shareAtStart.ignored, shareNow.ignored),
    shareIgnoredPlayers = shareDelta(shareAtStart.players, shareNow.players), pieces = pieces, generic = generic, wraps = wraps, unitMs = Instr.unit, unitLoops = Instr.unitLoops,
    calibration = Instr.calibration, nested = nested, leaks = leaks, samplesOpen = samplesOpen,
    samplesTotal = samplesTotal, queueSent = sent,
    refresh = { cpuMs = refreshCpuMs, cpuCalls = refreshCpuCalls, memoryMs = refreshMemMs,
      memoryCalls = refreshMemCalls } }
  Instr.frame, origEvent, origUpdate = nil, nil, nil
  clear(instrEvents)
end

-- Own CPU of EbonAPI and CPU of its whole family (EbonAPI + the EbonAPI-* modules) in the snapshot rows.
local function familyCpu(rows, out)
  out = out or { own = 0, family = 0 }

  for i = 1, #rows do
    local row = rows[i]

    if row.kind == "addon" and type(row.id) == "string" and row.ms then
      if row.id == OWN_FOLDER then
        out.own = out.own + row.ms
        out.family = out.family + row.ms
      elseif string.sub(row.id, 1, #OWN_FOLDER + 1) == OWN_FOLDER .. "-" then
        out.family = out.family + row.ms
      end
    end

    if row.children then
      familyCpu(row.children, out)
    end
  end

  return out
end

-- The pieces for the EbonAPI row (never more than the CPU of EbonAPI) and the record kept with the session.
local function instrumentExtra(rows)
  local data = lastInstr

  lastInstr = nil

  if not data then
    local refused = refusedReason

    refusedReason = nil

    return nil, refused and { instrumentRefused = refused } or nil
  end

  local cpu = familyCpu(rows)
  local cost = data.wraps * data.unitMs
  local refresh = data.refresh
  local refreshMs = refresh.cpuMs + refresh.memoryMs
  local sum = cost + refreshMs

  for i = 1, #data.pieces do
    sum = sum + data.pieces[i].ms
  end

  local scale = (sum > cpu.own and sum > 0) and cpu.own / sum or 1

  for i = 1, #data.pieces do
    data.pieces[i].ms = data.pieces[i].ms * scale
  end

  cost = cost * scale

  local costs = { { label = "~instrument", kind = PIECE_COST, ms = cost, calls = data.wraps, count = 1 } }

  if refresh.cpuCalls + refresh.memoryCalls > 0 then
    costs[2] = { label = "~refresh", kind = PIECE_REFRESH, ms = refreshMs * scale,
      calls = refresh.cpuCalls + refresh.memoryCalls, count = 1 }
  end

  local shown = sum * scale

  return { pieces = data.pieces, costs = costs },
    { inclusive = true, attributedMs = shown,
      cpuOwnMs = cpu.own, cpuFamilyMs = cpu.family, wraps = data.wraps, unitMs = data.unitMs,
      unitLoops = data.unitLoops, costMs = cost, scale = scale, calibration = data.calibration,
      generic = data.generic, nested = data.nested, leaks = data.leaks, samplesOpen = data.samplesOpen,
      samplesTotal = data.samplesTotal, queueSent = data.queueSent, refresh = refresh,
      shareKeys = data.shareKeys, shareMs = data.shareMs, shareIgnored = data.shareIgnored,
      shareIgnoredPlayers = data.shareIgnoredPlayers }
end

-- Recorder of the session (see Rec above). One tick = one profiler refresh, one read of the counter per addon of the
-- fixed list, one read of the heap: numbers written into preallocated arrays, no table, no closure, no string.
local function recordFill(t, size)
  for i = 1, size do
    t[i] = 0
  end
end

function Rec.start(duration)
  local n = 0

  clear(Rec.index)
  clear(Rec.folder)

  for index = 1, (GetNumAddOns and GetNumAddOns() or 0) do
    local folder = GetAddOnInfo(index)

    if folder and IsAddOnLoaded(index) then
      n = n + 1
      Rec.index[n], Rec.folder[n] = index, folder
    end
  end

  local span = type(duration) == "number" and duration > 0 and duration or 0

  Rec.n = n
  Rec.cap = math.floor(span / LIMITS.recordEvery) + 3
  Rec.memCap = math.floor(span / LIMITS.memoryEvery) + 3
  recordFill(Rec.at, Rec.cap)
  recordFill(Rec.heap, Rec.cap)
  recordFill(Rec.cpu, Rec.cap * n)
  recordFill(Rec.memAt, Rec.memCap)
  recordFill(Rec.mem, Rec.memCap * n)
  Rec.count, Rec.memCount, Rec.dropped = 0, 0, 0
  Rec.startAt = now()
  Rec.nextMem = LIMITS.memoryEvery
  Rec.calibrated = Instr.calibration ~= nil
  Rec.active = true
end

function Rec.release()
  Rec.active = false
  Rec.n, Rec.count, Rec.memCount, Rec.cap, Rec.memCap, Rec.dropped = 0, 0, 0, 0, 0, 0
  Rec.startAt, Rec.nextMem, Rec.calibrated = nil, nil, nil
  clear(Rec.index)
  clear(Rec.folder)
  clear(Rec.at)
  clear(Rec.heap)
  clear(Rec.cpu)
  clear(Rec.memAt)
  clear(Rec.mem)
end

-- withMemory: also read the memory of every addon (start, end, and each LIMITS.memoryEvery seconds).
function Rec.sample(withMemory)
  if not profiling() then
    return
  end

  local t = now()
  local n = Rec.n
  local s = Rec.count + 1

  if s > Rec.cap then
    Rec.dropped = Rec.dropped + 1

    return
  end

  refreshCpu()

  local base = (s - 1) * n
  local cpu, index = Rec.cpu, Rec.index

  for a = 1, n do
    cpu[base + a] = GetAddOnCPUUsage(index[a]) or 0
  end

  Rec.at[s], Rec.heap[s], Rec.count = t, collectgarbage("count"), s

  local m = Rec.memCount + 1

  if withMemory and m <= Rec.memCap and GetAddOnMemoryUsage and UpdateAddOnMemoryUsage
    and (m == 1 or Rec.memAt[m - 1] ~= t) then
    refreshMemory()

    local mem = Rec.mem
    local mbase = (m - 1) * n

    for a = 1, n do
      mem[mbase + a] = GetAddOnMemoryUsage(index[a]) or 0
    end

    Rec.memAt[m], Rec.memCount = t, m
  end
end

local function recordTick()
  if not Rec.active then
    return
  end

  local elapsed = now() - Rec.startAt
  local due = elapsed >= Rec.nextMem

  if due then
    while Rec.nextMem <= elapsed do
      Rec.nextMem = Rec.nextMem + LIMITS.memoryEvery
    end
  end

  Rec.sample(due)
end

-- The buffers of the running (or just finished, before clearRun) session. Read-only for the callers.
function Perf.recording()
  return Rec
end

local function startRun()
  Perf.resetAll(true)
  clear(runPeaks)
  clear(runGrowth)
  runLastMs = nil
  runLastAt = nil
  runStart = now()
  clearHistory()
  hist.prevAt = runStart

  for folder, kb in pairs(memRef) do
    hist.prevMem[folder] = kb
  end

  EbonAPI.Bus.tick(SAMPLE_TICKER, LIMITS.sampleEvery, function()
    if metered then
      noteWindow()
    end

    sampleRun()

    local data = account().perfRun

    if runStart and type(data) == "table" and now() - runStart >= (data.duration or 0) then
      Perf.finish()
    end
  end, "EbonAPI")
  if EbonAPI.Share and EbonAPI.Share.setTiming then
    EbonAPI.Share.setTiming(true)
  end

  Instr.start()
  Perf.snapshot({ memory = true, freshMemory = true })
  Rec.start(account().perfRun and account().perfRun.duration)
  Rec.sample(true)
  EbonAPI.Bus.tick(RECORD_TICKER, LIMITS.recordEvery, recordTick, "EbonAPI")
end

function Perf.begin(seconds, opts)
  if not profiling() then
    return false
  end

  local data = account().perfRun

  if type(data) == "table" and (data.phase == PHASE_RUNNING or data.phase == PHASE_SCANNING) then
    return false
  end

  account().perfRun = { phase = PHASE_RUNNING, duration = seconds, profilerByAddon = false,
    startedAt = time and time() or 0, scan = type(opts) == "table" and opts.scan and true or nil }
  startRun()

  return true
end

function Perf.enableProfiler(seconds, opts)
  if profiling() then
    return Perf.begin(seconds, opts)
  end

  if inCombat() or not pcall(SetCVar, CVAR, ON) then
    blocked = true
    pending = seconds

    return false
  end

  blocked = nil
  pending = nil
  account().perfRun = { phase = PHASE_ARMED, duration = seconds, profilerByAddon = true,
    scan = type(opts) == "table" and opts.scan and true or nil }
  ReloadUI()

  return true
end

function Perf.disableProfiler()
  if not writeProfiler(OFF) then
    blocked = true
    pending = nil

    return false
  end

  blocked = nil

  local data = account().perfRun

  if type(data) == "table" then
    data.restore = nil
  end

  ReloadUI()

  return true
end

-- Purge granted by the owner: perfLast and perfReports (replaced by perfRuns) are removed from the account at login, and
-- so is perfRuns itself (the owner: "Lors du prochain demarrage celles-ci effacees"). The SavedVariables are written at the
-- reload or logout BEFORE the next load runs this purge, so the sessions stay readable in the file until then.
-- Nothing else is written. A key that is absent is not touched.
Perf.PURGED_KEYS = { "perfLast", "perfReports", "perfRuns" }

function Perf.purgeLegacy()
  local acc = account()
  local removed = 0

  for _, key in ipairs(Perf.PURGED_KEYS) do
    if acc[key] ~= nil then
      acc[key] = nil
      removed = removed + 1
    end
  end

  return removed
end

function Perf.resume()
  Perf.purgeLegacy()

  local data = account().perfRun

  if type(data) ~= "table" or not data.phase then
    return STATE_IDLE
  end

  if data.phase == PHASE_ARMED then
    if profiling() then
      data.phase = PHASE_RUNNING
      data.startedAt = time and time() or 0
      startRun()

      return PHASE_RUNNING
    end

    account().perfRun = nil
    say(L.PERFPAGE_RUN_INTERRUPTED)

    return STATE_IDLE
  end

  if data.phase == PHASE_RUNNING or data.phase == PHASE_SCANNING then
    data.phase = PHASE_INTERRUPTED
    data.restore = data.profilerByAddon and profiling() or nil
    say(L.PERFPAGE_RUN_INTERRUPTED)

    return PHASE_INTERRUPTED
  end

  return data.phase
end

local function scanResult()
  local scan = EbonAPI.PerfScan

  if scan and scan.result then
    return scan.result() or {}
  end

  return {}
end

local function byCost(a, b)
  return (a.ms or 0) > (b.ms or 0)
end

local function copyPiece(piece, window)
  local ms = piece.ms or 0

  return { label = piece.label, kind = piece.kind, ms = ms, calls = piece.calls or 0, count = piece.count or 1,
    rate = window > 0 and ms / window or nil }
end

local function trimPieces(list, limit, window)
  local out = {}

  for i = 1, #list do
    out[i] = copyPiece(list[i], window)
  end

  sort(out, byCost)

  while #out > limit do
    out[#out] = nil
  end

  return out
end

local function piecesFor(row, scanned, analysis, window, extra)
  local list = {}

  for i = 1, #(scanned and scanned.pieces or {}) do
    list[#list + 1] = scanned.pieces[i]
  end

  if analysis and row.id == OWN_FOLDER then
    list[#list + 1] = analysis
  end

  local costs = nil

  if extra and row.id == OWN_FOLDER then
    for i = 1, #extra.pieces do
      list[#list + 1] = extra.pieces[i]
    end

    costs = extra.costs
  end

  local pieces = trimPieces(list, LIMITS.piecesKept - (costs and #costs or 0), window)

  if costs then
    for i = 1, #costs do
      pieces[#pieces + 1] = copyPiece(costs[i], window)
    end

    sort(pieces, byCost)
  end

  local sum = 0

  for i = 1, #pieces do
    sum = sum + pieces[i].ms
  end

  local rest = row.ms and row.ms - sum or 0

  pieces[#pieces + 1] = { label = "~rest", kind = PIECE_REST, ms = rest > 0 and rest or 0, calls = 0,
    count = 0, rate = (window > 0 and rest > 0) and rest / window or nil }

  return pieces
end

local function decorate(row, result, analysis, window, extra)
  if row.kind == "addon" then
    row.pieces = piecesFor(row, result.byAddon and result.byAddon[row.id], analysis, window, extra)
    row.peak = runPeaks[row.id]
    row.growthPeak = runGrowth[row.id]
  end

  if row.children then
    local peak = nil

    for i = 1, #row.children do
      decorate(row.children[i], result, analysis, window, extra)

      if row.children[i].peak then
        peak = (peak or 0) + row.children[i].peak
      end
    end

    row.peak = peak
  end
end

-- The EbonAPI line shows the CPU of EbonAPI minus the cost of the instrument, but only when the calibration established
-- that the profiler refreshes are billed to EbonAPI (updateBilled == true). The cost of the instrument is always kept
-- apart in the record (instrumentMs) and in the pieces of the line (never hidden). Without a verdict (nil) or with false
-- nothing is corrected; the record says why (correctionReason) and keeps the raw updateBilled field.
local function correctRows(rows, ms, window)
  local found = false

  for i = 1, #rows do
    local row = rows[i]
    local inside = row.kind == "addon" and row.id == OWN_FOLDER

    if row.children and correctRows(row.children, ms, window) then
      inside = true
    end

    if inside and row.ms then
      row.msRaw = row.ms
      row.ms = math.max(0, row.ms - ms)
      row.rate = window > 0 and row.ms / window or row.rate
      found = true
    end
  end

  return found
end

local function reshare(rows, totalMs)
  for i = 1, #rows do
    local row = rows[i]

    if row.ms then
      row.share = totalMs > 0 and row.ms / totalMs or 0
    end

    if row.children then
      reshare(row.children, totalMs)
    end
  end
end

local function correctForInstrument(snap, extra, record)
  if not record or not extra then
    return
  end

  local calibration = record.calibration
  local billed = calibration and calibration.updateBilled
  local instrumentMs = 0

  for i = 1, #extra.costs do
    instrumentMs = instrumentMs + extra.costs[i].ms
  end

  record.instrumentMs = instrumentMs
  record.correctionApplied = false
  record.correctionMs = 0
  record.correctionReason = (not calibration or not calibration.possible) and "noCalibration"
    or billed == nil and "undecided" or billed == false and "notBilled" or "billed"

  if billed ~= true or not snap.totals.ms then
    return
  end

  local totals = snap.totals

  if not correctRows(snap.rows, instrumentMs, snap.window) then
    return
  end

  totals.msRaw, totals.ownMsRaw = totals.ms, totals.ownMs
  totals.ms = math.max(0, totals.ms - instrumentMs)
  totals.ownMs = totals.ownMs and math.max(0, totals.ownMs - instrumentMs) or nil
  totals.rate = snap.window > 0 and totals.ms / snap.window or totals.rate
  totals.ownRate = (totals.ownMs and snap.window > 0) and totals.ownMs / snap.window or totals.ownRate
  totals.ownShare = (totals.ownMs and totals.ms > 0) and totals.ownMs / totals.ms or totals.ownShare
  reshare(snap.rows, totals.ms)
  record.correctionApplied = true
  record.correctionMs = instrumentMs
  record.cpuOwnCorrectedMs = math.max(0, record.cpuOwnMs - instrumentMs)
end

local function complete(startedMs, startedWall, scanned)
  local data = account().perfRun
  local result = scanned and scanResult() or {}

  if profiling() then
    refreshCpu()
  end

  local snap = Perf.snapshot({ memory = true, freshMemory = true })
  local window = snap.window
  local analysis = nil

  if scanned and profiling() and GetAddOnCPUUsage then
    local spent = (GetAddOnCPUUsage(OWN_FOLDER) or 0) - (startedMs or 0)

    analysis = { label = "~scanning", kind = PIECE_ANALYSIS, ms = spent > 0 and spent or 0, calls = 1,
      count = 1 }
  end

  local extra, record = instrumentExtra(snap.rows)

  for i = 1, #snap.rows do
    decorate(snap.rows[i], result, analysis, window, extra)
  end

  correctForInstrument(snap, extra, record)

  local stats = result.stats or {}
  local totals = snap.totals

  totals.peak = runPeaks[TOTAL_KEY]
  totals.instrument = record

  Perf.keepRun({
    at = (date and date("%Y-%m-%d %H:%M:%S")) or "",
    duration = now() - (runStart or startedWall or now()),
    profilerByAddon = data.profilerByAddon and true or false,
    totals = totals,
    -- Text only (see PerfData.encodeRows): no table per row / piece; the page decodes the session it shows.
    win = math.floor(window * 1000 + 0.5),
    rc = PerfData.encodeRows(snap.rows),
    rec = PerfData.encodeRecording(Rec),
    ua = PerfData.encodePieces(trimPieces(result.unattributed or {}, LIMITS.unattributedKept, window)),
    stats = { frames = stats.frames, tables = stats.tables, functions = stats.functions, ms = stats.ms },
  })

  if data.profilerByAddon then
    data.restore = writeProfiler(OFF) or true
  end

  data.phase = PHASE_DONE
  clearRun()
  say(L.PERFPAGE_RUN_DONE)
end

function Perf.finish()
  local data = account().perfRun

  if type(data) ~= "table" or data.phase ~= PHASE_RUNNING then
    return false
  end

  Rec.sample(true)
  stopSampling()
  sampleRun()

  local startedMs = nil

  if profiling() and GetAddOnCPUUsage then
    refreshCpu()
    startedMs = GetAddOnCPUUsage(OWN_FOLDER) or 0
  end

  local scan = EbonAPI.PerfScan
  local startedWall = runStart

  local function abort()
    data.phase = PHASE_INTERRUPTED
    data.restore = data.profilerByAddon and (writeProfiler(OFF) or true) or nil
    clearRun()
    say(L.PERFPAGE_RUN_INTERRUPTED)
  end

  if data.scan and scan and scan.start then
    data.phase = PHASE_SCANNING

    local started = scan.start(function(_, cancelled)
      if data.phase ~= PHASE_SCANNING then
        return
      end

      if cancelled or not pcall(complete, startedMs, startedWall, true) then
        abort()
      end
    end)

    if not started and data.phase == PHASE_SCANNING then
      abort()
    end
  elseif not pcall(complete, startedMs, startedWall, false) then
    abort()
  end

  return true
end
