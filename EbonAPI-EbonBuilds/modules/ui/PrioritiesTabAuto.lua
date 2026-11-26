local _, ns = ...

local Tab = {}
ns.PrioritiesTabAuto = Tab

local WEIGHT_THRESHOLDS = {
  { key = "autoBanishPct", label = "prio.auto.banBelow", min = 0, max = 100, step = 1 },
  { key = "autoRerollPct", label = "prio.auto.rerollBelow", min = 0, max = 300, step = 1 },
  { key = "rerollGuardPct", label = "prio.auto.rerollGuard", min = 0, max = 100, step = 1 },
  { key = "autoFreezePct", label = "prio.auto.freezeAbove", min = 0, max = 100, step = 1 },
}
local MATRIX_THRESHOLDS = {
  { key = "matrixBanishBelow", label = "prio.auto.banBelow", absolute = true, min = -5, max = 0, step = 0.1 },
  { key = "matrixRerollBelow", label = "prio.auto.rerollBelow", absolute = true, min = -5, max = 3, step = 0.1 },
  { key = "matrixRerollGuard", label = "prio.auto.rerollGuard", absolute = true, min = -5, max = 3, step = 0.1 },
  { key = "matrixFreezeAbove", label = "prio.auto.freezeAbove", absolute = true, min = -5, max = 3, step = 0.1 },
  { key = "matrixWeightFactor", label = "prio.auto.weightFactor", absolute = true, min = 0, max = 3, step = 0.1 },
}
local FAMILIES = {
  { key = "Tank" },
  { key = "Healer" },
  { key = "Melee" },
  { key = "Ranged" },
  { key = "Caster" },
  { key = "Survivability" },
}
local SOURCES = {
  { value = "matrix", label = "prio.auto.source.matrix" },
  { value = "weights", label = "prio.auto.source.weights" },
}

local tx = ns.PrioritiesState.Text

local function controls()
  return ns.PrioritiesControls
end

local function state()
  local shared = ns.PrioritiesState
  return shared and shared.State() or {}
end

local function selectedId()
  return state().buildId
end

local function selectedBuild()
  return ns.PrioritiesState.Build()
end

local function settings()
  local id = selectedId()
  if id == nil then return {} end
  return controls().Settings(selectedBuild()) or {}
end

local function noBuild()
  return selectedBuild() == nil
end

local function source()
  return settings().scoreSource == "weights" and "weights" or "matrix"
end

local function banItems()
  local list = settings().echoBanList or {}
  local items = {}
  for spellId, name in pairs(list) do
    local label = type(name) == "string" and name or (GetSpellInfo(spellId) or tostring(spellId))
    items[#items + 1] = { spellId = spellId, text = label }
  end
  table.sort(items, function(a, b)
    if a.text ~= b.text then return a.text < b.text end
    return a.spellId < b.spellId
  end)
  return items
end

local function automationTarget()
  local build = selectedBuild()
  if build then return build end
  return ns.Build and ns.Build.GetActive and ns.Build.GetActive() or nil
end

local function AutomationAvailable()
  return automationTarget() ~= nil
end

local function AutomationOn()
  local build = automationTarget()
  return build and build.automationEnabled and true or false
end

local function SetAutomationOn(value)
  local build = automationTarget()
  if not build then return end
  local wanted = value and true or false
  if (build.automationEnabled and true or false) ~= wanted then
    local oldId = build.id
    local wasSelected = selectedId() == oldId
    controls().ToggleAutomation(build)
    local saved = ns.Build.Save(oldId, { automationEnabled = build.automationEnabled })
    if wasSelected and saved and saved.id ~= oldId then
      ns.PrioritiesState.SelectBuild(saved.id)
    end
  end
  ns.PrioritiesState.Changed()
end

local function SouvenirsOn()
  local build = automationTarget()
  if not build then return false end
  local data = controls().Settings(build) or {}
  return data.manageSouvenirs ~= false
end

local function SetSouvenirsOn(value)
  local build = automationTarget()
  if not build then return end
  ns.Build.EnsureSettings(build)
  build.settings.manageSouvenirs = value and true or false
  ns.Build.Save(build.id, { settings = build.settings })
  ns.PrioritiesState.Changed()
end

Tab.SouvenirsOn = SouvenirsOn
Tab.SetSouvenirsOn = SetSouvenirsOn
Tab.AutomationAvailable = AutomationAvailable
Tab.AutomationOn = AutomationOn
Tab.SetAutomationOn = SetAutomationOn

function Tab.Build(parent, width, height)
  if Tab.ui and Tab.ui.unsubscribe then Tab.ui.unsubscribe() end
  local root = parent:Add("bar", { layout = "VERTICAL", width = width })
  local ui = { root = root, shown = nil, width = width }
  Tab.ui = ui

  local function refreshAll()
    Tab.Refresh()
  end

  root:Add("text", {
    text = tx("prio.panel.nobuild"),
    width = width,
    hidden = function() return not noBuild() end,
  })

  local body = root:Add("bar", { layout = "VERTICAL", width = width, hidden = noBuild })
  ui.body = body
  local scroll = ns.Widgets.Scroll(body, { layout = "VERTICAL", width = width, height = height })
  ns.Widgets.ScrollSize(scroll, width, height)
  local inner = scroll.kitScroll.child:GetWidth()
  if not inner or inner <= 0 then inner = width end
  ui.width = inner
  local content = scroll._content

  content:Add("select", {
    text = tx("prio.auto.source"),
    width = inner,
    values = function()
      local list = {}
      for _, entry in ipairs(SOURCES) do list[#list + 1] = { value = entry.value, text = tx(entry.label) } end
      return list
    end,
    get = source,
    onChange = function(_, key)
      local build = selectedBuild()
      if build and key ~= source() then controls().ToggleScoreSource(build) end
      refreshAll()
    end,
  })

  content:Add("toggle", {
    text = string.format(tx("prio.pair"), tx("prio.auto.mode"), tx("prio.auto.mode.best")),
    width = inner,
    get = function() return (settings().echoBanAllMode or "highestScore") == "highestScore" end,
    onChange = function(_, value)
      local build = selectedBuild()
      local best = (settings().echoBanAllMode or "highestScore") == "highestScore"
      if build and best ~= (value and true or false) then controls().ToggleBanAllMode(build) end
      refreshAll()
    end,
  })

  content:Add("heading", { text = tx("prio.auto.families"), width = inner })
  for _, family in ipairs(FAMILIES) do
    content:Add("toggle", {
      text = ns.FamilyName(family.key),
      width = inner,
      get = function()
        local list = settings().banishFamilyWhitelist
        return list and list[family.key] and true or false
      end,
      onChange = function(_, value)
        local build = selectedBuild()
        if build then controls().SetFamilyProtected(family.key, value and true or false, build) end
      end,
    })
  end

  content:Add("heading", { text = tx("prio.auto.thresholds"), width = inner })
  ui.thresholds = content:Add("bar", { layout = "VERTICAL", width = inner })

  content:Add("heading", { text = tx("prio.auto.banned"), width = inner })
  ui.ban = content:Add("button", {
    text = tx("prio.auto.ban"),
    width = inner,
    disabled = function() return state().echoId == nil or noBuild() end,
    onClick = function()
      local echoId = state().echoId
      local build = selectedBuild()
      if echoId == nil or not build then return end
      local name = GetSpellInfo(echoId)
      controls().AddBan(echoId, name or tostring(echoId), build)
      ns.PrioritiesState.Changed()
    end,
  })
  ui.list = content:Add("list", {
    frame = "FLAT",
    width = inner,
    height = math.floor(height / 3),
    items = function()
      local items = {}
      for _, entry in ipairs(banItems()) do
        items[#items + 1] = {
          text = entry.text,
          value = entry.spellId,
          actions = {
            {
              text = tx("prio.remove"),
              onClick = function()
                local build = selectedBuild()
                if build then controls().RemoveBan(entry.spellId, build) end
                ns.PrioritiesState.Changed()
              end,
            },
          },
        }
      end
      return items
    end,
  })

  ui.unsubscribe = ns.PrioritiesState.Subscribe(function(changed)
    if changed == "echo" or changed == "build" or changed == "tab" or changed == "data" then Tab.Refresh() end
  end)

  Tab.Refresh()
  return root, Tab.Refresh
end

local function rebuildThresholds(ui)
  local kind = source()
  if ui.shown == kind then return end
  ui.shown = kind
  ui.thresholds:Clear()
  local list = kind == "weights" and WEIGHT_THRESHOLDS or MATRIX_THRESHOLDS
  for _, entry in ipairs(list) do
    ui.thresholds:Add("range", {
      text = tx(entry.label),
      width = ui.width,
      min = entry.min,
      max = entry.max,
      step = entry.step,
      get = function()
        local build = selectedBuild()
        if not build or not controls().Settings(build) then return entry.min end
        return controls().ThresholdValue(entry, build)
      end,
      onChange = function(_, value)
        local build = selectedBuild()
        if build then controls().SetThreshold(entry, value, build) end
      end,
    })
  end
end

function Tab.Refresh()
  local ui = Tab.ui
  if not ui then return end
  rebuildThresholds(ui)
  ui.root:Refresh()
end
