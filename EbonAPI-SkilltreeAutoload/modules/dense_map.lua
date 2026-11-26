local NS = SkillTreeAutoLoad

-- STAL compact dense : la carte de l'arbre (W2).
-- Pools de boutons de noeuds et de textures de liens REUTILISES (jamais 1690), noeuds
-- choisis par la grille de NS.Dense.Data (aucune boucle sur tous les noeuds), zoom et
-- glisser sans AnimationGroup ni SetRotation. Les couleurs viennent de EbonAPI.Palette /
-- EbonAPI.Skins, les rappels passent par pcall.
--
-- HYPOTHESES sur NS.Dense.Data (formes non fixees au contrat, isolees dans les fonctions
-- d'acces LinkEnds, BoundsOf, LinksOf ; a corriger ICI si W1 en choisit d'autres) :
--   H1 un lien est {a=,b=} ou {from=,to=} ou {id1,id2} (ids de noeuds), ou un indice dans Data.Links ;
--   H2 Data.LinksIn(rect) prend UNE table {x0=,y0=,x1=,y1=} (aussi [1..4]) et rend une liste de liens ;
--   H3 Data.Bounds = {minX,minY,maxX,maxY} ou {x0,y0,x1,y1} ou {xmin,...} ou [1..4] ;
--   H4 Data.Grid:Query(x0,y0,x1,y1) en coordonnees de DONNEES (y vers le haut), rend une liste d'ids ;
--   H5 Data.ById[id] = {x=,y=,currency=} ; IconOf(id) rend un chemin de texture.
local Map = {}
NS.Dense = NS.Dense or {}
NS.Dense.Map = Map

-- Zoom, tailles, liens, couleurs : jetons tree.dense.* du skin (valeurs de PE, SK:2450-2453, pour les zooms) ; ordre, plafonds et seuils : EbonAPI.Common (stal.*).
-- Maquette : sous iconMinPx un noeud est un carre (plein = appris, contour = achetable, gris = verrouille) ;
-- l'icone du sort apparait des que le noeud mesure assez de pixels pour etre lisible : seuil sur la taille REELLE
-- (NODE_SIZE * zoom), pas sur un zoom : au zoom par defaut (0.6) un noeud fait 18 px, l'icone est donc visible.
-- Le seuil (jeton tree.dense.iconMinPx) est lu a l'usage, jamais a la charge : il suit le skin actif.
local Common = EbonAPI.Common
local function Dense(name) return EbonAPI.Skins.value("tree.dense." .. name) end
-- Mise en page (unites de donnees -> pixels : coordonnee * SPACING_SCALE * zoom)
-- Plafonds D8 (surplus non affiche, jamais cree au-dela)
-- Liens
-- Glisser, recentrage
-- Centre de chaque arbre de classe (PE skillTree_classes.lua:251-318) : aura (class_aura, couleur du theme, 0,45 pour
-- la classe du joueur, 0,16 sinon, rayon = noeud le plus loin x 1,25), icone ronde et anneau dore, a l'echelle du zoom.

-- Jetons de palette par etat (D12/D13)
-- Cles par etat : jetons tree.dense.state* (lus a l'usage ; "unknown" = adaptateur W5, dense_state.lua STATE_UNKNOWN)
local STATE_TOKEN = NS.Dense.STATE_TOKEN
local function StateKey(state) return Dense(STATE_TOKEN[state] or "stateUnknown") end
local DESATURATED = { locked = true, inconnu = true, unknown = true }

local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max
local pcall, type, tostring = pcall, type, tostring

-- Acces tolerants aux donnees (hypotheses H1-H3)
local function LinkEnds(link)
    if type(link) ~= "table" then return nil end
    return link.a or link.from or link[1], link.b or link.to or link[2]
end

local function BoundsOf(b)
    if type(b) ~= "table" then return nil end
    local x0 = b.minX or b.x0 or b.xmin or b[1]
    local y0 = b.minY or b.y0 or b.ymin or b[2]
    local x1 = b.maxX or b.x1 or b.xmax or b[3]
    local y1 = b.maxY or b.y1 or b.ymax or b[4]
    if x0 and y0 and x1 and y1 then return x0, y0, x1, y1 end
end

local function LinksOf(Data, x0, y0, x1, y1)
    local list = Data.LinksIn({ x0, y0, x1, y1, x0 = x0, y0 = y0, x1 = x1, y1 = y1 })
    if type(list) ~= "table" then return {} end
    return list
end

local function Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function Fail(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

local function Call(fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then Fail(err) end
end

local HexToRGB = NS.HexToRGB

local function Cursor(frame)
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    return x / scale, y / scale
end

local function Abandon()
    if NS.View and NS.View.Abandon then NS.View.Abandon() end
end

local Methods = {}
local Meta = { __index = Methods }

local function ViewSize(self)
    local w, h = self.view:GetWidth(), self.view:GetHeight()
    if not w or w < 10 then w = Common.get("stal.defaultWidth") end
    if not h or h < 10 then h = Common.get("stal.defaultHeight") end
    return w, h
end

local function ClampCenter(cx, cy)
    local x0, y0, x1, y1 = BoundsOf(NS.Dense.Data and NS.Dense.Data.Bounds)
    if not x0 then return cx, cy end
    return Clamp(cx, x0, x1), Clamp(cy, y0, y1)
end

local function Texture(owner, key, layer)
    local t = owner[key]
    if not t then
        t = owner:CreateTexture(nil, layer)
        t:SetTexture(Dense("linkTexStraight"))
        owner[key] = t
    end
    return t
end

local function PaintKey(tex, key)
    if tex.paintKey ~= key then
        tex.paintKey = key
        EbonAPI.Palette.paint(tex, "SetVertexColor", key)
    end
end

-- Police et ombre du skin actif : Bricks.font(fs, "small") (jeton fonts.small.*).
-- Jeton absent (nil) : repli sur la police du jeu, jamais de FontString sans police.
local function ApplyFont(fs)
    if not pcall(EbonAPI.Bricks.font, fs, "small") or not fs:GetFont() then
        fs:SetFont(STANDARD_TEXT_FONT, 10, "")
    end
end

-- Bouton de noeud (cree une fois, jamais plus de MAX_BUTTONS)
local function NewButton(self)
    local btn = CreateFrame("Button", nil, self.content)
    btn:RegisterForClicks("AnyUp")
    btn.border = btn:CreateTexture(nil, "BORDER")
    btn.border:SetTexture(Dense("linkTexStraight"))
    btn.border:SetAllPoints(btn)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", Dense("borderPx"), -Dense("borderPx"))
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -Dense("borderPx"), Dense("borderPx"))
    btn.rank = btn:CreateFontString(nil, "OVERLAY")
    btn.rank:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", Common.get("stal.rankOffsetX"), Common.get("stal.rankOffsetY"))   -- PE : skillTree.lua:2972 (valeurs par defaut des jetons)
    ApplyFont(btn.rank)
    EbonAPI.Palette.paint(btn.rank, "SetTextColor", Dense("rankKey"))
    btn:SetScript("OnEnter", function(b)
        self.hoverId = b.id
        NS.Overlay.NodeHalo(b, b.currency)   -- pièce de halo unique (overlay.lua), même qu'en vue standard
        Call(self.hoverFn, b.id, b)
    end)
    btn:SetScript("OnLeave", function(b)
        if self.hoverId == b.id then self.hoverId = nil end
        if b.halo then b.halo:Hide() end
        Call(self.hoverFn, nil)
    end)
    btn:SetScript("OnClick", function(b, button)
        if self.moved then return end
        Call(self.clickFn, b.id, button)
    end)
    btn:SetScript("OnMouseDown", function(_, button) self:BeginDrag(button) end)
    btn:SetScript("OnMouseUp", function(_, button) self:EndDrag(button) end)
    return btn
end

-- Fond du noeud : icone (zoom proche) ou carre uni (zoom lointain, aspect de la maquette).
local function PaintFill(btn, state, iconMode, iconPath)
    local kind = iconMode and "icon" or ("sq:" .. state)
    if btn.fillKind ~= kind then
        btn.fillKind = kind
        btn.iconPath = nil
        btn.icon.paintKey = nil
        if iconMode then
            local tint, trim = Common.get("stal.iconTint"), Common.get("stal.iconTrim")
            btn.icon:SetVertexColor(tint[1], tint[2], tint[3])
            btn.icon:SetTexCoord(trim, 1 - trim, trim, 1 - trim)   -- PE : skillTree.lua:3910 (valeur par defaut du jeton)
        else
            btn.icon:SetTexCoord(0, 1, 0, 1)
            btn.icon:SetTexture(Dense("linkTexStraight"))
            btn.icon:SetDesaturated(false)
            if state == "active" then
                PaintKey(btn.icon, StateKey("active"))
            elseif state == "ready" then
                PaintKey(btn.icon, Dense("fillKey"))
            else
                PaintKey(btn.icon, StateKey("locked"))
            end
        end
    end
    if iconMode then
        if btn.iconPath ~= iconPath then
            btn.iconPath = iconPath
            btn.icon:SetTexture(iconPath)
        end
        btn.icon:SetDesaturated(DESATURATED[state] and true or false)
        btn.icon:SetAlpha(state == "locked" and Dense("lockedAlpha") or 1)
    else
        btn.icon:SetAlpha((state == "locked" or state == "inconnu" or state == "unknown") and Dense("fillLockedAlpha") or 1)
    end
end

local function ConfigureButton(self, btn, id, node, sx, sy, snap, size, showText)
    local state = snap.state and snap.state[id] or "inconnu"
    btn.id = id
    btn.currency = node.currency
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", self.content, "TOPLEFT", sx, -sy)
    btn:SetSize(size, size)
    local iconMode = size >= Dense("iconMinPx")
    PaintFill(btn, state, iconMode, iconMode and NS.Dense.Data.IconOf(id) or nil)
    PaintKey(btn.border, StateKey(state))

    if showText and snap.max and (snap.max[id] or 0) > 0 then
        btn.rank:SetText(tostring(snap.rank and snap.rank[id] or 0) .. "/" .. tostring(snap.max[id]))
        btn.rank:Show()
    else
        btn.rank:Hide()
    end

    if snap.pending and snap.pending[id] then
        local t = Texture(btn, "pendingTex", "OVERLAY")
        t:SetAllPoints(btn.icon)
        PaintKey(t, Dense("pendingKey"))
        EbonAPI.Palette.alpha(t, Dense("pendingAlpha"))
        t:Show()
    elseif btn.pendingTex then
        btn.pendingTex:Hide()
    end

    if self.hoverId == id or (self.marks and self.marks[id]) then
        NS.Overlay.NodeHalo(btn, btn.currency)
    else
        NS.Overlay.HideNodeHalo(btn)
    end
    btn:Show()
end

-- Place un lien (droit : WHITE8x8 ; incline : link_line + TexCoord a 8 valeurs, comme PE)
local function PlaceLink(self, tex, x1, y1, x2, y2, lit)
    local dx, dy = x2 - x1, -(y2 - y1)
    local len = sqrt(dx * dx + dy * dy)
    if len < Common.get("stal.linkMinLength") then return false end
    local w = lit and Dense("linkLitPx") or Dense("linkPx")
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", self.content, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    PaintKey(tex, lit and Dense("mapLinkLitKey") or Dense("linkKey"))
    if abs(dy) < Common.get("stal.linkAxisTolerance") or abs(dx) < Common.get("stal.linkAxisTolerance") then
        tex:SetTexture(Dense("linkTexStraight"))
        tex:SetTexCoord(0, 1, 0, 1)
        if abs(dy) < Common.get("stal.linkAxisTolerance") then tex:SetSize(len, w) else tex:SetSize(w, len) end
        return true
    end
    if self.tiltedMissing then return false end
    local c, s = dx / len, dy / len
    local hw = (len * abs(c) + w * abs(s)) / 2
    local hh = (len * abs(s) + w * abs(c)) / 2
    local ku, kv = 1 / (len * Dense("linkTexFactor")), 1 / (w * Dense("linkTexFactor"))
    local function uv(qx, qy)
        return 0.5 + (qx * c + qy * s) * ku, 0.5 - (qy * c - qx * s) * kv
    end
    local ulx, uly = uv(-hw, hh)
    local llx, lly = uv(-hw, -hh)
    local urx, ury = uv(hw, hh)
    local lrx, lry = uv(hw, -hh)
    tex:SetTexture(Dense("linkTexTilted"))
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    tex:SetSize(hw * 2, hh * 2)
    return true
end

-- Selection plafonnee : si n depasse cap, un element sur n/cap (repartition uniforme)
local function Pick(list, i, n, cap)
    if n <= cap then return list[i] end
    return list[floor((i - 1) * n / cap) + 1]
end

-- Rayon d'une constellation en unites de donnees : noeud de la classe le plus loin de son centre (calcule une fois).
local function HubRadius(hub)
    if hub.radius then return hub.radius end
    local r = 0
    local nodes = NS.Dense.Data.Nodes or {}
    for i = 1, #nodes do
        local n = nodes[i]
        if n.classId == hub.classId then
            local dx, dy = (n.x or 0) - hub.x, (n.y or 0) - hub.y
            local d = sqrt(dx * dx + dy * dy)
            if d > r then r = d end
        end
    end
    hub.radius = r > 0 and r or Dense("hubRadius")
    return hub.radius
end

local function OwnToken()
    local _, token = UnitClass("player")
    return token
end

-- Aura (sous les liens, sur content) + icone et anneau (cadre hubLayer, sous les boutons de noeuds).
local function LayoutCenter(self)
    local pan = self.pan
    if pan then return pan.x, pan.y, pan.spanX, pan.spanY end
    return self.cx, self.cy, 0, 0
end

local function PanCovers(pan, x, y)
    return pan and math.abs(x - pan.x) <= pan.spanX and math.abs(y - pan.y) <= pan.spanY
end

function Methods:LayoutHubs(vw, vh, k, z)
    local hubs = NS.Dense.Data and NS.Dense.Data.Hubs or {}
    local pool = self.hubPieces
    local own = OwnToken()
    local halfW, halfH = vw / 2, vh / 2
    local lx, ly = LayoutCenter(self)
    local shown = min(#hubs, Dense("hubMax"))
    for i = 1, shown do
        local hub = hubs[i]
        local piece = pool[i]
        local sx, sy = halfW + (hub.x - lx) * k, halfH - (hub.y - ly) * k
        local size = Dense("hubSize") * Dense("hubIconScale") * z
        if sx + size > 0 and sx - size < vw and sy + size > 0 and sy - size < vh and size >= 4 then
            if not piece then
                piece = {}
                piece.icon = self.hubLayer:CreateTexture(nil, "ARTWORK")
                piece.icon:SetTexture(Dense("hubIcon"))
                piece.ring = self.hubLayer:CreateTexture(nil, "OVERLAY")
                piece.ring:SetTexture(Dense("hubRing"))
                local coords = (_G.CLASS_BUTTONS and _G.CLASS_BUTTONS[hub.token])
                    or (_G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[hub.token])
                if coords then piece.icon:SetTexCoord(unpack(coords)) end
                pool[i] = piece
            end
            piece.icon:SetSize(size, size)
            piece.icon:ClearAllPoints()
            piece.icon:SetPoint("CENTER", self.content, "TOPLEFT", sx, -sy)
            piece.ring:SetSize(size * Dense("hubRingScale"), size * Dense("hubRingScale"))
            piece.ring:ClearAllPoints()
            piece.ring:SetPoint("CENTER", piece.icon, "CENTER", 0, 0)
            piece.icon:Show()
            piece.ring:Show()
        elseif piece then
            piece.icon:Hide()
            piece.ring:Hide()
        end
    end
end

local function NodeText(node)
    if node._searchText then return node._searchText end
    local names, complete = {}, true
    for _, spell in ipairs(node.spells or {}) do
        local name = GetSpellInfo(spell)
        if name then names[#names + 1] = string.lower(name) else complete = false end
    end
    local text = table.concat(names, "\n")
    if complete then node._searchText = text end
    return text
end

local function HasFilter(self)
    return self.filter ~= nil and self.filter ~= ""
end

local function Matches(self, node)
    if not HasFilter(self) then return true end
    return string.find(NodeText(node), self.filter, 1, true) ~= nil
end

function Methods:Layout()
    if self.destroyed then return end
    local Data = NS.Dense.Data
    local snap = self.snap or {}
    local vw, vh = ViewSize(self)
    local z = self.zoom
    local k = Common.get("stal.spacingScale") * z
    self.content:SetSize(vw, vh)
    local cx, cy, spanX, spanY = LayoutCenter(self)
    local hx, hy = (vw / 2 + Dense("viewMargin")) / k + spanX, (vh / 2 + Dense("viewMargin")) / k + spanY
    local x0, y0, x1, y1 = cx - hx, cy - hy, cx + hx, cy + hy
    local halfW, halfH = vw / 2, vh / 2
    self:LayoutHubs(vw, vh, k, z)

    -- noeuds en vue (grille)
    local ids = Data.Grid:Query(x0, y0, x1, y1) or {}
    if HasFilter(self) then
        local kept = self.filtered or {}
        self.filtered = kept
        for i = #kept, 1, -1 do kept[i] = nil end
        for _, id in ipairs(ids) do
            local node = Data.ById[id]
            if node and Matches(self, node) then kept[#kept + 1] = id end
        end
        ids = kept
    end
    local n = #ids
    local count = min(n, Common.get("stal.maxButtons"))
    local size = max(Dense("nodeMinPx"), Dense("nodeSize") * z)
    local showText = z >= Dense("textMinZoom")
    local pool = self.buttons
    if n > 0 and not self.primed then
        -- Reserve complete au premier rendu : le panoramique ne cree ensuite aucune frame (plafond MAX_BUTTONS)
        self.primed = true
        for i = #pool + 1, Common.get("stal.maxButtons") do
            local btn = NewButton(self)
            btn:Hide()
            pool[i] = btn
        end
    end
    for i = 1, count do
        local id = Pick(ids, i, n, Common.get("stal.maxButtons"))
        local node = Data.ById[id]
        if node then
            local btn = pool[i]
            if not btn then
                btn = NewButton(self)
                pool[i] = btn
            end
            ConfigureButton(self, btn, id, node, halfW + (node.x - cx) * k, halfH - (node.y - cy) * k,
                snap, size, showText)
        else
            count = i - 1
            break
        end
    end
    for i = count + 1, self.nodesShown do
        if pool[i] then pool[i]:Hide() end
    end
    self.nodesShown = count
    if HasFilter(self) and self.hoverId ~= nil then
        local hovered = false
        for i = 1, count do
            if pool[i].id == self.hoverId then hovered = true break end
        end
        if not hovered then
            for _, b in ipairs(pool) do
                if b.id == self.hoverId and b.halo then b.halo:Hide() end
            end
            self.hoverId = nil
            Call(self.hoverFn, nil)
        end
    end
    self:SyncButtonLevels()

    -- liens en vue
    local links = LinksOf(Data, x0, y0, x1, y1)
    local ln = #links
    local tex, used = self.linkTex, 0
    local rank = snap.rank or {}
    for i = 1, min(ln, Common.get("stal.maxLinks")) do
        local link = Pick(links, i, ln, Common.get("stal.maxLinks"))
        if type(link) == "number" then link = Data.Links[link] end
        local a, b = LinkEnds(link)
        local na, nb = a and Data.ById[a], b and Data.ById[b]
        if na and nb and Matches(self, na) and Matches(self, nb) then
            local t = tex[used + 1]
            if not t then
                t = self.content:CreateTexture(nil, "BACKGROUND")
                tex[used + 1] = t
            end
            local lit = (rank[a] or 0) > 0 and (rank[b] or 0) > 0
            if PlaceLink(self, t, halfW + (na.x - cx) * k, halfH - (na.y - cy) * k,
                halfW + (nb.x - cx) * k, halfH - (nb.y - cy) * k, lit) then
                used = used + 1
                t:Show()
            end
        end
    end
    for i = used + 1, self.linksShown do
        if tex[i] then tex[i]:Hide() end
    end
    self.linksShown = used
    self.laid = { snap = self.snap, cx = self.cx, cy = self.cy, zoom = z, vw = vw, vh = vh, pan = self.pan }
end

function Methods:SetFilter(text)
    local value = string.lower(text or "")
    if value == (self.filter or "") then return end
    self.filter = value
    self.laid = nil
    self:Layout()
end

-- Boutons de noeud au-dessus de content : la vue (ScrollFrame, souris) est au-dessus de content ; un bouton reste
-- sous la vue si la surface a ete remontee apres sa creation (content suit la vue, ses enfants non).
function Methods:SyncButtonLevels()
    local level = self.content:GetFrameLevel() + 1
    local first = self.buttons[1]
    if not first or first:GetFrameLevel() == level then return end   -- tous les boutons partagent le meme niveau
    for _, btn in ipairs(self.buttons) do
        btn:SetFrameLevel(level)
    end
end

function Methods:SetView(cx, cy, zoom, defer)
    local newZoom = Clamp(zoom or self.zoom, NS.View.ZoomLimits())
    local nx, ny = ClampCenter(cx or self.cx, cy or self.cy)
    local pan = self.pan
    if pan and newZoom == self.zoom and not defer and PanCovers(pan, nx, ny) then
        self.cx, self.cy = nx, ny
        local k = Common.get("stal.spacingScale") * self.zoom
        self.view:SetHorizontalScroll((nx - pan.x) * k)
        self.view:SetVerticalScroll(-(ny - pan.y) * k)
        for _, fn in ipairs(self.viewFns) do Call(fn, self.cx, self.cy, self.zoom) end
        return
    end
    self.zoom = newZoom
    self.cx, self.cy = nx, ny
    self:UpdateZoomText()
    if self.pan then
        self.pan = nil
        self.view:SetHorizontalScroll(0)
        self.view:SetVerticalScroll(0)
    end
    if not defer then self:Layout() end
    for _, fn in ipairs(self.viewFns) do Call(fn, self.cx, self.cy, self.zoom) end
end

-- Controle « - 60 % + » en haut a gauche DANS la carte : l'element Kit « zoom » ; chaque + ou - avance d'un cran
-- de la molette (NS.View.WheelZoom) ; cree seulement a la demande (jamais dans Create, que les essais de la carte appellent
-- sans Kit) ; la molette met l'element a jour (SetValue ne rappelle pas onChange).
function Methods:UpdateZoomText()
    if self.zoomControl then self.zoomControl:SetValue(self.zoom) end
end

function Methods:ZoomBy(notches)
    self:SetView(self.cx, self.cy, (NS.View.WheelZoom(self.zoom, notches)))
end

local function ApplyZoomLevel(self, gauge)
    local control = self.zoomControl
    local level = self.view:GetFrameLevel() + Common.get("stal.controlLevel")
    local dress = EbonAPI.DressTree
    local surface = gauge and dress and type(dress.surface) == "function" and dress.surface() or nil
    if surface and surface.GetFrameLevel then
        -- Meme rangee que la jauge habillee (niveau surface + tree.gaugeLevel) : le controle passe devant la plaque de la jauge,
        -- qui deborde de son cadre, sinon il reste cache dessous dans les skins a plaque large.
        level = math.max(level, surface:GetFrameLevel() + Common.get("tree.gaugeLevel") + 1)
    end
    -- SetFrameLevel ne touche pas les enfants : les boutons - et + (crees au niveau d'origine) resteraient SOUS le fond du
    -- controle. Chaque descendant suit donc le decalage de niveau du controle.
    local shift = level - control:GetFrameLevel()
    local function Follow(frame)
        for _, child in ipairs({ frame:GetChildren() }) do
            child:SetFrameLevel(child:GetFrameLevel() + shift)
            Follow(child)
        end
    end
    Follow(control)
    control:SetFrameLevel(level)
end

-- Le controle de zoom se place du cote OPPOSE au panneau STAL (gauche si le panneau est a droite, droite sinon).
function Methods:PlaceZoomControl()
    local control = self.zoomControl
    if not control then return end
    local gauge = self.zoomGaugeFn()
    local parent = gauge and self.zoomRoot or self.view
    local reparented = parent ~= control:GetParent()
    if reparented then
        control:SetParent(parent)
        self.zoomAnchor = nil
        ApplyZoomLevel(self, gauge)
    end
    local mirrored = NS.Nav.Side() == "LEFT"
    local point, relativeTo, relativePoint, x, y
    if gauge then
        local gap = Common.get("stal.zoomGaugeGap")
        if mirrored then
            point, relativeTo, relativePoint, x, y = "LEFT", gauge, "RIGHT", gap, 0
        else
            point, relativeTo, relativePoint, x, y = "RIGHT", gauge, "LEFT", -gap, 0
        end
    elseif mirrored then
        point, relativeTo, relativePoint, x, y = "TOPRIGHT", self.view, "TOPRIGHT", -Dense("zoomMargin"), -Dense("zoomMargin")
    else
        point, relativeTo, relativePoint, x, y = "TOPLEFT", self.view, "TOPLEFT", Dense("zoomMargin"), -Dense("zoomMargin")
    end
    local last = self.zoomAnchor
    if last and last[1] == point and last[2] == relativeTo and last[3] == relativePoint and last[4] == x and last[5] == y then return end
    self.zoomAnchor = { point, relativeTo, relativePoint, x, y }
    control:ClearAllPoints()
    control:SetPoint(point, relativeTo, relativePoint, x, y)
end

function Methods:AttachZoomControl(api, root, readGauge)
    if self.zoomControl then return self.zoomControl end
    local view = self.view
    self.zoomRoot, self.zoomGaugeFn = root, readGauge
    local gauge = readGauge()
    local zoomMin, zoomMax, zoomRatio = NS.View.ZoomLimits()
    local button, gap = EbonAPI.Bricks.value("widgets.zoom.height"), EbonAPI.Bricks.value("widgets.zoom.gap")
    local control = api:Create("zoom", gauge and root or view, {
        width = 2 * button + 2 * gap + Common.get("stal.zoomReadout"),
        value = self.zoom, min = zoomMin, max = zoomMax, step = zoomRatio,
        onChange = function(value)
            Abandon()
            local notches = value > self.zoom and 1 or (value < self.zoom and -1 or 0)
            if notches ~= 0 then Call(self.ZoomBy, self, notches) end
        end,
    })
    self.zoomControl = control
    self:PlaceZoomControl()
    ApplyZoomLevel(self, gauge)
    return control
end

function Methods:PanTo(cx, cy, toX, toY, zoom)
    local pan = self.pan
    local covered = pan and math.abs(toX - pan.x) <= pan.spanX and math.abs(toY - pan.y) <= pan.spanY
    if not covered or (zoom and zoom ~= self.zoom) then
        self.zoom = Clamp(zoom or self.zoom, NS.View.ZoomLimits())
        self:UpdateZoomText()
        self.pan = {
            x = (self.cx + toX) / 2, y = (self.cy + toY) / 2, toX = toX, toY = toY,
            spanX = math.abs(toX - self.cx) / 2, spanY = math.abs(toY - self.cy) / 2,
        }
        self:Layout()
    end
    local k = Common.get("stal.spacingScale") * self.zoom
    self.cx, self.cy = ClampCenter(cx, cy)
    self.view:SetHorizontalScroll((self.cx - self.pan.x) * k)
    self.view:SetVerticalScroll(-(self.cy - self.pan.y) * k)
    for _, fn in ipairs(self.viewFns) do Call(fn, self.cx, self.cy, self.zoom) end
end

function Methods:GetView() return self.cx, self.cy, self.zoom end

local function SameSnap(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for key, va in pairs(a) do
        if key ~= "preset" then
            local vb = b[key]
            if va ~= vb then
                if type(va) ~= "table" or type(vb) ~= "table" then return false end
                for k, v in pairs(va) do if vb[k] ~= v then return false end end
                for k in pairs(vb) do if va[k] == nil then return false end end
            end
        end
    end
    for key in pairs(b) do if key ~= "preset" and a[key] == nil then return false end end
    return true
end

function Methods:Refresh(snapshot)
    local laid = self.laid
    if snapshot and laid and SameSnap(laid.snap, snapshot) and laid.zoom == self.zoom and laid.pan == self.pan
        and ((self.pan and PanCovers(self.pan, self.cx, self.cy)) or (laid.cx == self.cx and laid.cy == self.cy)) then
        local vw, vh = ViewSize(self)
        if laid.vw == vw and laid.vh == vh then return end
    end
    if snapshot then self.snap = snapshot end
    self:Layout()
end

function Methods:SetHighlight(marks)
    local before = self.marks
    self.marks = marks
    local pool = self.buttons
    for i = 1, self.nodesShown do
        local btn = pool[i]
        local id = btn and btn.id
        if id and ((before and before[id]) or (marks and marks[id])) then
            if self.hoverId == id or (marks and marks[id]) then
                NS.Overlay.NodeHalo(btn, btn.currency)
            else
                NS.Overlay.HideNodeHalo(btn)
            end
        end
    end
end

local SAFETY_MIN_ZOOM = 0.1

local function NodesBox(ids)
    local x0, y0, x1, y1
    for id in pairs(ids or {}) do
        local node = NS.Dense.Data.ById[id]
        if node then
            x0, x1 = min(x0 or node.x, node.x), max(x1 or node.x, node.x)
            y0, y1 = min(y0 or node.y, node.y), max(y1 or node.y, node.y)
        end
    end
    return x0, y0, x1, y1
end

function Methods:Surface()
    local map = self
    local surface = {}

    function surface.visible() return not map.destroyed and map.view:IsVisible() and true or false end
    function surface.ready() return not map.destroyed end
    function surface.get() return map.zoom, map.cx, map.cy end

    surface.geometry = {
        frame = function() return map.content end,
        rect = function()
            local vw, vh = ViewSize(map)
            local hs, vs = map.view:GetHorizontalScroll(), map.view:GetVerticalScroll()
            return hs, vs, hs + vw, vs + vh
        end,
        point = function(id)
            local node = NS.Dense.Data.ById[id]
            if not node then return nil end
            local vw, vh = ViewSize(map)
            local k = Common.get("stal.spacingScale") * map.zoom
            local hs, vs = map.view:GetHorizontalScroll(), map.view:GetVerticalScroll()
            return vw / 2 + (node.x - map.cx) * k + hs, vh / 2 - (node.y - map.cy) * k + vs
        end,
    }

    function surface.place(zoom, cx, cy, defer)
        map.anim:SetScript("OnUpdate", nil)
        map:SetView(cx, cy, zoom, defer)
    end

    function surface.pan(cx, cy, toX, toY, zoom)
        map:PanTo(cx, cy, toX, toY, zoom)
    end

    function surface.plan(missing, affordable, originZoom)
        local x0, y0, x1, y1 = NodesBox(missing)
        if not x0 then return nil end
        local vw, vh = ViewSize(map)
        local spacing = Common.get("stal.spacingScale")
        local margin = Dense("viewMargin")
        local fit = NS.View.FitBox(max(x1 - x0, 1) * spacing, max(y1 - y0, 1) * spacing, vw, vh, margin)
        if fit < SAFETY_MIN_ZOOM then
            local f0, g0, f1, g1
            if affordable and next(affordable) then f0, g0, f1, g1 = NodesBox(affordable) end
            if not f0 then f0, g0, f1, g1 = NodesBox(NS.Plan.LargestGroup(missing)) end
            if f0 then
                x0, y0, x1, y1 = f0, g0, f1, g1
                fit = NS.View.FitBox(max(x1 - x0, 1) * spacing, max(y1 - y0, 1) * spacing, vw, vh, margin)
            end
        end
        return max(SAFETY_MIN_ZOOM, min(originZoom, fit)), (x0 + x1) / 2, (y0 + y1) / 2
    end

    return surface
end

function Methods:OnHover(fn) self.hoverFn = fn end
function Methods:OnNodeClick(fn) self.clickFn = fn end
-- Ajout hors contrat : suivre les changements de vue (minimap) ; appelee sous pcall.
function Methods:OnView(fn) self.viewFns[#self.viewFns + 1] = fn end
-- Ajout hors contrat : l'asset link_line de PE est absent -> liens inclines non dessines.
function Methods:SetTiltedMissing(flag) self.tiltedMissing = flag and true or false; self.laid = nil; self:Layout() end
function Methods:TiltedMissing() return self.tiltedMissing end

function Methods:Restyle()
    self.laid = nil
    for _, btn in ipairs(self.buttons) do ApplyFont(btn.rank); btn.fillKind = nil end
end

-- Molette : meme echelle de crans, meme cale et meme point fixe que la vue normale (NS.View.WheelZoom) ; le point de
-- donnees sous le curseur reste dessous, en avant comme en arriere.
function Methods:Wheel(delta)
    Abandon()
    self.wheelNotches = self.wheelNotches + (delta > 0 and 1 or -1)
    self.wheelFrame:SetScript("OnUpdate", self.onWheel)
end

function Methods:WheelStep()
    local notches = self.wheelNotches
    self.wheelNotches = 0
    self.wheelFrame:SetScript("OnUpdate", nil)
    if notches == 0 then return end
    local vw, vh = ViewSize(self)
    local z = self.zoom
    local zn = NS.View.WheelZoom(z, notches)
    if zn == z then return end
    local mx, my = Cursor(self.view)
    local ax, ay = mx - self.view:GetLeft(), self.view:GetTop() - my
    local k, kn = Common.get("stal.spacingScale") * z, Common.get("stal.spacingScale") * zn
    local px, py = self.cx + (ax - vw / 2) / k, self.cy - (ay - vh / 2) / k
    self:SetView(px - (ax - vw / 2) / kn, py + (ay - vh / 2) / kn, zn)
end

function Methods:BeginDrag(button)
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    Abandon()
    self.dragging = true
    self.moved = false
    self.dragX, self.dragY = Cursor(self.view)
    self.dragCx, self.dragCy = self.cx, self.cy
    self.view:SetScript("OnUpdate", function(_, elapsed) self:DragStep(elapsed) end)
end

function Methods:DragStep(elapsed)
    if not self.dragging then return end
    -- comme PE : au plus un pas par DRAG_INTERVAL (elapsed plafonne a 0,1 s) ; sans argument = un pas immediat
    if elapsed then
        self.dragTimer = (self.dragTimer or 0) + math.min(elapsed, 0.1)
        if self.dragTimer < Common.get("stal.dragInterval") - 1e-9 then return end
        self.dragTimer = 0
    end
    local mx, my = Cursor(self.view)
    local dx, dy = mx - self.dragX, my - self.dragY
    if not self.moved and abs(dx) < Common.get("stal.dragThreshold") and abs(dy) < Common.get("stal.dragThreshold") then return end
    self.moved = true
    local k = Common.get("stal.spacingScale") * self.zoom
    self:SetView(self.dragCx - dx / k, self.dragCy - dy / k, self.zoom)
end

function Methods:EndDrag(button)
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    self.dragging = false
    self.view:SetScript("OnUpdate", nil)
end

-- Recentrage court par OnUpdate (frame creee une fois a Create, script pose seulement pendant le mouvement)
function Methods:CenterOn(x, y, animated)
    Abandon()
    local tx, ty = ClampCenter(x, y)
    if not animated then
        self.anim:SetScript("OnUpdate", nil)
        self:SetView(tx, ty, self.zoom)
        return
    end
    local sx, sy, t = self.cx, self.cy, 0
    self.anim:SetScript("OnUpdate", function(frame, elapsed)
        t = t + (elapsed or 0)
        local p = Clamp(t / Common.get("stal.centerSeconds"), 0, 1)
        local e = p * p * (3 - 2 * p)
        self:SetView(sx + (tx - sx) * e, sy + (ty - sy) * e, self.zoom)
        if p >= 1 then frame:SetScript("OnUpdate", nil) end
    end)
end

function Methods:Destroy()
    self.destroyed = true
    self.dragging = false
    self.view:SetScript("OnUpdate", nil)
    self.anim:SetScript("OnUpdate", nil)
    self.wheelFrame:SetScript("OnUpdate", nil)
    self.view:Hide()
    self.hoverFn, self.clickFn, self.snap, self.marks, self.viewFns = nil, nil, nil, nil, {}
end

function Map.Create(parent)
    local self = setmetatable({}, Meta)
    local view = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, view)
    view:SetScrollChild(content)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    self.view, self.content = view, content
    self.anim = CreateFrame("Frame", nil, view)
    self.wheelFrame, self.wheelNotches = CreateFrame("Frame", nil, view), 0
    self.onWheel = function() self:WheelStep() end
    self.hubPieces = {}
    self.hubLayer = CreateFrame("Frame", nil, content)
    self.hubLayer:SetAllPoints(content)
    self.buttons, self.linkTex, self.viewFns = {}, {}, {}
    self.nodesShown, self.linksShown = 0, 0
    self.zoom, self.cx, self.cy = Dense("defaultZoom"), 0, 0
    view:SetScript("OnMouseWheel", function(_, delta) self:Wheel(delta) end)
    view:SetScript("OnMouseDown", function(_, button) self:BeginDrag(button) end)
    view:SetScript("OnMouseUp", function(_, button) self:EndDrag(button) end)
    view:SetScript("OnSizeChanged", function() self:Layout() end)
    -- Entree de la souris sur la vue : la surface a pu etre remontee depuis le dernier Layout.
    view:HookScript("OnEnter", function() self:SyncButtonLevels() end)
    return self
end

-- Valeurs exposees, lues a l'usage (jeton du skin ou EbonAPI.Common), jamais recopiees.
Map.LinkTexTilted = function() return Dense("linkTexTilted") end
-- Ajout W5 : le controleur en deduit le rectangle de vue de la minimap et teste l'asset des liens inclines.
