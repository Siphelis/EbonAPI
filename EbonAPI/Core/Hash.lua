EbonAPI = EbonAPI or {}
EbonAPI.Hash = {}

local Hash = EbonAPI.Hash

local byte, sub, len, concat = string.byte, string.sub, string.len, table.concat
local floor = math.floor
local bxor = bit.bxor

local TWO32 = 4294967296
local LOW24 = 16777216
local OFFSET_HI, OFFSET_LO = 3421674724, 2216829733
local ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"

Hash.LENGTH = 11

local digits = {}

for index = 0, 63 do
  digits[index] = sub(ALPHABET, index + 1, index + 1)
end

function Hash.fnv64(text)
  local hi, lo = OFFSET_HI, OFFSET_LO

  for index = 1, len(text) do
    local low8 = lo % 256

    lo = lo - low8 + bxor(low8, byte(text, index))

    local product = lo * 435

    hi = (hi * 435 + floor(product / TWO32) + (lo % LOW24) * 256) % TWO32
    lo = product % TWO32
  end

  return hi, lo
end

local out = {}

function Hash.encode64(hi, lo)
  for index = 11, 7, -1 do
    local digit = lo % 64

    out[index] = digits[digit]
    lo = floor(lo / 64)
  end

  out[6] = digits[lo + (hi % 16) * 4]
  hi = floor(hi / 16)

  for index = 5, 1, -1 do
    local digit = hi % 64

    out[index] = digits[digit]
    hi = floor(hi / 64)
  end

  return concat(out, "", 1, 11)
end

-- 64-bit sums over two 32-bit halves (exact in a double): the order of the terms never matters.
function Hash.add(hi, lo, hi2, lo2)
  lo = lo + lo2

  if lo >= TWO32 then
    return (hi + hi2 + 1) % TWO32, lo - TWO32
  end

  return (hi + hi2) % TWO32, lo
end

function Hash.sub(hi, lo, hi2, lo2)
  lo = lo - lo2

  if lo < 0 then
    return (hi - hi2 - 1) % TWO32, lo + TWO32
  end

  return (hi - hi2) % TWO32, lo
end

function Hash.digest(text)
  return Hash.encode64(Hash.fnv64(text))
end

function Hash.before(a, b)
  local la, lb = len(a), len(b)
  local size = la < lb and la or lb

  for index = 1, size do
    local x, y = byte(a, index), byte(b, index)

    if x ~= y then
      return x < y
    end
  end

  return la < lb
end
