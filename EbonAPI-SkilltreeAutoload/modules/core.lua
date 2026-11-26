local NS = SkillTreeAutoLoad

local Core = {}
NS.Core = Core

local byte = string.byte
NS.wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end
local wipe = NS.wipe

local NODE_PREFIX = "skillTreeNode"
NS.EMPTY = {}
local EMPTY = NS.EMPTY

local nodeDefsById, spellCountById, classIds, classParents
local nodeButtons = {}
local warnedMultiChoice = false
local buttonsReady = false
local snapshotCache, snapshotTime, snapshotCount
local snapshotDirty = true
local snapshotStamp = 0
local scratch = {}
local ashesBad = false
local LISTED_NODES = 8

local function Raise(call, code, facts, cause)
    local api = NS.api
    local problem = api:Problem(code, facts, cause)
    api[call](api, problem)
    return nil, api:ProblemText(problem), problem
end

local function Fail(code, facts, cause)
    return Raise("Report", code, facts, cause)
end

local function Lapse(code, facts, cause)
    return Raise("Degrade", code, facts, cause)
end

local function GetNodeDefs()
    if nodeDefsById then return nodeDefsById end
    local db = EbonAPI.Ebonhold.TalentDatabase()
    if not db then
        return nil
    end
    local seenClass = {}
    nodeDefsById, spellCountById, classIds, classParents = {}, {}, {}, {}
    for _, node in ipairs(db[0].nodes) do
        nodeDefsById[node.id] = node
        spellCountById[node.id] = node.spells and #node.spells or 0
        local classId = node.classId
        if classId and not seenClass[classId] then
            seenClass[classId] = true
            classIds[#classIds + 1] = classId
        end
    end
    table.sort(classIds)
    for _, link in ipairs(db[0].links or EMPTY) do
        local child = nodeDefsById[link[2]]
        if child and child.classId then
            local parents = classParents[link[2]]
            if not parents then
                parents = {}
                classParents[link[2]] = parents
            end
            parents[#parents + 1] = link[1]
        end
    end
    return nodeDefsById
end

function Core.GetNodeDefs()
    return GetNodeDefs()
end

function Core.GetClassIds()
    if not GetNodeDefs() then return EMPTY end
    return classIds
end

function Core.TreeScroll()
    return EbonAPI.Ebonhold.Frame("skillTreeScroll")
end

function Core.TreeCanvas()
    return EbonAPI.Ebonhold.Frame("skillTreeCanvas")
end

function Core.NodeButton(nodeId)
    return EbonAPI.Ebonhold.Frame(NODE_PREFIX .. nodeId)
end

local function GetNodeButton(nodeId)
    local btn = nodeButtons[nodeId]
    if btn then return btn end
    btn = Core.NodeButton(nodeId)
    if btn then nodeButtons[nodeId] = btn end
    return btn
end

local function TreeButtonsReady(defs)
    if buttonsReady then return true end
    for nodeId in pairs(defs) do
        if GetNodeButton(nodeId) then
            buttonsReady = true
            return true
        end
    end
    return false
end

local function WarnMultiChoice(node)
    if warnedMultiChoice then return end
    warnedMultiChoice = true
    Lapse("TREE.MULTICHOICE_IGNORED", { node = node.name or node.id })
end

-- Bouton lisible d'un noeud (non locked ; infini : badge visible), sinon nil.
-- Renvoie aussi le badge pour un noeud infini.
local function LiveButton(node)
    local btn = GetNodeButton(node.id)
    if not btn or btn.state == "locked" then return nil end
    if node.infinite then
        local badge = btn.stackBadge
        if not (badge and badge:IsShown()) then return nil end
        return btn, badge
    end
    return btn
end

local function ReadNodeRank(node)
    if node.isMultipleChoice then
        WarnMultiChoice(node)
        return 0
    end

    local btn, badge = LiveButton(node)
    if not btn then return 0 end

    if node.infinite then
        return tonumber(badge.count:GetText()) or 0
    end

    local text = btn.rankText and btn.rankText:GetText()
    local b = text and byte(text, 1)
    if b and b >= 48 and b <= 57 then
        local value, i = 0, 1
        repeat
            value = value * 10 + (b - 48)
            i = i + 1
            b = byte(text, i)
        until not (b and b >= 48 and b <= 57)

        if b == 47 then
            i = i + 1
            b = byte(text, i)
            if b and b >= 48 and b <= 57 then
                repeat
                    i = i + 1
                    b = byte(text, i)
                until not (b and b >= 48 and b <= 57)
                if not b then return value end
            end
        end
    end

    return (btn.state == "active") and spellCountById[node.id] or 0
end

function Core.InvalidateSnapshot()
    snapshotDirty = true
end

function Core.GetTreeSnapshot()
    if snapshotCache and not snapshotDirty and (GetTime() - snapshotTime) < NS.SNAPSHOT_TTL then
        return snapshotCache
    end

    local defs = GetNodeDefs()
    if not defs then return nil, "the talent database is not loaded" end
    if not EbonAPI.Ebonhold.SkillTreeFrame() then return nil, "the Skill Tree frame does not exist yet" end
    if not TreeButtonsReady(defs) then
        local total = 0
        for _ in pairs(defs) do total = total + 1 end
        return nil, "none of the " .. total .. " node buttons is drawn yet"
    end

    wipe(scratch)
    local count = 0
    for nodeId, node in pairs(defs) do
        local rank = ReadNodeRank(node)
        if rank > 0 then
            scratch[nodeId] = rank
            count = count + 1
        end
    end

    snapshotTime, snapshotDirty = GetTime(), false

    if snapshotCache and count == snapshotCount then
        local same = true
        for nodeId, rank in pairs(scratch) do
            if snapshotCache[nodeId] ~= rank then
                same = false
                break
            end
        end
        if same then return snapshotCache end
    end

    snapshotCache, snapshotCount = scratch, count
    scratch = {}
    snapshotStamp = snapshotStamp + 1
    return snapshotCache
end

function Core.GetSnapshotStamp()
    return snapshotStamp
end

function Core.CaptureTreeState()
    Core.InvalidateSnapshot()
    local snapshot, err = Core.GetTreeSnapshot()
    if not snapshot then return nil, err end

    local defs = GetNodeDefs()
    local copy = {}
    for nodeId, rank in pairs(snapshot) do
        if not defs[nodeId].infinite then copy[nodeId] = rank end
    end
    return copy
end

function Core.GetBudgets()
    local budgets = NS.Cost.Budgets()
    local ash = budgets and budgets.ash
    if ash == nil then
        if not ashesBad then
            ashesBad = true
            Lapse("ASHES.UNREADABLE", { text = "nil" })
        end
    elseif ashesBad then
        ashesBad = false
        NS.api:Restore("ASHES.UNREADABLE")
    end
    return budgets
end

function Core.GetAvailableSoulAshes()
    local budgets = Core.GetBudgets()
    return budgets and budgets.ash
end

local function UnreadableBudget(sum, budgets)
    if not budgets then return true end
    for currency, amount in pairs(sum or {}) do
        if amount > 0 and budgets[currency] == nil then return true end
    end
    return false
end

function Core.ComputeActivationPlan(saveNodeRanks, snapshot)
    local defs = GetNodeDefs()
    if not defs then return nil end

    snapshot = snapshot or Core.GetTreeSnapshot()
    if not snapshot then return nil end

    local totalCost, pendingNodes, needs, classCost = {}, 0, {}, {}

    for nodeId, targetRank in pairs(saveNodeRanks or {}) do
        local node = defs[nodeId]
        if node then
            local currentRank = snapshot[nodeId] or 0
            if currentRank < targetRank then
                NS.Cost.AddRanks(totalCost, node, currentRank, targetRank)
                pendingNodes = pendingNodes + 1
                local classId = node.classId
                if classId then
                    needs[classId] = (needs[classId] or 0) + 1
                    NS.Cost.AddRanks(classCost, node, currentRank, targetRank)
                end
            end
        end
    end

    return totalCost, pendingNodes, needs, classCost
end

local function ClassTreeService()
    local tree = EbonAPI.Ebonhold.Service("ClassTree")
    if tree and type(tree.pending) == "table" and type(tree.Level) == "function"
        and type(tree.OwnedCount) == "function" then
        return tree
    end
    return nil
end

local slots = {}
local slotsStamp = 0

local function FreeSlots(tree, classId)
    if not tree then return 0 end
    local okLevel, level = pcall(tree.Level, classId)
    local okOwned, owned = pcall(tree.OwnedCount, classId)
    if not (okLevel and okOwned) then return 0 end
    local free = (tonumber(level) or 0) - (tonumber(owned) or 0)
    return (free > 0) and free or 0
end

function Core.ClassSlots()
    local tree = ClassTreeService()
    local ids = Core.GetClassIds()
    for i = 1, #ids do
        local classId = ids[i]
        local free = FreeSlots(tree, classId)
        if slots[classId] ~= free then
            slots[classId] = free
            slotsStamp = slotsStamp + 1
        end
    end
    return slots, slotsStamp
end

function Core.SpecTab()
    if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
    local okTabs, tabs = pcall(GetNumTalentTabs)
    if not okTabs or type(tabs) ~= "number" or tabs < 1 then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    local best, bestPoints = 1, 0
    for tab = 1, tabs do
        local okInfo, _, _, points = pcall(GetTalentTabInfo, tab, false, false, group)
        if okInfo then
            points = points or 0
            if points > bestPoints then best, bestPoints = tab, points end
        end
    end
    return best
end

function Core.PlayerClassId()
    local db = EbonAPI.Ebonhold.TalentDatabase()
    local hubs = type(db) == "table" and type(db[0]) == "table" and db[0].classHubs
    if type(hubs) ~= "table" then return nil end
    local token = select(2, UnitClass("player"))
    for classId, hub in pairs(hubs) do
        if type(hub) == "table" and hub.token == token then return classId end
    end
    return nil
end

function Core.ClassName(classId)
    local db = EbonAPI.Ebonhold.TalentDatabase()
    local hubs = db and db[0].classHubs
    local hub = hubs and hubs[classId]
    if not hub then return tostring(classId) end
    return (hub.token and NS.L["CLASS_" .. hub.token]) or hub.name or tostring(classId)
end

function Core.ClassNeeds(nodeRanks, snapshot)
    local defs = GetNodeDefs()
    local needs = {}
    if not defs then return needs end
    snapshot = snapshot or Core.GetTreeSnapshot() or EMPTY
    for nodeId, rank in pairs(nodeRanks or EMPTY) do
        local node = defs[nodeId]
        local classId = node and node.classId
        if classId and (snapshot[nodeId] or 0) < rank then needs[classId] = (needs[classId] or 0) + 1 end
    end
    return needs
end

function Core.ClassFits(needs, freeSlots)
    freeSlots = freeSlots or Core.ClassSlots()
    for classId, need in pairs(needs or EMPTY) do
        if need > (freeSlots[classId] or 0) then return false end
    end
    return true
end

function Core.ClassShortage(needs, freeSlots)
    local names
    local ids = Core.GetClassIds()
    for i = 1, #ids do
        local classId = ids[i]
        local need = needs and needs[classId]
        if need and need > ((freeSlots and freeSlots[classId]) or 0) then
            local name = Core.ClassName(classId)
            names = names and (names .. ", " .. name) or name
        end
    end
    return names
end

local function ChainDepth(nodeId)
    local depth, current = 0, nodeId
    while depth < 200 do
        local parents = classParents and classParents[current]
        local parentId = parents and parents[1]
        if not parentId then break end
        depth, current = depth + 1, parentId
    end
    return depth
end

local function OrderClassAdds(adds, before, defs)
    local depthOf = {}
    for i = 1, #adds do depthOf[adds[i]] = ChainDepth(adds[i]) end
    table.sort(adds, function(a, b)
        if depthOf[a] == depthOf[b] then return a < b end
        return depthOf[a] < depthOf[b]
    end)

    local placed, order = {}, {}
    for i = 1, #adds do
        local nodeId = adds[i]
        local ok = defs[nodeId].isStart and true or false
        local parents = classParents and classParents[nodeId]
        for p = 1, (parents and #parents or 0) do
            if ok then break end
            local parentId = parents[p]
            ok = placed[parentId] or (before[parentId] or 0) > 0
        end
        if ok then
            placed[nodeId] = true
            order[#order + 1] = nodeId
        end
    end
    return order
end

local function QueueClassNodes(classTree, skillTree, order, defs)
    for i = 1, #order do
        local nodeId = order[i]
        local amount, currency = NS.Cost.RankCost(defs[nodeId], 1)
        classTree.pending[nodeId] = true
        if amount > 0 then skillTree.PoolAdd(currency, -amount) end
    end
    skillTree.MarkUnsavedChanges()
    skillTree.RefreshTree()
end

local function EncodeBuildCode(nodeRanks)
    local utils = EbonAPI.Ebonhold.Utils()
    if not utils then return nil end

    local list = {}
    for nodeId, rank in pairs(nodeRanks or {}) do
        if rank > 0 then list[#list + 1] = { id = nodeId, rank = rank } end
    end
    if #list == 0 then return nil end
    table.sort(list, function(a, b) return a.id < b.id end)

    local buffer = {}

    local function appendVarInt(value)
        local bytes = utils.EncodeVarInt(value)
        for i = 1, #bytes do buffer[#buffer + 1] = bytes[i] end
    end

    appendVarInt(#list)
    for i = 1, #list do
        appendVarInt(list[i].id)
        buffer[#buffer + 1] = list[i].rank
    end

    return utils.Base64Encode(buffer)
end

function Core.CanActivate()
    local skillTree = EbonAPI.Ebonhold.SkillTree()

    return EbonAPI.Ebonhold.Utils() ~= nil and skillTree ~= nil and skillTree.UpdateTotalSoulPoints ~= nil
end

local ERROR_POPUP = "SKILLTREE_IMPORT_ERROR"

local function HideDialog(which)
    local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
    if dialog then dialog:Hide() end
end

local function ReadRefusal()
    local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible(ERROR_POPUP)
    if not dialog then return nil end

    local shown = dialog.text and dialog.text:GetText()
    local def = StaticPopupDialogs[ERROR_POPUP]
    local text = type(shown) == "string" and shown ~= "" and shown or (def and def.text) or ERROR_POPUP
    dialog:Hide()
    return (EbonAPI.Lib.stripColor(text):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function RunNativeImport(code)
    local button = EbonAPI.Ebonhold.SkillTreeImportButton()
    local onClick = button and button:GetScript("OnClick")
    if not onClick then return Lapse("IMPORT.UNAVAILABLE", { missing = "the import button of the Skill Tree" }) end

    HideDialog(ERROR_POPUP)

    local ok, err = pcall(onClick, button)
    if not ok then return Fail("IMPORT.CRASHED", { part = "the import button", detail = tostring(err) }) end

    HideDialog("SKILLTREE_IMPORT_CODE")

    local popup = StaticPopupDialogs["SKILLTREE_IMPORT_CODE"]
    if not (popup and popup.OnAccept) then
        return Lapse("IMPORT.UNAVAILABLE", { missing = "the import window of the Skill Tree" })
    end

    ok, err = pcall(popup.OnAccept, { editBox = { GetText = function() return code end } })
    if not ok then return Fail("IMPORT.CRASHED", { part = "the import window", detail = tostring(err) }) end

    local refusal = ReadRefusal()
    if refusal then return Fail("IMPORT.REFUSED_BY_PE", { text = refusal }) end

    return true
end

local function MergeInto(target, source, defs)
    for nodeId, rank in pairs(source or {}) do
        local node = defs and defs[nodeId]
        if not (node and node.classId) and rank > 0 and (not target[nodeId] or rank > target[nodeId]) then
            target[nodeId] = rank
        end
    end
    return target
end

local function Describe(list, key)
    local out = {}
    for i = 1, math.min(#list, LISTED_NODES) do out[i] = list[i][key] end
    local text = table.concat(out, ", ")
    if #list > LISTED_NODES then text = text .. ", +" .. (#list - LISTED_NODES) end
    return text
end

local function UnplacedNodes(defs, target, after, saveNodeRanks, before)
    local list = {}
    for nodeId, rank in pairs(target) do
        local read = after[nodeId] or 0
        if defs[nodeId] and read < rank then
            local btn = GetNodeButton(nodeId)
            local origin = saveNodeRanks[nodeId] and "in the save" or before[nodeId] and "in the tree" or "from the server only"
            list[#list + 1] = { id = nodeId, wanted = nodeId .. ":" .. rank, read = nodeId .. ":" .. read,
                state = nodeId .. " " .. ((btn and btn.state) or "without button") .. ", " .. origin }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- Pose les nœuds infinis par le vrai OnClick du bouton natif, un clic par rang manquant.
-- wanted = { [nodeId] = rang visé }. Un rang qui ne progresse plus après un clic (ressource épuisée) arrête
-- ce nœud sans erreur ; bouton ou OnClick absent = IMPORT.UNAVAILABLE ; erreur du clic = IMPORT.CRASHED.
function Core.ApplyInfiniteNodes(wanted)
    local defs = GetNodeDefs()
    if not defs then return Fail("TREE.NOT_READY", { detail = "the talent database is not loaded" }) end

    local ids = {}
    for nodeId in pairs(wanted or {}) do ids[#ids + 1] = nodeId end
    table.sort(ids)

    for _, nodeId in ipairs(ids) do
        local node = defs[nodeId]
        local want = wanted[nodeId]
        local current = node and ReadNodeRank(node) or 0
        if node and current < want then
            local btn = GetNodeButton(nodeId)
            local onClick = btn and btn:GetScript("OnClick")
            if not onClick then
                return Lapse("IMPORT.UNAVAILABLE", { missing = "the button of the infinite node " .. (node.name or nodeId) })
            end

            local clicks = 0
            while current < want and clicks < NS.MAX_RANK do
                local ok, err = pcall(onClick, btn)
                if not ok then
                    return Fail("IMPORT.CRASHED", { part = "the infinite node " .. (node.name or nodeId), detail = tostring(err) })
                end
                clicks = clicks + 1

                local read = ReadNodeRank(node)
                if read <= current then break end
                current = read
            end
        end
    end

    Core.InvalidateSnapshot()
    return true
end

function Core.ApplyBuild(saveNodeRanks)
    local skillTree = EbonAPI.Ebonhold.SkillTree()
    local setSoulAshes = skillTree and skillTree.UpdateTotalSoulPoints
    if not setSoulAshes then return Lapse("IMPORT.UNAVAILABLE", { missing = "UpdateTotalSoulPoints of ProjectEbonhold" }) end
    if type(skillTree.MarkUnsavedChanges) ~= "function" then
        return Lapse("IMPORT.UNAVAILABLE", { missing = "MarkUnsavedChanges of ProjectEbonhold" })
    end

    local defs = GetNodeDefs()
    if not defs then return Fail("TREE.NOT_READY", { detail = "the talent database is not loaded" }) end

    Core.InvalidateSnapshot()

    local before, why = Core.GetTreeSnapshot()
    if not before then return Fail("TREE.NOT_READY", { detail = why }) end

    local cost, _, needs = Core.ComputeActivationPlan(saveNodeRanks, before)
    if not cost then return Fail("TREE.NOT_READY", { detail = "the tree could not be read" }) end

    local serverSpendable, serverCommitted = NS.Bridge.GetServerBalance()
    if not (serverSpendable and serverCommitted) then return Lapse("BALANCE.NOT_RECEIVED", { seconds = NS.Bridge.Waited() }) end

    local budgets = Core.GetBudgets()
    if UnreadableBudget(cost, budgets) then return Lapse("BALANCE.NOT_RECEIVED", { seconds = NS.Bridge.Waited() }) end
    local refusal = NS.Cost.Refusal(cost, budgets)
    if refusal then return nil, refusal end

    local committedNodes = NS.Bridge.GetServerNodes()
    if not committedNodes then
        return Fail("TREE.NOT_READY", { detail = "the server has not announced the active loadout yet" })
    end

    local classAdds = {}
    for nodeId, rank in pairs(saveNodeRanks or {}) do
        local node = defs[nodeId]
        if node and node.classId and rank > (before[nodeId] or 0) then classAdds[#classAdds + 1] = nodeId end
    end

    local classTree, classOrder
    if #classAdds > 0 then
        classTree = ClassTreeService()
        local pools = EbonAPI.Ebonhold.SkillTree()
        if not (classTree and pools and type(pools.PoolAdd) == "function"
            and type(pools.MarkUnsavedChanges) == "function" and type(pools.RefreshTree) == "function") then
            return Lapse("IMPORT.UNAVAILABLE", { missing = "the class constellations of ProjectEbonhold" })
        end

        local shortage = Core.ClassShortage(needs, Core.ClassSlots())
        if shortage then return nil, string.format(NS.L.ERR_CLASS_LEVEL or "class level too low: %s", shortage) end

        classOrder = OrderClassAdds(classAdds, before, defs)
        if #classOrder < #classAdds then
            return nil, NS.L.ERR_CLASS_CHAIN or "a class node of the save is missing its predecessor in the series"
        end
    end

    local target = {}
    MergeInto(target, committedNodes, defs)
    MergeInto(target, before, defs)
    MergeInto(target, saveNodeRanks, defs)

    -- Les nœuds infinis dépassent 255 : le code d'import (un octet par rang) ne peut pas les porter.
    -- Ils sont posés par les clics du bouton natif, après l'import des nœuds normaux.
    local normal, infinite, infiniteCount, normalCount = {}, {}, 0, 0
    for nodeId, rank in pairs(target) do
        local node = defs[nodeId]
        if node and node.infinite then
            infinite[nodeId] = rank
            infiniteCount = infiniteCount + 1
        else
            if rank > NS.MAX_RANK then
                return Fail("IMPORT.RANK_TOO_HIGH", { node = node and node.name or nodeId, rank = rank })
            end
            normal[nodeId] = rank
            normalCount = normalCount + 1
        end
    end

    local added = {}
    for nodeId in pairs(saveNodeRanks or {}) do
        local rank, node = normal[nodeId], defs[nodeId]
        local owned = math.max(before[nodeId] or 0, committedNodes[nodeId] or 0)
        if rank and node and rank > owned then NS.Cost.AddRanks(added, node, owned, rank) end
    end
    if UnreadableBudget(added, budgets) then
        return Lapse("BALANCE.NOT_RECEIVED", { seconds = NS.Bridge.Waited() })
    end
    local available = budgets.ash
    local ashAdded = added.ash or 0
    if available and ashAdded > available then
        return Fail("IMPORT.TOO_EXPENSIVE", { cost = NS.Cost.Format({ ash = ashAdded }), balance = EbonAPI.Format.number(available) })
    end
    local importRefusal = NS.Cost.Refusal(added, budgets)
    if importRefusal then return nil, importRefusal end

    if normalCount > 0 or (infiniteCount == 0 and not classOrder) then
        if not EbonAPI.Ebonhold.Utils() then
            return Lapse("IMPORT.UNAVAILABLE", { missing = "the encoder of ProjectEbonhold" })
        end

        local code = EncodeBuildCode(normal)
        if not code then
            return Fail("IMPORT.CRASHED", { part = "the encoding", detail = "the build holds no node with a rank above 0" })
        end

        local ok, err, problem = RunNativeImport(code)
        if not ok then return nil, err, problem end
    end

    if infiniteCount > 0 then
        local ok, err, problem = Core.ApplyInfiniteNodes(infinite)
        if not ok then return nil, err, problem end
    end

    Core.InvalidateSnapshot()
    local after, afterWhy = Core.GetTreeSnapshot()
    if not after then return Fail("TREE.NOT_READY", { detail = afterWhy }) end

    -- Complétude : les nœuds normaux seulement. Un infini resté sous son rang visé (ressource épuisée)
    -- n'est pas une faute : il garde le rang que la ressource a permis, comme un achat partiel.
    local remainingCost, remaining = Core.ComputeActivationPlan(normal, after)
    if not remainingCost or remaining > 0 then
        local list = UnplacedNodes(defs, normal, after, saveNodeRanks or {}, before)
        return Fail("IMPORT.NODES_NOT_APPLIED", { wanted = Describe(list, "wanted"),
            read = Describe(list, "read"), state = Describe(list, "state") })
    end

    setSoulAshes(serverSpendable, serverCommitted, EbonAPI.State.GetPools())
    skillTree.MarkUnsavedChanges()

    if classOrder then
        QueueClassNodes(classTree, EbonAPI.Ebonhold.SkillTree(), classOrder, defs)

        Core.InvalidateSnapshot()
        local placed, placedWhy = Core.GetTreeSnapshot()
        if not placed then return Fail("TREE.NOT_READY", { detail = placedWhy }) end

        local missing = {}
        for i = 1, #classOrder do
            local nodeId = classOrder[i]
            if (placed[nodeId] or 0) < 1 then missing[#missing + 1] = { id = nodeId, wanted = nodeId .. ":1", read = nodeId .. ":0",
                state = nodeId .. " class node" } end
        end
        if #missing > 0 then
            return Fail("IMPORT.NODES_NOT_APPLIED", { wanted = Describe(missing, "wanted"),
                read = Describe(missing, "read"), state = Describe(missing, "state") })
        end
    end

    return cost
end
