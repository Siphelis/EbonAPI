local _, ns = ...

local CONSUME_DELAY = 0.4
local PICK_TIMEOUT = 8.0
local TICK = 0.1
local SETTLE_WINDOW = 1.0
local CHARGE_PROBE_INTERVAL = 3.0

local HUNT_CYCLE = 0.5
local DEFAULT_BUDGET = 10

local BUTTON_WIDTH = 190
local HUNT_BUTTON_WIDTH = 150
local RARITY_WIDTH = 28
local BUTTON_GAP = 8
local BUTTON_HEIGHT = 32
local BUTTON_Y = -8

local function QualityColor(q)
  local hex = EbonBuilds.Const.QualityHex(q)
  return hex and ("|cff" .. hex) or nil
end

local L = ns.L
local R = ns.C.R

local function N(n)
  return EbonAPI.Format.number(n)
end

local function S(n)
  return n == 1 and "" or L.PLURAL
end

local PE = nil
local container = nil
local button = nil
local huntButton = nil
local uiParent = nil
local subscribed = false

local state = "idle"
local pickSpellId = nil
local pickName = nil

local hunt = {
  armed  = false,
  active = false,
  budget = 0,
  spent  = 0,
  nextAt = 0,
  directInFlight = false,
}
ns.hunt = hunt

EbonBuilds.Reroll = EbonBuilds.Reroll or {}
function EbonBuilds.Reroll.IsHunting()
  return (hunt.armed or hunt.active) and true or false
end

local huntListeners = {}
local lastHunting = EbonBuilds.Reroll.IsHunting()

local function NotifyHunt()
  local now = EbonBuilds.Reroll.IsHunting()
  if now == lastHunting then return end
  lastHunting = now
  for _, fn in ipairs(huntListeners) do fn() end
end

function EbonBuilds.Reroll.OnHuntChange(fn)
  if type(fn) ~= "function" then return end
  huntListeners[#huntListeners + 1] = fn
end

local lastJudged = nil

local huntCycleInFlight = false

local orbMultiplier = 1
ns.selfCall = false

local function Multiplier()
  local n = orbMultiplier
  if type(n) ~= "number" or n < 1 then return 1 end
  return math.floor(n)
end

local FLOW = {
  ["REROLL.BUSY"] = L.BUSY,
  ["REROLL.NO_CHOICE"] = L.NO_CHOICE,
  ["REROLL.PICK_IN_FLIGHT"] = L.PICK_IN_FLIGHT,
  ["HUNT.RUNNING_ALREADY"] = L.HUNT_RUNNING_ALREADY,
}

local function PlainName(spellId)
  return GetSpellInfo(spellId) or L.THAT_ECHO
end

local function Blocked(code, a, b)
  local facts
  if code == "REROLL.NOT_ENOUGH_ORBS" then
    facts = { cost = a, charges = b }
  elseif code == "HUNT.BUDGET_TOO_LOW" then
    facts = { cost = a, budget = b }
  end
  return ns.api:Problem(code, facts)
end

local function Why(code, a, b)
  return FLOW[code] or ns.api:ProblemText(Blocked(code, a, b))
end

local function Refuse(code, a, b)
  if not FLOW[code] then ns.api:Report(Blocked(code, a, b)) end
end

local deadFor = nil

local Refresh

local function OpenHuntWindow()
  local hw = EbonBuilds.HuntWindow
  if hw and hw.Open then hw.Open() end
end

local function CloseHuntWindow()
  local hw = EbonBuilds.HuntWindow
  if hw and hw.Close then hw.Close() end
end

local function RefreshHuntWindow()
  local hw = EbonBuilds.HuntWindow
  if hw and hw.Refresh then hw.Refresh() end
end

local Timer = EbonBuilds.Timer
local Arm, Cancel = Timer.Arm, Timer.Cancel

local stateTimer  = Timer.New("Hunt: pick then spend")
local probeTimer  = Timer.New("Hunt: orb count probe")
local huntTimer   = Timer.New("Hunt: cycle floor")
local unfoldTimer = Timer.New("Hunt: unfold")
local Unfold

local settleTimer = Timer.New("Hunt: orb offer settle")
local settleUntil = 0

local function SettleTick()
  if GetTime() >= settleUntil then return end
  Refresh()
  Arm(settleTimer, TICK, SettleTick)
end

local function ArmSettle()
  settleUntil = GetTime() + SETTLE_WINDOW
  Arm(settleTimer, TICK, SettleTick)
end

local SS_OFFER, SS_GRANTED, SS_ORBS = 16, 18, 1220

local function State()
  return ns.api:State()
end

local snapshots = {}

local function Snapshot(key, op, read)
  local source = ns.api:ServerState(op)
  local slot = snapshots[key]
  if not slot then
    slot = {}
    snapshots[key] = slot
  end
  if source == nil then
    slot.source, slot.value = nil, nil
  elseif source ~= slot.source then
    slot.source, slot.value = source, read()
  end
  return slot.value
end

local function ReadOffer()
  local offer = State().GetOffer()
  return offer and offer.choices
end

local function Choices()
  return Snapshot("offer", SS_OFFER, ReadOffer)
end

local function ReadLocked()
  local set = {}
  local value = State().GetLocked()
  for _, p in ipairs(value and value.perks or {}) do set[p.spellId] = true end
  return set
end

local function ReadOwned()
  local map = {}
  local value = State().GetOwned()
  for _, p in ipairs(value and value.perks or {}) do map[p.spellId] = p end
  return map
end

local function ReadOrbs()
  local orbs = State().GetOrbs()
  return orbs and (orbs.charges or 0) or nil
end

local function Charges()
  return Snapshot("orbs", SS_ORBS, ReadOrbs) or 0
end

local function ChargesKnown()
  return Snapshot("orbs", SS_ORBS, ReadOrbs) ~= nil
end

local OnProbeExpired

local function ProbeCharges()
  if ChargesKnown() then
    Cancel(probeTimer)
    return
  end
  if probeTimer:IsShown() then return end
  EbonAPI.Actions.RequestOrbCharges()
  Arm(probeTimer, CHARGE_PROBE_INTERVAL, OnProbeExpired)
end

function OnProbeExpired()
  if ChargesKnown() then Refresh() else ProbeCharges() end
end

local function ColoredName(spellId, quality)
  local name = GetSpellInfo(spellId) or ("Echo " .. tostring(spellId))
  return (QualityColor(quality or 0) or "|cffFFFFFF") .. name .. "|r"
end

local function QualityName(q)
  local card = EbonAPI.ClientData.Quality(q)
  local name = card and card.name or tostring(q)
  return (QualityColor(q) or "") .. name .. R
end

local function Wanted(spellId)
  local wl = ns.Wishlist
  return (wl and wl.Has(spellId)) and true or false
end

local function WantedCount()
  local wl = ns.Wishlist
  return (wl and wl.Count()) or 0
end

local function AutoAcceptOn()
  return State().GetAutoAcceptLoadoutEchoes() and true or false
end

local function FindWanted(choices)
  if not choices or WantedCount() == 0 then return nil end
  for i = 1, #choices do
    local c = choices[i]
    if c.spellId and Wanted(c.spellId) then return c end
  end
  return nil
end

local function IsPermanent(spellId)
  local set = Snapshot("locked", SS_GRANTED, ReadLocked)
  return set ~= nil and set[spellId] == true
end

local function OwnedStacks(spellId)
  local map = Snapshot("owned", SS_GRANTED, ReadOwned)
  local perk = map and map[spellId]
  if not perk then return 0, nil end
  return perk.stack or 0, perk.maxStack
end

local function ChooseSacrifice(choices)
  if not choices then return nil end

  local best, bestScore
  for _, c in ipairs(choices) do
    local spellId = c.spellId
    local eligible = spellId and not Wanted(spellId) and not IsPermanent(spellId)
    if eligible then
      local owned, maxStack = OwnedStacks(spellId)
      eligible = not (maxStack and owned >= maxStack)
    end
    if eligible then
      local score = c.quality or 0
      if c.memory then score = score + 1000 end
      if c.frozen then score = score + 500 end
      if c.carried then score = score + 250 end
      if not bestScore or score < bestScore then
        best, bestScore = c, score
      end
    end
  end
  return best
end

local function CanReroll()
  if state ~= "idle" then return nil, "REROLL.BUSY" end

  local choices = Choices()
  if not choices or #choices == 0 then return nil, "REROLL.NO_CHOICE" end

  if State().GetPendingPick() then
    return nil, "REROLL.PICK_IN_FLIGHT"
  end

  local pick = ChooseSacrifice(choices)
  if not pick then
    return nil, "REROLL.NONE_FORGETTABLE", true
  end

  if not ChargesKnown() then return nil, "REROLL.CHARGES_UNKNOWN" end
  local cost = Multiplier()
  if Charges() < cost then
    return nil, "REROLL.NOT_ENOUGH_ORBS", false, cost, Charges()
  end

  return pick
end

local function HuntStop(key, args, foundId)
  if not hunt.active then return end
  local cost = Multiplier()
  hunt.endReason = key
  hunt.endArgs = args
  hunt.lastDraws = math.floor(hunt.spent / cost)
  hunt.lastSpent = hunt.spent
  hunt.lastBudget = hunt.budget
  hunt.active = false
  NotifyHunt()
  hunt.budget = 0
  huntCycleInFlight = false
  hunt.directInFlight = false
  lastJudged = nil

  local spent = hunt.spent
  hunt.spent = 0

  Cancel(huntTimer)

  if foundId and ns.Wishlist then ns.Wishlist.Remove(foundId) end
  if key then
    local reason = args and string.format(L[key], unpack(args)) or L[key]
    ns.api:Notify(reason .. string.format(L.HUNT_SPENT, N(spent), S(spent)))
  end
  RefreshHuntWindow()
  Refresh()
  if not foundId and EbonAPI.Ebonhold.IsOfferPending() == true then
    Arm(unfoldTimer, 0, Unfold)
  end
end

local function FailHuntCycle(key, args)
  if not huntCycleInFlight then return end
  huntCycleInFlight = false
  HuntStop(key, args, false)
end

local function Fail(problem, huntReason, huntArgs)
  if problem then ns.api:Report(problem) end
  FailHuntCycle(huntReason, huntArgs)
end

local function Abort(problem)
  state = "idle"
  pickSpellId, pickName = nil, nil
  Cancel(stateTimer)
  Fail(problem, "HUNT_INTERRUPTED")
  Refresh()
end

local function OnPickTimeout()
  Abort(ns.api:Problem("REROLL.PICK_TIMED_OUT", { echo = PlainName(pickSpellId), seconds = PICK_TIMEOUT }))
end

local function SendHuntSpend(spellId)
  if IsPermanent(spellId) then
    return false, "wentPermanent", nil, nil, ns.api:Problem("REROLL.WENT_PERMANENT", { echo = PlainName(spellId) }), "HUNT_WENT_PERMANENT"
  end

  local cost = Multiplier()
  if Charges() < cost then
    return false, "shortOrbs", cost, nil,
      ns.api:Problem("REROLL.SPEND_SHORT_ORBS", { echo = PlainName(spellId), cost = cost, charges = Charges() }),
      "HUNT_NO_ORBS", { N(cost) }
  end

  ns.selfCall = true
  local sent = EbonAPI.Ebonhold.ConfirmSpend(spellId, cost)
  ns.selfCall = false

  if not sent then
    return false, "sendFailed", cost
  end
  return true, nil, cost
end

local function Spend()
  local spellId = pickSpellId
  state = "idle"
  pickSpellId, pickName = nil, nil

  if not spellId then
    Fail(ns.api:Problem("REROLL.NO_PICK_TO_SPEND"), "HUNT_BEFORE_SPEND")
    return
  end

  local ok, why, cost, _, problem, huntReason, huntArgs = SendHuntSpend(spellId)
  if not ok then
    if why == "sendFailed" then
      FailHuntCycle("HUNT_SPEND_FAILED")
    else
      Fail(problem, huntReason, huntArgs)
    end
    return
  end

  if huntCycleInFlight then
    huntCycleInFlight = false
    hunt.spent = hunt.spent + cost
    hunt.sacrificeId = spellId
    RefreshHuntWindow()
  end

end

local function DirectSpend(spellId)
  if not hunt.active then return false end
  if hunt.drawCards or EbonAPI.Ebonhold.IsOfferPending() == true then return false end
  if hunt.directInFlight then return true end

  local step = Multiplier()
  if not IsPermanent(spellId) and Charges() >= step and hunt.spent + step > hunt.budget then
    HuntStop("HUNT_BUDGET_DONE", nil, false)
    return true
  end

  local ok, why, cost, _, problem, huntReason, huntArgs = SendHuntSpend(spellId)
  if not ok then
    hunt.directInFlight = false
    if why == "sendFailed" then
      HuntStop("HUNT_SPEND_FAILED")
    else
      if problem then ns.api:Report(problem) end
      HuntStop(huntReason, huntArgs, false)
    end
    return true
  end

  hunt.spent = hunt.spent + cost
  hunt.sacrificeId = spellId
  hunt.directInFlight = true
  pcall(RefreshHuntWindow)
  return true
end

local function SpendOrb()
  Spend()
  Refresh()
end

local function Reroll()
  local pick, code, _, a, b = CanReroll()
  if not pick then
    Refuse(code, a, b)
    return false
  end

  pickSpellId = pick.spellId
  pickName = ColoredName(pick.spellId, pick.quality)
  state = "picking"
  Arm(stateTimer, PICK_TIMEOUT, OnPickTimeout)

  local outcome = EbonAPI.Actions.SelectEcho(pick.spellId)

  if not outcome.sent then
    Abort(nil)
    return false
  end
  Refresh()
  return true
end

local budgetWanted = DEFAULT_BUDGET

local function Remaining()
  return (hunt.lastBudget or 0) - (hunt.lastSpent or 0)
end

local function Resumable()
  return not hunt.active and hunt.endReason == "HUNT_FOUND"
end

local function CanHunt(resume)
  if hunt.active then return nil, "HUNT.RUNNING_ALREADY" end
  if WantedCount() == 0 then return nil, "HUNT.NOTHING_ARMED" end
  if AutoAcceptOn() then return nil, "HUNT.AUTO_ACCEPT_ON" end
  if not ChargesKnown() then return nil, "REROLL.CHARGES_UNKNOWN" end

  local cost = Multiplier()
  if Charges() < cost then
    return nil, "REROLL.NOT_ENOUGH_ORBS", cost, Charges()
  end
  local room = math.min(resume and Remaining() or budgetWanted, Charges())
  if room < cost then
    return nil, "HUNT.BUDGET_TOO_LOW", cost, room
  end
  return true
end

local function HuntBegin(resume)
  local carried = resume and hunt.lastSpent or 0
  hunt.active = true
  NotifyHunt()
  hunt.budget = carried + math.min(resume and Remaining() or budgetWanted, Charges())
  hunt.spent  = carried
  hunt.nextAt = 0
  hunt.endReason = nil
  hunt.endArgs = nil
  hunt.drawCards, hunt.sacrificeId, hunt.foundId = nil, nil, nil
  lastJudged = nil
  huntCycleInFlight = false
  hunt.directInFlight = false

  if resume then RefreshHuntWindow() else OpenHuntWindow() end
  Refresh()
end

local function HuntStart(resume)
  local ok, code, a, b = CanHunt(resume)
  if not ok then
    Refuse(code, a, b)
    return
  end

  HuntBegin(resume)
end

local function ToggleHunt()
  if hunt.active then
    HuntStop("HUNT_STOPPED", nil, false)
  else
    HuntStart()
  end
end

function EbonBuilds.Reroll.ToggleHunt()
  ToggleHunt()
end

function EbonBuilds.Reroll.Continue()
  if Resumable() then HuntStart(true) end
end

function EbonBuilds.Reroll.SetBudget(n)
  local top = ChargesKnown() and math.max(1, Charges()) or math.huge
  budgetWanted = math.max(1, math.min(math.floor(n), top))
  EbonAPIEbonBuildsDB.globalSettings.huntBudget = budgetWanted
  RefreshHuntWindow()
  Refresh()
end

function EbonBuilds.Reroll.ColoredName(spellId, quality)
  return ColoredName(spellId, quality)
end

function EbonBuilds.Reroll.QualityName(q)
  return QualityName(q)
end

function EbonBuilds.Reroll.HuntState()
  local cost = Multiplier()
  local blocked = nil
  local resume = Resumable()
  if not hunt.active then
    local ok, code, x, y = CanHunt(resume)
    if not ok then blocked = Why(code, x, y) end
  end
  local active = hunt.active
  local budget = active and hunt.budget or math.min(budgetWanted, Charges())
  local spent = active and hunt.spent or (hunt.lastSpent or 0)
  return {
    active = active,
    wanted = WantedCount(),
    budget = budget,
    spent = spent,
    cost = cost,
    reserve = Charges(),
    drawsDone = math.floor(spent / cost),
    drawsPlanned = math.floor(budget / cost),
    endReason = (not active) and hunt.endReason or nil,
    endArgs = (not active) and hunt.endArgs or nil,
    blocked = blocked,
    continuable = resume and WantedCount() > 0 and Remaining() >= cost and Charges() >= cost,
    waiting = active and not hunt.drawCards and EbonAPI.Ebonhold.IsOfferPending() ~= true,
    drawCards = hunt.drawCards,
    sacrificeId = hunt.sacrificeId,
    foundId = hunt.foundId,
  }
end

local function ToggleGuard()
  hunt.armed = not hunt.armed
  local wl = ns.Wishlist
  if wl then wl.SetShown(hunt.armed) end
  if hunt.armed then
    if not hunt.active then
      hunt.endReason, hunt.endArgs = nil, nil
      if WantedCount() > 0 then OpenHuntWindow() end
    end
  else
    CloseHuntWindow()
  end
  NotifyHunt()
  Refresh()
end

Unfold = function()
  local parent, choose = EbonAPI.Ebonhold.PerkFrame(), _G.PerkChooseButton
  if parent and parent.perksHidden and choose and choose:IsShown() then
    choose:Click()
  end
end

local function HuntTick(choices)
  if not hunt.active then return end
  if state ~= "idle" then return end
  if not choices or #choices == 0 then return end
  if choices == lastJudged then return end

  local now = GetTime()
  if now < hunt.nextAt then
    Arm(huntTimer, hunt.nextAt - now, Refresh)
    return
  end

  lastJudged = choices
  local cards = {}
  for i = 1, #choices do
    cards[i] = { spellId = choices[i].spellId, quality = choices[i].quality }
  end
  hunt.drawCards = cards
  hunt.directInFlight = false
  hunt.sacrificeId = nil

  local found = FindWanted(choices)
  hunt.foundId = found and found.spellId or nil
  RefreshHuntWindow()
  if found then
    HuntStop("HUNT_FOUND", { ColoredName(found.spellId, found.quality) }, found.spellId)
    Arm(unfoldTimer, 0, Unfold)
    return
  end

  local cost = Multiplier()

  if hunt.spent + cost > hunt.budget then
    HuntStop("HUNT_BUDGET_DONE", nil, false)
    return
  end
  if Charges() < cost then
    ns.api:Report(ns.api:Problem("HUNT.NO_ORBS_LEFT", { cost = cost, charges = Charges(), spent = hunt.spent }))
    HuntStop("HUNT_NO_ORBS", { N(cost) }, false)
    return
  end

  local pick, code, _, a, b = CanReroll()
  if not pick then
    deadFor = choices
    Refuse(code, a, b)
    HuntStop("HUNT_STOPPED", nil, false)
    return
  end

  hunt.nextAt = GetTime() + HUNT_CYCLE
  huntCycleInFlight = true
  Reroll()
end

local function InstallPerkHooks()
  local draw = EbonBuilds.DrawHook
  draw.Install()

  draw.After("Show", function()
    ArmSettle()
    Refresh()
  end)

  draw.After("Hide", Refresh)

  draw.After("UpdateSinglePerk", Refresh)
end

local function OnPickResult(_, result)
  if result.ok then
    if state == "picking" then
      state = "consuming"
      Arm(stateTimer, CONSUME_DELAY, SpendOrb)
    elseif hunt.active then
      HuntStop("HUNT_STOPPED_CLICK", nil, false)
    end
  elseif state == "picking" then
    Abort(nil)
    return
  end
  Refresh()
end

local function OnOrbSpend(_, spend)
  local orbs = spend.orbs
  if not ns.selfCall and type(orbs) == "number" and orbs >= 1 then
    orbMultiplier = math.floor(orbs)
  end
end

local function OnServerData()
  if hunt.active then Refresh() end
  RefreshHuntWindow()
end

local TOGGLE_BUTTONS = { "PerkHideButton", "PerkChooseButton" }
local togglesHooked = 0

local function InstallToggleHooks()
  if togglesHooked >= #TOGGLE_BUTTONS then return end
  for i = 1, #TOGGLE_BUTTONS do
    local b = _G[TOGGLE_BUTTONS[i]]
    if b and not b._eorHooked and b.HookScript then
      b._eorHooked = true
      togglesHooked = togglesHooked + 1
      b:HookScript("OnClick", Refresh)
    end
  end
end

local function RerollTip(add)
  add(L.REROLL_TITLE, "title")

  local pick, code, _, a, b = CanReroll()
  if pick then
    local cost = Multiplier()
    add(string.format(L.REROLL_BODY, ColoredName(pick.spellId, pick.quality)), "text", true)
    add(string.format(L.REROLL_COST, N(cost), S(cost), N(Charges())))
  else
    add(Why(code, a, b), "error", true)
  end
end

local function HuntTip(add)
  local cost = Multiplier()

  if hunt.active then
    add(L.HUNT_RUNNING, "title")
    add(string.format(L.HUNT_PROGRESS, N(hunt.spent), N(hunt.budget), N(cost)))
    add(L.HUNT_CLICK_STOP, "muted")
    return
  end

  add(L.HUNT_TITLE, "title")
  local ok, code, a, b = CanHunt()
  if ok then
    local budget = math.min(budgetWanted, Charges())
    local draws  = math.floor(budget / cost)
    add(string.format(L.HUNT_BODY, WantedCount()), "text", true)
    add(string.format(L.HUNT_BODY_COST, N(cost), draws, N(budget)), "text", true)
    add(L.HUNT_BODY_MANUAL, "muted", true)
    if cost == 1 then
      add(L.HUNT_BODY_HINT, "faint", true)
    end
  else
    add(Why(code, a, b), "error", true)
  end
end

local rarityButton = nil

local function QualityRGB(q)
  local card = EbonAPI.ClientData.Quality(q)
  if card then return card.r, card.g, card.b end
  return 1, 1, 1
end

local function OpenFloorMenu(row)
  local items = { { text = row.name, title = true } }
  for i = 1, #row.qualities do
    local q = row.qualities[i]
    items[#items + 1] = {
      text = (i == 1) and L.RARITY_ANY or string.format(L.RARITY_MIN, QualityName(q)),
      checked = row.floor == q,
      onClick = function() ns.Wishlist.SetFloor(row.key, q) end,
    }
  end
  EbonBuilds.api:OpenMenu(items)
end

local function OpenRarityMenu()
  local wl = ns.Wishlist
  if not wl then return end
  local rows = wl.Armed()
  local items = {}
  for i = 1, #rows do
    local row = rows[i]
    items[i] = { text = row.name, onClick = function() OpenFloorMenu(row) end }
  end
  if #items == 0 then items[1] = { key = "NOTHING_ARMED", disabled = true } end
  EbonBuilds.api:OpenMenu(items)
end

local function RarityTip(add)
  add(L.RARITY_TITLE, "title")
  if WantedCount() == 0 then
    add(L.NOTHING_ARMED, "error", true)
  else
    add(L.RARITY_BODY, "text", true)
    add(L.RARITY_HINT, "muted", true)
  end
end

local function MakeButton(parent, label, width, onClick, tip)
  local b = EbonBuilds.Widgets.Kit("button", parent, {
    text = function(self) return self._label end,
    width = width, height = BUTTON_HEIGHT,
    onClick = function(self) onClick(self) end,
  })
  b._label = label
  b:Refresh()
  EbonBuilds.Widgets.Tip(b, function(add)
    Refresh()
    tip(add)
  end)
  return b
end

local function SetEnabled(w, on)
  if w._eorEnabled == on then return end
  w._eorEnabled = on
  w:SetDisabledState(not on)
end

local function SetShown(f, on)
  if f._eorShown == on then return end
  f._eorShown = on
  if on then f:Show() else f:Hide() end
end

local function Anchor(panel, parent)
  uiParent = parent
  panel:SetParent(parent)
  panel:SetFrameLevel(parent:GetFrameLevel() + 20)
  panel:ClearAllPoints()
  panel:SetPoint("TOP", parent, "BOTTOM", 0, BUTTON_Y)
end

local function EnsureUI(parent)
  if container then return container end

  container = EbonBuilds.Widgets.Kit("bar", parent, { spacing = BUTTON_GAP })
  Anchor(container, parent)

  button = MakeButton(container, "Reroll (Orb)", BUTTON_WIDTH, Reroll, RerollTip)
  huntButton = MakeButton(container, "Chercher", HUNT_BUTTON_WIDTH, ToggleHunt, HuntTip)
  rarityButton = MakeButton(container, "", RARITY_WIDTH, OpenRarityMenu, RarityTip)
  local swatch = rarityButton:CreateTexture(nil, "OVERLAY")
  swatch:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  swatch:SetWidth(RARITY_WIDTH - 14)
  swatch:SetHeight(BUTTON_HEIGHT - 18)
  swatch:SetPoint("CENTER")
  rarityButton.swatch = swatch

  SetShown(container, false)
  return container
end

local function RefreshRarity()
  if not rarityButton then return end
  local wl = ns.Wishlist
  local n = (wl and wl.Count()) or 0
  local floor = (n > 0 and wl.CommonFloor()) or nil

  if rarityButton._floor == floor and rarityButton._armed == n then return end
  rarityButton._floor, rarityButton._armed = floor, n

  if floor then
    rarityButton.swatch:SetVertexColor(QualityRGB(floor))
  else
    rarityButton.swatch:SetVertexColor(0.55, 0.55, 0.55)
  end
end

local function SetButtonText(b, label)
  b._label = label
  b:SetLabel(label)
end

local function SetLabel(b, enabled)
  local charges = ChargesKnown() and Charges() or nil
  if b._enabled == enabled and b._state == state and b._charges == charges then return end
  b._enabled, b._state, b._charges = enabled, state, charges

  if state ~= "idle" then
    SetButtonText(b, L.REROLL_BUSY, enabled)
  else
    SetButtonText(b, string.format(L.REROLL, charges or "?"), enabled)
  end
end

local function SetHuntLabel(b, enabled)
  local cost, count = Multiplier(), WantedCount()
  if b._enabled == enabled and b._active == hunt.active and b._spent == hunt.spent
      and b._budget == hunt.budget and b._count == count and b._cost == cost then
    return
  end
  b._enabled, b._active, b._spent = enabled, hunt.active, hunt.spent
  b._budget, b._count, b._cost = hunt.budget, count, cost

  if hunt.active then
    SetButtonText(b, string.format(L.HUNT_STOP, hunt.spent, hunt.budget), enabled)
  elseif cost > 1 then
    SetButtonText(b, string.format(L.HUNT_MULT, count, cost), enabled)
  else
    SetButtonText(b, string.format(L.HUNT, count), enabled)
  end
end

local function BuildToggle(root)
end

function EbonBuilds.Reroll.GetArmed()
  return hunt.armed and true or false
end

function EbonBuilds.Reroll.SetArmed(on)
  if (on and true or false) ~= (hunt.armed and true or false) then
    ToggleGuard()
  end
end

local function OnEchoesVisible(on)
end

local function Evaluate()
  local parent = EbonAPI.Ebonhold.PerkFrame()
  if not parent then
    if container then SetShown(container, false) end
    return
  end

  InstallToggleHooks()

  local choices = Choices()
  local offerPending = EbonAPI.Ebonhold.IsOfferPending() == true

  if offerPending then
    if not hunt.active then Cancel(settleTimer) end
    ProbeCharges()
    HuntTick(choices)
  end

  local relevant = parent:IsShown()
      and not parent.perksHidden
      and choices and #choices > 0
      and offerPending

  if not relevant then
    if container then SetShown(container, false) end
    return
  end

  local panel = EnsureUI(parent)
  if uiParent ~= parent then Anchor(panel, parent) end

  local pick, code, impossible = CanReroll()
  if impossible then
    if deadFor ~= choices then
      deadFor = choices
      Refuse(code)
    end
    SetShown(panel, false)
    return
  end

  local canReroll = (pick ~= nil) and not hunt.active
  SetEnabled(button, canReroll)
  SetLabel(button, canReroll)

  local canHunt = hunt.active or (CanHunt() ~= nil)
  SetEnabled(huntButton, canHunt)
  SetHuntLabel(huntButton, canHunt)

  SetEnabled(rarityButton, WantedCount() > 0)
  RefreshRarity()

  SetShown(panel, true)
end

local refreshing = false
function Refresh()
  NotifyHunt()
  if refreshing then return end
  refreshing = true
  ns.api:Guard("REROLL.REFRESH", Evaluate)
  refreshing = false
end

local function OnWishlistChanged()
  local count = WantedCount()
  if count > (hunt.wantedSeen or 0) then
    if ns.Wishlist then ns.Wishlist.SetShown(true) end
    OpenHuntWindow()
  end
  hunt.wantedSeen = count
  RefreshHuntWindow()
  Refresh()
end

local function Boot()
  local saved = EbonAPIEbonBuildsDB and EbonAPIEbonBuildsDB.globalSettings
  budgetWanted = saved and saved.huntBudget or DEFAULT_BUDGET
  if ns.Wishlist then ns.Wishlist.Load() end
  hunt.wantedSeen = WantedCount()
  if not EbonAPI.Ebonhold.IsPresent() then return end

  PE = EbonAPI.Ebonhold.Raw()
  local ui = PE and PE.PerkUI
  if not PE or not ui
      or not ui.Show or not ui.Hide or not ui.ResetSelection then
    PE = nil
    ns.api:Degrade(ns.api:Problem("HUNT.NO_PERK_SYSTEM"))
    return
  end

  InstallPerkHooks()

  if not subscribed then
    subscribed = true
    ns.api:On("SERVER_PICK_RESULT", OnPickResult)
    ns.api:On("CLIENT_ORB_SPEND", OnOrbSpend)
    ns.api:On("SERVER_OFFER", OnServerData)
    ns.api:On("SERVER_ORBS", OnServerData)
    if EbonAPI.Ebonhold.OnSpendRequest(DirectSpend) == false then
      ns.api:Degrade(ns.api:Problem("HUNT.NO_PERK_SYSTEM"))
    end
  end

  ns.OnWishlistChanged = OnWishlistChanged

  ns.OnJournalFound = BuildToggle
  ns.OnEchoesVisible = OnEchoesVisible
  if EbonBuilds.Pe and EbonBuilds.Pe.Shell then EbonBuilds.Pe.Shell.Install() end
end

ns.api:On("READY", Boot)
