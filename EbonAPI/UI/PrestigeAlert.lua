-- PrestigeAlert: the yellow bubble of Project Ebonhold ("You have enough Soul Ashes to Prestige! ...",
-- global frame EbonholdPrestigeAlert, it points at the Prestige tab) can be turned off for good.
-- The setting lives in EbonAPIDB (account.prestigeAlert.hidden); the native frame is never modified:
-- EbonAPI hides it each time it shows, also when it is created later than this file.
EbonAPI = EbonAPI or {}
EbonAPI.PrestigeAlert = {}

local PrestigeAlert = EbonAPI.PrestigeAlert
local DB = EbonAPI.DB

local FRAME = "EbonholdPrestigeAlert"

local store = nil
local hookedFrame = nil

local function held()
  if not DB.isAttached() then
    return nil
  end

  if not store then
    store = DB.store("EbonAPI", { account = { prestigeAlert = { hidden = false } } })
  end

  return store.account.prestigeAlert
end

function PrestigeAlert.isHidden()
  local values = held()

  return values ~= nil and values.hidden == true
end

local function frame()
  local found = _G[FRAME]

  return type(found) == "table" and found.HookScript and found or nil
end

local function enforce()
  local alert = frame()

  if alert and PrestigeAlert.isHidden() and alert:IsShown() then
    alert:Hide()
  end
end

local function hook()
  local alert = frame()

  if not alert or hookedFrame == alert then
    return
  end

  hookedFrame = alert
  alert:HookScript("OnShow", enforce)
  -- A script the addon sets itself after the frame exists replaces the hook above: its Show is watched too.
  if type(hooksecurefunc) == "function" then
    hooksecurefunc(alert, "Show", enforce)
  end

  enforce()
end

function PrestigeAlert.setHidden(value)
  local values = held()

  if not values then
    return false
  end

  values.hidden = value and true or false
  hook()
  enforce()

  return true
end

-- The frame may be created after this file: look at every frame created until it is found.
if type(hooksecurefunc) == "function" then
  hooksecurefunc("CreateFrame", function(_, name)
    if name == FRAME and hookedFrame ~= frame() then
      hook()
    end
  end)
end

hook()
EbonAPI:On("READY", hook)
