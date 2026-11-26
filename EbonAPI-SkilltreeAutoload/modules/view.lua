local NS = SkillTreeAutoLoad

local View = {}
NS.View = View

local HOVER_DELAY = 0.3
local TRANSITION = 0.25
local ARROW_SIZE = 28
local ARROW_INSET = 6

local ARROW_TEXTURES = {
    LEFT = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
    RIGHT = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
    TOP = "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up",
    BOTTOM = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
}

local COUNT_ANCHORS = {
    LEFT = { "LEFT", "RIGHT", 2, 0 },
    RIGHT = { "RIGHT", "LEFT", -2, 0 },
    TOP = { "TOP", "BOTTOM", 0, -2 },
    BOTTOM = { "BOTTOM", "TOP", 0, 2 },
}

local zone, driver, flow

local origin, target, pending, anim
local kept
local hovering, flaggedKey, flaggedCount = false, nil, nil
local arrows = {}
local marked = false

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

function View.FitBox(boxW, boxH, availW, availH, margin)
    return math.min((availW - 2 * margin) / boxW, (availH - 2 * margin) / boxH)
end

local function HideArrows()
    for _, arrow in pairs(arrows) do arrow:Hide() end
end

local function GetArrow(side, parent)
    local arrow = arrows[side]
    if arrow then
        if arrow.owner ~= parent then arrow.owner = parent; arrow:SetParent(parent) end
        return arrow
    end

    arrow = CreateFrame("Frame", nil, parent)
    arrow.owner = parent
    arrow:SetSize(ARROW_SIZE, ARROW_SIZE)

    arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
    arrow.icon:SetAllPoints(arrow)
    arrow.icon:SetTexture(ARROW_TEXTURES[side])

    local anchor = COUNT_ANCHORS[side]
    arrow.count = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow.count:SetPoint(anchor[1], arrow, anchor[2], anchor[3], anchor[4])

    arrows[side] = arrow
    return arrow
end

local function ShowArrows(missing)
    HideArrows()
    local geo = flow and flow.geometry
    if not (missing and geo) then return end

    local parent = geo.frame()
    local left, top, right, bottom = geo.rect()

    local counts, sums = {}, {}
    for nodeId in pairs(missing) do
        local x, y = geo.point(nodeId)
        if x then
            local dx = (x < left) and (left - x) or ((x > right) and (x - right) or 0)
            local dy = (y < top) and (top - y) or ((y > bottom) and (y - bottom) or 0)

            if dx > 0 or dy > 0 then
                local side, along
                if dx >= dy then
                    side, along = (x < left) and "LEFT" or "RIGHT", y
                else
                    side, along = (y < top) and "TOP" or "BOTTOM", x
                end
                counts[side] = (counts[side] or 0) + 1
                sums[side] = (sums[side] or 0) + along
            end
        end
    end

    local level = parent:GetFrameLevel() + 7
    local edge = ARROW_INSET + ARROW_SIZE / 2

    for side, count in pairs(counts) do
        local along = sums[side] / count
        local x, y
        if side == "LEFT" or side == "RIGHT" then
            x = (side == "LEFT") and (left + edge) or (right - edge)
            y = Clamp(along, top + edge, bottom - edge)
        else
            x = Clamp(along, left + edge, right - edge)
            y = (side == "TOP") and (top + edge) or (bottom - edge)
        end

        local arrow = GetArrow(side, parent)
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
        arrow:SetFrameLevel(level)
        arrow.count:SetText(EbonAPI.Format.number(count))
        arrow:Show()
    end
end

local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP_RATIO = 0.10, 2.50, 1.12

local ladder, ladderCount

local floor, log = math.floor, math.log

local function BuildLadder()
    if ladder then return end

    local steps = math.ceil(log(ZOOM_MAX / ZOOM_MIN) / log(ZOOM_STEP_RATIO))
    local ratio = (ZOOM_MAX / ZOOM_MIN) ^ (1 / steps)

    ladder, ladderCount = {}, steps + 1
    for i = 1, ladderCount do
        ladder[i] = ZOOM_MIN * ratio ^ (i - 1)
    end

    ladder[1], ladder[ladderCount] = ZOOM_MIN, ZOOM_MAX
end

local function NearestIndex(zoom)
    local lo, hi = 1, ladderCount
    while lo < hi do
        local mid = floor((lo + hi) * 0.5)
        if ladder[mid] < zoom then lo = mid + 1 else hi = mid end
    end

    if lo > 1 and (zoom - ladder[lo - 1]) < (ladder[lo] - zoom) then return lo - 1 end
    return lo
end

function View.WheelZoom(from, notches)
    BuildLadder()

    local index = NearestIndex(from) + notches
    if index < 1 then
        index = 1
    elseif index > ladderCount then
        index = ladderCount
    end

    return ladder[index], index
end

function View.ZoomLimits()
    BuildLadder()
    return ladder[1], ladder[ladderCount], ladder[2] / ladder[1]
end

local function AbandonPreview()
    if not origin then return end

    origin, target, pending, anim = nil, nil, nil, nil
    HideArrows()
end

local function Smooth(t)
    return t * t * (3 - 2 * t)
end

local function ShowMarks()
    if not (target and target.missing) then return end

    local skipped = flow.mark(target.missing, target.affordable)

    skipped = skipped or 0
    if skipped > 0 then
        if flaggedKey ~= target.key or flaggedCount ~= skipped then
            flaggedKey, flaggedCount = target.key, skipped
            local save = NS.Data.GetSave(target.key)
            NS.api:Degrade(NS.api:Problem("SAVE.NODES_NOT_IN_TREE",
                { save = save and save.name or tostring(target.key), nodes = skipped }))
        end
    elseif flaggedKey == target.key then
        flaggedKey, flaggedCount = nil, nil
        NS.api:Restore("SAVE.NODES_NOT_IN_TREE")
    end
end

local function EraseMarks()
    NS.Dense.ClearPresetMarks()
    marked = false
end

local function HideMarks()
    if marked then EraseMarks() end
end

View.ClearMarks = EraseMarks

local function FinishRestore() flow.finish() end

local function OnUpdate()
    local now = GetTime()

    if pending and now >= pending.due then
        if hovering and flow and flow.visible() then
            target = pending
            flow.frame()
        end
        pending = nil
    end

    if flow and anim then flow.advance(now) end

    if flow and origin and not hovering and not (anim and anim.restore)
        and not (zone and zone()) then
        flow.restore()
    end

    if not (pending or anim or origin) then driver:Hide() end
end

function View.Init()
    driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", OnUpdate)
end

function View.Attach(isInZone)
    zone = isInZone
end

function View.Preview(key, missing, affordable)
    hovering = true
    HideArrows()

    if not (driver and flow and flow.visible() and missing and next(missing)) then
        pending = nil
        EraseMarks()
        return
    end

    local entry = { key = key, missing = missing, affordable = affordable }

    if not NS.Data.IsPreviewCamera() then
        target, pending = entry, nil
        ShowMarks()
        return
    end

    if origin and target and target.key == key then
        target, pending = entry, nil
        flow.frame()
    else
        HideMarks()
        entry.due = (pending and pending.key == key) and pending.due or (GetTime() + HOVER_DELAY)
        pending = entry
    end

    driver:Show()
end

function View.Pause()
    pending = nil
    kept = origin
end

function View.Resume()
    if kept and not origin then origin = kept end
    kept = nil
end

function View.Release()
    hovering = false
    HideArrows()
end

function View.Cancel()
    hovering, pending, anim = false, nil, nil
    kept = nil
    HideArrows()

    if origin and flow and flow.ready() then FinishRestore() end
    origin, target = nil, nil

    if driver then driver:Hide() end
end

function View.Abandon()
    AbandonPreview()
end

local function DenseAnimate(surface, zoom, cx, cy, restore)
    local fromZoom, fromX, fromY = surface.get()
    local zoomedOut = zoom < fromZoom
    if zoomedOut then surface.pan(fromX, fromY, cx, cy, zoom) end

    anim = {
        startedAt = GetTime(), restore = restore, zoomedOut = zoomedOut,
        fromX = fromX, fromY = fromY, toZoom = zoom, toX = cx, toY = cy,
    }

    HideArrows()
    HideMarks()
    driver:Show()
end

local function DenseFrame(surface)
    return function()
        if not origin then
            local zoom, cx, cy = surface.get()
            origin = { zoom = zoom, cx = cx, cy = cy }
        end

        local zoom, cx, cy = surface.plan(target.missing, target.affordable, origin.zoom)
        if not zoom then
            ShowMarks()
            return
        end

        local fromZoom, fromX, fromY = surface.get()
        if math.abs(zoom - fromZoom) < 0.001 and math.abs(cx - fromX) * zoom < 1 and math.abs(cy - fromY) * zoom < 1 then
            anim = nil
            ShowMarks()
            return
        end

        DenseAnimate(surface, zoom, cx, cy, false)
    end
end

local function DenseFlow(surface)
    local function advance(now)
        local progress = math.min(1, (now - anim.startedAt) / TRANSITION)
        local eased = Smooth(progress)

        local x, y = anim.fromX + (anim.toX - anim.fromX) * eased, anim.fromY + (anim.toY - anim.fromY) * eased

        if progress >= 1 and not anim.zoomedOut and not anim.restore then
            surface.place(anim.toZoom, x, y, hovering and target and target.missing and true or false)
        else
            surface.pan(x, y, anim.toX, anim.toY)
        end

        if progress >= 1 then
            local restore = anim.restore
            anim = nil
            if restore then
                FinishRestore()
            elseif hovering and target then
                ShowMarks()
            end
        end
    end

    local function finish()
        local o = origin
        origin, target = nil, nil
        if o then surface.place(o.zoom, o.cx, o.cy) end
    end

    return {
        visible = surface.visible, ready = surface.ready, frame = DenseFrame(surface), advance = advance,
        restore = function() DenseAnimate(surface, origin.zoom, origin.cx, origin.cy, true) end,
        finish = finish,
        mark = function(missing)
            marked = true
            ShowArrows(missing)
            NS.Dense.ShowPresetMarks(missing)
        end,
        geometry = surface.geometry,
    }
end

function View.UseSurface(surface)
    if origin and flow then
        anim, pending = nil, nil
        HideArrows()
        FinishRestore()
    end
    kept = nil
    origin, target, pending, anim = nil, nil, nil, nil
    flow = surface and DenseFlow(surface) or nil
end
