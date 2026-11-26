local NS = SkillTreeAutoLoad

-- Arbre dense (W1) : état vivant de l'arbre de PE, lu SANS rien recopier de ses règles.
--
-- Constat sur skillTree_classes.lua (PE, lu le 03/11) :
--  * Les nœuds de classe (btn.classId) ont leur état écrit dans btn.state par refreshAccessibility
--    via ClassTree.NodeState(btn, parents, ashPool) (skillTree.lua:3735) : "active" si possédé ou
--    en attente (CT.Has), "locked" si la chaîne n'est pas posée, "ready" si niveau ET cendres
--    suffisent, sinon "nopoints". Lire btn.state suffit donc, comme pour le reste de l'arbre.
--  * Leur texte de rang est "1/1" (possédé OU en attente) ou "0/1" (skillTree.lua:3705).
--  * Leur « en attente » vit dans ProjectEbonhold.ClassTree.pending[id] (table publique, lecture
--    seule ici) ; il ne passe pas par Bridge.GetServerNodes. Repli si la table manque : pas de
--    pending pour les classes (pending[id] = nil).
--
-- Lit : boutons skillTreeNode<id> (.state, .rankText, .stackBadge.count), skillTreeFrame.poolTexts,
-- skillTreeBottomBar (bouton Appliquer, repéré par son champ __anchorToSearch), Bridge.GetServerNodes, Cost.Budgets.
NS.Dense = NS.Dense or {}
NS.Dense.STATE_TOKEN = { active = "stateActive", ready = "stateReady", nopoints = "stateNopoints", locked = "stateLocked",
    inconnu = "stateUnknown", unknown = "stateUnknown" }
local State = {}
NS.Dense.State = State

-- Clés de texte (NS.L) des raisons de repli.
local REASON_UNAVAILABLE = NS.REASON_UNAVAILABLE
-- Origines d'un solde.
local SOURCE_PE, SOURCE_SERVER, SOURCE_NONE = "pe", "server", "none"
local STATE_UNKNOWN = "unknown"
local BUTTONS = { LeftButton = true, RightButton = true }
local byte = string.byte

local buttons = {}          -- id -> bouton PE (mis en cache une fois trouvé)
local subscribers = {}
local hooked = false
local queued = false
local driver
local presetMarks = {}      -- ensemble d'ids du preset survolé (vide si aucun)
local applyCache

local function Button(id)
    local btn = buttons[id]
    if btn then return btn end
    btn = NS.Core.NodeButton(id)
    if btn then buttons[id] = btn end
    return btn
end

local function ReadNumber(text, from)
    local value, i, b = 0, from, byte(text, from)
    if not (b and b >= 48 and b <= 57) then return nil, from end
    repeat
        value = value * 10 + (b - 48)
        i = i + 1
        b = byte(text, i)
    until not (b and b >= 48 and b <= 57)
    return value, i
end

-- Rang courant d'un bouton : badge pour les infinis, "r/max" sinon, coche pour un choix multiple.
local function ReadRank(node, btn)
    if node.infinite then
        local badge = btn.stackBadge
        if not (badge and badge:IsShown() and badge.count) then return 0 end
        return tonumber(badge.count:GetText()) or 0
    end
    local text = btn.rankText and btn.rankText:GetText()
    if not text or text == "" then return 0 end
    local rank = ReadNumber(text, 1)
    if rank then return rank end
    return node.isMultipleChoice and 1 or 0
end

local function MaxRank(node)
    return node.spells and #node.spells or 0
end

-- Instantané complet : une boucle sur les nœuds, à la demande de l'appelant seulement.
function State.Snapshot()
    local Data = NS.Dense.Data
    local snap = { rank = {}, max = {}, state = {}, pending = {}, infinite = {}, known = true, missing = 0 }
    local built, why = Data.Build()
    if not built then
        snap.known, snap.reason = false, why
        return snap
    end

    local server = NS.Bridge and NS.Bridge.GetServerNodes and NS.Bridge.GetServerNodes()
    snap.pendingKnown = server ~= nil
    local classTree = ProjectEbonhold and ProjectEbonhold.ClassTree
    local classPending = classTree and type(classTree.pending) == "table" and classTree.pending or nil

    local nodes = Data.Nodes
    for i = 1, #nodes do
        local node = nodes[i]
        local id = node.id
        local btn = Button(id)
        snap.max[id] = MaxRank(node)
        if node.infinite then snap.infinite[id] = true end
        if not btn then
            snap.missing = snap.missing + 1
            snap.rank[id], snap.state[id] = 0, STATE_UNKNOWN
        else
            local rank = ReadRank(node, btn)
            snap.rank[id] = rank
            snap.state[id] = btn.state or STATE_UNKNOWN
            if node.classId then
                if classPending and classPending[id] then snap.pending[id] = true end
            elseif server and rank > (server[id] or 0) then
                snap.pending[id] = true
            end
        end
    end

    if snap.missing > 0 then
        snap.known, snap.reason = false, REASON_UNAVAILABLE
    end
    return snap
end

local function Digits(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[^%d]", "")
    return tonumber(text)
end

-- Quatre soldes dans l'ordre de PE (Cost.CURRENCIES = ash, shard, essence, artisan) : le texte
-- affiché par PE (serveur moins achats en attente) ; à défaut les soldes serveur de Cost.Budgets.
function State.Balances()
    local out = {}
    local order = NS.Cost and NS.Cost.CURRENCIES or {}
    local frame = EbonAPI.Ebonhold.Frame("skillTreeFrame")
    local texts = frame and frame.poolTexts
    local budgets
    for i = 1, #order do
        local key = order[i].key
        local entry = { currency = key, source = SOURCE_NONE }
        local amount = texts and texts[i] and Digits(texts[i]:GetText())
        if amount then
            entry.amount, entry.source = amount, SOURCE_PE
        else
            budgets = budgets or (NS.Cost.Budgets and NS.Cost.Budgets())
            if budgets and budgets[key] then entry.amount, entry.source = budgets[key], SOURCE_SERVER end
        end
        out[i] = entry
    end
    return out
end

-- Ids du preset livré actuellement survolé (lecture seule).
function State.PresetMarks()
    return presetMarks
end

function State.SetPresetMarks(nodeRanks)
    local marks = {}
    for id in pairs(nodeRanks or {}) do marks[id] = true end
    presetMarks = marks
end

function State.ClearPresetMarks()
    presetMarks = {}
end

local function Flush()
    queued = false
    if driver then driver:Hide() end
    for i = 1, #subscribers do
        local ok, err = pcall(subscribers[i])
        if not ok and NS.api and NS.api.Debug then NS.api:Debug("dense_state subscriber: " .. tostring(err)) end
    end
end

-- Rafraîchissement de PE : on note qu'il faut prévenir, la notification part au prochain frame
-- (un seul appel même si PE rafraîchit dix fois dans le même frame).
local function Queue()
    if queued then return end
    queued = true
    if driver then driver:Show() else Flush() end
end

local function InstallHook()
    if hooked or type(_G.refreshAccessibility) ~= "function" then return end
    hooked = true
    driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", Flush)
    hooksecurefunc("refreshAccessibility", Queue)
end

-- Abonne fn() aux changements de l'arbre ; renvoie une fonction de désabonnement.
function State.Subscribe(fn)
    if type(fn) ~= "function" then return function() end end
    subscribers[#subscribers + 1] = fn
    InstallHook()
    return function()
        for i = #subscribers, 1, -1 do
            if subscribers[i] == fn then table.remove(subscribers, i) end
        end
    end
end

-- Achat (LeftButton) ou retrait (RightButton) : le bouton de PE traite le clic (Maj compris).
function State.ClickNode(id, button)
    if not BUTTONS[button] then return false end
    local btn = Button(id)
    local onClick = btn and btn:GetScript("OnClick")
    if not onClick then return false end
    onClick(btn, button)
    return true
end

-- Bouton « Appliquer » de PE : enfant de skillTreeBottomBar qui porte le champ __anchorToSearch
-- (posé par PE sur ce seul bouton, skillTree.lua:1865) et un script OnClick (l.1882). Aucun texte
-- affiché n'est lu : le libellé est traduit par PE (ProjectEbonhold.L, l.1862).
function State.ApplyButton()
    if applyCache then return applyCache end
    local bar = EbonAPI.Ebonhold.Frame("skillTreeBottomBar")
    if not (bar and bar.GetChildren) then return nil end
    local children = { bar:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child.__anchorToSearch and child.GetScript and child:GetScript("OnClick") then
            applyCache = child
            return child
        end
    end
    return nil
end

function State.Apply()
    local btn = State.ApplyButton()
    local onClick = btn and btn:GetScript("OnClick")
    if not onClick then return false end
    onClick(btn, "LeftButton")
    return true
end
