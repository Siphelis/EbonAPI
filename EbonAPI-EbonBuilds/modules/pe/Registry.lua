EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.Registry = EbonBuilds.Pe.Registry or {}

local Registry = EbonBuilds.Pe.Registry

local screens = {}
local screenOrder = {}
local floats = {}
local floatFrames = {}

local function validEntry(key, def)
    return type(key) == "string" and type(def) == "table"
end

function Registry.RegisterScreen(key, def)
    if not validEntry(key, def) or screens[key] then
        return false
    end
    screens[key] = def
    table.insert(screenOrder, key)
    return true
end

function Registry.GetScreen(key)
    return screens[key]
end

function Registry.ScreenKeys()
    local list = {}
    for i = 1, #screenOrder do
        list[i] = screenOrder[i]
    end
    return list
end

function Registry.RegisterFloat(key, def)
    if not validEntry(key, def) or floats[key] then
        return false
    end
    floats[key] = def
    return true
end

function Registry.OpenFloat(key)
    local def = floats[key]
    if not def then
        return false
    end
    local frame = floatFrames[key]
    if not frame and def.build then
        frame = def.build(UIParent)
        floatFrames[key] = frame
    end
    if frame then
        frame:Show()
    end
    return true
end
