local NS = SkillTreeAutoLoad
local tostring = tostring

-- Arbre dense (W1) : données statiques de l'arbre, lues dans la TalentDatabase de PE (jamais
-- recopiées) et indexées une fois dans Build() : nœuds, liens, bornes, hubs de classe, grille
-- spatiale. Aucune boucle sur les nœuds hors de Build().
NS.Dense = NS.Dense or {}
local Data = {}
NS.Dense.Data = Data

NS.Text = function(key, tokens)
    local text = NS.L[key]
    for name, value in pairs(tokens or {}) do
        text = text:gsub("{" .. name .. "}", function() return tostring(value) end)
    end
    return text
end

-- Taille d'une cellule de la grille : celle du culling de PE (CULL_CELL, skillTree.lua:2475).
local GRID_CELL = 96
-- Clé de texte (NS.L) rendue quand la TalentDatabase est absente.
NS.REASON_UNAVAILABLE = "DENSE_UNAVAILABLE"
local REASON_UNAVAILABLE = NS.REASON_UNAVAILABLE
-- Index du 3e retour de GetSpellInfo = chemin de l'icône.
local ICON_FIELD = 3
local floor, min, max = math.floor, math.min, math.max

Data.CELL = GRID_CELL
Data.Nodes = {}
Data.ById = {}
Data.Links = {}
Data.Hubs = {}
Data.Currencies = {}
Data.CurrencyCount = {}
Data.Bounds = nil
Data.Grid = {}

local built = false
local cellsNode = {}   -- clé de cellule -> liste d'ids de nœuds
local cellsLink = {}   -- clé de cellule -> liste d'index de liens
local gridMinX, gridMinY, gridCols, gridRows = 0, 0, 1, 1
local linkStamp, stampCounter = {}, 0
local iconCache, nameCache = {}, {}

local function CellOf(x, y)
    return floor(x / GRID_CELL), floor(y / GRID_CELL)
end

local function CellKey(cx, cy)
    return (cx - gridMinX) * gridRows + (cy - gridMinY)
end

local function Push(map, key, value)
    local list = map[key]
    if not list then
        list = {}
        map[key] = list
    end
    list[#list + 1] = value
end

-- Cellules couvertes par un rectangle, bornées à la grille.
local function CellRange(x0, y0, x1, y1)
    if x0 > x1 then x0, x1 = x1, x0 end
    if y0 > y1 then y0, y1 = y1, y0 end
    local ax, ay = CellOf(x0, y0)
    local bx, by = CellOf(x1, y1)
    return max(ax, gridMinX), max(ay, gridMinY), min(bx, gridMinX + gridCols - 1), min(by, gridMinY + gridRows - 1)
end

-- Rectangle donné en 4 nombres ou en table {x0,y0,x1,y1} / {x0=,y0=,x1=,y1=}.
local function ReadRect(a, b, c, d)
    if type(a) == "table" then
        return a.x0 or a[1], a.y0 or a[2], a.x1 or a[3], a.y1 or a[4]
    end
    return a, b, c, d
end

local function BuildHubs(db)
    local hubs = db.classHubs
    if type(hubs) ~= "table" then return end
    local ids = {}
    for classId in pairs(hubs) do ids[#ids + 1] = classId end
    table.sort(ids)
    for i = 1, #ids do
        local hub = hubs[ids[i]]
        Data.Hubs[i] = { classId = ids[i], name = hub.name, x = hub.x, y = hub.y, color = hub.color, token = hub.token }
    end
end

local function BuildCurrencies()
    local known = {}
    local order = NS.Cost and NS.Cost.CURRENCIES or {}
    for i = 1, #order do
        local key = order[i].key
        if Data.CurrencyCount[key] then
            known[key] = true
            Data.Currencies[#Data.Currencies + 1] = key
        end
    end
    local extra = {}
    for key in pairs(Data.CurrencyCount) do
        if not known[key] then extra[#extra + 1] = key end
    end
    table.sort(extra)
    for i = 1, #extra do Data.Currencies[#Data.Currencies + 1] = extra[i] end
end

-- Construit les index. Renvoie true, ou nil + clé de texte si la TalentDatabase manque.
function Data.Build()
    if built then return true end
    local db = EbonAPI and EbonAPI.Ebonhold and EbonAPI.Ebonhold.TalentDatabase()
    db = db and db[0]
    if not (db and type(db.nodes) == "table") then return nil, REASON_UNAVAILABLE end

    local nodes, byId = {}, {}
    local minX, minY, maxX, maxY
    for i = 1, #db.nodes do
        local node = db.nodes[i]
        nodes[#nodes + 1] = node
        byId[node.id] = node
        local x, y = node.x or 0, node.y or 0
        if not minX then
            minX, minY, maxX, maxY = x, y, x, y
        else
            minX, minY, maxX, maxY = min(minX, x), min(minY, y), max(maxX, x), max(maxY, y)
        end
        local currency = node.currency or "ash"
        Data.CurrencyCount[currency] = (Data.CurrencyCount[currency] or 0) + 1
    end
    Data.Nodes, Data.ById = nodes, byId
    Data.Bounds = { minX = minX or 0, minY = minY or 0, maxX = maxX or 0, maxY = maxY or 0 }

    local cx0, cy0 = CellOf(Data.Bounds.minX, Data.Bounds.minY)
    local cx1, cy1 = CellOf(Data.Bounds.maxX, Data.Bounds.maxY)
    gridMinX, gridMinY = cx0, cy0
    gridCols, gridRows = cx1 - cx0 + 1, cy1 - cy0 + 1

    for i = 1, #nodes do
        local node = nodes[i]
        local cx, cy = CellOf(node.x or 0, node.y or 0)
        Push(cellsNode, CellKey(cx, cy), node.id)
    end

    -- Liens : ni extrémité inconnue ni longueur nulle (rien à tracer).
    local links = {}
    local source = db.links or {}
    for i = 1, #source do
        local a, b = byId[source[i][1]], byId[source[i][2]]
        if a and b and (a.x ~= b.x or a.y ~= b.y) then
            local link = { a = a.id, b = b.id, x0 = a.x, y0 = a.y, x1 = b.x, y1 = b.y }
            link[1], link[2] = a.id, b.id
            links[#links + 1] = link
            local ax, ay, bx, by = CellRange(link.x0, link.y0, link.x1, link.y1)
            for cx = ax, bx do
                for cy = ay, by do Push(cellsLink, CellKey(cx, cy), #links) end
            end
        end
    end
    Data.Links = links

    BuildHubs(db)
    BuildCurrencies()
    built = true
    return true
end

-- Ids des nœuds dont la position est dans le rectangle (bornes comprises).
function Data.Grid:Query(x0, y0, x1, y1)
    x0, y0, x1, y1 = ReadRect(x0, y0, x1, y1)
    local out = {}
    if not (built and x0 and y0 and x1 and y1) then return out end
    if x0 > x1 then x0, x1 = x1, x0 end
    if y0 > y1 then y0, y1 = y1, y0 end
    local ax, ay, bx, by = CellRange(x0, y0, x1, y1)
    local byId = Data.ById
    for cx = ax, bx do
        for cy = ay, by do
            local list = cellsNode[CellKey(cx, cy)]
            if list then
                for i = 1, #list do
                    local node = byId[list[i]]
                    local x, y = node.x or 0, node.y or 0
                    if x >= x0 and x <= x1 and y >= y0 and y <= y1 then out[#out + 1] = node.id end
                end
            end
        end
    end
    return out
end

-- Liens (entrées de Data.Links) dont la boîte englobante touche le rectangle.
function Data.LinksIn(x0, y0, x1, y1)
    x0, y0, x1, y1 = ReadRect(x0, y0, x1, y1)
    local out = {}
    if not (built and x0 and y0 and x1 and y1) then return out end
    if x0 > x1 then x0, x1 = x1, x0 end
    if y0 > y1 then y0, y1 = y1, y0 end
    stampCounter = stampCounter + 1
    local ax, ay, bx, by = CellRange(x0, y0, x1, y1)
    local links = Data.Links
    for cx = ax, bx do
        for cy = ay, by do
            local list = cellsLink[CellKey(cx, cy)]
            if list then
                for i = 1, #list do
                    local index = list[i]
                    if linkStamp[index] ~= stampCounter then
                        linkStamp[index] = stampCounter
                        local link = links[index]
                        if max(link.x0, link.x1) >= x0 and min(link.x0, link.x1) <= x1
                            and max(link.y0, link.y1) >= y0 and min(link.y0, link.y1) <= y1 then
                            out[#out + 1] = link
                        end
                    end
                end
            end
        end
    end
    return out
end

local function FirstSpell(id)
    local node = Data.ById[id]
    return node and node.spells and node.spells[1]
end

-- Icône (3e retour de GetSpellInfo du 1er sort, comme PE) ; nil tant que le client l'ignore.
function Data.IconOf(id)
    local cached = iconCache[id]
    if cached then return cached end
    local spell = FirstSpell(id)
    if not spell then return nil end
    local icon = select(ICON_FIELD, GetSpellInfo(spell))
    if icon then iconCache[id] = icon end
    return icon
end

function Data.NameOf(id)
    local cached = nameCache[id]
    if cached then return cached end
    local spell = FirstSpell(id)
    local name = spell and GetSpellInfo(spell)
    if name then
        nameCache[id] = name
        return name
    end
    local node = Data.ById[id]
    return node and node.name or nil
end
