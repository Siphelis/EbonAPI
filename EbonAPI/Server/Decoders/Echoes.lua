
local tonumber, type, find, sub, match, gmatch = tonumber, type, string.find, string.sub, string.match, string.gmatch

EbonAPI.Decoders.register(16, {
  name = "SEND_PLAYER_PERK_CHOICE", family = "Echoes", mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local out = { choices = {} }

    if body == "" then
      return out
    end

    local parse = body
    local n, rest = match(body, "^(%d+)|(.+)$")

    if n and rest then
      n = tonumber(n)

      if n and n > 0 then
        out.pendingRolls = n
        parse = rest
      end
    end

    local choices, sawSpec = out.choices, false

    for pair in gmatch(parse, "([^;]+)") do
      local chosen = match(pair, "^S,(%d+)$")

      if chosen then
        out.specDraw = { chosen = tonumber(chosen) or 0 }
        sawSpec = true
      end

      local idText, qualityText, flagText, extraText = match(pair, "^([^,]+),([^,]+),?([^,]*),?([^,]*)$")

      if idText and qualityText then
        local spellId, quality = tonumber(idText), tonumber(qualityText)

        if spellId and spellId ~= 0 and quality then
          local flag = tonumber(flagText) or 0

          choices[#choices + 1] = {
            spellId = spellId, quality = quality, flag = flag,
            frozen = flag == 1, carried = flag == 2, memory = flag == 3,
            memoryRemaining = flag == 3 and tonumber(extraText) or nil,
          }
        end
      end
    end

    if #choices == 0 and not sawSpec then
      return nil, "no_card"
    end

    if #choices == 4 then
      choices[4] = nil
      out.droppedFourth = true
    end

    return out
  end,
})

EbonAPI.Decoders.register(18, {
  name = "SEND_PLAYER_PERK_GRANTED", family = "Echoes", mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local out = { perks = {} }
    local first = true

    for part in gmatch(body, "([^;]+)") do
      if first then
        first = false
        out.maxSlots = tonumber(part)

        if not out.maxSlots then
          return nil, "bad_max_slots"
        end
      else
        local idText, stackText, maxText, qualityText, lockedText = match(part, "^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$")

        if not idText then
          idText, stackText, maxText = match(part, "^([^,]+),([^,]+),([^,]+)$")
          qualityText, lockedText = nil, nil
        end

        local spellId, stack, maxStack = tonumber(idText), tonumber(stackText), tonumber(maxText)

        if spellId and stack and maxStack then
          out.perks[#out.perks + 1] = {
            spellId = spellId, stack = stack, maxStack = maxStack,
            quality = qualityText and tonumber(qualityText) or 0,
            locked = lockedText ~= nil and tonumber(lockedText) == 1,
          }
        end
      end
    end

    return out
  end,
})

EbonAPI.Decoders.register(32, {
  name = "SEND_PLAYER_SPEC_INDEX", family = "Echoes", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local index = tonumber(body)

    if index and index >= 1 and index <= 5 and index == math.floor(index) then
      return { index = index }
    end

    return nil, "bad_index"
  end,
})

EbonAPI.Decoders.register(103, {
  name = "SEND_BANISH_REPLACEMENT_PERK", family = "Echoes", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    if body == "" then
      return { ok = false, quality = 0 }
    end

    local spellId, quality
    local comma = find(body, ",", 1, true)

    if comma then
      spellId = tonumber(sub(body, 1, comma - 1))
      quality = tonumber(sub(body, comma + 1))
    else
      spellId = tonumber(body)
      quality = 0
    end

    if not spellId then
      return nil, "bad_spell_id"
    end

    if not quality then
      return nil, "bad_quality"
    end

    if spellId == 0 then
      return { ok = false, quality = 0 }
    end

    return { ok = true, spellId = spellId, quality = quality }
  end,
})

EbonAPI.Decoders.register(104, {
  name = "SEND_FREEZE_PERK_RESULT", family = "Echoes", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    return { ok = body == "1" }
  end,
})

EbonAPI.Decoders.register(1000, {
  name = "SEND_PLAYER_PERK_SELECTION_RESULT", family = "Echoes", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local count = tonumber(body)

    if not count then
      return nil, "not_a_number"
    end

    return { ok = count >= 1, count = count }
  end,
})

EbonAPI.Decoders.register(1220, {
  name = "SEND_ORB_CHARGES", family = "Echoes", mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    if body == "" then
      return nil, "empty"
    end

    local chargesText, deltaText, pendingText = match(body, "^([^,]*),?([^,]*),?([^,]*)")
    local hasPending = find(body, ",[^,]*,") ~= nil
    local charges = tonumber(chargesText)

    if not charges then
      return nil, "bad_charges"
    end

    local out = { charges = charges, appliedDelta = tonumber(deltaText) }

    if hasPending then
      out.pendingOffers = tonumber(pendingText) or 0
    end

    return out
  end,
})

EbonAPI.Decoders.register(1224, {
  name = "SEND_PERK_BANISHED", family = "Echoes", mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local banished = {}

    for entry in gmatch(body, "[^,]+") do
      local id = tonumber(entry)

      if id and id > 0 then
        banished[#banished + 1] = id
      end
    end

    return { banished = banished }
  end,
})
