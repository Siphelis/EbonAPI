local NS = SkillTreeAutoLoad

-- Minimap de l'arbre dense (D10), portee par l'element Kit « miniview » : le cadre, le fond, le glisser, le
-- rectangle de vue (SetViewport) et son recentrage (onPan) viennent du Kit ; STAL dessine l'arbre ENTIER en
-- miniature comme la maquette : un petit carre par noeud (couleur selon son etat), les liens (1 px, allumes si les
-- deux bouts sont appris) et les hubs de classe. Dessin groupe : des TEXTURES (jamais des frames) d'un seul canevas,
-- creees une seule fois par tranches (CHUNK par image) puis seulement recolorees quand l'etat d'un noeud change.
NS.Dense = NS.Dense or {}
local Minimap = {}
NS.Dense.Minimap = Minimap

local function Dense(name) return EbonAPI.Skins.value("tree.dense." .. name) end
local SOLID_KEY = "media.solid"

local CHUNK = 400                  -- noeuds/liens crees par image
local LEVEL_LINKS, LEVEL_NODES = "BACKGROUND", "ARTWORK"
local STATE_TOKEN = NS.Dense.STATE_TOKEN
local function StateKey(state) return Dense(STATE_TOKEN[state] or "stateUnknown") end
local LEVEL_HUBS = "OVERLAY"

-- Adaptateurs W5 vers la vraie forme de NS.Dense.Data : Bounds = {minX,minY,maxX,maxY} (et non x0..y1) ;

local function BoundsOf(b)
    if type(b) ~= "table" then return nil end
    local x0, y0 = b.minX or b.x0, b.minY or b.y0
    local x1, y1 = b.maxX or b.x1, b.maxY or b.y1
    if x0 and y0 and x1 and y1 then return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 } end
end

local function SolidTexture()
    return EbonAPI.Skins.value(SOLID_KEY)
end

local function NewTexture(frame, layer, token, solid)
    local tex = frame:CreateTexture(nil, layer)
    tex:SetTexture(solid)
    EbonAPI.Palette.paint(tex, "SetVertexColor", token)
    return tex
end

-- Projection carte -> minimap (y de la carte vers le haut) et inverse
local function Project(mini, x, y)
    return mini.originX + (x - mini.x0) * mini.scale, mini.originY + (mini.y1 - y) * mini.scale
end

local function Unproject(mini, px, py)
    return mini.x0 + (px - mini.originX) / mini.scale, mini.y1 - (py - mini.originY) / mini.scale
end

-- Projection (bornes de la carte -> pixels de la minimap).
local function BuildIndex(mini)
    local data = NS.Dense.Data
    local bounds = BoundsOf(data and data.Bounds)
    if not bounds then return false end

    local width, height = bounds.x1 - bounds.x0, bounds.y1 - bounds.y0
    if width <= 0 or height <= 0 then return false end

    mini.x0, mini.y1 = bounds.x0, bounds.y1
    mini.scale = math.min(mini.width / width, mini.height / height)
    mini.originX = (mini.width - width * mini.scale) / 2
    mini.originY = (mini.height - height * mini.scale) / 2
    return true
end

-- Cree les reperes de hubs (une seule fois) : points aux couleurs de classe, comme la maquette.
local function BuildHubs(mini)
    local solid = mini.solid
    local hubs = NS.Dense.Data.Hubs or {}
    mini.hubTex = {}
    for i = 1, #hubs do
        local px, py = Project(mini, hubs[i].x, hubs[i].y)
        local tex = NewTexture(mini.canvas, LEVEL_HUBS, Dense("hubKey"), solid)
        local c = hubs[i].color
        if hubs[i].token then
            pcall(EbonAPI.Palette.paint, tex, "SetVertexColor", hubs[i].token)
        elseif type(c) == "number" then
            tex:SetVertexColor(EbonAPI.Palette.unpackColor(c))   -- couleur de classe de la maquette
        elseif type(c) == "table" then
            tex:SetVertexColor(c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1)
        end
        tex:SetSize(Dense("hubPx"), Dense("hubPx"))
        tex:SetPoint("CENTER", mini.canvas, "TOPLEFT", px, -py)
        mini.hubTex[i] = tex
    end
end

-- Couleur de monnaie du noeud (meme source que le halo de survol : NS.PresetsData.currencyColor).
local function CurrencyPaint(n)
    local colors = NS.PresetsData and NS.PresetsData.currencyColor or {}
    local hex = colors[n.currency or "ash"]
    local r, g, b = tostring(hex or ""):match("^(%x%x)(%x%x)(%x%x)$")
    if not r then return false end
    n.tex:SetVertexColor(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
    return true
end

-- Recolore les noeuds et les liens dont l'etat a change depuis le dernier passage (rien si rien n'a change).
local function Paint(mini)
    local snap = mini.snapshot
    if not (mini.nodes and snap and snap.state) then return end
    local state = snap.state
    local nodes = mini.nodes
    for i = 1, mini.nodesDone do
        local n = nodes[i]
        local st = state[n.id] or "unknown"
        if st ~= n.st then
            n.st = st
            if not CurrencyPaint(n) then EbonAPI.Palette.paint(n.tex, "SetVertexColor", StateKey(st)) end
            n.tex:SetAlpha((st == "active" or st == "ready") and 1 or Dense("minimapIdleAlpha") or 1)
        end
    end
    local links = mini.links
    for i = 1, mini.linksDone do
        local l = links[i]
        local lit = state[l.a] == "active" and state[l.b] == "active"
        if lit ~= l.lit then
            l.lit = lit
            local key = lit and Dense("linkLitKey") or Dense("linkKey")
            for j = 1, #l.tex do EbonAPI.Palette.paint(l.tex[j], "SetVertexColor", key) end
        end
    end
end

local function NewLink(mini, link)
    local a, b = NS.Dense.Data.ById[link.a], NS.Dense.Data.ById[link.b]
    if not (a and b) then return nil end
    local ax, ay = Project(mini, a.x, a.y)
    local bx, by = Project(mini, b.x, b.y)
    local dx, dy = bx - ax, by - ay
    local entry = { a = link.a, b = link.b, tex = {} }
    local function Dot(x, y, w, h)
        local t = mini.canvas:CreateTexture(nil, LEVEL_LINKS)
        t:SetTexture(mini.solid)
        EbonAPI.Palette.paint(t, "SetVertexColor", Dense("linkKey"))
        t:SetSize(math.max(w, Dense("dotSize")), math.max(h, Dense("dotSize")))
        t:SetPoint("CENTER", mini.canvas, "TOPLEFT", x, -y)
        entry.tex[#entry.tex + 1] = t
    end
    local adx, ady = math.abs(dx), math.abs(dy)
    if adx < Dense("dotMin") or ady < Dense("dotMin") then
        Dot((ax + bx) / 2, (ay + by) / 2, adx, ady)               -- droit : un seul segment
    else
        local n = math.min(Dense("maxDots"), math.ceil(math.max(adx, ady) / Dense("dotStep")))   -- oblique : quelques points alignes
        for k = 0, n - 1 do
            local f = (k + EbonAPI.Common.get("stal.minimapMiddle")) / n
            Dot(ax + dx * f, ay + dy * f, Dense("dotSize"), Dense("dotSize"))
        end
    end
    return entry
end

-- Creation par tranches : un pilote unique, sans frame par noeud ; tout est peint a la fin de chaque tranche.
local function Step(mini)
    local data = NS.Dense.Data
    local list, links = data.Nodes or {}, data.Links or {}
    local budget = CHUNK
    while budget > 0 and mini.nodesDone < #list do
        local node = list[mini.nodesDone + 1]
        mini.nodesDone = mini.nodesDone + 1
        budget = budget - 1
        local tex = mini.canvas:CreateTexture(nil, LEVEL_NODES)
        tex:SetTexture(mini.solid)
        local px, py = Project(mini, node.x or 0, node.y or 0)
        tex:SetSize(Dense("nodePx"), Dense("nodePx"))
        tex:SetPoint("CENTER", mini.canvas, "TOPLEFT", px, -py)
        mini.nodes[mini.nodesDone] = { id = node.id, tex = tex, currency = node.currency or "ash" }
        EbonAPI.Palette.paint(tex, "SetVertexColor", StateKey("unknown"))
        mini.nodes[mini.nodesDone].st = "unknown"
    end
    while budget > 0 and mini.linksDone < #links do
        local entry = NewLink(mini, links[mini.linksDone + 1])
        mini.linksDone = mini.linksDone + 1
        budget = budget - 1
        mini.links[mini.linksDone] = entry or { a = 0, b = 0, tex = {} }
    end
    Paint(mini)
    if mini.nodesDone >= #list and mini.linksDone >= #links then
        mini.driver:SetScript("OnUpdate", nil)
        mini.driver:Hide()
    end
end

local function BuildArbre(mini)
    mini.nodes, mini.links, mini.nodesDone, mini.linksDone = {}, {}, 0, 0
    mini.driver = mini.driver or CreateFrame("Frame")
    mini.driver:Show()
    mini.driver:SetScript("OnUpdate", function() Step(mini) end)
end

local function EnsureBuilt(mini)
    if mini.built then return true end
    if not mini.canvas then return false end
    mini.width, mini.height = mini.element:GetWidth(), mini.element:GetHeight()
    if not (mini.width and mini.height and mini.width > 0 and mini.height > 0) then return false end
    if not BuildIndex(mini) then return false end
    BuildHubs(mini)
    BuildArbre(mini)
    mini.built = true
    return true
end

-- Cree la minimap : un element Kit « miniview » sous `parent`. Renvoie le controleur { element, Refresh, SetViewRect,
-- OnPan, Stats, PixelToMap } ; le placement se fait sur mini.element.
function Minimap.Create(parent)
    local mini = { recalcs = 0, solid = SolidTexture() }
    mini.tick = function() end   -- plus de recalcul (dense.lua:WrapMini garde le crochet)
    mini.Refresh = Minimap.Refresh
    mini.SetViewRect = Minimap.SetViewRect
    mini.OnPan = Minimap.OnPan
    mini.Stats = Minimap.Stats
    mini.PixelToMap = Minimap.PixelToMap

    mini.element = NS.api:Create("miniview", parent, {
        draw = function(canvas, element)
            mini.canvas, mini.element = canvas, element
            EnsureBuilt(mini)
        end,
        onPan = function(xn, yn)
            if not (mini.built and mini.panFn) then return end
            local x, y = mini:PixelToMap(xn * mini.width, yn * mini.height)
            pcall(mini.panFn, x, y)
        end,
    })
    mini.canvas = mini.element:Canvas()
    EnsureBuilt(mini)
    return mini
end

function Minimap.PixelToMap(mini, px, py)
    if not mini.built then return nil end
    return Unproject(mini, px, py)
end

function Minimap.OnPan(mini, fn)
    mini.panFn = fn
end

function Minimap.Refresh(mini, snapshot)
    mini.snapshot = snapshot
    if EnsureBuilt(mini) then Paint(mini) end   -- recolore seulement ce qui a change
end

-- Rectangle de vue (cx, cy, largeur, hauteur en unites de carte) -> SetViewport (fractions du cadre) de l'element
function Minimap.SetViewRect(mini, cx, cy, w, h)
    if not mini.built then return end
    local l, t = Project(mini, cx - w / 2, cy + h / 2)
    local r, b = Project(mini, cx + w / 2, cy - h / 2)
    mini.element:SetViewport(l / mini.width, t / mini.height, (r - l) / mini.width, (b - t) / mini.height)
end

function Minimap.Stats(mini)
    return { cells = mini.nodesDone or 0, links = mini.linksDone or 0, hubs = mini.hubTex and #mini.hubTex or 0, recalcs = mini.recalcs }
end
