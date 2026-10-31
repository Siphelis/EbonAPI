EbonAPI = EbonAPI or {}
EbonAPI.PerfData = {}

local PerfData = EbonAPI.PerfData

local type, tostring, tonumber, pairs, ipairs = type, tostring, tonumber, pairs, ipairs
local lower, find, format, floor = string.lower, string.find, string.format, math.floor
local tsort = table.sort

local DEFAULT_COSTLY_RATE = 1
local DEFAULT_MEMORY_KB = 5120
local SUMMED = { "ms", "rate", "share", "memKB", "growth", "peak" }

local function num(v)
  if type(v) == "number" and v == v then
    return v
  end

  return nil
end

PerfData.num = num

local function key(text)
  return lower(tostring(text or ""))
end

local function sumField(list, field)
  local total

  for i = 1, #list do
    local v = num(list[i][field])

    if v then
      total = (total or 0) + v
    end
  end

  return total
end

local function copyRow(row)
  local out = {}

  for k, v in pairs(row) do
    out[k] = v
  end

  return out
end

local function leafCount(row)
  return num(row.count) or 1
end

local function parentOf(row, byKey, deps, attach)
  local id = row.id
  local declared = attach and attach[id]

  if declared and byKey[key(declared)] and key(declared) ~= key(id) then
    return key(declared)
  end

  local list = deps and deps[id]

  if type(list) ~= "table" then
    return nil
  end

  for i = 1, #list do
    local dep = key(list[i])

    if dep ~= key(id) and byKey[dep] then
      return dep
    end
  end

  return nil
end

local function clear(t)
  for k in pairs(t) do
    t[k] = nil
  end
end

-- Scratch tables reused by every call (never returned nor kept).
local walkBuf, seenBuf = {}, {}
local groupByKey, groupOrder, groupParents, groupMembers, groupTops = {}, {}, {}, {}, {}

local function cutCycles(parents, order)
  local walk, seen = walkBuf, seenBuf

  for i = 1, #order do
    clear(walk)
    clear(seen)

    local at = order[i]

    while at and not seen[at] do
      seen[at] = #walk + 1
      walk[#walk + 1] = at
      at = parents[at]
    end

    if at then
      local first = at

      for j = seen[at], #walk do
        if walk[j] < first then
          first = walk[j]
        end
      end

      parents[first] = nil
    end
  end
end

local function rootOf(id, parents)
  local at = id

  local up = parents[at]

  while up do
    at = up
    up = parents[at]
  end

  return at
end

function PerfData.group(rows, deps, attach)
  local out = {}

  if type(rows) ~= "table" then
    return out
  end

  local byKey, order, parents = groupByKey, groupOrder, groupParents

  clear(byKey)
  clear(order)
  clear(parents)

  for i = 1, #rows do
    local k = key(rows[i].id)

    if not byKey[k] then
      byKey[k] = rows[i]
      order[#order + 1] = k
    end
  end

  for i = 1, #order do
    parents[order[i]] = parentOf(byKey[order[i]], byKey, deps, attach)
  end

  cutCycles(parents, order)

  local members, tops = groupMembers, groupTops

  clear(members)
  clear(tops)

  for i = 1, #order do
    local k = order[i]
    local root = rootOf(k, parents)

    if root == k then
      tops[#tops + 1] = k
      members[k] = members[k] or {}
    else
      members[root] = members[root] or {}
      members[root][#members[root] + 1] = byKey[k]
    end
  end

  for i = 1, #tops do
    local k = tops[i]
    local row = byKey[k]
    local kids = members[k]

    if #kids == 0 then
      local single = copyRow(row)

      single.kind = single.kind or "addon"
      single.count = single.count or 1
      out[#out + 1] = single
    else
      local core = copyRow(row)

      core.kind = "addon"
      core.core = true
      core.count = core.count or 1

      local children = { core }

      for j = 1, #kids do
        local child = copyRow(kids[j])

        child.kind = child.kind or "addon"
        child.core = false
        child.count = child.count or 1
        children[#children + 1] = child
      end

      local own = false

      for j = 1, #children do
        if children[j].own then
          own = true
        end
      end

      local parent = {
        id = row.id,
        title = row.title,
        kind = "group",
        core = false,
        own = own,
        count = #children,
        children = children,
      }

      for j = 1, #SUMMED do
        parent[SUMMED[j]] = sumField(children, SUMMED[j])
      end

      out[#out + 1] = parent
    end
  end

  return out
end

local function byCost(field)
  return function(a, b)
    local va, vb = num(a.row[field]) or -1, num(b.row[field]) or -1

    if va ~= vb then
      return va > vb
    end

    return a.index < b.index
  end
end

function PerfData.aggregate(rows, opts)
  local out = {}

  if type(rows) ~= "table" then
    return out
  end

  opts = opts or {}

  local keep = floor(num(opts.keep) or #rows)
  local by = opts.by or "ms"
  local pin = opts.pin or "own"
  local ranked = {}

  for i = 1, #rows do
    ranked[i] = { row = rows[i], index = i }
  end

  tsort(ranked, byCost(by))

  local chosen = {}

  for i = 1, #ranked do
    if i <= keep or ranked[i].row[pin] then
      chosen[ranked[i].index] = true
    end
  end

  local rest = {}

  for i = 1, #rows do
    if chosen[i] then
      out[#out + 1] = rows[i]
    else
      rest[#rest + 1] = rows[i]
    end
  end

  if #rest > 0 then
    local others = {
      id = "others",
      kind = "others",
      core = false,
      own = false,
      peak = nil,
      children = {},
      count = 0,
    }

    for i = 1, #rest do
      others.count = others.count + leafCount(rest[i])
    end

    for j = 1, #SUMMED do
      if SUMMED[j] ~= "peak" then
        others[SUMMED[j]] = sumField(rest, SUMMED[j])
      end
    end

    out[#out + 1] = others
  end

  return out
end

local function sortValue(row, field)
  if field == "title" then
    return key(row.title or row.id)
  end

  return num(row[field])
end

local function before(field, descending)
  return function(a, b)
    local va, vb = sortValue(a.row, field), sortValue(b.row, field)

    if va ~= vb then
      if va == nil then
        return false
      end

      if vb == nil then
        return true
      end

      if descending then
        return va > vb
      end

      return va < vb
    end

    return a.index < b.index
  end
end

local function sortList(rows, field, descending)
  local ranked, tail = {}, {}

  for i = 1, #rows do
    if rows[i].kind == "others" then
      tail[#tail + 1] = rows[i]
    else
      ranked[#ranked + 1] = { row = rows[i], index = i }
    end
  end

  tsort(ranked, before(field, descending))

  local out = {}

  for i = 1, #ranked do
    local row = ranked[i].row

    if type(row.children) == "table" and #row.children > 0 then
      row = copyRow(row)
      row.children = sortList(row.children, field, descending)
    end

    out[#out + 1] = row
  end

  for i = 1, #tail do
    out[#out + 1] = tail[i]
  end

  return out
end

function PerfData.sort(rows, field, descending)
  if type(rows) ~= "table" then
    return {}
  end

  local out = sortList(rows, field or "ms", descending and true or false)
  local core

  for i = 1, #out do
    local children = out[i].children

    if out[i].kind == "group" and type(children) == "table" then
      core = nil

      for j = 1, #children do
        if children[j].core then
          core = j
        end
      end

      if core and core > 1 then
        local copy = copyRow(out[i])
        local list = { children[core] }

        for j = 1, #children do
          if j ~= core then
            list[#list + 1] = children[j]
          end
        end

        copy.children = list
        out[i] = copy
      end
    end
  end

  return out
end

local function passes(row, mode, costlyRate, memoryKB)
  if mode == "own" then
    return row.own and true or false
  end

  if mode == "costly" then
    return (num(row.rate) or 0) >= costlyRate
  end

  if mode == "memory" then
    return (num(row.memKB) or 0) >= memoryKB
  end

  return true
end

local function matches(row, query)
  if query == "" then
    return true
  end

  return find(key(row.title), query, 1, true) ~= nil or find(key(row.id), query, 1, true) ~= nil
end

function PerfData.filter(rows, mode, query, opts)
  local out = {}

  if type(rows) ~= "table" then
    return out
  end

  opts = opts or {}

  local costlyRate = num(opts.costlyRate) or DEFAULT_COSTLY_RATE
  local memoryKB = num(opts.memoryKB) or DEFAULT_MEMORY_KB
  local text = key(query)

  for i = 1, #rows do
    local row = rows[i]

    if row.kind ~= "others" then
      local children = row.children

      if type(children) == "table" and #children > 0 then
        local whole = matches(row, text)
        local kept = {}

        for j = 1, #children do
          local child = children[j]

          if passes(child, mode, costlyRate, memoryKB) and (whole or matches(child, text)) then
            kept[#kept + 1] = child
          end
        end

        if #kept > 0 then
          if #kept == #children then
            out[#out + 1] = row
          else
            local copy = copyRow(row)

            copy.children = kept
            out[#out + 1] = copy
          end
        end
      elseif passes(row, mode, costlyRate, memoryKB) and matches(row, text) then
        out[#out + 1] = row
      end
    end
  end

  return out
end

function PerfData.fold(last, current, dt, peaks)
  local nextLast, nextPeaks = {}, {}

  if type(peaks) == "table" then
    for id, v in pairs(peaks) do
      nextPeaks[id] = v
    end
  end

  if type(current) ~= "table" then
    return nextLast, nextPeaks
  end

  last = type(last) == "table" and last or {}
  dt = num(dt) or 0

  for id, ms in pairs(current) do
    ms = num(ms)

    if ms then
      local before = num(last[id])

      nextLast[id] = ms

      if before and ms >= before and dt > 0 then
        local rate = (ms - before) / dt

        if rate > (nextPeaks[id] or 0) or nextPeaks[id] == nil then
          nextPeaks[id] = rate
        end
      end
    end
  end

  return nextLast, nextPeaks
end

function PerfData.clock(seconds)
  seconds = num(seconds)

  if not seconds then
    return nil
  end

  if seconds < 0 then
    seconds = 0
  end

  seconds = floor(seconds)

  return format("%d:%02d", floor(seconds / 60), seconds % 60)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Compact storage of a recorded session (field "rec" of a perfRuns entry; fmt=2, an entry without "rec" is the old
-- format and has no recording).
--
-- Rule: one STRING per series, never a table per sample or per addon-sample (a nested table costs about 40 bytes of
-- memory and one "-- [n]" line in the SavedVariables file). All numbers are integers: CPU in tenths of ms (0.1 ms),
-- heap and memory in tenths of KB, times in ms.
--
-- Encoding of an integer list ("varint text"): each value is zigzag-mapped (0,-1,1,-2.. -> 0,1,2,3..), cut in groups
-- of 5 bits, least significant group first; one character per group from the 64-character alphabet
-- 0-9 A-Z a-z - _ (value 0..63); bit 32 of a character value means "another group follows". So 0 = "0", 1..15 and
-- -1..-16 take one character, up to +-511 two characters. "delta text" = the values written as differences to the
-- previous value (first against 0); "plain text" = the values as they are. No separator (the number of values is
-- stored: rec.count, memCount, #names). Decoding in any language: read characters, acc += (c & 31) * 32^k while
-- c >= 32, then z = acc + c * 32^k, value = z even and z / 2 or -(z + 1) / 2, then add to the running sum (delta).
-- Why not decimal with commas: ~2 characters per 0.5 s sample instead of ~4, and an idle sample costs one character;
-- why not a binary string: SavedVariables strings must stay plain printable text.
-- rec = {
--   fmt = 2,
--   count = N,              number of samples (every 0.5 s, LIMITS.recordEvery)
--   at = "...",             N values, ms since the first sample (delta of the delta: change of the step between samples)
--   heap = "...",           N values, Lua heap in tenths of KB (delta text)
--   total = "...",          N values, CUMULATIVE CPU of all recorded addons, tenths of ms (delta text)
--   names = "A|B|C",        addon FOLDERS of the session, "|" separated (index a = position, 1-based)
--   sum = "...",            per addon a: CPU spent over the session (last - first cumulative), tenths of ms (plain text)
--   peak = "...",           per addon a: largest CPU spent in ONE 0.5 s interval, tenths of ms (plain text)
--   active = "...",         per addon a: number of intervals with CPU > 0 (plain text)
--   series = { [folder] = "..." }   FULL series, only for "EbonAPI", "EbonAPI-*" and the K = PerfData.FULL_TOP
--                           heaviest other addons (by sum): N values, cumulative CPU in tenths of ms (delta text)
--   memCount = M, memAt = "...",    M memory reads (start, every LIMITS.memoryEvery s, end): ms since sample 1 (delta text)
--   mem = "...",            plain text of M * n values: row m (read m), addon a (order of names) at position
--                           (m-1)*n+a = DIFFERENCE in tenths of KB against the same addon in the previous read (first
--                           read against 0). Memory of a read = running sum down the reads.
--   dropped = d,            ticks lost beyond the buffer (only if > 0)
-- }
-- ---------------------------------------------------------------------------------------------------------------

-- K: how many of the heaviest non-EbonAPI addons keep a full 0.5 s series (the others keep sum, peak, active count).
PerfData.FULL_TOP = 10
PerfData.REC_FORMAT = 2

local concat = table.concat

local function tenths(v)
  v = num(v) or 0

  return floor(v * 10 + 0.5)
end

local function isOwn(folder)
  return folder == "EbonAPI" or string.sub(folder, 1, 8) == "EbonAPI-"
end

local ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local CHAR_OF, VALUE_OF = {}, {}

for i = 1, 64 do
  local c = string.sub(ALPHABET, i, i)

  CHAR_OF[i - 1], VALUE_OF[c] = c, i - 1
end

-- appends one signed integer: zigzag (0,-1,1,-2.. -> 0,1,2,3..) then groups of 5 bits, least significant first, one
-- character per group (bit 32 of the character value = "another group follows")
local function put(out, v)
  local z = v >= 0 and v * 2 or -v * 2 - 1

  repeat
    local low = z % 32

    z = (z - low) / 32
    out[#out + 1] = CHAR_OF[z > 0 and low + 32 or low]
  until z == 0
end

-- list of integers -> text. delta (default true): each value is written as the difference to the previous one
-- (first against 0); false: values as they are. See the format in the header.
function PerfData.encodeInts(list, count, delta)
  local out, prev = {}, 0

  for i = 1, count or #list do
    local v = list[i] or prev

    put(out, delta == false and v or v - prev)
    prev = v
  end

  return concat(out)
end

-- text -> list of count integers (same delta flag as the encoder)
function PerfData.decodeInts(text, count, delta)
  local out, prev, i, acc, scale = {}, 0, 0, 0, 1

  for k = 1, #(text or "") do
    local c = VALUE_OF[string.sub(text, k, k)] or 0

    if c >= 32 then
      acc, scale = acc + (c - 32) * scale, scale * 32
    else
      local z = acc + c * scale
      local v = z % 2 == 0 and z / 2 or -(z + 1) / 2

      i = i + 1
      prev = delta == false and v or prev + v
      out[i] = prev
      acc, scale = 0, 1
    end
  end

  for j = i + 1, count or 0 do
    out[j] = prev
  end

  while count and #out > count do
    out[#out] = nil
  end

  return out
end

-- The sample times are written as the change of the step between two samples (steady 0.5 s steps give small values)
local function secondDiff(list, count)
  local out, prev = {}, 0

  for i = 1, count do
    local v = list[i] or 0

    out[i], prev = v - prev, v
  end

  return out
end

local function secondSum(deltas, count)
  local out, sum = {}, 0

  for i = 1, count do
    sum = sum + (deltas[i] or 0)
    out[i] = sum
  end

  return out
end

local function plainList(list, count)
  return PerfData.encodeInts(list, count, false)
end

local function plainDecode(text, count)
  return PerfData.decodeInts(text, count, false)
end

-- Encodes the recording buffers (EbonAPI.Perf.recording()) into the "rec" record described above. Returns nil
-- when there is nothing recorded. opts.top overrides K (tests).
function PerfData.encodeRecording(buf, opts)
  local n, count = buf and buf.n or 0, buf and buf.count or 0

  if n < 1 or count < 1 then
    return nil
  end

  local top = opts and opts.top or PerfData.FULL_TOP
  local cpu, at, heap, folders = buf.cpu, buf.at, buf.heap, buf.folder
  local atMs, heapT, totalT = {}, {}, {}
  local sums, peaks, actives, cums = {}, {}, {}, {}

  for s = 1, count do
    atMs[s] = floor((at[s] - at[1]) * 1000 + 0.5)
    heapT[s] = tenths(heap[s])
    totalT[s] = 0
  end

  for a = 1, n do
    local cum, prev, peak, active = {}, nil, 0, 0

    for s = 1, count do
      local v = tenths(cpu[(s - 1) * n + a])

      cum[s] = v
      totalT[s] = totalT[s] + v

      if prev then
        local d = v - prev

        if d > peak then
          peak = d
        end

        if d > 0 then
          active = active + 1
        end
      end

      prev = v
    end

    cums[a], sums[a], peaks[a], actives[a] = cum, cum[count] - cum[1], peak, active
  end

  local rank = {}

  for a = 1, n do
    if not isOwn(folders[a]) then
      rank[#rank + 1] = a
    end
  end

  tsort(rank, function(x, y)
    if sums[x] ~= sums[y] then
      return sums[x] > sums[y]
    end

    return folders[x] < folders[y]
  end)

  local series = {}

  for a = 1, n do
    if isOwn(folders[a]) then
      series[folders[a]] = PerfData.encodeInts(cums[a], count)
    end
  end

  for r = 1, math.min(top, #rank) do
    series[folders[rank[r]]] = PerfData.encodeInts(cums[rank[r]], count)
  end

  local memCount = buf.memCount or 0
  local memAt, rows, prevRow = {}, {}, {}

  for m = 1, memCount do
    local row = {}

    memAt[m] = floor((buf.memAt[m] - at[1]) * 1000 + 0.5)

    for a = 1, n do
      local v = tenths(buf.mem[(m - 1) * n + a])

      row[a] = v - (prevRow[a] or 0)
      prevRow[a] = v
    end

    rows[m] = plainList(row, n)
  end

  local names = {}

  for a = 1, n do
    names[a] = folders[a]
  end

  return {
    fmt = PerfData.REC_FORMAT,
    count = count,
    at = PerfData.encodeInts(secondDiff(atMs, count), count),
    heap = PerfData.encodeInts(heapT, count),
    total = PerfData.encodeInts(totalT, count),
    names = concat(names, "|"),
    sum = plainList(sums, n),
    peak = plainList(peaks, n),
    active = plainList(actives, n),
    series = series,
    memCount = memCount,
    memAt = PerfData.encodeInts(memAt, memCount),
    mem = concat(rows),
    dropped = (buf.dropped or 0) > 0 and buf.dropped or nil,
  }
end

-- Decodes a "rec" record. Returns nil for the old format (no rec / other fmt). Result (all numbers are real units):
--   count, at[s] (seconds since sample 1), heap[s] (KB), total[s] (cumulative ms), names[a], sum[a] / peak[a] (ms),
--   active[a], series[folder][s] (cumulative ms; per-interval ms = difference), memAt[m] (s), mem[folder][m] (KB),
--   full[folder] = true when a full series exists.
function PerfData.decodeRecording(rec)
  if type(rec) ~= "table" or rec.fmt ~= PerfData.REC_FORMAT then
    return nil
  end

  local count = rec.count or 0
  local out = { count = count, at = {}, heap = {}, total = {}, names = {}, sum = {}, peak = {}, active = {},
    series = {}, full = {}, memAt = {}, mem = {}, dropped = rec.dropped or 0 }
  local atMs = secondSum(PerfData.decodeInts(rec.at, count), count)
  local heapT = PerfData.decodeInts(rec.heap, count)
  local totalT = PerfData.decodeInts(rec.total, count)

  for s = 1, count do
    out.at[s], out.heap[s], out.total[s] = atMs[s] / 1000, heapT[s] / 10, totalT[s] / 10
  end

  for name in string.gmatch((rec.names or "") .. "|", "([^|]*)|") do
    out.names[#out.names + 1] = name
  end

  local nn = #out.names
  local sum, peak, active = plainDecode(rec.sum, nn), plainDecode(rec.peak, nn), plainDecode(rec.active, nn)

  for a = 1, #out.names do
    out.sum[a], out.peak[a], out.active[a] = (sum[a] or 0) / 10, (peak[a] or 0) / 10, active[a] or 0
  end

  for folder, text in pairs(rec.series or {}) do
    local t = PerfData.decodeInts(text, count)

    for s = 1, count do
      t[s] = t[s] / 10
    end

    out.series[folder], out.full[folder] = t, true
  end

  local memCount, n = rec.memCount or 0, #out.names
  local memAtMs = PerfData.decodeInts(rec.memAt, memCount)
  local prev = {}

  for a = 1, n do
    out.mem[out.names[a]] = {}
    prev[a] = 0
  end

  for m2 = 1, memCount do
    out.memAt[m2] = memAtMs[m2] / 1000
  end

  local steps = plainDecode(rec.mem, memCount * n)

  for m = 1, memCount do
    for a = 1, n do
      prev[a] = prev[a] + (steps[(m - 1) * n + a] or 0)
      out.mem[out.names[a]][m] = prev[a] / 10
    end
  end

  return out
end

-- Compact storage of the table of a finished session (fields "rc" = rows, "ua" = unattributed pieces of a perfRuns
-- entry; they replace the tables rows / unattributed / history, which cost one Lua table per line). Text only.
--   rc: lines separated by ";", fields by "|". Title empty = the client's own (GetAddOnInfo, read when the page decodes). Line = kind|id|title|own|ms|memKB|growth|peak|growthPeak|msRaw|pieces
--   kind: "a" lone addon, "G<n>" group followed by its n children lines, "c" core addon of a group, "k" other child.
--   Integers: ms, peak, msRaw, memKB in 0.1 (ms or KB); growth, growthPeak in 0.01 KB/s; empty field = nil.
--   rate and share are not stored: rate = ms / window, share = ms / totals.ms (window and totals are in the entry).
--   pieces: "," separated; piece = kind:ms:calls:count:label with ms in 0.01 ms (label last: it may contain ":").
--   A label holds raw text plus codes "~code", translated when the page decodes (see PerfData.PIECE_CODES), so no
--   translated text is ever stored: ~rest ~scanning ~instrument ~refresh ~channel ~channelOther.
PerfData.PIECE_CODES = {
  rest = "PERFPAGE_PIECE_REST", scanning = "PERFPAGE_RUN_SCANNING", instrument = "PERFPAGE_PIECE_INSTRUMENT",
  refresh = "PERFPAGE_PIECE_REFRESH", channel = "PERFPAGE_PIECE_CHANNEL", channelOther = "PERFPAGE_PIECE_CHANNEL_OTHER",
}

local function clean(text)
  return (string.gsub(tostring(text or ""), "[;|,\r\n]", " "))
end

local function scaled(v, unit)
  v = num(v)

  return v and format("%d", floor(v * unit + 0.5)) or ""
end

-- Title of an addon as the table shows it (colour codes removed), read from the client: a stored line keeps its title
-- only when it differs from this one, so the usual line stores none.
local function addonTitle(id)
  local _, title = GetAddOnInfo(id)

  if type(title) ~= "string" or title == "" then
    return id
  end

  return (string.gsub(string.gsub(title, "|c%x%x%x%x%x%x%x%x", ""), "|r", ""))
end

local function encodePieces(list)
  local out = {}

  for i = 1, #(list or {}) do
    local p = list[i]

    out[i] = format("%s:%s:%d:%d:%s", clean(p.kind), scaled(p.ms, 100) == "" and "0" or scaled(p.ms, 100),
      p.calls or 0, p.count or 1, clean(p.label))
  end

  return table.concat(out, ",")
end

local function encodeRow(row, kind, out)
  local group = type(row.children) == "table" and #row.children > 0

  out[#out + 1] = table.concat({
    group and ("G" .. #row.children) or kind, clean(row.id),
    (row.title == nil or row.title == addonTitle(row.id)) and "" or clean(row.title), row.own and "1" or "0",
    scaled(row.ms, 10), scaled(row.memKB, 10), scaled(row.growth, 100), scaled(row.peak, 10),
    scaled(row.growthPeak, 100), scaled(row.msRaw, 10), encodePieces(row.pieces),
  }, "|")

  if group then
    for i = 1, #row.children do
      encodeRow(row.children[i], row.children[i].core and "c" or "k", out)
    end
  end
end

function PerfData.encodeRows(rows)
  local out = {}

  for i = 1, #(rows or {}) do
    encodeRow(rows[i], "a", out)
  end

  return table.concat(out, ";")
end

function PerfData.encodePieces(list)
  return encodePieces(list)
end

local function label(raw)
  local L = EbonAPI.L or {}

  return (string.gsub(raw, "~(%a+)", function(code)
    local name = PerfData.PIECE_CODES[code]

    return name and L[name] or ("~" .. code)
  end))
end

local function unit(text, divisor)
  local v = tonumber(text)

  return v and v / divisor or nil
end

local function decodePieces(text, window)
  local out = {}

  for item in string.gmatch(text or "", "[^,]+") do
    local kind, ms, calls, count, raw = string.match(item, "^([^:]*):([^:]*):([^:]*):([^:]*):(.*)$")

    if kind then
      local v = (tonumber(ms) or 0) / 100

      out[#out + 1] = { label = label(raw), kind = kind, ms = v, calls = tonumber(calls) or 0, count = tonumber(count) or 1,
        rate = (window > 0 and (v > 0 or kind ~= "rest")) and v / window or nil }
    end
  end

  return out
end

-- Decodes the row at lines[at]; returns the row and the number of lines it took (itself plus its children).
local function decodeRow(lines, at, window, totalMs)
  local f = {}

  for field in string.gmatch(lines[at] .. "|", "([^|]*)|") do
    f[#f + 1] = field
  end

  local ms = unit(f[5], 10)
  local row = { id = f[2], title = f[3] ~= "" and f[3] or addonTitle(f[2]), own = f[4] == "1", ms = ms, memKB = unit(f[6], 10), growth = unit(f[7], 100),
    peak = unit(f[8], 10), growthPeak = unit(f[9], 100), msRaw = unit(f[10], 10), kind = "addon", core = f[1] == "c",
    count = 1, rate = (ms and window > 0) and ms / window or nil,
    share = ms and (totalMs > 0 and ms / totalMs or 0) or nil }
  local pieces = decodePieces(f[11], window)
  local size = 1

  if #pieces > 0 then
    row.pieces = pieces
  end

  local kids = tonumber(string.match(f[1], "^G(%d+)$"))

  if kids then
    row.kind, row.count, row.children = "group", kids, {}

    for _ = 1, kids do
      local child, span = decodeRow(lines, at + size, window, totalMs)

      row.children[#row.children + 1] = child
      size = size + span
    end
  end

  return row, size
end

function PerfData.decodeRows(text, window, totalMs)
  local lines = {}

  for line in string.gmatch(text or "", "[^;]+") do
    lines[#lines + 1] = line
  end

  local out, at = {}, 1

  while at <= #lines do
    local row, size = decodeRow(lines, at, window or 0, totalMs or 0)

    out[#out + 1] = row
    at = at + size
  end

  return out
end

function PerfData.decodePieces(text, window)
  return decodePieces(text, window or 0)
end

-- Rows of an entry of perfRuns, decoded only when asked (the page, for the session it shows). An entry that still holds
-- a rows table is returned as is. The result is cached per entry (weak keys: freed with the entry).
local decoded = setmetatable({}, { __mode = "k" })

local function cached(entry, name, build)
  if type(entry) ~= "table" then
    return nil
  end

  decoded[entry] = decoded[entry] or {}

  if decoded[entry][name] == nil then
    decoded[entry][name] = build() or false
  end

  return decoded[entry][name] or nil
end

function PerfData.entryRows(entry)
  if type(entry) == "table" and type(entry.rows) == "table" then
    return entry.rows
  end

  return cached(entry, "rows", function()
    if type(entry.rc) ~= "string" then
      return nil
    end

    local totals = type(entry.totals) == "table" and entry.totals or {}

    return PerfData.decodeRows(entry.rc, (entry.win or 0) / 1000, totals.ms or 0)
  end)
end

function PerfData.entryUnattributed(entry)
  if type(entry) == "table" and type(entry.unattributed) == "table" then
    return entry.unattributed
  end

  return cached(entry, "ua", function()
    return type(entry.ua) == "string" and PerfData.decodePieces(entry.ua, (entry.win or 0) / 1000) or nil
  end)
end

-- History of a stored session for the graphs, rebuilt from "rec" (nothing else is stored): the last
-- slices of "step" seconds, same shape as Perf.history (kbs, cpu, mem, rate; per folder, oldest first). cpu exists for
-- the folders with a full series (EbonAPI, EbonAPI-* and the biggest ones); the others read as no data.
function PerfData.entryHistory(entry, step, slices)
  if type(entry) == "table" and type(entry.history) == "table" then
    return entry.history
  end

  return cached(entry, "history", function()
    local rec = PerfData.decodeRecording(entry.rec)

    if not rec or rec.count < 2 then
      return nil
    end

    local function at(list, times, t)
      local best = 1

      for i = 1, #times do
        if times[i] <= t + 1e-9 then
          best = i
        else
          break
        end
      end

      return list[best] or 0
    end

    local last = rec.at[rec.count]
    local count = math.min(slices, math.max(1, floor(last / step)))
    local out = { step = step, count = count, kbs = {}, cpu = {}, mem = {}, rate = {} }

    for folder in pairs(rec.series) do
      out.cpu[folder] = {}
    end

    for folder in pairs(rec.mem) do
      out.mem[folder], out.rate[folder] = {}, {}
    end

    for i = 1, count do
      local te = last - (count - i) * step
      local tb = te - step

      out.kbs[i] = (at(rec.heap, rec.at, te) - at(rec.heap, rec.at, tb)) / step

      for folder, series in pairs(rec.series) do
        out.cpu[folder][i] = math.max(0, at(series, rec.at, te) - at(series, rec.at, tb)) / step
      end

      for folder, series in pairs(rec.mem) do
        local now = at(series, rec.memAt, te)

        out.mem[folder][i] = now
        out.rate[folder][i] = (now - at(series, rec.memAt, tb)) / step
      end
    end

    return out
  end)
end

