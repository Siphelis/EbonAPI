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

function Lib.report(err, owner)
  local Catch = EbonAPI.Catch

  EbonAPI.Log.trace("error", owner, tostring(err))
  Catch.report(err, owner)

  return Catch.forward(err)
end

local function upperLatin(second)
  local code = byte(second)

  if code == 183 then
    return "\195\183"
  end

  return "\195" .. char(code - 32)
end

function Lib.upper(text)
  text = gsub(upper(text or ""), "\195([\160-\190])", upperLatin)
  text = gsub(text, "\195\191", "\197\184")
  text = gsub(text, "\195\159", "SS")

  return (gsub(text, "\197\147", "\197\146"))
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

function Lib.safeCall(fn, ...)
  local ok, err = pcall(fn, ...)

  if not ok then
    Lib.report(err)
  end

  return ok
end

function Lib.safeGet(fn, ...)
  local ok, result = pcall(fn, ...)

  if not ok then
    Lib.report(result)
    return nil, result
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

function Lib.setShown(widget, shown)
  if shown then
    widget:Show()
  else
    widget:Hide()
  end
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
      if target[key] == nil then
        target[key] = {}
      end

      if type(target[key]) == "table" then
        Lib.applyDefaults(target[key], value)
      end
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
    local numberA, numberB = type(a) == "number", type(b) == "number"

    if numberA and numberB then
      return a < b
    end

    if numberA ~= numberB then
      return numberA
    end

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

  local following = byte(body, stop + 1)

  while stop > start and following >= 128 and following <= 191 do
    stop = stop - 1
    following = byte(body, stop + 1)
  end

  while stop < length and following >= 128 and following <= 191 do
    stop = stop + 1
    following = byte(body, stop + 1)
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

-- LZW codec for the texts EbonAPI keeps for addons that are not loaded (Share.lua, packed values).
-- Codes of 9 to 12 bits (the width follows the number of codes already read, on both sides), dictionary
-- of 4096 entries that stops growing when full and starts again for each value; the bytes are written
-- in base 85 with 85 printable characters that are neither a backtick, a double quote, a backslash
-- nor a pipe (4 bytes become 5 characters, the last group of 1 to 3 bytes becomes 2 to 4 characters,
-- least significant digit first). No bit operators in this Lua: floor-free arithmetic on numbers.
-- Both directions work in tables kept between calls (the compressor's dictionary is a trie in three
-- arrays indexed by code, nothing to clear between two values; the decompressor keeps one number per code = (length * 4096 + prefix) * 256 +
-- last byte and rebuilds each phrase from the end in a byte buffer cut into strings of about 1 KB);
-- the buffers hold one-character strings (made once) and are cut with table.concat, so that the only
-- strings made are those pieces and the final result. Lib.lzwFree gives the tables back.
-- Every string made by table.concat stays within LZW_PIECE = 512 bytes, so that the concat fills one
-- luaL_Buffer (LUAL_BUFFERSIZE = BUFSIZ: 8192 with lupa, 512 with the MSVC stdio.h, NOT verified for the
-- client) and makes no intermediate string: 512 one-byte items fit exactly, the 513th would push a
-- 512-byte string. The compressor cuts its output at LZW_OUT = 510 (its items come five at a time).
local LZW_PIECE, LZW_OUT, LZW_JOIN = 512, 510, 66
local lzwAlpha, lzwDigit, lzwTwo, lzwChar = {}, {}, {}, {}
local lzwBuf, lzwParts, lzwHead, lzwSib, lzwByte, lzwEntry = {}, {}, {}, {}, {}, nil
local lzwNo, lzwNp = 0, 0
local lzwCap, lzwOver = 0, false
local lzwS1, lzwS2, lzwS3, lzwSn = 0, 0, 0, 0
local lzwAcc, lzwBits, lzwWidth, lzwLimit, lzwK = 0, 0, 9, 512, 0
local lzwN, lzwPrev, lzwPlen, lzwFirst, lzwPos = 256, -1, 0, 0, 0

do
  local count = 0

  for code = 33, 126 do
    if count < 85 and code ~= 34 and code ~= 92 and code ~= 96 and code ~= 124 then
      lzwAlpha[count] = char(code)
      lzwDigit[code] = count
      count = count + 1
    end
  end

  for bit = 0, 24 do
    lzwTwo[bit] = 2 ^ bit
  end

  for value = 0, 255 do
    lzwChar[value] = char(value)
  end
end

local function lzwFlush()
  lzwNp = lzwNp + 1
  lzwParts[lzwNp] = concat(lzwBuf, "", 1, lzwNo)
  lzwNo = 0
end

-- Joins lzwParts[1..count] into one string with the `..` operator, which builds its result in a single
-- allocation (table.concat above its buffer makes intermediate strings: measured 2.9 x the result for
-- 30 KB). 66 pieces per `..` (= 32 KB / 512 + 2, one level for Share.TEXT_MAX), written inline (a call
-- with many arguments would make the Lua stack grow; 66 operands use 66 registers, the limit is 250);
-- the pieces are left in the table (the caller clears them).
-- Cost: the pieces (1 x the text) plus 1 x the text for each level of 66 pieces, so 2 x up to
-- 66 * 512 = 33 KB, 3 x up to 2.2 MB.
local function lzwJoin(count)
  local parts = lzwParts

  while count > 1 do
    local last = count + 65 - (count - 1) % 66

    for index = count + 1, last do
      parts[index] = ""
    end

    local made = 0

    for index = 1, last, 66 do
      made = made + 1
      parts[made] = parts[index] .. parts[index + 1] .. parts[index + 2] .. parts[index + 3]
        .. parts[index + 4] .. parts[index + 5] .. parts[index + 6] .. parts[index + 7]
        .. parts[index + 8] .. parts[index + 9] .. parts[index + 10] .. parts[index + 11]
        .. parts[index + 12] .. parts[index + 13] .. parts[index + 14] .. parts[index + 15]
        .. parts[index + 16] .. parts[index + 17] .. parts[index + 18] .. parts[index + 19]
        .. parts[index + 20] .. parts[index + 21] .. parts[index + 22] .. parts[index + 23]
        .. parts[index + 24] .. parts[index + 25] .. parts[index + 26] .. parts[index + 27]
        .. parts[index + 28] .. parts[index + 29] .. parts[index + 30] .. parts[index + 31]
        .. parts[index + 32] .. parts[index + 33] .. parts[index + 34] .. parts[index + 35]
        .. parts[index + 36] .. parts[index + 37] .. parts[index + 38] .. parts[index + 39]
        .. parts[index + 40] .. parts[index + 41] .. parts[index + 42] .. parts[index + 43]
        .. parts[index + 44] .. parts[index + 45] .. parts[index + 46] .. parts[index + 47]
        .. parts[index + 48] .. parts[index + 49] .. parts[index + 50] .. parts[index + 51]
        .. parts[index + 52] .. parts[index + 53] .. parts[index + 54] .. parts[index + 55]
        .. parts[index + 56] .. parts[index + 57] .. parts[index + 58] .. parts[index + 59]
        .. parts[index + 60] .. parts[index + 61] .. parts[index + 62] .. parts[index + 63]
        .. parts[index + 64] .. parts[index + 65]
    end

    for index = made + 1, last do
      parts[index] = nil
    end

    count = made
  end

  return parts[1]
end

local function lzwPut(byteValue)
  if lzwSn == 0 then
    lzwS1, lzwSn = byteValue, 1
  elseif lzwSn == 1 then
    lzwS2, lzwSn = byteValue, 2
  elseif lzwSn == 2 then
    lzwS3, lzwSn = byteValue, 3
  else
    local value = lzwS1 + lzwS2 * 256 + lzwS3 * 65536 + byteValue * 16777216

    lzwSn = 0

    for _ = 1, 5 do
      local digit = value % 85

      value = (value - digit) / 85
      lzwNo = lzwNo + 1
      lzwBuf[lzwNo] = lzwAlpha[digit]
    end

    if lzwNo >= LZW_OUT then
      lzwFlush()

      -- a packed text as long as the text is dropped anyway: stop making pieces (at most 65)
      if lzwNp * LZW_OUT >= lzwCap then
        lzwOver = true
      end
    end
  end
end

local function lzwEmit(code)
  lzwK = lzwK + 1

  local top = 254 + lzwK

  if top >= lzwLimit and lzwLimit < 4096 then
    lzwWidth, lzwLimit = lzwWidth + 1, lzwLimit * 2
  end

  lzwAcc = lzwAcc + code * lzwTwo[lzwBits]
  lzwBits = lzwBits + lzwWidth

  while lzwBits >= 8 do
    local low = lzwAcc % 256

    lzwAcc = (lzwAcc - low) / 256
    lzwBits = lzwBits - 8
    lzwPut(low)
  end
end

-- The text packed, or nil when the packed form would not be shorter (keep the text as it is).
function Lib.lzwPack(text)
  local size = len(text)

  if size < 2 then
    return nil
  end

  local head, sibling, last = lzwHead, lzwSib, lzwByte
  local nextCode = 256
  local phrase = byte(text, 1)

  for code = 0, 255 do
    head[code] = 0
  end

  lzwNo, lzwNp, lzwSn, lzwAcc, lzwBits, lzwWidth, lzwLimit, lzwK = 0, 0, 0, 0, 0, 9, 512, 0

  lzwCap, lzwOver = size, false

  for index = 2, size do
    local value = byte(text, index)
    local child = head[phrase]

    while child ~= 0 and last[child] ~= value do
      child = sibling[child]
    end

    if child ~= 0 then
      phrase = child
    else
      lzwEmit(phrase)

      if lzwOver then
        for part = 1, lzwNp do
          lzwParts[part] = nil
        end

        lzwNo, lzwNp, lzwOver = 0, 0, false

        return nil
      end

      if nextCode < 4096 then
        head[nextCode] = 0
        last[nextCode] = value
        sibling[nextCode] = head[phrase]
        head[phrase] = nextCode
        nextCode = nextCode + 1
      end

      phrase = value
    end
  end

  lzwEmit(phrase)

  if lzwBits > 0 then
    lzwPut(lzwAcc)
  end

  if lzwSn > 0 then
    local count = lzwSn
    local value = lzwS1 + (count > 1 and lzwS2 or 0) * 256 + (count > 2 and lzwS3 or 0) * 65536

    for _ = 1, count + 1 do
      local digit = value % 85

      value = (value - digit) / 85
      lzwNo = lzwNo + 1
      lzwBuf[lzwNo] = lzwAlpha[digit]
    end

    lzwSn = 0
  end

  local packed

  if lzwNp == 0 then
    packed = concat(lzwBuf, "", 1, lzwNo)
  else
    if lzwNo > 0 then
      lzwFlush()
    end

    packed = lzwJoin(lzwNp)
    lzwParts[1] = nil
  end

  lzwNo, lzwNp = 0, 0

  if len(packed) >= size then
    return nil
  end

  return packed
end

-- Writes the phrase of a code in the buffer (from its end) and gives its length and its first byte.
local function lzwWrite(code)
  local entry, buffer = lzwEntry, lzwBuf
  local value = entry[code]
  local last = value % 256
  local rest = (value - last) / 256
  local prefix = rest % 4096
  local size = (rest - prefix) / 4096
  local at = lzwPos + size

  buffer[at] = lzwChar[last]

  for _ = 2, size do
    value = entry[prefix]
    last = value % 256
    rest = (value - last) / 256
    prefix = rest % 4096
    at = at - 1
    buffer[at] = lzwChar[last]
  end

  lzwPos = lzwPos + size

  return size, last
end

-- Cuts the 512-byte pieces off the phrases written in the buffer, moves the rest (under 512) to its start.
local function lzwCut()
  local buffer, from = lzwBuf, 1

  while lzwPos - from >= LZW_PIECE - 1 do
    lzwNp = lzwNp + 1
    lzwParts[lzwNp] = concat(buffer, "", from, from + LZW_PIECE - 1)
    from = from + LZW_PIECE
  end

  local rest = lzwPos - from + 1

  for index = 1, rest do
    buffer[index] = buffer[from + index - 1]
  end

  lzwPos = rest
end

local function lzwStep(code)
  lzwK = lzwK + 1

  local size, first
  local nextCode = lzwN

  if code < nextCode then
    size, first = lzwWrite(code)

    if lzwPrev >= 0 and nextCode < 4096 then
      lzwEntry[nextCode] = ((lzwPlen + 1) * 4096 + lzwPrev) * 256 + first
      lzwN = nextCode + 1
    end
  elseif code == nextCode and lzwPrev >= 0 and nextCode < 4096 then
    lzwEntry[nextCode] = ((lzwPlen + 1) * 4096 + lzwPrev) * 256 + lzwFirst
    lzwN = nextCode + 1
    size, first = lzwWrite(code)
  else
    return false
  end

  lzwPrev, lzwPlen, lzwFirst = code, size, first

  -- the width of the next code, the same function of its rank as in lzwEmit
  if 255 + lzwK >= lzwLimit and lzwLimit < 4096 then
    lzwWidth, lzwLimit = lzwWidth + 1, lzwLimit * 2
  end

  if lzwPos >= LZW_PIECE then
    lzwCut()
  end

  return true
end

local function lzwFeed(byteValue)
  lzwAcc = lzwAcc + byteValue * lzwTwo[lzwBits]
  lzwBits = lzwBits + 8

  while lzwBits >= lzwWidth do
    local base = lzwTwo[lzwWidth]
    local code = lzwAcc % base

    lzwAcc = (lzwAcc - code) / base
    lzwBits = lzwBits - lzwWidth

    if not lzwStep(code) then
      return false
    end
  end

  return true
end

-- The text of a packed value, or nil when the value is not a valid packed text.
function Lib.lzwUnpack(data)
  local size = len(data)
  local entry = lzwEntry

  if not entry then
    entry = {}

    for code = 0, 255 do
      entry[code] = 4096 * 256 + code
    end

    lzwEntry = entry
  end

  lzwN, lzwPrev, lzwPlen, lzwFirst, lzwPos = 256, -1, 0, 0, 0
  lzwAcc, lzwBits, lzwWidth, lzwLimit, lzwK, lzwNp = 0, 0, 9, 512, 0, 0

  local good = true
  local full = size - size % 5

  for index = 1, full, 5 do
    local a, b, c, d, e = byte(data, index, index + 4)
    local value = (lzwDigit[a] or 1e10) + 85 * ((lzwDigit[b] or 1e10) + 85 * ((lzwDigit[c] or 1e10)
      + 85 * ((lzwDigit[d] or 1e10) + 85 * (lzwDigit[e] or 1e10))))

    if value >= 4294967296 then
      good = false
      break
    end

    local b1 = value % 256
    value = (value - b1) / 256
    local b2 = value % 256
    value = (value - b2) / 256
    local b3 = value % 256
    local b4 = (value - b3) / 256

    if not (lzwFeed(b1) and lzwFeed(b2) and lzwFeed(b3) and lzwFeed(b4)) then
      good = false
      break
    end
  end

  local rest = size - full

  if good and rest > 0 then
    if rest == 1 then
      good = false
    else
      local value = 0

      for index = size, full + 1, -1 do
        value = value * 85 + (lzwDigit[byte(data, index)] or 1e10)
      end

      if value >= 4294967296 then
        good = false
      else
        for _ = 1, rest - 1 do
          local low = value % 256

          value = (value - low) / 256

          if not lzwFeed(low) then
            good = false
            break
          end
        end
      end
    end
  end

  local result

  if good then
    if lzwNp == 0 then
      result = concat(lzwBuf, "", 1, lzwPos)
    else
      if lzwPos > 0 then
        lzwNo = lzwPos
        lzwFlush()
      end

      result = lzwJoin(lzwNp)
    end
  end

  -- lzwJoin leaves nothing but lzwParts[1] (or, when the data was invalid, the pieces made so far)
  for index = 1, lzwNp do
    lzwParts[index] = nil
  end

  lzwNp, lzwNo, lzwPos = 0, 0, 0

  return result
end

-- Gives back the tables kept between two calls (about 80 KB after a decompression).
function Lib.lzwFree()
  lzwBuf, lzwParts, lzwHead, lzwSib, lzwByte, lzwEntry = {}, {}, {}, {}, {}, nil
end
