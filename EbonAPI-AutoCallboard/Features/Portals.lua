local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local L = AutoCallboardLocale
local state = RT.state

local Log = RT.Log

local DRAIN_SPELL_ID = 902052
local REQUEST_INTERVAL = 30
local RETRY_DELAY = 1
local RETRY_LIMIT = 10
local TICK_ID = "portalDrain"
local RETRY_ID = "portalAutoRetry"

local events
local pendingTarget
local retries = 0
local requestedAt
local arrowPortalId
local reportedZone
local drainExpires
local drainTicking
local initialized

local function Distance2(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return dx * dx + dy * dy
end

local function PortalAcbXY(portal)
  return tonumber(portal.y), tonumber(portal.x)
end

local function PortalZoneRowOf(portal)
  return Core.portalZoneRow((tonumber(portal.area) or -1) - 1)
end

local function IdBefore(a, b)
  local na, nb = tonumber(a), tonumber(b)

  if na and nb then
    return na < nb
  end

  return tostring(a) < tostring(b)
end

function Core.nearestPortal(portals, px, py, excludeId, continent)
  if type(portals) ~= "table" or not tonumber(px) or not tonumber(py) then
    return nil
  end

  local best, bestScore, bestSame

  for i = 1, #portals do
    local portal = portals[i]

    local ax, ay
    if type(portal) == "table" then
      ax, ay = PortalAcbXY(portal)
    end

    if type(portal) == "table" and portal.id ~= nil and portal.id ~= excludeId and ax and ay then
      local same = continent == nil or tonumber(portal.map) == continent
      local score = Distance2(ax, ay, px, py)

      if not best or (same and not bestSame) or (same == bestSame
          and (score < bestScore or (score == bestScore and IdBefore(portal.id, best.id)))) then
        best, bestScore, bestSame = portal, score, same
      end
    end
  end

  return best
end

function Core.nextAutoPortal(portals, usedId, px, py, continent)
  return Core.nearestPortal(portals, px, py, usedId, continent)
end

function Core.shouldTeleportToPortal(player, portal, checkpoint)
  if type(player) ~= "table" or type(portal) ~= "table" then
    return false
  end

  if type(checkpoint) ~= "table" then
    return false
  end

  if player.continent and portal.map and tonumber(player.continent) ~= tonumber(portal.map) then
    return true
  end

  local ax, ay = PortalAcbXY(portal)
  local playerDistance = Distance2(player.x, player.y, ax, ay)
  local checkpointDistance = Distance2(checkpoint.x, checkpoint.y, ax, ay)

  return checkpointDistance < playerDistance
end

function Core.drainRemaining(expiration, now)
  expiration, now = tonumber(expiration), tonumber(now)

  if not expiration or not now or expiration <= 0 then
    return nil
  end

  local remaining = expiration - now

  if remaining <= 0 then
    return nil
  end

  return remaining
end

function Core.portalZoneRow(area)
  local wanted = (tonumber(area) or -1) + 1

  for _, row in ipairs(Core.travelZones or {}) do
    if row[2] == wanted then
      return row
    end
  end

  return nil
end

local function OpenPortals()
  local service = EbonAPI and EbonAPI.Ebonhold

  if not service or not service.OpenPortals then
    return nil
  end

  return service.OpenPortals()
end

local PORTAL_ICON = "Interface\\Icons\\Spell_Shadow_SummonFelGuard"
local countButton
local countShown

local function PortalCount()
  local portals = OpenPortals()

  return portals and #portals or nil
end

local function CountText(count)
  return string.format("|T%s:0|t %s", PORTAL_ICON, count or "-")
end

local CONTINENT_INDEX = { [1] = 1, [0] = 2, [530] = 3, [571] = 4 }

local function ContinentName(portals)
  local first = portals and portals[1]
  local index = type(first) == "table" and CONTINENT_INDEX[tonumber(first.map)]

  if not index or not GetMapContinents then
    return nil
  end

  local name = select(index, GetMapContinents())

  if type(name) == "string" and name ~= "" then
    return name
  end

  return nil
end

local function CountTip()
  local portals = OpenPortals()
  local count = portals and #portals or nil
  local line = L.PORTAL_COUNT_UNKNOWN

  if count then
    local name = ContinentName(portals)

    if name then
      line = string.format(L.PORTAL_COUNT_TIP_LINE, name, count)
    else
      line = string.format(L.PORTAL_COUNT_TIP_LINE_PLAIN, count)
    end
  end

  GameTooltip:AddLine(line, 1, 1, 1)
  GameTooltip:AddLine(L.PORTAL_COUNT_CLICK, 0.8, 0.8, 0.8)
end

function RT.PortalCountButton(parent)
  if not state.portalCount then
    if countButton then
      countButton:Hide()
    end

    return nil
  end

  if not countButton then
    countButton = AutoCallboardSkin.MakeButton(parent, {
      name = "AutoCallboardPortalCount",
      onClick = function() RT.TravelToNearestPortal("portalCount") end,
      tipTitle = "PORTAL_COUNT_TIP_TITLE",
      tipExtra = CountTip,
    })
  end

  countShown = PortalCount()
  countButton:SetText(CountText(countShown))

  return countButton
end

local function RefreshPortalCount()
  if not state.portalCount or not countButton then
    return
  end

  local count = PortalCount()

  if count ~= countShown then
    RT.LayoutMainToolbar()
  end
end

local function RequestPortals()
  local service = EbonAPI and EbonAPI.Ebonhold

  if not service or not service.RequestPortals then
    return
  end

  local now = GetTime()

  if requestedAt and now - requestedAt < REQUEST_INTERVAL then
    return
  end

  requestedAt = now
  service.RequestPortals()
end

local POSITION_CAUSE = {
  ["client:absent"] = "PORTAL.POSITION_CLIENT_ABSENT",
  ["client:no-numbers"] = "PORTAL.POSITION_CLIENT_NO_NUMBERS",
  ["map:no-position"] = "PORTAL.POSITION_MAP_NO_POSITION",
  ["map:no-bounds"] = "PORTAL.POSITION_MAP_NO_BOUNDS",
}

local function PlayerWorldPoint()
  local point, failure = RT.PlayerWorldPoint()

  if point then
    reportedZone = nil

    return point
  end

  if failure and not failure.indoors then
    local key = table.concat(failure.tried, " ; ")

    if reportedZone ~= key then
      reportedZone = key
      local cause

      for _, code in ipairs(failure.tried) do
        local name = POSITION_CAUSE[code]

        if name then
          cause = RT.api:Problem(name, nil, cause)
        else
          cause = RT.api:Problem("PORTAL.POSITION_UNKNOWN_CODE", { code = code }, cause)
        end
      end

      RT.api:Report(RT.api:Problem("PORTAL.PLAYER_POSITION_UNKNOWN", { tried = key }, cause))
    end
  end

  return nil
end

local function CheckpointWorldPoint(checkpoint)
  local row = Core.portalZoneRow((tonumber(checkpoint.mapId) or 0) - 1)

  if not row then
    return nil
  end

  local point = RT.WorldPointFor(row[1], checkpoint.x, checkpoint.y)

  if not point then
    return nil
  end

  return { x = point.x, y = point.y, map = point.map }
end

local function PortalPoint(portal)
  local row = PortalZoneRowOf(portal)
  local ax, ay = PortalAcbXY(portal)

  if not row or not ax or not ay then
    return nil
  end

  return { x = ax, y = ay, map = tostring(row[3]) .. ":" .. (row[8] or ""), zone = row[1] }
end

local function ChooseCheckpoint(checkpoints, portal)
  local row = PortalZoneRowOf(portal)
  local point = PortalPoint(portal)

  if not row or not point then
    return nil
  end

  return Core.chooseTravelCheckpoint(checkpoints, row[1], false,
    { area = (tonumber(portal.area) or 0) - 1, x = point.y, y = point.x })
end

function Core.bestPortalCheckpoint(checkpoints, portal)
  return ChooseCheckpoint(checkpoints, portal)
end

local function TeleportFor(checkpoints, portal, player)
  local checkpoint = ChooseCheckpoint(checkpoints, portal)

  if not checkpoint then
    return nil
  end

  local point = CheckpointWorldPoint(checkpoint)

  if point and player and not Core.shouldTeleportToPortal(player, portal, point) then
    return nil
  end

  return checkpoint
end

local function DrainExpiration()
  if not UnitAura then
    return nil
  end

  for i = 1, 40 do
    local name, _, _, _, _, _, expiration, _, _, _, spellId = UnitAura("player", i, "HARMFUL")

    if not name then
      return nil
    end

    if spellId == DRAIN_SPELL_ID then
      return expiration
    end
  end

  return nil
end

local function FormatTime(seconds)
  seconds = math.ceil(seconds)

  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function RT.PortalRemainingText()
  local remaining = Core.drainRemaining(drainExpires, GetTime())

  if not remaining then
    return nil
  end

  return string.format(L.PORTAL_REMAINING_FORMAT, FormatTime(remaining))
end

local function StopDrainTick()
  if drainTicking then
    drainTicking = false
    RT.api:Untick(TICK_ID)
  end
end

local function PaintDrain()
  if not state.portalFollow then
    drainExpires = nil
    StopDrainTick()
    return
  end

  local text = RT.PortalRemainingText()

  if not text then
    drainExpires = nil
    StopDrainTick()
    return
  end

  local arrow = RT.routeArrow

  if not arrow or not arrow.IsShown or not arrow:IsShown() then
    StopDrainTick()
    return
  end

  if not arrow.status then
    return
  end

  local current = arrow.status:GetText() or ""

  if not string.find(current, text, 1, true) then
    arrow.status:SetText(current == "" and text or (current .. " - " .. text))
  end
end

local function RefreshDrain()
  drainExpires = DrainExpiration()

  if not drainExpires then
    StopDrainTick()
    return
  end

  PaintDrain()

  if not drainTicking then
    drainTicking = true
    RT.api:Tick(TICK_ID, 1, function()
      local target = RT.GetRouteArrowTarget and RT.GetRouteArrowTarget()

      if target and target.source == "portal" then
        RT.UpdateRouteArrow(true)
      end

      PaintDrain()
    end)
  end
end

local function Checkpoints()
  local service = EbonAPI.Ebonhold.Service("CheckpointService")

  if not service or not service.GetCheckpoints then
    return nil
  end

  local list = RT.api:Guard("portal.checkpoints", service.GetCheckpoints)

  return type(list) == "table" and list or nil
end

local function NearestPortalTeleport(checkpoints)
  local portals = OpenPortals()

  if not portals then
    RequestPortals()
    return nil
  end

  local player = PlayerWorldPoint()

  if not player then
    return nil
  end

  local portal = Core.nearestPortal(portals, player.x, player.y, nil, player.continent)

  if not portal then
    arrowPortalId = nil
    return nil
  end

  local point = PortalPoint(portal)

  if point then
    local target = RT.GetRouteArrowTarget and RT.GetRouteArrowTarget()

    if arrowPortalId ~= portal.id or not target or target.source ~= "portal" then
      arrowPortalId = portal.id
      RT.SetRouteArrowWorldTarget(point, nil)
    end
  end

  return TeleportFor(checkpoints, portal, player), true
end

function RT.PortalSuggestion(checkpoints, location)
  if not state.portalFollow then
    return nil
  end

  if not events or not events:IsListening("UNIT_AURA") then
    RT.WatchPortalDrain()
  end

  local target = NearestPortalTeleport(checkpoints)

  return target
end

function RT.TravelToNearestPortal(source)
  local checkpoints = Checkpoints()
  local target, found
  if checkpoints then
    target, found = NearestPortalTeleport(checkpoints)
  end

  if not target then
    if not found then
      RT.api:Report(RT.api:Problem("TRAVEL.NO_DESTINATION", { quest = L.PORTAL_COUNT_TIP_TITLE }))
    end

    return false
  end

  return RT.SendTravel(target, source)
end

local function TryAuto()
  local target = pendingTarget

  if not target then
    return
  end

  if RT.IsStoppedByDeath() then
    pendingTarget = nil
    events:Unlisten("PLAYER_REGEN_ENABLED")
    return
  end

  local blocked = RT.AutoTravelBlocked()

  if blocked == "combat" then
    events:Listen("PLAYER_REGEN_ENABLED")
    return
  end

  if blocked == "dead" then
    pendingTarget = nil
    return
  end

  if blocked then
    retries = retries + 1

    if retries > RETRY_LIMIT then
      pendingTarget = nil
      return
    end

    RT.api:After(RETRY_ID, RETRY_DELAY, TryAuto)
    return
  end

  pendingTarget = nil
  events:Unlisten("PLAYER_REGEN_ENABLED")
  Log("travel", "portal auto teleport")
  RT.SendTravel(target, "portal")
end

local function ArrowOnPortal()
  local target = RT.GetRouteArrowTarget and RT.GetRouteArrowTarget()

  return target ~= nil and target.source == "portal"
end

local function RetargetArrow(excludeId)
  local portals = OpenPortals()
  local player = PlayerWorldPoint()

  if not portals or not player then
    return nil
  end

  local portal = Core.nearestPortal(portals, player.x, player.y, excludeId, player.continent)

  if not portal then
    arrowPortalId = nil

    if ArrowOnPortal() then
      RT.ClearRouteArrowTarget()
    end

    return nil
  end

  local point = PortalPoint(portal)

  if point then
    arrowPortalId = portal.id
    RT.SetRouteArrowWorldTarget(point, nil)
  end

  return portal
end

local function OnPortalUsed(_, id)
  local portal

  if ArrowOnPortal() or state.portalFollow then
    portal = RetargetArrow(id)
  elseif state.portalAuto then
    local portals = OpenPortals()
    local player = PlayerWorldPoint()

    if portals and player then
      portal = Core.nextAutoPortal(portals, id, player.x, player.y, player.continent)
    end
  end

  if not state.portalAuto or not portal then
    return
  end

  local checkpoints = Checkpoints()
  local target = checkpoints and TeleportFor(checkpoints, portal, nil)

  if not target then
    return
  end

  pendingTarget = target
  retries = 0
  TryAuto()
end

local function OnEvent(event, unit)
  if event == "UNIT_AURA" then
    if unit == "player" and state.portalFollow then
      RefreshDrain()
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    events:Unlisten("PLAYER_REGEN_ENABLED")
    TryAuto()
  end
end

function RT.InitPortals()
  if initialized then
    return
  end

  initialized = true
  events = RT.NewEventRelay(OnEvent)
  RT.api:On("SERVER_PORTALS", function()
    arrowPortalId = nil
    RefreshPortalCount()
    if state.portalFollow then
      RT.RefreshTravelSuggestion("portals", true)
    elseif ArrowOnPortal() then
      RetargetArrow(nil)
    end
  end)
  RT.api:On("SERVER_PORTAL_USED", OnPortalUsed)
end

function RT.WatchPortalDrain()
  if state.portalFollow then
    RT.InitPortals()
    events:Listen("UNIT_AURA")
    RefreshDrain()
  elseif events then
    events:Unlisten("UNIT_AURA")
    drainExpires = nil
    StopDrainTick()
  end
end

RT.api:On("READY", RT.WatchPortalDrain)
