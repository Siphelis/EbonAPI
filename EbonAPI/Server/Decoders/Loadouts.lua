
local type, tonumber = type, tonumber
local match, gmatch = string.match, string.gmatch

local function decodeLoadouts(body)
  if type(body) ~= "string" or body == "" then
    return nil, "empty"
  end

  local globalPart, loadoutsPart = match(body, "^([^_]+)_?(.*)$")

  if not globalPart then
    return nil, "bad_format"
  end

  local nums = {}

  for n in gmatch(globalPart, "(%d+)") do
    nums[#nums + 1] = tonumber(n)
  end

  if not nums[2] then
    return nil, "bad_header"
  end

  local global = {
    selectedLoadoutId = nums[1],
    spendable = nums[2],
    banked = nums[3] or 0,
    maximumPermanentEchoes = nums[4],
  }

  if nums[10] then
    global.pools = {
      shard = { spendable = nums[5], banked = nums[6] },
      essence = { spendable = nums[7], banked = nums[8] },
      artisan = { spendable = nums[9], banked = nums[10] },
    }
  end

  local loadouts = {}

  if loadoutsPart and loadoutsPart ~= "" then
    for text in gmatch(loadoutsPart, "([^;]+)") do
      local parts = {}

      for part in gmatch(text, "([^,]+)") do
        parts[#parts + 1] = part
      end

      if #parts >= 3 then
        local nodes = {}

        for i = 4, #parts do
          local nodeId, rank = match(parts[i], "(%d+):(%d+)")

          if nodeId and rank then
            nodes[#nodes + 1] = { nodeId = tonumber(nodeId), rank = tonumber(rank) }
          end
        end

        loadouts[#loadouts + 1] = {
          id = tonumber(parts[1]),
          name = parts[2],
          points = tonumber(parts[3]),
          nodes = nodes,
        }
      end
    end
  end

  return { global = global, loadouts = loadouts }
end

local function decodeRaw(body)
  return { raw = body }
end

local function decodeResult(body)
  local flag = match(tostring(body), "^([01])$")

  if not flag then
    return nil, "bad_flag"
  end

  return { success = flag == "1" }
end

local Decoders = EbonAPI.Decoders

Decoders.register(3, { name = "SEND_LOADOUTS", family = "Loadouts", mode = "event", decode = decodeLoadouts })
Decoders.register(4, { name = "SEND_CREATED_LOADOUT", family = "Loadouts", mode = "event", decode = decodeRaw })
Decoders.register(5, { name = "SEND_UPDATED_LOADOUT", family = "Loadouts", mode = "event", decode = decodeRaw })
Decoders.register(6, { name = "SEND_SKILL_TREE_UPDATE_SPELL_CAST_RESULT", family = "Loadouts", mode = "event", decode = decodeResult })
