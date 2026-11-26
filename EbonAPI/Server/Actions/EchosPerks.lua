local Actions = EbonAPI.Actions

local type, tostring, concat = type, tostring, table.concat

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function perks()
  local pe = _G.ProjectEbonhold

  return type(pe) == "table" and type(pe.Perks) == "table" and pe.Perks or {}
end

local spellCheck = EbonAPI.Actions.spellCheck
local spellBody = EbonAPI.Actions.spellBody

Actions.define({
  name = "RequestEchoChoice", cs = "REQUEST_PLAYER_PERK_CHOICE", service = { "PerkService", "RequestChoice" },
})

local selectEcho = Actions.define({
  name = "SelectEcho", cs = "REQUEST_PLAYER_PERK_SELECTION", service = { "PerkService", "SelectPerk" },
  check = spellCheck, body = spellBody,
  why = function(spellId)
    local p = perks()

    if p.pendingSelectSpellId then
      return "a pick is already in flight"
    end

    if type(p.currentChoice) ~= "table" then
      return "no echo choice on the table"
    end

    return "the spell is not one of the cards on the table"
  end,
})

local function clearCaller(...)
  EbonAPI.State.notePickCaller(nil)

  return ...
end

Actions.SelectEcho = function(...)
  local where = string.match(debugstack and debugstack(2, 1, 0) or "", "^(.-:%d+):") or "unknown"

  EbonAPI.State.notePickCaller(where)

  return clearCaller(selectEcho(...))
end

Actions.define({
  name = "RequestGrantedEchoes", cs = "REQUEST_PLAYER_GRANTED_PERKS",
  service = { "PerkService", "RequestGrantedPerks" },
})

Actions.define({
  name = "AddEchoStack", cs = "REQUEST_DEV_ADD_PERK_STACK", check = spellCheck, body = spellBody,
})

Actions.define({
  name = "RemoveEchoStack", cs = "REQUEST_DEV_REMOVE_PERK_STACK", check = spellCheck, body = spellBody,
})

Actions.define({
  name = "RequestOrbCharges", cs = "REQUEST_ORB_CHARGES", service = { "OrbService", "RequestCharges" },
})

Actions.define({
  name = "SpendOrbs", cs = "REQUEST_ORB_CONSUME",
  check = function(spellIds, orbCount)
    if type(spellIds) ~= "table" or #spellIds == 0 then
      return "the list of echoes must not be empty"
    end

    for index = 1, #spellIds do
      if not integer(spellIds[index]) or spellIds[index] <= 0 then
        return "echo " .. index .. " has no valid spell id"
      end
    end

    if orbCount ~= nil and (not integer(orbCount) or orbCount < 1) then
      return "the orb count must be an integer of 1 or more"
    end

    if #spellIds > 1 and orbCount ~= nil and orbCount ~= 1 then
      return "a batch spends one orb per echo: the orb count must be 1"
    end
  end,
  body = function(spellIds, orbCount)
    local ids = {}

    for index = 1, #spellIds do
      ids[index] = tostring(spellIds[index])
    end

    return tostring(orbCount or 1) .. "|" .. concat(ids, ",")
  end,
})
