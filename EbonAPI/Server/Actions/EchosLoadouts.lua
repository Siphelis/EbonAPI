local Actions = EbonAPI.Actions

local type, tostring, concat = type, tostring, table.concat
local gsub = string.gsub

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function perks()
  local pe = _G.ProjectEbonhold

  return type(pe) == "table" and type(pe.Perks) == "table" and pe.Perks or {}
end

local sanitizeName = EbonAPI.Actions.sanitize

local function classToken(class)
  local token = gsub(string.upper(tostring(class or "")), "[^A-Z]", "")

  if token == "" then
    local _, own = UnitClass("player")

    token = own or "UNKNOWN"
  end

  return token
end

local function busy()
  local p = perks()

  if p.pendingBuildSlotRequest and (GetTime and GetTime() or 0) - (p.pendingBuildSlotRequestAt or 0) <= 3 then
    return "ProjectEbonhold is busy with another build action (guard of 3 s)"
  end
end

local function slotCheck(minimum)
  return function(slot)
    if not integer(slot) or slot < minimum then
      return "the slot must be an integer of " .. minimum .. " or more"
    end
  end
end

local function slotBody(slot)
  return tostring(slot)
end

Actions.define({
  name = "RequestEchoDiscovery", cs = "REQUEST_ECHO_DISCOVERY", service = { "PerkService", "RequestEchoDiscovery" },
})

Actions.define({
  name = "RequestSharedLoadouts", cs = "REQUEST_ECHO_LOADOUTS_SHARED",
  service = { "PerkService", "RequestSharedEchoLoadouts" },
  check = function(class)
    if class ~= nil and type(class) ~= "string" then
      return "the class filter must be a string (a class token such as WARRIOR) or nil"
    end
  end,
  body = function(class)
    return (gsub(string.upper(tostring(class or "")), "[^A-Z]", ""))
  end,
})

local function echoesCheck(echoes)
  if type(echoes) ~= "table" or #echoes == 0 then
    return "the list of echoes must not be empty"
  end

  for index = 1, #echoes do
    local echo = echoes[index]

    if type(echo) ~= "table" or not integer(echo.spellId) or echo.spellId <= 0 then
      return "echo " .. index .. " has no valid spellId"
    end

    if echo.quality ~= nil and (not integer(echo.quality) or echo.quality < 0) then
      return "echo " .. index .. " has an invalid quality"
    end

    if echo.stacks ~= nil and (not integer(echo.stacks) or echo.stacks < 1) then
      return "echo " .. index .. " has an invalid stacks count"
    end
  end
end

Actions.define({
  name = "PublishEchoLoadout", cs = "REQUEST_ECHO_LOADOUT_PUBLISH",
  service = { "PerkService", "PublishEchoLoadout" },
  check = function(name, class, echoes)
    if type(name) ~= "string" then
      return "the name must be a string"
    end

    if class ~= nil and type(class) ~= "string" then
      return "the class must be a string or nil"
    end

    return echoesCheck(echoes)
  end,
  callArgs = function(name, class, echoes)
    return { name = name, class = class, echoes = echoes }
  end,
  body = function(name, class, echoes)
    local parts = {}

    for index = 1, #echoes do
      local echo = echoes[index]

      parts[index] = echo.spellId .. "." .. (echo.quality or 0) .. "." .. (echo.stacks or 1)
        .. (echo.avoid and ".1" or "")
    end

    return sanitizeName(name) .. "|" .. classToken(class) .. "|" .. concat(parts, ",")
  end,
})

Actions.define({
  name = "UnpublishEchoLoadout", cs = "REQUEST_ECHO_LOADOUT_UNPUBLISH",
  service = { "PerkService", "UnpublishEchoLoadout" },
  check = function(name, class)
    if type(name) ~= "string" or name == "" then
      return "the name must be a non empty string"
    end

    if class ~= nil and type(class) ~= "string" then
      return "the class must be a string or nil"
    end
  end,
  callArgs = function(name, class)
    return { name = name, class = class }
  end,
  body = function(name, class)
    return sanitizeName(name) .. "|" .. classToken(class)
  end,
})

Actions.define({
  name = "RenamePerkLoadout", cs = "REQUEST_PERK_LOADOUT_RENAME",
  service = { "PerkService", "RenameServerBuildSlot" },
  check = function(slot, name)
    local bad = slotCheck(1)(slot)

    if bad then
      return bad
    end

    if type(name) ~= "string" or name == "" then
      return "the name must be a non empty string"
    end
  end,
  body = function(slot, name)
    return tostring(slot) .. "|" .. sanitizeName(name)
  end,
  why = busy,
})

Actions.define({
  name = "DeletePerkLoadout", cs = "REQUEST_PERK_LOADOUT_DELETE",
  service = { "PerkService", "DeleteServerBuildSlot" },
  check = slotCheck(1), body = slotBody, why = busy,
})

Actions.define({
  name = "ActivatePerkLoadout", cs = "REQUEST_PERK_LOADOUT_ACTIVATE",
  service = { "PerkService", "ActivateServerBuildSlot" },
  check = slotCheck(0), body = slotBody, why = busy,
})

Actions.define({
  name = "UnlockPerkLoadoutSlot", cs = "REQUEST_PERK_LOADOUT_UNLOCK",
  service = { "PerkService", "UnlockServerBuildSlot" },
  why = busy,
})

Actions.define({
  name = "SetHiddenVisuals", cs = "REQUEST_HIDDEN_VISUALS_SET",
  check = function(echoMode, classMode)
    if (echoMode ~= 0 and echoMode ~= 1 and echoMode ~= 2) or (classMode ~= 0 and classMode ~= 1 and classMode ~= 2) then
      return "each mode must be 0 (shown), 1 (hide others) or 2 (hide all)"
    end
  end,
  body = function(echoMode, classMode)
    local mask = 0

    if echoMode >= 1 then
      mask = mask + 1
    end

    if echoMode == 2 then
      mask = mask + 2
    end

    if classMode >= 1 then
      mask = mask + 4
    end

    if classMode == 2 then
      mask = mask + 8
    end

    return tostring(mask)
  end,
})

Actions.define({
  name = "RequestPerkLoadouts", cs = "REQUEST_PERK_LOADOUTS", service = { "PerkService", "RequestServerBuildSlots" },
})
