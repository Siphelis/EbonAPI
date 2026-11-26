EbonBuilds = EbonBuilds or {}

local floor = math.floor
local format = string.format
local pairs = pairs
local tostring = tostring

local Controls = {}
EbonBuilds.PrioritiesControls = Controls

local LOCKED_SLOTS = 5

local function resolveBuild(build)
    if type(build) == "table" then return build end
    if build ~= nil then return EbonBuilds.Build.Get(build) end
    return nil
end

function Controls.Settings(build)
    local target = build ~= nil and resolveBuild(build) or (build == nil and EbonBuilds.Build.GetActive())
    return target and target.settings
end

local function writable(build)
    if build ~= nil then
        local target = resolveBuild(build)
        if not target then return nil, nil end
        EbonBuilds.Build.EnsureSettings(target)
        return target.settings, target
    end
    return Controls.Settings(), nil
end

function Controls.Persist()
    local build = EbonBuilds.Build.GetActive()
    if not build then return end
    EbonBuilds.Build.Save(build.id, { settings = build.settings })
end

function Controls.IsBanned(entry, list)
    for _, spellId in pairs(entry.spellIds or { entry.spellId }) do
        if list[spellId] then return true end
    end
    return false
end

local function write(container, key, value, build)
    container[key] = value
    if build then
        EbonBuilds.Build.Save(build.id, { settings = build.settings })
    else
        Controls.Persist()
    end
end

function Controls.Quantise(entry, value)
    if entry.absolute then return floor(value * 10 + 0.5) / 10 end
    return floor(value + 0.5)
end

function Controls.FormatThreshold(entry, v)
    if entry.absolute then return format("%+.2f", v) end
    return v .. "%"
end

function Controls.ThresholdValue(entry, build)
    local value = Controls.Settings(build)[entry.key]
    if value == nil then value = entry.absolute and entry.min or 0 end
    return value
end

function Controls.ApplyWeight(entry, value)
    if not entry then return nil end
    local api = EbonBuilds.api
    if not (value and floor(value) == value and value >= 0) then
        if api then api:Report(api:Problem("TABLE.WEIGHT_INVALID", { echo = entry.name, value = tostring(value) })) end
        return "invalid"
    elseif EbonBuilds.Build.GetActive() == nil then
        if api then api:Report(api:Problem("TABLE.WEIGHT_NOT_SAVED", { echo = entry.name, value = tostring(value) })) end
        return "nobuild"
    end
    EbonBuilds.Weights.Set(entry.name, value)
    return "ok"
end

function Controls.ToggleBan(entry, target)
    local build = target or EbonBuilds.Build.GetActive()
    if not build or not entry or not entry.spellId then return false end
    EbonBuilds.Build.EnsureSettings(build)
    local locked = build.lockedEchoes or {}
    for _, spellId in pairs(entry.spellIds or { entry.spellId }) do
        for i = 1, LOCKED_SLOTS do
            if locked[i] == spellId then return false end
        end
    end
    local list = build.settings.echoBanList
    local was = false
    for _, spellId in pairs(entry.spellIds or { entry.spellId }) do
        if list[spellId] then
            was = true
            list[spellId] = nil
        end
    end
    if not was then list[entry.spellId] = entry.name end
    if target then
        EbonBuilds.Build.Save(target.id, { settings = target.settings })
    else
        Controls.Persist()
    end
    return true
end

function Controls.SetQualityBonus(q, v)
    write(Controls.Settings().qualityBonus, q, v)
end

function Controls.SetQualityBonusMode(q, v)
    write(Controls.Settings().qualityBonusMode, q, v)
end

function Controls.SetFamilyBonus(family, v)
    write(Controls.Settings().familyBonus, family, v)
end

function Controls.SetFamilyBonusMode(family, v)
    write(Controls.Settings().familyBonusMode, family, v)
end

function Controls.ToggleAutomation(build)
    local target
    if build ~= nil then target = resolveBuild(build) else target = EbonBuilds.Build.GetActive() end
    if not target then return false end
    target.automationEnabled = not target.automationEnabled
    return true
end

function Controls.ToggleScoreSource(build)
    local settings, target = writable(build)
    write(settings, "scoreSource", (settings.scoreSource == "weights") and "matrix" or "weights", target)
end

function Controls.ToggleBanAllMode(build)
    local settings, target = writable(build)
    write(settings, "echoBanAllMode", (settings.echoBanAllMode or "highestScore") == "highestScore" and "random" or "highestScore", target)
end

function Controls.SetFamilyProtected(family, value, build)
    local settings, target = writable(build)
    settings.banishFamilyWhitelist = settings.banishFamilyWhitelist or {}
    write(settings.banishFamilyWhitelist, family, value and true or nil, target)
end

function Controls.SetThreshold(entry, value, target)
    if target then
        local build = resolveBuild(target)
        if not build then return false end
        EbonBuilds.Build.EnsureSettings(build)
        write(build.settings, entry.key, Controls.Quantise(entry, value), build)
        return
    end
    write(Controls.Settings(), entry.key, Controls.Quantise(entry, value))
end

function Controls.AddBan(spellId, name, target)
    local current, build
    if target then
        build = resolveBuild(target)
        if not build then return false end
        EbonBuilds.Build.EnsureSettings(build)
        current = build.settings
    else
        current = Controls.Settings()
    end
    if not current then return false end
    current.echoBanList = current.echoBanList or {}
    write(current.echoBanList, spellId, name, build)
    return true
end

function Controls.RemoveBan(spellId, target)
    local settings, build
    if target then
        build = resolveBuild(target)
        if not build then return false end
        EbonBuilds.Build.EnsureSettings(build)
        settings = build.settings
    else
        settings = Controls.Settings()
        if not settings then
            EbonAPI.Log.trace("fail", "EbonBuilds", "PrioritiesControls.RemoveBan", "no build")
            return false
        end
    end
    local list = settings.echoBanList
    if list and spellId then
        write(list, spellId, nil, build)
        return true
    end
    return false
end
