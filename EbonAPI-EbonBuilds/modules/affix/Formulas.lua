EbonBuilds.AffixFormulas = EbonBuilds.AffixFormulas or {}
local Formulas = EbonBuilds.AffixFormulas

local floor, min, max, abs = math.floor, math.min, math.max, math.abs

local function refuse(key)
    return { calculable = false, raison = key }
end

local function ok(inflige, subis)
    return { calculable = true, inflige = inflige, subis = subis, raison = "" }
end

local function sign(effet)
    if effet.s == -1 then
        return -1
    end
    return 1
end

local function applySigned(s, raw)
    local magnitude = floor(abs(raw))
    if raw < 0 then
        return -s * magnitude
    end
    return s * magnitude
end

local function measureReady(mesure)
    return mesure ~= nil and mesure.enough == true
end

local function pct(effet, ctx)
    if effet.k == "journal" then
        return refuse("affix.nc.frequence_absente")
    end
    local mesure = ctx and ctx.mesure
    if not measureReady(mesure) then
        return refuse("affix.nc.pas_de_donnees")
    end
    local s = sign(effet)
    if effet.t == "inflige_pct" then
        return ok(s * floor((mesure.dmg or 0) * effet.v / 100), nil)
    end
    local taken = (mesure.takenPhys or 0) + (mesure.takenMagic or 0)
    return ok(nil, -s * floor(taken * effet.v / 100))
end

local function crit(effet, ctx)
    if effet.k ~= "sans_mesure" then
        return refuse("affix.nc.frequence_absente")
    end
    local mesure = ctx and ctx.mesure
    if not measureReady(mesure) or (mesure.durationMs or 0) <= 0 then
        return refuse("affix.nc.pas_de_donnees")
    end
    if (mesure.crits or 0) == 0 then
        return refuse("affix.nc.pas_de_critique")
    end
    local s = sign(effet)
    local avgCrit = mesure.avgCrit or 0
    if effet.t == "crit_degats" then
        local cpm = floor(mesure.crits * 60000 / mesure.durationMs)
        return ok(s * floor(cpm * avgCrit * effet.v / 100), nil)
    end
    local critPct = mesure.critPct or 0
    local hpm = floor((mesure.hits or 0) * 60000 / mesure.durationMs)
    local pEff
    if s == 1 then
        pEff = min(effet.v, 100 - critPct)
    else
        pEff = min(effet.v, critPct)
    end
    pEff = max(pEff, 0)
    local conv = floor(hpm * pEff / 100)
    return ok(applySigned(s, conv * (avgCrit - (mesure.avgNormal or 0))), nil)
end

local function hate(effet, ctx)
    if effet.k ~= "sans_mesure" then
        return refuse("affix.nc.frequence_absente")
    end
    local stats = ctx and ctx.stats
    if stats == nil then
        return refuse("affix.nc.stats_absentes")
    end
    local mesure = ctx.mesure
    if not measureReady(mesure) then
        return refuse("affix.nc.pas_de_donnees")
    end
    if stats.hastePercent == nil then
        return refuse("affix.nc.stats_absentes")
    end
    local s = sign(effet)
    return ok(s * floor((mesure.dmgSwing or 0) * effet.v / (100 + stats.hastePercent)), nil)
end

local function attackPower(effet, ctx)
    if effet.k ~= "sans_mesure" then
        return refuse("affix.nc.frequence_absente")
    end
    local stats = ctx and ctx.stats
    if stats == nil then
        return refuse("affix.nc.stats_absentes")
    end
    local melee = stats.melee
    local offSpeed = melee and melee.offSpeed
    local weapons = 1
    if offSpeed ~= nil and offSpeed > 0 then
        weapons = 2
    end
    local s = sign(effet)
    return ok(s * floor(effet.v * 60 * weapons / 14), nil)
end

local function spell(effet, ctx)
    if effet.c ~= "infliges" then
        return refuse("affix.nc.hors_degats")
    end
    if not (ctx and ctx.porte) then
        return refuse("affix.nc.non_porte")
    end
    local sorts = ctx.sorts
    local value = effet.sort ~= nil and sorts ~= nil and sorts[effet.sort] or nil
    if value == nil or value <= 0 then
        return refuse("affix.nc.sort_non_mesure")
    end
    return ok(sign(effet) * value, nil)
end

function Formulas.effet(effet, ctx)
    if type(effet) ~= "table" then
        return refuse("affix.nc.type_non_chiffrable")
    end
    local t = effet.t
    if t == "non_chiffrable" or effet.k == "non" then
        return refuse("affix.nc.type_non_chiffrable")
    end
    if t == "soin" then
        return refuse("affix.nc.soin")
    end
    if t == "ressource" then
        return refuse("affix.nc.ressource")
    end
    if t == "vitesse_deplacement" then
        return refuse("affix.nc.deplacement")
    end
    if t == "degats_periodiques" or t == "declenchement" then
        return spell(effet, ctx)
    end
    if effet.v == nil then
        return refuse("affix.nc.valeur_absente")
    end
    if t == "inflige_pct" or t == "subis_pct" then
        return pct(effet, ctx)
    end
    if t == "crit" or t == "crit_degats" then
        return crit(effet, ctx)
    end
    if t == "hate" then
        return hate(effet, ctx)
    end
    if t == "carac_plate" then
        if effet.n == "puissance_attaque" then
            return attackPower(effet, ctx)
        end
        if effet.n == "puissance_sorts" then
            return refuse("affix.nc.puissance_sorts")
        end
        return refuse("affix.nc.caracteristique")
    end
    if t == "carac_pct" then
        return refuse("affix.nc.caracteristique")
    end
    return refuse("affix.nc.type_non_chiffrable")
end

function Formulas.calculer(effets, ctx)
    if type(effets) ~= "table" or #effets == 0 then
        return { calculable = false, raisons = { "affix.nc.valeur_absente" } }
    end
    local inflige, subis = 0, 0
    local raisons = {}
    for i = 1, #effets do
        local r = Formulas.effet(effets[i], ctx)
        if r.calculable then
            inflige = inflige + (r.inflige or 0)
            subis = subis + (r.subis or 0)
        else
            raisons[#raisons + 1] = r.raison
        end
    end
    if #raisons > 0 then
        return { calculable = false, raisons = raisons }
    end
    return { calculable = true, inflige = inflige, subis = subis, raisons = {} }
end
