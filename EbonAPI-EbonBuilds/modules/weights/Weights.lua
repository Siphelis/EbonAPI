EbonBuilds.Weights = {}

local function ResolveBuild(build)
    if type(build) == "table" then return build end
    if build ~= nil then return EbonBuilds.Build.Get(build) end
    return nil
end

function EbonBuilds.Weights.Get(echoName, build)
    local target = ResolveBuild(build)
    local weights
    if build ~= nil then
        weights = target and target.echoWeights
    else
        weights = EbonBuilds.Build.GetActiveWeights()
    end
    local w = weights and weights[echoName]
    if type(w) == "number" then return w end
    local E = EbonAPI and EbonAPI.EchoCatalog
    local names = E and E.Names()
    local entry = names and names[echoName]
    if not entry then return 0 end
    local classToken, spec
    if target then
        classToken, spec = target.class, target.spec
    else
        local active = not EbonBuilds.Draft.isEditing and EbonBuilds.Build.GetActive()
        if active then
            classToken, spec = active.class, active.spec
        end
    end
    classToken = classToken or EbonBuilds.Build.PlayerClassToken()
    spec = spec or EbonBuilds.Build.PlayerTopTalentTab()
    return EbonBuilds.Weights.Default(entry, classToken, spec)
end

function EbonBuilds.Weights.Set(echoName, value, build)
    if type(value) ~= "number" then return end
    local intVal = math.floor(value)
    if intVal < 0 then return end
    local weights
    if build ~= nil then
        local target = ResolveBuild(build)
        if not target then return end
        target.echoWeights = target.echoWeights or {}
        weights = target.echoWeights
    else
        weights = EbonBuilds.Build.GetActiveWeights()
    end
    if not weights then return end
    if weights[echoName] == intVal then return end
    weights[echoName] = intVal
    if EbonBuilds.Automation and EbonBuilds.Automation.ResetPeakCache then
        EbonBuilds.Automation.ResetPeakCache()
    end
end
