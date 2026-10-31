EbonAPI = EbonAPI or {}
local Treemap = {}
EbonAPI.Treemap = Treemap

local floor, min, max = math.floor, math.min, math.max
local HUGE = math.huge
local QUANTUM = 1000000

local function valid(v)
  return type(v) == "number" and v == v and v > 0 and v < HUGE
end

local function before(a, b)
  if a.value ~= b.value then return a.value > b.value end
  local ia, ib = a.id, b.id
  if type(ia) == type(ib) and (type(ia) == "number" or type(ia) == "string") then
    if ia ~= ib then return ia < ib end
  else
    ia, ib = tostring(ia), tostring(ib)
    if ia ~= ib then return ia < ib end
  end
  return a.order < b.order
end

local function sorted(items)
  local list = {}
  for i = 1, #(items or {}) do
    local it = items[i]
    if type(it) == "table" and valid(it.value) then
      list[#list + 1] = { id = it.id, value = it.value, order = i }
    end
  end
  table.sort(list, before)
  return list
end

local function worst(row, side)
  local sum, hi, lo = 0, 0, HUGE
  for i = 1, #row do
    local a = row[i].area
    sum = sum + a
    hi = max(hi, a)
    lo = min(lo, a)
  end
  local s2 = side * side
  return max(s2 * hi / (sum * sum), (sum * sum) / (s2 * lo))
end

local function place(row, rect, out)
  local sum = 0
  for i = 1, #row do sum = sum + row[i].area end
  if rect.w >= rect.h then
    local cw = min(sum / rect.h, rect.w)
    local y = rect.y
    for i = 1, #row do
      local ch = row[i].area / sum * rect.h
      out[#out + 1] = { id = row[i].id, x = rect.x, y = y, w = cw, h = ch }
      y = y + ch
    end
    rect.x = rect.x + cw
    rect.w = rect.w - cw
  else
    local ch = min(sum / rect.w, rect.h)
    local x = rect.x
    for i = 1, #row do
      local cw = row[i].area / sum * rect.w
      out[#out + 1] = { id = row[i].id, x = x, y = rect.y, w = cw, h = ch }
      x = x + cw
    end
    rect.y = rect.y + ch
    rect.h = rect.h - ch
  end
end

local function inset(cells, gap)
  if not (type(gap) == "number" and gap > 0) then return cells end
  for i = 1, #cells do
    local c = cells[i]
    local dx = min(gap / 2, c.w / 2)
    local dy = min(gap / 2, c.h / 2)
    c.x, c.y = c.x + dx, c.y + dy
    c.w, c.h = c.w - 2 * dx, c.h - 2 * dy
  end
  return cells
end

function Treemap.layout(items, w, h, gap)
  local out = {}
  if not (valid(w) and valid(h)) then return out end
  local list = sorted(items)
  if #list == 0 then return out end
  local total = 0
  for i = 1, #list do total = total + list[i].value end
  local scale = w * h / total
  for i = 1, #list do list[i].area = list[i].value * scale end
  local rect = { x = 0, y = 0, w = w, h = h }
  local row = {}
  local i = 1
  while i <= #list do
    local item = list[i]
    local side = min(rect.w, rect.h)
    if #row == 0 then
      row[1] = item
      i = i + 1
    else
      local with = {}
      for k = 1, #row do with[k] = row[k] end
      with[#with + 1] = item
      if worst(with, side) <= worst(row, side) then
        row = with
        i = i + 1
      else
        place(row, rect, out)
        row = {}
      end
    end
  end
  if #row > 0 then place(row, rect, out) end
  return inset(out, gap)
end

local function quantum(v)
  return floor(v * QUANTUM + 0.5) / QUANTUM
end

local function round(v)
  return floor(quantum(v) + 0.5)
end

function Treemap.snap(cells)
  local out = {}
  for i = 1, #(cells or {}) do
    local c = cells[i]
    local x1, y1 = round(c.x), round(c.y)
    local x2, y2 = round(c.x + c.w), round(c.y + c.h)
    out[i] = { id = c.id, x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
  end
  return out
end
