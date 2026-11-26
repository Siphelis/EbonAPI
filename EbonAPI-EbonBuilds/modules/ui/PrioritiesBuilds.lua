local _, ns = ...

local Builds = {}
ns.PrioritiesBuilds = Builds

local OWNER = "EbonBuilds"

local current
local seeded

local function make(kind, parent, spec)
  return EbonAPI.Kit.create(OWNER, kind, parent, spec)
end

function Builds.Width()
  local row = tonumber(EbonAPI.Skins.value("kit.row")) or 0
  local padding = tonumber(EbonAPI.Skins.value("kit.collection.padding")) or 0
  return row + 2 * padding
end

local function buildItems()
  local items = {}
  local selectedId = ns.PrioritiesState.State().buildId
  local chosen
  for _, build in ipairs(ns.Build.List()) do
    local id = build.id
    local item = {
      value = id,
      text = build.title or tostring(id),
      icon = EbonBuilds.Pe.IconWindow.DEFAULT_ICON,
      onClick = function() ns.PrioritiesState.SelectBuild(id) end,
    }
    items[#items + 1] = item
    if selectedId ~= nil and id == selectedId then chosen = item end
  end
  return items, chosen
end

local function seedActive()
  if seeded then return end
  seeded = true
  if ns.PrioritiesState.State().buildId ~= nil then return end
  local active = ns.Build.GetActive()
  if active then ns.PrioritiesState.SelectBuild(active.id) end
end

function Builds.Refresh()
  local list = current
  if not list then return end
  local items, chosen = buildItems()
  list:SetItems(items)
  list:Select(chosen)
end

local unsubscribe

function Builds.Build(parent, width, height)
  local list = make("list", parent, {
    items = {},
    width = width,
    height = height,
    frame = "SMALL",
    emptyKey = "WELCOME_TITLE",
    iconOnly = true,
  })
  current = list
  seedActive()
  Builds.Refresh()
  if unsubscribe then unsubscribe() end
  unsubscribe = ns.PrioritiesState.Subscribe(function(changedKey)
    if changedKey == "build" or changedKey == "select" or changedKey == "data" then
      Builds.Refresh()
    end
  end)
  return list, Builds.Refresh
end
