EbonAPI = EbonAPI or {}
EbonAPI.PerfPage = {}

local PerfPage = EbonAPI.PerfPage

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local ipairs, pairs, pcall, setmetatable, type = ipairs, pairs, pcall, setmetatable, type

local OWNER = EbonAPI.name

PerfPage.LIMITS = {
  progressEvery = 1,
  maxRows = 16,
  minRows = 4,
  mapHeight = 260,
  panelWidth = 180,
  panelGap = 16,
  panelRows = 8,
  defaultDuration = 300,
  nameWidth = 92,
  valueWidth = 56,
  secondsPerMinute = 60,
  progressTicker = "perf.page.progress",
  dataTicker = "perf.page.data",
}
PerfPage.builders = {}
PerfPage.instances = setmetatable({}, { __mode = "k" })

local function S(key)
  return EbonAPI.Bricks.value(key)
end

local function limit(name)
  local model = EbonAPI.PerfModel and EbonAPI.PerfModel.LIMITS

  if model and model[name] ~= nil then
    return model[name]
  end

  return PerfPage.LIMITS[name]
end

local function viewItems()
  local L = EbonAPI.L

  return {
    { id = "dashboard", text = L.PERFPAGE_VIEW_DASHBOARD },
    { id = "map", text = L.PERFPAGE_VIEW_MAP },
    { id = "freezes", text = L.PERFPAGE_VIEW_FREEZES },
  }
end

local function makeZone(root, state)
  local zone = CreateFrame("Frame", nil, root)

  zone.contentHeight = 0
  zone:SetHeight(zone.contentHeight)

  function zone:SetContentHeight(height)
    self.contentHeight = height
    self:SetHeight(height)
    PerfPage.relayout(root)
  end

  return zone
end

function PerfPage.relayout(root)
  local state = root.perf
  local width = state.width
  local gap = S("kit.gap")
  local tileWidth = floor((width - gap * (#state.tiles - 1)) / #state.tiles)
  local y = 0

  local row = max(state.selector:GetHeight(), state.pill:GetHeight())

  state.selector:ClearAllPoints()
  state.selector:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)
  state.pill:ClearAllPoints()
  state.pill:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, -y)
  y = y + row + gap

  local tilesHeight = 0

  for index, tile in ipairs(state.tiles) do
    tile:SetWidth(tileWidth)
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", root, "TOPLEFT", (index - 1) * (tileWidth + gap), -y)
    tilesHeight = max(tilesHeight, tile:GetHeight())
  end

  y = y + tilesHeight + gap

  local zones = state.zones
  local shown = state.detail and zones.detail or zones[state.view]

  for name, zone in pairs(zones) do
    if name ~= "footer" then
      zone:SetWidth(width)
      zone:ClearAllPoints()
      zone:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)

      if zone == shown then
        zone:Show()
      else
        zone:Hide()
      end
    end
  end

  y = y + shown.contentHeight + gap

  zones.footer:SetWidth(width)
  zones.footer:ClearAllPoints()
  zones.footer:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)
  zones.footer:Show()
  y = y + zones.footer.contentHeight

  root:SetWidth(width)
  root:SetHeight(y)

  return y
end

function PerfPage.setView(root, view)
  local state = root.perf

  if not state.zones[view] or view == "footer" then
    return false
  end

  state.view = view
  state.selector:SetValue(view)

  if view == "map" then
    state.detail = nil
  end

  if state.drawMap then
    state.drawMap()
  end

  if state.drawBoard then
    state.drawBoard()
  end

  if state.drawFreezes then
    state.drawFreezes()
  end

  PerfPage.relayout(root)

  return true
end

function PerfPage.view(last)
  if type(last) ~= "table" then
    return nil
  end

  local fps, latency

  if type(GetFramerate) == "function" then
    fps = GetFramerate()
  end

  if type(GetNetStats) == "function" then
    local _, _, ping = GetNetStats()

    latency = ping
  end

  local profiling = last.profiling

  if profiling == nil then
    profiling = true
  end

  return {
    at = last.at,
    window = last.duration or last.window,
    profiling = profiling,
    fps = fps,
    latency = latency,
    totals = last.totals,
    rows = EbonAPI.PerfData.entryRows(last),
    unattributed = EbonAPI.PerfData.entryUnattributed(last),
    stats = last.stats,
    freezes = EbonAPI.PerfData.entryFreezes(last),
    freezeInfo = last.fz,
    pieceStats = EbonAPI.PerfData.entryPieceStats(last),
  }
end

-- Show the "turn the profiler on" button only while the profiler is off (3.3.5 has no SetShown).
function PerfPage.showEnable(state, status)
  if status.profiling then
    state.enableButton:Hide()
  else
    state.enableButton:Show()
  end
end

function PerfPage.update(root, snapshot)
  local state = root.perf
  local model = EbonAPI.PerfModel
  local items = model.dashboardTiles(snapshot)

  for index, tile in ipairs(state.tiles) do
    tile:SetItem(items[index])
  end

  local status = EbonAPI.Perf.status()
  local pill = model.pill(status)

  state.pill:SetState(pill.level, pill.text)
  PerfPage.showEnable(state, status)
  state.snapshot = snapshot
  state.stale.board = true

  for _, callback in ipairs(state.onTick) do
    callback(snapshot, state, root)
  end
end

function PerfPage.refresh(root, fresh)
  local ok, live = pcall(EbonAPI.Perf.snapshot, { memory = true, freshMemory = fresh })

  if not ok then
    live = nil
  end

  PerfPage.update(root, PerfPage.view(live))
  PerfPage.status(root)

  return root.perf.snapshot
end

local function runInfo()
  local ok, run = pcall(EbonAPI.Perf.run)

  return ok and type(run) == "table" and run or { state = "idle" }
end

local function active(run)
  return run.state == "running" or run.state == "scanning"
end

function PerfPage.status(root)
  local state = root.perf
  local L = EbonAPI.L
  local run = runInfo()
  local text = ""

  if run.state == "running" then
    local clock = EbonAPI.PerfData.clock
    local total = (run.duration or 0)

    text = format(L.PERFPAGE_RUN_PROGRESS, clock(run.elapsed or 0) or "", clock(total) or "")
  elseif run.state == "scanning" then
    text = L.PERFPAGE_RUN_SCANNING
  end

  if state.statusText then
    state.statusText:SetText(text)
  end

  if state.recording then
    local left = run.state == "running" and EbonAPI.PerfModel.remainingText() or nil

    if left then
      state.recording:SetState("bad", left)
      state.recording:Show()
      state.recordingDot:Show()
    else
      state.recording:Hide()
      state.recordingDot:Hide()
    end
  end

  if state.scanToggle and active(run) and (run.scan and true or false) ~= state.scan then
    state.scan = run.scan and true or false
    state.scanToggle:SetValue(state.scan)
  end

  local status = EbonAPI.Perf.status()
  local permanent = status.profiling == true and run.profilerByAddon ~= true and not active(run)

  if state.permanent then
    if permanent then
      state.permanent:Show()
      state.profilerOff:Show()
    else
      state.permanent:Hide()
      state.profilerOff:Hide()
    end
  end

  return run
end

local function askRestore(run)
  if active(run) or not EbonAPI.Perf.restorePending() then
    PerfPage.asked = nil

    return
  end

  if PerfPage.asked then
    return
  end

  PerfPage.asked = true

  EbonAPI.Kit.openDialog({
    owner = OWNER,
    text = EbonAPI.L.PERFPAGE_PROFILER_RESTORE,
    accept = EbonAPI.L.UI_YES,
    cancel = EbonAPI.L.UI_NO,
    onAccept = function()
      EbonAPI.Perf.disableProfiler()
    end,
  })
end

function PerfPage.pill(root)
  local status = EbonAPI.Perf.status()
  local pill = EbonAPI.PerfModel.pill(status)

  root.perf.pill:SetState(pill.level, pill.text)
  PerfPage.showEnable(root.perf, status)
end

-- One second: progress line, pill clock, and the final redraw when a session ends.
function PerfPage.progress()
  local run = nil

  for _, root in pairs(PerfPage.instances) do
    if root:IsVisible() then
      local state = root.perf
      local previous = state.runState

      run = PerfPage.status(root)
      state.runState = run.state

      if previous ~= nil and previous ~= run.state and not active(run) then
        PerfPage.refresh(root)
      else
        PerfPage.pill(root)
      end
    end
  end

  if run then
    askRestore(run)
  else
    PerfPage.sync()
  end
end

-- Live data: cumulated values since the last reset, at the sampling pace.
function PerfPage.data()
  for _, root in pairs(PerfPage.instances) do
    if root:IsVisible() then
      PerfPage.refresh(root)
    end
  end
end

-- Both tickers and the watch exist only while a page is shown.
function PerfPage.sync()
  local wanted = false

  for _, root in pairs(PerfPage.instances) do
    if root:IsVisible() then
      local run = PerfPage.status(root)

      root.perf.runState = run.state
      wanted = true
    end
  end

  if wanted then
    EbonAPI.Bus.tick(limit("progressTicker"), limit("progressEvery"), PerfPage.progress, OWNER)
    EbonAPI.Bus.tick(limit("dataTicker"), EbonAPI.Perf.LIMITS.liveEvery, PerfPage.data, OWNER)

    if not PerfPage.watching then
      PerfPage.watching = true
      EbonAPI.Perf.watch(true, OWNER)
    end
  else
    EbonAPI.Bus.untick(limit("progressTicker"))
    EbonAPI.Bus.untick(limit("dataTicker"))

    if PerfPage.watching then
      PerfPage.watching = false
      EbonAPI.Perf.watch(false, OWNER)
    end
  end
end

function PerfPage.shown(root)
  PerfPage.sync()
  PerfPage.refresh(root, true)
  PerfPage.asked = nil
  askRestore(runInfo())
end

function PerfPage.build(parent, width)
  local existing = PerfPage.instances[parent]

  if existing then
    existing.perf.width = width
    PerfPage.relayout(existing)

    return existing
  end

  local Kit = EbonAPI.Kit
  local model = EbonAPI.PerfModel
  local root = CreateFrame("Frame", nil, parent)
  local pillState = model.pill(EbonAPI.Perf.status())
  local state = {
    view = "dashboard",
    width = width,
    runState = nil,
    tiles = {},
    zones = {},
    onTick = {},
    -- Views recalculated only while displayed: stale[view] is set by new data, cleared by the recalculation;
    -- recalcs[view] counts them (essay).
    stale = {},
    recalcs = { board = 0, detail = 0, map = 0 },
  }

  root.perf = state
  PerfPage.instances[parent] = root

  state.selector = Kit.create(OWNER, "choice", root, {
    shape = "segment",
    items = viewItems(),
    value = state.view,
    onChange = function(id)
      PerfPage.setView(root, id)
    end,
  })

  state.pill = Kit.create(OWNER, "pill", root, {
    level = pillState.level,
    text = pillState.text,
    tip = pillState.tip,
  })

  local items = model.dashboardTiles(nil)

  for index = 1, #items do
    local item = items[index]

    state.tiles[index] = Kit.create(OWNER, "tile", root, {
      label = item.label,
      value = item.value,
      sub = item.sub,
      level = item.level,
      gauge = item.gauge,
      accent = item.accent,
      tip = item.tip,
    })
  end

  state.zones.dashboard = makeZone(root, state)
  state.zones.map = makeZone(root, state)
  state.zones.freezes = makeZone(root, state)
  state.zones.detail = makeZone(root, state)
  state.zones.footer = makeZone(root, state)

  root:SetScript("OnShow", function(self)
    PerfPage.shown(self)
  end)

  root:SetScript("OnHide", function()
    PerfPage.sync()
  end)

  for _, builder in ipairs(PerfPage.builders) do
    builder(root, state)
  end

  PerfPage.relayout(root)

  if root:IsVisible() then
    PerfPage.shown(root)
  end

  return root
end

local function levelColor(row)
  local level = row.level

  if level == nil or level == "ok" then
    return nil
  end

  return S("widgets.pill." .. level)
end

-- Ranking: addon name, proportional track, value of the current tab (CPU / Memory / Growth).
local function boardSpecs()
  local L = EbonAPI.L

  return {
    { id = "title", text = L.PERFPAGE_COL_ADDON, width = limit("nameWidth") },
    { id = "track", text = "", bar = "bar", sort = false },
    { id = "value", text = "", width = limit("valueWidth"), align = "RIGHT", color = levelColor },
  }
end

-- Opens the detail of an addon (M3 view, built by buildDetail): remembers the key and refreshes the page.
function PerfPage.openDetail(key, root)
  if root == nil then
    for _, instance in pairs(PerfPage.instances) do
      root = instance

      break
    end
  end

  if root == nil or key == nil then
    return false
  end

  root.perf.detail = key
  PerfPage.refresh(root)
  PerfPage.relayout(root)

  return true
end

-- Back from the detail to the dashboard: the selection is kept.
function PerfPage.closeDetail(root)
  if root == nil then
    for _, instance in pairs(PerfPage.instances) do
      root = instance

      break
    end
  end

  if root == nil or root.perf.detail == nil then
    return false
  end

  root.perf.detail = nil

  if root.perf.drawBoard then
    root.perf.drawBoard()
  end

  PerfPage.relayout(root)

  return true
end

local function resolved(columns)
  for _, column in ipairs(columns) do
    if type(column.color) == "string" then
      column.color = S(column.color)
    end
  end

  return columns
end

local RAW = { cpu = "rate", mem = "memKB", growth = "growth" }
local TEXT = { cpu = "cpuText", mem = "memText", growth = "kbsText" }

-- Share (0..1) of each entry against the largest absolute value of the list, for the raw value `entry.raw`.
local function shares(entries)
  local top = 0

  for _, entry in ipairs(entries) do
    top = max(top, entry.raw and math.abs(entry.raw) or 0)
  end

  for _, entry in ipairs(entries) do
    entry.share = top > 0 and entry.raw and min(1, math.abs(entry.raw) / top) or 0
  end

  return entries
end

-- Dashboard zone: the ranking (10 addons, name + track + value) on the left, the panel of the selected addon on the
-- right (chart of its 4 fixed columns, its name, its modules as name + track + value).
local function buildBoard(root, state)
  local Kit, Bricks, L = EbonAPI.Kit, EbonAPI.Bricks, EbonAPI.L
  local model = EbonAPI.PerfModel
  local F = model.format
  local zone = state.zones.dashboard
  local gap = S("kit.gap")
  local rowHeight = S("kit.table.row")
  local barHeight = S("kit.table.bar.height")
  local grid, chart, message, panelName
  local panelRows = {}
  local items = {}

  local function metric()
    return RAW[state.mapTab] and state.mapTab or "cpu"
  end

  local function gridWidth()
    return max(1, state.width - limit("panelWidth") - limit("panelGap"))
  end

  local function panelRow(index)
    local row = panelRows[index]

    if not row then
      row = {
        name = Bricks.text(zone, "small", "text"),
        track = Kit.create(OWNER, "progress", zone, { height = barHeight }),
        value = Bricks.text(zone, "small", "muted"),
      }
      row.name:SetJustifyH("LEFT")
      row.value:SetJustifyH("RIGHT")
      panelRows[index] = row
    end

    return row
  end

  -- Modules of the selected addon for the current tab: { name, text, share } sorted by value, at most panelRows.
  local function modulesOf(item)
    local on = state.snapshot and state.snapshot.profiling == true
    local kind = metric()
    local source = item and type(item.row.children) == "table" and #item.row.children > 0 and item.row.children
      or { item and item.row }
    local list = {}

    for _, child in ipairs(source) do
      local raw = tonumber(child[RAW[kind]])

      if kind == "cpu" and not on then
        raw = nil
      end

      list[#list + 1] = { name = child.title or child.id, raw = raw }
    end

    table.sort(list, function(a, b)
      return (a.raw or 0) > (b.raw or 0)
    end)

    for index = #list, limit("panelRows") + 1, -1 do
      list[index] = nil
    end

    for _, entry in ipairs(list) do
      local raw = entry.raw

      if raw == nil then
        entry.text = F.dec(nil, 0)
      elseif kind == "cpu" then
        entry.text = F.dec(raw, limit("places").rate)
      elseif kind == "mem" then
        entry.text = F.memory(raw)
      else
        entry.text = (raw > 0 and "+" or "") .. F.dec(raw, limit("places").growth)
      end
    end

    return shares(list)
  end

  local function fit()
    local count = min(max(#grid:Sorted(), limit("minRows")), limit("maxRows"))
    local height = (count + 1) * rowHeight + S("border.size")
    local panel, panelX = limit("panelWidth"), gridWidth() + limit("panelGap")

    if grid:GetHeight() ~= height then
      grid:SetHeight(height)
    end

    grid:ClearAllPoints()
    grid:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, 0)

    if grid:GetWidth() ~= gridWidth() then
      grid:SetWidth(gridWidth())
    end

    chart:ClearAllPoints()
    chart:SetPoint("TOPLEFT", zone, "TOPLEFT", panelX, 0)

    if chart:GetWidth() ~= panel then
      chart:SetWidth(panel)
    end

    local y = chart:GetHeight() + gap

    panelName:ClearAllPoints()
    panelName:SetPoint("TOPLEFT", zone, "TOPLEFT", panelX, -y)
    y = y + panelName:GetHeight() + gap

    local entries = modulesOf(items[state.selected])

    for index, entry in ipairs(entries) do
      local row = panelRow(index)
      local mid = -(y + (index - 1) * rowHeight + rowHeight / 2)

      row.name:ClearAllPoints()
      row.name:SetPoint("LEFT", zone, "TOPLEFT", panelX + 4, mid)
      row.name:SetWidth(limit("nameWidth"))
      row.name:SetText(entry.name)
      row.track:SetWidth(max(1, panel - 140))
      row.track:ClearAllPoints()
      row.track:SetPoint("LEFT", zone, "TOPLEFT", panelX + 100, mid)
      row.track:SetValue(entry.share, 1)
      row.value:ClearAllPoints()
      row.value:SetPoint("LEFT", zone, "TOPLEFT", panelX + panel - 36, mid)
      row.value:SetWidth(32)
      row.value:SetText(entry.text)
      row.name:Show()
      row.track:Show()
      row.value:Show()
    end

    for index = #entries + 1, #panelRows do
      panelRows[index].name:Hide()
      panelRows[index].track:Hide()
      panelRows[index].value:Hide()
    end

    local total = max(height, y + #entries * rowHeight)

    if zone.contentHeight ~= total then
      zone:SetContentHeight(total)
    end
  end

  local function drawChart()
    local item = items[state.selected]

    chart:SetColumns(item and resolved(model.columnsFor(item)) or {})
    panelName:SetText(item and item.name or "")
  end

  local function select(key)
    state.selected = key

    for _, data in ipairs(grid:Sorted()) do
      if data.id == key then
        grid.selected = data
      end
    end

    grid:kitDraw()
    drawChart()
  end

  local function refresh()
    state.stale.board = false
    state.recalcs.board = state.recalcs.board + 1

    local list, empty = model.ranking(state.snapshot, state)
    local rows = {}
    local kind = metric()
    local entries = {}

    items = {}

    for index, item in ipairs(list) do
      items[item.key] = item
      entries[index] = { raw = tonumber(item.row[RAW[kind]]) }

      if kind == "cpu" and not (state.snapshot and state.snapshot.profiling == true) then
        entries[index].raw = nil
      end
    end

    shares(entries)

    for index, item in ipairs(list) do
      rows[index] = {
        id = item.key,
        title = item.name,
        value = item[TEXT[kind]],
        bar = entries[index].share,
        level = kind == "cpu" and item.level or nil,
      }
    end

    grid:SetRows(rows)
    state.selected = model.defaultSelection(list, state.selected)
    select(state.selected)

    if empty then
      message:SetText(empty)
      message:Show()
    else
      message:Hide()
    end

    fit()
  end

  grid = Kit.create(OWNER, "table", zone, {
    width = gridWidth(),
    columns = boardSpecs(),
    rows = {},
    onSelect = function(_, row)
      if row and row.id ~= nil then
        select(row.id)
      end
    end,
    onActivate = function(_, row)
      if row and row.id ~= nil then
        PerfPage.openDetail(row.id, root)
      end
    end,
  })

  chart = Kit.create(OWNER, "chart", zone, { width = limit("panelWidth") })
  panelName = Bricks.text(zone, "small", "text")
  panelName:SetJustifyH("LEFT")

  message = Bricks.text(zone, "small", "muted")
  message:SetPoint("TOPLEFT", grid, "TOPLEFT", S("kit.inset"), -(rowHeight * 2))
  message:Hide()

  local baseDraw = grid.kitDraw

  function grid:kitDraw()
    baseDraw(self)
    fit()
  end

  zone:SetScript("OnSizeChanged", fit)

  state.grid, state.chart, state.message, state.panelName, state.panelRows = grid, chart, message, panelName, panelRows
  -- Only the displayed view is recalculated: the table is redrawn when it is shown (dashboard without detail).
  function state.drawBoard()
    if state.view == "dashboard" and not state.detail and state.stale.board then
      refresh()
    end
  end

  state.onTick[#state.onTick + 1] = state.drawBoard

  refresh()
end

PerfPage.builders[#PerfPage.builders + 1] = buildBoard

local function buildDetail(root, state)
  local Kit, Bricks, L = EbonAPI.Kit, EbonAPI.Bricks, EbonAPI.L
  local model = EbonAPI.PerfModel
  local zone = state.zones.detail
  local gap = S("kit.gap")
  local rows = {}

  local back = Kit.create(OWNER, "button", zone, {
    text = L.PERFPAGE_DETAIL_BACK,
    onClick = function()
      PerfPage.closeDetail(root)
    end,
  })

  back:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, 0)

  local title = Bricks.text(zone, S("page.title.font"), S("page.title.color"))

  title:SetPoint("LEFT", back, "RIGHT", gap, 0)

  local axis = Bricks.text(zone, "small", "muted")

  axis:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -gap)

  local stacked = Kit.create(OWNER, "stacked", zone, { width = state.width })

  stacked:SetPoint("TOPLEFT", axis, "BOTTOMLEFT", 0, -gap)

  local empty = Bricks.text(zone, "small", "muted")

  empty:SetPoint("CENTER", stacked, "CENTER", 0, 0)
  empty:SetWidth(max(1, state.width - S("kit.inset") * 4))
  empty:SetText(L.PERFPAGE_DETAIL_EMPTY)
  empty:Hide()

  local function legendRow(index)
    local row = rows[index]

    if not row then
      row = { swatch = zone:CreateTexture(nil, "ARTWORK") }
      row.name = Bricks.text(zone, "small", "text")
      row.value = Bricks.text(zone, "small", "muted")
      row.swatch:SetSize(S("fonts.small.size"), S("fonts.small.size"))
      row.value:SetJustifyH("RIGHT")
      rows[index] = row
    end

    return row
  end

  local function refresh(snapshot)
    if not state.detail then
      return
    end

    state.recalcs.detail = state.recalcs.detail + 1

    local info = model.detail(state.detail, snapshot)

    if not info then
      state.detail = nil
      PerfPage.relayout(root)

      return
    end

    local ok, history = pcall(EbonAPI.Perf.history)
    local step = ok and type(history) == "table" and tonumber(history.step) or 5

    title:SetText(info.title)
    axis:SetText(format(L.PERFPAGE_DETAIL_AXIS, step))
    stacked:SetWidth(state.width)
    stacked:SetSeries(info.data)
    empty:SetWidth(max(1, state.width - S("kit.inset") * 4))
    if #info.data.slices == 0 then
      empty:Show()
    else
      empty:Hide()
    end

    local lineHeight = S("fonts.small.size") + gap
    local top = back:GetHeight() + gap + axis:GetHeight() + gap + stacked:GetHeight() + gap

    for index, entry in ipairs(info.legend) do
      local row = legendRow(index)
      local r, g, b = stacked:ColorOf(entry.colored and entry.module or nil)

      row.swatch:SetTexture(r, g, b, 1)
      row.swatch:ClearAllPoints()
      row.swatch:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -(top + (index - 1) * lineHeight))
      row.name:ClearAllPoints()
      row.name:SetPoint("LEFT", row.swatch, "RIGHT", gap, 0)
      row.name:SetText(entry.module .. (entry.folder and entry.folder ~= entry.module and (" (" .. entry.folder .. ")") or ""))
      row.value:ClearAllPoints()
      row.value:SetPoint("RIGHT", zone, "RIGHT", 0, 0)
      row.value:SetPoint("TOP", row.swatch, "TOP", 0, 0)
      row.value:SetText(entry.cpuText)
      row.swatch:Show()
      row.name:Show()
      row.value:Show()
    end

    for index = #info.legend + 1, #rows do
      rows[index].swatch:Hide()
      rows[index].name:Hide()
      rows[index].value:Hide()
    end

    local total = top + #info.legend * lineHeight

    if zone.contentHeight ~= total then
      zone:SetContentHeight(total)
    end
  end

  state.detailUi = { back = back, title = title, axis = axis, stacked = stacked, empty = empty, rows = rows }
  state.onTick[#state.onTick + 1] = refresh
end

PerfPage.builders[#PerfPage.builders + 1] = buildDetail

local MAP_TABS = {
  { id = "cpu", text = "PERFPAGE_MAP_TAB_CPU" },
  { id = "mem", text = "PERFPAGE_MAP_TAB_MEMORY" },
  { id = "growth", text = "PERFPAGE_MAP_TAB_GROWTH" },
}

local function buildMap(root, state)
  local Kit, Bricks, L = EbonAPI.Kit, EbonAPI.Bricks, EbonAPI.L
  local model = EbonAPI.PerfModel
  local zone = state.zones.map
  local gap = S("kit.gap")
  local swatch = S("fonts.small.size")
  local maps, legend, tabs = {}, nil, nil

  state.mapTab = state.mapTab or MAP_TABS[1].id
  state.maps = maps

  local function mapHeight()
    return limit("mapHeight")
  end

  local function tabsHeight()
    return S("nav.tab.height") + S("kit.spacing") + mapHeight()
  end

  local function fit()
    local width, height = state.width, mapHeight()

    for _, entry in ipairs(MAP_TABS) do
      local map = maps[entry.id]

      if map:GetWidth() ~= width or map:GetHeight() ~= height then
        map:SetSize(width, height)
      end
    end

    local textWidth = max(1, width - (swatch + gap) * 3)

    if legend.text:GetWidth() ~= textWidth then
      legend.text:SetWidth(textWidth)
    end

    local legendHeight = max(swatch, legend.text:GetStringHeight() or 0)

    legend:SetWidth(width)
    legend:SetHeight(legendHeight)
    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -(tabsHeight() + gap))

    local total = tabsHeight() + gap + legendHeight

    if zone.contentHeight ~= total then
      zone:SetContentHeight(total)
    end
  end

  tabs = Kit.create(OWNER, "tabs", zone, {
    onSelect = function(_, id)
      state.mapTab = id
      state.stale.board = true

      if state.drawMap then
        state.drawMap()
      end
    end,
  })

  for _, entry in ipairs(MAP_TABS) do
    local page = tabs:AddTab(entry.id, { text = L[entry.text] })

    maps[entry.id] = page:Add("treemap", { width = state.width, height = mapHeight() })
  end

  tabs:ClearAllPoints()
  tabs:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, 0)
  tabs:Select(state.mapTab)

  legend = CreateFrame("Frame", nil, zone)
  legend.marks = {}

  for index, key in ipairs({ "accent.fill", "gray.low", "gray.high" }) do
    local mark = legend:CreateTexture(nil, "ARTWORK")

    mark:SetTexture(Bricks.media("solid"))
    Bricks.paint(mark, "SetVertexColor", S("widgets.map." .. key))
    mark:SetWidth(swatch)
    mark:SetHeight(swatch)
    mark:SetPoint("TOPLEFT", legend, "TOPLEFT", (index - 1) * (swatch + gap), 0)
    legend.marks[index] = mark
  end

  legend.text = Bricks.text(legend, "small", "muted")
  legend.text:SetJustifyH("LEFT")
  legend.text:SetPoint("TOPLEFT", legend, "TOPLEFT", (swatch + gap) * 3, 0)
  legend.text:SetText(L.PERFPAGE_MAP_LEGEND)

  state.tabs, state.legend = tabs, legend

  zone:SetScript("OnSizeChanged", fit)

  function state.drawMap()
    if state.view == "map" and maps[state.mapTab] then
      state.recalcs.map = state.recalcs.map + 1
      maps[state.mapTab]:SetItems(model.mapItems(state.snapshot, state.mapTab))
      fit()
    end
  end

  state.onTick[#state.onTick + 1] = function()
    state.drawMap()
  end

  fit()
end

local function startRun(root, seconds)
  local Perf = EbonAPI.Perf

  if EbonAPI.Perf.status().profiling then
    Perf.begin(seconds, { scan = root.perf.scan })
    PerfPage.sync()

    return
  end

  EbonAPI.Kit.openDialog({
    owner = OWNER,
    text = EbonAPI.L.PERFPAGE_PROFILER_ASK,
    accept = EbonAPI.L.UI_YES,
    cancel = EbonAPI.L.UI_NO,
    onAccept = function()
      PerfPage.arm(seconds, { scan = root.perf.scan })
    end,
  })
end

-- Shared click of the "measure for" button and of the "turn the profiler on" button.
function PerfPage.runClick(root)
  if active(runInfo()) then
    PerfPage.status(root)

    return
  end

  startRun(root, root.perf.duration)
end

function PerfPage.arm(seconds, opts)
  local Perf = EbonAPI.Perf

  if Perf.enableProfiler(seconds, opts) then
    return true
  end

  PerfPage.waitingOpts = opts

  if not PerfPage.waiting then
    PerfPage.waiting = function()
      EbonAPI.Bus.off("PLAYER_REGEN_ENABLED", PerfPage.waiting, OWNER)
      PerfPage.waiting = nil

      local pending = Perf.run().pending

      if pending then
        Perf.enableProfiler(pending, PerfPage.waitingOpts)
      end
    end

    EbonAPI.Bus.on("PLAYER_REGEN_ENABLED", PerfPage.waiting, OWNER)
  end

  return false
end

local function buildFooter(root, state)
  local Kit, Bricks, L = EbonAPI.Kit, EbonAPI.Bricks, EbonAPI.L
  local zone = state.zones.footer
  local gap = S("kit.gap")
  local buttons = {}

  state.scan = false
  state.duration = EbonAPI.PerfModel.durations[1]

  for _, seconds in ipairs(EbonAPI.PerfModel.durations) do
    if seconds == limit("defaultDuration") then
      state.duration = seconds
    end
  end

  local function kb(value)
    return floor(value + 0.5) .. " " .. L.PERFPAGE_UNIT_KB
  end

  local function button(action, anchor, point, relative, x, y)
    local made = Kit.create(OWNER, "button", zone, {
      text = action.text,
      onClick = action.run,
    })

    made:ClearAllPoints()
    made:SetPoint(point, anchor, relative, x, y)
    buttons[#buttons + 1] = made
    state[action.id .. "Button"] = made

    return made
  end

  local run = button({
    id = "run",
    text = L.PERFPAGE_RUN_BUTTON,
    run = function()
      PerfPage.runClick(root)
    end,
  }, zone, "TOPLEFT", "TOPLEFT", 0, 0)

  local choices = {}

  for index, seconds in ipairs(EbonAPI.PerfModel.durations) do
    choices[index] = { id = seconds, text = format(L.PERFPAGE_RUN_MINUTES, seconds / limit("secondsPerMinute")) }
  end

  state.durations = Kit.create(OWNER, "choice", zone, {
    shape = "segment",
    items = choices,
    value = state.duration,
    onChange = function(id)
      state.duration = id
    end,
  })
  state.durations:ClearAllPoints()
  state.durations:SetPoint("LEFT", run, "RIGHT", gap, 0)

  state.recordingDot = zone:CreateTexture(nil, "OVERLAY")
  state.recordingDot:SetTexture(Bricks.media("solid"))
  Bricks.paint(state.recordingDot, "SetVertexColor", S("widgets.pill.bad"))
  state.recordingDot:SetWidth(S("fonts.small.size"))
  state.recordingDot:SetHeight(S("fonts.small.size"))
  state.recordingDot:SetPoint("LEFT", state.durations, "RIGHT", gap, 0)
  state.recordingDot:Hide()

  state.recording = Kit.create(OWNER, "pill", zone, { level = "bad", text = "" })
  state.recording:ClearAllPoints()
  state.recording:SetPoint("LEFT", state.recordingDot, "RIGHT", gap, 0)
  state.recording:Hide()

  local gc = button({
    id = "gc",
    text = L.UI_PERF_GC,
    run = function()
      local before, after = EbonAPI.Perf.gcAll()

      before, after = before or 0, after or 0
      Kit.notify(OWNER, format(L.PERFPAGE_GC_DONE, kb(before), kb(after), kb(after - before)))
    end,
  }, run, "TOPLEFT", "BOTTOMLEFT", 0, -gap)

  local reset = button({
    id = "reset",
    text = L.UI_PERF_RESET,
    run = function()
      EbonAPI.Perf.resetAll()
      Kit.notify(OWNER, L.PERFPAGE_RESET_DONE)
      PerfPage.refresh(root)
    end,
  }, gc, "LEFT", "RIGHT", gap, 0)
  reset:ClearAllPoints()
  reset:SetPoint("LEFT", gc, "RIGHT", gap, 0)

  state.scanToggle = Kit.create(OWNER, "toggle", zone, {
    text = L.PERFPAGE_SCAN_LABEL,
    tip = L.PERFPAGE_SCAN_TIP,
    value = false,
    onChange = function(value)
      state.scan = value and true or false
    end,
  })
  state.scanToggle:ClearAllPoints()
  state.scanToggle:SetPoint("LEFT", reset, "RIGHT", gap, 0)

  button({
    id = "enable",
    text = L.PERFPAGE_PROFILER_ENABLE,
    run = function()
      PerfPage.runClick(root)
    end,
  }, state.scanToggle, "LEFT", "RIGHT", gap, 0)
  PerfPage.showEnable(state, EbonAPI.Perf.status())

  state.permanent = Kit.create(OWNER, "pill", zone, { level = "warn", text = L.PERFPAGE_PROFILER_PERMANENT })
  state.permanent:ClearAllPoints()
  state.permanent:SetPoint("TOPLEFT", gc, "BOTTOMLEFT", 0, -gap)
  state.permanent:Hide()

  state.profilerOff = Kit.create(OWNER, "button", zone, {
    text = L.PERFPAGE_PROFILER_OFF,
    onClick = function()
      Kit.openDialog({
        owner = OWNER,
        text = L.PERFPAGE_PROFILER_OFF_ASK,
        accept = L.UI_YES,
        cancel = L.UI_NO,
        onAccept = function()
          EbonAPI.Perf.disableProfiler()
        end,
      })
    end,
  })
  state.profilerOff:ClearAllPoints()
  state.profilerOff:SetPoint("LEFT", state.permanent, "RIGHT", gap, 0)
  state.profilerOff:Hide()

  state.statusText = Bricks.text(zone, "small", "muted")
  state.statusText:SetJustifyH("LEFT")
  state.statusText:SetPoint("TOPLEFT", gc, "BOTTOMLEFT", 0, -(gap + max(state.permanent:GetHeight(), state.profilerOff:GetHeight()) + gap))

  state.buttons = buttons
  zone:SetContentHeight(run:GetHeight() + gap + gc:GetHeight() + gap
    + max(state.permanent:GetHeight(), state.profilerOff:GetHeight()) + gap + S("fonts.small.size"))
end

local FREEZE_KINDS = {
  handler = "PERFPAGE_PIECE_KIND_HANDLER",
  frame = "PERFPAGE_PIECE_KIND_FRAME",
  bus_event = "PERFPAGE_PIECE_KIND_EVENT",
  bus_tick = "PERFPAGE_PIECE_KIND_TIMER",
  hook = "PERFPAGE_PIECE_KIND_HOOK",
}

local FREEZE_PIECE_LINES = 5
local NO_ROWS = {}
local FREEZE_TOP_LINES = 3
local FREEZE_ADDON_NAMES = 3

local function freezeVerdict(L, gel)
  if gel.loading then
    return L.PERFPAGE_FREEZE_LOADING
  end

  local d = gel.d or 0

  if (gel.lua or 0) >= d / 2 then
    return L.PERFPAGE_FREEZE_VERDICT_OWN
  end

  if (gel.sc or 0) >= d / 2 then
    return L.PERFPAGE_FREEZE_VERDICT_LUA
  end

  return L.PERFPAGE_FREEZE_VERDICT_CLIENT
end

local PE_PIECE_LINES = 12
local PE_ADDON = "ProjectEbonhold"

local function findRow(rows, id)
  for _, row in ipairs(rows or NO_ROWS) do
    if row.id == id then
      return row
    end

    local found = findRow(row.children, id)

    if found then
      return found
    end
  end

  return nil
end

local function freezePiece(L, piece)
  local kind = FREEZE_KINDS[piece.kind]
  local label = piece.label
  local text

  if label == nil or label == "" then
    label = L.PERFPAGE_PIECE_UNKNOWN
  end

  text = format("%s  %s", label, format(L.PERFPAGE_FREEZE_MS, format("%.1f", piece.ms or 0)))

  if kind then
    text = L[kind] .. "  " .. text
  end

  if (piece.calls or 0) > 0 then
    text = text .. "  " .. format(L.PERFPAGE_PIECE_CALLS, piece.calls)
  end

  return text
end

local function buildFreezes(root, state)
  local Bricks, L = EbonAPI.Bricks, EbonAPI.L
  local zone = state.zones.freezes
  local gap = S("kit.gap")
  local ui = nil
  local drawn = nil
  local drawnStats = nil

  local function lineHeight()
    return S("fonts.small.size") + gap
  end

  local function makeBlock()
    local block = CreateFrame("Frame", nil, zone)

    block.head = Bricks.text(block, "small", "text")
    block.flags = Bricks.text(block, "small", "muted")
    block.flags:SetJustifyH("RIGHT")
    block.pieces = {}
    block.peLines = {}
    block.others = Bricks.text(block, "small", "muted")
    block.heap = Bricks.text(block, "small", "muted")
    block.events = Bricks.text(block, "small", "muted")
    block.scene = Bricks.text(block, "small", "muted")

    return block
  end

  local function pieceLine(block, index)
    local line = block.pieces[index]

    if not line then
      line = Bricks.text(block, "small", "text")
      block.pieces[index] = line
    end

    return line
  end

  local function peLine(index)
    ui.pe[index] = ui.pe[index] or Bricks.text(zone, "small", index == 1 and "muted" or "text")
    ui.pe[index]:ClearAllPoints()
    ui.pe[index]:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -(index * lineHeight()))
    ui.pe[index]:SetWidth(max(1, state.width))
    ui.pe[index]:SetJustifyH("LEFT")

    return ui.pe[index]
  end

  local function pieceBlock(stats, rows, first)
    local count = 0

    if type(stats) == "table" and #stats > 0 then
      local sum = 0

      for index = 1, #stats do
        sum = sum + (stats[index].net or 0)
      end

      local row = findRow(rows, PE_ADDON)
      local cpu = row and row.ms or 0
      local head = peLine(1)

      head:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -(first * lineHeight()))
      head:SetText(cpu > 0 and format(L.PERFPAGE_PE_HEAD, sum, cpu, sum / cpu * 100) or format(L.PERFPAGE_PE_HEAD_NOCPU, sum))
      head:Show()
      count = 1

      for index = 1, min(#stats, PE_PIECE_LINES) do
        local p = stats[index]
        local line = peLine(index + 1)

        line:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -((first + index) * lineHeight()))
        line:SetText(format("%s  %s  %s", p.label or L.PERFPAGE_PIECE_UNKNOWN, format(L.PERFPAGE_PIECE_CALLS, p.calls or 0),
          format(L.PERFPAGE_PE_LINE, p.total or 0, p.net or 0)))
        line:Show()
        count = count + 1
      end
    end

    for index = count + 1, #ui.pe do
      ui.pe[index]:Hide()
    end

    return count
  end

  local function place(text, block, row)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -(row * lineHeight()))
    text:SetWidth(max(1, state.width))
    text:SetJustifyH("LEFT")
  end

  local function fillBlock(block, gel, y)
    local pieces = 0
    local row = 0

    block:ClearAllPoints()
    block:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -y)
    block:SetWidth(state.width)

    local d = gel.d or 0
    local t = floor(gel.t or 0)

    place(block.head, block, row)
    block.head:SetText(format("%02d:%02d  %s  %s %s (%.0f %%)", floor(t / 60), t % 60,
      format(L.PERFPAGE_FREEZE_MS, format("%.0f", d)), L.PERFPAGE_FREEZE_LUA,
      format(L.PERFPAGE_FREEZE_MS, format("%.0f", gel.lua or 0)), d > 0 and (gel.lua or 0) / d * 100 or 0))

    local flags = ""

    if gel.combat then
      flags = L.PERFPAGE_FREEZE_COMBAT
    end

    if gel.loading then
      flags = flags == "" and L.PERFPAGE_FREEZE_LOADING or (flags .. "  " .. L.PERFPAGE_FREEZE_LOADING)
    else
      local verdict = freezeVerdict(L, gel)

      flags = flags == "" and verdict or (flags .. "  " .. verdict)
    end

    block.flags:ClearAllPoints()
    block.flags:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
    block.flags:SetText(flags)
    row = row + 1

    local top = gel.top or NO_ROWS
    local inside = gel.inside or NO_ROWS

    for index = 1, min(#top, FREEZE_TOP_LINES) do
      pieces = pieces + 1
      local line = pieceLine(block, pieces)

      place(line, block, row)
      line:SetText(freezePiece(L, top[index]))
      line:Show()
      row = row + 1
    end

    for index = 1, #inside do
      if pieces >= FREEZE_PIECE_LINES then
        break
      end

      pieces = pieces + 1
      local line = pieceLine(block, pieces)

      place(line, block, row)
      line:SetText(freezePiece(L, inside[index]))
      line:Show()
      row = row + 1
    end

    for index = pieces + 1, #block.pieces do
      block.pieces[index]:Hide()
    end

    local kept = gel.pcs or NO_ROWS

    for index = 1, min(#kept, FREEZE_PIECE_LINES) do
      local line = block.peLines[index]

      if not line then
        line = Bricks.text(block, "small", "muted")
        block.peLines[index] = line
      end

      place(line, block, row)
      line:SetText(format("%s  %s  %s  %s", L.PERFPAGE_PE_FREEZE, kept[index].label,
        format(L.PERFPAGE_FREEZE_MS, format("%.1f", kept[index].net or 0)), format(L.PERFPAGE_PIECE_CALLS, kept[index].calls or 0)))
      line:Show()
      row = row + 1
    end

    for index = min(#kept, FREEZE_PIECE_LINES) + 1, #block.peLines do
      block.peLines[index]:Hide()
    end

    local names = ""

    for index = 1, min(#(gel.addons or NO_ROWS), FREEZE_ADDON_NAMES) do
      local addon = gel.addons[index]

      names = names .. "  " .. format("%s %s", addon.id, format(L.PERFPAGE_FREEZE_MS, format("%.0f", addon.ms or 0)))
    end

    place(block.others, block, row)
    block.others:SetText(format("%s  %s / %s%s", L.PERFPAGE_FREEZE_OTHERS,
      format(L.PERFPAGE_FREEZE_MS, format("%.0f", gel.addonsMs or 0)),
      format(L.PERFPAGE_FREEZE_MS, format("%.0f", gel.addonsWindow or 0)), names))
    row = row + 1

    place(block.heap, block, row)
    block.heap:SetText(format("%s  %.1f %s  %s  %s %s %s", L.PERFPAGE_FREEZE_HEAP, gel.hd or 0, L.PERFPAGE_UNIT_KB,
      L.PERFPAGE_FREEZE_CONTEXT, gel.zone or "", gel.wins or "", gel.page or ""))
    row = row + 1

    if gel.ev ~= nil then
      place(block.events, block, row)
      block.events:SetText(format("%s  %d  %s", L.PERFPAGE_FREEZE_EVENTS, gel.ev, gel.evTop or ""))
      block.events:Show()
      row = row + 1
    else
      block.events:Hide()
    end

    local scene = ""

    if gel.plates ~= nil then
      scene = format("%s  %d", L.PERFPAGE_FREEZE_PLATES, gel.plates)
    end

    if gel.raid ~= nil then
      scene = (scene == "" and "" or (scene .. "   ")) .. format("%s  %d", L.PERFPAGE_FREEZE_RAID, gel.raid)
    end

    if gel.fps ~= nil then
      scene = (scene == "" and "" or (scene .. "   ")) .. format("%s  %.1f", L.PERFPAGE_FREEZE_FPS, gel.fps)
    end

    if scene ~= "" then
      place(block.scene, block, row)
      block.scene:SetText(scene)
      block.scene:Show()
      row = row + 1
    else
      block.scene:Hide()
    end

    block:SetHeight(row * lineHeight())

    return row * lineHeight() + gap
  end

  local function summaryRows(csv, secs, title, row)
    if csv == nil then
      return row
    end

    row = row + 1
    ui.sum[row] = ui.sum[row] or Bricks.text(zone, "small", "muted")
    ui.sum[row]:ClearAllPoints()
    ui.sum[row]:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -(row * lineHeight()))
    ui.sum[row]:SetText(format(title, secs or 0))
    ui.sum[row]:Show()

    local items = {}

    for name, n in string.gmatch(csv, "([^,:]+):(%d+)") do
      items[#items + 1] = format(L.PERFPAGE_FREEZE_RATE, name, (secs or 0) > 0 and n / secs or n)
    end

    for first = 1, #items, 5 do
      row = row + 1
      ui.sum[row] = ui.sum[row] or Bricks.text(zone, "small", "text")
      ui.sum[row]:ClearAllPoints()
      ui.sum[row]:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -(row * lineHeight()))
      ui.sum[row]:SetWidth(max(1, state.width))
      ui.sum[row]:SetJustifyH("LEFT")
      ui.sum[row]:SetText(table.concat(items, "   ", first, min(first + 4, #items)))
      ui.sum[row]:Show()
    end

    return row
  end

  local function draw()
    if state.view ~= "freezes" then
      return
    end

    if not ui then
      ui = { blocks = {}, sum = {}, pe = {} }
      ui.head = Bricks.text(zone, "small", "muted")
      ui.head:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, 0)
      ui.head:SetText(L.PERFPAGE_FREEZE_HEAD)
      ui.empty = Bricks.text(zone, "small", "muted")
      ui.empty:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, 0)
      ui.empty:SetWidth(max(1, state.width))
      ui.more = Bricks.text(zone, "small", "muted")
      ui.more:SetWidth(max(1, state.width))
    end

    local snapshot = state.snapshot

    if type(snapshot) ~= "table" or (drawn == (snapshot.freezes or NO_ROWS) and drawnStats == snapshot.pieceStats) then
      return
    end

    local list = snapshot.freezes or NO_ROWS
    local info = snapshot.freezeInfo or NO_ROWS

    drawn = list
    drawnStats = snapshot.pieceStats

    local top = lineHeight()
    local y = top
    local last = summaryRows(info.evc, info.evcs, L.PERFPAGE_FREEZE_SUM_COMBAT, 0)

    last = summaryRows(info.evo, info.evos, L.PERFPAGE_FREEZE_SUM_OUT, last)

    for index = last + 1, #ui.sum do
      ui.sum[index]:Hide()
    end

    local pieceLines = pieceBlock(snapshot.pieceStats, snapshot.rows, last + 1)

    last = last + pieceLines
    y = y + last * lineHeight()

    if #list == 0 then
      ui.head:Hide()
      ui.empty:SetText(format(L.PERFPAGE_FREEZE_NONE, floor(info.th or 0)))
      ui.empty:Show()
    else
      ui.empty:Hide()
      ui.head:Show()
    end

    for index, gel in ipairs(list) do
      local block = ui.blocks[index]

      if not block then
        block = makeBlock()
        ui.blocks[index] = block
      end

      y = y + fillBlock(block, gel, y)
      block:Show()
    end

    for index = #list + 1, #ui.blocks do
      ui.blocks[index]:Hide()
    end

    local missing = (info.n or 0) - (info.kept or #list)

    if missing > 0 then
      ui.more:ClearAllPoints()
      ui.more:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, -y)
      ui.more:SetText(format(L.PERFPAGE_FREEZE_MORE, missing))
      ui.more:Show()
      y = y + lineHeight()
    else
      ui.more:Hide()
    end

    if zone.contentHeight ~= y then
      zone:SetContentHeight(y)
    end
  end

  state.drawFreezes = draw
  state.onTick[#state.onTick + 1] = draw
end

PerfPage.builders[#PerfPage.builders + 1] = buildFreezes
PerfPage.builders[#PerfPage.builders + 1] = buildMap
PerfPage.builders[#PerfPage.builders + 1] = buildFooter
