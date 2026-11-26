
local tonumber, type = tonumber, type

local function eq1(v) return v == "1" end

EbonAPI.Decoders.register(1270, {
  name = "SEND_TOOLBELT_STATE", family = "Toolbelt",
  mode = "state",
  decode = function(body)
    if type(body) ~= "string" then return nil, "body is not a string" end

    local fields = {}

    for part in string.gmatch(body, "([^|]+)") do
      local k, v = part:match("^(%w+):(.*)$")
      if k then fields[k] = v end
    end

    local waystones = {}

    for slot, id in string.gmatch(fields.ways or "", "(%d+)=(%d+)") do
      waystones[tonumber(slot)] = tonumber(id)
    end

    return {
      owned = {
        bank = eq1(fields.bank), vendor = eq1(fields.vendor), loot = eq1(fields.loot),
        mail = eq1(fields.mail), auction = eq1(fields.ah), guildBank = eq1(fields.gbank),
        callboard = eq1(fields.cb), anvil = eq1(fields.anvil), forge = eq1(fields.forge),
      },
      loot = {
        on = eq1(fields.on),
        minQuality = tonumber(fields.q) or 0,
        classMask = tonumber(fields.t) or 4294967295,
        destroy = eq1(fields.d),
        destroyMaxQuality = tonumber(fields.dq) or 0,
        destroyClassMask = tonumber(fields.dt) or 4294967295,
      },
      repairCost = tonumber(fields.repair) or 0,
      waystones = waystones,
    }
  end,
})

EbonAPI.Decoders.register(1271, {
  name = "SEND_TOOLBELT_RESULT", family = "Toolbelt", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "body is not a string" end

    local parts = {}

    for p in string.gmatch(body .. ",", "([^,]*),") do parts[#parts + 1] = p end

    local kind = parts[1]

    if kind == "SELL" then
      return { kind = kind, count = tonumber(parts[2]) or 0, copper = tonumber(parts[3]) or 0 }
    elseif kind == "REPAIR" then
      return { kind = kind, spent = tonumber(parts[2]) or 0, remaining = tonumber(parts[3]) or 0 }
    elseif kind == "GBANK" then
      return { kind = kind }
    elseif kind == "FORGE" then
      return { kind = kind, seconds = tonumber(parts[2]) or 0 }
    elseif kind == "FAIL" then
      return { kind = kind, what = parts[2], reason = parts[3] }
    end

    return { kind = kind, raw = body }
  end,
})
