
local type, tonumber = type, tonumber
local gmatch = string.gmatch

local function nullable(text)
  if text == nil or text == "NULL" then
    return nil
  end

  return tonumber(text)
end

local function decodeShop(body)
  if type(body) ~= "string" then
    return nil, "not_a_string"
  end

  local entries = {}

  for text in gmatch(body, "([^%-]+)") do
    if text:find("%S") then
      local f = {}

      for field in gmatch(text, "([^#]+)") do
        f[#f + 1] = field
      end

      local id = tonumber(f[1])

      if id then
        entries[#entries + 1] = {
          id = id,
          categoryId = f[2] ~= "NULL" and tonumber(f[2]) or 12,
          itemId = tonumber(f[3]),
          creatureId = nullable(f[4]),
          price = tonumber(f[5]),
          discountActive = f[6] == "1",
          discount = nullable(f[7]),
          discountEnd = nullable(f[8]),
        }
      end
    end
  end

  return { entries = entries }
end

local function decodeBalance(body)
  local balance = tonumber(body)

  if not balance then
    return nil, "not_a_number"
  end

  return { balance = balance }
end

local Decoders = EbonAPI.Decoders

Decoders.register(1, { name = "SEND_SHOP_DATA", family = "Shop", mode = "event", decode = decodeShop })
Decoders.register(2, { name = "SEND_ACCOUNT_DP", family = "Shop", mode = "event", decode = decodeBalance })
