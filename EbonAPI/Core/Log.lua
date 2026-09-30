EbonAPI = EbonAPI or {}
EbonAPI.Log = {}

local Log = EbonAPI.Log
local Lib = EbonAPI.Lib
local Handle = EbonAPI.Handle

local type, tostring, select = type, tostring, select
local format, concat = string.format, table.concat

Log.COLOR = {
  RESET = "|r",
}

local COLOR = Log.COLOR

local function join(...)
  local count = select("#", ...)

  if count == 1 then
    return tostring((...))
  end

  local parts = {}

  for index = 1, count do
    parts[index] = tostring((select(index, ...)))
  end

  return concat(parts, " ")
end

local function emit(owner, color, text)
  if not DEFAULT_CHAT_FRAME then
    return
  end

  DEFAULT_CHAT_FRAME:AddMessage(
    COLOR.PREFIX .. "[" .. (owner or "EbonAPI") .. "]" .. COLOR.RESET
      .. " " .. color .. text .. COLOR.RESET)
end

local CAPACITY = 128

Log.CAPACITY = CAPACITY

local tAt, tKind, tOwner, tA, tB = {}, {}, {}, {}, {}
local cursor = 0
local filled = 0

local debugOwners = {}
local debugAll = false
local kindsSeen = {}

function Log.trace(kind, owner, a, b, at)
  cursor = cursor % CAPACITY + 1

  tAt[cursor] = at or (GetTime and GetTime() or 0)
  tKind[cursor] = kind
  tOwner[cursor] = owner
  tA[cursor] = a
  tB[cursor] = b
  kindsSeen[kind] = true

  if filled < CAPACITY then
    filled = filled + 1
  end
end

function Log.count(kind)
  local total = 0

  for index = 1, filled do
    if tKind[index] == kind then
      total = total + 1
    end
  end

  return total
end

function Log.kinds()
  return Lib.sortedKeys(kindsSeen)
end

function Log.isDebug(owner)
  return debugAll or debugOwners[owner] == true
end

function Log.setDebug(owner, enabled)
  if owner == nil or owner == "*" then
    debugAll = enabled and true or false
    return debugAll
  end

  debugOwners[owner] = enabled and true or nil

  return debugOwners[owner] == true
end

local function describe(a, b)
  if type(a) == "number" then
    local opcodes = EbonAPI.Opcodes
    local text = opcodes and opcodes.describe(a) or ("opcode " .. a)

    if b then
      return text .. "  " .. b .. "B"
    end

    return text
  end

  if b then
    return tostring(a) .. " " .. tostring(b)
  end

  return tostring(a)
end

function Log.dump(limit, kind)
  local lines = {}
  local now = GetTime and GetTime() or 0

  limit = limit or 20

  local index = cursor

  for _ = 1, filled do
    if not kind or tKind[index] == kind then
      lines[#lines + 1] = format("%6.1fs  %-5s  %-14s  %s",
        now - tAt[index], tKind[index], tOwner[index] or "-", describe(tA[index], tB[index]))

      if #lines >= limit then
        break
      end
    end

    index = index - 1

    if index == 0 then
      index = filled
    end
  end

  if #lines == 0 then
    return "empty trace"
  end

  return concat(lines, "\n")
end

function Log.print(owner, ...)
  emit(owner, COLOR.TEXT, join(...))
end

function Log.warn(owner, ...)
  local text = join(...)

  Log.trace("warn", owner, text)
  emit(owner, COLOR.WARN, text)
end

function Log.success(owner, ...)
  emit(owner, COLOR.SUCCESS, join(...))
end

function Log.error(owner, ...)
  local text = join(...)

  Log.trace("error", owner, text)
  Lib.report("[" .. (owner or "EbonAPI") .. "] " .. text)
end

function Log.debug(owner, ...)
  if not (debugAll or debugOwners[owner]) then
    return
  end

  emit(owner, COLOR.MUTED, join(...))
end

function Handle:Print(...)
  Log.print(self.addonName, ...)
end

function Handle:Warn(...)
  Log.warn(self.addonName, ...)
end

function Handle:Error(...)
  Log.error(self.addonName, ...)
end

function Handle:Success(...)
  Log.success(self.addonName, ...)
end

function Handle:Debug(...)
  Log.debug(self.addonName, ...)
end

function Handle:SetDebug(enabled)
  return Log.setDebug(self.addonName, enabled)
end

function Handle:IsDebug()
  return Log.isDebug(self.addonName)
end
