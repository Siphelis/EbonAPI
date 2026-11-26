EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.PlayersDetail = EbonBuilds.Pe.PlayersDetail or {}

local Detail = EbonBuilds.Pe.PlayersDetail

local format = string.format

local MARGIN = 10
local HEADER_BOTTOM = 56
local BAR_HEIGHT = 64
local BAND_HEIGHT = 40
local BAND_RESERVE = 64
local EXPORT_WIDTH = 90
local STAR_SIZE = 16
local STAR_GAP = 2

local panel, state
local classIcon, roleIcon, title, star, origin, titleStars
local barFrame, bodyFrame
local bandTitle, codeBox, exportButton, message
local cancelButton, saveButton
local view

local function T(key, fallback)
    local L = EbonBuilds.L
    return L and L[key] or fallback or key
end

local function Kit(kind, parent, spec)
    return EbonBuilds.Widgets.Kit(kind, parent, spec)
end

local function ClassName(token)
    local card = token and token ~= "" and EbonAPI.ClientData.Class(token)
    return card and card.name or token
end

local function RoleName(key)
    return EbonBuilds.FamilyName(key)
end

local function RoleIcon(key)
    for _, family in ipairs(EbonAPI.ClientData.Families()) do
        if family.key == key then return family.icon end
    end
end

local function Current()
    if state.view == "import" then return state.importEntry end
    return state.selection and state.selection.entry or nil
end

local function ReceivedDate(entry)
    local stamp = entry.lastModified or (type(entry.raw) == "table" and entry.raw.lastModified) or nil
    if type(stamp) ~= "string" then return nil end
    local year, month, day = stamp:match("^(%d+)-(%d+)-(%d+)")
    if not year then return nil end
    return format("%02d/%02d/%s", tonumber(day), tonumber(month), year)
end

local function OriginText(entry)
    if state.view == "import" or entry.kind == "imported" then
        return T("PLAYERS_IMPORTED_UNSAVED", "imported · not saved")
    end
    if entry.kind == "player" then
        return T("PLAYERS_MY_BUILD", "my build")
    end
    if entry.kind == "recovered" then
        local date = ReceivedDate(entry)
        if date then return format(T("PLAYERS_RECEIVED_ON", "received on %s"), date) end
    end
    return nil
end

local function ExportCode(entry)
    local source = EbonBuilds.PlayerBuilds.ExportSource(entry)
    return EbonBuilds.ExportImport.ExportEBH1(source)
end

local function ShowMessage(text)
    message.content = text
    message:Refresh()
    message:Show()
end

local function FillCode(entry, focus)
    message:Hide()
    local code, reason = ExportCode(entry)
    if type(code) == "string" and code ~= "" then
        codeBox:SetText(code)
        if focus then codeBox:SelectAll() end
        return
    end
    codeBox:SetText("")
    if reason == "EXPORT_EMPTY" then
        ShowMessage(T("SHARE_EXPORT_EMPTY", "This build has no Echo to export."))
    else
        ShowMessage(T("SHARE_EXPORT_FAILED", "This build could not be found."))
    end
end

local function Export()
    local entry = Current()
    if not entry then return end
    FillCode(entry, true)
end

local function Rate(entry)
    local Stars = EbonBuilds.Stars
    local PB = EbonBuilds.PlayerBuilds
    if not (Stars and titleStars and PB and PB.Stars) then return end
    Stars.Set(titleStars, PB.Stars(entry))
end

local function ShowEntry(entry)
    local roleKey = EbonBuilds.PlayerBuilds.Roles(entry)
    local className = ClassName(entry.class)
    if entry.class and entry.class ~= "" then
        EbonBuilds.Widgets.SetClassIcon(classIcon, entry.class)
        classIcon:Show()
    else
        classIcon:Hide()
    end
    local texture = roleKey and RoleIcon(roleKey)
    if texture then
        roleIcon:SetTexture(texture)
        roleIcon:Show()
    else
        roleIcon:Hide()
    end
    local roleName = roleKey and RoleName(roleKey) or ""
    title.content = format(T("PLAYERS_DETAIL_TITLE", "%s · %s"), className or "", roleName)
    title:Refresh()
    Rate(entry)
    if state.view ~= "import" and entry.kind == "favorite" then star:Show() else star:Hide() end
    local line = OriginText(entry)
    origin.content = line or ""
    origin:Refresh()
    if line then origin:Show() else origin:Hide() end
    if state.view == "import" then
        codeBox:SetText("")
    else
        FillCode(entry, false)
    end
end

function Detail.Anchors()
    if not panel then return nil end
    return { panel = bodyFrame, bar = barFrame }
end

function Detail.Build(parent, owner)
    view = owner or EbonBuilds.Pe.PlayersView
    state = view and view.state or {}
    local Stars = EbonBuilds.Stars

    panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)

    classIcon = panel:CreateTexture(nil, "ARTWORK")
    classIcon:SetWidth(24)
    classIcon:SetHeight(24)
    classIcon:SetPoint("TOPLEFT", panel, "TOPLEFT", MARGIN, -8)
    roleIcon = panel:CreateTexture(nil, "ARTWORK")
    roleIcon:SetWidth(16)
    roleIcon:SetHeight(16)
    roleIcon:SetPoint("LEFT", classIcon, "RIGHT", 6, 0)

    title = Kit("text", panel, { size = "medium", color = "heading", width = 260, text = function(self) return self.content or "" end })
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 62, -10)
    if Stars then
        titleStars = Stars.Create(panel, STAR_SIZE, STAR_GAP, "OVERLAY")
        Stars.Place(titleStars, "LEFT", title, "RIGHT", STAR_SIZE + STAR_GAP + 6, 0)
    end
    star = panel:CreateTexture(nil, "OVERLAY")
    star:SetWidth(18)
    star:SetHeight(18)
    star:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -MARGIN, -8)
    star:SetTexture(EbonAPI.Bricks.media("icons"))
    star:SetTexCoord(EbonAPI.Bricks.glyphCoords("starOn"))
    star:SetVertexColor(1, 0.82, 0, 1)

    origin = Kit("text", panel, { size = "small", color = "muted", width = 400, text = function(self) return self.content or "" end })
    origin:SetPoint("TOPLEFT", panel, "TOPLEFT", MARGIN, -34)

    barFrame = CreateFrame("Frame", nil, panel)
    barFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", MARGIN, -HEADER_BOTTOM)
    barFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -MARGIN, -HEADER_BOTTOM)
    barFrame:SetHeight(BAR_HEIGHT)
    bodyFrame = CreateFrame("Frame", nil, panel)
    bodyFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", MARGIN, -(HEADER_BOTTOM + BAR_HEIGHT))
    bodyFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -MARGIN, BAND_RESERVE)

    bandTitle = Kit("text", panel, { size = "small", color = "muted", width = 90, key = "PLAYERS_CODE_TITLE" })
    bandTitle:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", MARGIN, 14)
    exportButton = Kit("button", panel, { text = T("PLAYERS_EXPORT", "Export"), width = EXPORT_WIDTH, onClick = Export })
    exportButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -MARGIN, 8)
    codeBox = Kit("codeBox", panel, { readOnly = true, height = BAND_HEIGHT, copyHint = T("PLAYERS_COPY_HINT", "Ctrl+C to copy") })
    codeBox:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 104, 6)
    codeBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -(MARGIN + EXPORT_WIDTH + 8), 6)
    message = Kit("text", panel, { size = "small", color = "danger", text = function(self) return self.content or "" end })
    message:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 104, 50)
    message:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -MARGIN, 50)
    message:Hide()

    cancelButton = Kit("button", panel, { text = T("PLAYERS_CANCEL", "Cancel"), width = 110, onClick = function() view.Cancel() end })
    cancelButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -130, 8)
    saveButton = Kit("button", panel, { text = T("PLAYERS_SAVE", "Save"), width = 110, onClick = function() view.Save() end })
    saveButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -MARGIN, 8)
    cancelButton:Hide()
    saveButton:Hide()


    return panel
end

function Detail.Refresh(owner)
    if not panel then return end
    view = owner or view
    state = view.state
    message:Hide()
    local importing = state.view == "import"
    if importing then
        bandTitle:Hide() codeBox:Hide() exportButton:Hide()
        cancelButton:Show() saveButton:Show()
    else
        cancelButton:Hide() saveButton:Hide()
        bandTitle:Show() codeBox:Show() exportButton:Show()
    end
    local entry = Current()
    if not entry then
        panel:Hide()
        return
    end
    panel:Show()
    ShowEntry(entry)
end
