local _, ns = ...

EbonBuilds = EbonBuilds or {}
EbonBuilds.Pe = EbonBuilds.Pe or {}
EbonBuilds.Pe.EchoesGrid = EbonBuilds.Pe.EchoesGrid or {}

local EchoesGrid = EbonBuilds.Pe.EchoesGrid

local FRAME_X, FRAME_Y = 330, -44
local FILTERS_WIDTH, GAP = 350, 10
local MIN_COLUMNS = 7
local STEP_X, STEP_Y = 62, 78
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 1170, 480
local SLOTS = 6

local QUALITY_COLORS = {
    [0] = { 1, 1, 1 },
    [1] = { 0.1, 1, 0.1 },
    [2] = { 0, 0.4, 1 },
    [3] = { 0.8, 0.4, 1 },
    [4] = { 1, 0.5, 0 },
}

local catalogCache = { source = nil, list = nil }
local lastCharges = {}

local Grid = {}
Grid.__index = Grid

local text = EbonBuilds.Pe.Common.text

local function collectEchoes()
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    local database = catalog and catalog.Database and catalog.Database()
    if type(database) ~= "table" then return {} end
    if catalogCache.source == database and catalogCache.list and #catalogCache.list > 0 then
        return catalogCache.list
    end
    local list = {}
    for spellId, data in pairs(database) do
        if type(spellId) == "number" and type(data) == "table" then
            local name, _, icon = GetSpellInfo(spellId)
            if name then
                list[#list + 1] = {
                    spellId = spellId,
                    name = name,
                    lname = name:lower(),
                    icon = icon,
                    quality = tonumber(data.quality) or 0,
                    classMask = data.classMask or 0,
                    families = data.families or {},
                    tome = data.isTome == true,
                    maxStack = tonumber(data.maxStack) or 1,
                    ownedStacks = 0,
                    ownedLocked = false,
                }
            end
        end
    end
    catalogCache = { source = database, list = list }
    return list
end

local function readOwned()
    local owned = {}
    local service = ProjectEbonhold and ProjectEbonhold.PerkService
    if type(service) ~= "table" then return owned end
    local granted = service.GetGrantedPerks and service.GetGrantedPerks()
    if type(granted) == "table" then
        for _, instances in pairs(granted) do
            if type(instances) == "table" then
                for _, inst in ipairs(instances) do
                    local spellId = inst.spellId
                    if type(spellId) == "number" then
                        local entry = owned[spellId] or { stacks = 0, locked = false }
                        entry.stacks = entry.stacks + (inst.stack or 1)
                        owned[spellId] = entry
                    end
                end
            end
        end
    end
    local lockedPerks = service.GetLockedPerks and service.GetLockedPerks()
    if type(lockedPerks) == "table" then
        for _, perk in ipairs(lockedPerks) do
            local spellId = perk.spellId
            if type(spellId) == "number" then
                local entry = owned[spellId] or { stacks = 0, locked = false }
                entry.locked = true
                owned[spellId] = entry
            end
        end
    end
    return owned
end

function EchoesGrid.OwnedList()
    local out = {}
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    for spellId, info in pairs(readOwned()) do
        local data = catalog and catalog.Entry and catalog.Entry(spellId) or {}
        out[#out + 1] = {
            key = spellId,
            spellId = spellId,
            quality = tonumber(data.quality) or 0,
            stacks = math.max(info.stacks or 0, 1),
            locked = info.locked == true,
            chosen = true,
            banned = false,
        }
    end
    table.sort(out, function(a, b)
        if a.locked ~= b.locked then return a.locked end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.spellId < b.spellId
    end)
    return out
end

local function readBuild()
    local charges = {}
    local build = EbonBuilds.Build.GetActive()
    if build then
        local list = EbonBuilds.Build.Echoes(build)
        for i = 1, #list do
            local item = list[i]
            if item.chosen then charges[item.spellId] = item.stacks end
        end
    end
    return build, charges
end

local function compare(a, b)
    local ownedA, ownedB = a.ownedStacks > 0, b.ownedStacks > 0
    if ownedA ~= ownedB then return ownedA end
    if a.quality ~= b.quality then return a.quality > b.quality end
    if a.lname ~= b.lname then return a.lname < b.lname end
    return a.spellId < b.spellId
end

local function setKey(set)
    local keys = {}
    for key in pairs(set) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function signature(filter, extraWished, extraBanned)
    return table.concat({
        filter.text or "",
        tostring(filter.myClass),
        tostring(filter.discovery),
        tostring(filter.tome),
        tostring(filter.spec),
        tostring(filter.hunt),
        tostring(extraWished),
        tostring(extraBanned),
        setKey(filter.classes),
        setKey(filter.qualities),
        setKey(filter.families),
    }, "|")
end

local function slotOf(locked, spellId)
    if not locked then return nil end
    for i = 1, SLOTS do
        if locked[i] == spellId then return i end
    end
    return nil
end

local function sameNameSlot(locked, spellId)
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    if not locked or not catalog or not catalog.NameKey then return nil end
    local name = catalog.NameKey(spellId)
    if not name then return nil end
    for i = 1, SLOTS do
        if type(locked[i]) == "number" and catalog.NameKey(locked[i]) == name then return i end
    end
    return nil
end

local function addEcho(entry)
    local build = EbonBuilds.Build.GetActive()
    if not build then return false end
    build.lockedEchoes = build.lockedEchoes or {}
    local locked = build.lockedEchoes
    local spellId = entry.spellId
    if slotOf(locked, spellId) then
        local current = EbonBuilds.Build.Stacks(build, spellId)
        if current >= entry.maxStack then return false end
        build.echoStacks = build.echoStacks or {}
        build.echoStacks[spellId] = current + 1
    else
        local slot = sameNameSlot(locked, spellId)
        if not slot then
            for i = 1, SLOTS do
                if type(locked[i]) ~= "number" then
                    slot = i
                    break
                end
            end
        end
        if not slot then
            UIErrorsFrame:AddMessage(string.format(text("ECH_RA_FULL", "The build already holds %d echoes"), SLOTS), 1, 0.1, 0.1)
            return false
        end
        if type(locked[slot]) == "number" and build.echoStacks then
            build.echoStacks[locked[slot]] = nil
        end
        locked[slot] = spellId
    end
    EbonBuilds.Build.Save(build.id, { lockedEchoes = locked })
    return true
end

local function removeEcho(entry)
    local build = EbonBuilds.Build.GetActive()
    if not build then return false end
    local spellId = entry.spellId
    local slot = slotOf(build.lockedEchoes, spellId)
    if not slot then return false end
    local current = EbonBuilds.Build.Stacks(build, spellId)
    if current > 1 then
        build.echoStacks = build.echoStacks or {}
        build.echoStacks[spellId] = current - 1
    else
        build.lockedEchoes[slot] = nil
        if build.echoStacks then build.echoStacks[spellId] = nil end
    end
    EbonBuilds.Build.Save(build.id, { lockedEchoes = build.lockedEchoes })
    return true
end

local function toggleAvoid(entry)
    local build = EbonBuilds.Build.GetActive()
    if not build then return false end
    if slotOf(build.lockedEchoes, entry.spellId) then return false end
    EbonBuilds.Build.EnsureSettings(build)
    local list = build.settings.echoBanList
    if list[entry.spellId] then
        list[entry.spellId] = nil
    else
        list[entry.spellId] = entry.name
    end
    EbonBuilds.Build.Save(build.id, { settings = build.settings })
    return true
end

local function isBanned(spellId)
    local build = EbonBuilds.Build.GetActive()
    local list = build and build.settings and build.settings.echoBanList
    return list ~= nil and list[spellId] ~= nil
end

local function ensureMarks(tile)
    if tile.ebWish then return end
    local anchor = tile.icon
    local wish = tile:CreateTexture(nil, "OVERLAY")
    EbonBuilds.Wishlist.StyleMark(wish)
    wish:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
    wish:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)
    wish:Hide()
    local ban = tile:CreateTexture(nil, "OVERLAY")
    ban:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    ban:SetSize(18, 18)
    ban:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
    ban:Hide()
    tile.ebWish = wish
    tile.ebBan = ban
end

local function linkEcho(entry)
    local marker = "{echo:" .. entry.spellId .. ":" .. entry.quality .. "}"
    if not ChatEdit_InsertLink(marker) then
        ChatFrame_OpenChat(marker)
    end
end

local function onTileClick(grid, tile, mouseButton)
    local entry = tile.ebEntry
    if not entry then return end
    local changed = false
    if IsShiftKeyDown() then
        linkEcho(entry)
        return
    elseif IsControlKeyDown() then
        if mouseButton ~= "LeftButton" then return end
        EbonBuilds.Wishlist.Toggle(entry.spellId)
        changed = true
    elseif IsAltKeyDown() then
        if mouseButton ~= "LeftButton" then return end
        changed = toggleAvoid(entry)
    elseif mouseButton == "LeftButton" then
        changed = addEcho(entry)
    elseif mouseButton == "RightButton" then
        changed = removeEcho(entry)
    end
    if changed then
        grid:Update()
        if grid.onBuildChanged then grid.onBuildChanged() end
    end
end

local function fillTip(tile)
    local spellId = tile.ebTipSpell
    if not spellId then return false end
    local name = GetSpellInfo(spellId)
    if not name then return false end
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    local data = catalog and catalog.Entry and catalog.Entry(spellId) or {}
    local color = QUALITY_COLORS[data.quality] or QUALITY_COLORS[0]
    GameTooltip:AddLine(name, color[1], color[2], color[3])
    GameTooltip:AddLine(" ")
    if utils and utils.GetSpellDescription then
        GameTooltip:AddLine(utils.GetSpellDescription(spellId, 4000, tile.ebTipStacks or 1), 1, 0.82, 0, true)
    else
        GameTooltip:SetHyperlink("spell:" .. spellId)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(EbonBuilds.Wishlist.Has(spellId) and text("HUNT_UNMARK", "Ctrl+click: stop hunting") or text("HUNT_MARK", "Ctrl+click: hunt this Echo"), 0.5, 0.5, 0.5)
    GameTooltip:AddLine(isBanned(spellId) and text("BAN_UNMARK", "Alt+click: stop banning") or text("BAN_MARK", "Alt+click: ban this Echo"), 0.5, 0.5, 0.5)
    local owned = readOwned()[spellId]
    if owned and owned.locked then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(text("ECH_RA_TIP_LOCKED", "Permanent echo (locked between runs)"), 1, 0.82, 0)
    end
    local charge = lastCharges[spellId]
    if charge then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(text("ECH_RA_TIP_BUILD", "In the active build: %d / %d"), charge, data.maxStack or 1), 0.5, 0.75, 1)
    end
    local source = ProjectEbonhold and ProjectEbonhold.PerkDropSources and ProjectEbonhold.PerkDropSources[spellId]
    if not source and data.groupId and ProjectEbonhold and ProjectEbonhold.PerkDropSourceByGroup then
        source = ProjectEbonhold.PerkDropSourceByGroup[data.groupId]
    end
    if source then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(source, 0.5, 0.5, 0.5, true)
    end
    if data.isTome then
        GameTooltip:AddLine(" ")
        if EbonBuilds.Discovery.State(spellId) == "found" then
            local service = ProjectEbonhold and ProjectEbonhold.PerkService
            local disabled = service and service.IsTomeEchoDisabled and service.IsTomeEchoDisabled(spellId)
            if disabled then
                GameTooltip:AddLine(text("ECH_RA_TIP_TOME_OFF", "Tome learned (disabled)"), 0.1, 1, 0.1)
            else
                GameTooltip:AddLine(text("ECH_RA_TIP_TOME_ON", "Tome learned (enabled)"), 0.1, 1, 0.1)
            end
        else
            GameTooltip:AddLine(text("ECH_RA_TIP_TOME_REQ", "Requires Tome to unlock"), 1, 0.82, 0)
        end
    end
end

function EchoesGrid.TipFor(tile, spellId, stacks)
    tile.ebTipSpell = spellId
    tile.ebTipStacks = stacks
    if tile.ebTipHooked then return end
    tile.ebTipHooked = true
    EbonBuilds.Widgets.Tip(tile, function() return fillTip(tile) end, "ANCHOR_RIGHT")
end

function Grid:Draw()
    local items = self.items
    local rows = math.ceil(#items / self.columns)
    local maxTop = math.max(0, rows - self.rows)
    if self.top > maxTop then self.top = maxTop end
    if self.top < 0 then self.top = 0 end
    local base = self.top * self.columns
    for i = 1, self.page do
        local tile = self.tiles[i]
        local entry = items[base + i]
        if entry then
            tile.ebEntry = entry
            tile:SetData({
                icon = entry.icon,
                name = entry.name,
                quality = math.min(entry.quality + 1, 5),
                locked = entry.ownedLocked,
                marked = entry.tome,
                markKind = "book",
                stacks = self.charges[entry.spellId] or 0,
                badge = EbonBuilds.Weights.SpecBadge(entry),
            })
            if EbonBuilds.Discovery.State(entry.spellId) == "notFound" then
                tile:SetState("dim")
            else
                tile:SetState("normal")
            end
            EchoesGrid.TipFor(tile, entry.spellId, entry.ownedStacks > 0 and entry.ownedStacks or 1)
            ensureMarks(tile)
            local banned = isBanned(entry.spellId)
            tile.ebWish:SetShown(EbonBuilds.Wishlist.Shown(entry.spellId))
            tile.ebBan:SetShown(banned)
            if banned then tile.icon:SetDesaturated(true) end
            tile:Show()
        else
            tile.ebEntry = nil
            tile:Hide()
        end
    end
    if #items == 0 then
        self.empty:Show()
    else
        self.empty:Hide()
    end
end

function Grid:Update()
    local build, charges = readBuild()
    self.build = build
    self.charges = charges
    lastCharges = charges
    self:Draw()
end

function Grid:Scroll(delta)
    local before = self.top
    if delta > 0 then
        self.top = self.top - 1
    else
        self.top = self.top + 1
    end
    local maxTop = math.max(0, math.ceil(#self.items / self.columns) - self.rows)
    if self.top < 0 then self.top = 0 end
    if self.top > maxTop then self.top = maxTop end
    if self.top ~= before then self:Draw() end
end

function Grid:Refresh()
    local all = collectEchoes()
    local filter = EbonBuilds.EchoFilter.Get()
    local owned = readOwned()
    for i = 1, #all do
        local entry = all[i]
        local info = owned[entry.spellId]
        entry.ownedStacks = info and info.stacks or 0
        entry.ownedLocked = info and info.locked or false
    end
    local items = EbonBuilds.EchoFilter.Apply(all)
    local extraWished, extraBanned = EbonBuilds.Pe.EchoesFilters.Extra()
    if extraWished or extraBanned then
        local kept = {}
        for i = 1, #items do
            if EbonBuilds.Pe.EchoesFilters.PassesExtra(items[i].spellId) then kept[#kept + 1] = items[i] end
        end
        items = kept
    end
    table.sort(items, compare)
    local key = signature(filter, extraWished, extraBanned)
    if key ~= self.filterKey then
        self.filterKey = key
        self.top = 0
    end
    self.items = items
    local found
    if EbonBuilds.Discovery.Counts() ~= nil then
        found = EbonBuilds.EchoFilter.Counts(all)
    end
    self.empty:SetText(text("ECH_RA_EMPTY", "No echo matches these filters"))
    self:Update()
    return found, #all, #items
end

function EchoesGrid.Create(parent, onBuildChanged)
    local frame = CreateFrame("Frame", nil, parent)
    local zoneWidth, zoneHeight = parent:GetWidth(), parent:GetHeight()
    if not zoneWidth or zoneWidth < 400 then zoneWidth = DEFAULT_WIDTH end
    if not zoneHeight or zoneHeight < 100 then zoneHeight = DEFAULT_HEIGHT end
    local columns = math.max(MIN_COLUMNS, math.floor((zoneWidth - FRAME_X - FILTERS_WIDTH - GAP) / STEP_X))
    local rows = math.max(1, math.floor((zoneHeight + FRAME_Y) / STEP_Y))
    frame:SetWidth(columns * STEP_X)
    frame:SetHeight(rows * STEP_Y)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", FRAME_X, FRAME_Y)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)

    local grid = setmetatable({
        frame = frame,
        onBuildChanged = onBuildChanged,
        columns = columns,
        rows = rows,
        page = columns * rows,
        tiles = {},
        items = {},
        charges = {},
        top = 0,
        filterKey = nil,
    }, Grid)

    local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
    empty:SetText(text("ECH_RA_EMPTY", "No echo matches these filters"))
    empty:Hide()
    grid.empty = empty

    frame:SetScript("OnMouseWheel", function(_, delta)
        grid:Scroll(delta)
    end)

    for i = 1, grid.page do
        local row = math.floor((i - 1) / columns)
        local column = (i - 1) % columns
        local tile = EbonBuilds.Widgets.Kit("echoTile", frame, {
            state = "normal",
            onClick = function(self, mouseButton)
                onTileClick(grid, self, mouseButton)
            end,
        })
        tile:SetPoint("TOPLEFT", frame, "TOPLEFT", column * STEP_X, -row * STEP_Y)
        tile:Hide()
        grid.tiles[i] = tile
    end

    return grid
end
