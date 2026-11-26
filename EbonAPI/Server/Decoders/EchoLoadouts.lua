
local tonumber, type, match, gmatch, gsub, upper = tonumber, type, string.match, string.gmatch, string.gsub, string.upper

EbonAPI.Decoders.register(530, {
  name = "SEND_ECHO_DISCOVERY", family = "EchoLoadouts", mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local out = { entries = {}, counts = {}, disabled = {} }

    if body == "" then
      return out
    end

    for entry in gmatch(body, "([^,]+)") do
      local idText, countText, enabledText = match(entry, "^(%d+):?(%d*):?(%d*)$")
      local spellId = tonumber(idText)

      if spellId then
        local count = tonumber(countText) or 1
        local enabled = enabledText ~= "0"

        out.entries[#out.entries + 1] = { spellId = spellId, count = count, enabled = enabled }
        out.counts[spellId] = count

        if not enabled then
          out.disabled[spellId] = true
        end
      end
    end

    if #out.entries == 0 then
      return nil, "no_entry"
    end

    return out
  end,
})

EbonAPI.Decoders.register(531, {
  name = "SEND_ECHO_LOADOUTS_SHARED", family = "EchoLoadouts", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local list = {}

    for entry in gmatch(body, "([^;]+)") do
      local author, name, class, echoText = match(entry, "^([^|]*)|([^|]*)|([^|]*)|(.*)$")

      if not author then
        author, name, echoText = match(entry, "^([^|]*)|([^|]*)|(.*)$")
        class = nil
      end

      if name and name ~= "" then
        local echoes = {}

        for echo in gmatch(echoText or "", "([^,]+)") do
          local id, quality, stacks, avoid = match(echo, "^(%d+)%.(%d+)%.?(%d*)%.?(%d*)$")
          id = tonumber(id)

          if id then
            echoes[#echoes + 1] = {
              spellId = id, quality = tonumber(quality) or 0,
              stacks = tonumber(stacks) or 1, avoid = (tonumber(avoid) == 1) or nil,
            }
          end
        end

        if #echoes > 0 then
          local token = class and gsub(upper(class), "[^A-Z]", "") or nil

          if token == "" then
            token = nil
          end

          list[#list + 1] = { author = author, name = name, class = token, echoes = echoes }
        end
      end
    end

    return { loadouts = list }
  end,
})

EbonAPI.Decoders.register(540, {
  name = "SEND_PERK_LOADOUTS", family = "EchoLoadouts", mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    if body == "" then
      return { enabled = false, active = 1, design = 0, maxSlots = 0, unlocked = 0, costs = {}, slots = {} }
    end

    local out = { enabled = true, costs = {}, slots = {} }
    local first = true

    for record in gmatch(body, "([^;]+)") do
      if first then
        first = false

        local active, design, maxSlots, unlocked, costs = match(record, "^(%d+)|(%d+)|(%d+)|(%d+)|(.*)$")

        if not active then
          return nil, "bad_header"
        end

        out.active, out.design = tonumber(active), tonumber(design)
        out.maxSlots, out.unlocked = tonumber(maxSlots), tonumber(unlocked)

        for cost in gmatch(costs, "([^%.]+)") do
          out.costs[#out.costs + 1] = tonumber(cost) or 0
        end
      else
        local slotText, name, kind, info, echoText, memoryText = match(record, "^(%d+)|([^|]*)|([01])|([%d%.]+)|([^|]*)|?(.*)$")
        local slot = tonumber(slotText)

        if slot then
          local live = kind == "1"
          local missing, remaining, total = match(info, "^(%d+)%.?(%d*)%.?(%d*)$")
          local echoes, memory = {}, {}

          for entry in gmatch(echoText, "([^,]+)") do
            local id, stacks, flagText = match(entry, "^(%d+)%.(%d+)%.(%d+)$")
            id = tonumber(id)

            if id then
              local flag = tonumber(flagText) == 1

              echoes[#echoes + 1] = {
                spellId = id, stacks = tonumber(stacks) or 1, flag = flag,
                locked = flag and live or false, avoid = (flag and not live) or nil,
              }
            end
          end

          for entry in gmatch(memoryText or "", "([^,]+)") do
            local id, stacks, left = match(entry, "^(%d+)%.(%d+)%.(%d+)$")
            id = tonumber(id)

            if id then
              memory[#memory + 1] = { spellId = id, stacks = tonumber(stacks) or 1, remaining = tonumber(left) or 0 }
            end
          end

          out.slots[slot] = {
            slot = slot, name = name or "", live = live, missing = tonumber(missing) or 0,
            memoryRemaining = tonumber(remaining) or 0, memoryTotal = tonumber(total) or 0,
            echoes = echoes, memory = memory,
          }
        end
      end
    end

    if first then
      return nil, "bad_header"
    end

    return out
  end,
})

EbonAPI.Decoders.register(541, {
  name = "SEND_PERK_LOADOUT_RESULT", family = "EchoLoadouts", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local status, op, detail = match(body, "^([^,]+),([^,]+),(.*)$")

    if not status then
      return nil, "bad_format"
    end

    if status ~= "OK" and status ~= "FAIL" then
      return nil, "bad_status"
    end

    local out = { status = status, ok = status == "OK", op = op, detail = detail }

    if out.ok then
      local slot = match(detail, "^(%d+)")

      if slot then
        out.slot = tonumber(slot)
      end

      local _, skipped = match(detail, "^(%d+),(%d+)$")

      if skipped then
        out.skipped = tonumber(skipped)
      end
    else
      out.reason = detail
    end

    return out
  end,
})

EbonAPI.Decoders.register(542, {
  name = "SEND_PERK_LOADOUT_ACTIVE", family = "EchoLoadouts", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local active, design = match(body, "^(%d+)|(%d+)$")

    if active then
      return { active = tonumber(active), design = tonumber(design) }
    end

    active = match(body, "^(%d+)$")

    if active then
      return { active = tonumber(active), design = 0 }
    end

    return nil, "bad_format"
  end,
})
