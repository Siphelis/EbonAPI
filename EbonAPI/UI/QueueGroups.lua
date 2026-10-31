EbonAPI = EbonAPI or {}
EbonAPI.QueueGroups = EbonAPI.QueueGroups or {}

-- The "Contenu" tab of the send queue window: the flows of the queue grouped by destination, one
-- collapsible block per destination, in a virtual list (only the visible lines own a frame).
-- Identity of a destination = kind + who; the identity of a flow = row.id, else row.pos.

local QueueGroups = EbonAPI.QueueGroups
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Parameters = EbonAPI.Parameters
local Bricks = EbonAPI.Bricks

local format, floor, ceil, max, min, lower, byte = string.format, math.floor, math.ceil, math.max, math.min, string.lower, string.byte
local pcall, tostring, tonumber, type, ipairs, pairs, sort, concat, setmetatable = pcall, tostring, tonumber, type, ipairs, pairs, table.sort, table.concat, setmetatable

local THEME = Palette.THEME
local TOOL_H = 26
local FORGET = 60
local OVERSCAN = 1
local SORTS = { "depart", "az", "wait" }
local SORT_KEY = { depart = "QUEUEVIEW_GROUPS_SORT_DEPART", az = "QUEUEVIEW_GROUPS_SORT_AZ", wait = "QUEUEVIEW_GROUPS_SORT_WAIT" }

local function S(key, fallback)
  local ok, found = pcall(Skins.value, key)
  if ok and found ~= nil then
    return found
  end

  return fallback
end

local function word(key)
  local L = EbonAPI.L

  return (L and L[key]) or key
end

local function num(n)
  n = tonumber(n)
  if not n or n ~= n or n == math.huge or n == -math.huge then
    return 0
  end

  return n
end

local function hue(key)
  local color = THEME[key] or THEME.text

  return color[1] + color[2] * 1000 + color[3] * 1000000
end

local function tint(target, method, key, alpha)
  local color = THEME[key] or THEME.text
  target[method](target, color[1], color[2], color[3], alpha or 1)
end

local function clamp(n, low, high)
  return max(low, min(high, n))
end

local function same(mem, signature)
  if mem.sig == signature then
    return true
  end

  mem.sig = signature

  return false
end

local function utf8cut(text, chars)
  local at, count = 1, 0
  while at <= #text and count < chars do
    local b = byte(text, at)
    at = at + (b >= 240 and 4 or b >= 224 and 3 or b >= 192 and 2 or 1)
    count = count + 1
  end

  return text:sub(1, at - 1), count
end

-- Text that never leaves its box: cut by characters (UTF-8 aware) until it fits, then an ellipsis.
local function fit(fs, text, width)
  fs:SetWidth(width)
  fs:SetText(text)
  if (fs:GetStringWidth() or 0) <= width then
    return
  end

  local _, total = utf8cut(text, 1000)
  local low, high = 0, total
  while low < high do
    local mid = ceil((low + high) / 2)
    fs:SetText(utf8cut(text, mid) .. "\226\128\166")
    if (fs:GetStringWidth() or 0) <= width then
      low = mid
    else
      high = mid - 1
    end
  end

  fs:SetText(utf8cut(text, low) .. "\226\128\166")
end

local function text(parent, key, justify)
  local fs = Bricks.text(parent, "small", key or "text")
  fs:SetJustifyH(justify or "LEFT")
  fs:SetHeight(14)
  if fs.SetWordWrap then
    fs:SetWordWrap(false)
  end

  return fs
end

local backdrops = {}

local function backdropOf(shape, radius)
  local id = shape .. radius
  if not backdrops[id] then
    local solid = S("media.solid", "Interface\\Buttons\\WHITE8X8")
    if shape == "round" then
      local edge = max(4, radius)
      local inset = floor(edge * 0.25)
      backdrops[id] = {
        bgFile = solid, edgeFile = S("media.rounded", solid), edgeSize = edge,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
      }
    else
      backdrops[id] = { bgFile = solid, edgeFile = solid, edgeSize = 1 }
    end
  end

  return backdrops[id]
end

local function readSkin()
  local shape = S("widgets.queue.shape")
  local ok, corners = pcall(Parameters.value, nil, "corners")
  local round = ok and tonumber(corners) or 0
  if shape ~= "square" and shape ~= "bevel" and shape ~= "round" then
    shape = round > 0 and "round" or (S("border.style") == "TEXTURE" and "bevel" or "square")
  end

  local st = { shape = shape }
  st.radius = max(0, tonumber(S("widgets.queue.radius")) or (shape == "round" and max(3, min(round, 8)) or 0))
  st.headH = clamp(tonumber(S("widgets.queue.group.headHeight", 34)) or 34, 20, 60)
  st.rowH = clamp(tonumber(S("widgets.queue.group.rowHeight", 24)) or 24, 16, 48)
  st.headBg = S("widgets.queue.group.headBg", "card")
  st.headEdge = S("widgets.queue.group.headEdge", "borderDim")
  st.bodyBg = S("widgets.queue.group.bodyBg", "bgSoft")
  st.edgeAlpha = tonumber(S("widgets.queue.group.edgeAlpha", shape == "square" and 0.35 or 1)) or 1
  st.guide = S("widgets.queue.group.guide", shape == "square") and true or false
  st.id = concat({ shape, st.radius, st.headH, st.rowH, st.headBg, st.headEdge, st.bodyBg, st.edgeAlpha, tostring(st.guide),
    hue(st.headBg), hue(st.headEdge), hue(st.bodyBg), hue("rowHover"), hue("borderDim") }, "|")

  return st
end

local function identOf(row)
  return tostring(row.kind) .. "\1" .. tostring(row.who)
end

local function labelOf(g)
  if g.kind == "whisper" or g.kind == nil then
    return tostring(g.who)
  end

  return word("QUEUEVIEW_KIND_" .. tostring(g.kind))
end

-- Shares of the queue in whole percents whose sum is exactly 100 (largest remainder).
local function shares(groups, total)
  local sum, base = 0, {}
  for index, g in ipairs(groups) do
    local exact = g.left * 100 / total
    base[index] = { index = index, whole = floor(exact), rest = exact - floor(exact) }
    sum = sum + base[index].whole
  end

  local order = {}
  for index = 1, #base do
    order[index] = base[index]
  end

  sort(order, function(a, b)
    if a.rest ~= b.rest then
      return a.rest > b.rest
    end

    return a.index < b.index
  end)

  local missing = (#groups > 0 and 100 or 0) - sum
  for index = 1, #order do
    if missing > 0 then
      order[index].whole = order[index].whole + 1
      missing = missing - 1
    end
  end

  for index, g in ipairs(groups) do
    g.share = base[index].whole
  end
end

local function groupRows(rows, interval)
  local list, byIdent = {}, {}
  for index, row in ipairs(rows or {}) do
    local ident = identOf(row)
    local g = byIdent[ident]
    if not g then
      g = { ident = ident, who = row.who, kind = row.kind, flows = {}, left = 0, oldest = 0, lanes = {}, first = #list + 1 }
      byIdent[ident] = g
      list[#list + 1] = g
    end

    local flow = {
      row = row, fid = row.id or row.pos or index, left = num(row.left), parts = max(1, num(row.parts)), age = num(row.age),
      eta = (not row.held) and row.eta ~= nil and num(row.eta) or nil,
    }
    g.flows[#g.flows + 1] = flow
    g.left = g.left + flow.left
    g.oldest = max(g.oldest, flow.age)
    if row.held and not g.held then
      g.held = row.held
    end

    local seen = false
    for _, lane in ipairs(g.lanes) do
      seen = seen or lane == row.lane
    end

    if not seen and #g.lanes < 3 then
      g.lanes[#g.lanes + 1] = row.lane
    end

    if flow.eta then
      local last = flow.eta + flow.left * interval
      g.e0 = g.e0 and min(g.e0, flow.eta) or flow.eta
      g.e1 = g.e1 and max(g.e1, last) or last
    end
  end

  return list
end

function QueueGroups.build(parent, opts)
  opts = opts or {}
  local QP = EbonAPI.QueueParts
  local root = CreateFrame("Frame", nil, parent)
  local g = { opts = opts, sortMode = "depart", opened = {}, items = {}, lines = {}, paints = 0, creates = 0, groups = {}, hasRows = false }

  if opts.width then
    root:SetWidth(opts.width)
  end

  if opts.height then
    root:SetHeight(opts.height)
  end

  if not opts.width and not opts.height then
    root:SetAllPoints(parent)
  end

  g.root = root

  local label = text(root, "muted")
  label:SetPoint("LEFT", root, "TOPLEFT", 8, -TOOL_H / 2)
  label:SetText(word("QUEUEVIEW_GROUPS_SORT"))
  local sortButtons, x = {}, 8 + (label:GetStringWidth() or 0) + 8
  for index, mode in ipairs(SORTS) do
    local button = Bricks.create("button", root)
    button:SetLabel(word(SORT_KEY[mode]))
    button:Fit(max(button:TextWidth(), 0) + 8)
    button:SetPoint("LEFT", root, "TOPLEFT", x, -TOOL_H / 2)
    button.onClick = function()
      g:SetSort(mode)
    end
    x = x + (button:GetWidth() or 40) + 4
    sortButtons[index] = button
  end

  local closeAll, openAll = Bricks.create("button", root), Bricks.create("button", root)
  closeAll:SetLabel(word("QUEUEVIEW_GROUPS_COLLAPSE"))
  closeAll:Fit(max(closeAll:TextWidth(), 0) + 8)
  closeAll:SetPoint("RIGHT", root, "TOPRIGHT", -8, -TOOL_H / 2)
  closeAll.onClick = function()
    g:SetAll(false)
  end
  openAll:SetLabel(word("QUEUEVIEW_GROUPS_EXPAND"))
  openAll:Fit(max(openAll:TextWidth(), 0) + 8)
  openAll:SetPoint("RIGHT", closeAll, "LEFT", -4, 0)
  openAll.onClick = function()
    g:SetAll(true)
  end
  local count = text(root, "muted", "RIGHT")
  count:SetPoint("RIGHT", openAll, "LEFT", -10, 0)
  count:SetWidth(220)
  g.sortButtons, g.count, g.openAll, g.closeAll = sortButtons, count, openAll, closeAll

  local scroll = Bricks.create("scroll", root)
  scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -TOOL_H)
  scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
  scroll:SetMode("VERTICAL")
  g.scroll = scroll

  local empty = text(root, "muted", "CENTER")
  empty:SetPoint("CENTER", root, "CENTER", 0, 0)
  empty:SetWidth(300)
  empty:SetText(word("QUEUEVIEW_GROUPS_EMPTY"))
  empty:Hide()
  g.empty = empty

  function g:Frame()
    return root
  end

  function g:size()
    local width = root:GetWidth() or 0
    local height = (root:GetHeight() or 0) - TOOL_H
    local bar = tonumber(S("widgets.scroll.width", 8)) or 8
    if width <= 0 then
      width = tonumber(opts.width) or 958
    end

    if height <= 0 then
      height = tonumber(opts.height) and (opts.height - TOOL_H) or 400
    end

    return max(200, width - bar), max(1, height)
  end

  local function hot(self, item)
    local gr = item.g
    for _, mark in ipairs({ self.hl or false, self.over or false }) do
      if mark and mark.who == gr.who then
        if item.flow then
          if mark.fid ~= nil and mark.fid == item.flow.fid then
            return true
          end
        elseif mark.fid == nil or not self:isOpen(gr) then
          return true
        end
      end
    end

    return false
  end

  function g:isOpen(gr)
    local state = self.opened[gr.ident]

    return state ~= nil and state.open
  end

  local function setOpen(self, gr, open)
    self.opened[gr.ident] = { open = open, seen = GetTime() }
  end

  local function newLine(self)
    local line = CreateFrame("Frame", nil, scroll.child)
    line:EnableMouse(true)
    line.mem = {}
    line.hover = line:CreateTexture(nil, "BACKGROUND")
    line.hover:SetAllPoints(line)
    line.hover:SetTexture(S("media.solid", "Interface\\Buttons\\WHITE8X8"))
    line.hover:Hide()
    line.bg = line:CreateTexture(nil, "BACKGROUND")
    line.bg:SetAllPoints(line)
    line.bg:SetTexture(S("media.solid", "Interface\\Buttons\\WHITE8X8"))
    line.guide = line:CreateTexture(nil, "ARTWORK")
    line.guide:SetTexture(S("media.solid", "Interface\\Buttons\\WHITE8X8"))
    line.guide:SetWidth(1)
    line.guide:SetPoint("TOP", line, "TOPLEFT", 14, 0)
    line.guide:SetPoint("BOTTOM", line, "BOTTOMLEFT", 14, 0)
    line:SetScript("OnEnter", function()
      local item = line.item
      if item then
        self.over = { who = item.g.who, fid = item.flow and item.flow.fid or nil }
        self:paint()
        if opts.onEnter then
          opts.onEnter(item.g.who, item.flow and item.flow.fid or nil)
        end
      end
    end)
    line:SetScript("OnLeave", function()
      self.over = nil
      self:paint()
      if opts.onLeave then
        opts.onLeave()
      end
    end)
    line:SetScript("OnMouseUp", function()
      local item = line.item
      if item and not item.flow then
        self:Toggle(item.g)
      end
    end)
    self.lines[#self.lines + 1] = line
    self.creates = self.creates + 1

    return line
  end

  local function makeHead(line)
    local h = {}
    h.chevron = line:CreateTexture(nil, "OVERLAY")
    h.chevron:SetTexture(Bricks.media("chevron"))
    h.chevron:SetWidth(12)
    h.chevron:SetHeight(12)
    Palette.paint(h.chevron, "SetVertexColor", "text")
    h.rank = text(line, "muted", "RIGHT")
    h.dots = { QP.dot(line), QP.dot(line), QP.dot(line) }
    h.name = text(line, "text")
    h.bar = QP.bar(line)
    h.sum = text(line, "muted")
    h.old = text(line, "muted", "RIGHT")
    h.pill = QP.pill(line)
    h.pill:SetWidth(54)
    h.win = text(line, "muted", "RIGHT")
    line.head = h

    return h
  end

  local function makeFlow(line)
    local f = {}
    f.rank = text(line, "muted", "RIGHT")
    f.kind = QP.pill(line)
    f.key = text(line, "text")
    f.pips = QP.pips(line)
    f.cnt = text(line, "muted")
    f.state = QP.pill(line)
    f.wait = QP.pill(line)
    f.wait:SetWidth(54)
    f.eta = text(line, "muted", "RIGHT")
    line.flow = f

    return f
  end

  local function skinLine(line, st, mode)
    local key = mode .. st.id
    if line.skinKey == key then
      return
    end

    line.skinKey = key
    if mode == "head" then
      line:SetBackdrop(backdropOf(st.shape, st.radius))
      tint(line, "SetBackdropColor", st.headBg, 1)
      tint(line, "SetBackdropBorderColor", st.shape == "bevel" and "shadow" or st.headEdge, st.edgeAlpha)
      line.bg:Hide()
      line.guide:Hide()
    else
      line:SetBackdrop(nil)
      tint(line.bg, "SetVertexColor", st.bodyBg, 1)
      tint(line.guide, "SetVertexColor", "borderDim", 0.6)
      line.bg:Show()
      if st.guide then
        line.guide:Show()
      else
        line.guide:Hide()
      end
    end

    tint(line.hover, "SetVertexColor", "rowHover", 0.5)
  end

  local function paintHead(self, line, item, st, width)
    local h = line.head or makeHead(line)
    local gr = item.g
    local open = self:isOpen(gr)
    local isHot = hot(self, item)
    local oldLevel = QP.level(gr.oldest, QP.LIMITS.wait)
    local summary
    if gr.held then
      summary = format(word("QUEUEVIEW_GROUP_SUMMARY_HELD"), QP.number(#gr.flows), QP.number(gr.left), QP.number(gr.share), word("QUEUEVIEW_HELD_WORD_" .. tostring(gr.held)))
    else
      summary = format(word("QUEUEVIEW_GROUP_SUMMARY"), QP.number(#gr.flows), QP.number(gr.left), QP.number(gr.share))
    end

    local window
    if gr.e0 == nil then
      window = word("QUEUEVIEW_NONE")
    elseif gr.e0 < 0.05 then
      window = format(word("QUEUEVIEW_SPAN"), word("QUEUEVIEW_NOW"), QP.duration(gr.e1))
    else
      window = format(word("QUEUEVIEW_IN"), QP.span(gr.e0, gr.e1))
    end

    local name = labelOf(gr)
    local lanes = concat(gr.lanes, ",")
    local sig = concat({ st.id, width, item.rank, tostring(open), tostring(isHot), name, lanes, floor(gr.left * 1000 / max(1, self.total)), summary,
      QP.seconds(gr.oldest), oldLevel, window }, "\2")
    if same(line.mem, sig) then
      return
    end

    self.paints = self.paints + 1
    local nd = #gr.lanes
    local nameW = clamp(floor(width * 0.17), 110, 200)
    local nameX = 54 + nd * 11 + 2
    h.chevron:ClearAllPoints()
    h.chevron:SetPoint("LEFT", line, "LEFT", 6, 0)
    Bricks.turn(h.chevron, open)
    h.rank:ClearAllPoints()
    h.rank:SetPoint("LEFT", line, "LEFT", 22, 0)
    h.rank:SetWidth(26)
    h.rank:SetText(tostring(item.rank))
    for index, dot in ipairs(h.dots) do
      local frame = dot:Frame()
      if index <= nd then
        dot:Set(gr.lanes[index])
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", line, "LEFT", 54 + (index - 1) * 11, 0)
        frame:Show()
      else
        frame:Hide()
      end
    end

    h.name:ClearAllPoints()
    h.name:SetPoint("LEFT", line, "LEFT", nameX, 0)
    fit(h.name, name, nameW)
    local barFrame = h.bar:Frame()
    barFrame:ClearAllPoints()
    barFrame:SetPoint("LEFT", line, "LEFT", nameX + nameW + 8, 0)
    h.bar:Set(max(0.02, gr.left / max(1, self.total)), QP.laneColor(gr.lanes[1]))
    local sumX = nameX + nameW + 8 + (barFrame:GetWidth() or 60) + 8
    local rightBlock = 10 + 120 + 8 + 54 + 6 + 62 + 8
    h.sum:ClearAllPoints()
    h.sum:SetPoint("LEFT", line, "LEFT", sumX, 0)
    fit(h.sum, summary, max(40, width - sumX - rightBlock))
    h.win:ClearAllPoints()
    h.win:SetPoint("RIGHT", line, "RIGHT", -10, 0)
    fit(h.win, window, 120)
    h.win:SetJustifyH("RIGHT")
    local pillFrame = h.pill:Frame()
    pillFrame:ClearAllPoints()
    pillFrame:SetPoint("RIGHT", line, "RIGHT", -(10 + 120 + 8), 0)
    h.pill:Set(QP.seconds(gr.oldest), oldLevel)
    h.old:ClearAllPoints()
    h.old:SetPoint("RIGHT", pillFrame, "LEFT", -6, 0)
    h.old:SetWidth(62)
    h.old:SetText(word("QUEUEVIEW_GROUP_OLDEST"))
    if isHot then
      line.hover:Show()
    else
      line.hover:Hide()
    end
  end

  local function paintFlow(self, line, item, st, width)
    local f = line.flow or makeFlow(line)
    local fl, gr = item.flow, item.g
    local row = fl.row
    local isHot = hot(self, item)
    local waitLevel = QP.level(fl.age, QP.LIMITS.wait)
    local depart
    if fl.eta == nil then
      depart = word("QUEUEVIEW_NONE")
    elseif fl.eta < 0.05 then
      depart = word("QUEUEVIEW_NOW")
    else
      depart = format(word("QUEUEVIEW_IN"), QP.seconds(fl.eta))
    end

    local key = tostring(row.op or "")
    if row.detail and row.detail ~= "" then
      key = key .. " " .. tostring(row.detail)
    end

    local held = row.held and QP.heldText(row.held, num(row.heldFor)) or ""
    local kindText = (row.kind and row.kind ~= "whisper") and word("QUEUEVIEW_KIND_" .. tostring(row.kind)) or ""
    local sig = concat({ st.id, width, tostring(row.pos), tostring(isHot), key, fl.left, fl.parts, held, kindText, tostring(row.lane),
      QP.seconds(fl.age), waitLevel, depart }, "\2")
    if same(line.mem, sig) then
      return
    end

    self.paints = self.paints + 1
    local keyW = clamp(floor(width * 0.25), 110, 260)
    local pipsX = 126 + keyW + 8
    f.rank:ClearAllPoints()
    f.rank:SetPoint("LEFT", line, "LEFT", 22, 0)
    f.rank:SetWidth(30)
    f.rank:SetText(row.pos ~= nil and tostring(row.pos) or "")
    local kindFrame = f.kind:Frame()
    if kindText ~= "" then
      kindFrame:ClearAllPoints()
      kindFrame:SetPoint("LEFT", line, "LEFT", 58, 0)
      f.kind:Set(kindText, nil)
      kindFrame:Show()
    else
      kindFrame:Hide()
    end

    f.key:ClearAllPoints()
    f.key:SetPoint("LEFT", line, "LEFT", 126, 0)
    fit(f.key, key, keyW)
    local pipsFrame = f.pips:Frame()
    pipsFrame:ClearAllPoints()
    pipsFrame:SetPoint("LEFT", line, "LEFT", pipsX, 0)
    f.pips:Set(fl.left, fl.parts, row.lane)
    f.cnt:ClearAllPoints()
    f.cnt:SetPoint("LEFT", line, "LEFT", pipsX + 79 + 8, 0)
    f.cnt:SetWidth(54)
    f.cnt:SetText(format("%s/%s", QP.number(fl.left), QP.number(fl.parts)))
    local stateFrame = f.state:Frame()
    if held ~= "" then
      stateFrame:ClearAllPoints()
      stateFrame:SetPoint("LEFT", line, "LEFT", pipsX + 79 + 8 + 58, 0)
      f.state:Set(held, "warn")
      stateFrame:Show()
    else
      stateFrame:Hide()
    end

    f.eta:ClearAllPoints()
    f.eta:SetPoint("RIGHT", line, "RIGHT", -10, 0)
    fit(f.eta, depart, 100)
    local waitFrame = f.wait:Frame()
    waitFrame:ClearAllPoints()
    waitFrame:SetPoint("RIGHT", line, "RIGHT", -(10 + 100 + 8), 0)
    f.wait:Set(QP.seconds(fl.age), waitLevel)
    if isHot then
      line.hover:Show()
    else
      line.hover:Hide()
    end
  end

  local function showMode(line, mode)
    if line.mode == mode then
      return
    end

    line.mode = mode
    local head, flow = line.head, line.flow
    if mode == "head" then
      if head then
        head.chevron:Show()
        head.rank:Show()
        head.name:Show()
        head.bar:Frame():Show()
        head.sum:Show()
        head.old:Show()
        head.pill:Frame():Show()
        head.win:Show()
      end

      if flow then
        flow.rank:Hide()
        flow.kind:Frame():Hide()
        flow.key:Hide()
        flow.pips:Frame():Hide()
        flow.cnt:Hide()
        flow.state:Frame():Hide()
        flow.wait:Frame():Hide()
        flow.eta:Hide()
      end
    else
      if head then
        head.chevron:Hide()
        head.rank:Hide()
        head.name:Hide()
        head.bar:Frame():Hide()
        head.sum:Hide()
        head.old:Hide()
        head.pill:Frame():Hide()
        head.win:Hide()
        for _, dot in ipairs(head.dots) do
          dot:Frame():Hide()
        end
      end

      if flow then
        flow.rank:Show()
        flow.key:Show()
        flow.pips:Frame():Show()
        flow.cnt:Show()
        flow.wait:Frame():Show()
        flow.eta:Show()
      end
    end

    line.mem.sig = nil
  end

  -- Paint the lines of the visible range; a line whose values did not change repaints nothing.
  function g:paint()
    local st, width, height = self.st, self.width, self.height
    if not st then
      return
    end

    local items, n = self.items, self.itemCount
    local offset = scroll:Offset() or 0
    local first, last = 1, n
    for index = 1, n do
      if items[index].y + items[index].h > offset then
        first = index
        break
      end
    end

    for index = first, n do
      if items[index].y >= offset + height then
        last = index - 1
        break
      end
    end

    first, last = max(1, first - OVERSCAN), min(n, last + OVERSCAN)
    local used = 0
    for index = first, last do
      used = used + 1
      local line = self.lines[used] or newLine(self)
      local item = items[index]
      local mode = item.flow and "flow" or "head"
      showMode(line, mode)
      skinLine(line, st, mode)
      line.item = item
      local key = item.y .. "|" .. item.h .. "|" .. width
      if line.place ~= key then
        line.place = key
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -item.y)
        line:SetWidth(width)
        line:SetHeight(item.h)
      end

      line:Show()
      if mode == "head" then
        paintHead(self, line, item, st, width)
      else
        paintFlow(self, line, item, st, width)
      end
    end

    for index = used + 1, #self.lines do
      local line = self.lines[index]
      line.item = nil
      line:Hide()
    end

    self.visibleLines = used
  end

  function g:layout()
    local st = self.st
    local order, items, n = self.order, self.items, 0
    local y = 0
    for _, gr in ipairs(order) do
      n = n + 1
      items[n] = items[n] or {}
      local item = items[n]
      item.g, item.flow, item.rank, item.y, item.h = gr, nil, gr.rank, y, st.headH
      y = y + st.headH
      if self:isOpen(gr) then
        for _, flow in ipairs(gr.flows) do
          n = n + 1
          items[n] = items[n] or {}
          item = items[n]
          item.g, item.flow, item.rank, item.y, item.h = gr, flow, nil, y, st.rowH
          y = y + st.rowH
        end
      end
    end

    self.itemCount, self.contentHeight = n, y
    self.width, self.height = self:size()
    scroll:SetView(self.width, self.height)
    scroll:SetContentHeight(y)
    self:paint()
  end

  function g:resort()
    local order = self.groups
    local mode = self.sortMode
    sort(order, function(a, b)
      if mode == "az" then
        local la, lb = lower(labelOf(a)), lower(labelOf(b))
        if la ~= lb then
          return la < lb
        end
      elseif mode == "wait" then
        if a.oldest ~= b.oldest then
          return a.oldest > b.oldest
        end
      end

      return a.first < b.first
    end)

    for index, gr in ipairs(order) do
      gr.rank = index
    end

    self.order = order
    for index, button in ipairs(self.sortButtons) do
      button:SetSelected(SORTS[index] == mode)
    end
  end

  function g:SetSort(mode)
    if self.sortMode ~= mode then
      self.sortMode = mode
      self:resort()
      self:layout()
    end
  end

  function g:SetAll(open)
    for _, gr in ipairs(self.groups) do
      setOpen(self, gr, open)
    end

    self:layout()
  end

  function g:Toggle(gr)
    setOpen(self, gr, not self:isOpen(gr))
    self:layout()
  end

  function g:Open(who, scrollTo)
    for _, gr in ipairs(self.groups) do
      if gr.who == who then
        setOpen(self, gr, true)
        self:layout()
        if scrollTo then
          for index = 1, self.itemCount do
            local item = self.items[index]
            if item.g == gr and not item.flow then
              scroll:SetOffset(item.y)
              break
            end
          end

          self:paint()
        end

        return true
      end
    end

    return false
  end

  function g:Highlight(who, fid)
    if who == nil then
      self.hl = nil
    else
      self.hl = { who = who, fid = fid }
    end

    self:paint()
  end

  function g:SetRows(rows, snap)
    local interval = snap and tonumber(snap.interval)
    if not interval or interval <= 0 then
      local Queue = EbonAPI.Queue
      interval = Queue and tonumber(Queue.SEND_INTERVAL) or 0.5
    end

    local list = groupRows(rows, interval)
    local total = 0
    for _, gr in ipairs(list) do
      total = total + gr.left
    end

    self.total = max(1, total)
    shares(list, self.total)
    self.groups = list
    self.rowCount = #(rows or {})
    self.st = readSkin()

    local at = GetTime()
    local present = {}
    for _, gr in ipairs(list) do
      present[gr.ident] = true
      local state = self.opened[gr.ident]
      if state then
        state.seen = at
      end
    end

    for ident, state in pairs(self.opened) do
      if not present[ident] and at - state.seen > FORGET then
        self.opened[ident] = nil
      end
    end

    self:resort()
    if not self.filled and #list > 0 then
      self.filled = true
      if self.order[1] and not self.opened[self.order[1].ident] then
        setOpen(self, self.order[1], true)
      end
    end

    local line = format(word("QUEUEVIEW_GROUPS_COUNT"), QP.number(#list), QP.number(self.rowCount))
    if self.countText ~= line then
      self.countText = line
      count:SetText(line)
    end

    if #list == 0 then
      empty:Show()
    else
      empty:Hide()
    end

    self:layout()
  end

  scroll.bar:HookScript("OnValueChanged", function()
    if g.st then
      g:paint()
    end
  end)

  root:SetScript("OnSizeChanged", function()
    if g.st then
      g:layout()
    end
  end)

  g:resort()

  return g
end
