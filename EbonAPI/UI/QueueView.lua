EbonAPI = EbonAPI or {}
EbonAPI.QueueView = {}

local QueueView = EbonAPI.QueueView
local Kit = EbonAPI.Kit
local Queue = EbonAPI.Queue
local Share = EbonAPI.Share
local Bus = EbonAPI.Bus
local Handle = EbonAPI.Handle
local Palette = EbonAPI.Palette
local Bricks = EbonAPI.Bricks
local Skins = EbonAPI.Skins
local Lib = EbonAPI.Lib
local L = EbonAPI.L

local format, floor, ceil, min, max, concat = string.format, math.floor, math.ceil, math.min, math.max, table.concat
local ipairs, pcall, tostring, type, rawget = ipairs, pcall, tostring, type, rawget

local OWNER, ID, TICK = "EbonAPI", "queue", "EbonAPI:queueview"
local WIDTH = 1000
local BARS, BIN, PITCH = 100, 3, 3
local CHART_WIDTH, CHART_HEIGHT = 308, 60
local RATE_SCALE = 50

-- The window shows the send queue once a second: what it holds and for whom, how long each message
-- has waited, how fast it fills and empties, what left last and how the shared values are asked.
-- Everything is read from Queue.view, Queue.recent, Queue.history and Share.view; nothing moves.

local data = {
  snap = nil, rows = {}, lanes = {}, dests = {}, recent = {}, history = nil, fetch = nil, holders = {}, flights = {},
}

local win, tabs
local refreshed = {}
local frozen = false
local freezeButton

local function round1(value)
  return floor((value or 0) * 10 + 0.5) / 10
end

local function kindLabel(kind)
  return L["QUEUEVIEW_KIND_" .. tostring(kind)] or tostring(kind)
end

local function heldLabel(held, seconds)
  if not held then
    return ""
  end

  return format(L["QUEUEVIEW_HELD_" .. held] or held, seconds or 0)
end

local function ago(value)
  return value and round1(value) or ""
end

local function report(err)
  if Lib and Lib.report then
    Lib.report(err, OWNER)
  end
end

local function lineTotal()
  local snap = data.snap

  if not snap then
    return ""
  end

  return format(L.QUEUEVIEW_LINE_TOTAL, snap.total, snap.capacity, snap.whispers, snap.channel, snap.server, snap.parts)
end

local function lineRate()
  local snap = data.snap

  if not snap then
    return ""
  end

  local r = snap.rate

  return format(L.QUEUEVIEW_LINE_RATE, r.in10, r.out10, r.in10 - r.out10, r.in60, r.out60, r.in60 - r.out60)
end

local function lineWait()
  local snap = data.snap

  if not snap then
    return ""
  end

  local r = snap.rate

  return format(L.QUEUEVIEW_LINE_WAIT, r.wait10, r.peak10, r.wait60, r.peak60)
end

local function lineOldest()
  local snap = data.snap

  if not snap then
    return ""
  end

  return format(L.QUEUEVIEW_LINE_OLDEST, snap.oldest, snap.drain, 1 / snap.interval)
end

local function linePace()
  local interval = Queue.SEND_INTERVAL
  local rate = 1 / interval

  return format(L.QUEUEVIEW_PACE, format(rate == floor(rate) and "%d" or "%.1f", rate), floor(interval * 1000 + 0.5))
end

local function lineTotals()
  local snap = data.snap

  if not snap then
    return ""
  end

  return format(L.QUEUEVIEW_LINE_TOTALS, snap.sent.whisper, snap.sent.channel, snap.sent.server,
    snap.dropped.full, snap.dropped.offline, snap.dropped.failed)
end

local function lineFetch()
  local fetch = data.fetch

  if not fetch then
    return ""
  end

  return format(L.QUEUEVIEW_FETCH_LINE, fetch.live, fetch.window, fetch.perPeer, fetch.waiting, fetch.delayed,
    fetch.late, fetch.timeout)
end

local function buckets(list)
  local sum = 0

  for index = 1, #list do
    sum = sum + list[index]
  end

  if sum == 0 then
    return ""
  end

  local share = {}

  for index = 1, #list do
    share[index] = floor(list[index] * 100 / sum + 0.5)
  end

  return format(L.QUEUEVIEW_TIP_BUCKETS, share[1], share[2], share[3], share[4], share[5], share[6], share[7])
end

local function contentRows()
  local out = {}

  for index, row in ipairs(data.rows) do
    local parts = ""

    if row.parts and row.parts > 1 then
      parts = format("%d/%d", row.left, row.parts)
    end

    out[index] = {
      pos = row.pos, who = row.who, lane = row.lane, kind = kindLabel(row.kind), op = row.op, detail = row.detail,
      parts = parts, age = round1(row.age), eta = round1(row.eta), state = heldLabel(row.held, row.heldFor),
      tip = format("%s > %s: %s %s", row.lane, tostring(row.who), row.op, row.detail or ""),
    }
  end

  return out
end

local function recentRows()
  local out = {}

  for index, row in ipairs(data.recent) do
    out[index] = {
      ago = round1(row.ago), who = row.who, lane = row.lane, kind = kindLabel(row.kind), op = row.op,
      detail = row.detail, waited = round1(row.wait), result = row.ok and L.QUEUEVIEW_RESULT_OK or L.QUEUEVIEW_RESULT_FAILED,
    }
  end

  return out
end

local function destRows()
  local out = {}

  for index, row in ipairs(data.dests) do
    out[index] = {
      who = row.who, lane = row.lane, kind = kindLabel(row.kind), waiting = row.waiting, queued = row.queued,
      sent = row.sent, failed = row.failed, avg = round1(row.avg), max = round1(row.max), last = ago(row.last),
      state = heldLabel(row.held, row.heldFor),
    }
  end

  return out
end

local function laneRows()
  local out = {}

  for index, row in ipairs(data.lanes) do
    out[index] = {
      lane = row.lane, waiting = row.waiting, queued = row.queued, sent = row.sent, failed = row.failed,
      avg = round1(row.avg), max = round1(row.max), last = ago(row.last), tip = buckets(row.buckets),
    }
  end

  return out
end

local function holderRows()
  local out = {}

  for index, row in ipairs(data.holders) do
    out[index] = {
      peer = row.peer, inflight = row.inflight, keys = row.keys, answered = row.answered and L.QUEUEVIEW_YES or "",
      muted = row.muted and round1(row.muted) or "", slow = row.slow or "", limit = row.timeout,
      heard = ago(row.heard),
    }
  end

  return out
end

local function flightRows()
  local out = {}

  for index, row in ipairs(data.flights) do
    out[index] = {
      key = row.key, peer = row.peer, asked = row.queued and L.QUEUEVIEW_QUEUED or round1(row.age), limit = row.limit,
    }
  end

  return out
end

local function historyRows()
  local history = data.history
  local out = {}

  if not history then
    return out
  end

  for step = history.seconds, 1, -1 do
    out[#out + 1] = {
      time = step - history.seconds - 1, len = history.len[step], ins = history.ins[step], outs = history.outs[step],
      avg = round1(history.wait[step]), max = round1(history.peak[step]),
    }
  end

  return out
end

-- Three series, drawn five minutes back in bars of three seconds. The bars sit on the clock: the
-- seconds 0 to 2 of a group of three are always the same bar, so a bar is drawn once, when its
-- three seconds are over, and never changes afterwards; every three seconds the picture moves by
-- one bar. The scale is fixed, so a bar keeps its height. A value above the scale is drawn red, at
-- full height, and the real peak is written under the chart.
local SERIES = {
  { id = "len", field = "len", mode = "max", title = "QUEUEVIEW_CHART_LEN" },
  { id = "ins", field = "ins", mode = "mean", title = "QUEUEVIEW_CHART_IN" },
  { id = "outs", field = "outs", mode = "mean", title = "QUEUEVIEW_CHART_OUT", follow = true },
}

local views = {}

local LADDER = { 1, 2, 3, 5, 7, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100 }

-- What goes out belongs to the addon, so its scale follows what is really sent: never below the rate in
-- use nor below the highest bar in view, in the steps of LADDER. It rises at once and falls only when
-- the need is under 70% of the scale, which means the high bars have left the window: it does not jump
-- from second to second. Nothing goes red, the queue keeps its sends under its own rate.
local function followScale(serie, list)
  local need = 1 / Queue.SEND_INTERVAL

  for index = 1, list and #list or 0 do
    if list[index] > need then
      need = list[index]
    end
  end

  local want = need > LADDER[#LADDER] and ceil(need / 10) * 10 or LADDER[#LADDER]

  for _, step in ipairs(LADDER) do
    if step >= need - 0.001 then
      want = step

      break
    end
  end

  if not serie.scaled or want > serie.scaled or need < serie.scaled * 0.7 then
    serie.scaled = want
  end

  return serie.scaled
end

local function scaleOf(serie, list)
  if serie.field == "len" then
    return data.snap and data.snap.capacity or 500
  end

  if serie.follow then
    if list then
      return followScale(serie, list)
    end

    return serie.scaled or max(1, ceil(1 / Queue.SEND_INTERVAL - 0.001))
  end

  return RATE_SCALE
end

local function scaleText(serie)
  if serie.field == "len" then
    return format("0-%d", scaleOf(serie))
  end

  return format("0-%d/s", scaleOf(serie))
end

local function seriesBars(serie)
  local history = data.history

  if not history or not history.last then
    return nil
  end

  local last, seconds = history.last, history.seconds
  local newest = floor((last - BIN) / BIN)
  local cells = history[serie.field]
  local list = {}

  for index = 1, BARS do
    local bin = newest - BARS + index
    local sum, top = 0, 0

    for second = bin * BIN, bin * BIN + BIN - 1 do
      local step = second - last + seconds
      local value = step >= 1 and cells[step] or 0

      sum = sum + value

      if value > top then
        top = value
      end
    end

    list[index] = serie.mode == "max" and top or sum / BIN
  end

  return list, newest
end

local function seriesScale(serie)
  local history = data.history

  if not history or not history.last then
    return ""
  end

  local cells = history[serie.field]
  local last, seconds = history.last, history.seconds
  local top, current = 0, 0

  for second = (floor((last - BIN) / BIN) - BARS + 1) * BIN, last - 1 do
    local step = second - last + seconds
    local value = step >= 1 and cells[step] or 0

    if value > top then
      top = value
    end

    current = value
  end

  if serie.field == "len" and data.snap then
    current = data.snap.total
  end

  local function number(value)
    return serie.field == "len" and format("%d", value) or format("%.1f", value)
  end

  return format(L.QUEUEVIEW_CHART_SCALE, scaleText(serie), number(top), number(current), BIN)
end

local function inset()
  return (Skins.value("border.size") or 1) + 1
end

-- How far above its frame a bar may go: up to the title bar of the window, with a margin. A window
-- that is not laid out yet gives two heights of the chart.
local function roomAbove(frame)
  local top = frame:GetTop()
  local ceiling = win and (win.head and win.head:GetBottom() or win:GetTop())

  if top and ceiling and ceiling > top then
    return max(0, ceiling - top - 6)
  end

  return CHART_HEIGHT * 2
end

local TIPS, TIP_SPACE = 4, 9

-- A bar above the scale goes out of the frame to its real height, as far as the room allows; the
-- highest ones carry their real value, whatever the room, at most TIPS of them and TIP_SPACE bars apart.
local function drawTips(view, over, edge)
  table.sort(over, function(x, y)
    return x.value > y.value
  end)

  local used = 0
  local chosen = {}

  for _, spike in ipairs(over) do
    local clear = true

    for _, other in ipairs(chosen) do
      if math.abs(other.index - spike.index) < TIP_SPACE then
        clear = false
      end
    end

    if clear and used < TIPS then
      used = used + 1
      chosen[used] = spike
    end
  end

  for index = 1, TIPS do
    local tip = view.tips[index]

    if not tip then
      tip = Bricks.text(view.frame, "small", "danger")
      view.tips[index] = tip
    end

    local spike = chosen[index]

    if spike then
      tip:ClearAllPoints()
      tip:SetPoint("BOTTOM", view.frame, "BOTTOMLEFT", edge + (spike.index - 1) * PITCH + PITCH / 2,
        edge + spike.drawn + 1)
      tip:SetText(format("%.0f", spike.value))
      tip:Show()
    else
      tip:Hide()
    end
  end
end

local function drawSeries(view)
  local list, newest = seriesBars(view.serie)
  local top = scaleOf(view.serie, list)

  if not list or (view.drawn == newest and not view.dirty and view.scale == top) then
    return
  end

  view.drawn, view.dirty, view.scale = newest, false, top

  local frame, edge = view.frame, inset()
  local ceiling = view.serie.follow and math.huge or top
  local height = frame:GetHeight() - edge * 2
  local room = roomAbove(frame)
  local over = {}

  view.label:SetText(scaleText(view.serie))

  for index = 1, BARS do
    local bar = view.bars[index]

    if not bar then
      bar = frame:CreateTexture(nil, "ARTWORK")
      bar:SetTexture(Bricks.media("solid"))
      view.bars[index] = bar
    end

    local value = list[index]

    Palette.paint(bar, "SetVertexColor", value > ceiling and "danger" or (Skins.value("kit.chart.color") or "accent"))
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", edge + (index - 1) * PITCH, edge)
    bar:SetWidth(PITCH - 1)

    local shown = value > 0 and min(height * value / top, value > ceiling and height + room or height) or 0

    bar:SetHeight(max(1, shown))
    bar:Show()

    if value > ceiling then
      over[#over + 1] = { index = index, value = value, drawn = shown }
    end
  end

  drawTips(view, over, edge)
end

local function invalidate()
  for _, view in ipairs(views) do
    view.dirty = true
  end
end

local parts = {}
local focus, relayout, picked

local function guard(fn, ...)
  local ok, err = pcall(fn, ...)

  if not ok then
    report(err)
  end

  return ok
end

local function collect()
  data.snap, data.rows, data.lanes, data.dests = Queue.view()
  data.history = Queue.history(360)

  if Share and Share.view then
    data.fetch, data.holders, data.flights = Share.view()
  end
end

local function selectedTab()
  return tabs and tabs:Selected() or "content"
end

local PAINT = {
  content = { { "groups", function(piece) piece:SetRows(data.rows, data.snap) end } },
  recent = { { "activity", function(piece) piece:SetDests(data.dests) end } },
  people = { { "people", function(piece) piece:SetDests(data.dests) end } },
  lanes = { { "lanes", function(piece) piece:SetLanes(data.lanes) end } },
  fetch = {
    { "fetch", function(piece) piece:SetFetch(data.fetch, data.holders, data.flights) end },
    { "holders", function(piece) piece:SetHolders(data.holders) end },
  },
  history = { { "history", function(piece) piece:SetHistory(Queue.history(300)) end } },
}

local function refreshTab()
  for _, source in ipairs(PAINT[selectedTab()] or {}) do
    local piece = parts[source[1]]

    if piece then
      guard(source[2], piece)
    end
  end
end

local function fit(host, height)
  height = floor((height or 0) + 0.5)

  if host and height > 1 and host:GetHeight() ~= height then
    host:SetHeight(height)
    relayout = true
  end
end

local function refreshAll()
  if not win then
    return
  end

  for _, element in ipairs(refreshed) do
    guard(element.Refresh, element)
  end

  if parts.cells then
    guard(function()
      parts.cells:SetRows(data.rows, data.snap)
      fit(parts.rowHost, parts.cells:GetHeight())
    end)
  end

  if parts.band then
    guard(function()
      parts.band:Refresh(data.snap)

      if parts.cells and parts.band.height ~= parts.cells:GetHeight() then
        parts.band:SetHeight(parts.cells:GetHeight())
      end
    end)
  end

  for _, view in ipairs(views) do
    guard(drawSeries, view)
  end

  refreshTab()

  if relayout then
    relayout = false
    win:Layout()
  end
end

local function dump()
  local out = {}
  local function add(text)
    out[#out + 1] = text
  end

  collect()
  data.recent = Queue.recent(150)
  add(lineTotal())
  add(lineRate())
  add(lineWait())
  add(lineOldest())
  add(linePace())
  add(lineTotals())
  add("")
  add(L.QUEUEVIEW_TAB_CONTENT)

  for _, row in ipairs(contentRows()) do
    add(format("%s | %s | %s | %s | %s | %s | %s | %s | %s | %s", row.pos, tostring(row.who), row.lane, row.kind,
      row.op, row.detail or "", row.parts, row.age, row.eta, row.state))
  end

  add("")
  add(L.QUEUEVIEW_TAB_RECENT)

  for _, row in ipairs(recentRows()) do
    add(format("%s | %s | %s | %s | %s | %s | %s", row.ago, tostring(row.who), row.lane, row.kind, row.op,
      row.detail or "", row.waited .. " " .. row.result))
  end

  add("")
  add(L.QUEUEVIEW_TAB_PEOPLE)

  for _, row in ipairs(destRows()) do
    add(format("%s | %s | %s | waiting %s queued %s sent %s failed %s mean %s max %s last %s %s", tostring(row.who),
      row.lane, row.kind, row.waiting, row.queued, row.sent, row.failed, row.avg, row.max, row.last, row.state))
  end

  add("")
  add(L.QUEUEVIEW_TAB_LANES)

  for _, row in ipairs(laneRows()) do
    add(format("%s | waiting %s queued %s sent %s failed %s mean %s max %s last %s | %s", row.lane, row.waiting,
      row.queued, row.sent, row.failed, row.avg, row.max, row.last, row.tip))
  end

  add("")
  add(L.QUEUEVIEW_TAB_FETCH)
  add(lineFetch())

  for _, row in ipairs(holderRows()) do
    add(format("%s | in flight %s keys %s answered %s muted %s slow %s limit %s heard %s", tostring(row.peer),
      row.inflight, row.keys, row.answered, row.muted, row.slow, row.limit, row.heard))
  end

  for _, row in ipairs(flightRows()) do
    add(format("%s | %s | asked %s limit %s", row.key, tostring(row.peer), row.asked, row.limit))
  end

  add("")
  add(L.QUEUEVIEW_TAB_HISTORY)

  for _, row in ipairs(historyRows()) do
    add(format("%s s | length %s in %s out %s mean %s max %s", row.time, row.len, row.ins, row.outs, row.avg, row.max))
  end

  return concat(out, "\n")
end

local function copy(text)
  local clip = rawget(_G, "CopyToClipboard")

  if type(clip) == "function" then
    clip(text)
  else
    Handle.CopyBox({ addonName = OWNER }, text, L.QUEUEVIEW_TITLE)
  end
end

local function tick()
  if not win or not win:IsShown() then
    Bus.untick(TICK)

    return
  end

  if frozen then
    return
  end

  local ok, err = pcall(function()
    collect()
    refreshAll()
  end)

  if not ok then
    report(err)
  end
end

-- The tab body adapts to the screen: BODY_SHARE of the height of UIParent minus the fixed part of the window,
-- kept between BODY_MIN and BODY_MAX. CHROME is the title bar and the margins of the window.
local BODY_SHARE, BODY_MIN, BODY_MAX, SCREEN_FALLBACK = 0.92, 160, 270, 768
local CHART_BOX, CHROME, ROW_GAP = 112, 40, 7
local bodyHeight, fixedHeight = BODY_MAX, 0

local function skinNumber(key, default)
  local ok, result = pcall(Skins.value, key)

  return ok and type(result) == "number" and result or default
end

local function screenHeight()
  local ok, result = pcall(function()
    return UIParent:GetHeight()
  end)

  return ok and type(result) == "number" and result > 0 and result or SCREEN_FALLBACK
end

local function link(fid, who)
  if parts.cells then
    guard(parts.cells.SetHover, parts.cells, fid, who)
  end
end

local function setFocus(who)
  focus = who

  if parts.cells then
    guard(parts.cells.SetFocus, parts.cells, who)
  end
end

local function pick(who)
  picked = true

  if parts.cells and parts.cells.GetFocus then
    focus = parts.cells:GetFocus()
  end

  if who == nil or focus == who then
    setFocus(nil)

    return
  end

  setFocus(who)

  if tabs then
    tabs:Select("content")
  end

  refreshTab()

  if parts.groups then
    guard(parts.groups.Open, parts.groups, who, true)
  end
end

local function lightOn(info)
  if info and parts.groups then
    guard(parts.groups.Highlight, parts.groups, info.who, info.fid)
  end
end

local function lightOff()
  if parts.groups then
    guard(parts.groups.Highlight, parts.groups, nil)
  end
end

local function host(container, height)
  local frame = container:Add("chart", { width = WIDTH, height = height })

  Bricks.unframe(frame)

  return frame
end

local function place(piece, frame)
  local target = piece.Frame and piece:Frame() or piece

  target:ClearAllPoints()
  target:SetAllPoints(frame)
end

local function make(name, builder)
  local ok, result = pcall(builder)

  if ok then
    parts[name] = result
  else
    report(result)
  end
end

local function build()
  if win then
    return win
  end

  win = Kit.window(OWNER, ID, { key = "QUEUEVIEW_TITLE", point = { "CENTER" } })

  local legendHost = host(win, 1)

  make("legend", function()
    local legend = EbonAPI.QueueCells.legend(legendHost, {})

    legend:SetPoint("TOPLEFT", legendHost, "TOPLEFT", 0, 0)
    fit(legendHost, legend:GetHeight())

    return legend
  end)

  parts.rowHost = host(win, 1)
  make("cells", function()
    local cells = EbonAPI.QueueCells.build(parts.rowHost, {
      capacity = 500, onEnter = lightOn, onLeave = lightOff, onPick = pick,
    })

    cells:SetPoint("TOPLEFT", parts.rowHost, "TOPLEFT", 0, 0)
    fit(parts.rowHost, cells:GetHeight())

    if cells.zone then
      cells.zone:HookScript("OnMouseUp", function()
        if not picked then
          setFocus(nil)
        end

        picked = nil
      end)
    end

    return cells
  end)

  make("band", function()
    local band = EbonAPI.QueueBand.build(parts.rowHost, {})
    local left = (EbonAPI.QueueCells.WIDTH or 158) + ROW_GAP

    band.frame:SetPoint("TOPLEFT", parts.rowHost, "TOPLEFT", left, 0)
    band:SetWidth(WIDTH - left)

    if parts.cells then
      band:SetHeight(parts.cells:GetHeight())
    end

    return band
  end)

  -- The tab body, once: the screen's share minus what the rest of the window takes.
  local stripHeight, spacing = skinNumber("nav.tab.height", 24), skinNumber("kit.spacing", 6)
  local above = (parts.legend and parts.legend:GetHeight() or 0) + (parts.cells and parts.cells:GetHeight() or 0)

  fixedHeight = above + CHART_BOX + stripHeight + spacing * 5 + CHROME
  bodyHeight = min(BODY_MAX, max(BODY_MIN, floor(BODY_SHARE * screenHeight() - fixedHeight)))

  local charts = win:Add("bar", {})

  for _, serie in ipairs(SERIES) do
    local box = charts:Add("group", { key = serie.title, width = CHART_WIDTH + 20, height = 112 })
    local frame = box:Add("chart", { width = CHART_WIDTH, height = CHART_HEIGHT })
    local label = Bricks.text(frame, "small", "muted")
    local note = box:Add("status", {
      width = CHART_WIDTH,
      text = function()
        return seriesScale(serie)
      end,
    })

    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset() + 2), -(inset() + 1))
    views[#views + 1] = { serie = serie, frame = frame, label = label, bars = {}, tips = {}, dirty = true }
    refreshed[#refreshed + 1] = note
  end

  -- One host (no automatic layout) holds the tabs at its left and the three buttons at its right, on the same line.
  local stripHeight = skinNumber("nav.tab.height", 24)
  local line = win:Add("bar", {
    layout = "NONE", width = WIDTH, height = stripHeight + spacing + bodyHeight,
  })
  local buttons = line:Add("bar", {})

  buttons:Add("button", {
    key = "QUEUEVIEW_COPY",
    onClick = function()
      copy(dump())
    end,
  })
  buttons:Add("button", {
    key = "QUEUEVIEW_RESET",
    onClick = function()
      Queue.resetStats()
      invalidate()
      collect()
      refreshAll()
    end,
  })
  freezeButton = buttons:Add("button", {
    text = function()
      return frozen and L.QUEUEVIEW_UNFREEZE or L.QUEUEVIEW_FREEZE
    end,
    onClick = function(element)
      frozen = not frozen
      element:Refresh()
    end,
  })

  tabs = line:Add("tabs", {
    width = WIDTH, height = stripHeight + spacing + bodyHeight,
    onSelect = function()
      if data.snap then
        refreshTab()
      end
    end,
  })
  tabs:ClearAllPoints()
  tabs:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
  buttons:ClearAllPoints()
  buttons:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 0)
  buttons:SetFrameLevel(tabs:GetFrameLevel() + 5)

  for _, child in ipairs(buttons:Children()) do
    child:SetHeight(stripHeight)
  end

  local function onLane(lane)
    if parts.cells then
      guard(parts.cells.SetLane, parts.cells, lane)
    end
  end

  local function tab(id, key)
    return host(tabs:AddTab(id, { key = key }), bodyHeight)
  end

  local content = tab("content", "QUEUEVIEW_TAB_CONTENT")

  make("groups", function()
    local groups = EbonAPI.QueueGroups.build(content, {
      width = WIDTH, height = bodyHeight, onEnter = function(who, fid) link(fid, who) end,
      onLeave = function() link(nil, nil) end,
    })

    place(groups, content)

    return groups
  end)

  local recent = tab("recent", "QUEUEVIEW_TAB_RECENT")

  make("activity", function()
    local activity = EbonAPI.QueueStrips.activity(recent, {
      width = WIDTH, height = bodyHeight, onEnter = function(who) link(nil, who) end,
      onLeave = function() link(nil, nil) end, onLane = onLane,
    })

    place(activity, recent)

    return activity
  end)

  local people = tab("people", "QUEUEVIEW_TAB_PEOPLE")

  make("people", function()
    local registry = EbonAPI.QueueTable.people(people, {
      width = WIDTH, height = bodyHeight, onEnter = function(who) link(nil, who) end,
      onLeave = function() link(nil, nil) end, onLane = onLane,
    })

    place(registry, people)

    return registry
  end)

  local lanes = tab("lanes", "QUEUEVIEW_TAB_LANES")

  make("lanes", function()
    return EbonAPI.QueueCards.lanes(lanes, { width = WIDTH, height = bodyHeight })
  end)

  local fetch = tab("fetch", "QUEUEVIEW_TAB_FETCH")
  local slot = CreateFrame("Frame", nil, fetch)

  make("fetch", function()
    return EbonAPI.QueueCards.fetch(fetch, { width = WIDTH, height = bodyHeight, holdersSlot = slot })
  end)
  make("holders", function()
    local holders = EbonAPI.QueueTable.holders(slot, {
      width = WIDTH, height = bodyHeight, onEnter = function(peer) link(nil, peer) end,
      onLeave = function() link(nil, nil) end,
    })

    place(holders, slot)

    return holders
  end)

  local history = tab("history", "QUEUEVIEW_TAB_HISTORY")

  make("history", function()
    return EbonAPI.QueueStrips.history(history, { width = WIDTH, height = bodyHeight })
  end)

  return win
end

function QueueView.open()
  build()
  invalidate()
  win:Open()
  collect()
  refreshAll()
  Bus.tick(TICK, 1, tick)
end

function QueueView.window()
  return win
end

-- The built pieces by name (cells, band, groups, activity, people, lanes, fetch, holders, history), for the trials.
function QueueView.piece(name)
  return parts[name]
end

function QueueView.series(id)
  for _, serie in ipairs(SERIES) do
    if serie.id == id then
      return seriesBars(serie)
    end
  end
end

function QueueView.heights(id)
  for _, view in ipairs(views) do
    if view.serie.id == id then
      local list = {}

      for index, bar in ipairs(view.bars) do
        list[index] = bar:GetHeight()
      end

      return list
    end
  end
end

function QueueView.tips(id)
  for _, view in ipairs(views) do
    if view.serie.id == id then
      local list = {}

      for _, tip in ipairs(view.tips) do
        if tip:IsShown() then
          list[#list + 1] = tip:GetText()
        end
      end

      return list
    end
  end
end

function QueueView.geometry()
  return { body = bodyHeight, fixed = fixedHeight, bandWidth = WIDTH - (EbonAPI.QueueCells.WIDTH or 158) - ROW_GAP,
    bars = BARS, bin = BIN, pitch = PITCH, width = CHART_WIDTH, height = CHART_HEIGHT, inset = inset(), rate = RATE_SCALE, out = scaleOf(SERIES[3]) }
end

function QueueView.select(id)
  if tabs and PAINT[id] then
    tabs:Select(id)
  end
end

function QueueView.last()
  return data.snap
end

function QueueView.isFrozen()
  return frozen
end

function QueueView.freeze(state)
  frozen = state and true or false

  if freezeButton then
    freezeButton:Refresh()
  end
end

function QueueView.text()
  return dump()
end
