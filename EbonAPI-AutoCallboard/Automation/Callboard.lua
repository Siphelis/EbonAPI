local Core = AutoCallboardCore
local RT = AutoCallboardRuntime
local state = RT.state

local BOARD_NAME = "Hero's Call Board"
local BOARD_CACHED_NAME = "Objectives Board"
local BOARD_OBJECT_IDS = { [600600] = true }
local BOARD_WINDOW = "EbonholdCallboardFrame"
local ACCEPT_WINDOW = 12

local pendingAcceptUntil


function RT.FrameIsVisibleOrShown(target)
  if not target then
    return false
  end

  if target.IsVisible and target:IsVisible() then
    return true
  end

  if not target.IsVisible and target.IsShown and target:IsShown() then
    return true
  end

  return false
end

function RT.GetBoardWindow()
  local window = rawget(_G, BOARD_WINDOW)
  return type(window) == "table" and window or nil
end

function RT.IsBoardWindowShown()
  return RT.FrameIsVisibleOrShown(RT.GetBoardWindow())
end

function RT.CleanBoardText(value)
  value = Core.stripColorCodes(value)
  value = value:gsub("^%s+", ""):gsub("%s+$", "")

  return value
end

function RT.IsBoardName(value)
  value = RT.CleanBoardText(value)

  if value == EbonAPI.Ebonhold.Text(BOARD_NAME) or value == BOARD_NAME or value == BOARD_CACHED_NAME then
    return true, value
  end

  return false, value
end

function RT.ExtractBoardObjectIdFromGuid(guid)
  if type(guid) ~= "string" then
    return nil
  end

  local hex = guid:gsub("^0x", "")
  if string.len(hex) < 10 then
    return nil
  end

  local prefix = string.sub(hex, 1, 4)
  if prefix ~= "F110" and prefix ~= "F130" then
    return nil
  end

  return tonumber(string.sub(hex, 5, 10), 16)
end

function RT.IsKnownBoardObjectId(objectId)
  return objectId and BOARD_OBJECT_IDS[tonumber(objectId)] == true
end

function RT.IsBoardNpcName(value)
  local isBoardName, cleanName = RT.IsBoardName(value)
  if isBoardName then
    return true, cleanName
  end

  if state and cleanName == state.targetName then
    return true, cleanName
  end

  return false, cleanName
end

function RT.IsGossipFrameOpen()
  return GossipFrame and GossipFrame.IsShown and GossipFrame:IsShown()
end

function RT.GetNpcBoardInfo()
  if not RT.IsGossipFrameOpen() then
    return nil
  end

  local name = UnitName and RT.CleanBoardText(UnitName("npc")) or ""
  local guid = UnitGUID and UnitGUID("npc") or nil
  local objectId = RT.ExtractBoardObjectIdFromGuid(guid)
  local nameMatches, cleanName = RT.IsBoardNpcName(name)
  local idMatches = RT.IsKnownBoardObjectId(objectId)

  if not nameMatches and not idMatches then
    return nil
  end

  return {
    name = cleanName,
    guid = guid,
    objectId = objectId,
    nameMatches = nameMatches,
    idMatches = idMatches,
  }
end

function RT.HasRemoteBoard()
  local toolbelt = EbonAPI.Ebonhold.Service("ToolbeltService")
  local toolbeltState = toolbelt and type(toolbelt.GetState) == "function" and toolbelt.GetState()

  return type(toolbeltState) == "table" and type(toolbeltState.owned) == "table"
      and toolbeltState.owned.callboard == true
end

local windowFromDialogue = false
local watchedWindow

local function NoteWindowFromDialogue(shown)
  windowFromDialogue = shown

  local window = shown and RT.GetBoardWindow()

  if window and window ~= watchedWindow and window.HookScript then
    watchedWindow = window
    window:HookScript("OnHide", function()
      windowFromDialogue = false
    end)
  end
end

function RT.GetBoardAccess()
  local shown = RT.IsBoardWindowShown()

  if RT.GetNpcBoardInfo() then
    NoteWindowFromDialogue(shown)
    return "near"
  end

  if not shown then
    windowFromDialogue = false
  elseif windowFromDialogue then
    return "near"
  end

  if RT.HasRemoteBoard() then
    return "remote"
  end

  return nil
end

function RT.ArmQuestAccept()
  pendingAcceptUntil = GetTime() + ACCEPT_WINDOW
end

function RT.GetPendingAcceptUntil()
  return pendingAcceptUntil
end

function RT.ClearPendingAcceptUntil()
  pendingAcceptUntil = nil
end

