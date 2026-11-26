local _, ns = ...

local floor, max, min = math.floor, math.max, math.min
local concat = table.concat

local WEIGHT_MAX = 116

local Tab = {}
ns.PrioritiesTabWeights = Tab

local RARITY_KEYS = { [0] = "rarity.common", [1] = "rarity.uncommon", [2] = "rarity.rare", [3] = "rarity.epic" }
local FAMILY_FALLBACK = { "tank", "healer", "melee", "ranged", "caster", "survival" }

local tx = ns.PrioritiesState.Text

local function state()
    return ns.PrioritiesState.State()
end

local function currentBuild()
    return ns.PrioritiesState.Build()
end

local function lookup(spellId)
    return ns.PrioritiesCard.Lookup(spellId)
end

local function rarityName(quality)
    local key = RARITY_KEYS[quality]
    if key then return tx(key) end
    local data = EbonAPI and EbonAPI.ClientData
    local info = data and data.Quality and data.Quality(quality)
    return (info and info.name) or tostring(quality)
end

local function classSpec(build)
    local class = build and build.class or ns.Build.PlayerClassToken()
    local spec = build and build.spec or ns.Build.PlayerTopTalentTab()
    return class, spec
end

local function defaultWeight(entry, build)
    local class, spec = classSpec(build)
    return ns.Weights.Default(entry, class, spec)
end

local function weightOf(entry, build)
    return ns.Weights.Get(entry.name, build) or 0
end

local function weightCeiling(entry, build)
    return max(WEIGHT_MAX, weightOf(entry, build), defaultWeight(entry, build) or 0)
end

local function roleText(entry)
    local families = entry.families
    if type(families) ~= "table" or #families == 0 then return tx("prio.echo.role.damage") end
    local out = {}
    for i = 1, #families do
        out[i] = tostring(ns.FamilyName(families[i]))
    end
    return concat(out, ", ")
end

local function scoresText(entry, build)
    local settings = build and build.settings
    if not settings then return "" end
    local weight = weightOf(entry, build)
    local scores = {}
    for q = 0, 4 do
        if entry.qualities and entry.qualities[q] then
            local score = ns.Scoring.ScorePerQuality(entry, weight, settings, q)
            scores[#scores + 1] = floor((score or 0) + 0.5)
        end
    end
    if #scores == 0 then return "" end
    return string.format(tx("prio.echo.score"), concat(scores, " / "))
end

Tab.ScoresText = scoresText

local function isWanted(entry)
    return ns.Wishlist.Has(entry.spellId) == true
end

local function isBanned(entry, build)
    local list = build and build.settings and build.settings.echoBanList
    if not list then return false end
    return ns.PrioritiesControls.IsBanned(entry, list)
end

local function wantedFloor(entry)
    local key = ns.Matrix.Key(entry.spellId)
    local rows = ns.Wishlist.Armed()
    for i = 1, #rows do
        if rows[i].key == key then return rows[i].floor end
    end
    return entry.quality or 0
end

local function headerText(build)
    local classToken, specToken = build.class, build.spec
    local data = EbonAPI and EbonAPI.ClientData
    local card = classToken and data and data.Class and data.Class(classToken)
    local specCard = classToken and data and data.Spec and data.Spec(classToken, specToken)
    return string.format(
        tx("prio.build.header"),
        (card and card.name) or tostring(classToken or ""),
        (specCard and specCard.name) or tostring(specToken or ""),
        ""
    )
end

local function familyList()
    local data = EbonAPI and EbonAPI.ClientData
    local list = data and data.Families and data.Families()
    local out = {}
    if type(list) == "table" then
        for _, family in ipairs(list) do
            if family.key then out[#out + 1] = tostring(family.key) end
        end
    end
    if #out == 0 then
        for i, key in ipairs(FAMILY_FALLBACK) do out[i] = key end
    end
    return out
end

function Tab.Build(page, width, height)
    local Kit = EbonAPI.Kit
    local W = ns.Widgets
    local current = { entry = nil }
    local unsubscribe

    local root, host, w
    if height then
        root = W.Scroll(page, { width = width, height = height, layout = "VERTICAL" })
        W.ScrollSize(root, width, height)
        host = root._content
        local view = root.kitScroll and root.kitScroll.child and root.kitScroll.child:GetWidth() or 0
        w = view > 0 and min(view, width) or width
    else
        root = page:Add("bar", { layout = "VERTICAL", width = width })
        host = root
        w = width
    end
    local gap = tonumber(EbonAPI.Skins.value("kit.spacing")) or 0
    local function add(parent, kind, spec) return parent:Add(kind, spec) end

    local function noBuild() return currentBuild() == nil end
    local function noEcho() return currentBuild() ~= nil and current.entry == nil end
    local function hasEcho() return current.entry ~= nil end

    add(host, "text", { width = w, hidden = function() return not noBuild() end, text = function() return tx("prio.panel.nobuild") end })
    add(host, "text", { width = w, hidden = function() return not noBuild() end, text = function() return tx("prio.panel.nobuild.grid") end })
    add(host, "text", { width = w, hidden = function() return not noEcho() end, text = function() return tx("prio.panel.noecho") end })

    add(host, "text", {
        width = w,
        hidden = noBuild,
        text = function()
            local build = currentBuild()
            return build and headerText(build) or ""
        end,
    })

    local echoBox = add(host, "bar", { layout = "VERTICAL", width = w, spacing = gap, hidden = function() return not hasEcho() end })

    local head = add(echoBox, "bar", { layout = "HORIZONTAL", width = w, spacing = gap })
    local icon = add(head, "icon", {
        icon = function()
            local entry = current.entry
            return entry and select(3, GetSpellInfo(entry.spellId)) or nil
        end,
    })
    local titleWidth = max(1, w - icon:GetWidth() - gap)
    local titles = add(head, "bar", { layout = "VERTICAL", width = titleWidth })
    add(titles, "text", { width = titleWidth, text = function() return current.entry and current.entry.name or "" end })
    add(titles, "text", {
        width = titleWidth,
        text = function()
            local entry = current.entry
            if not entry then return "" end
            return string.format(tx("prio.echo.role"), roleText(entry))
        end,
    })

    add(echoBox, "text", {
        width = w,
        text = function()
            local entry = current.entry
            return entry and scoresText(entry, currentBuild()) or ""
        end,
    })

    local range = add(echoBox, "range", {
        width = w,
        min = 0,
        max = WEIGHT_MAX,
        step = 1,
        text = function() return tx("prio.echo.weight") end,
        get = function()
            local entry = current.entry
            return entry and weightOf(entry, currentBuild()) or 0
        end,
        onChange = function(_, value)
            local entry, build = current.entry, currentBuild()
            if not entry or not build or type(value) ~= "number" then return end
            value = floor(value + 0.5)
            if value == weightOf(entry, build) then return end
            ns.Weights.Set(entry.name, value, build)
            ns.Build.Save(build.id, { echoWeights = build.echoWeights })
            ns.PrioritiesState.Changed()
        end,
    })

    add(echoBox, "button", {
        width = w,
        text = function() return tx("prio.echo.default") end,
        onClick = function()
            local entry, build = current.entry, currentBuild()
            if not entry or not build then return end
            local default = defaultWeight(entry, build)
            if default == nil or weightOf(entry, build) == default then return end
            ns.Weights.Set(entry.name, default, build)
            ns.Build.Save(build.id, { echoWeights = build.echoWeights })
            ns.PrioritiesState.Changed()
        end,
    })

    add(echoBox, "text", {
        width = w,
        hidden = function() return not (current.entry and isWanted(current.entry)) end,
        text = function() return tx("prio.echo.wanted") end,
    })
    add(echoBox, "text", {
        width = w,
        hidden = function() return not (current.entry and isWanted(current.entry)) end,
        text = function()
            local entry = current.entry
            if not entry then return "" end
            return string.format(tx("prio.pair"), tx("prio.echo.minrarity"), rarityName(wantedFloor(entry)))
        end,
    })
    add(echoBox, "text", {
        width = w,
        hidden = function() return not (current.entry and isBanned(current.entry, currentBuild())) end,
        text = function() return tx("prio.echo.banned") end,
    })

    local bonusBox = add(host, "bar", { layout = "VERTICAL", width = w, spacing = gap, hidden = noBuild })

    local function settingsOf()
        local build = currentBuild()
        if not build then return nil, nil end
        ns.Build.EnsureSettings(build)
        return build.settings, build
    end

    local function bonusRow(label, tableKey, modeKey, key)
        add(bonusBox, "input", {
            width = w,
            text = label,
            get = function()
                local settings = settingsOf()
                local group = settings and settings[tableKey]
                local value = group and group[key]
                return tostring(value == nil and 0 or value)
            end,
            onChange = function(_, text)
                local number = tonumber(text)
                local settings, build = settingsOf()
                if not number or not settings then return end
                settings[tableKey] = settings[tableKey] or {}
                if settings[tableKey][key] == number then return end
                settings[tableKey][key] = number
                ns.Build.Save(build.id, { settings = settings })
                ns.PrioritiesState.Changed()
            end,
        })
        add(bonusBox, "toggle", {
            width = w,
            text = function() return string.format(tx("rb.opt.mode"), type(label) == "function" and label() or label) end,
            get = function()
                local settings = settingsOf()
                local group = settings and settings[modeKey]
                return group and group[key] and true or false
            end,
            onChange = function(_, value)
                local settings, build = settingsOf()
                if not settings then return end
                settings[modeKey] = settings[modeKey] or {}
                value = value and true or false
                if (settings[modeKey][key] and true or false) == value then return end
                settings[modeKey][key] = value
                ns.Build.Save(build.id, { settings = settings })
                ns.PrioritiesState.Changed()
            end,
        })
    end

    add(bonusBox, "heading", { width = w, text = function() return tx("prio.weights.rarity") end })
    for q = 0, 3 do
        bonusRow(function() return rarityName(q) end, "qualityBonus", "qualityBonusMode", q)
    end
    add(bonusBox, "heading", { width = w, text = function() return tx("prio.weights.family") end })
    for _, key in ipairs(familyList()) do
        bonusRow(function() return ns.FamilyName(key) end, "familyBonus", "familyBonusMode", key)
    end

    local function refresh()
        local st = state()
        local build = currentBuild()
        current.entry = build and lookup(st.echoId) or nil
        if current.entry then
            range.spec.max = weightCeiling(current.entry, build)
        end
        root:Refresh()
        Kit.relayout(echoBox, true)
        Kit.relayout(bonusBox, true)
        Kit.relayout(host, true)
        if root ~= host and root.Layout then root:Layout() end
        Kit.relayout(page, true)
    end

    unsubscribe = ns.PrioritiesState.Subscribe(function(changedKey)
        if changedKey == "build" or changedKey == "echo" or changedKey == "tab" or changedKey == "data" or changedKey == nil then
            refresh()
        end
    end)
    root.Unsubscribe = unsubscribe

    refresh()
    return root, refresh
end
