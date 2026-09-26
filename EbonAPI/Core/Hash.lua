EbonAPI = EbonAPI or {}
EbonAPI.Hash = {}

local Hash = EbonAPI.Hash

local byte, sub, len, concat = string.byte, string.sub, string.len, table.concat
local floor = math.floor

local TWO32 = 4294967296
local LOW24 = 16777216
local OFFSET_HI, OFFSET_LO = 3421674724, 2216829733
local ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"

Hash.LENGTH = 11

local digits = {}

for index = 0, 63 do
  digits[index] = sub(ALPHABET, index + 1, index + 1)
end

local function xor8(a, b)
  local result, weight = 0, 1

  for _ = 1, 8 do
    local x, y = a % 2, b % 2

    if x ~= y then
      result = result + weight
    end

    a, b, weight = floor(a / 2), floor(b / 2), weight * 2
  end

  return result
end

function Hash.fnv64(text)
  local hi, lo = OFFSET_HI, OFFSET_LO

  for index = 1, len(text) do
    local low8 = lo % 256

    lo = lo - low8 + xor8(low8, byte(text, index))

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

function Hash.digest(text)
  return Hash.encode64(Hash.fnv64(text))
end

function Hash.before(a, b)
  local size = len(a) < len(b) and len(a) or len(b)

  for index = 1, size do
    local x, y = byte(a, index), byte(b, index)

    if x ~= y then
      return x < y
    end
  end

  return len(a) < len(b)
end
