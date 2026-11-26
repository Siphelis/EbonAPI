
local Decoders = EbonAPI.Decoders

local tonumber, type = tonumber, type

local split = Decoders.split

local function num(value, default)
  return tonumber(value) or default
end

local function flag(value, default)
  return (tonumber(value) or default) == 1
end

Decoders.register(1235, {
  name = "SEND_REAPER_STATE",
  family = "ReaperContracts",
  mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local f = split(body, ";")

    return {
      gauge = num(f[1], 0),
      cap = num(f[2], 100),
      pact = flag(f[3], 0),
      fragments = num(f[4], 0),
      perEye = num(f[5], 40),
      hasEye = flag(f[6], 0),
      reaperAlive = flag(f[7], 0),
      reaperTorment = num(f[8], 0),
      harvested = flag(f[9], 0),
      enabled = flag(f[10], 1),
    }
  end,
})

Decoders.register(1237, {
  name = "SEND_CONTRACTS",
  family = "ReaperContracts",
  mode = "state",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_a_string"
    end

    local parts = split(body, "|")
    local h = split(parts[1], ";")
    local out = {
      gauge = num(h[1], 0),
      used = num(h[2], 0),
      max = num(h[3], 5),
      price = num(h[4], 0),
      ashes = num(h[5], 0),
      shards = num(h[6], 0),
      open = flag(h[7], 0),
      anchorPrice = num(h[10], 0),
      anchorState = num(h[11], 0),
      anchorPlace = h[12] or "",
      list = {},
    }
    local list = parts[2]

    if list and list ~= "" then
      local items, count = split(list, ";")

      for i = 1, count do
        local c = split(items[i], "~")

        if c[1] and c[2] then
          local contract = {
            key = c[1],
            kind = num(c[2], 1),
            state = num(c[3], 0),
            torment = num(c[4], 0),
            level80 = flag(c[5], 0),
            required = num(c[6], 1),
            progress = num(c[7], 0),
            bonus = num(c[8], 0),
            title = c[9] or "",
            name = c[10] or "",
            order = i,
            mapId = num(c[11], 0),
            zoneId = num(c[12], 0),
            levelMax = num(c[13], 0),
            level = num(c[14], 0),
            duration = num(c[15], 0),
            started = flag(c[16], 0),
          }

          if contract.started then
            contract.remaining = num(c[17], 0)
          end

          out.list[#out.list + 1] = contract
        end
      end
    end

    return out
  end,
})
