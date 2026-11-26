local Perf = EbonAPI.Perf
local Pieces = {}

EbonAPI.PerfPieces = Pieces

local MAX_DEPTH = 32
local EXTENSION_MAX = 48
local RETRY_EVERY = 4.95

local SCRIPT_TARGETS = {
  { "DragonUI.Nameplates.module.eventFrame", "OnEvent" },
  { "DragonUI.Nameplates.module.scannerFrame", "OnUpdate" },
  { "DragonUI.AuraCooldownsModule.frames.eventFrame", "OnEvent" },
  { "DragonUI_CombatQueueFrame", "OnEvent" },
  { "skillTreeFrame", "OnUpdate" },
  { "EbonholdSuperTrackPin.driver", "OnUpdate" },
  { "ProjectEbonholdPerkFrame", "OnUpdate" },
  { "ProjectEbonholdTrialHUD", "OnUpdate" },
  { "HardmodeFrame", "OnEvent" },
}

local FUNCTION_TARGETS = {
  "DragonUI.Nameplates.unitcache.OnCombatLog",
  "DragonUI.Nameplates.auras.HandleCombatLog",
  "DragonUI.Nameplates.auras.PruneCaches",
  "DragonUI.Nameplates.auras.DebuffRuntime.UpdateAuraCacheFromUnit",
  "DragonUI.Nameplates.tap.PruneCache",
  "DragonUI.Nameplates.layout.FlushPendingPlateLayout",
  "DragonUI.Nameplates.identity.FindUniquePlateForUnit",
  "DragonUI.CombatQueue.ProcessQueue",
  "DragonUI.SetupMainBarPageDriver",
  "ProjectEbonhold.SkillTree.UpdateTotalSoulPoints",
  "ProjectEbonhold.HardmodeUI.Refresh",
  "ProjectEbonhold.DeathRecap.Capture",
  "ProjectEbonhold.CallboardUI.Refresh",
  "ToolbeltService.Request",
  "ToolbeltService.GetSellPreview",
  "ToolbeltService.Sell",
  "ToolbeltService.Repair",
}

local EXTENSION_TABLES = {
  "DragonUI.Nameplates.unitcache",
  "DragonUI.Nameplates.auras",
  "DragonUI.Nameplates.tap",
  "DragonUI.Nameplates.layout",
  "DragonUI.Nameplates.castbar",
  "DragonUI.Nameplates.identity",
}

local function split(path)
  local parts, n = {}, 0

  for part in string.gmatch(path, "[^%.]+") do
    n = n + 1
    parts[n] = part
  end

  return parts, n
end

local function labelOf(parts, n)
  if n == 1 or (n == 2 and parts[1] == "DragonUI") then
    return parts[n]
  end

  return parts[n - 1] .. "." .. parts[n]
end

local targets, targetN = {}, 0

for i = 1, #SCRIPT_TARGETS do
  local parts, n = split(SCRIPT_TARGETS[i][1])

  targetN = targetN + 1
  targets[targetN] = { parts = parts, n = n, script = SCRIPT_TARGETS[i][2], label = labelOf(parts, n) }
end

for i = 1, #FUNCTION_TARGETS do
  local parts, n = split(FUNCTION_TARGETS[i])

  targetN = targetN + 1
  targets[targetN] = { parts = parts, n = n, label = labelOf(parts, n) }
end

local extTables = {}
local priorityCap = targetN
local extensionCap = math.min(EXTENSION_MAX, Perf.LIMITS.pieceWraps - priorityCap)

for i = 1, #EXTENSION_TABLES do
  local parts, n = split(EXTENSION_TABLES[i])

  extTables[i] = { parts = parts, n = n, name = parts[n] }
end

local clock = debugprofilestop
local records, recordN = {}, 0
local index = {}
local stats = {}
local touched, touchedN = {}, 0
local kids = {}
local depth = 0
local cost = 0
local lastTry = 0
local active = false
local scanPlaced = 0
local priorityN, extensionN = 0, 0

for i = 1, MAX_DEPTH do
  kids[i] = 0
end

local function step(node, key)
  return node[key]
end

local function walk(parts, n)
  local node = _G

  for i = 1, n do
    if type(node) ~= "table" then
      return nil
    end

    local ok, value = pcall(step, node, parts[i])

    if not ok then
      return nil
    end

    node = value
  end

  return node
end

local function leave(st, ev, c0, c1, ok, ...)
  local c2 = clock()
  local level = depth
  local net = c2 - c1 - kids[level]

  depth = level - 1
  net = net > 0 and net or 0
  st.calls, st.total, st.net = st.calls + 1, st.total + c2 - c1, st.net + net

  if ev then
    ev.calls, ev.total, ev.net = ev.calls + 1, ev.total + c2 - c1, ev.net + net
  end

  if not st.touched then
    st.touched = true
    touchedN = touchedN + 1
    touched[touchedN] = st
  end

  st.fc, st.fnet = st.fc + 1, st.fnet + net

  local c3 = clock()

  cost = cost + (c1 - c0) + (c3 - c2)

  if level > 1 then
    kids[level - 1] = kids[level - 1] + (c3 - c0)
  end

  if ok then
    return ...
  end

  error((...), 0)
end

local function makeFunction(orig, st)
  return function(...)
    if not active or depth >= MAX_DEPTH then
      return orig(...)
    end

    local c0 = clock()

    depth = depth + 1
    kids[depth] = 0

    local c1 = clock()

    return leave(st, nil, c0, c1, pcall(orig, ...))
  end
end

local function makeEvent(orig, st)
  local events = st.ev

  return function(self, event, ...)
    if not active or depth >= MAX_DEPTH then
      return orig(self, event, ...)
    end

    local c0 = clock()

    local ev = nil

    if event ~= nil then
      ev = events[event]

      if not ev then
        ev = { calls = 0, total = 0, net = 0 }
        events[event] = ev
      end
    end

    depth = depth + 1
    kids[depth] = 0

    local c1 = clock()

    return leave(st, ev, c0, c1, pcall(orig, self, event, ...))
  end
end

local function statFor(label, withEvents)
  local st = stats[label]

  if not st then
    st = { label = label, calls = 0, total = 0, net = 0, fc = 0, fnet = 0, touched = false, ev = withEvents and {} or nil }
    stats[label] = st
  end

  return st
end

local function record(owner, key, orig, wrapper, script, st)
  local byOwner = index[owner]

  if not byOwner then
    byOwner = {}
    index[owner] = byOwner
  end

  local rec = { owner = owner, key = key, orig = orig, wrapper = wrapper, script = script, st = st }

  byOwner[key] = rec
  recordN = recordN + 1
  records[recordN] = rec
end

local function placeFrame(owner, script, label)
  if type(owner) ~= "table" or type(owner.GetScript) ~= "function" or type(owner.SetScript) ~= "function"
    or type(owner.IsProtected) ~= "function" then
    return false
  end

  local byOwner = index[owner]

  if byOwner and byOwner[script] then
    return false
  end

  local okProt, protected = pcall(owner.IsProtected, owner)

  if not okProt or protected then
    return false
  end

  local okGet, orig = pcall(owner.GetScript, owner, script)

  if not okGet or type(orig) ~= "function" then
    return false
  end

  local st = statFor(label, script == "OnEvent")
  local wrapper = script == "OnEvent" and makeEvent(orig, st) or makeFunction(orig, st)

  if not pcall(owner.SetScript, owner, script, wrapper) then
    return false
  end

  record(owner, script, orig, wrapper, script, st)

  return true
end

local function placeField(owner, key, label)
  if type(owner) ~= "table" then
    return false
  end

  local byOwner = index[owner]

  if byOwner and byOwner[key] then
    return false
  end

  local orig = owner[key]

  if type(orig) ~= "function" then
    return false
  end

  local st = statFor(label, false)
  local wrapper = makeFunction(orig, st)

  owner[key] = wrapper
  record(owner, key, orig, wrapper, nil, st)

  return true
end

local function scanBody()
  local placed = 0

  for i = 1, targetN do
    if priorityN >= priorityCap then
      break
    end

    local target = targets[i]
    local done = false

    if target.script then
      done = placeFrame(walk(target.parts, target.n), target.script, target.label)
    else
      local owner = walk(target.parts, target.n - 1)

      done = placeField(owner, target.parts[target.n], target.label)
    end

    if done then
      priorityN = priorityN + 1
      placed = placed + 1
    end
  end

  for i = 1, #extTables do
    if extensionN >= extensionCap then
      break
    end

    local ext = extTables[i]
    local owner = walk(ext.parts, ext.n)

    if type(owner) == "table" then
      local keys, keyN = {}, 0

      for key, value in pairs(owner) do
        if type(key) == "string" and type(value) == "function" then
          keyN = keyN + 1
          keys[keyN] = key
        end
      end

      table.sort(keys)

      for j = 1, keyN do
        if extensionN >= extensionCap then
          break
        end

        if placeField(owner, keys[j], ext.name .. "." .. keys[j]) then
          extensionN = extensionN + 1
          placed = placed + 1
        end
      end
    end
  end

  scanPlaced = placed
end

local function scan()
  scanPlaced = 0
  pcall(scanBody)

  return scanPlaced
end

function Pieces.place()
  clock = debugprofilestop

  if recordN == 0 then
    for label in pairs(stats) do
      stats[label] = nil
    end

    for i = touchedN, 1, -1 do
      touched[i] = nil
    end

    touchedN, cost = 0, 0
  end

  active = true
  lastTry = GetTime()

  return scan()
end

function Pieces.retry()
  if not active or priorityN + extensionN >= priorityCap + extensionCap then
    return 0
  end

  local at = GetTime()

  if at - lastTry < RETRY_EVERY then
    return 0
  end

  lastTry = at

  return scan()
end

function Pieces.remove()
  for i = recordN, 1, -1 do
    local rec = records[i]

    if rec.script then
      if pcall(rec.owner.GetScript, rec.owner, rec.script) and rec.owner:GetScript(rec.script) == rec.wrapper then
        pcall(rec.owner.SetScript, rec.owner, rec.script, rec.orig)
      end
    elseif rec.owner[rec.key] == rec.wrapper then
      rec.owner[rec.key] = rec.orig
    end

    records[i] = nil
  end

  for owner in pairs(index) do
    index[owner] = nil
  end

  recordN, priorityN, extensionN, active = 0, 0, 0, false
end

function Pieces.placed()
  return recordN
end

function Pieces.depth()
  return depth
end

function Pieces.stats()
  return stats
end

function Pieces.takeCost()
  local taken = cost

  cost = 0

  return taken
end

function Pieces.frame()
  for i = touchedN, 1, -1 do
    local st = touched[i]

    st.touched, st.fc, st.fnet = false, 0, 0
    touched[i] = nil
  end

  touchedN = 0
end

function Pieces.top(limit)
  local out, count = {}, 0

  for i = 1, touchedN do
    local st = touched[i]

    if st.fnet > 0 or st.fc > 0 then
      count = count + 1
      out[count] = { label = st.label, calls = st.fc, net = st.fnet }
    end
  end

  table.sort(out, function(a, b)
    return a.net > b.net
  end)

  for i = count, limit + 1, -1 do
    out[i] = nil
  end

  return out
end
