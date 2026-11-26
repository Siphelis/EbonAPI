EbonAPI = EbonAPI or {}
EbonAPI.MicroBar = {}

local MicroBar = EbonAPI.MicroBar
local Lib = EbonAPI.Lib
local Bus = EbonAPI.Bus

local tinsert = table.insert

-- Bartender4 rebuilds its micro menu from the game's button list and three fixed names, so the Toolbelt button
-- that ProjectEbonhold creates is dropped from the bar, and ProjectEbonhold anchors the others with a second
-- family of anchors. The bar is completed after each refresh and realigned once ProjectEbonhold has moved the
-- buttons. No file of Bartender4 and no table of the game is changed; only the bar's own button list is completed.

local BARTENDER = "Bartender4"
local MODULE = "MicroMenu"
local BUTTON = "ToolbeltMicroButton"
local ANCHOR_BUTTON = "MainMenuMicroButton"
local MOVE_HOOK = "VehicleMenuBar_MoveMicroButtons"
local REALIGN_ID = "EbonAPI.MicroBar.realign"
local REALIGN_DELAY = 0.8
local LEVEL_STEP = 1

local REALIGN_EVENTS = { "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS" }

local installed = false
local module = nil

local function noop() end

local function indexOf(list, frame)
  for index = 1, #list do
    if list[index] == frame then
      return index
    end
  end

  return nil
end

local function include()
  local bar = module.bar
  local button = rawget(_G, BUTTON)

  if not bar or not bar.buttons or not button then
    return
  end

  local buttons = bar.buttons

  if not indexOf(buttons, button) then
    local before = indexOf(buttons, rawget(_G, ANCHOR_BUTTON))

    tinsert(buttons, before or (#buttons + 1), button)
  end

  module.button_count = #buttons
  bar.numbuttons = #buttons

  local option = module.optionobject

  if option and option.table and option.table.general then
    option.table.general.args.rows.max = #buttons
  end

  if not InCombatLockdown() then
    button:SetParent(bar)
    button:SetFrameLevel(bar:GetFrameLevel() + LEVEL_STEP)
  end
end

local function realign()
  local bar = module.bar

  if not bar or not module:IsEnabled() then
    return
  end

  if not InCombatLockdown() then
    module:RestoreButtons()

    return
  end

  -- ProjectEbonhold swaps the bar's button list without its count: the list is rebuilt first. The bar frame is
  -- protected in combat: only the buttons are anchored, its size is left alone
  module:RefreshButtons()
  bar.SetSize = noop

  local ok, err = pcall(bar.UpdateButtonLayout, bar)

  bar.SetSize = nil

  if not ok then
    Lib.report(err)
  end
end

local function aligned()
  Lib.safeCall(realign)
end

local function refreshed()
  include()
end

function MicroBar.install()
  if installed or not IsAddOnLoaded(BARTENDER) then
    return
  end

  local bartender = rawget(_G, BARTENDER)

  module = bartender and bartender.GetModule and bartender:GetModule(MODULE, true)

  if not module then
    return
  end

  installed = true

  hooksecurefunc(module, "RefreshButtons", refreshed)

  local function later()
    Bus.after(REALIGN_ID, REALIGN_DELAY, aligned)
  end

  if type(rawget(_G, MOVE_HOOK)) == "function" then
    hooksecurefunc(MOVE_HOOK, later)
  end

  for _, event in ipairs(REALIGN_EVENTS) do
    Bus.onCore(event, later)
  end

  Bus.onCore("PLAYER_REGEN_ENABLED", aligned)

  if module.bar then
    include()
    aligned()
  end
end
