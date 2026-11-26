local Decoders = EbonAPI.Decoders

local type, tonumber, pairs, ipairs = type, tonumber, pairs, ipairs
local match, gmatch = string.match, string.gmatch
local sort = table.sort

local Portals = {}
EbonAPI.Portals = Portals

local mapId, openSet, closedUntil = nil, nil, {}
local cache, cacheData, cacheUntil = nil, nil, nil
local index, indexData = nil, nil

local function portalData()
  local pe = _G.ProjectEbonhold

  if type(pe) == "table" and type(pe.PortalData) == "table" then
    return pe.PortalData
  end

  return nil
end

local function indexOf(data)
  if index and indexData == data then
    return index
  end

  index, indexData = {}, data

  for area, zone in pairs(data) do
    if type(zone) == "table" and type(zone.portals) == "table" then
      for _, portal in ipairs(zone.portals) do
        index[portal.id] = { id = portal.id, map = zone.map, area = area, x = portal.x, y = portal.y }
      end
    end
  end

  return index
end

local function byId(a, b)
  return a.id < b.id
end

local function build()
  local data = portalData()
  local list = {}
  local nextExpiry = nil

  cacheData = data

  if data then
    local entries = indexOf(data)

    if openSet then
      for id in pairs(openSet) do
        local entry = entries[id]

        if entry then
          list[#list + 1] = entry
        end
      end
    else
      local now = GetTime()

      for id, entry in pairs(entries) do
        local deadline = closedUntil[id]

        if entry.map == mapId then
          if deadline and now < deadline then
            if not nextExpiry or deadline < nextExpiry then
              nextExpiry = deadline
            end
          else
            list[#list + 1] = entry
          end
        end
      end
    end

    sort(list, byId)
  end

  cache, cacheUntil = list, nextExpiry
end

function Portals.Open()
  if mapId == nil then
    return nil
  end

  if not cache or cacheData ~= portalData() or (cacheUntil and GetTime() >= cacheUntil) then
    build()
  end

  return cache, mapId
end

local function touch()
  cache = nil
  EbonAPI:Emit("SERVER_PORTALS")
end

local function parseEntries(text)
  local out = {}

  for raw in gmatch(text, "[^,]+") do
    local id, secs = match(raw, "^(%d+):(%d+)$")

    if id then
      out[#out + 1] = { tonumber(id), tonumber(secs) }
    end
  end

  return out
end

local function decodeList(body)
  local map, list = match(body or "", "^(%d+)|(.*)$")

  if not map then
    return nil, "bad_list"
  end

  local ids = match(list, "^open|(.*)$")

  if ids then
    local open = {}

    for id in gmatch(ids, "%d+") do
      open[tonumber(id)] = true
    end

    return { map = tonumber(map), open = open }
  end

  return { map = tonumber(map), closed = parseEntries(list) }
end

local function decodeState(body)
  local map, list = match(body or "", "^(%d+)|(.*)$")

  if not map then
    return nil, "bad_state"
  end

  return { map = tonumber(map), entries = parseEntries(list) }
end

local function decodeId(body)
  local map, id = match(body or "", "^(%d+)|(%d+)$")

  if not id then
    return nil, "bad_id"
  end

  return { map = tonumber(map), id = tonumber(id) }
end

local function applyList(value)
  mapId = value.map
  closedUntil = {}
  openSet = value.open

  if not openSet then
    local now = GetTime()

    for _, pair in ipairs(value.closed) do
      if pair[2] > 0 then
        closedUntil[pair[1]] = now + pair[2]
      end
    end
  end

  touch()
end

local function applyState(value)
  if mapId == nil or value.map ~= mapId then
    return
  end

  local now = GetTime()

  for _, pair in ipairs(value.entries) do
    local id, secs = pair[1], pair[2]
    local shut = secs > 0

    closedUntil[id] = shut and (now + secs) or nil

    if openSet then
      openSet[id] = (not shut) or nil
    end
  end

  touch()
end

local function applySeen(value)
  if mapId == nil then
    return
  end

  closedUntil[value.id] = nil

  if openSet then
    openSet[value.id] = true
  end

  touch()
end

local function applyUsed(value)
  local own = mapId ~= nil and value.map == mapId

  if own then
    if openSet then
      openSet[value.id] = nil
    else
      closedUntil[value.id] = math.huge
    end

    cache = nil
  end

  EbonAPI:Emit("SERVER_PORTAL_USED", value.id)

  if own then
    EbonAPI:Emit("SERVER_PORTALS")
  end
end

local function register(opcode, name, decode, apply)
  Decoders.register(opcode, { name = name, family = "Portals", mode = "event", decode = decode })
  Decoders.subscribe(opcode, apply)
end

register(1294, "SEND_TORMENT_PORTALS", decodeList, applyList)
register(1295, "SEND_TORMENT_PORTAL_STATE", decodeState, applyState)
register(1296, "SEND_TORMENT_PORTAL_SEEN", decodeId, applySeen)
register(1297, "SEND_TORMENT_PORTAL_USED", decodeId, applyUsed)
