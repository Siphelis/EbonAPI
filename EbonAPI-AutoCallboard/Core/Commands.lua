local Core = AutoCallboardCore or {}
AutoCallboardCore = Core
local L = AutoCallboardLocale

local tonumber = tonumber

local trim = Core.trim

local BOOLEAN_TRUE_WORDS = { on = true, ["true"] = true, yes = true }
local BOOLEAN_FALSE_WORDS = { off = true, ["false"] = true, no = true }

local function parseBoolean(rest)
  local lowered = rest:lower()

  if BOOLEAN_TRUE_WORDS[lowered] then
    return true
  end

  if BOOLEAN_FALSE_WORDS[lowered] then
    return false
  end

  return nil
end

local DEBUG_COMMANDS = {
  etrace = "etrace",
  eventtrace = "etrace",
  inspect = "inspect",
  dump = "dump",
  cooldown = "cooldown",
  cd = "cooldown",
  log = "logs",
  logs = "logs",
  clearlogs = "clearlogs",
}

local function parseText(rest, usage, field)
  if rest == "" then
    return { kind = "invalid", message = L[usage] }
  end

  return { kind = "set", field = field, value = rest }
end

local function parseDebugFlag(rest, usage, action)
  local value = parseBoolean(rest)

  if value == nil then
    return { kind = "invalid", message = L[usage] }
  end

  return { kind = "debug", action = action, value = value }
end

local SLASH_PARSERS = {
  name = function(rest) return parseText(rest, "USAGE_NAME", "targetName") end,
  debug = function(rest)
    if rest == "" then
      return { kind = "debug", action = "open" }
    end

    return parseDebugFlag(rest, "USAGE_DEBUG", "enabled")
  end,
  watch = function(rest) return parseDebugFlag(rest, "USAGE_WATCH", "mouseWatch") end,
  sniff = function(rest)
    local lowered = rest:lower()

    if rest == "" or lowered == "dump" then
      return { kind = "debug", action = "sniffDump" }
    end

    if lowered == "clear" then
      return { kind = "debug", action = "sniffClear" }
    end

    return parseDebugFlag(rest, "USAGE_SNIFF", "sniffer")
  end,
}

SLASH_PARSERS.sniffer = SLASH_PARSERS.sniff

function Core.parseSlash(input)
  local message = trim(input)

  if message == "" then
    return { kind = "version" }
  end

  local command, rest = message:match("^(%S+)%s*(.-)$")
  command = command and command:lower() or ""
  rest = trim(rest)

  local debugAction = DEBUG_COMMANDS[command]
  if debugAction then
    return { kind = "debug", action = debugAction }
  end

  local parser = SLASH_PARSERS[command]
  if parser then
    local parsed = parser(rest)

    if parsed.kind == "invalid" then
      parsed.command = command
      parsed.value = rest
    end

    return parsed
  end

  return { kind = "unknown", command = command }
end
