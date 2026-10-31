local NS = SkillTreeAutoLoad

local Core = {}
NS.Core = Core

local byte = string.byte
local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end

local nodeDefsById, spellCountById
local nodeButtons = {}
local warnedMultiChoice = false
local buttonsReady = false
local snapshotCache, snapshotTime, snapshotCount
local snapshotDirty = true
local snapshotStamp = 0
local scratch = {}
local ashesBad, inconsistent = false, false
local LISTED_NODES = 8
local MAX_RANK = 255

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
    nodeDefsById, spellCountById = {}, {}
    for _, node in ipairs(db[0].nodes) do
        nodeDefsById[node.id] = node
        spellCountById[node.id] = node.spells and #node.spells or 0
    end
    return nodeDefsById
end

function Core.GetNodeDefs()
    return GetNodeDefs()
end

local function GetNodeButton(nodeId)
    local btn = nodeButtons[nodeId]
    if btn then return btn end
    btn = _G["skillTreeNode" .. nodeId]
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

local function ReadNodeRank(node)
    if node.isMultipleChoice then
        WarnMultiChoice(node)
        return 0
    end

    local btn = GetNodeButton(node.id)
    if not btn or btn.state == "locked" then return 0 end

    if node.infinite then
        local badge = btn.stackBadge
        if not (badge and badge:IsShown()) then return 0 end
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

local function ParseSoulAshes(text)
    text = EbonAPI.Lib.stripColor(text)

    local sign, numberPart = text:match("(%-?)([%d][%d%s,%.]*)%s*$")
    if not numberPart then return nil end

    local digits = numberPart:gsub("%D", "")
    if digits == "" then return nil end

    local value = tonumber(digits)
    if not value then return nil end

    return (sign == "-") and -value or value
end

local ashesText, ashesValue

function Core.GetAvailableSoulAshes()
    local frame = EbonAPI.Ebonhold.SkillTreeFrame()
    local fs = frame and frame.pointsText
    if not fs then return nil end

    local text = fs:GetText()
    if type(text) ~= "string" or text == "" then return nil end

    if text ~= ashesText then
        ashesText, ashesValue = text, ParseSoulAshes(text)
        if ashesValue then
            if ashesBad then
                ashesBad = false
                NS.api:Restore("ASHES.UNREADABLE")
            end
        else
            ashesBad = true
            Lapse("ASHES.UNREADABLE", { text = EbonAPI.Lib.stripColor(text) })
        end
    end
    return ashesValue
end

local INFINITE_RANK_COST_CAP = 100000000

local function RankCost(node, rank)
    local costs = node.soulPointsCosts or {}
    if not node.infinite then return costs[rank] or 0 end

    local base = math.max(costs[1] or 1, 1)
    local cost = math.ceil(base * (node.infiniteGrowth or 1.15) ^ (rank - 1) - 0.000001)
    if cost >= INFINITE_RANK_COST_CAP then return INFINITE_RANK_COST_CAP end
    return math.max(cost, 1)
end

function Core.ComputeActivationPlan(saveNodeRanks, snapshot)
    local defs = GetNodeDefs()
    if not defs then return nil end

    snapshot = snapshot or Core.GetTreeSnapshot()
    if not snapshot then return nil end

    local totalCost, pendingNodes = 0, 0

    for nodeId, targetRank in pairs(saveNodeRanks or {}) do
        local node = defs[nodeId]
        if node then
            local currentRank = snapshot[nodeId] or 0
            if currentRank < targetRank then
                for rankIdx = currentRank + 1, targetRank do
                    totalCost = totalCost + RankCost(node, rankIdx)
                end
                pendingNodes = pendingNodes + 1
            end
        end
    end

    return totalCost, pendingNodes
end

function Core.GetEffectiveSpendable()
    local spendable = NS.Bridge.GetServerBalance()
    if not spendable then return Lapse("BALANCE.NOT_RECEIVED", { seconds = NS.Bridge.Waited() }) end

    local committedNodes = NS.Bridge.GetServerNodes()
    if not committedNodes then
        return Fail("TREE.NOT_READY", { detail = "the server has not announced the active loadout yet" })
    end

    local snapshot, why = Core.GetTreeSnapshot()
    if not snapshot then return Fail("TREE.NOT_READY", { detail = why }) end

    local pendingCost = Core.ComputeActivationPlan(snapshot, committedNodes)
    if not pendingCost then return Fail("TREE.NOT_READY", { detail = "the tree could not be read" }) end

    local gap = 0
    for nodeId, committedRank in pairs(committedNodes) do
        if (snapshot[nodeId] or 0) < committedRank then gap = gap + 1 end
    end

    local effective = spendable - pendingCost
    if gap > 0 or effective < 0 then
        inconsistent = true
        Lapse("BALANCE.INCONSISTENT", { balance = EbonAPI.Format.number(spendable),
            cost = EbonAPI.Format.number(pendingCost), nodes = gap })
        if effective < 0 then effective = 0 end
    elseif inconsistent then
        inconsistent = false
        NS.api:Restore("BALANCE.INCONSISTENT")
    end

    return effective
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

local function CountKnownRanks(defs, nodeRanks)
    local total = 0
    for nodeId, rank in pairs(nodeRanks or {}) do
        if defs[nodeId] then total = total + rank end
    end
    return total
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

local function MergeInto(target, source)
    for nodeId, rank in pairs(source or {}) do
        if rank > 0 and (not target[nodeId] or rank > target[nodeId]) then
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
    NS.View.ClearFaults()
    local skillTree = EbonAPI.Ebonhold.SkillTree()
    local setSoulAshes = skillTree and skillTree.UpdateTotalSoulPoints
    if not setSoulAshes then return Lapse("IMPORT.UNAVAILABLE", { missing = "UpdateTotalSoulPoints of ProjectEbonhold" }) end

    local defs = GetNodeDefs()
    if not defs then return Fail("TREE.NOT_READY", { detail = "the talent database is not loaded" }) end

    Core.InvalidateSnapshot()

    local before, why = Core.GetTreeSnapshot()
    if not before then return Fail("TREE.NOT_READY", { detail = why }) end

    local cost = Core.ComputeActivationPlan(saveNodeRanks, before)
    if not cost then return Fail("TREE.NOT_READY", { detail = "the tree could not be read" }) end

    local _, serverCommitted = NS.Bridge.GetServerBalance()
    if not serverCommitted then return Lapse("BALANCE.NOT_RECEIVED", { seconds = NS.Bridge.Waited() }) end

    local committedNodes = NS.Bridge.GetServerNodes()
    if not committedNodes then
        return Fail("TREE.NOT_READY", { detail = "the server has not announced the active loadout yet" })
    end

    local target = {}
    MergeInto(target, committedNodes)
    MergeInto(target, before)
    MergeInto(target, saveNodeRanks)

    -- Les nœuds infinis dépassent 255 : le code d'import (un octet par rang) ne peut pas les porter.
    -- Ils sont posés par les clics du bouton natif, après l'import des nœuds normaux.
    local normal, infinite, infiniteCount, normalCount = {}, {}, 0, 0
    for nodeId, rank in pairs(target) do
        local node = defs[nodeId]
        if node and node.infinite then
            infinite[nodeId] = rank
            infiniteCount = infiniteCount + 1
        else
            if rank > MAX_RANK then
                return Fail("IMPORT.RANK_TOO_HIGH", { node = node and node.name or nodeId, rank = rank })
            end
            normal[nodeId] = rank
            normalCount = normalCount + 1
        end
    end

    -- Le total des rangs ne compte que les nœuds normaux : un rang infini élevé n'est pas un prix d'import.
    local available = Core.GetAvailableSoulAshes()
    local rankTotal = CountKnownRanks(defs, normal)
    if available and rankTotal > available then
        return Fail("IMPORT.TOO_EXPENSIVE", { ranks = rankTotal, balance = EbonAPI.Format.number(available) })
    end

    if normalCount > 0 or infiniteCount == 0 then
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
    local _, remaining = Core.ComputeActivationPlan(normal, after)
    if not remaining or remaining > 0 then
        local list = UnplacedNodes(defs, normal, after, saveNodeRanks or {}, before)
        return Fail("IMPORT.NODES_NOT_APPLIED", { wanted = Describe(list, "wanted"),
            read = Describe(list, "read"), state = Describe(list, "state") })
    end

    local effective, _, balanceProblem = Core.GetEffectiveSpendable()
    if effective then
        setSoulAshes(effective, serverCommitted)
    else
        Fail("BALANCE.NOT_REFRESHED", {}, balanceProblem)
    end

    return cost
end
