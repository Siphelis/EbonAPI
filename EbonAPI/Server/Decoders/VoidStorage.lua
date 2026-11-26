
local Decoders = EbonAPI.Decoders

local tonumber, type = tonumber, type
local split = Decoders.split

Decoders.register(100, {
  name = "SEND_CONTENT_VOID_STORAGE",
  family = "VoidStorage",
  mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not a string"
    end

    if body == "" then
      return { tab = nil, items = {}, empty = true }
    end

    local parts = split(body, ";")
    local tab = tonumber(parts[1])

    if not tab or tab < 1 then
      return nil, "invalid tab index"
    end

    local items = {}

    for index = 2, #parts, 2 do
      local entry, count = tonumber(parts[index]), tonumber(parts[index + 1])

      if entry and count then
        items[#items + 1] = { slot = (index - 2) / 2 + 1, entry = entry, count = count }
      end
    end

    return { tab = tab, items = items }
  end,
})
