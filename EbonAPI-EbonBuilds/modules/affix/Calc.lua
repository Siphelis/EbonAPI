EbonBuilds.AffixCalc = EbonBuilds.AffixCalc or {}

local AffixCalc = EbonBuilds.AffixCalc
local cache = {}

local function lireEffet(enchantId)
    local affixes = nil
    if type(EbonAPI) == "table" then
        affixes = EbonAPI.Affixes
    end
    if type(affixes) ~= "table" then
        return nil, false
    end

    local effets = nil
    if type(affixes.GetEffect) == "function" then
        effets = affixes.GetEffect(enchantId)
    end
    if type(effets) ~= "table" then
        effets = nil
    end

    local porte = false
    if type(affixes.GetEquipped) == "function" then
        local equipes = affixes.GetEquipped()
        if type(equipes) == "table" then
            for slot = 1, 19 do
                local piece = equipes[slot]
                if type(piece) == "table" and piece.enchantId == enchantId then
                    porte = true
                    break
                end
            end
        end
    end

    return effets, porte
end

local function lireCaracteristiques()
    if type(EbonAPI) ~= "table" or type(EbonAPI.Character) ~= "table" or type(EbonAPI.Character.GetStats) ~= "function" then
        return nil
    end
    return EbonAPI.Character.GetStats()
end

local function lireMesure(effets)
    local copie = {}
    local meter = EbonBuilds.CombatMeter
    if type(meter) ~= "table" then
        copie.enough = false
        return copie, nil
    end

    if type(meter.Read) == "function" then
        local lue = meter.Read()
        if type(lue) == "table" then
            for cle, valeur in pairs(lue) do
                copie[cle] = valeur
            end
        end
    end

    copie.enough = false
    if type(meter.HasEnoughData) == "function" and meter.HasEnoughData() then
        copie.enough = true
    end

    local sorts = nil
    if type(effets) == "table" and type(meter.ReadSpell) == "function" then
        sorts = {}
        for _, effet in ipairs(effets) do
            if type(effet) == "table" and effet.sort then
                local dmgPerMin = meter.ReadSpell(effet.sort)
                sorts[effet.sort] = dmgPerMin
            end
        end
    end

    return copie, sorts
end

local function Estimer(enchantId)
    if enchantId == nil then
        return nil
    end

    local deja = cache[enchantId]
    if deja then
        return deja
    end

    local formules = EbonBuilds.AffixFormulas
    if type(formules) ~= "table" or type(formules.calculer) ~= "function" then
        return nil
    end

    local effets, porte = lireEffet(enchantId)
    local mesure, sorts = lireMesure(effets)
    local ctx = {
        porte = porte,
        stats = lireCaracteristiques(),
        mesure = mesure,
        sorts = sorts,
    }

    local resultat = formules.calculer(effets, ctx)
    cache[enchantId] = resultat
    return resultat
end

local function Invalidate()
    for cle in pairs(cache) do
        cache[cle] = nil
    end
end

AffixCalc.Estimer = Estimer
AffixCalc.Invalidate = Invalidate
