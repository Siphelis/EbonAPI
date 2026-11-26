local NS = SkillTreeAutoLoad

-- Arbre dense (W5) : le contrôleur. Il assemble Data, State, Map, Minimap et Chrome (modules dense_*) et décide
-- quand l'écran dense remplace l'arbre de PE : dense ssi fenêtre de PE visible
-- ET données de l'arbre lues (contrat D7). Tout autre cas : l'écran de PE et le compact actuel, inchangés.
--
-- États : off (rien à faire), on (écran dense affiché), repli (retour à l'écran de PE, avec sa raison).
-- Un repli « erreur » ou « retour » est collant : il tient jusqu'à la fermeture de la fenêtre de PE (Disable("hide"))
-- ou jusqu'à ce que les conditions d'activation cessent (fenêtre cachée) ; ApplyLayout rappelle Sync()
-- souvent, sans cette règle l'écran dense reviendrait aussitôt. Un repli « indisponible » (arbre de PE pas encore
-- construit, InitTree différé) se réessaie à chaque rafraîchissement de PE.
--
-- PE n'est jamais modifié ni détruit : skillTreeScroll est caché (Hide) puis ré-affiché ; les boutons de nœuds de PE
-- restent mis à jour (refreshAccessibility ne regarde que la visibilité de skillTreeFrame, skillTree.lua:3797).
-- La fenêtre (plaque, titre, onglets, barre du bas, masquage des éléments natifs) est habillée par le noyau
-- (EbonAPI.DressTree) : STAL ne s'y branche que par TREE_UI_DRESSED / TREE_UI_UNDRESSED, pose son écran dans
-- DressTree.surface() et ses compteurs dans DressTree.bottom(). Rien n'est créé ni accroché avant Enable.
NS.Dense = NS.Dense or {}
local Dense = NS.Dense

-- États et raisons (valeurs internes, jamais affichées telles quelles).
local MODE_OFF, MODE_ON, MODE_FALLBACK = "off", "on", "repli"
local REASON_ERROR, REASON_HIDE, REASON_UNAVAILABLE = "erreur", "hide", "indisponible"
local STICKY = { [REASON_ERROR] = true }
local RETRY = { [REASON_UNAVAILABLE] = true }

-- Identifiants du jeu et du Kit.
local EVENTS = { "SERVER_ASH", "SERVER_POOLS" }
local EVENT_DRESSED, EVENT_UNDRESSED = "TREE_UI_DRESSED", "TREE_UI_UNDRESSED"

-- Mise en page (px) : minimap en bas à droite de la carte ; niveaux de cadre au-dessus de la fenêtre de PE.
local ROOT_LEVEL = 5   -- au-dessus de la surface de DressTree ; marge et niveaux de la minimap : EbonAPI.Common stal.mini*, stal.viewLevel

local mode, why = MODE_OFF, nil
local enabling = false
local ui                      -- { root, map, mini, chrome, snap, marks, activeClass }
local scrollHooked = false
local subscribed = false
local lastError
local Subscribe          -- défini plus bas (installe les crochets une fois)

local function Scroll() return EbonAPI.Ebonhold.Frame("skillTreeScroll") end
local function Window() return EbonAPI.Ebonhold.Frame("skillTreeFrame") end

local Text = NS.Text

-- Ligne unique du repli : canal de diagnostic du coeur (api:Report), pas d'ecriture directe dans le chat.
local function ChatLine(text)
    pcall(function() NS.api:Report(NS.api:Problem("INIT.STEP_FAILED", { part = "Dense", detail = text })) end)
end

-- État pour les essais et le diagnostic : mode, raison, dernière erreur.
function Dense.Status() return mode, why, lastError end

-- Conditions D7 (hors données de l'arbre, lues dans Enable).
local function Wanted()
    local window, scroll = Window(), Scroll()
    return (window and scroll and window:IsVisible()) and true or false
end

local function RestorePE()
    local scroll = Scroll()
    if scroll then scroll:Show() end
    NS.Nav.SetMap(nil)
    if ui then
        ui.root:Hide()
        pcall(ui.chrome.HideTip, ui.chrome)
    end
end

-- Quitte l'écran dense. « hide » (fenêtre fermée) et toute raison non collante : retour à off ; « erreur » et
-- « retour » : repli collant (voir l'en-tête). PE retrouve son écran (skillTreeScroll ré-affiché, rien détruit).
local function ClearPortrait(on)
    local tree = EbonAPI.DressTree
    if tree and type(tree.clearPortrait) == "function" then pcall(tree.clearPortrait, on) end
end

local disabling = false

function Dense.Disable(reason)
    if disabling then return end
    disabling = true
    local ok, err = pcall(function()
        if reason == REASON_HIDE then ClearPortrait(false) end
        local was = mode == MODE_ON
        if STICKY[reason] then
            mode, why = MODE_FALLBACK, reason
        elseif RETRY[reason] then
            mode, why = MODE_FALLBACK, reason
        else
            mode, why = MODE_OFF, nil
        end
        if was then
            if NS.View and NS.View.UseSurface then pcall(NS.View.UseSurface, nil) end
            RestorePE()
        end
        if STICKY[reason] and EbonAPI.DressTree then pcall(EbonAPI.DressTree.undress) end
    end)
    disabling = false
    if not ok then error(err, 0) end
end

-- Erreur dans l'écran dense : repli sur PE, une ligne dans le chat, jamais d'exception vers l'appelant.
local function Fail(err)
    if mode == MODE_FALLBACK and why == REASON_ERROR then return end   -- deja replie : une seule ligne de chat
    lastError = tostring(err)
    Dense.Disable(REASON_ERROR)
    ChatLine(Text("DENSE_FALLBACK", { reason = lastError }))
end

local function Guard(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Fail(err) end
    return ok
end

-- Rectangle de vue -> minimap ; classe active -> chrome.
local function UpdateView()
    if not ui then return end
    local map = ui.map
    local cx, cy, zoom = map:GetView()
    local w, h = map.view:GetWidth(), map.view:GetHeight()
    if not (w and h and w > 0 and h > 0) then return end
    local k = EbonAPI.Common.get("stal.spacingScale") * zoom
    local viewW, viewH = w / k, h / k
    ui.mini:SetViewRect(cx, cy, viewW, viewH)
    local class = NS.Nav.ClassInView(cx, cy, viewW / 2, viewH / 2)
    if class ~= NS.Nav.ActiveClass() then
        NS.Nav.SetActiveClass(class)
        ui.chrome:SetActiveClass(class)
    end
end

local function RefreshApply()
    local btn = NS.Dense.State.ApplyButton()
    local enabled = btn and btn:IsEnabled()
    ui.chrome:SetApplyEnabled(enabled and enabled ~= 0 and enabled ~= false and true or false)
    return btn
end

-- Un rendu complet à partir de l'état de PE. Les erreurs remontent à l'appelant (Guard).
local function Render()
    local State = NS.Dense.State
    local snap = State.Snapshot()
    local marks = State.PresetMarks()
    snap.preset = marks
    ui.snap = snap
    if marks ~= ui.marks then
        ui.marks = marks
        ui.map:SetHighlight(marks)
    end
    ui.map:Refresh(snap)
    ui.mini:Refresh(snap)
    ui.chrome:SetBalances(State.Balances())
    local apply = RefreshApply()
    local notice
    if snap.missing > 0 or not apply then notice = Text("DENSE_UNAVAILABLE") end
    ui.chrome:SetNotice(notice)
    UpdateView()
end

local function Balances()
    if mode == MODE_ON then ui.chrome:SetBalances(NS.Dense.State.Balances()) end
end

-- Les rappels asynchrones (molette, glisser, minimap, recentrage) tournent hors de Guard : leurs méthodes sont
-- enveloppées une fois pour que toute erreur déclenche le repli.
local function WrapMap(map)
    local layout = getmetatable(map).__index.Layout
    map.Layout = function(self) Guard(layout, self) end
end

local function WrapMini(mini)
    local tick = mini.tick
    if not tick then return end
    mini.tick = function() Guard(tick) end
end

local function BuildPieces(root, built, surface, bottom)
    local Dense_ = NS.Dense
    root:SetAllPoints(surface)
    root:SetFrameLevel((surface:GetFrameLevel() or 0) + ROOT_LEVEL)

    local chrome = Dense_.Chrome.Create(root, bottom)
    local map = Dense_.Map.Create(root)
    -- C4 : la carte est bornée par la colonne du chrome (chrome.slot), jamais dessous.
    local function ReadGauge()
        local tree = rawget(_G, "skillTreeFrame")
        return type(tree) == "table" and tree.progressBar or nil
    end
    local function FitView()
        map.view:ClearAllPoints()
        local left = NS.Nav.Side() == "LEFT"
        local from, to = left and root or chrome.bar, left and chrome.bar or root
        local top = left and "TOPLEFT" or "TOPRIGHT"
        local x1, x2 = left and chrome.leftInset or 0, left and 0 or -chrome.rightInset
        map.view:SetPoint("TOPLEFT", from, top, x1, 0)
        map.view:SetPoint("TOPRIGHT", to, top, x2, 0)
        map.view:SetPoint("BOTTOMRIGHT", to, left and "BOTTOMLEFT" or "BOTTOMRIGHT", x2, 0)
        map:PlaceZoomControl()
    end
    chrome.onLayout = FitView
    FitView()
    root:HookScript("OnShow", FitView)
    map.view:SetFrameLevel(root:GetFrameLevel() + EbonAPI.Common.get("stal.viewLevel"))
    -- C7 : minimap ENFANT de la zone de carte, en bas à droite, au-dessus des nœuds.
    local mini = Dense_.Minimap.Create(map.view)
    mini.element:ClearAllPoints()
    mini.element:SetPoint("BOTTOMRIGHT", map.view, "BOTTOMRIGHT", -EbonAPI.Common.get("stal.miniMargin"), EbonAPI.Common.get("stal.miniMargin"))
    mini.element:SetFrameLevel(map.view:GetFrameLevel() + EbonAPI.Common.get("stal.miniLevel"))
    -- C5 / P10 : contrôle de zoom sur la rangée de la jauge de PE (la barre bleue), à sa gauche ; sans jauge, il reste
    -- en haut à gauche de la carte. Z2 : le bouton « Centrer » est dans la colonne des classes
    -- (dense_chrome.lua), au rang qu'il a dans la barre de nav.lua.
    map:AttachZoomControl(NS.api, root, ReadGauge)
    chrome:OnCenter(function()
        Guard(NS.Nav.GoToCenter)
    end)
    built.chrome, built.map, built.mini = chrome, map, mini
    WrapMap(map)
    WrapMini(mini)

    map:OnNodeClick(function(id, button) Guard(NS.Dense.State.ClickNode, id, button) end)
    map:OnHover(function(id, node)
        Guard(function()
            if id then chrome:ShowTip(id, built.snap, node) else chrome:HideTip() end
        end)
    end)
    map:OnView(function() if ui then Guard(UpdateView) end end)
    mini:OnPan(function(x, y) Guard(map.CenterOn, map, x, y, false) end)
    chrome:OnClass(function(classId)
        Guard(NS.Nav.CommitClass, classId)
    end)
    chrome:OnApply(function() Guard(NS.Dense.State.Apply) end)
    local box = rawget(_G, "skillTreeSearchBox")
    if box and box.HookScript and not box.stalFilter then
        box.stalFilter = true
        box:HookScript("OnTextChanged", function(self)
            if ui and ui.map then Guard(ui.map.SetFilter, ui.map, self:GetText()) end
        end)
    end
    if box then map:SetFilter(box:GetText()) end
    return built
end

-- Le root naît caché ; si la construction échoue, il reste caché (jamais d'écran dense orphelin sur PE).
local function Build(surface, bottom)
    local root = CreateFrame("Frame", nil, surface)
    root:Hide()
    local built = { root = root }
    local ok, err = pcall(BuildPieces, root, built, surface, bottom)
    if not ok then
        root:Hide()
        error(err, 0)
    end
    return built
end

-- Les liens inclinés demandent l'asset link_line de PE (D9) : absent -> liens droits seulement.
local function CheckTilted()
    local probe = ui.probe
    if not probe then
        probe = ui.root:CreateTexture(nil, "BACKGROUND")
        ui.probe = probe
    end
    probe:SetTexture(NS.Dense.Map.LinkTexTilted())
    local present = probe:GetTexture() ~= nil
    probe:SetTexture(nil)
    probe:Hide()
    ui.map:SetTiltedMissing(not present)
end

local function HideScroll()
    local scroll = Scroll()
    if not scrollHooked then
        scrollHooked = true
        scroll:HookScript("OnShow", function(self) if mode == MODE_ON then self:Hide() end end)
    end
    scroll:Hide()
end

local function EnableCore()
    local Data, State = NS.Dense.Data, NS.Dense.State
    local built = Data.Build()
    if not built then
        mode, why = MODE_FALLBACK, REASON_UNAVAILABLE
        return false
    end
    -- D2 : aucun bouton de PE (InitTree différé) -> pas d'écran dense, on réessaie au prochain rafraîchissement.
    local probe = State.Snapshot()
    if probe.missing >= #Data.Nodes then
        mode, why = MODE_FALLBACK, REASON_UNAVAILABLE
        return false
    end
    -- La fenêtre habillée par le noyau : surface (zone libre) et barre du bas ; sinon on réessaie.
    local DressTree = EbonAPI.DressTree
    if DressTree then DressTree.dress() end
    local surface, bottom = DressTree and DressTree.surface(), DressTree and DressTree.bottom()
    if not (surface and bottom and DressTree.state() == "dressed") then
        mode, why = MODE_FALLBACK, REASON_UNAVAILABLE
        return false
    end
    if not ui then ui = Build(surface, bottom) end
    ClearPortrait(true)
    State.ApplyButton()
    mode, why = MODE_ON, nil
    if NS.View and NS.View.UseSurface then NS.View.UseSurface(ui.map:Surface()) end
    HideScroll()
    NS.Nav.SetMap(ui.map)
    ui.root:Show()
    CheckTilted()
    Render()
    return true
end

function Dense.Enable()
    if mode == MODE_ON then return true end
    if not Wanted() then return false end
    if enabling then return false end   -- rappel de PE pendant la construction : pas d'Enable imbrique
    enabling = true
    local ok, res = pcall(function() Subscribe(); return EnableCore() end)
    enabling = false
    if not ok then
        -- Écran dense caché et PE rendu AVANT toute remise à zéro, quel que soit le mode atteint.
        local scroll = Scroll()
        if scroll then scroll:Show() end
        if ui then
            pcall(ui.root.Hide, ui.root)
            pcall(ui.chrome.HideTip, ui.chrome)
        end
        Fail(res)
        if ui and not ui.snap then ui = nil end   -- construction à moitié faite : on repart de zéro à la prochaine tentative
        return false
    end
    return res
end

-- Rafraîchissement de PE (refreshAccessibility, un appel par frame) : rendu, ou nouvel essai d'un repli « indisponible ».
local function OnTreeChanged()
    if mode == MODE_ON then
        Guard(Render)
    elseif mode == MODE_FALLBACK and RETRY[why] then
        Dense.Sync()
    end
end

-- Événements collants du noyau : la fenêtre vient d'être (ré)habillée -> l'écran dense s'accorde ; dé-habillée (fenêtre
-- fermée) -> retour à PE. Pendant Enable le rappel est ignoré (Enable lit déjà la surface).
local function OnDressed()
    if enabling then return end
    if mode == MODE_ON then
        Guard(function() ui.map:Refresh(); UpdateView() end)
    else
        Dense.Sync()
    end
end

local function OnUndressed()
    if enabling then return end
    ClearPortrait(false)
    if mode == MODE_ON then Dense.Disable(nil) end
end

local function OnPreset()
    if mode == MODE_ON then Guard(Render) end
end

Subscribe = function()
    if subscribed then return end
    subscribed = true
    NS.Dense.State.Subscribe(OnTreeChanged)
    NS.api:On(EVENT_DRESSED, OnDressed)
    NS.api:On(EVENT_UNDRESSED, OnUndressed)
    for i = 1, #EVENTS do
        NS.api:On(EVENTS[i], function() Guard(Balances) end)
    end
end

function Dense.ShowPresetMarks(nodeRanks)
    NS.Dense.State.SetPresetMarks(nodeRanks)
    OnPreset()
end

function Dense.ClearPresetMarks()
    NS.Dense.State.ClearPresetMarks()
    OnPreset()
end

-- Appelé par ApplyLayout (ui.lua) : accorde l'état de l'écran dense aux conditions du moment.
function Dense.Sync()
    local ok, err = pcall(function()
        local wanted = Wanted()
        if mode == MODE_ON then
            if wanted then
                ui.map:Refresh()
                UpdateView()
            end
        elseif mode == MODE_FALLBACK then
            if not wanted then
                mode, why = MODE_OFF, nil
            elseif RETRY[why] then
                Dense.Enable()
            end
        elseif wanted then
            Dense.Enable()
        end
    end)
    if not ok then Fail(err) end
end

-- Constantes exposées (essais).
Dense.REASON_ERROR, Dense.REASON_HIDE, Dense.REASON_UNAVAILABLE = REASON_ERROR, REASON_HIDE, REASON_UNAVAILABLE
