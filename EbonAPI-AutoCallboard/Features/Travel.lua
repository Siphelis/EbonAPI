local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local L = AutoCallboardLocale
local Skin = AutoCallboardSkin
local state = RT.state

local Log = RT.Log

local BUTTON_NAME = "AutoCallboardTravelButton"

local button
local suggestion
local suggestionQuestKey
local requestedAt
local autoQuestKey
local MaybeAutoTravel
local lastTravelCheckpoints
local lastTravelUnlockedCount
local lastTravelLocation

local LOCATION_ALIASES = {
  tirisfalglades = "tirisfal", elwynnforest = "elwynn", redridgemountains = "redridge",
  alteracmountains = "alterac", arathihighlands = "arathi", hillsbradfoothills = "hillsbrad",
  stranglethornvale = "stranglethorn", dustwallowmarsh = "dustwallow", azshara = "aszhara",
  stormwindcity = "stormwind", shattrathcity = "shattrath", silvermooncity = "silvermoon",
  darnassus = "darnassis", stockades = "stockade",
  tempestkeepnetherstorm = "tempestkeep",
  ogrimmar = "orgrimmar",
}

local function Trim(value)
  if type(value) ~= "string" then
    return ""
  end

  return (value:match("^%s*(.-)%s*$"))
end

local function NormalizeLocation(value)
  value = Trim(value):lower()
  value = value:gsub("[^%w]", "")

  value = value:gsub("^the", "")
  return LOCATION_ALIASES[value] or value
end

function Core.travelLocationFromText(text)
  text = Trim(text)

  if text == "" then
    return ""
  end

  local location

  for match in string.gmatch(text, "%f[%w][iI][nN]%s+([^%.]+)") do
    location = match
  end

  return Trim(location or "")
end

function Core.travelCheckpointLocation(name)
  name = Trim(name)

  if name == "" then
    return ""
  end

  local zone = name:match(",%s*([^,]+)%s*$")

  return Trim(zone or name)
end

function Core.travelCheckpointUsable(checkpoint)
  if type(checkpoint) ~= "table" then
    return false
  end

  if (tonumber(checkpoint.id) or 0) <= 0 then
    return false
  end

  return checkpoint.unlocked and true or false
end

local ClientBounds

local zonesByName, zonesByMap = {}, {}
local entrancesByName = {}
local subzonesByName = {}

for name, parent in pairs(Core.travelSubzones or {}) do
  subzonesByName[NormalizeLocation(name)] = NormalizeLocation(parent)
end

for name, entrances in pairs(Core.travelEntrances or {}) do
  entrancesByName[NormalizeLocation(name)] = entrances
end

local regionZones = {}

for _, row in ipairs(Core.travelZones or {}) do
  local zone = { name = row[1], mapId = row[2], serverMapId = row[3],
    region = row[8], bounds = row[4] and { row[4], row[5], row[6], row[7], row[3] } or nil }
  zonesByName[NormalizeLocation(zone.name)] = zone
  zonesByMap[zone.mapId] = zone
  if row[8] then
    regionZones[#regionZones + 1] = { name = row[1], region = row[8] }
  end
end

local function WorldMapKey(zone, map)
  return tostring(map) .. ":" .. ((zone and zone.region) or "")
end

local function MapToWorld(zone, bounds, x, y)
  x, y = tonumber(x), tonumber(y)
  if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
    return nil
  end
  return { x = bounds[1] + (bounds[2] - bounds[1]) * x,
    y = bounds[3] + (bounds[4] - bounds[3]) * y, map = WorldMapKey(zone, bounds[5]) }
end

local function WorldPoint(checkpoint, boundsByName)
  local zone = zonesByMap[tonumber(checkpoint.mapId)]
  if not zone then
    zone = zonesByName[NormalizeLocation(Core.travelCheckpointLocation(checkpoint.name))]
  end
  if not zone then
    return nil
  end
  local bounds = (boundsByName and boundsByName[NormalizeLocation(zone.name)]) or zone.bounds
  if not bounds or bounds[5] ~= tonumber(checkpoint.serverMapId) then
    return nil
  end
  return MapToWorld(zone, bounds, checkpoint.x, checkpoint.y)
end

local boundsSource, boundsCopy

ClientBounds = function()
  local ebonBounds = EbonAPI.Ebonhold.Service("WorldMapBounds")

  if not ebonBounds then
    return nil
  end

  if ebonBounds == boundsSource then
    return boundsCopy
  end

  local boundsByName = {}

  for name, bounds in pairs(ebonBounds) do
    if type(bounds) == "table" and type(bounds[1]) == "number" and type(bounds[2]) == "number"
        and type(bounds[3]) == "number" and type(bounds[4]) == "number" and type(bounds[5]) == "number"
        and bounds[1] > bounds[2] and bounds[3] > bounds[4] then
      boundsByName[NormalizeLocation(name)] = bounds
    end
  end

  boundsSource, boundsCopy = ebonBounds, boundsByName

  return boundsByName
end

function RT.WorldPointFor(mapName, x, y, areaId)
  local zone = (areaId and zonesByMap[tonumber(areaId)]) or zonesByName[NormalizeLocation(mapName)]
  local bounds = (ClientBounds() or {})[NormalizeLocation(zone and zone.name or mapName)]

  if not bounds and zone and zone.bounds then
    bounds = zone.bounds
  end

  if not bounds then
    return nil
  end

  return MapToWorld(zone, bounds, x, y)
end

local function RegionAt(serverMap, north, west)
  local bounds = ClientBounds() or {}
  for _, zone in ipairs(regionZones) do
    local b = bounds[NormalizeLocation(zone.name)]
    if b and b[5] == serverMap and west <= b[1] and west >= b[2] and north <= b[3] and north >= b[4] then
      return zone.region
    end
  end
  return nil
end

function RT.PlayerWorldPoint()
  local position, failure = EbonAPI.Ebonhold.PlayerPosition()
  if not position then
    return nil, failure
  end
  if position.serverMap == nil then
    return nil
  end
  local serverMap = tonumber(position.serverMap)
  local region = RegionAt(serverMap, position.north, position.west)
  return { x = position.west, y = position.north, map = tostring(serverMap) .. ":" .. (region or ""), continent = serverMap }
end

function Core.travelZoneKey(location)
  local wanted = NormalizeLocation(location)

  if wanted == "" then
    return ""
  end

  return subzonesByName[wanted] or wanted
end

local MAP_REFRESH_INTERVAL = 1
local mapRefreshedAt

local function RefreshPlayerMap()
  if not SetMapToCurrentZone then
    return
  end

  if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
    return
  end

  local now = GetTime and GetTime() or 0

  if mapRefreshedAt and now - mapRefreshedAt < MAP_REFRESH_INTERVAL then
    return
  end

  mapRefreshedAt = now
  SetMapToCurrentZone()
end

function RT.InvalidatePlayerMap()
  mapRefreshedAt = nil
end

function RT.GetCurrentZoneKey()
  if not GetMapInfo then
    return ""
  end

  RefreshPlayerMap()

  return NormalizeLocation(GetMapInfo())
end

function RT.ReadPlayerMapPoint()
  if not GetPlayerMapPosition then
    return nil
  end

  RefreshPlayerMap()

  local x, y = GetPlayerMapPosition("player")
  x, y = tonumber(x), tonumber(y)

  if not x or not y or (x == 0 and y == 0) then
    return nil
  end

  local areaId = GetCurrentMapAreaID and tonumber(GetCurrentMapAreaID())

  if areaId == 0 then
    areaId = nil
  end

  return (GetMapInfo and GetMapInfo()) or "", x, y, areaId
end

function RT.IsPlayerInTravelZone(location)
  local wanted = Core.travelZoneKey(location)

  if wanted == "" then
    return false
  end

  local here = RT.GetCurrentZoneKey()

  if here == "" then
    return false
  end

  return here == wanted
end

function Core.chooseMeetingStone(checkpoints, text)
  if type(checkpoints) ~= "table" then
    return nil
  end

  local haystack = NormalizeLocation(text)
  local best, bestLength

  for i = 1, #(checkpoints) do
    local checkpoint = checkpoints[i]

    if type(checkpoint) == "table" and string.find(tostring(checkpoint.kind or ""), "^MEETINGSTONE")
        and Core.travelCheckpointUsable(checkpoint) then
      local name = NormalizeLocation(checkpoint.name)

      if name ~= "" and string.find(haystack, name, 1, true) and (not best or string.len(name) > bestLength) then
        best, bestLength = checkpoint, string.len(name)
      end
    end
  end

  return best
end

function Core.chooseTravelCheckpoint(checkpoints, location, zoneOnly, poi)
  if type(checkpoints) ~= "table" then
    return nil
  end

  local wanted = NormalizeLocation(location)
  wanted = subzonesByName[wanted] or wanted

  if wanted == "" then
    return nil
  end

  local boundsByName = ClientBounds()

  local anchors = {}
  local zones = {}
  local targetZone = zonesByName[wanted]
  local poiZone = type(poi) == "table" and zonesByMap[(tonumber(poi.area) or -1) + 1] or nil
  local poiBounds = poiZone and ((boundsByName and boundsByName[NormalizeLocation(poiZone.name)]) or poiZone.bounds)
  local poiX, poiY = type(poi) == "table" and tonumber(poi.x), type(poi) == "table" and tonumber(poi.y)
  if poiBounds and poiX and poiY then
    targetZone = poiZone
    zones[poiZone.mapId] = true
    anchors[1] = { x = poiY, y = poiX, map = WorldMapKey(poiZone, poiBounds[5]) }
  elseif targetZone then
    zones[targetZone.mapId] = true
    local bounds = (boundsByName and boundsByName[wanted]) or targetZone.bounds
    if bounds then
      anchors[1] = { x = (bounds[1] + bounds[2]) / 2, y = (bounds[3] + bounds[4]) / 2,
        map = WorldMapKey(targetZone, bounds[5]) }
    end
  else
    for _, checkpoint in ipairs(checkpoints) do
      if NormalizeLocation(checkpoint.name) == wanted then
        zones[tonumber(checkpoint.mapId) or 0] = true
        local point = WorldPoint(checkpoint, boundsByName)
        if point then
          table.insert(anchors, point)
        end
      end
    end
    if #anchors == 0 then
      for _, entrance in ipairs(entrancesByName[wanted] or {}) do
        local zone = zonesByName[NormalizeLocation(entrance[1])]
        if zone then
          zones[zone.mapId] = true
          local point = WorldPoint({ mapId = zone.mapId, serverMapId = zone.serverMapId,
            x = entrance[2], y = entrance[3] }, boundsByName)
          if point then
            table.insert(anchors, point)
          end
        end
      end
    end
  end

  local best, bestScore, bestRank

  for i = 1, #(checkpoints) do
    local checkpoint = checkpoints[i]

    if Core.travelCheckpointUsable(checkpoint) then
      local full = NormalizeLocation(checkpoint.name)
      local zone = NormalizeLocation(Core.travelCheckpointLocation(checkpoint.name))

      local exact = full == wanted or zone == wanted
      local sameZone = targetZone and tonumber(checkpoint.mapId) == targetZone.mapId
        and tonumber(checkpoint.serverMapId) == targetZone.serverMapId
      local rank = (exact or sameZone) and 0 or 1
      local point = WorldPoint(checkpoint, boundsByName)
      local score
      if point then
        for _, anchor in ipairs(anchors) do
          if point.map == anchor.map then
            local distance = (point.x - anchor.x)^2 + (point.y - anchor.y)^2
            if not score or distance < score then
              score = distance
            end
          end
        end
      end
      local inZone = exact or sameZone or zones[tonumber(checkpoint.mapId) or 0] == true
      if zoneOnly and not inZone then
        score = nil
      elseif not score and (exact or (zoneOnly and inZone)) then
        score = math.huge
      end
      if score then
        if not best or rank < bestRank or (rank == bestRank and (score < bestScore
            or (score == bestScore and tonumber(checkpoint.id) < tonumber(best.id)))) then
          best = checkpoint
          bestScore = score
          bestRank = rank
        end
      end
    end
  end

  return best
end

function Core.travelCheckpointLabel(checkpoint)
  if type(checkpoint) ~= "table" then
    return ""
  end

  local name = Trim(EbonAPI.Ebonhold.Text(checkpoint.name))

  if name == "" then
    return ""
  end

  local place = name:match("^([^,]+)")

  return Trim(place or name)
end

function Core.countUnlockedCheckpoints(checkpoints)
  local count = 0

  if type(checkpoints) ~= "table" then
    return count
  end

  for i = 1, #(checkpoints) do
    if Core.travelCheckpointUsable(checkpoints[i]) then
      count = count + 1
    end
  end

  return count
end

Core.TRAVEL_CAPITALS = {
  { key = "dalaran", id = 310 }, { key = "stormwind", id = 2 }, { key = "ironforge", id = 6 },
  { key = "rutheran", id = 27 }, { key = "orgrimmar", id = 23 }, { key = "thunderbluff", id = 22 },
  { key = "undercity", id = 11 }, { key = "silvermoon", id = 82 }, { key = "exodar", id = 94 },
  { key = "shattrath", id = 128 }, { key = "acherus", id = 315 },
}

Core.TRAVEL_DEFAULT_AUTO = "auto"

Core.TRAVEL_RACE_CAPITAL = {
  Human = "stormwind", Dwarf = "ironforge", Gnome = "ironforge", NightElf = "rutheran",
  Orc = "orgrimmar", Troll = "orgrimmar", Tauren = "thunderbluff", Scourge = "undercity",
  BloodElf = "silvermoon", Draenei = "exodar",
}

local function UnlockedCapital(checkpoints, key)
  for _, capital in ipairs(Core.TRAVEL_CAPITALS) do
    if capital.key == key then
      for i = 1, #(checkpoints) do
        local checkpoint = checkpoints[i]

        if type(checkpoint) == "table" and tonumber(checkpoint.id) == capital.id
            and Core.travelCheckpointUsable(checkpoint) then
          return checkpoint
        end
      end
    end
  end

  return nil
end

function Core.chooseDefaultCapital(checkpoints, setting, raceToken)
  if type(checkpoints) ~= "table" then
    return nil
  end

  return (setting and setting ~= Core.TRAVEL_DEFAULT_AUTO and UnlockedCapital(checkpoints, setting))
      or UnlockedCapital(checkpoints, "dalaran")
      or UnlockedCapital(checkpoints, Core.TRAVEL_RACE_CAPITAL[raceToken or ""] or "")
end

local serviceDown = false

local function GetService()
  return EbonAPI.Ebonhold.Service("CheckpointService")
end

local function GetCheckpoints()
  local service = GetService()

  if not service or not service.GetCheckpoints then
    return nil
  end

  local list = RT.api:Guard("travel.checkpoints", service.GetCheckpoints)

  if type(list) ~= "table" then
    return nil
  end

  return list
end

function RT.RequestTravelCheckpoints(source)
  local service = GetService()

  if not service or not service.RequestCheckpoints then
    return false
  end

  local now = GetTime and GetTime() or 0

  if requestedAt and (now - requestedAt) < 30 then
    return false
  end

  requestedAt = now

  local _, problem = RT.api:Guard("travel.request", service.RequestCheckpoints)
  local ok = problem == nil
  Log("travel", "requested checkpoint data ", tostring(source), " ok=", tostring(ok))

  return ok
end

function RT.IsTravelEnabled()
  return state and state.travelEnabled and true or false
end

function RT.IsTravelAutoEnabled()
  if not RT.IsTravelEnabled() then
    return false
  end

  return state and state.travelAuto and true or false
end

local function ContractKey(contract)
  if type(contract) ~= "table" then
    return ""
  end

  return tostring(contract.questId or 0) .. ":" .. tostring(Core.questTitle(contract))
end

local selectedQuestId

local autoTarget, autoLocation, acceptedQuestKey, lastAcceptedQuestKey

function RT.GetAcceptedTravelContract()
  local board = RT.GetBoard()

  if not board then
    return nil
  end

  local lastID = RT.lastAcceptedQuest and tonumber(RT.lastAcceptedQuest.questID)
  local first

  for i = 1, #(board.quests) do
    local quest = board.quests[i]

    if quest.state == Core.STATE.ACCEPTED then
      if lastID and quest.questId == lastID then
        return quest
      end

      first = first or quest
    end
  end

  return first
end

function RT.GetTravelContract()
  local selected = selectedQuestId and RT.IsBoardWindowShown and RT.IsBoardWindowShown()
      and RT.GetBoardQuest(selectedQuestId)

  return selected or RT.GetAcceptedTravelContract()
end

local function IsInstanceContract(contract)
  local category = Core.questCategory(contract)

  return category == Core.CATEGORY.DUNGEON or category == Core.CATEGORY.RAID
end

local function UpdateButton()
  if not button then
    return
  end

  if not suggestion then
    button:Hide()
    return
  end

  button:SetText(string.format(L.TRAVEL_BUTTON_FORMAT, Core.travelCheckpointLabel(suggestion)))
  button:Show()
end

local function CreateButton()
  if button or not RT.controlFrame then
    return button
  end

  button = Skin.Root(Skin.MakeButton(UIParent, {
    name = BUTTON_NAME,
    point = { "TOPLEFT", RT.controlFrame, "BOTTOMLEFT", 0, -4 },
    onClick = function()
      RT.TravelToSuggestion("button")
    end,
    tipTitle = "TRAVEL_BUTTON_LABEL",
    tipBody = "TRAVEL_BUTTON_TOOLTIP",
  }))

  button:Hide()

  return button
end

local function AutoTravelBlocked()
  if InCombatLockdown and InCombatLockdown() then
    return "combat"
  end

  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
    return "dead"
  end

  return nil
end

local SendTravel

RT.AutoTravelBlocked = AutoTravelBlocked

function MaybeAutoTravel(questKey)
  if RT.IsStoppedByDeath() then
    return false
  end
  if not RT.IsTravelAutoEnabled() then
    autoQuestKey = questKey
    return false
  end

  if not autoTarget or questKey == "" then
    return false
  end

  if autoQuestKey == nil then
    autoQuestKey = questKey
    Log("travel", "auto armed on ", questKey)
    return false
  end

  if questKey == autoQuestKey then
    return false
  end

  local service = GetService()
  if not service or type(service.UseCheckpoint) ~= "function" then
    return false
  end

  local blocked = AutoTravelBlocked()

  if blocked then
    Log("travel", "auto held (", blocked, ") for ", questKey)
    return false
  end

  if RT.IsPlayerInTravelZone(autoLocation) then
    autoQuestKey = questKey
    Log("travel", "auto skipped, already in ", tostring(autoLocation))
    return false
  end

  autoQuestKey = questKey

  return SendTravel(autoTarget, "auto")
end

function RT.ResetTravelAutoBaseline()
  autoQuestKey = ContractKey(RT.GetAcceptedTravelContract())
end

function RT.GetTravelSuggestion()
  return suggestion
end

function RT.ClearTravelSuggestion()
  suggestion = nil
  suggestionQuestKey = nil
  lastTravelCheckpoints = nil
  lastTravelUnlockedCount = nil
  lastTravelLocation = nil
  autoTarget = nil
  autoLocation = nil
  lastAcceptedQuestKey = nil
  UpdateButton()
end

local function PlayerRaceToken()
  if not UnitRace then
    return nil
  end

  local _, token = UnitRace("player")

  return token
end

local function PoiOf(contract)
  local area = tonumber(contract and contract.poiArea)
  local x, y = tonumber(contract and contract.poiX), tonumber(contract and contract.poiY)

  if not area or area <= 0 or not x or not y then
    return nil
  end

  local areas = EbonAPI.Ebonhold.Service("CallboardMapAreas")

  if not areas or type(areas[area]) ~= "table" then
    return nil
  end

  return { area = area, x = x, y = y }
end

function RT.ContractWorldPoint(contract)
  local poi = PoiOf(contract)
  local zone = poi and zonesByMap[poi.area + 1]
  local bounds = zone and ((ClientBounds() or {})[NormalizeLocation(zone.name)] or zone.bounds)

  if not bounds then
    return nil
  end

  return { x = poi.y, y = poi.x, map = WorldMapKey(zone, bounds[5]), zone = zone.name }
end

function RT.NearestContractTarget()
  local board = RT.GetBoard and RT.GetBoard()
  local here = board and RT.PlayerWorldPoint()

  if not here then
    return nil
  end

  local best, bestPoint, bestDistance, other, otherPoint

  for _, contract in ipairs(board.accepted or {}) do
    local point = RT.ContractWorldPoint(contract)

    if point and point.map == here.map then
      local distance = (point.x - here.x) ^ 2 + (point.y - here.y) ^ 2

      if not best or distance < bestDistance then
        best, bestPoint, bestDistance = contract, point, distance
      end
    elseif point and not other then
      other, otherPoint = contract, point
    end
  end

  if best then
    return best, bestPoint, true
  end

  return other, otherPoint, false
end

local function ChooseFor(contract, checkpoints)
  local location = Core.travelLocationFromText(Core.objectiveText(contract))
  local chosen = IsInstanceContract(contract)
      and Core.chooseMeetingStone(checkpoints, Core.questTitle(contract) .. " " .. Core.objectiveText(contract))
      or nil

  chosen = chosen or Core.chooseTravelCheckpoint(checkpoints, location, true, PoiOf(contract))

  if chosen then
    return chosen, location, true
  end

  return Core.chooseDefaultCapital(checkpoints, state and state.travelDefault, PlayerRaceToken()), location, false
end

function RT.RefreshTravelSuggestion(source, skipAuto)
  if not RT.IsTravelEnabled() then
    RT.ClearTravelSuggestion()
    return nil
  end

  local contract = RT.GetTravelContract()

  if not contract then
    if autoQuestKey ~= nil then
      autoQuestKey = ""
    end
    RT.ClearTravelSuggestion()
    return nil
  end

  local questKey = ContractKey(contract)
  local accepted = RT.GetAcceptedTravelContract()
  local acceptedKey = accepted and ContractKey(accepted) or ""
  acceptedQuestKey = acceptedKey

  if autoQuestKey == nil then
    autoQuestKey = acceptedKey
  end

  local checkpoints = GetCheckpoints()
  local unlocked = Core.countUnlockedCheckpoints(checkpoints)

  if unlocked <= 0 then
    RT.RequestTravelCheckpoints("refresh")
    RT.ClearTravelSuggestion()
    return nil
  end

  local location = Core.travelLocationFromText(Core.objectiveText(contract))

  if source == "watch" and suggestionQuestKey == questKey and lastAcceptedQuestKey == acceptedKey
      and lastTravelCheckpoints == checkpoints and lastTravelUnlockedCount == unlocked
      and lastTravelLocation == location then
    if not skipAuto then
      MaybeAutoTravel(acceptedKey)
    end
    return suggestion
  end

  lastTravelCheckpoints = checkpoints
  lastTravelUnlockedCount = unlocked
  lastTravelLocation = location
  lastAcceptedQuestKey = acceptedKey

  local chosen, _, onSite = ChooseFor(contract, checkpoints)
  local portal = RT.PortalSuggestion and RT.PortalSuggestion(checkpoints, location)

  if portal then
    chosen = portal
  end

  if accepted == contract then
    autoTarget, autoLocation = onSite and chosen or nil, location
  elseif accepted then
    local target, where, there = ChooseFor(accepted, checkpoints)
    autoTarget, autoLocation = there and target or nil, where
  else
    autoTarget, autoLocation = nil, nil
  end

  if (chosen and chosen.id) ~= (suggestion and suggestion.id) or suggestionQuestKey ~= questKey then
    Log("travel", "contract=", Core.questTitle(contract), " location=", location,
      " checkpoint=", chosen and chosen.name or "none", " source=", tostring(source),
      " selected=", tostring(selectedQuestId))
  end

  suggestion = chosen
  suggestionQuestKey = questKey
  CreateButton()
  UpdateButton()
  if not skipAuto then
    MaybeAutoTravel(acceptedKey)
  end

  return suggestion
end

function RT.SetTravelSelection(questId)
  questId = tonumber(questId)

  if questId == selectedQuestId then
    return
  end

  selectedQuestId = questId
  RT.RefreshTravelSuggestion("selection", true)
end

function RT.GetTravelSelection()
  return selectedQuestId
end

function SendTravel(target, source)
  local blocked = AutoTravelBlocked()

  if blocked then
    RT.api:Report(RT.api:Problem(blocked == "combat" and "TRAVEL.IN_COMBAT" or "TRAVEL.PLAYER_DEAD"))
    return false
  end

  local service = GetService()

  if not service or not service.UseCheckpoint then
    RT.Error(L.TRAVEL_UNAVAILABLE)
    return false
  end

  if not Core.travelCheckpointUsable(target) then
    RT.api:Report(RT.api:Problem("TRAVEL.CHECKPOINT_LOCKED", { checkpoint = Core.travelCheckpointLabel(target) }))
    return false
  end

  Log("travel", "using checkpoint ", tostring(target.id), " ", tostring(target.name), " source=", tostring(source))

  autoQuestKey = acceptedQuestKey
  local ok, result = pcall(service.UseCheckpoint, tonumber(target.id))

  if not ok or result == false then
    RT.Error(L.TRAVEL_UNAVAILABLE)
    return false
  end

  Log("travel", "teleport requested source=", tostring(source),
    " target=", Core.travelCheckpointLabel(target))

  return true
end

RT.SendTravel = SendTravel

local ROAM_MIN_INTERVAL = 60
local roamAt, roamFrom, roamDestination

function RT.MaybeTravelAround()
  if not RT.IsTravelAutoEnabled() then
    return false
  end

  if not RT.IsStarted() then
    return false
  end

  if IsInInstance and IsInInstance() then
    return false
  end

  local board = RT.GetBoard and RT.GetBoard()

  if not board or #(board.accepted or {}) == 0 then
    return false
  end

  local here = RT.GetCurrentZoneKey()

  if here == "" then
    return false
  end

  for _, contract in ipairs(board.accepted) do
    local point = RT.ContractWorldPoint(contract)

    if point and RT.IsPlayerInTravelZone(point.zone) then
      return false
    end
  end

  local contract, point = RT.NearestContractTarget()

  if not contract or not point then
    return false
  end

  local destination = Core.travelZoneKey(point.zone)
  local now = GetTime and GetTime() or 0

  if roamAt and now - roamAt < ROAM_MIN_INTERVAL then
    return false
  end

  if roamDestination == destination and roamFrom == here then
    return false
  end

  if AutoTravelBlocked() then
    return false
  end

  local service = GetService()

  if not service or type(service.UseCheckpoint) ~= "function" then
    return false
  end

  local target = Core.chooseTravelCheckpoint(GetCheckpoints(), point.zone, true, PoiOf(contract))

  if not target then
    return false
  end

  roamAt, roamFrom, roamDestination = now, here, destination
  Log("travel", "nothing left around ", here, ", going to ", tostring(point.zone))

  return SendTravel(target, "around")
end

function RT.TravelToSuggestion(source)
  local previousId = suggestion and suggestion.id
  local previousQuestKey = suggestionQuestKey
  local target = RT.RefreshTravelSuggestion("send", true)

  if not target then
    RT.api:Report(RT.api:Problem("TRAVEL.NO_DESTINATION", { quest = L.QUEST_FALLBACK_LABEL }))
  elseif target.id ~= previousId or suggestionQuestKey ~= previousQuestKey then
    RT.api:Report(RT.api:Problem("TRAVEL.SUGGESTION_CHANGED", { checkpoint = Core.travelCheckpointLabel(target) }))
  end

  if not target or target.id ~= previousId or suggestionQuestKey ~= previousQuestKey then
    return false
  end

  return SendTravel(target, source)
end

function RT.TravelDefaultChoices()
  local values = { [Core.TRAVEL_DEFAULT_AUTO] = L.TRAVEL_DEFAULT_AUTO }
  local sorting = { Core.TRAVEL_DEFAULT_AUTO }
  local checkpoints = GetCheckpoints() or {}

  for _, capital in ipairs(Core.TRAVEL_CAPITALS) do
    local label

    for i = 1, #(checkpoints) do
      if type(checkpoints[i]) == "table" and tonumber(checkpoints[i].id) == capital.id then
        label = Core.travelCheckpointLabel(checkpoints[i])
        break
      end
    end

    values[capital.key] = (label and label ~= "") and label or capital.key
    sorting[#(sorting) + 1] = capital.key
  end

  return values, sorting
end

function RT.SetTravelDefault(key)
  RT.SetField("travelDefault", key)
end

function RT.OnTravelEnabledChanged()
  if RT.IsTravelEnabled() then
    RT.RequestTravelCheckpoints("enabled")
  end

  RT.ResetTravelAutoBaseline()
  RT.RefreshTravelSuggestion("toggle")
end

function RT.OnTravelAutoChanged()
  RT.ResetTravelAutoBaseline()
  Log("travel", "auto travel ", tostring(RT.IsTravelAutoEnabled()))
end

function RT.SetTravelEnabled(enabled)
  RT.SetField("travelEnabled", enabled and true or false)
end

function RT.SetTravelAutoEnabled(enabled)
  RT.SetField("travelAuto", enabled and true or false)
end

function RT.WatchTravelSuggestion()
  if not state then
    return 5
  end

  if not RT.IsTravelEnabled() then
    if suggestion then
      RT.ClearTravelSuggestion()
    end

    return 5
  end

  if not GetService() then
    if not serviceDown then
      serviceDown = true
      RT.api:Degrade(RT.api:Problem("TRAVEL.SERVICE_UNAVAILABLE"))
    end

    RT.ClearTravelSuggestion()
    return 5
  end

  if serviceDown then
    serviceDown = false
    RT.api:Restore("TRAVEL.SERVICE_UNAVAILABLE")
  end

  RT.RefreshTravelSuggestion("watch")
  RT.MaybeTravelAround()

  return 1
end
