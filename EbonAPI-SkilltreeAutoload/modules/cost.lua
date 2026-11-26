local NS = SkillTreeAutoLoad

local Cost = {}
NS.Cost = Cost

local ceil, max = math.ceil, math.max

local INFINITE_RANK_COST_CAP = 100000000

local CURRENCIES = {
    { key = "ash", name = "Ashes" },
    { key = "shard", name = "Shards" },
    { key = "essence", name = "Essence" },
    { key = "artisan", name = "Artisan" },
}

Cost.CURRENCIES = CURRENCIES

function Cost.Name(key)
    local L = NS.L
    local localized = L and L["CURRENCY_" .. key:upper()]
    if localized then return localized end
    for i = 1, #CURRENCIES do
        if CURRENCIES[i].key == key then return CURRENCIES[i].name end
    end
    return key
end

function Cost.RankCost(node, rank)
    local currency = node.currency or "ash"
    local costs = node.soulPointsCosts
    if not costs then return 0, currency end

    if node.infinite then
        local cost = ceil(max(costs[1] or 1, 1) * (node.infiniteGrowth or 1.15) ^ (rank - 1) - 0.000001)
        if cost >= INFINITE_RANK_COST_CAP then return INFINITE_RANK_COST_CAP, currency end
        return max(cost, 1), currency
    end

    return costs[rank] or costs[#costs] or 0, currency
end

function Cost.AddRanks(sum, node, fromRank, toRank)
    for rank = fromRank + 1, toRank do
        local cost, currency = Cost.RankCost(node, rank)
        sum[currency] = (sum[currency] or 0) + cost
    end
    return sum
end

function Cost.Format(sum, separator)
    local parts = {}
    for i = 1, #CURRENCIES do
        local key = CURRENCIES[i].key
        local amount = sum and sum[key]
        if amount and amount > 0 then
            parts[#parts + 1] = EbonAPI.Format.number(amount) .. " " .. Cost.Name(key)
        end
    end
    if #parts == 0 then return EbonAPI.Format.number(0) end
    return table.concat(parts, separator or "  "), #parts
end

function Cost.Shortfall(sum, budgets)
    local missing
    for currency, amount in pairs(sum or {}) do
        local short = amount - ((budgets and budgets[currency]) or 0)
        if amount > 0 and short > 0 then
            missing = missing or {}
            missing[currency] = short
        end
    end
    return missing
end

function Cost.Fits(sum, budgets)
    return budgets ~= nil and Cost.Shortfall(sum, budgets) == nil
end

function Cost.Refusal(sum, budgets)
    local short = Cost.Shortfall(sum, budgets)
    if not short then return nil end
    local L = NS.L
    return string.format((L and L.ERR_NOT_ENOUGH) or "Not enough: %s", Cost.Format(short))
end

local function Spendable(entry)
    if type(entry) ~= "table" then return nil end
    local value = entry.spendable
    if type(value) == "number" then return value end
    return nil
end

function Cost.Budgets()
    local state = EbonAPI and EbonAPI.State
    if not (state and state.GetAsh and state.GetPools) then return nil end

    local budgets = {}
    budgets.ash = Spendable(state.GetAsh())

    local pools = state.GetPools()
    if type(pools) == "table" then
        budgets.shard = Spendable(pools.shard)
        budgets.essence = Spendable(pools.essence)
        budgets.artisan = Spendable(pools.artisan)
    end

    -- Achats en attente chez PE (déjà retirés de l'affichage de PE, pas des soldes serveur) :
    -- nœuds de classe mis en attente, nœuds communs posés au-dessus de la sauvegarde serveur.
    local defs = NS.Core.GetNodeDefs()
    local classTree = ProjectEbonhold and ProjectEbonhold.ClassTree
    local pendingClass = classTree and type(classTree.pending) == "table" and classTree.pending
    local committed = NS.Bridge and NS.Bridge.GetServerNodes()
    local snapshot = committed and NS.Core.GetTreeSnapshot()
    if defs then
        local owed = {}
        for nodeId in pairs(pendingClass or {}) do
            local node = defs[nodeId]
            if node then Cost.AddRanks(owed, node, 0, 1) end
        end
        for nodeId, rank in pairs(snapshot or {}) do
            local node = defs[nodeId]
            local floor = committed[nodeId] or 0
            if node and not node.classId and rank > floor then Cost.AddRanks(owed, node, floor, rank) end
        end
        for currency, amount in pairs(owed) do
            if budgets[currency] then budgets[currency] = budgets[currency] - amount end
        end
    end

    return budgets
end
