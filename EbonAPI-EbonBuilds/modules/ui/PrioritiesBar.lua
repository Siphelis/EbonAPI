local _, ns = ...

local Bar = {}
ns.PrioritiesBar = Bar

local OWNER = "EbonBuilds"
local FILTERS = { "all", "modified", "wanted", "banned" }
local SORTS = { "name", "weight" }

local tx = ns.PrioritiesState.Text

local function state()
  return ns.PrioritiesState.State()
end

local function options(keys, prefix)
  return function()
    local list = {}
    for _, key in ipairs(keys) do
      list[#list + 1] = { value = key, text = tx(prefix .. key) }
    end
    return list
  end
end

local MENU_SHARE = 0.31

function Bar.Build(parent, width)
  local row = EbonAPI.Kit.create(OWNER, "bar", parent, { width = width })

  local search = row:Add("input", {
    text = tx("prio.bar.search"),
    get = function() return state().search end,
    onChange = function(_, text) ns.PrioritiesState.SetSearch(text) end,
  })

  local show = row:Add("select", {
    text = tx("prio.bar.show"),
    values = options(FILTERS, "prio.bar.show."),
    get = function() return state().filter end,
    onChange = function(_, key) ns.PrioritiesState.SetFilter(key) end,
  })

  local sort = row:Add("select", {
    text = tx("prio.bar.sort"),
    values = options(SORTS, "prio.bar.sort."),
    get = function() return state().sort end,
    onChange = function(_, key) ns.PrioritiesState.SetSort(key) end,
  })

  local column = row:Add("bar", { layout = "VERTICAL" })

  local auto = column:Add("toggle", {
    text = tx("prio.bar.auto"),
    get = function() return ns.PrioritiesTabAuto.AutomationOn() end,
    disabled = function() return not ns.PrioritiesTabAuto.AutomationAvailable() end,
    onChange = function(_, value) ns.PrioritiesTabAuto.SetAutomationOn(value) end,
  })

  local souvenirs = column:Add("toggle", {
    text = tx("prio.auto.souvenirs"),
    get = function() return ns.PrioritiesTabAuto.SouvenirsOn() end,
    disabled = function() return not ns.PrioritiesTabAuto.AutomationAvailable() end,
    onChange = function(_, value) ns.PrioritiesTabAuto.SetSouvenirsOn(value) end,
  })

  auto:Refresh()
  souvenirs:Refresh()

  local columnWidth = math.max(auto:GetWidth(), souvenirs:GetWidth())

  local _, _, _, gap = show:GetPoint()
  gap = (gap or search:GetWidth()) - search:GetWidth()

  local usable = width - gap * 3 - columnWidth
  local wShow = math.floor(usable * MENU_SHARE)
  local wSort = wShow
  local wSearch = usable - wShow - wSort

  search.spec.width = wSearch
  show.spec.width = wShow
  sort.spec.width = wSort
  auto.spec.width = columnWidth
  souvenirs.spec.width = columnWidth

  local function refresh()
    search:Refresh()
    show:Refresh()
    sort:Refresh()
    auto:Refresh()
    souvenirs:Refresh()
    column:Layout()
    row:Layout()
  end

  refresh()

  return row, refresh
end
