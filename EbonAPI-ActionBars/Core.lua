local _, ns = ...

local Bars = {}
ns.Bars = Bars

ns.api = EbonAPI and EbonAPI:NewAddon("ActionBars", 2, 1, { icon = "INV_Misc_Gear_01" }) or nil

local OWNER = "ActionBars"
local MAX_BARS = 10
local SLOT_COUNT = 12

Bars.OWNER = OWNER
Bars.MAX_BARS = MAX_BARS
Bars.SLOT_COUNT = SLOT_COUNT

local TYPES = { spell = true, item = true, macro = true, companion = true }

local LAYOUT_DEFAULTS = {
  scale = 1.0,
  spacing = 4,
  columns = 12,
  shown = 12,
  showKeybind = true,
  visible = true,
}

local queue = {}
local store
local placed

local function getStore()
  if not store then
    store = EbonAPI.DB.store(OWNER, { character = { bars = {}, nextId = 1 } })
  end

  return store
end

function Bars.OrderList(reversed)
  local order = {}

  for index = 1, SLOT_COUNT do
    order[index] = reversed and (SLOT_COUNT + 1 - index) or index
  end

  return order
end

function Bars.Find(id)
  local bars = Bars.GetData().bars

  for position = 1, #bars do
    if bars[position].id == id then
      return bars[position], position
    end
  end

  return nil
end

local findBar = Bars.Find

local function hasContent(bar)
  for index = 1, SLOT_COUNT do
    if bar.slots[index] then
      return true
    end
  end

  return false
end

local function validOrder(order)
  if type(order) ~= "table" or #order ~= SLOT_COUNT then
    return false
  end

  local seen = {}

  for index = 1, SLOT_COUNT do
    local value = order[index]

    if type(value) ~= "number" or value < 1 or value > SLOT_COUNT or value ~= math.floor(value) or seen[value] then
      return false
    end

    seen[value] = true
  end

  return true
end

local function validLayoutValue(key, value)
  if key == "scale" then
    return type(value) == "number" and value > 0
  end

  if key == "spacing" then
    return type(value) == "number" and value >= 0
  end

  if key == "columns" or key == "shown" then
    return type(value) == "number" and value == math.floor(value) and value >= 1 and value <= SLOT_COUNT
  end

  if key == "showKeybind" or key == "visible" then
    return type(value) == "boolean"
  end

  if key == "order" then
    return validOrder(value)
  end

  return false
end

local function pendingCreates()
  local total = 0

  for index = 1, #queue do
    if queue[index].op == "create" then
      total = total + 1
    end
  end

  return total
end

local function doCreate()
  local data = Bars.GetData()

  if #data.bars >= MAX_BARS then
    return nil, "max"
  end

  local id = data.nextId
  data.nextId = id + 1

  local bar = { id = id, hidden = false, slots = {}, order = Bars.OrderList(false) }

  EbonAPI.Lib.copyShallow(LAYOUT_DEFAULTS, bar)

  for index = 1, SLOT_COUNT do
    bar.slots[index] = false
  end

  data.bars[#data.bars + 1] = bar

  return id
end

local function hideFrame(id)
  local buttons = ns.Buttons
  local frame = buttons and buttons.FrameName and _G[buttons.FrameName(id)]

  if frame then
    frame:Hide()
  end
end

local function doRemove(id)
  local bar, position = findBar(id)

  if not bar then
    return nil
  end

  hideFrame(id)

  if hasContent(bar) then
    bar.hidden = true
    return "hidden"
  end

  table.remove(Bars.GetData().bars, position)

  return "deleted"
end

local function doShow(id)
  local bar = findBar(id)

  if not bar then
    return false
  end

  bar.hidden = false

  if ns.Buttons and ns.Buttons.Refresh then
    ns.Buttons.Refresh(id)
  end

  return true
end

local function doSetLayout(id, layout)
  local bar = findBar(id)

  if not bar or type(layout) ~= "table" then
    return false
  end

  for key, value in pairs(layout) do
    if not validLayoutValue(key, value) then
      return false
    end
  end

  for key, value in pairs(layout) do
    if key == "order" then
      local order = {}

      for index = 1, SLOT_COUNT do
        order[index] = value[index]
      end

      bar.order = order
    else
      bar[key] = value
    end
  end

  return true
end

local operations = {
  create = doCreate,
  remove = doRemove,
  show = doShow,
  setlayout = doSetLayout,
}

function Bars.IsValidType(t)
  return TYPES[t] == true
end

function Bars.GetData()
  local current = getStore()

  return current.char or current:Rebind().char
end

function Bars.Count()
  return #Bars.GetData().bars
end

function Bars.Queue(op, ...)
  local handler = type(op) == "function" and op or operations[op]

  if not handler then
    return false
  end

  if InCombatLockdown() then
    queue[#queue + 1] = { op = op, handler = handler, args = { n = select("#", ...), ... } }
    return true
  end

  handler(...)

  return true
end

function Bars.Flush()
  if InCombatLockdown() then
    return 0
  end

  local pending = queue
  queue = {}

  for index = 1, #pending do
    local entry = pending[index]

    entry.handler(unpack(entry.args, 1, entry.args.n))
  end

  return #pending
end

function Bars.Create()
  if InCombatLockdown() then
    if Bars.Count() + pendingCreates() >= MAX_BARS then
      return nil, "max"
    end

    Bars.Queue("create")

    return nil, "queued"
  end

  return doCreate()
end

local function run(op, missing, queued, id, ...)
  if not findBar(id) then
    return missing
  end

  if InCombatLockdown() then
    Bars.Queue(op, id, ...)
    return queued
  end

  return operations[op](id, ...)
end

function Bars.Remove(id)
  return run("remove", nil, "queued", id)
end

function Bars.Show(id)
  return run("show", false, true, id)
end

function Bars.SetLayout(id, layout)
  return run("setlayout", false, true, id, layout)
end

function Bars.GetSlot(id, index)
  local bar = findBar(id)

  if not bar or type(index) ~= "number" or index < 1 or index > SLOT_COUNT then
    return nil
  end

  return bar.slots[index] or nil
end

function Bars.SetSlot(id, index, content)
  local bar = findBar(id)

  if not bar then
    return false, "bar"
  end

  if type(index) ~= "number" or index < 1 or index > SLOT_COUNT or index ~= math.floor(index) then
    return false, "index"
  end

  if content == nil then
    bar.slots[index] = false
    Bars.PlacedChanged()
    return true
  end

  if type(content) ~= "table" or not Bars.IsValidType(content.type) then
    return false, "type"
  end

  bar.slots[index] = EbonAPI.Lib.copyShallow(content)
  Bars.PlacedChanged()

  return true
end

local function buildPlaced()
  placed = {}
  local bars = Bars.GetData().bars

  for position = 1, #bars do
    local slots = bars[position].slots

    for index = 1, SLOT_COUNT do
      local content = slots[index]

      if content and content.type == "spell" then
        if content.id then
          placed[content.id] = true
        end

        local name = content.id and GetSpellInfo(content.id) or content.name

        if name then
          placed[name] = true
        end
      end
    end
  end
end

function Bars.IsSpellPlaced(spellId)
  if not spellId then
    return false
  end

  if not placed then
    buildPlaced()
  end

  if placed[spellId] then
    return true
  end

  local name = GetSpellInfo(spellId)

  return name ~= nil and placed[name] == true
end

function Bars.PlacedChanged()
  placed = nil

  if SpellBookFrame and SpellBookFrame:IsShown() and SpellButton_UpdateBorderOverlay then
    for index = 1, SPELLS_PER_PAGE or 12 do
      local button = _G["SpellButton" .. index]

      if button then
        SpellButton_UpdateBorderOverlay(button)
      end
    end
  end
end

if type(SpellButton_UpdateBorderOverlay) == "function" then
  hooksecurefunc("SpellButton_UpdateBorderOverlay", function(self)
    local overlay = self and self.BorderOverlay

    if overlay and self.data and overlay:IsShown() and Bars.IsSpellPlaced(self.data) then
      overlay:Hide()
    end
  end)
end
