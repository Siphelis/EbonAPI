local NS = SkillTreeAutoLoad

local Plan = {}
NS.Plan = Plan

local parentsOf, childrenOf, maxRankOf, nodeOf, isStartNode
local chainOf, chainsOfClass

local EMPTY = NS.EMPTY

local function BuildGraph()
    if parentsOf then return true end

    local db = EbonAPI.Ebonhold.TalentDatabase()
    local tree = db and db[0]
    if not (tree and tree.nodes and tree.links) then return false end

    parentsOf, childrenOf, maxRankOf, nodeOf, isStartNode = {}, {}, {}, {}, {}

    for _, node in ipairs(tree.nodes) do
        maxRankOf[node.id] = #(node.spells or {})
        nodeOf[node.id] = node
        if node.isStart then isStartNode[node.id] = true end
    end

    for _, link in ipairs(tree.links) do
        local parentId, childId = link[1], link[2]

        local parents = parentsOf[childId]
        if not parents then
            parents = {}
            parentsOf[childId] = parents
        end
        parents[#parents + 1] = parentId

        local kids = childrenOf[parentId]
        if not kids then
            kids = {}
            childrenOf[parentId] = kids
        end
        kids[#kids + 1] = childId
    end

    chainOf, chainsOfClass = {}, {}
    local startsOfClass = {}
    for _, node in ipairs(tree.nodes) do
        if node.isStart and node.classId then
            local list = startsOfClass[node.classId]
            if not list then
                list = {}
                startsOfClass[node.classId] = list
            end
            list[#list + 1] = node.id
        end
    end
    for classId, starts in pairs(startsOfClass) do
        table.sort(starts)
        local chains = {}
        for k = 1, #starts do
            local members, stack = {}, { starts[k] }
            while #stack > 0 do
                local nodeId = stack[#stack]
                stack[#stack] = nil
                if not chainOf[nodeId] then
                    chainOf[nodeId] = k
                    members[#members + 1] = nodeId
                    local kids = childrenOf[nodeId]
                    for i = 1, (kids and #kids or 0) do stack[#stack + 1] = kids[i] end
                end
            end
            chains[k] = members
        end
        chainsOfClass[classId] = chains
    end

    return true
end

local function NextCost(nodeId, rank)
    return NS.Cost.RankCost(nodeOf[nodeId], rank + 1)
end

function Plan.ComputeMissing(targets, snapshot)
    local missing, count = {}, 0
    snapshot = snapshot or EMPTY

    for nodeId, targetRank in pairs(targets or EMPTY) do
        if (snapshot[nodeId] or 0) < targetRank then
            missing[nodeId] = targetRank
            count = count + 1
        end
    end

    return missing, count
end

local function PushLinked(linked, set, seen, stack)
    for i = 1, (linked and #linked or 0) do
        local nodeId = linked[i]
        if set[nodeId] and not seen[nodeId] then
            seen[nodeId] = true
            stack[#stack + 1] = nodeId
        end
    end
end

function Plan.LargestGroup(set)
    if not BuildGraph() then return set end

    local seen, best, bestSize = {}, set, 0
    for startId in pairs(set) do
        if not seen[startId] then
            seen[startId] = true
            local group, size, stack = {}, 0, { startId }

            while #stack > 0 do
                local nodeId = stack[#stack]
                stack[#stack] = nil
                group[nodeId] = set[nodeId]
                size = size + 1
                PushLinked(parentsOf[nodeId], set, seen, stack)
                PushLinked(childrenOf[nodeId], set, seen, stack)
            end

            if size > bestSize then best, bestSize = group, size end
        end
    end

    return best
end

function Plan.ComputeProgress(targets, snapshot)
    if not BuildGraph() then return nil end

    snapshot = snapshot or EMPTY
    local ownedCost, totalCost, ownedNodes, totalNodes = {}, {}, 0, 0

    for nodeId, targetRank in pairs(targets or EMPTY) do
        if maxRankOf[nodeId] then
            local node = nodeOf[nodeId]
            local currentRank = snapshot[nodeId] or 0
            if currentRank > targetRank then currentRank = targetRank end

            NS.Cost.AddRanks(totalCost, node, 0, targetRank)
            NS.Cost.AddRanks(ownedCost, node, 0, currentRank)

            totalNodes = totalNodes + 1
            if currentRank >= targetRank then ownedNodes = ownedNodes + 1 end
        end
    end

    return ownedCost, totalCost, ownedNodes, totalNodes
end

local function HeapPush(costs, ids, size, cost, id)
    size = size + 1

    local i = size
    while i > 1 do
        local up = math.floor(i / 2)
        local upCost, upId = costs[up], ids[up]
        if upCost < cost or (upCost == cost and upId < id) then break end
        costs[i], ids[i] = upCost, upId
        i = up
    end

    costs[i], ids[i] = cost, id
    return size
end

local function HeapPop(costs, ids, size)
    local topCost, topId = costs[1], ids[1]
    local holdCost, holdId = costs[size], ids[size]

    costs[size], ids[size] = nil, nil
    size = size - 1

    if size > 0 then
        local i = 1
        while true do
            local down = i * 2
            if down > size then break end

            local right = down + 1
            if right <= size then
                local leftCost, leftId = costs[down], ids[down]
                local rightCost, rightId = costs[right], ids[right]
                if rightCost < leftCost or (rightCost == leftCost and rightId < leftId) then
                    down = right
                end
            end

            local downCost, downId = costs[down], ids[down]
            if holdCost < downCost or (holdCost == downCost and holdId < downId) then break end
            costs[i], ids[i] = downCost, downId
            i = down
        end
        costs[i], ids[i] = holdCost, holdId
    end

    return topCost, topId, size
end

local wipe = NS.wipe

local goals, waiting = {}, {}
local heapCosts, heapIds = {}, {}

local function ClassifyNode(nodeId, snapshot)
    if isStartNode[nodeId] then return true end

    local parents = parentsOf[nodeId]
    if not parents then return false end

    local unmet = 0
    for i = 1, #parents do
        local parentId = parents[i]
        local parentMax = maxRankOf[parentId] or 0

        if parentMax == 0 then return false end

        if (snapshot[parentId] or 0) < parentMax then
            if goals[parentId] ~= parentMax then return false end
            unmet = unmet + 1
        end
    end

    if unmet == 0 then return true end

    waiting[nodeId] = unmet
    return false
end

function Plan.ComputeProgressive(targets, snapshot, budgets)
    if not BuildGraph() then return nil end

    snapshot = snapshot or EMPTY
    wipe(goals)
    wipe(waiting)
    wipe(heapCosts)
    wipe(heapIds)

    for nodeId, targetRank in pairs(targets or EMPTY) do
        local maxRank = maxRankOf[nodeId]
        if maxRank then
            local goal = (targetRank > maxRank) and maxRank or targetRank
            if (snapshot[nodeId] or 0) < goal then goals[nodeId] = goal end
        end
    end

    local heapSize = 0

    for nodeId in pairs(goals) do
        if ClassifyNode(nodeId, snapshot) then
            heapSize = HeapPush(heapCosts, heapIds, heapSize,
                (NextCost(nodeId, snapshot[nodeId] or 0)), nodeId)
        end
    end

    local remaining = {}
    for currency, amount in pairs(budgets or EMPTY) do remaining[currency] = amount end

    local free = {}
    for classId, slots in pairs(NS.Core.ClassSlots()) do free[classId] = slots end

    local chosen, chosenCount, spent, blocked = {}, 0, {}, nil

    local specClass, specChain, specRemaining, deferred = nil, nil, 0, {}
    local specTab = NS.Core.SpecTab and NS.Core.SpecTab()
    local playerClassId = specTab and NS.Core.PlayerClassId and NS.Core.PlayerClassId()
    local chains = playerClassId and chainsOfClass[playerClassId]
    local members = chains and chains[specTab]
    if members then
        specClass, specChain = playerClassId, specTab
        for i = 1, #members do
            if goals[members[i]] then specRemaining = specRemaining + 1 end
        end
    end

    while heapSize > 0 do
        local _, nodeId
        _, nodeId, heapSize = HeapPop(heapCosts, heapIds, heapSize)

        local newRank = (chosen[nodeId] or snapshot[nodeId] or 0) + 1
        local cost, currency = NS.Cost.RankCost(nodeOf[nodeId], newRank)
        local classId = nodeOf[nodeId].classId
        local needsSlot = classId ~= nil and newRank == 1

        if needsSlot and classId == specClass and specRemaining > 0 and chainOf[nodeId] ~= specChain then
            deferred[#deferred + 1] = nodeId
        elseif needsSlot and (free[classId] or 0) < 1 then
            -- aucun emplacement libre pour cette classe : le nœud reste hors du lot
        elseif cost > (remaining[currency] or 0) then
            blocked = blocked or {}
            if not blocked[currency] or cost < blocked[currency] then blocked[currency] = cost end
        else
            if not chosen[nodeId] then chosenCount = chosenCount + 1 end
            if needsSlot then free[classId] = free[classId] - 1 end
            chosen[nodeId] = newRank
            remaining[currency] = (remaining[currency] or 0) - cost
            spent[currency] = (spent[currency] or 0) + cost

            if newRank < goals[nodeId] then
                heapSize = HeapPush(heapCosts, heapIds, heapSize,
                    (NextCost(nodeId, newRank)), nodeId)
            end

            if specRemaining > 0 and classId == specClass and chainOf[nodeId] == specChain and newRank >= goals[nodeId] then
                specRemaining = specRemaining - 1
                if specRemaining == 0 then
                    for i = 1, #deferred do
                        local deferredId = deferred[i]
                        heapSize = HeapPush(heapCosts, heapIds, heapSize,
                            (NextCost(deferredId, chosen[deferredId] or snapshot[deferredId] or 0)), deferredId)
                    end
                end
            end

            if newRank >= (maxRankOf[nodeId] or 0) then
                local kids = childrenOf[nodeId]
                for i = 1, (kids and #kids or 0) do
                    local childId = kids[i]
                    local unmet = waiting[childId]
                    if unmet then
                        unmet = unmet - 1
                        if unmet > 0 then
                            waiting[childId] = unmet
                        else
                            waiting[childId] = nil
                            heapSize = HeapPush(heapCosts, heapIds, heapSize,
                                (NextCost(childId, chosen[childId] or snapshot[childId] or 0)), childId)
                        end
                    end
                end
            end
        end
    end

    return chosen, spent, chosenCount, blocked
end

-- Ancêtres (transitifs, nœuds de départ exclus) des nœuds de `nodeRanks` qui n'y figurent pas,
-- avec leur rang max. Renvoie nil si l'arbre n'est pas encore chargé. Sert aux presets :
-- un nœud ne s'active que si ses parents sont au rang max (ClassifyNode).
function Plan.Ancestors(nodeRanks)
    if not BuildGraph() then return nil end

    local added, count = {}, 0
    local seen, stack = {}, {}
    for nodeId in pairs(nodeRanks or EMPTY) do
        seen[nodeId] = true
        stack[#stack + 1] = nodeId
    end

    while #stack > 0 do
        local nodeId = stack[#stack]
        stack[#stack] = nil

        local parents = parentsOf[nodeId]
        for i = 1, (parents and #parents or 0) do
            local parentId = parents[i]
            if not seen[parentId] then
                seen[parentId] = true
                if not isStartNode[parentId] then
                    added[parentId] = maxRankOf[parentId] or 0
                    count = count + 1
                    stack[#stack + 1] = parentId
                end
            end
        end
    end

    return added, count
end
