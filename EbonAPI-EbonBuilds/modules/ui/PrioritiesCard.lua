local _, ns = ...

local floor, max = math.floor, math.max
local format = string.format

local Card = {}
ns.PrioritiesCard = Card

local OWNER = "EbonBuilds"

local index = { list = nil, bySpell = {} }

local function L(key)
    return ns.L[key]
end

local function Lookup(spellId)
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    local list = catalog and catalog.NameList()
    if not list then return nil end
    if index.list ~= list then
        index.list = list
        index.bySpell = {}
        for i = 1, #list do
            local entry = list[i]
            index.bySpell[entry.spellId] = entry
            for _, id in pairs(entry.spellIds or {}) do
                if index.bySpell[id] == nil then index.bySpell[id] = entry end
            end
        end
    end
    return index.bySpell[spellId]
end

Card.Lookup = Lookup

local function QualityName(q)
    local data = EbonAPI and EbonAPI.ClientData
    local info = data and data.Quality and data.Quality(q)
    return (info and info.name) or tostring(q)
end

local function RoleText(entry)
    local families = entry.families
    if type(families) ~= "table" or #families == 0 then return nil end
    local out = {}
    for i = 1, #families do
        out[i] = tostring(ns.FamilyName(families[i]))
    end
    return table.concat(out, ", ")
end

local function DefaultWeight(entry)
    local build = not ns.Draft.isEditing and ns.Build.GetActive()
    local class, spec
    if build then class, spec = build.class, build.spec end
    class = class or ns.Build.PlayerClassToken()
    spec = spec or ns.Build.PlayerTopTalentTab()
    return ns.Weights.Default(entry, class, spec)
end

local function WantedFloor(entry)
    local key = ns.Matrix.Key(entry.spellId)
    local rows = ns.Wishlist.Armed()
    for i = 1, #rows do
        if rows[i].key == key then return rows[i].floor end
    end
    return entry.quality or 0
end

local function IsBanned(entry)
    local build = ns.Build.GetActive()
    local list = build and build.settings and build.settings.echoBanList
    if not list then return false end
    return ns.PrioritiesControls.IsBanned(entry, list)
end

local function IsLocked(entry)
    local build = ns.Build.GetActive()
    local lockedList = build and build.lockedEchoes or {}
    for _, spellId in pairs(entry.spellIds or { entry.spellId }) do
        for i = 1, 5 do
            if lockedList[i] == spellId then return true end
        end
    end
    return false
end

local function ScoresText(entry)
    local build = ns.Build.GetActive()
    local settings = build and build.settings
    if not settings then return "" end
    local weight = ns.Weights.Get(entry.name) or 0
    local scores = {}
    for q = 0, 4 do
        if entry.qualities and entry.qualities[q] then
            local score = ns.Scoring.ScorePerQuality(entry, weight, settings, q)
            scores[#scores + 1] = floor((score or 0) + 0.5)
        end
    end
    return L("rb.col.scores") .. " : " .. table.concat(scores, " / ")
end

local function StarCount(entry)
    if not entry.spellId then return 0 end
    return ns.Rating.Stars(entry.spellId, true) or 0
end

local function WriteBan(entry)
    return ns.PrioritiesControls.ToggleBan(entry)
end

local function WeightCeiling(entry)
    local top = 0
    local weights = ns.Build.GetActiveWeights()
    if weights then
        for _, value in pairs(weights) do
            if type(value) == "number" and value > top then top = value end
        end
    end
    return max(top, DefaultWeight(entry) or 0, ns.Weights.Get(entry.name) or 0, 1) * 2
end

function Card.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

    local create = EbonAPI.Kit.create
    local baseShow = frame.Show
    local current = { spellId = nil, entry = nil }
    local onChange = nil
    local pieces = {}
    local lastWidth = nil

    local function Changed()
        frame:Refresh()
        if onChange then onChange() end
    end

    local iconSpec = {
        icon = function()
            local entry = current.entry
            return entry and select(3, GetSpellInfo(entry.spellId)) or nil
        end,
    }
    iconSpec.point = { "TOPLEFT", frame, "TOPLEFT", 0, 0 }
    local icon = create(OWNER, "icon", frame, iconSpec)
    local gap = floor(icon:GetHeight() / 4)

    local nameSpec = {
        text = function() return current.entry and current.entry.name or "" end,
        point = { "TOPLEFT", icon, "TOPRIGHT", gap, 0 },
    }
    local name = create(OWNER, "text", frame, nameSpec)

    local subSpec = {
        text = function()
            local entry = current.entry
            if not entry then return "" end
            local role = RoleText(entry)
            local quality = QualityName(entry.quality)
            if role then return quality .. " · " .. role end
            return quality
        end,
        point = { "TOPLEFT", name, "BOTTOMLEFT", 0, 0 },
    }
    local sub = create(OWNER, "text", frame, subSpec)

    local starsLabelSpec = {
        text = function() return L("rb.col.stars") end,
        point = { "TOPLEFT", sub, "BOTTOMLEFT", 0, 0 },
    }
    local starsLabel = create(OWNER, "text", frame, starsLabelSpec)
    local starSize = sub:GetHeight()
    local starGap = floor(starSize / 4)
    local stars = ns.Stars.Create(frame, starSize, starGap)

    local scoresSpec = {
        text = function()
            local entry = current.entry
            return entry and ScoresText(entry) or ""
        end,
        point = { "TOPLEFT", starsLabel, "BOTTOMLEFT", 0, 0 },
    }
    local scores = create(OWNER, "text", frame, scoresSpec)

    local stateSpec = {
        text = function() return L("rb.col.state") .. " : " .. L("rb.state.locked") end,
        point = { "TOPLEFT", scores, "BOTTOMLEFT", 0, 0 },
    }
    local state = create(OWNER, "text", frame, stateSpec)

    local noneSpec = {
        text = function() return L("prio.page.card.none") end,
        point = { "TOPLEFT", frame, "TOPLEFT", 0, 0 },
    }
    local none = create(OWNER, "text", frame, noneSpec)

    local rangeSpec = {
        text = function() return L("prio.page.card.weight") end,
        min = 0,
        max = 2,
        step = 1,
        point = { "TOPLEFT", scores, "BOTTOMLEFT", 0, -gap },
    }
    rangeSpec.get = function()
        local entry = current.entry
        return entry and ns.Weights.Get(entry.name) or 0
    end
    rangeSpec.onChange = function(_, value)
        local entry = current.entry
        if not entry or type(value) ~= "number" then return end
        if floor(value) == ns.Weights.Get(entry.name) then return end
        ns.Weights.Set(entry.name, value)
        Changed()
    end
    local range = create(OWNER, "range", frame, rangeSpec)

    local floorSpec = {
        values = function()
            local entry = current.entry
            local out = {}
            local qualities = entry and (entry.qualities or { [entry.quality] = true }) or {}
            for q = 0, 4 do
                if qualities[q] then out[#out + 1] = { value = q, text = QualityName(q) } end
            end
            return out
        end,
        get = function()
            local entry = current.entry
            return entry and WantedFloor(entry) or nil
        end,
        point = { "TOPLEFT", range, "BOTTOMLEFT", 0, -gap },
    }
    floorSpec.onChange = function(_, quality)
        local entry = current.entry
        if not entry or quality == nil then return end
        local wasWanted = ns.Wishlist.Has(entry.spellId)
        if wasWanted and WantedFloor(entry) == quality then return end
        if not wasWanted then ns.Wishlist.Toggle(entry.spellId) end
        ns.Wishlist.SetFloor(ns.Matrix.Key(entry.spellId), quality)
        Changed()
    end
    local floorSelect = create(OWNER, "select", frame, floorSpec)

    local wantedSpec = {
        text = function()
            local entry = current.entry
            if not entry then return "" end
            return format(L("prio.page.card.wanted"), QualityName(WantedFloor(entry)))
        end,
        get = function()
            local entry = current.entry
            return entry and ns.Wishlist.Has(entry.spellId) or false
        end,
        point = { "TOPLEFT", floorSelect, "BOTTOMLEFT", 0, -gap },
    }
    wantedSpec.onChange = function(checked)
        local entry = current.entry
        if not entry then return end
        local has = ns.Wishlist.Has(entry.spellId)
        if checked and not has then
            ns.Wishlist.Toggle(entry.spellId)
        elseif not checked and has then
            ns.Wishlist.Remove(entry.spellId)
        else
            return
        end
        Changed()
    end
    local wanted = create(OWNER, "checkBox", frame, wantedSpec)

    local bannedSpec = {
        text = function() return L("prio.page.card.banned") end,
        get = function()
            local entry = current.entry
            return entry and IsBanned(entry) or false
        end,
        point = { "TOPLEFT", wanted, "BOTTOMLEFT", 0, -gap },
    }
    bannedSpec.onChange = function(checked)
        local entry = current.entry
        if not entry then return end
        if checked == IsBanned(entry) then return end
        if WriteBan(entry) then Changed() else frame:Refresh() end
    end
    local banned = create(OWNER, "checkBox", frame, bannedSpec)

    local defaultSpec = {
        text = function() return L("prio.page.card.default") end,
        point = { "TOPLEFT", banned, "BOTTOMLEFT", 0, -gap },
    }
    defaultSpec.onClick = function()
        local entry = current.entry
        if not entry then return end
        local default = DefaultWeight(entry)
        if default == nil or ns.Weights.Get(entry.name) == default then return end
        ns.Weights.Set(entry.name, default)
        Changed()
    end
    local default = create(OWNER, "button", frame, defaultSpec)

    pieces = { icon, name, sub, starsLabel, scores, range, floorSelect, wanted, banned, default }

    local function IsCurrentLocked()
        return current.entry ~= nil and IsLocked(current.entry)
    end

    local function Apply()
        local has = current.entry ~= nil
        for i = 1, #pieces do
            if has then pieces[i]:Show() else pieces[i]:Hide() end
        end
        if IsCurrentLocked() then state:Show() else state:Hide() end
        ns.Stars.Set(stars, has and StarCount(current.entry) or nil)
        if has then none:Hide() else none:Show() end
    end

    local function ApplyWidth(width)
        if width == lastWidth then return end
        lastWidth = width
        frame:SetWidth(width)
        local room = width - icon:GetWidth() - gap
        nameSpec.width = room
        subSpec.width = room
        noneSpec.width = width
        starsLabelSpec.width = floor(width / 2)
        scoresSpec.width = width
        stateSpec.width = width
        ns.Stars.Place(stars, "LEFT", starsLabel, "LEFT", floor(width / 2) + starSize + starGap, 0)
        rangeSpec.width = width
        floorSpec.width = width
        name:Refresh()
        sub:Refresh()
        starsLabel:Refresh()
        scores:Refresh()
        state:Refresh()
        none:Refresh()
        range:Refresh()
        floorSelect:Refresh()
    end

    function frame:Show(spellId)
        baseShow(self)
        local entry = spellId ~= nil and Lookup(spellId) or nil
        current.spellId = spellId
        current.entry = entry
        if entry then rangeSpec.max = WeightCeiling(entry) end
        Apply()
        self:Refresh()
    end

    function frame:Refresh()
        for i = 1, #pieces do pieces[i]:Refresh() end
        state:Refresh()
        none:Refresh()
        local entry = current.entry
        local locked = IsCurrentLocked()
        if locked then state:Show() else state:Hide() end
        banned:SetDisabledState(locked)
        ns.Stars.Set(stars, entry and StarCount(entry) or nil)
        return self
    end

    function frame:SetOnChange(fn)
        onChange = fn
    end

    function frame:Height(width)
        ApplyWidth(width)
        local head = name:GetHeight() + sub:GetHeight()
        local extra = math.max(0, icon:GetHeight() - head)
        starsLabel:ClearAllPoints()
        starsLabel:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -extra)
        local last = scores
        local total = head + extra + starsLabel:GetHeight() + scores:GetHeight()
        if IsCurrentLocked() then
            last = state
            total = total + state:GetHeight()
        end
        range:ClearAllPoints()
        range:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -gap)
        local rows = { range, floorSelect, wanted, banned, default }
        for i = 1, #rows do
            total = total + gap + rows[i]:GetHeight()
        end
        return total
    end

    Apply()
    return frame
end
