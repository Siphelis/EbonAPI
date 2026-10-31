EbonAPI = EbonAPI or {}
EbonAPI.QueueCells = EbonAPI.QueueCells or {}

-- The block of the send queue: one 3 px cell per remaining part of a stream, in departure order, 20 columns
-- by 25 lines (500 cells), with the counter at its right inside the same card-shaped frame. One mouse zone
-- finds the cell under the cursor (or the counter); every cell keeps a signature and is repainted only when it
-- changed. No colour per addon: accent (focus), caution after 10 s, danger after 30 s, white = leaves within
-- the second, held stream = half opacity. Skin keys: widgets.cells.shape (square, bevel, round),
-- widgets.queue.counter.size, widgets.synthesis.fill / border (the card form of the frame).

local QueueCells = EbonAPI.QueueCells
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Parameters = EbonAPI.Parameters
local Bricks = EbonAPI.Bricks
local QueueParts = EbonAPI.QueueParts

local format, floor, ceil, max, min = string.format, math.floor, math.ceil, math.max, math.min
local pcall, tonumber, tostring, type, ipairs = pcall, tonumber, tostring, type, ipairs

local THEME = Palette.THEME
local COLUMNS = 20
local SIZE = 3
local PITCH = 4
local HOT = 8
local DIM = 0.14
local HELD = 0.5
local MARGIN_X = 8
local MARGIN_Y = 5
local COUNTER_GAP = 10
local CAUTION_AT = 40
local DANGER_AT = 80
local LEGEND_HEIGHT = 14
local SWATCH = 7
local SWATCH_GAP = 5
local LEGEND_SPACE = 14

QueueCells.WIDTH = 158

local function word(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

local function value(key, fallback)
  local ok, found = pcall(Skins.value, key)
  if ok and found ~= nil then
    return found
  end

  return fallback
end

local function num(n)
  n = tonumber(n)
  if not n or n ~= n or n == math.huge or n == -math.huge then
    return 0
  end

  return n
end

local function tint(target, key, alpha)
  local color = THEME[key] or THEME.text
  target:SetVertexColor(color[1], color[2], color[3], alpha or 1)
end

local function hue(key)
  local color = THEME[key] or THEME.text

  return color[1] + color[2] * 1000 + color[3] * 1000000
end

local function look()
  local shape = value("widgets.cells.shape")
  if shape ~= "square" and shape ~= "bevel" and shape ~= "round" then
    local ok, corners = pcall(Parameters.value, nil, "corners")
    if ok and (tonumber(corners) or 0) > 0 then
      shape = "round"
    elseif value("border.style") == "TEXTURE" then
      shape = "bevel"
    else
      shape = "square"
    end
  end

  return shape
end

local function paletteMark()
  return hue("focus") + hue("caution") + hue("danger") + hue("text") + hue("borderDim") + hue("card") + hue("muted")
    + hue("border")
end

local function fidOf(row)
  return row.fid or row.id or row.pos
end

local function percent(total, capacity)
  return capacity > 0 and floor(total / capacity * 100 + 0.5) or 0
end

function QueueCells.build(parent, opts)
  opts = opts or {}

  local frame = CreateFrame("Frame", nil, parent)
  frame.repaints = 0
  frame.cells = {}
  frame.cols = COLUMNS
  frame.lines = 0
  frame.size = SIZE
  frame.pitch = PITCH
  frame.gap = PITCH - SIZE

  local sig, rowOf, partOf, alpha = {}, {}, {}, {}
  local mem = {}
  local state = { rows = nil, hot = nil, counter = false, focus = nil, lane = nil, hoverFid = nil, hoverWho = nil,
    count = 0, capacity = 0, used = {} }
  local interval = 0.15
  local tip = { title = "", body = "" }

  frame:SetWidth(QueueCells.WIDTH)
  frame:SetHeight(1)

  local zone = CreateFrame("Frame", nil, frame)
  zone:EnableMouse(true)
  frame.zone = zone

  local numberText = Bricks.text(frame, "normal", "text")
  local ofText = Bricks.text(frame, "small", "muted")
  local pctText = Bricks.text(frame, "normal", "focus")
  for _, fs in ipairs({ numberText, ofText, pctText }) do
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then
      fs:SetWordWrap(false)
    end
  end

  frame.counter = { number = numberText, of = ofText, pct = pctText }
  frame.counterText = { number = "", of = "", pct = "" }

  local function applyCard()
    local fill = value("widgets.synthesis.fill", "card")
    local border = value("widgets.synthesis.border", "border")

    Bricks.frame(frame, "small", fill, border)
    frame.look = { fill = fill, border = border, inset = Bricks.insetOf(frame) }
  end

  local function applyCounter()
    local size = max(8, floor(num(value("widgets.queue.counter.size", 29))))

    Bricks.font(numberText, "normal")
    pcall(function()
      local file, _, flags = numberText:GetFont()
      if file then
        numberText:SetFont(file, size, flags)
      end
    end)
    Bricks.font(ofText, "small")
    Bricks.font(pctText, "normal")

    local x = MARGIN_X + COLUMNS * PITCH - (PITCH - SIZE) + COUNTER_GAP
    local top = max(2, floor((frame:GetHeight() - (size + 2 + 13 + 15)) / 2))
    local room = max(1, QueueCells.WIDTH - x - 4)

    numberText:ClearAllPoints()
    numberText:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -top)
    numberText:SetWidth(room)
    numberText:SetHeight(size + 2)
    ofText:ClearAllPoints()
    ofText:SetPoint("TOPLEFT", numberText, "BOTTOMLEFT", 0, -1)
    ofText:SetWidth(room)
    pctText:ClearAllPoints()
    pctText:SetPoint("TOPLEFT", ofText, "BOTTOMLEFT", 0, -1)
    pctText:SetWidth(room)
    frame.counterX, frame.counterSize = x, size
  end

  local function placeCell(i, big)
    local cell = frame.cells[i]
    local fill = cell.fill
    local side = big and HOT or SIZE
    local grow = big and (HOT - SIZE) / 2 or 0

    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN_X + cell.x - grow, -(MARGIN_Y + cell.y - grow))
    fill:SetWidth(side)
    fill:SetHeight(side)
    if fill.SetDrawLayer then
      fill:SetDrawLayer("ARTWORK", big and 7 or 0)
    end

    cell.big = big
  end

  local function heldOf(code)
    return code and code > 0 and ((code - 1) % 10) % 4 >= 2
  end

  local function setAlpha(i, dim, hi)
    local code = (dim and 1 or 0) + (hi and 2 or 0)
    if alpha[i] == code then
      return
    end

    alpha[i] = code

    local cell = frame.cells[i]
    cell.fill:SetAlpha(dim and DIM or (heldOf(sig[i]) and HELD or 1))

    local big = hi and sig[i] ~= nil and sig[i] ~= 0
    if (cell.big or false) ~= (big or false) then
      placeCell(i, big)
    end
  end

  local function paintCell(i, code, key)
    local fill = frame.cells[i].fill

    frame.repaints = frame.repaints + 1
    if code == 0 then
      tint(fill, "borderDim", 0.5)
    else
      tint(fill, key, 1)
    end

    alpha[i] = nil
  end

  local function applyFocus()
    local rows = state.rows
    local fid, who = state.hoverFid, state.hoverWho or state.focus
    local n = state.count

    if fid then
      local found
      for r = 1, #rows do
        if fidOf(rows[r]) == fid and state.used[r] then
          found = rows[r]
          break
        end
      end

      if found then
        who = found.who
      else
        fid = nil
      end
    end

    if not fid and who then
      local present
      for r = 1, #rows do
        if rows[r].who == who and state.used[r] then
          present = true
          break
        end
      end

      if not present then
        if who == state.focus then
          state.focus = nil
        end

        who = nil
      end
    end

    local lane = (not fid and not who) and state.lane or nil

    for i = 1, n do
      local row = rows[rowOf[i]]
      local on
      if fid then
        on = fidOf(row) == fid
      elseif who then
        on = row.who == who
      elseif lane ~= nil then
        on = row.lane == lane
      end

      setAlpha(i, on == false, on == true and fid ~= nil)
    end

    for i = n + 1, state.capacity do
      setAlpha(i, false, false)
    end
  end

  local function layout(capacity)
    local shape = look()
    local texture = shape == "round" and value("media.circle", "Interface\\Buttons\\WHITE8X8")
      or value("media.solid", "Interface\\Buttons\\WHITE8X8")
    local mark = paletteMark()
    local fillKey, borderKey = value("widgets.synthesis.fill", "card"), value("widgets.synthesis.border", "border")
    local counterSize = value("widgets.queue.counter.size", 29)
    local lines = ceil(capacity / COLUMNS)

    if mem.shape == shape and mem.lines == lines and mem.mark == mark and mem.capacity == capacity
      and mem.texture == texture and mem.fill == fillKey and mem.border == borderKey and mem.csize == counterSize then
      return false
    end

    mem.shape, mem.lines, mem.mark, mem.capacity, mem.texture = shape, lines, mark, capacity, texture
    mem.fill, mem.border, mem.csize = fillKey, borderKey, counterSize

    for i = #frame.cells + 1, capacity do
      local cell = { fill = frame:CreateTexture(nil, "ARTWORK") }
      frame.cells[i] = cell
    end

    frame.lines, frame.shape = lines, shape

    for i = 1, #frame.cells do
      local cell = frame.cells[i]
      if i <= capacity then
        cell.x = ((i - 1) % COLUMNS) * PITCH
        cell.y = floor((i - 1) / COLUMNS) * PITCH
        cell.fill:SetTexture(texture)
        placeCell(i, false)
        cell.fill:Show()
        sig[i] = -1
        alpha[i] = nil
      else
        cell.fill:Hide()
        sig[i] = nil
      end
    end

    state.capacity = capacity
    frame.planWidth = COLUMNS * PITCH - (PITCH - SIZE)
    frame.planHeight = lines * PITCH - (PITCH - SIZE)
    frame:SetHeight(frame.planHeight + MARGIN_Y * 2)
    zone:ClearAllPoints()
    zone:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN_X, -MARGIN_Y)
    zone:SetWidth(QueueCells.WIDTH - MARGIN_X * 2)
    zone:SetHeight(frame.planHeight)
    applyCard()
    applyCounter()
    mem.counter = nil

    return true
  end

  local function drawCounter(total, capacity, snap)
    local pct = percent(total, capacity)
    local numberStr = QueueParts.number(total)
    local ofStr = format(word("QUEUEVIEW_COUNTER_OF"), QueueParts.number(capacity))
    local pctStr = format(word("QUEUEVIEW_CELL_PCT"), tostring(pct))
    local key = pct >= DANGER_AT and "danger" or (pct >= CAUTION_AT and "caution" or "text")
    local detail = format(word("QUEUEVIEW_COUNTER_DETAIL"), QueueParts.number(num(snap.whispers)),
      QueueParts.number(num(snap.channel)), QueueParts.number(num(snap.server)), QueueParts.number(num(snap.parts)))
    local title = format(word("QUEUEVIEW_COUNTER_TIP"), numberStr, QueueParts.number(capacity), tostring(pct))
    local sum = numberStr .. "|" .. ofStr .. "|" .. pctStr .. "|" .. key .. "|" .. title .. "|" .. detail

    if mem.counter == sum then
      return
    end

    mem.counter = sum
    numberText:SetText(numberStr)
    ofText:SetText(ofStr)
    pctText:SetText(pctStr)
    Bricks.paint(numberText, "SetTextColor", key)
    frame.counterText.number, frame.counterText.of, frame.counterText.pct = numberStr, ofStr, pctStr
    frame.counterKey = key
    frame.counterPct = pct
    tip.title, tip.body = title, detail
  end

  function frame:SetRows(rows, snap)
    rows = rows or {}
    snap = snap or {}

    local capacity = max(1, floor(num(snap.capacity ~= nil and snap.capacity or opts.capacity or 500)))
    layout(capacity)

    state.rows = rows
    interval = num(snap.interval) > 0 and num(snap.interval) or interval

    local goCount = ceil(1 / interval)
    local limits = QueueParts.LIMITS.wait
    local n, sends = 0, 0

    for r = 1, #rows do
      local row = rows[r]
      local left = floor(num(row.left))
      local total = max(left, floor(num(row.parts)))
      local held = row.held ~= nil and row.held ~= false
      local age = num(row.age)
      local level = age >= limits[2] and 2 or (age >= limits[1] and 1 or 0)
      local used = false

      for k = 1, left do
        if n >= capacity then
          break
        end

        n = n + 1
        used = true

        local go = (not held) and sends < goCount
        if not held then
          sends = sends + 1
        end

        local code = 1 + level * 10 + (go and 4 or 0) + (held and 2 or 0)
        rowOf[n], partOf[n] = r, total - left + k
        if sig[n] ~= code then
          sig[n] = code
          paintCell(n, code, go and "text" or (level == 2 and "danger" or (level == 1 and "caution" or "focus")))
        end
      end

      state.used[r] = used
    end

    for r = #rows + 1, #state.used do
      state.used[r] = nil
    end

    for i = n + 1, capacity do
      rowOf[i], partOf[i] = nil, nil
      if sig[i] ~= 0 then
        sig[i] = 0
        paintCell(i, 0)
      end
    end

    state.count = n

    drawCounter(snap.total ~= nil and num(snap.total) or n, capacity, snap)
    applyFocus()

    if state.hot or state.counter then
      frame:Probe(true)
    end

    return self
  end

  function frame:GetFocus()
    return state.focus
  end

  function frame:SetFocus(who)
    state.focus = who
    if state.rows then
      applyFocus()
    end

    return self
  end

  function frame:SetHover(fid, who)
    state.hoverFid, state.hoverWho = fid, who
    if state.rows then
      applyFocus()
    end

    return self
  end

  function frame:SetLane(lane)
    state.lane = lane
    if state.rows then
      applyFocus()
    end

    return self
  end

  function frame:CellAt(x, y)
    if not x or not y or x < 0 or y < 0 then
      return nil
    end

    local col, line = floor(x / PITCH) + 1, floor(y / PITCH) + 1
    if col > COLUMNS or line > frame.lines then
      return nil
    end

    local index = (line - 1) * COLUMNS + col
    if index > state.capacity or not rowOf[index] then
      return nil
    end

    return index
  end

  function frame:Info(i)
    local row = state.rows and rowOf[i] and state.rows[rowOf[i]]
    if not row then
      return nil
    end

    local left = floor(num(row.left))
    local total = max(left, floor(num(row.parts)))
    local part = partOf[i]

    return {
      who = row.who, lane = row.lane, key = row.key or row.detail, part = part, total = total, age = num(row.age),
      eta = row.eta, held = row.held, heldFor = row.heldFor, fid = fidOf(row),
      slot = part - (total - left),
    }
  end

  function frame:TipText(info)
    local when
    if info.held then
      when = QueueParts.heldText(info.held, info.heldFor)
    else
      when = format(word("QUEUEVIEW_CELL_ETA"), QueueParts.seconds(num(info.eta) + (info.slot - 1) * interval))
    end

    return format(word("QUEUEVIEW_CELL_TITLE"), tostring(info.who), tostring(info.lane)),
      format(word("QUEUEVIEW_CELL_PART"), tostring(info.key), QueueParts.number(info.part), QueueParts.number(info.total))
        .. "\n" .. format(word("QUEUEVIEW_CELL_AGE"), QueueParts.seconds(info.age)) .. "\n" .. when
  end

  function frame:CounterTip()
    return tip.title, tip.body
  end

  local function hideTip()
    frame.tipShown = nil
    if GameTooltip then
      GameTooltip:Hide()
    end
  end

  local function leave()
    state.hot = nil
    hideTip()

    if opts.onLeave then
      opts.onLeave()
    end
  end

  function frame:Probe(refresh)
    local scale = zone:GetEffectiveScale() or 1
    local cx, cy = GetCursorPosition()
    local left, top = zone:GetLeft(), zone:GetTop()
    local x, y
    if left and top and cx then
      x, y = cx / scale - left, top - cy / scale
    end

    local index = x and frame:CellAt(x, y)
    if index and not rowOf[index] then
      index = nil
    end

    if index and index == state.hot and not refresh then
      return
    end

    if not index then
      if state.hot then
        leave()
      end

      local onCounter = x ~= nil and x >= COLUMNS * PITCH and x < QueueCells.WIDTH - MARGIN_X * 2 and y >= 0
        and y < (frame.planHeight or 0)
      if onCounter then
        if not state.counter or refresh then
          state.counter = true
          frame.tipShown = tip.body
          Bricks.tip(zone, tip.title, tip.body)
        end
      elseif state.counter then
        state.counter = false
        hideTip()
      end

      return
    end

    if state.counter then
      state.counter = false
    end

    local changed = index ~= state.hot
    state.hot = index

    local info = frame:Info(index)
    local title, body = frame:TipText(info)
    Bricks.tip(zone, title, body)
    frame.tipShown = body

    if changed and opts.onEnter then
      opts.onEnter(info)
    end
  end

  zone:SetScript("OnEnter", function()
    zone:SetScript("OnUpdate", function()
      frame:Probe()
    end)

    frame:Probe()
  end)

  zone:SetScript("OnLeave", function()
    zone:SetScript("OnUpdate", nil)
    if state.hot then
      leave()
    end

    if state.counter then
      state.counter = false
      hideTip()
    end
  end)

  zone:SetScript("OnMouseUp", function()
    local info = state.hot and frame:Info(state.hot)
    if info and opts.onPick then
      opts.onPick(info.who)
    end
  end)

  function frame:CellState(i)
    local cell = self.cells[i]
    if not cell or not sig[i] then
      return nil
    end

    local code = sig[i]
    local go = code > 0 and ((code - 1) % 10) >= 4
    local level = code > 0 and floor((code - 1) / 10) or nil
    local key = "borderDim"
    if code > 0 then
      key = go and "text" or (level == 2 and "danger" or (level == 1 and "caution" or "focus"))
    end

    return {
      empty = code == 0, key = key, level = level, go = go, held = heldOf(code) or false,
      dim = alpha[i] ~= nil and alpha[i] % 2 == 1, hi = alpha[i] ~= nil and alpha[i] >= 2, row = rowOf[i], part = partOf[i],
      lane = rowOf[i] and state.rows and state.rows[rowOf[i]] and state.rows[rowOf[i]].lane or nil,
    }
  end

  layout(max(1, floor(num(opts.capacity or 500))))
  drawCounter(0, state.capacity, {})

  return frame
end

-- The legend: three marks on one line, a 7 px square then its text.
function QueueCells.legend(parent, opts)
  opts = opts or {}

  local frame = CreateFrame("Frame", nil, parent)
  local limits = QueueParts.LIMITS.wait
  local warn = opts.warn or limits[1]
  local danger = opts.danger or limits[2]
  local marks = {
    { key = "caution", text = format(word("QUEUEVIEW_CELL_WARN"), QueueParts.number(warn)) },
    { key = "danger", text = format(word("QUEUEVIEW_CELL_DANGER"), QueueParts.number(danger)) },
    { key = "text", text = word("QUEUEVIEW_CELL_GO") },
  }
  local x = 0

  frame.items = {}
  frame.texts = {}
  frame:SetHeight(LEGEND_HEIGHT)

  for index, mark in ipairs(marks) do
    local swatch = frame:CreateTexture(nil, "ARTWORK")
    local text = Bricks.text(frame, "small", "muted")

    text:SetText(mark.text)
    swatch:SetTexture(value("media.solid", "Interface\\Buttons\\WHITE8X8"))
    tint(swatch, mark.key, 1)
    swatch:SetWidth(SWATCH)
    swatch:SetHeight(SWATCH)
    swatch:ClearAllPoints()
    swatch:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -floor((LEGEND_HEIGHT - SWATCH) / 2))
    text:ClearAllPoints()
    text:SetPoint("LEFT", frame, "TOPLEFT", x + SWATCH + SWATCH_GAP, -floor(LEGEND_HEIGHT / 2))
    text:SetJustifyH("LEFT")
    frame.items[index] = { swatch = swatch, text = text, key = mark.key, x = x }
    frame.texts[index] = mark.text
    x = x + SWATCH + SWATCH_GAP + (text:GetStringWidth() or 0) + (index < #marks and LEGEND_SPACE or 0)
  end

  frame.shown = #marks
  frame:SetWidth(max(1, ceil(x)))

  return frame
end
