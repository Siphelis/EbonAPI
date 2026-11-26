local _, ns = ...

local Page = {}
ns.PrioritiesPage = Page

local OWNER = "EbonBuilds"
local FILTERS = { "all", "modified", "wanted", "banned" }
local SORTS = { "name", "weight" }

local states = setmetatable({}, { __mode = "k" })
local lastHost

local function make(kind, parent, spec)
  return EbonAPI.Kit.create(OWNER, kind, parent, spec)
end

local function resolve(host)
  if type(host) == "table" and states[host] then return states[host] end
  if lastHost then return states[lastHost] end
  return nil
end

local function refreshAll(st)
  for _, refresh in ipairs(st.refreshers) do refresh() end
  if EbonAPI.Kit.relayout then EbonAPI.Kit.relayout(st.host, true) end
end

local WATCHED = { build = true, echo = true, filter = true, sort = true, search = true, data = true }
local unsubscribe

function Page.Build(parent, available, visibleHeight)
  local state = ns.PrioritiesState
  local spacing = EbonAPI.Skins.value("kit.spacing")

  local root = make("bar", parent, { layout = "VERTICAL", width = available })
  local st = { host = root, refreshers = {} }
  states[root] = st
  lastHost = root

  local function add(element, refresh)
    if type(refresh) == "function" then st.refreshers[#st.refreshers + 1] = refresh end
    return element
  end

  local top = add(ns.PrioritiesBar.Build(root, available))
  local topHeight = top:GetHeight() or 0

  local room = (visibleHeight or math.floor(available * 0.6)) - topHeight - spacing
  room = math.max(room, topHeight * 4)

  local tileWidth = ns.PrioritiesGrid.Metrics()
  local widthBuilds = ns.PrioritiesBuilds.Width()
  local widthMiddle = 4 * tileWidth
  local widthPanel = available - widthBuilds - widthMiddle - 2 * spacing

  st.row = make("bar", root, { layout = "HORIZONTAL", width = available, height = room })

  add(ns.PrioritiesBuilds.Build(st.row, widthBuilds, room))

  local middle = make("bar", st.row, { layout = "VERTICAL", width = widthMiddle, height = room })
  local countElement = add(ns.PrioritiesCount.Build(middle, widthMiddle))
  local countHeight = countElement and countElement.GetHeight and countElement:GetHeight() or 0
  add(ns.PrioritiesGrid.Build(middle, widthMiddle, room - countHeight - spacing))

  add(ns.PrioritiesPanel.Build(st.row, widthPanel, room))

  if unsubscribe then unsubscribe() end
  unsubscribe = state.Subscribe(function(key)
    if WATCHED[key] and root:IsShown() then refreshAll(st) end
  end)

  middle:Layout()
  st.row:Layout()
  root:Layout()
  root:SetHeight(topHeight + spacing + room)
  return root
end

function Page.Refresh(host)
  local st = resolve(host)
  if st then refreshAll(st) end
end

function Page.Select(_host, spellId)
  local state = ns.PrioritiesState
  local current = state.State().echoId
  if spellId == nil then
    if current ~= nil then state.SelectEcho(current) end
    return
  end
  if current ~= spellId then state.SelectEcho(spellId) end
end

function Page.SetFilter(_host, value)
  ns.PrioritiesState.SetFilter(value)
end

function Page.SetSort(_host, value)
  if value ~= "name" and value ~= "weight" then return end
  ns.PrioritiesState.SetSort(value)
end

function Page.SetSearch(_host, text)
  ns.PrioritiesState.SetSearch(text or "")
end

function Page.SelectBuild(_host, id)
  if id == nil then return end
  local state = ns.PrioritiesState
  if state.State().buildId == id then return end
  state.SelectBuild(id)
end

function Page.Count(_host)
  local total, weighted, wanted, banned = ns.PrioritiesCount.Count(ns.PrioritiesState.State().buildId)
  return string.format(ns.L["prio.page.count"], total, weighted, wanted, banned)
end

function Page.Sorts()
  local out = {}
  for index, key in ipairs(SORTS) do out[index] = key end
  return out
end

function Page.Filters()
  local out = {}
  for index, key in ipairs(FILTERS) do out[index] = key end
  return out
end
