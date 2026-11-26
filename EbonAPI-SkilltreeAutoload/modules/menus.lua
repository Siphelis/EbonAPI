local NS = SkillTreeAutoLoad
local L = NS.L
local COLOR = NS.COLOR
local Colorize = NS.Colorize

local Menus = {}
NS.Menus = Menus

local function CleanName(raw)
    if type(raw) ~= "string" then return nil end

    local name = EbonAPI.Lib.stripColor(raw)
    name = name:gsub("[%c|]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end

    return name
end

local function RejectName(raw)
    NS.api:Report(NS.api:Problem("SAVE.NAME_INVALID", { entered = tostring(raw), rule = L.RULE_NAME_EMPTY }))
end

local function CaptureFailed(err)
    NS.api:Report(NS.api:Problem("SAVE.CAPTURE_FAILED", { detail = tostring(err) }))
end

local function CountNodes(nodeRanks)
    local count = 0
    for _ in pairs(nodeRanks or {}) do count = count + 1 end
    return count
end

StaticPopupDialogs["STAL_INPUT_TEXT"] = {
    text = "%s",
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
        local data = self.data
        self.editBox:SetText((data and data.default) or "")
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local data = self.data
        if data and data.onAccept then data.onAccept(self.editBox:GetText()) end
        self:Hide()
    end,
    EditBoxOnEnterPressed = function(self)
        local dialog = self:GetParent()
        if dialog.data and dialog.data.onAccept then
            dialog.data.onAccept(self:GetText())
        end
        dialog:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["STAL_CONFIRM"] = {
    text = "%s",
    OnAccept = function(self)
        local data = self.data
        if data and data.onAccept then data.onAccept() end
        self:Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ResetLink(editBox)
    if editBox:GetText() ~= NS.Update.URL then editBox:SetText(NS.Update.URL) end
    editBox:HighlightText()
end

StaticPopupDialogs["STAL_UPDATE_LINK"] = {
    hasEditBox = true,
    hasWideEditBox = true,
    maxLetters = 0,
    OnShow = function(self)
        ResetLink(self.wideEditBox)
        self.wideEditBox:SetFocus()
    end,
    EditBoxOnTextChanged = ResetLink,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Menus.Localize()
    local input, confirm, link =
        StaticPopupDialogs["STAL_INPUT_TEXT"], StaticPopupDialogs["STAL_CONFIRM"], StaticPopupDialogs["STAL_UPDATE_LINK"]

    input.button1, input.button2 = L.POPUP_OK, L.POPUP_CANCEL
    confirm.button1, confirm.button2 = L.POPUP_YES, L.POPUP_NO
    link.text, link.button1 = L.POPUP_UPDATE, L.POPUP_OK
end

Menus.Localize()

function Menus.ShowUpdateLink()
    local version, installed = NS.Update.GetAvailable()
    if version then StaticPopup_Show("STAL_UPDATE_LINK", version, installed) end
end

function Menus.PromptText(prompt, default, onAccept)
    StaticPopup_Show("STAL_INPUT_TEXT", prompt, nil,
        { default = default, onAccept = onAccept })
end

function Menus.Confirm(text, onAccept)
    StaticPopup_Show("STAL_CONFIRM", text, nil, { onAccept = onAccept })
end

local SEPARATOR = { separator = true } -- attendu du Kit (api:OpenMenu) ; ligne de separation

local function Entry(text, onClick)
    return { text = text, onClick = onClick }
end

function Menus.NewSave()
    Menus.PromptText(L.PROMPT_NEW_SAVE, nil, function(raw)
        local name = CleanName(raw)
        if not name then
            RejectName(raw)
            return
        end

        local nodeRanks, err = NS.Core.CaptureTreeState()
        if not nodeRanks then
            CaptureFailed(err)
            return
        end

        NS.Data.CreateSave(name, nil, nodeRanks)
        NS.UI.RefreshList()
    end)
end

function Menus.NewGroup()
    Menus.PromptText(L.PROMPT_NEW_GROUP, nil, function(raw)
        local name = CleanName(raw)
        if not name then
            RejectName(raw)
            return
        end
        NS.Data.CreateGroup(name)
        NS.UI.RefreshList()
    end)
end

function Menus.ShowSaveMenu(saveId, anchor)
    if not NS.Data.GetSave(saveId) then return end

    local function moveTo(groupId)
        return function()
            if NS.Data.MoveSaveToGroup(saveId, groupId) then
                NS.UI.RefreshList()
            end
        end
    end

    local items = {
        Entry(L.MENU_RENAME, function()
            local save = NS.Data.GetSave(saveId)
            Menus.PromptText(L.PROMPT_RENAME, save and save.name, function(raw)
                local newName = CleanName(raw)
                if not newName then
                    RejectName(raw)
                    return
                end
                if NS.Data.RenameSave(saveId, newName) then NS.UI.RefreshList() end
            end)
        end),

        -- sous-menu : deuxieme OpenMenu ouvert au clic, a l'ancre recue par onClick(item, anchor)
        Entry(L.MENU_MOVE, function(_, menuAnchor)
            local groups = { Entry(L.UNGROUPED, moveTo(nil)) }
            for _, groupId in ipairs(NS.Data.GetSortedGroupIds()) do
                groups[#groups + 1] = Entry(NS.Data.GetGroup(groupId).name, moveTo(groupId))
            end
            NS.api:OpenMenu(groups, menuAnchor)
        end),

        Entry(L.MENU_UPDATE, function()
            local save = NS.Data.GetSave(saveId)
            if not save then return end

            local nodeRanks, err = NS.Core.CaptureTreeState()
            if not nodeRanks then
                CaptureFailed(err)
                return
            end

            local function apply()
                if NS.Data.UpdateSaveContent(saveId, nodeRanks) then
                    NS.UI.RefreshList()
                end
            end

            local newCount = CountNodes(nodeRanks)
            local oldCount = CountNodes(save.nodeRanks)
            if newCount < oldCount then
                NS.api:Notify(string.format(L.MSG_UPDATE_SHRINKS, newCount, oldCount))
                Menus.Confirm(string.format(L.CONFIRM_SHRINK_SAVE,
                    save.name, newCount, oldCount), apply)
            else
                apply()
            end
        end),

        Entry(Colorize(COLOR.ERROR, L.MENU_DELETE), function()
            local save = NS.Data.GetSave(saveId)
            Menus.Confirm(string.format(L.CONFIRM_DELETE_SAVE, save and save.name or saveId), function()
                if NS.Data.DeleteSave(saveId) then NS.UI.RefreshList() end
            end)
        end),

        SEPARATOR,
        Entry(L.MENU_EXPORT, function() NS.Share.ShowExportSave(saveId) end),
    }

    NS.api:OpenMenu(items, anchor)
end

function Menus.ShowGroupMenu(groupId, anchor)
    if not NS.Data.GetGroup(groupId) then return end

    local items = {
        Entry(L.MENU_RENAME_GROUP, function()
            local group = NS.Data.GetGroup(groupId)
            Menus.PromptText(L.PROMPT_RENAME_GROUP, group and group.name, function(raw)
                local newName = CleanName(raw)
                if not newName then
                    RejectName(raw)
                    return
                end
                if NS.Data.RenameGroup(groupId, newName) then NS.UI.RefreshList() end
            end)
        end),

        Entry(Colorize(COLOR.ERROR, L.MENU_DELETE_GROUP), function()
            local group = NS.Data.GetGroup(groupId)
            Menus.Confirm(string.format(L.CONFIRM_DELETE_GROUP,
                group and group.name or groupId, L.UNGROUPED), function()
                if NS.Data.DeleteGroup(groupId) then NS.UI.RefreshList() end
            end)
        end),
    }

    NS.api:OpenMenu(items, anchor)
end
