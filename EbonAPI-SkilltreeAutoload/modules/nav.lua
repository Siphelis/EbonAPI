local NS = SkillTreeAutoLoad
local L = NS.L

local Nav = {}
NS.Nav = Nav

local function Dense(name) return EbonAPI.Skins.value("tree.dense." .. name) end

local function Hubs()
    local db = EbonAPI.Ebonhold.TalentDatabase()
    return db and db[0].classHubs
end

local activeClass

function Nav.ClassInView(cx, cy, halfW, halfH, project)
    local best, bestDist
    for classId, hub in pairs(Hubs() or {}) do
        local hx, hy = hub.x, hub.y
        if project then hx, hy = project(hx, hy) end
        if hx and hy then
            local dx, dy = hx - cx, hy - cy
            if math.abs(dx) <= halfW and math.abs(dy) <= halfH then
                local dist = dx * dx + dy * dy
                if not bestDist or dist < bestDist or (dist == bestDist and classId < best) then best, bestDist = classId, dist end
            end
        end
    end
    return best
end

function Nav.SetActiveClass(classId) activeClass = classId end

function Nav.ActiveClass() return activeClass end

local function HubColor(hub)
    local r, g, b = (hub and hub.color or ""):match("(%x%x)(%x%x)(%x%x)")
    if not r then return EbonAPI.Palette.unpackColor(Dense("navTipFallback")) end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local function ClassName(hub, classId)
    if not hub then return tostring(classId) end
    return (hub.token and L["CLASS_" .. hub.token]) or hub.name or tostring(classId)
end

-- The tree's centre is its cross of central nodes: the starting nodes with no class that are infinite (identified by their data, never by name).
local function CentralNodes()
    local db = EbonAPI.Ebonhold.TalentDatabase()
    if not db then return nil end

    local set, count = {}, 0
    for _, node in ipairs(db[0].nodes) do
        if node.isStart and node.infinite and not node.classId then
            set[node.id], count = true, count + 1
        end
    end
    return count > 0 and set or nil
end

local denseMap

function Nav.SetMap(map) denseMap = map end

function Nav.GoTo(x, y, glide)
    if denseMap then denseMap:CenterOn(x, y, glide and true or false) end
end

function Nav.Side()
    return (NS.Data.GetPanelSide() == "LEFT") and "LEFT" or "RIGHT"
end

-- The tooltip opens toward the tree, away from the window edge.
function Nav.TooltipAnchor()
    return (Nav.Side() == "RIGHT") and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
end

function Nav.GoToClass(classId)
    local hubs = Hubs()
    local hub = hubs and hubs[classId]
    if hub then Nav.GoTo(hub.x, hub.y, true) end
end

local preview, leftOrigin, leftAt

function Nav.Previewing() return preview ~= nil end

function Nav.PreviewClass(classId)
    if not denseMap then return end
    if not preview then
        NS.View.Pause()
        if leftOrigin and GetTime() - leftAt < EbonAPI.Common.get("stal.centerSeconds") then
            preview = leftOrigin
        else
            local cx, cy = denseMap:GetView()
            preview = { cx = cx, cy = cy }
        end
        leftOrigin = nil
    end
    Nav.GoToClass(classId)
end

function Nav.EndPreview()
    if not (preview and denseMap) then return end
    local origin = preview
    preview, leftOrigin, leftAt = nil, origin, GetTime()
    denseMap:CenterOn(origin.cx, origin.cy, true)
    NS.View.Resume()
    NS.UI.HoldOpen()
end

function Nav.CommitClass(classId)
    preview, leftOrigin = nil, nil
    NS.UI.CloseOpen()
    Nav.GoToClass(classId)
end

function Nav.GoToCenter()
    if not denseMap then return end
    NS.UI.CloseOpen()
    local x, y = Nav.StartCenter()
    if x then Nav.GoTo(x, y, true) end
end

function Nav.ClassTip(btn, hub, active)
    GameTooltip:SetOwner(btn, Nav.TooltipAnchor())
    GameTooltip:SetText(ClassName(hub, btn.classId), HubColor(hub))
    GameTooltip:Show()
    NS.Overlay.ClassHalo(btn, hub, active)
end

function Nav.CenterTip(btn)
    GameTooltip:SetOwner(btn, Nav.TooltipAnchor())
    GameTooltip:SetText(L.NAV_CENTER, EbonAPI.Palette.unpackColor(Dense("tipColor")))
    GameTooltip:Show()
end

-- Centre (x, y) de la boite englobante des noeuds centraux, en coordonnees de donnees, ou nil.
function Nav.StartCenter()
    local set = CentralNodes()
    if not set then return nil end

    local minX, minY, maxX, maxY
    for _, node in ipairs(EbonAPI.Ebonhold.TalentDatabase()[0].nodes) do
        if set[node.id] then
            minX, maxX = math.min(minX or node.x, node.x), math.max(maxX or node.x, node.x)
            minY, maxY = math.min(minY or node.y, node.y), math.max(maxY or node.y, node.y)
        end
    end
    return (minX + maxX) / 2, (minY + maxY) / 2
end
