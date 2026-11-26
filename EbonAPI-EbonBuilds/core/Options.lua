EbonBuilds.Options = {}

local L = EbonBuilds.L

local function Settings()
    return EbonAPIEbonBuildsDB.globalSettings
end

function EbonBuilds.Options.Register()
    EbonBuilds.api:Options({
        type = "group",
        name = EbonBuilds.NAME,
        get = function(info) return Settings()[info[#info]] end,
        set = function(info, value) Settings()[info[#info]] = value end,
        args = {
            priorities = {
                type = "description", order = 0, view = "kit",
                name = function() return L.SHELL_TAB_PRIORITIES end,
                build = function(parent, available, visibleHeight)
                    return EbonBuilds.PrioritiesPage.Build(parent, available, visibleHeight)
                end,
            },
        },
    })
end
