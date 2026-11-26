EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}

local PAD = 3

local view = {
    frame = nil,
    header = nil,
    title = nil,
    button = nil,
}

local function refreshHeader()
    local header = view.header
    if not header then return end
    local Rail = EbonBuilds.Pe.Rail
    local name = Rail and Rail.DisplayedName and Rail.DisplayedName() or nil
    view.title:SetContent(name or "", header:GetWidth() - EbonBuilds.Pe.Shell.HeaderButton() - PAD * 3, "medium")
    local can = Rail and Rail.CanActivate and Rail.CanActivate() or false
    if can then
        view.button:Show()
    else
        view.button:Hide()
    end
end

local function buildHeader(frame)
    local inset = rawget(_G, "ProjectEbonholdEchoJournalMyRunInset")
    if not inset then return end
    local api = EbonBuilds.api
    local header = CreateFrame("Frame", nil, frame)
    local Shell = EbonBuilds.Pe.Shell
    header:SetHeight(Shell.HeaderHeight())
    Shell.PlaceHeader(header)
    view.header = header

    view.title = api:Create("text", header, { width = 80, size = "medium", color = "heading" })
    view.title:SetPoint("LEFT", header, "LEFT", PAD, 0)

    view.button = EbonBuilds.Widgets.Kit("button", header, {
        glyph = "check", width = Shell.HeaderButton(), height = Shell.HeaderButton(),
        onClick = function() EbonBuilds.Pe.Rail.Activate() end,
    })
    view.button:SetPoint("RIGHT", header, "RIGHT", -PAD, 0)
    EbonBuilds.Widgets.Tip(view.button, function(add)
        add(EbonBuilds.L.RAIL_ACTIVATE, "text")
    end, "ANCHOR_TOP")

    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    EbonAPI.Bricks.paint(line, "SetVertexColor", "border")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

    local rule = header:CreateTexture(nil, "ARTWORK")
    rule:SetTexture("Interface\\Buttons\\WHITE8X8")
    EbonAPI.Bricks.paint(rule, "SetVertexColor", "border")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 0, Shell.RowGap())
    rule:SetPoint("BOTTOMRIGHT", inset, "TOPRIGHT", 0, Shell.RowGap())

    header:SetScript("OnShow", refreshHeader)
    EbonBuilds.Pe.Rail.OnChange(refreshHeader)
end

local function build(parent)
    if view.frame then return view.frame end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    view.frame = frame
    EbonBuilds.Pe.EchoesFilters.Create(frame)
    buildHeader(frame)
    return frame
end

local function refresh()
    if not view.frame then return end
    EbonBuilds.Pe.EchoesFilters.Refresh()
    refreshHeader()
end

EbonBuilds.Pe.Registry.RegisterScreen("echoes", {
    build = build,
    refresh = refresh,
})
