local _, ns = ...

EbonBuilds.EchoFilter = {}
local EchoFilter = EbonBuilds.EchoFilter

local TOMES = { tome = true, tomeKnown = true, enabled = true, disabled = true }
local DISCOVERY = { all = true, found = true, notFound = true }

local state
local callbacks = {}

local function Defaults()
    return {
        text = "",
        classes = {},
        myClass = false,
        qualities = {},
        families = {},
        specs = {},
        tome = nil,
        discovery = "all",
        hunt = false,
    }
end

state = Defaults()

local function Notify()
    for i = 1, #callbacks do
        callbacks[i]("refreshed", nil)
    end
end

local function CopySet(set)
    local out = {}
    for k, v in pairs(set) do out[k] = v end
    return out
end

local function Database()
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    return catalog and catalog.Database()
end

local function IsTome(database, spellId)
    local data = database and database[spellId]
    return data ~= nil and data.isTome == true
end

local function IsDisabled(spellId)
    local service = ProjectEbonhold and ProjectEbonhold.PerkService
    if service and service.IsTomeEchoDisabled then
        return service.IsTomeEchoDisabled(spellId) == true
    end
    return false
end

local function ClassMaskBits(set)
    local bits = {}
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    for token in pairs(set) do
        local value = catalog and catalog.ClassBit(token)
        if value then bits[#bits + 1] = value end
    end
    return bits
end

local function MyClassBit()
    local token = select(2, UnitClass("player"))
    local catalog = EbonAPI and EbonAPI.EchoCatalog
    return token and catalog and catalog.ClassBit(token)
end

local function MatchesClass(entry, bits)
    local mask = entry.classMask
    if not mask or mask == 0 then return true end
    for i = 1, #bits do
        if bit.band(mask, bits[i]) ~= 0 then return true end
    end
    return false
end

local function MatchesQuality(entry, set)
    local qualities = entry.qualities
    if not qualities then
        return entry.quality ~= nil and set[entry.quality] == true
    end
    for q in pairs(set) do
        if qualities[q] then return true end
    end
    return false
end

local function MatchesFamilies(entry, set)
    local has = {}
    local hasAny = false
    for _, family in ipairs(entry.families or {}) do
        local key = EbonAPI.ClientData.Family(family)
        has[key] = true
        if key ~= "No family" then hasAny = true end
    end
    if next(set) == nil then return true end
    for wanted in pairs(set) do
        if wanted == "No family" then
            if not hasAny then return true end
        elseif has[wanted] then
            return true
        end
    end
    return false
end

local ROLE_SHARE = 3

local analysis
local analysisSource

local function Analyze()
    local database = Database()
    if type(database) ~= "table" then return nil end
    if analysis and analysisSource == database then return analysis end
    local clientData = EbonAPI.ClientData
    local catalog = EbonAPI.EchoCatalog
    local isRole = {}
    local families = clientData.Families()
    for i = 1, #families do isRole[families[i].key] = true end
    local total, counts, classOf = {}, {}, {}
    for _, data in pairs(database) do
        if type(data) == "table" and type(data.families) == "table" then
            local specKeys, roleKeys = {}, {}
            for _, family in ipairs(data.families) do
                if type(family) == "string" then
                    local role = clientData.Family(family)
                    if isRole[role] then
                        if role ~= "No family" then roleKeys[role] = true end
                    else
                        local className = family:match("^(.-) %- ")
                        if className then
                            specKeys[family] = true
                            classOf[family] = className:gsub("%s", ""):upper()
                        end
                    end
                end
            end
            for key in pairs(specKeys) do
                total[key] = (total[key] or 0) + 1
                local bucket = counts[key]
                if not bucket then
                    bucket = {}
                    counts[key] = bucket
                end
                for role in pairs(roleKeys) do
                    bucket[role] = (bucket[role] or 0) + 1
                end
            end
        end
    end
    local list, bySpec = {}, {}
    for key, token in pairs(classOf) do
        local roles = {}
        for role, count in pairs(counts[key]) do
            if count * ROLE_SHARE >= total[key] then roles[role] = true end
        end
        list[#list + 1] = { key = key, class = token }
        bySpec[key] = {
            class = token,
            bit = catalog and catalog.ClassBit(token),
            total = total[key],
            counts = counts[key],
            roles = roles,
        }
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    analysis = { list = list, bySpec = bySpec }
    analysisSource = database
    return analysis
end

local function MatchesSpecs(entry, set)
    local info = Analyze()
    local labels, roles = {}, {}
    for _, family in ipairs(entry.families or {}) do
        labels[family] = true
        roles[EbonAPI.ClientData.Family(family)] = true
    end
    local mask = entry.classMask
    for key in pairs(set) do
        if labels[key] then return true end
        local spec = info and info.bySpec[key]
        if spec and (not mask or mask == 0 or (spec.bit and bit.band(mask, spec.bit) ~= 0)) then
            for role in pairs(spec.roles) do
                if roles[role] then return true end
            end
        end
    end
    return false
end

local function MatchesTome(entry, database, mode)
    local spellId = entry.spellId
    if not IsTome(database, spellId) then return false end
    if mode == "tome" then return true end
    local found = EbonBuilds.Discovery.State(spellId)
    if found == "unknown" then return true end
    if mode == "tomeKnown" then return found == "found" end
    if found ~= "found" then return false end
    local disabled = IsDisabled(spellId)
    if mode == "enabled" then return not disabled end
    return disabled
end

local function MatchesHunt(entry)
    local wishlist = ns.Wishlist
    if not wishlist then return true end
    return wishlist.Has(entry.spellId) == true
end

function EchoFilter.Specs()
    local info = Analyze()
    return info and info.list or {}
end

function EchoFilter.SpecRoles()
    local info = Analyze()
    return info and info.bySpec or {}
end

local function SpecKey(set)
    local keys = {}
    for key in pairs(set) do keys[#keys + 1] = key end
    if #keys == 0 then return nil end
    table.sort(keys)
    return table.concat(keys, "|")
end

function EchoFilter.Get()
    return {
        text = state.text,
        classes = CopySet(state.classes),
        myClass = state.myClass,
        qualities = CopySet(state.qualities),
        families = CopySet(state.families),
        spec = SpecKey(state.specs),
        specs = CopySet(state.specs),
        tome = state.tome,
        discovery = state.discovery,
        hunt = state.hunt,
    }
end

local function SetFlags(target, value)
    if type(value) ~= "table" then return false end
    for k, v in pairs(value) do
        if v then target[k] = true end
    end
    return true
end

function EchoFilter.Set(key, value)
    if key == "text" then
        if type(value) ~= "string" then return nil, "FILTER_BAD_VALUE" end
        state.text = value:lower()
    elseif key == "classes" or key == "families" then
        local fresh = {}
        if not SetFlags(fresh, value) then return nil, "FILTER_BAD_VALUE" end
        state[key] = fresh
    elseif key == "qualities" then
        local fresh = {}
        if not SetFlags(fresh, value) then return nil, "FILTER_BAD_VALUE" end
        for q in pairs(fresh) do
            if type(q) ~= "number" or q < 0 or q > 3 then return nil, "FILTER_BAD_VALUE" end
        end
        state.qualities = fresh
    elseif key == "myClass" or key == "hunt" then
        if type(value) ~= "boolean" then return nil, "FILTER_BAD_VALUE" end
        state[key] = value
    elseif key == "spec" or key == "specs" then
        local fresh = {}
        if type(value) == "string" then
            fresh[value] = true
        elseif value ~= nil and not SetFlags(fresh, value) then
            return nil, "FILTER_BAD_VALUE"
        end
        state.specs = fresh
    elseif key == "tome" then
        if value ~= nil and not TOMES[value] then return nil, "FILTER_BAD_VALUE" end
        state.tome = value
    elseif key == "discovery" then
        if not DISCOVERY[value] then return nil, "FILTER_BAD_VALUE" end
        state.discovery = value
    else
        return nil, "FILTER_BAD_KEY"
    end
    Notify()
    return true
end

function EchoFilter.Reset()
    state = Defaults()
    Notify()
    return true
end

function EchoFilter.Apply(entries)
    local out = {}
    if type(entries) ~= "table" then return out end
    local text = state.text
    local classBits
    if next(state.classes) then classBits = ClassMaskBits(state.classes) end
    local mineBit = state.myClass and MyClassBit() or nil
    local qualities = next(state.qualities) and state.qualities or nil
    local families = next(state.families) and state.families or nil
    local specs = next(state.specs) and state.specs or nil
    local tome = state.tome
    local database = tome and Database() or nil
    local discovery = state.discovery
    local checkDiscovery = discovery ~= "all"
    for i = 1, #entries do
        local entry = entries[i]
        local ok = true
        if text ~= "" then
            ok = (entry.lname or entry.name:lower()):find(text, 1, true) ~= nil
        end
        if ok and classBits then ok = MatchesClass(entry, classBits) end
        if ok and mineBit then ok = MatchesClass(entry, { mineBit }) end
        if ok and qualities then ok = MatchesQuality(entry, qualities) end
        if ok and families then ok = MatchesFamilies(entry, families) end
        if ok and specs then ok = MatchesSpecs(entry, specs) end
        if ok and tome then ok = MatchesTome(entry, database, tome) end
        if ok and checkDiscovery then
            local found = EbonBuilds.Discovery.State(entry.spellId)
            if found ~= "unknown" then
                ok = found == discovery
            end
        end
        if ok and state.hunt then ok = MatchesHunt(entry) end
        if ok then out[#out + 1] = entry end
    end
    return out
end

function EchoFilter.Counts(entries)
    if type(entries) ~= "table" then return 0, 0 end
    local found = 0
    for i = 1, #entries do
        if EbonBuilds.Discovery.State(entries[i].spellId) == "found" then
            found = found + 1
        end
    end
    return found, #entries
end

function EchoFilter.OnChanged(fn)
    if type(fn) == "function" then
        callbacks[#callbacks + 1] = fn
    end
end
