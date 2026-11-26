local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local state = RT.state


RT.noneSelectionEntry = { id = nil, name = "", desiredQuests = {} }

local BuildSelectionContextMenu

local function AccountProfile()
  return RT.GetAccountProfile()
end

local function Refresh()
  RT.RefreshBoardGraft()
end

function RT.LoadSelectionPreset(entry)
  if not entry then
    return
  end

  RT.SetDesiredQuests(entry.desiredQuests)
  RT.SetActiveSelectionId(entry.id)

  RT.ApplyListDifficulty(entry.difficulty, "collection loaded " .. tostring(entry.name))
  RT.EvaluateBoard("list")
  Refresh()
end

function RT.IsSelectionActive(entry)
  return entry ~= nil and entry.id ~= nil and RT.GetActiveSelectionId() == entry.id
end

function RT.IsSelectionDifficultyLocked(entry)
  if not entry or entry.difficulty == nil then
    return false
  end

  if RT.IsSelectionActive(entry) then
    return false
  end

  local current = RT.GetCurrentDifficulty()

  if not current or current == entry.difficulty then
    return false
  end

  return not RT.CanApplyDifficulty(entry.difficulty)
end

function RT.CollectionState(entry)
  if not RT.IsSelectionActive(entry) then
    return nil
  end

  return Core.sameDesiredMap(state.desiredQuests, entry.desiredQuests) and "loaded" or "modified"
end

function RT.IsSelectionUnsaved()
  local profile = AccountProfile()
  local loaded = Core.findSelection(profile, RT.GetActiveSelectionId())

  if loaded then
    return not Core.sameDesiredMap(state.desiredQuests, loaded.desiredQuests), loaded
  end

  if Core.desiredQuestCount(state.desiredQuests) == 0 then
    return false, nil
  end

  for _, entry in ipairs(profile.savedSelections or {}) do
    if Core.sameDesiredMap(state.desiredQuests, entry.desiredQuests) then
      return false, nil
    end
  end

  return true, nil
end

local function ConfirmReplace(replace)
  local unsaved, loaded = RT.IsSelectionUnsaved()

  if not unsaved then
    replace()
    return
  end

  local body

  if loaded then
    body = string.format(L.COLLECTIONS_CONFIRM_MODIFIED, loaded.name)
  else
    body = string.format(L.COLLECTIONS_CONFIRM_UNSAVED, Core.desiredQuestCount(state.desiredQuests))
  end

  Skin.Dialog({
    title = L.COLLECTIONS_CONFIRM_TITLE,
    body = body,
    acceptText = L.COLLECTIONS_CONFIRM_REPLACE,
    cancelText = L.BUTTON_CANCEL,
    onAccept = replace,
  })
end

function RT.RequestLoadCollection(id)
  if id ~= nil then
    local entry = Core.findSelection(AccountProfile(), id)

    if not entry or RT.IsSelectionDifficultyLocked(entry) then
      return false
    end
  end

  ConfirmReplace(function()
    RT.LoadCollection(id)
  end)

  return true
end

function RT.RequestRenameSelection(entry)
  if not entry then
    Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "rename" }))
    return
  end

  Skin.Dialog({
    title = string.format(L.LISTS_RENAME_DIALOG_TITLE, entry.name),
    body = "",
    editBox = { default = entry.name, maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      local nextProfile, ok = Core.renameSelection(AccountProfile(), entry.id, text)
      if not ok then
        Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "rename" }))
        return
      end

      RT.SaveAccountProfile(nextProfile)
      Refresh()
      end,
  })
end

function RT.RequestOverwriteSelection(entry)
  if not entry then
    Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "overwrite" }))
    return
  end

  Skin.Dialog({
    title = entry.name,
    body = string.format(L.LISTS_OVERWRITE_CONFIRM_TEXT, entry.name),
    acceptText = L.BUTTON_OKAY,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      local nextProfile, ok = Core.updateSelectionContent(AccountProfile(), entry.id, state.desiredQuests)
      if not ok then
        Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "overwrite" }))
        return
      end

      RT.SaveAccountProfile(nextProfile)
      RT.SetActiveSelectionId(entry.id)
      Refresh()
      end,
  })
end

function RT.RequestDeleteSelection(entry)
  if not entry then
    Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "delete" }))
    return
  end

  Skin.Dialog({
    title = entry.name,
    body = string.format(L.LISTS_DELETE_CONFIRM_TEXT, entry.name),
    acceptText = L.BUTTON_DELETE,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      local nextProfile, ok = Core.deleteSelection(AccountProfile(), entry.id)
      if not ok then
        Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "delete" }))
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if RT.GetActiveSelectionId() == entry.id then
        RT.SetActiveSelectionId(nil)
      end

      Refresh()
      end,
  })
end

local function AskForNewSelection(groupId, titleKey, getDesired, activate)
  local profile = AccountProfile()

  if Core.selectionsFull(profile, groupId) then
    Core.report(Core.problem("LIST.CONTAINER_FULL", { limit = Core.MAX_SAVED_SELECTIONS }))
    return
  end

  Skin.Dialog({
    title = L[titleKey],
    body = "",
    editBox = { default = Core.peekNextSelectionName(profile), maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      local nextProfile, entry, err = Core.createSelection(AccountProfile(), getDesired(), text, groupId)

      if err == "full" then
        Core.report(Core.problem("LIST.CONTAINER_FULL", { limit = Core.MAX_SAVED_SELECTIONS }))
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if entry and activate then
        RT.SetActiveSelectionId(entry.id)
      end

      if entry then
        RT.ShowCollection(entry.id)
      end

      Refresh()
      end,
  })
end

function RT.RequestCreateSelection(groupId)
  AskForNewSelection(groupId, "LISTS_NEW_DIALOG_TITLE", function()
    return state.desiredQuests
    end, true)
end

function RT.RequestCreateSelectionWithQuest(key, groupId)
  if type(key) ~= "string" or key == "" then
    return
  end

  AskForNewSelection(groupId, "QUEST_MENU_NEW_TITLE", function()
    return { [key] = true }
    end, false)
end

function RT.RequestSetQuestInSelection(entry, key, wanted)
  if not entry or entry.id == nil or type(key) ~= "string" or key == "" then
    return false
  end

  local nextProfile, ok = Core.setQuestInSelection(AccountProfile(), entry.id, key, wanted)

  if not ok then
    Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "setquest" }))
    return false
  end

  RT.SaveAccountProfile(nextProfile)

  wanted = wanted and true or false

  if RT.GetActiveSelectionId() == entry.id
      and (state.desiredQuests[key] == true) ~= wanted then
    RT.ToggleDesiredQuest(key)
  end

  Refresh()

  return true
end

function RT.RequestSetQuestsInSelection(entry, keys, wanted)
  if not entry or entry.id == nil or type(keys) ~= "table" then
    return false
  end

  local profile, changed = AccountProfile(), false

  for i = 1, #(keys) do
    local ok

    profile, ok = Core.setQuestInSelection(profile, entry.id, keys[i], wanted)
    changed = changed or ok
  end

  if not changed then
    return false
  end

  RT.SaveAccountProfile(profile)

  if RT.GetActiveSelectionId() == entry.id then
    RT.SetWantedKeys(keys, wanted)
  end

  Refresh()

  return true
end

function RT.RequestCreateGroup()
  local profile = AccountProfile()

  if Core.groupsFull(profile) then
    Core.report(Core.problem("LIST.GROUPS_FULL", { limit = Core.MAX_GROUPS }))
    return
  end

  Skin.Dialog({
    title = L.LISTS_NEW_GROUP_TITLE,
    body = "",
    editBox = { default = Core.peekNextGroupName(profile), maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      local nextProfile, group, err = Core.createGroup(AccountProfile(), text)

      if err == "full" then
        Core.report(Core.problem("LIST.GROUPS_FULL", { limit = Core.MAX_GROUPS }))
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if group then
        RT.SetOpenGroupId(group.id)
      end

      Refresh()
      end,
  })
end

function RT.RequestRenameGroup(group)
  if not group then
    Core.report(Core.problem("LIST.GROUP_CHANGE_REFUSED", { group = group and group.name or "?", reason = "not_found", action = "rename" }))
    return
  end

  Skin.Dialog({
    title = string.format(L.LISTS_RENAME_GROUP_TITLE, group.name),
    body = "",
    editBox = { default = group.name, maxLetters = Core.MAX_SELECTION_NAME_LENGTH },
    acceptText = L.BUTTON_ACCEPT,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function(text)
      local nextProfile, ok = Core.renameGroup(AccountProfile(), group.id, text)
      if not ok then
        Core.report(Core.problem("LIST.GROUP_CHANGE_REFUSED", { group = group and group.name or "?", reason = "not_found", action = "rename" }))
        return
      end

      RT.SaveAccountProfile(nextProfile)
      Refresh()
      end,
  })
end

function RT.RequestDeleteGroup(group)
  if not group then
    Core.report(Core.problem("LIST.GROUP_CHANGE_REFUSED", { group = group and group.name or "?", reason = "not_found", action = "delete" }))
    return
  end

  local profile = AccountProfile()
  local count = Core.selectionCount(profile, group.id)
  local body

  if count == 0 then
    body = string.format(L.LISTS_DELETE_GROUP_EMPTY_BODY, group.name)
  else
    body = string.format(L.LISTS_DELETE_GROUP_BODY, group.name, RT.DescribeGroupContents(profile, group.id))
  end

  Skin.Dialog({
    title = L.LISTS_DELETE_GROUP_TITLE,
    body = body,
    acceptText = L.BUTTON_DELETE,
    cancelText = L.BUTTON_CANCEL,
    onAccept = function()
      local activeId = RT.GetActiveSelectionId()
      local activeSelection = Core.findSelection(AccountProfile(), activeId)
      local nextProfile, ok = Core.deleteGroup(AccountProfile(), group.id)

      if not ok then
        Core.report(Core.problem("LIST.GROUP_CHANGE_REFUSED", { group = group and group.name or "?", reason = "not_found", action = "delete" }))
        return
      end

      RT.SaveAccountProfile(nextProfile)

      if activeSelection and Core.sameContainer(activeSelection.groupId, group.id) then
        RT.SetActiveSelectionId(nil)
      end

      if RT.GetOpenGroupId() == group.id then
        RT.SetOpenGroupId(nil)
      end

      Refresh()
      end,
  })
end

function RT.RequestMoveSelection(entry, groupId)
  if not entry then
    Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "move" }))
    return
  end

  local nextProfile, ok, err = Core.setSelectionGroup(AccountProfile(), entry.id, groupId)

  if err == "full" then
    Core.report(Core.problem("LIST.CONTAINER_FULL", { limit = Core.MAX_SAVED_SELECTIONS }))
    return
  end

  if not ok then
    Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "move" }))
    return
  end

  RT.SaveAccountProfile(nextProfile)
  Refresh()
end

local function PlaceOf(entry)
  local entries = Core.selectionsInContainer(AccountProfile(), entry.groupId)

  for index, each in ipairs(entries) do
    if each.id == entry.id then
      return index, entries
    end
  end

  return nil, entries
end

function RT.RequestMoveSelectionBy(entry, step)
  local index, entries = PlaceOf(entry)
  local target = index and index + step

  if not target or target < 1 or target > #(entries) then
    return
  end

  local before = step < 0 and entries[target] or entries[target + 1]
  local nextProfile, ok = Core.moveSelectionTo(AccountProfile(), entry.id, entry.groupId, before and before.id or nil)

  if ok then
    RT.SaveAccountProfile(nextProfile)
    Refresh()
  end
end

function RT.RequestMoveSelectionTo(entry, groupId, beforeId)
  if not entry then
    Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "move" }))
    return false
  end

  local nextProfile, ok, err = Core.moveSelectionTo(AccountProfile(), entry.id, groupId, beforeId)

  if err == "full" then
    Core.report(Core.problem("LIST.CONTAINER_FULL", { limit = Core.MAX_SAVED_SELECTIONS }))
    return false
  end

  if not ok then
    Core.report(Core.problem("LIST.SELECTION_CHANGE_REFUSED", { list = entry and entry.name or "?", reason = "not_found", action = "move" }))
    return false
  end

  RT.SaveAccountProfile(nextProfile)
  Refresh()

  return true
end

function RT.RequestMoveGroupTo(group, index)
  local nextProfile, moved = Core.moveGroupToIndex(AccountProfile(), group.id, index)

  if moved then
    RT.SaveAccountProfile(nextProfile)
    Refresh()
  end

  return moved
end

function RT.RequestMoveGroupBy(group, step)
  local profile = AccountProfile()
  local index = Core.findGroupIndex(profile, group.id)
  local target = index and index + step

  if not target or target < 1 or target > Core.groupCount(profile) then
    return
  end

  RT.RequestMoveGroupTo(group, target)
end

local function BuildDifficultySubmenu(menu, entry)
  menu:Reset()
  menu:AddItem(entry.name, { header = true })
  menu:AddItem("< " .. L.LISTS_MENU_DIFFICULTY, {
    keepOpen = true,
    onClick = function()
      BuildSelectionContextMenu(menu, entry)
      end,
  })

  RT.AddDifficultySlider(menu, entry.difficulty, function(tier)
    RT.RequestSetSelectionDifficulty(entry, tier)
    end)

  menu:Layout()
end

local function BuildMoveSubmenu(menu, entry)
  local profile = AccountProfile()

  menu:Reset()
  menu:AddItem(entry.name, { header = true })
  menu:AddItem("< " .. L.LISTS_MENU_MOVE_TO, {
    keepOpen = true,
    onClick = function()
      BuildSelectionContextMenu(menu, entry)
      end,
  })

  menu:AddItem(L.LISTS_MOVE_TO_LIST, {
    checked = entry.groupId == nil,
    onClick = function()
      RT.RequestMoveSelection(entry, nil)
      end,
  })

  for i = 1, #(profile.groups) do
    local group = profile.groups[i]
    menu:AddItem(group.name, {
      checked = entry.groupId == group.id,
      onClick = function()
        RT.RequestMoveSelection(entry, group.id)
        end,
    })
  end

  menu:Layout()
end

BuildSelectionContextMenu = function(menu, entry)
  local index, entries = PlaceOf(entry)

  menu:Reset()
  menu:AddItem(entry.name, { header = true })

  if Core.groupCount(AccountProfile()) > 0 then
    menu:AddItem(L.LISTS_MENU_MOVE_TO, {
      arrow = true,
      keepOpen = true,
      onClick = function() BuildMoveSubmenu(menu, entry) end,
    })
  end

  menu:AddItem(L.LISTS_MENU_UP, {
    disabled = not index or index <= 1,
    onClick = function() RT.RequestMoveSelectionBy(entry, -1) end,
  })
  menu:AddItem(L.LISTS_MENU_DOWN, {
    disabled = not index or index >= #(entries),
    onClick = function() RT.RequestMoveSelectionBy(entry, 1) end,
  })
  menu:AddItem(L.LISTS_MENU_DIFFICULTY, {
    arrow = true,
    keepOpen = true,
    onClick = function() BuildDifficultySubmenu(menu, entry) end,
  })
  menu:AddItem(L.LISTS_MENU_UPDATE, {
    onClick = function() RT.RequestOverwriteSelection(entry) end,
  })
  menu:AddItem(L.LISTS_MENU_RENAME, {
    onClick = function() RT.RequestRenameSelection(entry) end,
  })
  menu:AddItem(L.LISTS_MENU_DELETE, {
    onClick = function() RT.RequestDeleteSelection(entry) end,
  })

  menu:Layout()
end

local function EnsureContextMenu()
  if not RT.listsContextMenu then
    RT.listsContextMenu = Skin.Menu("AutoCallboardListsContextMenu")
  end

  return RT.listsContextMenu
end

function RT.ShowSelectionContextMenu(row, entry)
  if not entry or entry.id == nil then
    return
  end

  local menu = EnsureContextMenu()
  BuildSelectionContextMenu(menu, entry)
  menu:OpenAt(row, "TOPLEFT", "TOPRIGHT", 4, 2)
end

function RT.ShowGroupContextMenu(anchor, group)
  if not group then
    return
  end

  local profile = AccountProfile()
  local index = Core.findGroupIndex(profile, group.id)
  local menu = EnsureContextMenu()

  menu:Reset()
  menu:AddItem(group.name, { header = true })
  menu:AddItem(L.COLLECTIONS_NEW_HERE, {
    disabled = Core.selectionsFull(profile, group.id),
    onClick = function() RT.RequestCreateSelection(group.id) end,
  })
  menu:AddItem(L.LISTS_MENU_UP, {
    disabled = not index or index <= 1,
    onClick = function() RT.RequestMoveGroupBy(group, -1) end,
  })
  menu:AddItem(L.LISTS_MENU_DOWN, {
    disabled = not index or index >= Core.groupCount(profile),
    onClick = function() RT.RequestMoveGroupBy(group, 1) end,
  })
  menu:AddItem(L.LISTS_MENU_RENAME, {
    onClick = function() RT.RequestRenameGroup(group) end,
  })
  menu:AddItem(L.LISTS_MENU_DELETE, {
    onClick = function() RT.RequestDeleteGroup(group) end,
  })
  menu:Layout()
  menu:OpenAt(anchor, "TOPLEFT", "BOTTOMLEFT", 0, -2)
end
