EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.Common = EbonBuilds.Pe.Common or {}

local Common = EbonBuilds.Pe.Common

function Common.text(key, fallback)
    local L = EbonBuilds.L
    local value = L and L[key]
    if type(value) == "string" and value ~= "" and value ~= key then
        return value
    end
    return fallback
end

function Common.show(object, flag)
    if flag then object:Show() else object:Hide() end
end
