EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.Rail = EbonBuilds.Pe.Rail or {}

local Rail = EbonBuilds.Pe.Rail

local SOLID = "Interface\\Buttons\\WHITE8X8"
local BASE_SIZE = 60
local MAX_SCALE = 0.9
local MIN_SCALE = 0.5
local ROW_GAP = 2
local ROWS_TOP = 4
local MARK_SIZE = 10
local GOLD = { 1, 0.82, 0, 1 }

local frame
local freeRow
local rows = {}
local listeners = {}
local subscribed = false

local function railWidth()
    local Shell = EbonBuilds.Pe.Shell
    return Shell and Shell.RailWidth and Shell.RailWidth() or 70
end

local function pilot()
    local api = EbonAPI and EbonAPI.JournalPilot
    if api and api.SetPreview and api.GetPreview then
        return api
    end
    return nil
end

local function liveBuilds()
    local live = {}
    local sorted = EbonAPI and EbonAPI.State and EbonAPI.State.sortedBuilds and EbonAPI.State.sortedBuilds() or {}
    for i = 1, #sorted do
        if sorted[i].kind == "live" then
            live[#live + 1] = sorted[i]
        end
    end
    return live
end

local function activeSlot()
    local _, slot = EbonAPI.State.activeBuild()
    return slot
end

local function previewSlot()
    local api = pilot()
    return api and tonumber(api.GetPreview()) or nil
end

local function buildName(build)
    local name = tostring(build.name or "")
    if name == "" then
        return string.format(EbonBuilds.L.SHARE_SLOT_NAME, tonumber(build.slot) or 0)
    end
    return name
end

local function classColor()
    local _, token = UnitClass("player")
    return token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] or nil
end

local function showTip(self)
    if not self.tipText then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tipText, 1, 1, 1)
    if self.hintText then
        GameTooltip:AddLine(self.hintText)
    end
    GameTooltip:Show()
end

local function hideTip()
    GameTooltip:Hide()
end

local function findBuild(slot)
    local builds = liveBuilds()
    for i = 1, #builds do
        if tonumber(builds[i].slot) == slot then
            return builds[i]
        end
    end
    return nil
end

local function slotName(slot)
    local build = findBuild(slot)
    if build then
        return buildName(build)
    end
    return string.format(EbonBuilds.L.SHARE_SLOT_NAME, slot)
end

local function notify()
    for i = 1, #listeners do
        listeners[i]()
    end
end

local function choose(slot)
    local api = pilot()
    if api then
        api.SetPreview(slot)
    end
    Rail.Refresh()
end

local function makeRow()
    local disc = EbonBuilds.api:Create("railDisc", frame, {
        classColor = classColor(),
        initials = "",
    })
    disc:HookScript("OnEnter", function() showTip(disc) end)
    disc:HookScript("OnLeave", hideTip)
    disc.mark = disc:CreateTexture(nil, "OVERLAY")
    disc.mark:SetTexture(SOLID)
    disc.mark:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], GOLD[4])
    disc.mark:SetWidth(MARK_SIZE)
    disc.mark:SetHeight(MARK_SIZE)
    disc.mark:SetPoint("TOPRIGHT", disc, "TOPRIGHT", 0, 0)
    disc.mark:Hide()
    return disc
end

local function place(disc, index, scale, pitch)
    disc:SetScale(scale)
    disc:ClearAllPoints()
    disc:SetPoint("TOP", frame, "TOP", 0, -(ROWS_TOP + (index - 1) * pitch) / scale)
end

local function paintRow(disc, selected, isActive)
    disc:SetState(selected and "active" or "idle")
    if isActive then
        disc.mark:Show()
    else
        disc.mark:Hide()
    end
end

local function layout(count)
    local room = frame:GetHeight() - ROWS_TOP
    local scale = (room / count - ROW_GAP) / BASE_SIZE
    scale = math.min(MAX_SCALE, math.max(MIN_SCALE, scale))
    return scale, BASE_SIZE * scale + ROW_GAP
end

function Rail.Refresh()
    if frame and freeRow then
        local builds = liveBuilds()
        local active = activeSlot()
        local preview = previewSlot()
        local scale, pitch = layout(#builds + 1)

        freeRow.spec.initials = EbonBuilds.L.RAIL_FREE_SHORT
        freeRow.tipText = EbonBuilds.L.RAIL_FREE
        place(freeRow, 1, scale, pitch)
        freeRow:SetState(preview == nil and "active" or "free")
        freeRow.mark:Hide()

        local shown = 0
        for i = 1, #builds do
            local build = builds[i]
            local slot = tonumber(build.slot)
            local row = rows[i]
            if not row then
                row = makeRow()
                row.spec.onClick = function(mouse)
                    if mouse == "RightButton" then
                        EbonBuilds.Pe.IconWindow.Open(row.slot, row.buildName)
                    else
                        choose(row.slot)
                    end
                end
                rows[i] = row
            end
            local name = buildName(build)
            row.slot = slot
            row.tipText = name
            row.hintText = EbonBuilds.L.RAIL_ICON_HINT
            row.buildName = name
            row.spec.icon = EbonBuilds.Pe.IconWindow.Get(slot, name)
            row.spec.initials = string.upper(string.sub(name, 1, 2))
            row.spec.classColor = classColor()
            place(row, i + 1, scale, pitch)
            paintRow(row, slot == preview, slot == active)
            row:Show()
            shown = i
        end
        for i = shown + 1, #rows do
            rows[i].slot = nil
            rows[i]:Hide()
        end
    end
    notify()
end

function Rail.OnChange(fn)
    listeners[#listeners + 1] = fn
end

function Rail.DisplayedName()
    local slot = previewSlot() or activeSlot()
    if not slot then return nil end
    return slotName(slot)
end

function Rail.CanActivate()
    local slot = previewSlot()
    return slot ~= nil and slot ~= activeSlot()
end

local function activate(slot)
    local perks = EbonAPI.Ebonhold and EbonAPI.Ebonhold.Service and EbonAPI.Ebonhold.Service("PerkService")
    if perks and type(perks.ActivateServerBuildSlot) == "function" then
        return perks.ActivateServerBuildSlot(slot)
    end
    return EbonBuilds.api:SendServer(EbonAPI.CS.REQUEST_PERK_LOADOUT_ACTIVATE, tostring(slot))
end

function Rail.Activate()
    if not Rail.CanActivate() then return end
    local slot = previewSlot()
    EbonBuilds.api:Dialog({
        text = string.format(EbonBuilds.L.RAIL_ACTIVATE_CONFIRM, slotName(slot)),
        acceptKey = "RAIL_ACTIVATE",
        cancelKey = "CANCEL",
        onAccept = function()
            activate(slot)
        end,
    })
end

function Rail.Create(parent)
    if frame then return frame end
    local width = railWidth()

    frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)

    local background = EbonBuilds.api:Create("bare", frame, {
        frame = "flat",
        border = EbonAPI.Bricks.value("widgets.bare.fill"),
    })
    background:SetAllPoints(frame)
    background:SetFrameLevel(frame:GetFrameLevel())

    frame:SetScript("OnSizeChanged", function()
        Rail.Refresh()
    end)

    freeRow = makeRow()
    freeRow.spec.onClick = function(mouse)
        if mouse ~= "RightButton" then
            choose(nil)
        end
    end

    if not subscribed then
        subscribed = true
        EbonBuilds.api:On("SERVER_BUILDS", Rail.Refresh)
        EbonBuilds.api:On("SERVER_BUILD_ACTIVE", Rail.Refresh)
    end

    Rail.Refresh()
    return frame
end
