
local EbonAPI = EbonAPI
local register = EbonAPI.Decoders.register

local function int_list(body)
  if type(body) ~= "string" then return nil, "not_a_string" end

  local list, n = {}, 0

  for token in string.gmatch(body, "%S+") do
    if not string.find(token, "^%-?%d+$") then return nil, "bad_token" end

    n = n + 1
    list[n] = tonumber(token)
  end

  return list
end

local function list_decoder(field)
  return function(body)
    local list, reason = int_list(body)

    if not list then return nil, reason end

    return { [field] = list }
  end
end

local function single_id(field)
  return function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    local token = string.match(body, "^%s*(%-?%d+)%s*$")

    if not token then return nil, "bad_token" end

    return { [field] = tonumber(token) }
  end
end

register(1100, { name = "SEND_COLLECTED_MOUNTS", family = "Collections", mode = "event", decode = list_decoder("spellIds") })
register(1101, { name = "SEND_COLLECTED_PETS", family = "Collections", mode = "event", decode = list_decoder("spellIds") })
register(1102, { name = "SEND_COLLECTED_APPEARANCES", family = "Collections", mode = "event", decode = list_decoder("ids") })

register(1103, {
  name = "SEND_TRANSMOG_SLOTS", family = "Collections", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    local slots, n = {}, 0

    for slot, item, illusion in string.gmatch(body, "(%d+):(%-?%d+):?(%d*)") do
      n = n + 1
      slots[n] = { slot = tonumber(slot), item = tonumber(item), illusion = tonumber(illusion) or 0 }
    end

    if n == 0 and string.find(body, "%S") then return nil, "no_slot" end

    return { slots = slots }
  end,
})

register(1104, { name = "SEND_MOUNT_LEARNED", family = "Collections", mode = "event", decode = single_id("spellId") })
register(1105, { name = "SEND_PET_LEARNED", family = "Collections", mode = "event", decode = single_id("spellId") })
register(1106, { name = "SEND_APPEARANCE_LEARNED", family = "Collections", mode = "event", decode = single_id("itemId") })

register(1107, {
  name = "SEND_TRANSMOG_SLOT_UPDATE", family = "Collections", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    local slot, item, illusion = string.match(body, "(%d+):(%-?%d+):?(%d*)")

    if not slot then return nil, "bad_slot" end

    return { slot = tonumber(slot), item = tonumber(item), illusion = tonumber(illusion) or 0 }
  end,
})

register(1108, {
  name = "SEND_TRANSMOG_OUTFITS", family = "Collections", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    local activeStr, maxStr, rest = string.match(body, "^(%d+);(%d+);?(.*)$")

    if not activeStr then return nil, "bad_header" end

    local outfits, n = {}, 0

    for chunk in string.gmatch(rest, "[^;]+") do
      local id, name, srcs = string.match(chunk, "^(%d+)|([^|]*)|(.*)$")

      if not id then return nil, "bad_outfit" end

      local sources, m, pos = {}, 0, 1

      while pos <= #srcs do
        local a, b, slot, entry = string.find(srcs, "^(%d+):(%d+),?", pos)

        if not a then return nil, "bad_outfit" end

        m = m + 1
        sources[m] = { slot = tonumber(slot), entry = tonumber(entry) }
        pos = b + 1
      end

      n = n + 1
      outfits[n] = { id = tonumber(id), name = name, sources = sources }
    end

    return { activeId = tonumber(activeStr), max = tonumber(maxStr), outfits = outfits }
  end,
})

register(1109, {
  name = "SEND_FORM_LOOK_STATE", family = "Collections", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "not_a_string" end

    return { hidden = (body == "1") }
  end,
})
