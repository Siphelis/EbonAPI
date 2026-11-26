local _, ns = ...

ns.PrioritiesGrid = ns.PrioritiesGrid or {}

local Grid = ns.PrioritiesGrid

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local type, tostring, tonumber = type, tostring, tonumber

local OWNER = "EbonBuilds"
local VISIBLE_TILES = 60
local SPARE = 2
local COLUMNS = 4

local tileW, tileH

local function tileSize()
  if not tileW then
    local probe = EbonAPI.Kit.create(OWNER, "echoTile", UIParent, {})

    probe:SetData({ name = "M" })
    tileW, tileH = probe:GetWidth(), probe:GetHeight()
    probe:Hide()
  end

  return tileW, tileH
end

function Grid.Metrics()
  return (tileSize())
end

local function signature(entry)
  return table.concat({
    tostring(entry.spellId), tostring(entry.label), tostring(entry.tile), tostring(entry.quality), tostring(entry.icon), tostring(entry.tip),
    entry.wanted and "1" or "0", entry.banned and "1" or "0", entry.modified and "1" or "0", tostring(entry.weight),
  }, "|")
end

function Grid.Create(parent, onSelect)
  local grid = CreateFrame("Frame", nil, parent)
  grid:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  grid:EnableMouse(true)
  grid:EnableMouseWheel(true)

  local pool = {}
  local bound = {}
  local items = {}
  local sigs = {}
  local entries = {}
  local selected
  local firstRow = 0
  local layoutWidth
  local viewHeight

  local info = { columns = 1, visibleRows = 1, firstIndex = 1, height = 0 }
  grid.info = info

  local function newTile(slot)
    local tile = EbonAPI.Kit.create(OWNER, "echoTile", grid, {
      point = { "TOPLEFT", grid, "TOPLEFT", 0, 0 },
      tipFill = function(lines, self)
        local item = items[self]
        local state = ns.PrioritiesState.State()
        local build = state.buildId ~= nil and ns.Build.Get(state.buildId) or nil

        if item then
          ns.Widgets.EchoTip(function(...) lines:Add(...) end, {
            entry = item.entry, build = build, weight = item.weight, modified = item.modified,
            default = item.default, wanted = item.wanted, banned = item.banned,
          })
        end
      end,
      onClick = function(self)
        local spellId = bound[self]

        if spellId and onSelect then
          onSelect(spellId)
        end
      end,
    })

    tile:Hide()
    pool[slot] = tile

    return tile
  end

  local function ensurePool(count)
    for slot = #pool + 1, count do
      newTile(slot)
    end
  end

  local function measure()
    return tileSize()
  end

  local function totalRows()
    return ceil(#entries / info.columns)
  end

  local function clampRow(row)
    local top = max(0, totalRows() - info.visibleRows)

    return min(max(floor(tonumber(row) or 0), 0), top)
  end

  local function bindTile(tile, entry)
    if not entry then
      if bound[tile] ~= nil or tile:IsShown() then
        bound[tile] = nil
        items[tile] = nil
        sigs[tile] = nil
        tile:Hide()
      end

      return
    end

    local sig = signature(entry) .. (entry.spellId == selected and "|s" or "|n")

    bound[tile] = entry.spellId
    items[tile] = entry

    if sigs[tile] ~= sig then
      sigs[tile] = sig

      tile:SetData({
        icon = entry.icon,
        name = entry.label,
        quality = entry.tile,
        tipTitle = entry.label,
        marked = entry.wanted == true,
        locked = entry.banned == true,
        stacks = entry.modified and type(entry.weight) == "number" and entry.weight or nil,
        selected = selected ~= nil and entry.spellId == selected,
        badge = EbonBuilds.Weights.SpecBadge(entry),
      })
      tile:SetState(entry.banned and "dim" or "normal")
    end

    if not tile:IsShown() then
      tile:Show()
    end
  end

  local function bind()
    local columns, rows = info.columns, info.visibleRows

    info.firstIndex = firstRow * columns + 1

    for slot = 1, #pool do
      local entry = nil

      if slot <= columns * rows then
        entry = entries[info.firstIndex + slot - 1]
      end

      bindTile(pool[slot], entry)
    end
  end

  local function place(width)
    local tw, th = measure()
    local columns = COLUMNS
    local rows = max(1, ceil(VISIBLE_TILES / columns))
    if viewHeight then rows = max(1, floor(viewHeight / th)) end

    info.columns, info.visibleRows = columns, rows
    info.height = rows * th

    ensurePool(columns * rows + SPARE)

    for slot = 1, #pool do
      local tile = pool[slot]

      if slot <= columns * rows then
        local index = slot - 1

        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", grid, "TOPLEFT", (index % columns) * tw, -floor(index / columns) * th)
      end
    end

    grid:SetWidth(columns * tw)
    grid:SetHeight(info.height)
    layoutWidth = width
    firstRow = clampRow(firstRow)
  end

  ensurePool(1)

  function grid:SetEntries(list)
    entries = type(list) == "table" and list or {}
    sigs = {}
    firstRow = clampRow(firstRow)
    bind()
  end

  function grid:SetSelected(spellId)
    if selected ~= spellId then
      selected = spellId
      bind()
    end
  end

  function grid:Refresh()
    bind()
  end

  function grid:Height(width, visibleHeight)
    width = tonumber(width)
    visibleHeight = tonumber(visibleHeight)

    if visibleHeight and visibleHeight ~= viewHeight then
      viewHeight = visibleHeight
      place(width or layoutWidth or 1)
      bind()
    elseif width and width ~= layoutWidth then
      place(width)
      bind()
    elseif not layoutWidth then
      place(1)
      bind()
    end

    return info.height
  end

  function grid:Scroll(offset)
    local row = clampRow(offset)

    if row ~= firstRow then
      firstRow = row
      bind()
    end
  end

  grid:SetScript("OnMouseWheel", function(_, delta)
    grid:Scroll(firstRow - delta)
  end)

  return grid
end

local iconCache = {}

local function iconOf(spellId)
  local icon = iconCache[spellId]

  if icon == nil then
    icon = select(3, GetSpellInfo(spellId))
    iconCache[spellId] = icon
  end

  return icon
end

local function labelOf(spellId, fallback)
  local name = GetSpellInfo(spellId)

  if type(name) == "string" and name ~= "" then return name end

  return fallback
end

local function tileQuality(quality)
  return math.min((tonumber(quality) or 0) + 1, 5)
end

local function collect()
  local state = ns.PrioritiesState.State()
  local build = state.buildId ~= nil and ns.Build.Get(state.buildId) or nil
  local catalog = EbonAPI.EchoCatalog.NameList() or {}
  local class = build and build.class or ns.Build.PlayerClassToken()
  local spec = build and build.spec or ns.Build.PlayerTopTalentTab()
  local bans = build and build.settings and build.settings.echoBanList or {}
  local armed = build and ns.PrioritiesCount.ArmedSet() or {}
  local needle = state.search ~= "" and state.search:lower() or nil
  local list = {}

  for _, entry in ipairs(catalog) do
    local name = entry.name or ""
    local default = ns.Weights.Default(entry, class, spec)
    local weight = build and ns.Weights.Get(name, build) or default
    local item = {
      spellId = entry.spellId, name = name, label = labelOf(entry.spellId, name), tile = tileQuality(entry.quality), quality = entry.quality, icon = iconOf(entry.spellId),
      families = entry.families, entry = entry, default = default,
      weight = weight, modified = build ~= nil and weight ~= default,
      wanted = build ~= nil and armed[ns.Matrix.Key(entry.spellId)] == true,
      banned = build ~= nil and ns.PrioritiesControls.IsBanned(entry, bans),
    }
    local keep = true

    if state.filter == "modified" then keep = item.modified
    elseif state.filter == "wanted" then keep = item.wanted
    elseif state.filter == "banned" then keep = item.banned end

    if keep and needle and not item.label:lower():find(needle, 1, true) then keep = false end

    if keep then list[#list + 1] = item end
  end

  if state.sort == "weight" then
    table.sort(list, function(a, b)
      if a.weight ~= b.weight then return a.weight > b.weight end
      return a.label < b.label
    end)
  else
    table.sort(list, function(a, b) return a.label < b.label end)
  end

  return list
end

local current
local currentWidth
local currentHeight

function Grid.Refresh()
  if not current then return end

  current:SetEntries(collect())
  current:SetSelected(ns.PrioritiesState.State().echoId)
  current:Height(currentWidth, currentHeight)
end

function Grid.Build(parent, width, height)
  local carrier = EbonAPI.Kit.create(OWNER, "bar", parent, { width = width, height = height, layout = "NONE" })
  local grid = Grid.Create(carrier, function(spellId) ns.PrioritiesState.SelectEcho(spellId) end)

  grid:SetSize(width, height)
  current, currentWidth, currentHeight = grid, width, height
  grid:Height(width, height)
  grid:SetScript("OnShow", function(self) self:Height(width, height) end)

  Grid.Refresh()

  return carrier, Grid.Refresh
end
