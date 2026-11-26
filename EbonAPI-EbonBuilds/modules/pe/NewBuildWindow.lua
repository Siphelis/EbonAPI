local WIDTH, HEIGHT = 360, 170
local BUTTON_HEIGHT = 22
local FIELD_WIDTH = 320
local NAME_LIMIT = 32
local RED = "|cffff5555"
local RESET = "|r"

local api
local window, root, input, edit, descBox, saveButton, deleteButton
local editing, pending
local message = ""
local messageLine

local function T(key, fallback)
    local L = EbonBuilds.L
    local value = L and L[key]
    if type(value) == "string" and value ~= key then
        return value
    end
    return fallback
end

local function setMessage(text)
    message = text or ""
    if messageLine then
        messageLine:Refresh()
    end
end

local function cancel()
    window:Close()
end

local function refreshRail()
    local Rail = EbonBuilds.Pe and EbonBuilds.Pe.Rail
    if Rail and Rail.Refresh then
        Rail.Refresh()
    end
end

local function submit()
    local name = strtrim(edit:GetText() or "")
    if name == "" then
        setMessage(RED .. T("NEWBUILD_EMPTY", "Enter a name for the build.") .. RESET)
        edit:SetFocus()
        return
    end
    local description = descBox.edit:GetText() or ""
    local Build = EbonBuilds.Build
    if editing then
        local saved = Build.Save(editing.id, { title = name, comments = description })
        if saved then
            editing = saved
        end
        refreshRail()
        window:Close()
        return
    end
    local build = Build.Create({
        title = name,
        comments = description,
        class = Build.PlayerClassToken(),
        spec = Build.PlayerTopTalentTab(),
        settings = Build.DefaultSettings(),
    })
    if build then
        Build.SetActive(build.id)
    end
    window:Close()
end

local function confirmDelete()
    if not editing then
        return
    end
    local target = editing
    local L = EbonBuilds.L
    api:Dialog({
        text = string.format(L.DELETE_BUILD_CONFIRM, target.title or L.UNTITLED),
        acceptKey = "DELETE",
        cancelKey = "CANCEL",
        onAccept = function()
            EbonBuilds.Build.Delete(target.id)
            refreshRail()
            if editing and editing.id == target.id then
                window:Close()
            end
        end,
    })
end

local function applyMode()
    local target = pending
    pending = nil
    editing = target
    edit:SetText(target and target.title or "")
    descBox.edit:SetText(target and target.comments or "")
    setMessage("")
    if target then
        deleteButton:Show()
    else
        deleteButton:Hide()
    end
    if window.Refresh then
        window:Refresh()
    end
    saveButton:Refresh()
    edit:SetFocus()
end

local function button(x, width, getter, onClick)
    local element = api:Create("button", root, { width = width, text = getter, onClick = onClick })
    element:SetWidth(width)
    element:SetHeight(BUTTON_HEIGHT)
    element:SetPoint("TOPLEFT", root, "TOPLEFT", x, -(HEIGHT - 40))
    return element
end

local function build()
    api = EbonBuilds.api
    window = api:Window("newbuild", {
        text = function()
            if editing then
                return T("EDIT_BUILD_TITLE", "Edit build")
            end
            return T("NEWBUILD_TITLE", "New build")
        end,
        width = WIDTH,
        height = HEIGHT,
    })
    window:SetFrameStrata("DIALOG")

    root = CreateFrame("Frame", nil, window)
    root:SetWidth(WIDTH)
    root:SetHeight(HEIGHT)
    root:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    root:SetFrameLevel(window:GetFrameLevel() + 5)

    local hint = api:Create("text", root, {
        width = FIELD_WIDTH,
        text = function()
            return T("NEWBUILD_HINT", "Name of the new build")
        end,
    })
    hint:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -38)

    input = api:Create("input", root, { width = FIELD_WIDTH })
    input:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -54)
    edit = input.edit
    edit:SetMaxLetters(NAME_LIMIT)
    edit:SetScript("OnEnterPressed", submit)
    edit:SetScript("OnEscapePressed", cancel)
    edit:HookScript("OnTextChanged", function()
        if message ~= "" then
            setMessage("")
        end
    end)

    descBox = EbonBuilds.Widgets.Field(root, { width = FIELD_WIDTH }, { placeholder = "FORM_DESCRIPTION_HINT" })
    descBox:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -82)

    messageLine = api:Create("text", root, {
        width = FIELD_WIDTH,
        text = function()
            return message
        end,
    })
    messageLine:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -110)

    saveButton = button(WIDTH - 20 - 86 - 10 - 86, 86, function()
        if editing then
            return T("SAVE_BUILD", "Save")
        end
        return T("NEWBUILD_CREATE", "Create")
    end, submit)
    deleteButton = button(20, 86, function()
        return T("DELETE_BUILD", "Delete")
    end, confirmDelete)
    deleteButton:Hide()
    button(WIDTH - 20 - 86, 86, function()
        return T("SHARE_CANCEL", "Cancel")
    end, cancel)

    window:HookScript("OnShow", function()
        applyMode()
    end)
    return window
end

EbonBuilds.Pe.NewBuildWindow = {
    Open = function(target)
        pending = target
        EbonBuilds.Pe.Registry.OpenFloat("newbuild")
        if window and window:IsShown() and pending then
            applyMode()
        end
    end,
}

EbonBuilds.Pe.Registry.RegisterFloat("newbuild", {
    build = build,
    hide = function()
        if window then
            window:Close()
        end
    end,
})
