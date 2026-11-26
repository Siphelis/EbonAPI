EbonAPI = EbonAPI or {}
EbonAPI.JournalPilot = {}

local JournalPilot = EbonAPI.JournalPilot
local Problems = EbonAPI.Problems

local type, pcall, tonumber = type, pcall, tonumber

Problems.declare("EbonAPI", "EBONAPI", {
  ["JOURNAL.FILTER_ERROR"] = { class = "echec", key = "spellId" },
})

local preview = nil
local filter = nil
local previewWrapped = false
local filterWrapped = false
local originalDesign = nil
local originalGranted = nil
local originalLocked = nil
local originalAvailable = nil
local buildWrapped = false
local orbWrapped = false
local buildLine = nil
local slotsLine = nil
local previewBuild = nil
local designTraceWrapped = false
local CURRENT_LINE = "echo_journal%.lua:%d+: in "
local DEFINED_AT = "in function <[^>]-echo_journal%.lua:(%d+)>"

local function perkService()
  local root = ProjectEbonhold

  if type(root) ~= "table" or type(root.PerkService) ~= "table" then
    return nil
  end

  return root.PerkService
end

function JournalPilot.Available()
  local root = ProjectEbonhold

  if type(root) ~= "table" then
    return false
  end

  local service = perkService()

  if not service or type(service.GetServerActiveDesign) ~= "function" then
    return false
  end

  if type(root.IsPerkAvailableForClass) ~= "function" then
    return false
  end

  if type(root.EchoJournal) ~= "table" or type(root.EchoJournal.OnDataChanged) ~= "function" then
    return false
  end

  return true
end

local function callerIsJournal()
  if type(debugstack) ~= "function" then
    return false
  end

  local trace = debugstack(3, 1, 0)

  return type(trace) == "string" and string.find(trace, CURRENT_LINE) ~= nil
end

local function wrapDesign()
  if previewWrapped then
    return
  end

  local service = perkService()
  originalDesign = service.GetServerActiveDesign
  previewWrapped = true

  service.GetServerActiveDesign = function(...)
    if preview ~= nil then
      return preview
    end

    if previewBuild ~= nil and callerIsJournal() then
      return 0
    end

    return originalDesign(...)
  end
end

local function wrapAvailable()
  if filterWrapped then
    return
  end

  originalAvailable = ProjectEbonhold.IsPerkAvailableForClass
  filterWrapped = true

  ProjectEbonhold.IsPerkAvailableForClass = function(spellId, ...)
    if filter == nil then
      return originalAvailable(spellId, ...)
    end

    local ok, value = pcall(filter, spellId)

    if not ok then
      Problems.report(Problems.new("EbonAPI", "JOURNAL.FILTER_ERROR", { spellId = spellId }, value))

      return false
    end

    return value
  end
end

local function foreignPreview()
  if previewBuild ~= nil then
    return true
  end

  return preview ~= nil and preview ~= originalDesign()
end

local function ownedForReal(spellId)
  if type(originalGranted) == "function" then
    local granted = originalGranted()

    if type(granted) == "table" then
      for _, instances in pairs(granted) do
        for _, instance in ipairs(instances) do
          if instance.spellId == spellId and (instance.stack or 1) > 0 then
            return true
          end
        end
      end
    end
  end

  if type(originalLocked) == "function" then
    local locked = originalLocked()

    if type(locked) == "table" then
      for _, item in ipairs(locked) do
        if item.spellId == spellId then
          return true
        end
      end
    end
  end

  return false
end

local function blocksSpend(spellId)
  if spellId == nil or (preview == nil and previewBuild == nil) then
    return false
  end

  return not ownedForReal(spellId)
end

EbonAPI.Ebonhold.SetSpendBlocker(blocksSpend)

local function orbService()
  local root = ProjectEbonhold

  if type(root) ~= "table" or type(root.OrbService) ~= "table" then
    return nil
  end

  return root.OrbService
end

local function currentBuild()
  local service = perkService()

  if not service or type(service.GetServerBuildSlots) ~= "function" then
    return nil
  end

  local ok, slots = pcall(service.GetServerBuildSlots)

  if not ok or type(slots) ~= "table" then
    return nil
  end

  if previewBuild ~= nil then
    if type(previewBuild.echoes) ~= "table" then
      return nil
    end

    return previewBuild
  end

  local build = slots[preview]

  if type(build) ~= "table" or type(build.echoes) ~= "table" then
    return nil
  end

  return build
end

local function buildGranted(build)
  local granted = {}

  for _, echo in ipairs(build.echoes) do
    if type(echo) == "table" and echo.spellId ~= nil and not echo.avoid and not (previewBuild ~= nil and echo.locked) then
      local list = granted[echo.spellId] or {}
      list[#list + 1] = { spellId = echo.spellId, quality = echo.quality, stack = echo.stacks or 1 }
      granted[echo.spellId] = list
    end
  end

  return granted
end

local function fromLine(trace, wanted)
  if wanted == nil or type(trace) ~= "string" then
    return false
  end

  if not string.find(trace, CURRENT_LINE) then
    return false
  end

  for line in string.gmatch(trace, DEFINED_AT) do
    if tonumber(line) == wanted then
      return true
    end
  end

  return false
end

local function buildLocked(build)
  local locked = {}

  for _, echo in ipairs(build.echoes) do
    if type(echo) == "table" and echo.spellId ~= nil and echo.locked and not echo.avoid then
      locked[#locked + 1] = { spellId = echo.spellId, quality = echo.quality, stack = echo.stacks or 1 }
    end
  end

  return locked
end

local function fromBuildItems(trace)
  return fromLine(trace, buildLine)
end

local function fromSlotsRow(trace)
  return previewBuild ~= nil and fromLine(trace, slotsLine)
end

local function wrapPerkGetter(original, fromBuild)
  return function(...)
    if not foreignPreview() or type(debugstack) ~= "function" then
      return original(...)
    end

    local trace = debugstack(2, 1, 0)
    local items = fromBuildItems(trace)

    if not items and not fromSlotsRow(trace) then
      return original(...)
    end

    local built = fromBuild(items)

    if built == nil then
      return original(...)
    end

    return built
  end
end

local function wrapDiscovered(original)
  local function finish(learned, ...)
    if learned and (preview ~= nil or previewBuild ~= nil) and foreignPreview() then
      JournalPilot.Refresh()
    end

    return ...
  end

  return function(...)
    local learned = false

    if buildLine == nil and type(debugstack) == "function" then
      local trace = debugstack(2, 1, 0)

      if type(trace) == "string" then
        local line = string.match(trace, "echo_journal%.lua:%d+: in function <[^>]-echo_journal%.lua:(%d+)>")

        if line ~= nil then
          buildLine = tonumber(line)
          learned = true
        end
      end
    end

    return finish(learned, original(...))
  end
end

local function wrapSlotsLearner(original)
  return function(...)
    if slotsLine == nil and type(debugstack) == "function" then
      local trace = debugstack(2, 1, 0)

      if type(trace) == "string" then
        local line = string.match(trace, DEFINED_AT)

        if line ~= nil then
          slotsLine = tonumber(line)
        end
      end
    end

    return original(...)
  end
end

local function wrapBuild()
  if buildWrapped then
    return
  end

  local service = perkService()

  if not service then
    return
  end

  buildWrapped = true

  originalGranted = service.GetGrantedPerks
  originalLocked = service.GetLockedPerks

  if type(service.GetGrantedPerks) == "function" then
    service.GetGrantedPerks = wrapPerkGetter(service.GetGrantedPerks, function(items)
      if not items then
        return nil
      end

      local build = currentBuild()

      if build == nil then
        return nil
      end

      return buildGranted(build)
    end)
  end

  if type(service.GetLockedPerks) == "function" then
    service.GetLockedPerks = wrapPerkGetter(service.GetLockedPerks, function(items)
      local build = currentBuild()

      if build == nil then
        return nil
      end

      if previewBuild == nil then
        if items then
          return {}
        end

        return nil
      end

      return buildLocked(build)
    end)
  end

  if type(service.GetDiscoveredEchoes) == "function" then
    service.GetDiscoveredEchoes = wrapDiscovered(service.GetDiscoveredEchoes)
  end

  if type(service.GetMaximumPermanentEchoes) == "function" then
    service.GetMaximumPermanentEchoes = wrapSlotsLearner(service.GetMaximumPermanentEchoes)
  end

  if type(service.GetActiveEchoLoadout) == "function" then
    local loadout = service.GetActiveEchoLoadout

    service.GetActiveEchoLoadout = function(...)
      if previewBuild ~= nil and callerIsJournal() then
        return nil
      end

      return loadout(...)
    end
  end
end

local function wrapOrbMethod(orb, name)
  local original = orb[name]

  if type(original) ~= "function" then
    return
  end

  orb[name] = function(...)
    if blocksSpend((...)) then
      return nil
    end

    return original(...)
  end
end

local function wrapOrb()
  if orbWrapped then
    return
  end

  local orb = orbService()

  if not orb then
    return
  end

  orbWrapped = true

  wrapOrbMethod(orb, "SpendOn")
end

function JournalPilot.Refresh()
  local root = ProjectEbonhold

  if type(root) ~= "table" or type(root.EchoJournal) ~= "table" then
    return
  end

  if type(root.EchoJournal.OnDataChanged) == "function" then
    root.EchoJournal.OnDataChanged()
  end
end

function JournalPilot.SetPreview(slot)
  if not JournalPilot.Available() then
    return
  end

  wrapDesign()

  if slot ~= nil then
    wrapBuild()
    wrapOrb()
  end

  previewBuild = nil
  preview = slot
  JournalPilot.Refresh()
end

function JournalPilot.SetPreviewBuild(build)
  if not JournalPilot.Available() then
    return
  end

  wrapDesign()

  if build ~= nil then
    wrapBuild()
    wrapOrb()
  end

  preview = nil
  previewBuild = build
  JournalPilot.Refresh()
end

function JournalPilot.GetPreviewBuild()
  return previewBuild
end

function JournalPilot.GetPreview()
  return preview
end

function JournalPilot.SetFilter(fn)
  if not JournalPilot.Available() then
    return
  end

  wrapBuild()
  wrapAvailable()
  filter = fn
  JournalPilot.Refresh()
end
