EbonAPI = EbonAPI or {}
EbonAPI.Lib = {}

local Lib = EbonAPI.Lib

local type, tonumber, pairs, next = type, tonumber, pairs, next
local tostring, pcall = tostring, pcall
local floor, abs, huge, max, min = math.floor, math.abs, math.huge, math.max, math.min
local concat, remove, sort = table.concat, table.remove, table.sort
local len, sub, gsub, match, find, byte = string.len, string.sub, string.gsub, string.match, string.find, string.byte
local char, upper = string.char, string.upper

Lib.floor = floor
Lib.abs = abs
Lib.max = max
Lib.min = min
Lib.concat = concat

function Lib.report(err)
  if geterrorhandler then
    local handler = geterrorhandler()

    if handler then
      handler(err)
      return true
    end
  end

  if DEFAULT_CHAT_FRAME then
    local COLOR = EbonAPI.Log.COLOR

    DEFAULT_CHAT_FRAME:AddMessage(COLOR.ERROR .. "[EbonAPI]" .. COLOR.RESET .. " " .. tostring(err))
  end

  return false
end

local function upperLatin(second)
  local code = byte(second)

  if code == 183 then
    return "\195\183"
  end

  return "\195" .. char(code - 32)
end

function Lib.upper(text)
  return (gsub(upper(text or ""), "\195([\160-\190])", upperLatin))
end

local ICONS = "Interface\\Icons\\"

function Lib.icon(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end

  if find(value, "[\\/]") then
    return value
  end

  return ICONS .. value
end

function Lib.safeCall(fn, a, b, c)
  local ok, err = pcall(fn, a, b, c)

  if not ok then
    Lib.report(err)
  end

  return ok
end

function Lib.safeGet(fn, a, b)
  local ok, result = pcall(fn, a, b)

  if not ok then
    Lib.report(result)
    return nil
  end

  return result
end

function Lib.num(value, fallback)
  value = tonumber(value)

  if not value or value ~= value or value == huge or value == -huge then
    return fallback or 0
  end

  return value
end

function Lib.int(value, fallback)
  return floor(Lib.num(value, fallback))
end

function Lib.bool(value)
  return value and true or false
end

function Lib.copper(value)
  return max(0, floor(Lib.num(value)))
end

function Lib.count(t)
  local total = 0

  for _ in pairs(t) do
    total = total + 1
  end

  return total
end

function Lib.isEmpty(t)
  return next(t) == nil
end

function Lib.copyShallow(source, target)
  target = target or {}

  for key, value in pairs(source) do
    target[key] = value
  end

  return target
end

function Lib.copyDeep(source, seen)
  if type(source) ~= "table" then
    return source
  end

  seen = seen or {}

  if seen[source] then
    return seen[source]
  end

  local copy = {}
  seen[source] = copy

  for key, value in pairs(source) do
    copy[key] = Lib.copyDeep(value, seen)
  end

  return copy
end

function Lib.applyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = {}
      end

      Lib.applyDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end

  return target
end

function Lib.indexOf(list, value)
  for index = 1, #list do
    if list[index] == value then
      return index
    end
  end

  return nil
end

function Lib.removeValue(list, value)
  local index = Lib.indexOf(list, value)

  if not index then
    return false
  end

  remove(list, index)

  return true
end

function Lib.keys(t, into)
  into = into or {}

  for key in pairs(t) do
    into[#into + 1] = key
  end

  return into
end

function Lib.sortedKeys(t)
  local keys = Lib.keys(t)

  sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)

  return keys
end

function Lib.trim(value)
  return (match(value, "^%s*(.-)%s*$"))
end

function Lib.split(value, separator, into)
  for index = #into, 1, -1 do
    into[index] = nil
  end

  if type(value) ~= "string" then
    return into, 0
  end

  local start = 1
  local count = 0
  local width = len(separator)

  while true do
    local stop = find(value, separator, start, true)

    count = count + 1

    if not stop then
      into[count] = sub(value, start)
      break
    end

    into[count] = sub(value, start, stop - 1)
    start = stop + width
  end

  return into, count
end

function Lib.stripColor(value)
  value = gsub(value, "|c%x%x%x%x%x%x%x%x", "")
  value = gsub(value, "|r", "")

  return value
end

function Lib.colorize(color, text)
  return color .. tostring(text) .. "|r"
end

function Lib.cutUtf8(body, start, budget)
  local length = len(body)
  local stop = start + budget - 1

  if stop >= length then
    return length
  end

  while stop > start do
    local following = byte(body, stop + 1)

    if following < 128 or following > 191 then
      break
    end

    stop = stop - 1
  end

  return stop
end

function Lib.splitUtf8(body, budget, into)
  local length = len(body)
  local start = 1
  local count = 0

  repeat
    local stop = Lib.cutUtf8(body, start, budget)

    count = count + 1
    into[count] = sub(body, start, stop)
    start = stop + 1
  until start > length

  for index = #into, count + 1, -1 do
    into[index] = nil
  end

  return into, count
end
