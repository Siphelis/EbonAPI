local _, ns = ...

local L = ns.L

local KeyOf = EbonBuilds.Matrix.Key

local databaseMissing = false

local function Database()
  local E = EbonAPI and EbonAPI.EchoCatalog
  local database = E and E.Database()
  if database then
    if databaseMissing then
      databaseMissing = false
      ns.api:Restore("WISHLIST.NO_DATABASE")
    end
  elseif not databaseMissing then
    databaseMissing = true
    ns.api:Degrade(ns.api:Problem("WISHLIST.NO_DATABASE"))
  end
  return database
end

local function Entry(spellId)
  local db = Database()
  if not db then return nil end
  return db[spellId]
end

local function QualityOf(spellId)
  local data = Entry(spellId)
  return (data and data.quality) or 0
end

local wanted     = {}
local count      = 0
local generation = 0
local shown      = true

local Wishlist = {}
ns.Wishlist = Wishlist

function Wishlist.Has(spellId)
  if not spellId then return false end
  local data = Entry(spellId)
  local floor = wanted[KeyOf(spellId)]
  if not floor then return false end
  return ((data and data.quality) or 0) >= floor
end

function Wishlist.Count() return count end

function Wishlist.Shown(spellId)
  return shown and Wishlist.Has(spellId)
end

function Wishlist.SetShown(on)
  on = on and true or false
  if shown == on then return end
  shown = on
  generation = generation + 1
end

local loaded = false

local function Persist()
  local db = EbonAPIEbonBuildsCharDB
  if not db or not loaded then return end
  local saved = db.huntSelection or {}
  local same, n = true, 0
  for key, floor in pairs(saved) do
    n = n + 1
    if wanted[key] ~= floor then same = false end
  end
  if same and n == count then return end
  if count == 0 then
    db.huntSelection = nil
    return
  end
  local copy = {}
  for key, floor in pairs(wanted) do copy[key] = floor end
  db.huntSelection = copy
end

local function Touch()
  generation = generation + 1
  if not loaded then Wishlist.Load() end
  Persist()
  local notify = ns.OnWishlistChanged
  if notify then notify() end
end

local function Survey(keys)
  local out = {}
  local db = Database()
  if not db then return out end

  for spellId, data in pairs(db) do
    local key = KeyOf(spellId)
    if keys[key] then
      local q = data.quality or 0
      local rec = out[key]
      if not rec then
        rec = { sample = spellId, sampleQ = q, qualities = {} }
        out[key] = rec
      elseif q < rec.sampleQ then
        rec.sample, rec.sampleQ = spellId, q
      end
      local list, seen = rec.qualities, false
      for i = 1, #list do
        if list[i] == q then seen = true break end
      end
      if not seen then
        local at = #list + 1
        for i = 1, #list do
          if q < list[i] then at = i break end
        end
        table.insert(list, at, q)
      end
    end
  end
  return out
end

function Wishlist.Toggle(spellId)
  if not spellId then return false end
  local key = KeyOf(spellId)

  if wanted[key] then
    wanted[key] = nil
    count = count - 1
  else
    local rec = Survey({ [key] = true })[key]
    wanted[key] = (rec and rec.qualities[1]) or QualityOf(spellId)
    count = count + 1
  end
  Touch()
  return wanted[key] ~= nil
end

function Wishlist.SetFloor(key, quality)
  if key == nil or wanted[key] == nil then return false end
  if wanted[key] == quality then return false end
  wanted[key] = quality
  Touch()
  return true
end

function Wishlist.Remove(spellId)
  if not spellId then return false end
  local key = KeyOf(spellId)
  if wanted[key] == nil then return false end
  wanted[key] = nil
  count = count - 1
  Touch()
  return true
end

function Wishlist.Load()
  local db = EbonAPIEbonBuildsCharDB
  if not db or not Database() then return end
  local saved = db.huntSelection or {}
  local known = Survey(saved)
  for key, floor in pairs(saved) do
    if known[key] and type(floor) == "number" and wanted[key] == nil then
      wanted[key] = floor
      count = count + 1
    end
  end
  generation = generation + 1
  loaded = true
  Persist()
end

function Wishlist.Armed()
  local rows = {}
  local survey = Survey(wanted)
  for key, floor in pairs(wanted) do
    local rec = survey[key]
    local sample = rec and rec.sample or key
    rows[#rows + 1] = {
      key       = key,
      floor     = floor,
      sample    = sample,
      qualities = rec and rec.qualities or { floor },
      name      = GetSpellInfo(sample) or ("Echo " .. tostring(sample)),
    }
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function Wishlist.CommonFloor()
  local common = nil
  for _, floor in pairs(wanted) do
    if common == nil then common = floor
    elseif common ~= floor then return nil end
  end
  return common
end

local SCROLL_NAMES = {
  "ProjectEbonholdEchoJournalScroll",
  "ProjectEbonholdEchoJournalMyRunScroll",
}

local POLL = 0.15

local MARK_TEXTURE = "Interface\\Buttons\\CheckButtonHilight"

local grids = {}
for i = 1, #SCROLL_NAMES do
  grids[i] = {
    name = SCROLL_NAMES[i], scroll = nil, child = nil,
    buttons = {}, n = 0, rawN = -1, probe = 0,
  }
end

local function OrbArmed()
  local orb = EbonAPI.Ebonhold.Orbs()
  return (orb and orb.IsArmed and orb.IsArmed()) and true or false
end

function Wishlist.Hint(button)
  local id = button.spellId
  if not id or not button._eorWrapper or button:GetScript("OnClick") ~= button._eorWrapper or OrbArmed() then
    return nil
  end
  return wanted[KeyOf(id)] and L.HUNT_UNMARK or L.HUNT_MARK
end

function Wishlist.StyleMark(mark)
  mark:SetTexture(MARK_TEXTURE)
  mark:SetBlendMode("ADD")
  mark:SetVertexColor(1, 0.82, 0, 0.9)
end

local function EnsureMark(button)
  local mark = button._eorMark
  if mark then return mark end

  local anchor = button.icon or button
  mark = button:CreateTexture(nil, "OVERLAY")
  Wishlist.StyleMark(mark)
  mark:SetPoint("TOPLEFT", anchor, "TOPLEFT", -2, 2)
  mark:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 2, -2)
  mark:Hide()

  button._eorMark = mark
  return mark
end

local function HookClick(button)
  if button._eorWrapper and button:GetScript("OnClick") == button._eorWrapper then
    return
  end

  local original = button:GetScript("OnClick")
  if original == button._eorWrapper then original = button._eorOriginal end
  button._eorOriginal = original

  local wrapper = function(self, mouseButton, down)
    local id = self.spellId
    if id and mouseButton == "LeftButton" and IsControlKeyDown() and not OrbArmed() then
      Wishlist.Toggle(id)
      local enter = self:GetScript("OnEnter")
      if enter then enter(self) end
    else
      local passthrough = self._eorOriginal
      if passthrough then passthrough(self, mouseButton, down) end
    end
    local after = ns.OnJournalClick
    if after then after(self) end
  end

  button._eorWrapper = wrapper
  button:SetScript("OnClick", wrapper)
end

local function HookEnter(button)
  if button._eorEnter then return end
  local hook = ns.OnJournalEnter
  if not hook then return end
  button._eorEnter = true
  button:HookScript("OnEnter", hook)
end

local function Rebuild(grid)
  local child = grid.scroll:GetScrollChild()
  if not child then
    grid.child, grid.n, grid.rawN = nil, 0, -1
    return
  end

  local n = child:GetNumChildren()
  if child == grid.child and n == grid.rawN then return end
  grid.child, grid.rawN = child, n

  local kids = { child:GetChildren() }
  local buttons, count = grid.buttons, 0
  for i = 1, #kids do
    local b = kids[i]
    if b.GetObjectType and b:GetObjectType() == "Button" then
      count = count + 1
      buttons[count] = b
    end
  end
  for i = count + 1, #buttons do buttons[i] = nil end
  grid.n = count
end

local function Paint(grid)
  local buttons, n = grid.buttons, grid.n
  if n == 0 then return end

  grid.probe = (grid.probe % n) + 1
  HookClick(buttons[grid.probe])

  for i = 1, n do
    local b = buttons[i]
    local id = b.spellId
    if b._eorId ~= id then
      b._eorId = id
      HookClick(b)
      HookEnter(b)
      b._eorGen = nil
    end
    if b._eorGen ~= generation then
      b._eorGen = generation
      if id and Wishlist.Shown(id) then
        EnsureMark(b):Show()
      elseif b._eorMark then
        b._eorMark:Hide()
      end
    end
  end
end

local function Sweep(grid)
  Rebuild(grid)
  Paint(grid)
end

local function JournalRoot(frame)
  local f = frame
  while f do
    local parent = f:GetParent()
    if not parent or parent == UIParent then return f end
    f = parent
  end
  return frame
end

local function AttachSweeper(grid)
  local f = CreateFrame("Frame", nil, grid.scroll)
  ns.api:Track("Journal sweep (" .. (grid.name:match("Journal(%a+)$") or grid.name) .. ")", f)
  f.elapsed = 0
  local sweep = function() Sweep(grid) end
  f:SetScript("OnUpdate", function(self, delta)
    self.elapsed = self.elapsed + delta
    if self.elapsed < POLL then return end
    self.elapsed = 0
    ns.api:Guard("WISHLIST.JOURNAL_SWEEP", sweep)
  end)
  grid.sweeper = f
end

local function EchoesVisible()
  for i = 1, #grids do
    local scroll = grids[i].scroll
    if scroll and scroll:IsVisible() then return true end
  end
  return false
end

local function NotifyEchoes()
  local f = ns.OnEchoesVisible
  if f then f(EchoesVisible()) end
end

local function Discover()
  local wired = 0
  for i = 1, #grids do
    local grid = grids[i]
    if not grid.sweeper then
      local scroll = _G[grid.name]
      if scroll then
        grid.scroll = scroll
        AttachSweeper(grid)
        local found = ns.OnJournalFound
        if found then found(JournalRoot(scroll)) end
        scroll:HookScript("OnShow", NotifyEchoes)
        scroll:HookScript("OnHide", NotifyEchoes)
        NotifyEchoes()
      end
    end
    if grid.sweeper then wired = wired + 1 end
  end
  return wired >= #grids
end

local discovery = EbonBuilds.Timer.New("Journal discovery")
local wiredAll = false

local function OnJournalShow()
  if wiredAll then return end
  EbonBuilds.Timer.Arm(discovery, 0, function() wiredAll = Discover() end)
end

local journal = EbonAPI.Ebonhold.EchoJournal()
if journal and journal.Show then
  hooksecurefunc(journal, "Show", OnJournalShow)
  if _G[SCROLL_NAMES[1]] then OnJournalShow() end
elseif EbonAPI.Ebonhold.IsPresent() then
  ns.api:Degrade(ns.api:Problem("WISHLIST.NO_JOURNAL"))
end
