local _, ns = ...

local Panel = {}
ns.PrioritiesPanel = Panel

local OWNER = "EbonBuilds"

local TABS = {
  { id = "weights", key = "prio.tab.weights", module = "PrioritiesTabWeights" },
  { id = "automation", key = "prio.tab.automation", module = "PrioritiesTabAuto" },
  { id = "wishes", key = "prio.tab.wishes", module = "PrioritiesTabWishes" },
  { id = "delays", key = "prio.tab.delays", module = "PrioritiesTabDelays" },
}

local tx = ns.PrioritiesState.Text

local function stateOf()
  local shared = ns.PrioritiesState
  return shared and shared.State() or {}
end

local function validTab(id)
  for _, entry in ipairs(TABS) do
    if entry.id == id then return true end
  end
  return false
end

function Panel.Build(parent, width, height)
  local skins = EbonAPI.Skins
  local spacing = skins.value("kit.spacing")
  local pageWidth = math.max(1, width or 1)

  local tabs = EbonAPI.Kit.create(OWNER, "tabs", parent, {
    width = width,
    height = height,
    columns = 2,
    onSelect = function(_, id)
      local shared = ns.PrioritiesState
      if shared and stateOf().tab ~= id then shared.SetTab(id) end
    end,
  })

  local refreshers = {}
  local building = true
  local pages, pageSpecs = {}, {}

  for _, entry in ipairs(TABS) do
    pageSpecs[entry.id] = {
      text = function() return tx(entry.key) end,
      width = pageWidth,
    }
    pages[entry.id] = tabs:AddTab(entry.id, pageSpecs[entry.id])
  end

  local pageHeight = math.max(1, (height or 1) - tabs:StripHeight() - spacing)

  for _, entry in ipairs(TABS) do
    local page = pages[entry.id]
    if height then pageSpecs[entry.id].height = pageHeight end
    page:SetHeight(pageHeight)
    local module = ns[entry.module]
    if module and type(module.Build) == "function" then
      local element, refresh = module.Build(page, pageWidth, pageHeight)
      local fn = refresh
      if type(fn) ~= "function" then
        fn = function() if module.Refresh then module.Refresh(element) end end
      end
      refreshers[entry.id] = fn
    end
  end

  building = false

  local function open()
    local wanted = stateOf().tab
    if validTab(wanted) and tabs:Selected() ~= wanted then
      tabs:Select(wanted)
    end
  end

  local function refresh()
    open()
    for _, entry in ipairs(TABS) do
      local fn = refreshers[entry.id]
      if fn then fn() end
    end
    tabs:Refresh()
  end

  Panel.Refresh = refresh

  if ns.PrioritiesState then
    ns.PrioritiesState.Subscribe(function(key)
      if building then return end
      if key == "tab" then
        open()
      elseif key == "build" or key == "echo" or key == "data" then
        local fn = refreshers[stateOf().tab]
        if fn then fn() end
        tabs:Refresh()
      end
    end)
  end

  open()
  return tabs, refresh
end
