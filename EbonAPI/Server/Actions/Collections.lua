local Actions = EbonAPI.Actions

local type, tostring, concat = type, tostring, table.concat

local SCOPES = { [""] = true, mounts = true, pets = true, appearances = true, transmog = true }

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function slotCheck(slot)
  if not integer(slot) or slot < 0 then
    return "the slot must be an integer of 0 or more"
  end
end

local function pairsCheck(entries, key, label)
  if type(entries) ~= "table" or #entries == 0 then
    return "the list must hold at least one entry"
  end

  for index = 1, #entries do
    local entry = entries[index]

    if type(entry) ~= "table" then
      return "entry " .. index .. " must be a table"
    end

    local bad = slotCheck(entry.slot)

    if bad then
      return "entry " .. index .. ": " .. bad
    end

    if not integer(entry[key]) or entry[key] < 0 then
      return "entry " .. index .. ": " .. label .. " must be an integer of 0 or more"
    end
  end
end

local function pairsBody(entries, key, separator)
  local parts = {}

  for index = 1, #entries do
    parts[index] = tostring(entries[index].slot) .. ":" .. tostring(entries[index][key])
  end

  return concat(parts, separator)
end

local function outfitIdCheck(id)
  if not integer(id) or id < 0 or id > 255 then
    return "the outfit id must be an integer from 0 to 255"
  end
end

local function nameCheck(name)
  if type(name) ~= "string" or name == "" then
    return "the name must be a non empty string"
  end

  if name:find("|", 1, true) then
    return "the name must not contain a vertical bar"
  end
end

Actions.define({
  name = "RequestCollections", cs = "REQUEST_COLLECTIONS",
  check = function(which)
    if which ~= nil and not SCOPES[which] then
      return "the scope must be nil, an empty string, mounts, pets, appearances or transmog"
    end
  end,
  body = function(which) return which or "" end,
})

Actions.define({
  name = "ApplyTransmog", cs = "REQUEST_APPLY_TRANSMOG",
  check = function(entries) return pairsCheck(entries, "item", "item") end,
  body = function(entries) return pairsBody(entries, "item", " ") end,
})

Actions.define({
  name = "ClearTransmog", cs = "REQUEST_CLEAR_TRANSMOG",
  check = function(slot)
    if slot ~= nil then
      return slotCheck(slot)
    end
  end,
  body = function(slot) return slot == nil and "" or tostring(slot) end,
})

Actions.define({
  name = "ApplyIllusion", cs = "REQUEST_APPLY_ILLUSION",
  check = function(entries) return pairsCheck(entries, "enchant", "enchant id") end,
  body = function(entries) return pairsBody(entries, "enchant", " ") end,
})

Actions.define({
  name = "UnlockAppearance", cs = "REQUEST_UNLOCK_APPEARANCE",
  check = function(itemId)
    if not integer(itemId) or itemId <= 0 then
      return "the item id must be a positive integer"
    end
  end,
  body = function(itemId) return tostring(itemId) end,
})

Actions.define({
  name = "SetFormLook", cs = "REQUEST_FORM_LOOK_SET",
  check = function(hidden)
    if type(hidden) ~= "boolean" then
      return "hidden must be a boolean"
    end
  end,
  body = function(hidden) return hidden and "1" or "0" end,
})

Actions.define({
  name = "SaveOutfit", cs = "REQUEST_OUTFIT_SAVE",
  check = function(id, name, entries)
    if id ~= nil then
      local bad = outfitIdCheck(id)

      if bad then
        return bad
      end
    end

    local bad = nameCheck(name)

    if bad then
      return bad
    end

    if entries ~= nil then
      if type(entries) ~= "table" then
        return "the entries must be a list"
      end

      for index = 1, #entries do
        local entry = entries[index]

        if type(entry) ~= "table" then
          return "entry " .. index .. " must be a table"
        end

        local badSlot = slotCheck(entry.slot)

        if badSlot then
          return "entry " .. index .. ": " .. badSlot
        end

        if not integer(entry.entry) or entry.entry <= 0 then
          return "entry " .. index .. ": the entry must be a positive integer"
        end
      end
    end
  end,
  body = function(id, name, entries)
    return tostring(id or 255) .. "|" .. name .. "|" .. (entries and #entries > 0 and pairsBody(entries, "entry", ",") or "")
  end,
})

Actions.define({
  name = "RenameOutfit", cs = "REQUEST_OUTFIT_RENAME",
  check = function(id, name) return outfitIdCheck(id) or nameCheck(name) end,
  body = function(id, name) return tostring(id) .. "|" .. name end,
})

Actions.define({
  name = "DeleteOutfit", cs = "REQUEST_OUTFIT_DELETE",
  check = outfitIdCheck, body = function(id) return tostring(id) end,
})

Actions.define({
  name = "ApplyOutfit", cs = "REQUEST_OUTFIT_APPLY",
  check = outfitIdCheck, body = function(id) return tostring(id) end,
})

Actions.define({
  name = "RequestCreatureCache", cs = "REQUEST_CREATURE_CACHE",
  check = function(creatureId)
    if not integer(creatureId) or creatureId <= 0 then
      return "the creature id must be a positive integer"
    end
  end,
  body = function(creatureId) return tostring(creatureId) end,
})
