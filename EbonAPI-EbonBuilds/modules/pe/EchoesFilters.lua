EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.EchoesFilters = EbonBuilds.Pe.EchoesFilters or {}

local Filters = EbonBuilds.Pe.EchoesFilters

local ALL_KEY = "all"
local FAMILY_COUNT = 6

local TOMES_CHOICES = {
    { ALL_KEY, "ECH_RA_TOMES_ALL", "All echoes" },
    { "tome", "ECH_RA_TOMES_TOME", "Tomes only" },
    { "tomeKnown", "ECH_RA_TOMES_KNOWN", "Known tomes only" },
    { "enabled", "ECH_RA_TOMES_ENABLED", "Enabled only" },
    { "disabled", "ECH_RA_TOMES_DISABLED", "Disabled only" },
}

local QUALITIES = {
    { 0, "Common", "ECH_RA_RARITY_COMMON" },
    { 1, "Uncommon", "ECH_RA_RARITY_UNCOMMON" },
    { 2, "Rare", "ECH_RA_RARITY_RARE" },
    { 3, "Epic", "ECH_RA_RARITY_EPIC" },
}

local column
local frame
local onChangeHook
local familyKeys = {}
local specClass = {}
local defaultsApplied = false
local entryCache = { byId = {} }
local extra = { wished = false, banned = false }

local text = EbonBuilds.Pe.Common.text

local function notify()
    if onChangeHook then onChangeHook() end
end

local function familyName(key)
    return EbonBuilds.FamilyName(key)
end

local function entryFor(spellId)
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    local database = catalog and catalog.Database and catalog.Database()
    if type(database) ~= "table" then return nil end
    if entryCache.source ~= database then
        entryCache = { source = database, byId = {} }
    end
    local cached = entryCache.byId[spellId]
    if cached then return cached end
    local data = database[spellId]
    local name = type(data) == "table" and GetSpellInfo(spellId)
    if not name then return nil end
    local entry = {
        spellId = spellId,
        name = name,
        lname = name:lower(),
        quality = tonumber(data.quality) or 0,
        classMask = data.classMask or 0,
        families = data.families or {},
        tome = data.isTome == true,
    }
    entryCache.byId[spellId] = entry
    return entry
end

local function passes(spellId)
    local entry = entryFor(spellId)
    return entry ~= nil and #EbonBuilds.EchoFilter.Apply({ entry }) > 0 and Filters.PassesExtra(spellId)
end

local function publish()
    local pilot = EbonAPI and EbonAPI.JournalPilot
    if not (pilot and pilot.SetFilter) then return end
    pilot.SetFilter(passes)
    if pilot.Refresh then pilot.Refresh() end
end

function Filters.Extra()
    return extra.wished, extra.banned
end

function Filters.PassesExtra(spellId)
    if not (extra.wished or extra.banned) then return true end
    if extra.wished and EbonBuilds.Wishlist.Has(spellId) then return true end
    if extra.banned then
        local build = EbonBuilds.Build.GetActive()
        local list = build and build.settings and build.settings.echoBanList
        if list and list[spellId] then return true end
    end
    return false
end

local function setFilter(key, value)
    EbonBuilds.EchoFilter.Set(key, value)
    if frame and frame:IsShown() then publish() end
end

local function countKeys(set)
    local count = 0
    for _ in pairs(set) do count = count + 1 end
    return count
end

local function commitSet(key, set, total)
    if countKeys(set) >= total then
        set = {}
    end
    setFilter(key, set)
end

local function effectiveSet(current, all)
    local set = {}
    if next(current) == nil then
        for i = 1, #all do set[all[i]] = true end
    else
        for k, v in pairs(current) do set[k] = v end
    end
    return set
end

local function playerClass()
    local _, token = UnitClass("player")
    return token
end

local function selectMine()
    local token = playerClass()
    setFilter("classes", token and { [token] = true } or {})
end

local function pruneSpecs(state, token)
    local pruned = false
    for key in pairs(state.specs) do
        if specClass[key] ~= token then
            state.specs[key] = nil
            pruned = true
        end
    end
    if pruned then setFilter("specs", state.specs) end
end

local function resetState()
    extra.wished = false
    extra.banned = false
    EbonBuilds.EchoFilter.Reset()
    selectMine()
    setFilter("myClass", true)
end

local function classItems()
    local classes = EbonAPI.ClientData.Classes()
    local items = {}
    for i = 1, #classes do
        local token = classes[i].token
        items[i] = { token = token, name = function() return EbonAPI.ClientData.Class(token).name end }
        for index = 1, #classes[i].specs do
            specClass[classes[i].specs[index].key] = token
        end
    end
    return items
end

local function specList(token)
    local classes = EbonAPI.ClientData.Classes()
    for i = 1, #classes do
        if classes[i].token == token then
            local list = {}
            for index = 1, #classes[i].specs do
                local spec = EbonAPI.ClientData.Spec(token, index)
                list[index] = { key = classes[i].specs[index].key, name = spec.name, icon = spec.icon }
            end
            return list
        end
    end
    return {}
end

local function qualityItems()
    local items = {}
    for i = 1, #QUALITIES do
        local quality = QUALITIES[i][1]
        local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality + 1]
        items[i] = {
            key = quality,
            color = qc and { qc.r, qc.g, qc.b } or nil,
            text = text(QUALITIES[i][3], QUALITIES[i][2]),
            read = function()
                local qualities = EbonBuilds.EchoFilter.Get().qualities
                return next(qualities) == nil or qualities[quality] == true
            end,
            write = function(checked)
                local set = effectiveSet(EbonBuilds.EchoFilter.Get().qualities, { 0, 1, 2, 3 })
                set[quality] = checked and true or nil
                commitSet("qualities", set, 4)
            end,
        }
    end
    return items
end

local function familyItems()
    local list = EbonAPI and EbonAPI.ClientData and EbonAPI.ClientData.Families() or {}
    local items = {}
    for i = 1, #list do
        local key = list[i].key
        if key ~= "No family" and #items < FAMILY_COUNT then
            familyKeys[#items + 1] = key
            items[#items + 1] = {
                key = key,
                icon = list[i].icon,
                name = function() return familyName(key) end,
                read = function()
                    local families = EbonBuilds.EchoFilter.Get().families
                    return next(families) == nil or families[key] == true
                end,
                write = function(on)
                    local set = effectiveSet(EbonBuilds.EchoFilter.Get().families, familyKeys)
                    set[key] = on and true or nil
                    commitSet("families", set, #familyKeys)
                end,
            }
        end
    end
    return items
end

local function tomesItems()
    local items = {}
    for i = 1, #TOMES_CHOICES do
        items[i] = { value = TOMES_CHOICES[i][1], text = text(TOMES_CHOICES[i][2], TOMES_CHOICES[i][3]) }
    end
    return items
end

local huntSubscribed = false

local function huntChecksGroup()
    return {
        kind = "checks",
        columns = 1,
        height = 24,
        items = {
            {
                key = "hunt",
                text = text("TOGGLE", "Hunt"),
                read = function()
                    local reroll = EbonBuilds.Reroll
                    return reroll and reroll.GetArmed and reroll.GetArmed() or false
                end,
                write = function(checked)
                    if EbonBuilds.Reroll and EbonBuilds.Reroll.SetArmed then
                        EbonBuilds.Reroll.SetArmed(checked and true or false)
                    end
                end,
            },
        },
    }
end

local function groups()
    local list = {
        {
            kind = "search",
            title = text("ECH_RA_SEARCH_LABEL", "Search"),
            hint = text("ECH_RA_SEARCH", "Search an Echo"),
            read = function() return EbonBuilds.EchoFilter.Get().text end,
            write = function(value) setFilter("text", value) end,
        },
        {
            kind = "classes",
            title = text("ECH_RA_CLASS", "Class"),
            items = classItems(),
            read = function() return next(EbonBuilds.EchoFilter.Get().classes) end,
            write = function(token)
                local state = EbonBuilds.EchoFilter.Get()
                if state.myClass then setFilter("myClass", false) end
                setFilter("classes", token and { [token] = true } or {})
            end,
            specs = {
                of = specList,
                read = function()
                    local state = EbonBuilds.EchoFilter.Get()
                    pruneSpecs(state, next(state.classes))
                    return state.specs
                end,
                write = function(key, on)
                    local current = EbonBuilds.EchoFilter.Get().specs
                    current[key] = on and true or nil
                    setFilter("specs", current)
                end,
            },
            mine = {
                text = text("ECH_RA_MY_CLASS", "My class only"),
                read = function() return EbonBuilds.EchoFilter.Get().myClass == true end,
                write = function(checked)
                    if checked then selectMine() end
                    setFilter("myClass", checked and true or false)
                end,
            },
        },
        {
            kind = "checks",
            title = text("ECH_RA_RARITY", "Rarity"),
            columns = 2,
            items = qualityItems(),
        },
        {
            kind = "checks",
            columns = 2,
            items = {
                {
                    key = "wished",
                    text = text("rb.tab.hunt", "Wishes"),
                    read = function() return extra.wished end,
                    write = function(checked)
                        extra.wished = checked and true or false
                        if frame and frame:IsShown() then publish() end
                    end,
                },
                {
                    key = "banned",
                    text = text("rb.auto.banned", "Banned Echoes"),
                    read = function() return extra.banned end,
                    write = function(checked)
                        extra.banned = checked and true or false
                        if frame and frame:IsShown() then publish() end
                    end,
                },
            },
        },
        {
            kind = "icons",
            title = text("ECH_RA_FAMILY", "Family"),
            items = familyItems(),
        },
        {
            kind = "dropdown",
            title = text("ECH_RA_TOMES", "Tomes"),
            items = tomesItems(),
            read = function() return EbonBuilds.EchoFilter.Get().tome or ALL_KEY end,
            write = function(value)
                if value == ALL_KEY then value = nil end
                setFilter("tome", value)
            end,
        },
        {
            kind = "dropdown",
            title = text("ECH_RA_DISCOVERY", "Discovery"),
            items = {
                { value = "all", text = text("ECH_RA_DISC_ALL", "All") },
                { value = "found", text = text("ECH_RA_DISC_FOUND", "Discovered") },
                { value = "notFound", text = text("ECH_RA_DISC_NOT", "Not discovered") },
            },
            read = function() return EbonBuilds.EchoFilter.Get().discovery or "all" end,
            write = function(value) setFilter("discovery", value) end,
            note = function()
                EbonBuilds.Discovery.Refresh()
                local _, reason = EbonBuilds.Discovery.Counts()
                if reason == "UNKNOWN" then
                    return text("ECH_RA_DISC_UNKNOWN", "No data yet")
                end
                return nil
            end,
        },
    }
    local reset = {
        kind = "reset",
        text = text("ECH_RA_RESET", "Reset filters"),
        onClick = resetState,
    }
    if EbonAPI and EbonAPI.Emblem and EbonAPI.Emblem.available and EbonAPI.Emblem.available("hunt") then
        list[#list + 1] = reset
        list[#list + 1] = { kind = "emblem", name = "hunt", fallback = huntChecksGroup() }
    else
        list[#list + 1] = huntChecksGroup()
        list[#list + 1] = reset
    end
    return list
end

function Filters.Reset()
    if column then
        column.Reset()
    else
        resetState()
        notify()
    end
end

function Filters.Refresh()
    if column then column.Refresh() end
end

function Filters.Create(parent, onChange)
    if frame then
        onChangeHook = onChange
        return frame
    end
    onChangeHook = onChange

    if not defaultsApplied then
        defaultsApplied = true
        if not EbonBuilds.EchoFilter.Get().myClass then
            setFilter("myClass", true)
        end
        if next(EbonBuilds.EchoFilter.Get().classes) == nil then
            selectMine()
        end
    end

    column = EbonBuilds.Pe.FilterColumn.Create(parent, groups(), notify)
    frame = column.Frame
    frame:SetScript("OnShow", publish)
    if not huntSubscribed and EbonBuilds.Reroll and EbonBuilds.Reroll.OnHuntChange then
        huntSubscribed = true
        EbonBuilds.Reroll.OnHuntChange(function()
            if column and column.Frame and column.Frame:IsShown() then column.Refresh() end
        end)
    end
    return frame
end
