local Core = AutoCallboardCore
local RT = AutoCallboardRuntime

local Log = RT.Log

local START_DELAY = 5
local KEY_PREFIX = "r"

local share = {}

RT.routeShare = share

function RT.GetRouteLibrary()
  local state = RT.state

  if type(state.routeLibrary) ~= "table" then
    state.routeLibrary = {}
  end

  if type(state.routeLibrary.entries) ~= "table" then
    state.routeLibrary.entries = {}
  end

  return state.routeLibrary
end

function RT.ServerDay()
  if CalendarGetDate then
    local ok, _, month, day, year = pcall(CalendarGetDate)
    local number = ok and Core.dayNumber(year, month, day)

    if number then
      return number
    end
  end

  local now = date and date("*t")

  return now and Core.dayNumber(now.year, now.month, now.day) or 0
end

local function RefreshLibrary()
  RT.RefreshRouteLibrary()
end

local function HeldRoutes(category)
  local held = {}

  for _, route in ipairs(RT.GetAccountProfile().savedRoutes or {}) do
    if Core.isRouteShared(route) and (category == nil or route.category == category) then
      held[Core.routeHash(route)] = route
    end
  end

  return held
end

function RT.RefreshHeldLibraryEntries()
  local library, today = RT.GetRouteLibrary(), RT.ServerDay()
  local changed = false

  for hash, route in pairs(HeldRoutes()) do
    if Core.mergeLibraryEntry(library, hash, Core.libraryEntryFromRoute(route, today), today) then
      changed = true
    end
  end

  if changed then
    RT.TouchState()
    RefreshLibrary()
  end

  return changed
end

local function KeyName(hash)
  return KEY_PREFIX .. (string.gsub((string.gsub(hash, "%(", "_0")), "%)", "_1"))
end

local function HashOfKey(name)
  if type(name) ~= "string" or string.sub(name, 1, #(KEY_PREFIX)) ~= KEY_PREFIX then
    return nil
  end

  local hash = string.gsub((string.gsub(string.sub(name, #(KEY_PREFIX) + 1), "_0", "(")), "_1", ")")

  hash = Core.sanitizeRouteHash(hash)

  return hash and KeyName(hash) == name and hash or nil
end

local function SplitText(text)
  if type(text) ~= "string" then
    return nil
  end

  local entryText, code = string.match(text, "^([^|]*)|(.*)$")

  if not entryText then
    return nil
  end

  return entryText, code
end

local function MergeShared(name)
  local hash = HashOfKey(name)
  local entryText = SplitText(RT.api:GetShared(name))

  if not hash or not entryText then
    return false
  end

  local parsed, entry = Core.parseLibraryEntry(entryText)

  if parsed ~= hash then
    return false
  end

  if Core.mergeLibraryEntry(RT.GetRouteLibrary(), hash, entry, RT.ServerDay()) then
    RT.TouchState()
    RefreshLibrary()

    return true
  end

  return false
end

local function OnReceived(_, addon, name)
  if addon == RT.api.addonName and HashOfKey(name) then
    MergeShared(name)
  end
end

function RT.MergeSharedRoutes()
  for _, name in ipairs(RT.api:SharedNames()) do
    MergeShared(name)
  end
end

function RT.IsRouteAvailable(hash)
  hash = Core.sanitizeRouteHash(hash)

  if not hash then
    return false
  end

  local _, code = SplitText(RT.api:GetShared(KeyName(hash)))

  return code ~= nil and code ~= ""
end

local function EntryName(hash)
  local entry = RT.GetRouteLibrary().entries[hash]

  return entry and entry.name or tostring(hash)
end

function RT.FetchLibraryRoute(hash)
  hash = Core.sanitizeRouteHash(hash)

  if not hash then
    return false
  end

  if Core.findRouteByHash(RT.GetAccountProfile(), hash, RT.GetRouteLibrary().entries[hash]) then
    RT.api:Report(RT.api:Problem("ROUTESHARE.ALREADY_OWNED", { route = EntryName(hash), hash = hash }))
    return false
  end

  local _, code = SplitText(RT.api:GetShared(KeyName(hash)))

  if not code or code == "" then
    RT.api:Report(RT.api:Problem("ROUTESHARE.NO_HOLDER", { route = EntryName(hash), hash = hash, tried = 0 }))
    return false
  end

  return RT.ImportLibraryRoute(code, hash) ~= nil
end

function RT.ImportLibraryRoute(code, hash)
  local route, cause = Core.decodeRoute(code)
  local profile = RT.GetAccountProfile()

  if not route then
    RT.api:Report(RT.api:Problem("ROUTESHARE.CODE_INVALID",
      { route = EntryName(hash), hash = hash, holder = "?", reason = "decode" }, cause))
  elseif Core.codeHash(code) ~= hash then
    RT.api:Report(RT.api:Problem("ROUTESHARE.CODE_INVALID",
      { route = EntryName(hash), hash = hash, holder = "?", reason = "hash" }))
  end

  if not route or Core.codeHash(code) ~= hash then
    return nil
  end

  if Core.findRouteByHash(profile, hash, { category = route.category, steps = #(route.steps) }) then
    RT.api:Report(RT.api:Problem("ROUTESHARE.ALREADY_OWNED", { route = route.name, hash = hash }))
    return nil
  end

  local nextProfile, entry, err = Core.createRoute(profile, route.steps, route.name, route.category,
    { difficulty = route.difficulty, shared = true, sharedHash = hash })

  if err == "full" then
    RT.api:Report(RT.api:Problem("RECORDER.ROUTES_FULL", { max = Core.MAX_SAVED_ROUTES, category = route.category }))
    return nil
  end

  if not entry then
    local reason = type(err) == "table" and err.code or err

    RT.api:Report(RT.api:Problem("ROUTESHARE.IMPORT_FAILED",
      { route = route.name, hash = hash, reason = tostring(reason) }))
    return nil
  end

  RT.SaveAccountProfile(nextProfile)

  local saved = Core.findRoute(nextProfile, entry.id)
  local today = RT.ServerDay()

  Core.mergeLibraryEntry(RT.GetRouteLibrary(), hash, Core.libraryEntryFromRoute(saved, today), today)
  RT.TouchState()
  Log("share", "imported ", hash, " from the library")

  RT.RefreshRouteWindow()

  RefreshLibrary()

  return saved
end

local function PublishRoute(route, hash, entry)
  local code = Core.encodeRoute(route)
  local serial = Core.serializeLibraryEntry(hash, entry)

  if not code or not serial then
    return false
  end

  local name, text = KeyName(hash), serial .. "|" .. code
  local held, state = RT.api:GetShared(name)

  if held == text then
    return true
  end

  state = tonumber(state)

  local day = entry.day

  if state and day <= state then
    day = state + 1
  end

  RT.api:Share(name, day, text)

  return true
end

function RT.SyncSharedRoutes()
  local profile = RT.GetAccountProfile()
  local library, today
  local nextProfile, announced = profile, false

  for _, route in ipairs(profile.savedRoutes or {}) do
    if Core.routeNeedsAnnounce(route) then
      library, today = library or RT.GetRouteLibrary(), today or RT.ServerDay()

      local hash = Core.routeHash(route)
      local entry = Core.libraryEntryFromRoute(route, today)

      if Core.mergeLibraryEntry(library, hash, entry, today) then
        RefreshLibrary()
      end

      if PublishRoute(route, hash, entry) then
        nextProfile = (Core.routeContainer.update(nextProfile, route.id, { sharedHash = hash }))
        announced = true
      end
    end
  end

  if announced then
    RT.SaveAccountProfile(nextProfile)
    RT.TouchState()
  end

  return announced
end

function RT.ShareRoute(id, shared)
  local before = Core.findRoute(RT.GetAccountProfile(), id)
  local nextProfile, ok = Core.setRouteShared(RT.GetAccountProfile(), id, shared)

  if not ok then
    return false
  end

  RT.SaveAccountProfile(nextProfile)

  if shared then
    RT.SyncSharedRoutes()
  elseif before then
    RT.api:Unshare(KeyName(Core.routeHash(before)))
  end

  RT.TouchState()
  RefreshLibrary()
  RT.RefreshRouteWindow()

  return true
end

local function PurgeLibrary()
  local held = {}

  for hash in pairs(HeldRoutes()) do
    held[hash] = true
  end

  if Core.purgeRouteLibrary(RT.GetRouteLibrary(), RT.ServerDay(), held) > 0 then
    RT.TouchState()
    RefreshLibrary()
  end
end

function RT.InitRouteShare()
  RT.api:On("SHARE_RECEIVED", OnReceived)

  RT.api:After("routeShareStart", START_DELAY, function()
    RT.RefreshHeldLibraryEntries()
    RT.MergeSharedRoutes()
    RT.SyncSharedRoutes()
    PurgeLibrary()
  end)
end
