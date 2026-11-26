
local D = EbonAPI.Decoders

local split = D.split

local function int(s)
  if type(s) ~= "string" or not string.find(s, "^%-?%d+$") then return nil end
  return tonumber(s)
end

D.register(1258, { name = "SEND_RAID_FINDER_DATA", family = "RaidFinder", mode = "state",
  decode = function(body)
    if type(body) ~= "string" then return nil, "corps non chaine" end
    local f = split(body, "|")
    local names = { "release", "maxQueueable", "maxTier", "roles", "classRoles" }
    local out = {}
    for i = 1, 5 do
      out[names[i]] = int(f[i])
      if out[names[i]] == nil then return nil, "champ " .. i .. " (" .. names[i] .. ") non entier" end
    end
    out.maps = {}
    for entry in string.gmatch(f[6] or "", "([^;]+)") do
      local m, l, t = string.match(entry, "^(%d+),(%d+),(%d+)$")
      if m then out.maps[#out.maps + 1] = { mapId = tonumber(m), lootable = tonumber(l), total = tonumber(t) } end
    end
    return out
  end })

local COMMON = { "map", "tier", "tank", "healer", "damage", "players" }
local VARIANTS = {
  [1] = { "soakLeft", "inRaid", "queuedSecs" },
  [2] = { "secondsLeft", "accepted", "total", "answered", "myRole" },
  [3] = { "target", "searching", "leader", "searchSecs" },
}
local BOOLS = { inRaid = true, answered = true, searching = true, leader = true }

D.register(1259, { name = "SEND_RAID_FINDER_STATE", family = "RaidFinder", mode = "state",
  decode = function(body)
    if type(body) ~= "string" then return nil, "corps non chaine" end
    local f = split(body, "|")
    local status = int(f[1])
    if status == nil or status < 0 or status > 3 then return nil, "statut inconnu" end
    local out = { status = status }
    if status == 0 then return out end
    local idx = 1
    for _, n in ipairs(COMMON) do
      idx = idx + 1
      out[n] = int(f[idx])
      if out[n] == nil then return nil, "champ " .. idx .. " (" .. n .. ") non entier" end
    end
    for _, n in ipairs(VARIANTS[status]) do
      idx = idx + 1
      local v = int(f[idx])
      if v == nil then return nil, "champ " .. idx .. " (" .. n .. ") non entier" end
      if BOOLS[n] then v = (v ~= 0) end
      out[n] = v
    end
    if status == 1 then
      local maps = {}
      for map in string.gmatch(f[idx + 1] or "", "(%d+)") do maps[#maps + 1] = tonumber(map) end
      if #maps > 0 then out.maps = maps end
    end
    if status == 2 then
      local r = f[idx + 1]
      if r == nil or r == "" then out.refill = false
      else
        local v = int(r)
        if v == nil then return nil, "champ refill non entier" end
        out.refill = (v ~= 0)
      end
    end
    return out
  end })

D.register(1265, { name = "SEND_RAID_FINDER_RESULT", family = "RaidFinder", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "corps non chaine" end
    local head, reason = string.match(body, "^(%u+),?(.*)$")
    if head == "OK" then return { ok = true } end
    if head == "FAIL" then
      if reason == "" then reason = nil end
      return { ok = false, reason = reason }
    end
    return nil, "corps ni OK ni FAIL"
  end })
