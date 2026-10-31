EbonAPI = EbonAPI or {}
EbonAPI.PerfModel = {}

local PerfModel = EbonAPI.PerfModel
local L = EbonAPI.L

local type, ipairs, pairs = type, ipairs, pairs
local format, gsub = string.format, string.gsub
local abs, max, min = math.abs, math.max, math.min
local insert = table.insert

local LIMITS = {
  costlyRate = 1,
  memoryKB = 5120,
  kbPerMb = 1024,
  percentScale = 100,
  cpuWarn = 100,
  cpuBad = 300,
  cpuScale = 500,
  memWarnKB = 153600,
  memBadKB = 307200,
  fpsWarn = 30,
  fpsBad = 15,
  fpsScale = 60,
  places = { tileRate = 0, rate = 1, percent = 1, mem = 1, kb = 0, growth = 1, fps = 0, latency = 0 },
  separator = " · ",
  none = "\226\128\148",
  tipPieces = 5,
  fallbackSort = "memKB",
}

PerfModel.LIMITS = LIMITS

local num = EbonAPI.PerfData.num

local function decimal(value, places)
  return (gsub(format("%." .. places .. "f", value), "%.", L.NUMBER_DECIMAL))
end

local function dec(value, places)
  value = num(value)

  if value == nil then
    return LIMITS.none
  end

  return decimal(value, places)
end

local function memory(kb)
  kb = num(kb)

  if kb == nil then
    return LIMITS.none
  end

  if abs(kb) >= LIMITS.kbPerMb then
    return decimal(kb / LIMITS.kbPerMb, LIMITS.places.mem) .. " " .. L.PERFPAGE_UNIT_MB
  end

  return decimal(kb, LIMITS.places.kb) .. " " .. L.PERFPAGE_UNIT_KB
end

local function unit(value)
  return format("%s %s", value, L.PERFPAGE_UNIT_MS)
end

local function clamp(value)
  value = num(value)

  if value == nil then
    return nil
  end

  return max(0, min(1, value))
end

local function ratio(value, scale)
  value = num(value)

  if value == nil or not num(scale) or scale <= 0 then
    return nil
  end

  return clamp(value / scale)
end

local function levelHigh(value, warn, bad)
  value = num(value)

  if value == nil then
    return nil
  end

  if value >= bad then
    return "bad"
  end

  if value >= warn then
    return "warn"
  end

  return "ok"
end

local function levelLow(value, warn, bad)
  value = num(value)

  if value == nil then
    return nil
  end

  if value < bad then
    return "bad"
  end

  if value < warn then
    return "warn"
  end

  return "ok"
end

local function totalsOf(snapshot)
  local totals = type(snapshot) == "table" and snapshot.totals

  return type(totals) == "table" and totals or {}
end

local function rowsOf(snapshot)
  local list = type(snapshot) == "table" and snapshot.rows

  return type(list) == "table" and list or {}
end

local function profiling(snapshot)
  return type(snapshot) == "table" and snapshot.profiling == true
end

function PerfModel.tiles(snapshot)
  local totals = totalsOf(snapshot)
  local on = profiling(snapshot)
  local places = LIMITS.places
  local rate = on and num(totals.rate) or nil
  local peak = on and num(totals.peak) or nil
  local uiKB = num(totals.uiKB)
  local ownKB = num(totals.ownKB)
  local fps = type(snapshot) == "table" and num(snapshot.fps) or nil
  local latency = type(snapshot) == "table" and num(snapshot.latency) or nil

  return {
    {
      label = L.PERFPAGE_TILE_CPU_LABEL,
      value = rate and unit(decimal(rate, places.tileRate)) or LIMITS.none,
      sub = format(L.PERFPAGE_TILE_CPU_SUB, dec(peak, places.tileRate)),
      level = levelHigh(rate, LIMITS.cpuWarn, LIMITS.cpuBad),
      gauge = ratio(rate, LIMITS.cpuScale),
      accent = false,
      tip = L.PERFPAGE_TILE_CPU_TIP,
    },
    {
      label = L.PERFPAGE_TILE_MEM_LABEL,
      value = memory(uiKB),
      sub = format(L.PERFPAGE_TILE_MEM_SUB, memory(ownKB)),
      level = levelHigh(uiKB, LIMITS.memWarnKB, LIMITS.memBadKB),
      gauge = uiKB and uiKB > 0 and ratio(ownKB, uiKB) or nil,
      accent = false,
      tip = L.PERFPAGE_TILE_MEM_TIP,
    },
    {
      label = L.PERFPAGE_TILE_FPS_LABEL,
      value = dec(fps, places.fps),
      sub = format(L.PERFPAGE_TILE_FPS_SUB, dec(latency, places.latency)),
      level = levelLow(fps, LIMITS.fpsWarn, LIMITS.fpsBad),
      gauge = ratio(fps, LIMITS.fpsScale),
      accent = false,
      tip = L.PERFPAGE_TILE_FPS_TIP,
    },
  }
end

local function filterOptions()
  return { costlyRate = LIMITS.costlyRate, memoryKB = LIMITS.memoryKB }
end

local function maxima(list)
  local top = { rate = 0, memKB = 0 }

  for _, row in ipairs(list) do
    for field in pairs(top) do
      top[field] = max(top[field], abs(num(row[field]) or 0))
    end
  end

  return top
end

local function levelOf(row, on)
  if not on then
    return nil
  end

  return levelHigh(row.rate, LIMITS.cpuWarn, LIMITS.cpuBad)
end

local function leaves(list, into)
  for _, row in ipairs(list) do
    if type(row.children) == "table" and #row.children > 0 then
      leaves(row.children, into)
    elseif row.kind ~= "others" and row.kind ~= "piece" then
      insert(into, row)
    end
  end

  return into
end

local METRICS = {
  cpu = function(row)
    return num(row.rate)
  end,
  mem = function(row)
    return num(row.memKB)
  end,
  growth = function(row)
    return num(row.growth)
  end,
}

local function mapTip(metric, row)
  local places = LIMITS.places

  if metric == "mem" then
    return format(L.PERFPAGE_MAP_TIP_MEMORY, memory(row.memKB))
  end

  if metric == "growth" then
    return format(L.PERFPAGE_MAP_TIP_GROWTH, dec(row.growth, places.growth) .. " " .. L.PERFPAGE_COL_KBS)
  end

  local share = num(row.share)
  local text = format(L.PERFPAGE_MAP_TIP_CPU, dec(row.rate, places.rate),
    share and decimal(share * LIMITS.percentScale, places.percent) or LIMITS.none)

  if num(row.peak) then
    text = text .. LIMITS.separator .. format(L.PERFPAGE_MAP_TIP_PEAK, decimal(row.peak, places.rate))
  end

  local lines = {}

  for _, piece in ipairs(type(row.pieces) == "table" and row.pieces or {}) do
    if #lines >= LIMITS.tipPieces then
      break
    end

    if piece.kind ~= "rest" then
      lines[#lines + 1] = (piece.label or "") .. LIMITS.separator .. dec(piece.rate, places.rate) .. " "
        .. L.PERFPAGE_UNIT_MS
    end
  end

  if #lines > 0 then
    text = text .. "\n" .. L.PERFPAGE_MAP_TIP_PIECES .. "\n" .. table.concat(lines, "\n")
  end

  return text
end

function PerfModel.mapItems(snapshot, metric)
  local read = METRICS[metric] or METRICS.cpu
  local kind = METRICS[metric] and metric or "cpu"
  local flat = leaves(rowsOf(snapshot), {})
  local top = 0
  local items = {}

  for _, row in ipairs(flat) do
    local value = max(0, read(row) or 0)

    if not row.own then
      top = max(top, value)
    end

    insert(items, { row = row, value = value })
  end

  local out = {}

  for _, entry in ipairs(items) do
    local row = entry.row
    local item = {
      id = row.id,
      label = row.title or row.id,
      value = entry.value,
      tone = row.own and "accent" or "gray",
      tip = mapTip(kind, row),
    }

    if not row.own then
      item.heat = top > 0 and clamp(entry.value / top) or 0
    end

    insert(out, item)
  end

  return out
end

function PerfModel.pill(status)
  if type(status) == "table" and status.profiling == true then
    local clock = EbonAPI.PerfData.clock(status.elapsed) or EbonAPI.PerfData.clock(0)

    return { level = "ok", text = format(L.PERFPAGE_PILL_ON, clock), tip = L.PERFPAGE_PILL_TIP }
  end

  return { level = "warn", text = L.PERFPAGE_PILL_OFF, tip = L.PERFPAGE_PILL_TIP }
end

PerfModel.THRESHOLDS = {
  note = "PROVISOIRE, non mesuré : plafonds et seuils de couleur à régler après mesure",
  cpu = { ceiling = 300, warn = 100, bad = 300 },
  peak = { ceiling = 400, warn = 150, bad = 400 },
  memory = { ceiling = 204800, warn = 51200, bad = 153600 },
  kbs = { ceiling = 100, warn = 20, bad = 60 },
}

PerfModel.RANKING = { count = 10, detailSeries = 5, slices = 26, none = LIMITS.none }

PerfModel.durations = { 60, 300, 900, 1800 }

PerfModel.format = {
  decimal = decimal, dec = dec, memory = memory, unit = unit, clamp = clamp, ratio = ratio, levelHigh = levelHigh,
}

local function text(key)
  return L[key] or key
end

local function signed(value, places)
  value = num(value)

  if value == nil then
    return LIMITS.none
  end

  return (value > 0 and "+" or "") .. decimal(value, places)
end

local function historyOf(history)
  if type(history) == "table" then
    return history
  end

  local perf = EbonAPI.Perf

  if perf and type(perf.history) == "function" then
    local ok, value = pcall(perf.history)

    if ok and type(value) == "table" then
      return value
    end
  end

  return nil
end

local function allocationRate(snapshot)
  local total

  for _, row in ipairs(rowsOf(snapshot)) do
    if num(row.growth) then
      total = (total or 0) + row.growth
    end
  end

  return total
end

function PerfModel.dashboardTiles(snapshot, history)
  local old = PerfModel.tiles(snapshot)
  local totals = totalsOf(snapshot)
  local on = profiling(snapshot)
  local rate = on and num(totals.rate) or nil
  local peak = on and num(totals.peak) or nil
  local kbs = allocationRate(snapshot)
  local cpu = old[1]

  cpu.label = text("PERFPAGE_TILE_TIME_LABEL")

  return {
    cpu,
    {
      label = text("PERFPAGE_TILE_ALLOC_LABEL"),
      value = kbs ~= nil and (signed(kbs, LIMITS.places.growth) .. " " .. L.PERFPAGE_COL_KBS) or LIMITS.none,
      sub = text("PERFPAGE_TILE_ALLOC_SUB"),
      level = nil,
      gauge = nil,
      accent = true,
      tip = text("PERFPAGE_TILE_ALLOC_TIP"),
      rate = rate,
      peak = peak,
    },
    old[2],
    old[3],
  }
end

local function rankRow(row, on, top)
  local places = LIMITS.places
  local modules = type(row.children) == "table" and #row.children or 1

  return {
    key = row.id,
    name = row.title or row.id,
    cpu = row.rate,
    peak = row.peak,
    memory = row.memKB,
    kbs = row.growth,
    share = row.share,
    own = row.own,
    core = row.core,
    modules = modules,
    cpuText = on and dec(row.rate, places.rate) or LIMITS.none,
    peakText = on and row.peak ~= nil and dec(row.peak, places.rate) or LIMITS.none,
    memText = memory(row.memKB),
    kbsText = row.growth ~= nil and signed(row.growth, places.growth) or LIMITS.none,
    bar = on and top.rate > 0 and clamp(abs(num(row.rate) or 0) / top.rate)
      or (not on and top.memKB > 0 and clamp(abs(num(row.memKB) or 0) / top.memKB) or 0),
    level = levelOf(row, on),
    row = row,
  }
end

function PerfModel.ranking(snapshot, state)
  local data = EbonAPI.PerfData
  local on = profiling(snapshot)
  local list = data.filter(rowsOf(snapshot), state and state.filter or "all", state and state.query, filterOptions())

  list = data.sort(list, on and "rate" or LIMITS.fallbackSort, true)

  local count = state and num(state.count) or PerfModel.RANKING.count
  local top = maxima(list)
  local out = {}

  for index, row in ipairs(list) do
    if index > count then
      break
    end

    insert(out, rankRow(row, on, top))
  end

  local empty

  if #out == 0 then
    empty = #rowsOf(snapshot) == 0 and L.PERFPAGE_EMPTY_NODATA or L.PERFPAGE_EMPTY_FILTER
  end

  return out, empty
end

function PerfModel.defaultSelection(list, current)
  if type(list) ~= "table" then
    return nil
  end

  for _, item in ipairs(list) do
    if current ~= nil and item.key == current then
      return current
    end
  end

  return list[1] and list[1].key or nil
end

local function column(labelKey, value, threshold, shown)
  local level = levelHigh(value, threshold.warn, threshold.bad)

  return {
    labelKey = labelKey,
    label = text(labelKey),
    value = value or 0,
    ceiling = threshold.ceiling,
    text = shown,
    level = level,
    color = level and ("widgets.pill." .. level) or nil,
  }
end

function PerfModel.columnsFor(row)
  local t = PerfModel.THRESHOLDS
  local item = type(row) == "table" and row or {}
  local kbs = num(item.kbs)

  return {
    column("PERFPAGE_COLUMN_CPU", num(item.cpu), t.cpu, item.cpuText or dec(item.cpu, LIMITS.places.rate)),
    column("PERFPAGE_COL_PEAK", num(item.peak), t.peak, item.peakText or dec(item.peak, LIMITS.places.rate)),
    column("PERFPAGE_COL_MEM", num(item.memory), t.memory, item.memText or memory(item.memory)),
    column("PERFPAGE_COL_KBS", kbs and abs(kbs) or nil, t.kbs, item.kbsText or signed(kbs, LIMITS.places.growth)),
  }
end

local function findRow(list, key)
  for _, row in ipairs(list) do
    if row.id == key then
      return row
    end

    if type(row.children) == "table" then
      local found = findRow(row.children, key)

      if found then
        return found
      end
    end
  end
end

local function agoText(seconds)
  return format(text("PERFPAGE_DETAIL_AGO"), EbonAPI.PerfData.clock(seconds) or "0:00")
end

function PerfModel.detail(key, snapshot, history)
  local row = findRow(rowsOf(snapshot), key)

  if not row then
    return nil
  end

  history = historyOf(history)

  local cpu = history and type(history.cpu) == "table" and history.cpu or {}
  local step = history and num(history.step) or 5
  local members = {}

  if type(row.children) == "table" and #row.children > 0 then
    for _, child in ipairs(row.children) do
      insert(members, { folder = child.id, name = child.title or child.id, rate = num(child.rate) or 0 })
    end
  else
    insert(members, { folder = row.id, name = row.title or row.id, rate = num(row.rate) or 0 })
  end

  local function total(member)
    local sum = 0

    for _, value in ipairs(cpu[member.folder] or {}) do
      sum = sum + (num(value) or 0)
    end

    return sum
  end

  for _, member in ipairs(members) do
    member.sum = total(member)
  end

  table.sort(members, function(a, b)
    if (a.folder == key) ~= (b.folder == key) then
      return a.folder == key
    end

    if a.sum ~= b.sum then
      return a.sum > b.sum
    end

    return a.name < b.name
  end)

  local series = PerfModel.RANKING.detailSeries
  local modules = {}

  for index = 1, min(series, #members) do
    modules[index] = members[index].name
  end

  local count = history and num(history.count) or 0
  local first = max(1, count - PerfModel.RANKING.slices + 1)
  local slices, tips = {}, {}
  local unit = L.PERFPAGE_UNIT_MS

  for i = first, count do
    local slice, lines, sum = {}, {}, 0
    local rest = 0

    for index, member in ipairs(members) do
      local value = num(cpu[member.folder] and cpu[member.folder][i]) or 0

      if index <= series then
        insert(slice, { module = member.name, value = value })
        insert(lines, member.name .. LIMITS.separator .. dec(value, LIMITS.places.rate) .. " " .. unit)
      else
        rest = rest + value
      end

      sum = sum + value
    end

    if #members > series then
      insert(slice, { others = true, value = rest })
      insert(lines, text("PERFPAGE_DETAIL_OTHERS") .. LIMITS.separator .. dec(rest, LIMITS.places.rate) .. " " .. unit)
    end

    insert(slices, slice)
    insert(tips, { title = agoText((count - i) * step), body = table.concat(lines, "\n") })
  end

  local legend = {}

  for index, member in ipairs(members) do
    local series1 = cpu[member.folder]
    local last = series1 and num(series1[count]) or member.rate

    insert(legend, {
      module = member.name,
      folder = member.folder,
      cpu = last,
      cpuText = dec(last, LIMITS.places.rate) .. " " .. unit,
      colored = index <= series,
    })
  end

  return {
    key = key,
    title = row.title or row.id,
    data = {
      slices = slices,
      modules = modules,
      tips = tips,
      labels = #slices > 0 and { unit = unit, first = agoText((count - first) * step), last = text("PERFPAGE_DETAIL_NOW") }
        or nil,
    },
    legend = legend,
  }
end

function PerfModel.remainingText(seconds)
  if seconds == nil then
    local perf = EbonAPI.Perf

    if perf and type(perf.remaining) == "function" then
      local ok, value = pcall(perf.remaining)

      seconds = ok and value or nil
    end
  end

  seconds = num(seconds)

  if seconds == nil then
    return nil
  end

  return format(text("PERFPAGE_REMAINING"), EbonAPI.PerfData.clock(seconds) or "0:00")
end
