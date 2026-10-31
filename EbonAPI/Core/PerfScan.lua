EbonAPI = EbonAPI or {}
EbonAPI.PerfScan = {}

local PerfScan = EbonAPI.PerfScan
local Bus = EbonAPI.Bus

local type, pcall, next, rawget, tostring, pairs, tonumber = type, pcall, next, rawget, tostring, pairs, tonumber
local sort = table.sort
local lower, gsub, sub = string.lower, string.gsub, string.sub

local LIMITS = {
  timerId = "perf.scan",
  tickEvery = 0.05,
  budgetMs = 6,
  maxDepth = 4,
  maxKeys = 4000,
  maxRootKeys = 100000,
  maxTables = 6000,
  maxFrames = 20000,
  maxPieces = 6000,
  piecesCap = 100,
  unattributedCap = 100,
  prefixMin = 3,
  parentDepth = 4,
  coreName = "EbonAPI",
  secureProbeKey = "EbonAPI",
  scripts = {
    "OnUpdate", "OnEvent", "OnShow", "OnHide", "OnClick", "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp",
    "OnMouseWheel", "OnValueChanged", "OnTextChanged", "OnEnterPressed", "OnEscapePressed", "OnKeyDown",
    "OnKeyUp", "OnChar", "OnDragStart", "OnDragStop", "OnReceiveDrag", "OnSizeChanged", "OnAttributeChanged",
    "OnLoad", "OnEditFocusGained", "OnEditFocusLost", "OnTooltipSetItem", "OnTooltipCleared",
  },
}

PerfScan.LIMITS = LIMITS

local KIND = {
  OnUpdate = "onupdate",
  OnEvent = "onevent",
}

local PHASE_REGISTRY, PHASE_FRAMES, PHASE_GLOBALS, PHASE_DONE = 1, 2, 3, 4

local running = false
local lastResult = nil
local onDoneFn = nil
local state = nil
local selfPiece = nil

local function hasScript(frame, name)
  return frame:HasScript(name)
end

local function getScript(frame, name)
  return frame:GetScript(name)
end

local function frameName(frame)
  return frame:GetName()
end

local function frameParent(frame)
  return frame:GetParent()
end

local function ownerFolder(owner)
  local name

  if type(owner) == "string" then
    name = owner
  elseif type(owner) == "table" then
    local ok, found = pcall(function(o)
      return o.addonName or o.name
    end, owner)

    if ok and type(found) == "string" then
      name = found
    end
  end

  if not name then
    return LIMITS.coreName
  end

  local perf = EbonAPI.Perf

  if perf and perf.addonFolder then
    local ok, folder = pcall(perf.addonFolder, name)

    if ok and type(folder) == "string" then
      return folder
    end
  end

  return name
end

local function normalize(text)
  return lower((gsub(tostring(text), "[^%w]", "")))
end

local function buildFolders()
  local folders = { exact = {}, list = {} }
  local perf = EbonAPI.Perf
  local names = {}

  if perf and perf.owners then
    local ok, got = pcall(perf.owners)

    if ok and type(got) == "table" then
      names = got
    end
  end

  names[#names + 1] = LIMITS.coreName

  for index = 1, #names do
    local folder = ownerFolder(names[index])
    local norm = normalize(folder)

    if norm ~= "" and not folders.exact[norm] then
      folders.exact[norm] = folder
      folders.list[#folders.list + 1] = { norm = norm, folder = folder, len = #norm }
    end
  end

  return folders
end

local function matchFolder(text)
  if type(text) ~= "string" then
    return nil
  end

  local cache = state.matchCache
  local cached = cache[text]

  if cached ~= nil then
    return cached or nil
  end

  local folders = state.folders
  local norm = normalize(text)
  local found = folders.exact[norm]

  if not found then
    local best = 0

    for index = 1, #folders.list do
      local entry = folders.list[index]

      if entry.len >= LIMITS.prefixMin and entry.len > best and sub(norm, 1, entry.len) == entry.norm then
        best = entry.len
        found = entry.folder
      end
    end
  end

  cache[text] = found or false

  return found
end

local function taintOf(container, key)
  if not state.capable or not issecurevariable then
    return nil
  end

  local ok, _, who = pcall(issecurevariable, container, key)

  if ok and type(who) == "string" then
    return who
  end

  return nil
end

local function readCost(fn)
  if not GetFunctionCPUUsage then
    return 0, 0
  end

  local ok, ms, calls = pcall(GetFunctionCPUUsage, fn, false)

  if not ok then
    return 0, 0
  end

  return tonumber(ms) or 0, tonumber(calls) or 0
end

local function addPiece(fn, label, kind, addon, named)
  if type(fn) ~= "function" then
    return nil
  end

  local seen = state.seen
  local known = seen[fn]

  if known then
    known.count = known.count + 1

    return known
  end

  if known == false then
    return nil
  end

  local ms, calls = readCost(fn)

  if not named and ms <= 0 and calls <= 0 then
    seen[fn] = false

    return nil
  end

  if state.pieceCount >= LIMITS.maxPieces then
    return nil
  end

  local piece = { label = label, kind = kind, ms = ms, calls = calls, count = 1, addon = addon, fn = fn }

  seen[fn] = piece
  state.pieceCount = state.pieceCount + 1
  state.pieces[state.pieceCount] = piece

  return piece
end

local function scriptsOf(frame, label, addon, named)
  local scripts = LIMITS.scripts

  for index = 1, #scripts do
    local script = scripts[index]
    local ok, has = pcall(hasScript, frame, script)

    if ok and has then
      local got, fn = pcall(getScript, frame, script)

      if got and type(fn) == "function" then
        addPiece(fn, label .. ":" .. script, KIND[script] or "script", addon, named)
      end
    end
  end
end

local function frameLabelAndAddon(frame)
  local okName, name = pcall(frameName, frame)

  if not okName or type(name) ~= "string" then
    name = nil
  end

  local addon

  if name then
    addon = taintOf(_G, name) or matchFolder(name)
  end

  local label = name
  local parent = frame
  local depth = 0

  while (not name or not addon) and depth < LIMITS.parentDepth do
    local okParent, up = pcall(frameParent, parent)

    if not okParent or type(up) ~= "table" then
      break
    end

    local okUp, upName = pcall(frameName, up)

    if okUp and type(upName) == "string" then
      if not label then
        label = upName .. ".*"
      end

      addon = addon or taintOf(_G, upName) or matchFolder(upName)

      if addon then
        break
      end
    end

    parent = up
    depth = depth + 1
  end

  return label or "?", addon
end

local function processFrame(frame, label, addon, named)
  local visited = state.visited

  if visited[frame] then
    return
  end

  visited[frame] = true
  state.frames = state.frames + 1

  if not label then
    label, addon = frameLabelAndAddon(frame)
  end

  scriptsOf(frame, label, addon, named)
end

local function collectRegistries()
  local queue = state.queue

  if Bus and Bus.eachTicker then
    Bus.eachTicker(function(id, owner, fn)
      queue[#queue + 1] = { fn = fn, label = tostring(id), kind = "timer", addon = ownerFolder(owner) }
    end)
  end

  if Bus and Bus.eachHandler then
    Bus.eachHandler(function(event, fn, owner, isCore)
      queue[#queue + 1] = { fn = fn, label = tostring(event), kind = "event", addon = (isCore and not owner) and LIMITS.coreName or ownerFolder(owner) }
    end)
  end

  if EbonAPI.eachSubscription then
    EbonAPI.eachSubscription(function(event, fn, owner)
      queue[#queue + 1] = { fn = fn, label = tostring(event), kind = "event", addon = ownerFolder(owner) }
    end)
  end

  local perf = EbonAPI.Perf

  if perf and perf.eachTracked then
    perf.eachTracked(function(owner, name, kind, target)
      queue[#queue + 1] = { target = target, label = tostring(name), kind = kind, addon = ownerFolder(owner) }
    end)
  end
end

local function processEntry(entry)
  local target = entry.target

  if target == nil then
    addPiece(entry.fn, entry.label, entry.kind, entry.addon, true)
  elseif type(target) == "function" then
    addPiece(target, entry.label, "function", entry.addon, true)
  elseif type(target) == "table" then
    processFrame(target, entry.label, entry.addon, true)
  end
end

local function freeze(tbl, max)
  local keys, count = {}, 0
  max = max or LIMITS.maxKeys

  pcall(function()
    local key = next(tbl)

    while key ~= nil and count < max do
      count = count + 1
      keys[count] = key
      key = next(tbl, key)
    end
  end)

  return keys, count
end

local function isFrameTable(value)
  return type(rawget(value, 0)) == "userdata"
end

local function pushTable(tbl, addon, depth, path)
  local visited = state.visited

  if visited[tbl] or isFrameTable(tbl) or state.tables >= LIMITS.maxTables then
    return
  end

  visited[tbl] = true
  state.tables = state.tables + 1

  local keys, count = freeze(tbl)

  state.stack[#state.stack + 1] = { tbl = tbl, keys = keys, count = count, index = 1, addon = addon, depth = depth, path = path }
end

local function walkEntry(item, key)
  local value = rawget(item.tbl, key)
  local kind = type(value)
  local isRoot = item.tbl == _G

  if kind ~= "function" and kind ~= "table" then
    return
  end

  local textKey = type(key) == "string" and key or tostring(key)
  local addon = item.addon

  if isRoot then
    addon = taintOf(_G, key) or matchFolder(textKey)
  elseif not addon then
    addon = taintOf(item.tbl, key)
  end

  if kind == "function" then
    local label = item.path and (item.path .. "." .. textKey) or textKey

    addPiece(value, label, "function", addon, false)
  elseif item.depth < LIMITS.maxDepth and (addon or not isRoot) then
    pushTable(value, addon, item.depth + 1, item.path and (item.path .. "." .. textKey) or textKey)
  end
end

local function overBudget(t0)
  return debugprofilestop() - t0 >= LIMITS.budgetMs
end

local function advance(t0)
  while state.phase ~= PHASE_DONE do
    if state.phase == PHASE_REGISTRY then
      if not state.collected then
        state.collected = true
        collectRegistries()
      end

      local queue = state.queue

      while state.queueIndex <= #queue do
        if overBudget(t0) then
          return
        end

        processEntry(queue[state.queueIndex])
        state.queueIndex = state.queueIndex + 1
      end

      state.phase = PHASE_FRAMES
    elseif state.phase == PHASE_FRAMES then
      while true do
        if overBudget(t0) then
          return
        end

        local frame = EnumerateFrames and EnumerateFrames(state.cursor) or nil

        if frame == nil or state.frameSteps >= LIMITS.maxFrames then
          break
        end

        state.cursor = frame
        state.frameSteps = state.frameSteps + 1
        processFrame(frame)
      end

      state.phase = PHASE_GLOBALS
    elseif state.phase == PHASE_GLOBALS then
      if not state.rootPushed then
        state.rootPushed = true
        state.visited[_G] = true
        state.tables = state.tables + 1

        local keys, count = freeze(_G, LIMITS.maxRootKeys)

        state.stack[1] = { tbl = _G, keys = keys, count = count, index = 1, depth = 0 }
      end

      local stack = state.stack

      while #stack > 0 do
        if overBudget(t0) then
          return
        end

        local item = stack[#stack]

        if item.index > item.count then
          stack[#stack] = nil
        else
          local key = item.keys[item.index]

          item.index = item.index + 1
          walkEntry(item, key)
        end
      end

      state.phase = PHASE_DONE
    end
  end
end

local function buildResult()
  local byAddon = {}
  local unattributed = {}
  local pieces = state.pieces

  for index = 1, state.pieceCount do
    local piece = pieces[index]
    local out = { label = piece.label, kind = piece.kind, ms = piece.ms, calls = piece.calls, count = piece.count }

    if piece.addon then
      local entry = byAddon[piece.addon]

      if not entry then
        entry = { pieces = {} }
        byAddon[piece.addon] = entry
      end

      entry.pieces[#entry.pieces + 1] = out
    else
      unattributed[#unattributed + 1] = out
    end
  end

  local function byCost(a, b)
    if a.ms ~= b.ms then
      return a.ms > b.ms
    end

    if a.calls ~= b.calls then
      return a.calls > b.calls
    end

    return a.label < b.label
  end

  local function trim(list, cap)
    sort(list, byCost)

    for index = #list, cap + 1, -1 do
      list[index] = nil
    end
  end

  for _, entry in pairs(byAddon) do
    trim(entry.pieces, LIMITS.piecesCap)
  end

  trim(unattributed, LIMITS.unattributedCap)

  return {
    byAddon = byAddon,
    unattributed = unattributed,
    stats = { frames = state.frames, tables = state.tables, functions = state.pieceCount, ms = state.ms },
  }
end

local function finish()
  Bus.untick(LIMITS.timerId)

  lastResult = buildResult()
  running = false
  state = nil
  selfPiece = nil

  local done = onDoneFn

  onDoneFn = nil

  if done then
    pcall(done, lastResult)
  end
end

local function step()
  if not running or not state then
    Bus.untick(LIMITS.timerId)

    return
  end

  local t0 = debugprofilestop()
  local ok = pcall(advance, t0)

  state.ms = state.ms + (debugprofilestop() - t0)

  if not ok or state.phase == PHASE_DONE then
    finish()
  end
end

function PerfScan.start(onDone)
  if running then
    return false
  end

  local capable = false

  if issecurevariable then
    local ok, _, who = pcall(issecurevariable, _G, LIMITS.secureProbeKey)

    capable = ok and who ~= nil
  end

  state = {
    phase = PHASE_REGISTRY,
    capable = capable,
    seen = {},
    visited = {},
    pieces = {},
    pieceCount = 0,
    queue = {},
    queueIndex = 1,
    stack = {},
    matchCache = {},
    frames = 0,
    frameSteps = 0,
    tables = 0,
    ms = 0,
  }

  state.folders = buildFolders()
  running = true
  onDoneFn = onDone
  selfPiece = nil

  Bus.tick(LIMITS.timerId, LIMITS.tickEvery, step, LIMITS.coreName)

  return true
end

function PerfScan.running()
  return running
end

function PerfScan.cancel()
  if not running then
    return false
  end

  Bus.untick(LIMITS.timerId)

  running = false
  state = nil
  selfPiece = nil

  local done = onDoneFn

  onDoneFn = nil

  if done then
    pcall(done, nil, true)
  end

  return true
end

function PerfScan.result()
  return lastResult
end
