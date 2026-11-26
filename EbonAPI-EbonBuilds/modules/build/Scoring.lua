EbonBuilds.Scoring = {}


local NormFamily = EbonBuilds.Const.NormFamily

local function ApplyModifier(score, baseWeight, value, multiplicative)
    if multiplicative then
        if value == 0 then return score end
        return score + baseWeight * (value - 1)
    else
        return score + value
    end
end

local function ApplyFamilyBonuses(s, base, entry, fb, fm, wl)
    local hasWhitelist = false
    for _ in pairs(wl) do hasWhitelist = true; break end

    if entry.families and #entry.families > 0 then
        for i = 1, #entry.families do
            local key = NormFamily(entry.families[i])
            if key and (not hasWhitelist or wl[key]) then
                s = ApplyModifier(s, base, fb[key] or 0, fm[key])
            end
        end
    else
        if not hasWhitelist or wl["No family"] then
            s = ApplyModifier(s, base, fb["No family"] or 0, fm["No family"])
        end
    end
    return s
end

function EbonBuilds.Scoring.ScorePerQuality(entry, weight, settings, quality)
    local qb = settings.qualityBonus or {}
    local qm = settings.qualityBonusMode or {}
    local fb = settings.familyBonus  or {}
    local fm = settings.familyBonusMode or {}
    local wl = settings.banishFamilyWhitelist or {}
    local base = weight or 0
    local s = base

    s = ApplyModifier(s, base, qb[quality] or 0, qm[quality])
    s = ApplyFamilyBonuses(s, base, entry, fb, fm, wl)
    return s
end

function EbonBuilds.Scoring.Score(entry, weight, settings)
    return EbonBuilds.Scoring.ScorePerQuality(entry, weight, settings, entry.quality)
end

local function MatchesClass(entry, bitVal)
    if not bitVal then return true end
    if not entry.classMask or entry.classMask == 0 then return true end
    return bit.band(entry.classMask, bitVal) ~= 0
end

local function WeightOf(weights, name, entry, classToken, spec)
    local w = weights and weights[name]
    if type(w) == "number" then return w end
    if entry then return EbonBuilds.Weights.Default(entry, classToken, spec) end
    return 0
end

EbonBuilds.Scoring.WeightOf = WeightOf

function EbonBuilds.Scoring.ComputePeak(classToken, settings, weights, spec)
    if not settings then return nil, 0 end
    local list = EbonAPI.EchoCatalog.NameList() or {}
    local bitVal = classToken and EbonAPI.EchoCatalog.ClassBit(classToken)
    local bestName, bestScore = nil, nil
    for i = 1, #list do
        local e = list[i]
        if MatchesClass(e, bitVal) then
            local w  = WeightOf(weights, e.name, e, classToken, spec)
            local sc = EbonBuilds.Scoring.Score(e, w, settings)
            if bestScore == nil or sc > bestScore then
                bestScore, bestName = sc, e.name
            end
        end
    end
    return bestName, bestScore or 0
end
