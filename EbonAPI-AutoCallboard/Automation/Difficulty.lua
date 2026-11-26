local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local state = RT.state

local Log = RT.Log

RT.difficultyPollInterval = 0.5
RT.difficultyIdlePollInterval = 2

function RT.GetHardmodeService()
  return EbonAPI.Ebonhold.Service("HardmodeService")
end

function RT.GetCurrentDifficulty()
  local tier = EbonAPI.Ebonhold.CurrentHardmodeTier

  if RT.api then
    return Core.sanitizeDifficulty(RT.api:Guard("Difficulty.read", tier))
  end

  return Core.sanitizeDifficulty(tier())
end

function RT.GetEffectiveDifficulty()
  local effective = Core.sanitizeDifficulty(EbonAPI.Ebonhold.EffectiveHardmodeTier())

  if effective and effective ~= RT.GetCurrentDifficulty() then
    return effective
  end

  return nil
end

local function InDungeonOrRaid()
  if not IsInInstance then
    return false
  end

  local ok, inInstance, instanceType = pcall(IsInInstance)

  return (ok and inInstance and Core.instanceCategory(instanceType) ~= 0) and true or false
end

function RT.IsDifficultyChangeAllowedHere()
  if InDungeonOrRaid() then
    return false
  end

  local level = UnitLevel and tonumber(UnitLevel("player")) or 0
  if level <= 10 then
    return true
  end

  return (IsResting and IsResting()) and true or false
end

function RT.IsDifficultyUnlocked(tier)
  local service = RT.GetHardmodeService()

  if not tier or not service or type(service.IsTierUnlocked) ~= "function" then
    return true
  end

  local ok, unlocked = pcall(service.IsTierUnlocked, tier)

  return not ok or unlocked and true or false
end

function RT.CanApplyDifficulty(tier)
  if UnitAffectingCombat and UnitAffectingCombat("player") then
    return false
  end

  return RT.IsDifficultyChangeAllowedHere() and RT.IsDifficultyUnlocked(tier)
end

function RT.GetActiveSelectionDifficulty()
  if not state then
    return nil
  end

  local selection = Core.findSelection(RT.GetAccountProfile(), RT.GetActiveSelectionId())
  if not selection then
    return nil
  end

  return Core.sanitizeDifficulty(selection.difficulty)
end

function RT.ApplyListDifficulty(tier, source)
  tier = Core.sanitizeDifficulty(tier)

  local current = RT.GetCurrentDifficulty()

  if not tier or not current or current == tier then
    return
  end

  local service = RT.GetHardmodeService()
  if not service or type(service.SetDifficulty) ~= "function" then
    Core.report(Core.problem("DIFFICULTY.SERVICE_MISSING", { tier = Core.difficultyLabel(tier), source = tostring(source) }))
    Log("difficulty", "service unavailable source=", source)
    return nil, "service_missing"
  end

  if not RT.CanApplyDifficulty(tier) then
    Log("difficulty", "change not allowed here target=", Core.difficultyLabel(tier), " source=", source)
    return
  end

  if service.SetDifficulty(tier) == false then
    Core.report(Core.problem("DIFFICULTY.SET_REFUSED", { tier = Core.difficultyLabel(tier), source = tostring(source) }))
    Log("difficulty", "change refused by service target=", Core.difficultyLabel(tier), " source=", source)
    return nil, "set_refused"
  end

  Log("difficulty", "difficulty requested target=", Core.difficultyLabel(tier), " source=", source)
end

function RT.WatchDifficultyChange()
  local collectionsShown = RT.IsCollectionsShown()
  local watched = collectionsShown or RT.IsBoardWindowShown()
  local delay = watched and RT.difficultyPollInterval or RT.difficultyIdlePollInterval

  local current = RT.GetCurrentDifficulty()
  local effective = RT.GetEffectiveDifficulty()
  local difficultyChanged = current ~= RT.lastSeenDifficulty or effective ~= RT.lastSeenEffectiveDifficulty

  local canApplyChanged = false
  if collectionsShown then
    local canApply = RT.CanApplyDifficulty()
    if canApply ~= RT.lastCanApplyDifficulty then
      canApplyChanged = true
      RT.lastCanApplyDifficulty = canApply
    end
  end

  if not difficultyChanged and not canApplyChanged then
    return delay
  end

  if difficultyChanged then
    local previous = RT.lastSeenDifficulty
    RT.lastSeenDifficulty = current
    RT.lastSeenEffectiveDifficulty = effective

    if previous ~= nil and current ~= nil and previous ~= current then
      Log("difficulty", "change seen ", Core.difficultyLabel(previous), " -> ", Core.difficultyLabel(current))
    end

    RT.RefreshBoardGraft()
  end

  if collectionsShown then
    RT.RefreshCollections()
  end

  return delay
end

function RT.FormatDifficultyStatus()
  local current = RT.GetCurrentDifficulty()

  if not current then
    return ""
  end

  local text = string.format(L.DIFFICULTY_STATUS_SUFFIX, Core.difficultyLabel(current))
  local effective = RT.GetEffectiveDifficulty()
  local wanted = RT.GetActiveSelectionDifficulty()

  if effective then
    text = text .. string.format(L.DIFFICULTY_STATUS_INSTANCE_SUFFIX, Core.difficultyLabel(effective))
  end

  if wanted and wanted ~= current then
    text = text .. string.format(L.DIFFICULTY_STATUS_WANTED_SUFFIX, Core.difficultyLabel(wanted))
  end

  return text
end

function RT.RequestSetSelectionDifficulty(entry, tier)
  if not entry or entry.id == nil then
    return
  end

  local nextProfile, ok = Core.setSelectionDifficulty(RT.GetAccountProfile(), entry.id, tier)
  if not ok then
    Core.report(Core.problem("DIFFICULTY.SELECTION_REFUSED", {
      entryId = tostring(entry.id),
      tier = tier ~= nil and Core.difficultyLabel(tier) or "none",
    }))
    return
  end

  RT.SaveAccountProfile(nextProfile)
  RT.RefreshBoardGraft()
end

function RT.DifficultySliderValue(tier)
  tier = Core.sanitizeDifficulty(tier)

  if not tier then
    return Core.MIN_DIFFICULTY - 1
  end

  return tier
end

function RT.AddDifficultySlider(menu, tier, onCommit)
  local floor = Core.MIN_DIFFICULTY - 1

  menu:AddSlider({
    width = 150,
    min = floor,
    max = Core.maxDifficulty(),
    step = 1,
    value = RT.DifficultySliderValue(tier),
    title = L.LISTS_MENU_DIFFICULTY,
    format = function(value)
      return Core.difficultyLabel(value)
    end,
    onCommit = function(value)
      value = math.floor(value + 0.5)

      if value <= floor then
        onCommit(nil)
        return
      end

      onCommit(value)
      end,
  })
end
