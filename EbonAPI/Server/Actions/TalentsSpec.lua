local Actions = EbonAPI.Actions

local type, tostring, concat = type, tostring, table.concat

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function specCheck(index)
  if not integer(index) or index < 1 or index > 5 then
    return "the specialization index must be an integer from 1 to 5"
  end
end

local function specBody(index)
  return tostring(index)
end

Actions.define({
  name = "SelectSpec", cs = "REQUEST_APPLY_SPECS", service = { "SpecService", "ApplySpec" },
  check = specCheck, body = specBody,
})

Actions.define({
  name = "QueryCurrentSpec", cs = "REQUEST_CURRENT_SPEC", service = { "SpecService", "RequestCurrentSpec" },
})

Actions.define({
  name = "ResetTalents", cs = "REQUEST_RESET_TALENT_TREE", service = { "SpecService", "ResetTalents" },
  check = specCheck, body = specBody,
})

Actions.define({ name = "PreviewSpecTalents", cs = "REQUEST_SPEC_TALENTS", check = specCheck, body = specBody })

Actions.define({
  name = "ApplyTalentPlan", cs = "REQUEST_APPLY_TALENT_PLAN",
  check = function(changes)
    if type(changes) ~= "table" or #changes == 0 then
      return "the list of changes must not be empty"
    end

    for index = 1, #changes do
      local change = changes[index]

      if type(change) ~= "table" or not integer(change.talentId) or change.talentId <= 0 then
        return "change " .. index .. " has no valid talentId"
      end

      if not integer(change.rank) or change.rank < 0 then
        return "change " .. index .. " has no valid rank (integer of 0 or more)"
      end
    end
  end,
  body = function(changes)
    local parts = {}

    for index = 1, #changes do
      parts[index] = tostring(changes[index].talentId) .. ":" .. tostring(changes[index].rank)
    end

    return concat(parts, ",")
  end,
})
