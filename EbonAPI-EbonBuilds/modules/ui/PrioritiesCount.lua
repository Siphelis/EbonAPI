local _, ns = ...

local Count = {}
ns.PrioritiesCount = Count

local tx = ns.PrioritiesState.Text

local function armedSet()
  local set = {}
  for _, row in ipairs(ns.Wishlist.Armed()) do
    set[row.key] = true
  end
  return set
end

Count.ArmedSet = armedSet

function Count.Count(buildId)
  local catalog = EbonAPI.EchoCatalog.NameList() or {}
  local total = #catalog
  local build = buildId ~= nil and ns.Build.Get(buildId) or nil
  if not build then return total, 0, 0, 0 end
  local weights = build.echoWeights or {}
  local bans = build.settings and build.settings.echoBanList or {}
  local armed = armedSet()
  local class = build.class or ns.Build.PlayerClassToken()
  local spec = build.spec or ns.Build.PlayerTopTalentTab()
  local weighted, wanted, banned = 0, 0, 0
  for _, entry in ipairs(catalog) do
    local value = weights[entry.name]
    if type(value) == "number" and value ~= ns.Weights.Default(entry, class, spec) then
      weighted = weighted + 1
    end
    if armed[ns.Matrix.Key(entry.spellId)] == true then wanted = wanted + 1 end
    if ns.PrioritiesControls.IsBanned(entry, bans) then banned = banned + 1 end
  end
  return total, weighted, wanted, banned
end

local function currentText()
  local state = ns.PrioritiesState.State()
  local total, weighted, wanted, banned = Count.Count(state.buildId)
  return string.format(tx("prio.page.count"), total, weighted, wanted, banned)
end

local current

function Count.Refresh()
  if current and current.Refresh then current:Refresh() end
end

function Count.Build(parent, width)
  local element = parent:Add("text", { text = currentText, width = width })
  current = element
  return element, Count.Refresh
end
