EbonAPI = EbonAPI or {}
EbonAPI.Format = {}

local Format = EbonAPI.Format
local Lib = EbonAPI.Lib
local L = EbonAPI.L

local tonumber, tostring = tonumber, tostring
local floor, abs, max = math.floor, math.abs, math.max
local format, len, sub = string.format, string.len, string.sub
local concat, insert = table.concat, table.insert

local GOLD = "|cffffd700"
local SILVER = "|cffc7c7cf"
local COPPER = "|cffeda55f"

function Format.number(value)
  value = Lib.num(value)

  local negative = value < 0
  local size = abs(value)
  local rounded = size % 1 == 0 and size or floor(size + 0.5)
  local text = format("%.0f", rounded)
  local grouped = ""

  while len(text) > 3 do
    grouped = " " .. sub(text, -3) .. grouped
    text = sub(text, 1, len(text) - 3)
  end

  grouped = text .. grouped

  if negative then
    return "-" .. grouped
  end

  return grouped
end

function Format.compact(value)
  value = Lib.num(value)

  local negative = value < 0
  local size = abs(value)
  local text

  if size >= 1000000000 then
    text = format("%.2fG", size / 1000000000)
  elseif size >= 1000000 then
    text = format("%.2fM", size / 1000000)
  elseif size >= 10000 then
    text = format("%.1fk", size / 1000)
  else
    return Format.number(value)
  end

  if negative then
    return "-" .. text
  end

  return text
end

function Format.percent(value)
  return format("%.1f%%", Lib.num(value))
end

function Format.pair(current, maximum)
  return Format.compact(current) .. " / " .. Format.compact(maximum)
end

function Format.rate(value)
  return Format.compact(value) .. (L.PER_HOUR or "/h")
end

function Format.bytes(value)
  value = Lib.num(value)

  if value >= 1048576 then
    return format("%.2f MB", value / 1048576)
  end

  return format("%.0f KB", value / 1024)
end

function Format.boolean(value)
  if value then
    return L.YES or "yes"
  end

  return L.NO or "no"
end

local function splitCopper(value)
  local total = Lib.copper(abs(Lib.num(value)))
  local gold = floor(total / 10000)
  local silver = floor((total - gold * 10000) / 100)

  return gold, silver, total - gold * 10000 - silver * 100
end

function Format.money(value)
  local gold, silver, copper = splitCopper(value)
  local parts = {}

  if gold > 0 then
    insert(parts, tostring(gold) .. "g")
  end

  if gold > 0 or silver > 0 then
    insert(parts, tostring(silver) .. "s")
  end

  insert(parts, tostring(copper) .. "c")

  local text = concat(parts, " ")

  if Lib.num(value) < 0 then
    return "-" .. text
  end

  return text
end

function Format.moneyRich(value)
  local gold, silver, copper = splitCopper(value)
  local parts = {}

  if gold > 0 then
    insert(parts, Format.number(gold) .. GOLD .. "g|r")
  end

  if gold > 0 or silver > 0 then
    insert(parts, silver .. SILVER .. "s|r")
  end

  insert(parts, copper .. COPPER .. "c|r")

  local text = concat(parts, " ")

  if Lib.num(value) < 0 then
    return "-" .. text
  end

  return text
end

function Format.duration(seconds)
  seconds = max(0, Lib.int(seconds))

  local hours = floor(seconds / 3600)
  local minutes = floor((seconds - hours * 3600) / 60)
  local rest = seconds - hours * 3600 - minutes * 60

  local h = L.UNIT_HOUR_SHORT or "h"
  local m = L.UNIT_MIN_SHORT or "m"
  local s = L.UNIT_SEC_SHORT or "s"

  if hours > 0 then
    return hours .. h .. " " .. minutes .. m
  end

  if minutes > 0 then
    return minutes .. m .. " " .. rest .. s
  end

  return rest .. s
end

function Format.seconds(value)
  return tostring(max(0, Lib.int(value))) .. (L.UNIT_SEC_SHORT or "s")
end

function Format.secondsRemaining(untilTime)
  if not untilTime or not GetTime then
    return 0
  end

  return max(0, untilTime - GetTime())
end

function Format.list(values, separator)
  if type(values) ~= "table" then
    return ""
  end

  local parts = {}

  for index = 1, #values do
    parts[index] = tostring(values[index])
  end

  return concat(parts, separator or ", ")
end
