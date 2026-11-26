local _, ns = ...

local L = ns.L
local HuntWindow = {}
EbonBuilds.HuntWindow = HuntWindow

local frame = nil
local parts = nil
local pools = { wanted = {}, draw = {} }

local function N(n)
  return EbonAPI.Format.number(n)
end

local function S(n)
  return n == 1 and "" or L.PLURAL
end

local function State()
  return EbonBuilds.Reroll.HuntState()
end

local function Mode(st)
  if st.active then return "running" end
  if st.endReason then return "ended" end
  return "ready"
end

local function StatusText()
  local st = State()
  local mode = Mode(st)
  if mode == "running" then return st.waiting and L.HUNT_WAITING or L.HUNT_RUNNING end
  if mode == "ended" then
    if st.continuable and st.blocked then return st.blocked end
    local text = L[st.endReason] or st.endReason
    if st.endArgs then return string.format(text, unpack(st.endArgs)) end
    return text
  end
  if st.wanted == 0 then return L.HUNT_STATE_NONE end
  return st.blocked or L.HUNT_STATE_READY_BODY
end

local function WantedEntries()
  local wl = ns.Wishlist
  local rows = wl and wl.Armed() or {}
  local rr = EbonBuilds.Reroll
  local entries = {}
  for i = 1, #rows do
    local row = rows[i]
    local entry = { spellId = row.sample, quality = row.floor }
    if row.floor ~= row.qualities[1] then
      entry.min = string.format(L.RARITY_MIN, rr.QualityName(row.floor))
    end
    entries[i] = entry
  end
  return entries
end

local function DrawEntries()
  local st = State()
  local cards = st.drawCards or {}
  local entries = {}
  for i = 1, #cards do
    local c = cards[i]
    local found = c.spellId == st.foundId
    entries[i] = {
      spellId = c.spellId,
      quality = c.quality,
      found = found,
      sacrificed = not found and c.spellId == st.sacrificeId,
    }
  end
  return entries
end

local function NewIcon(row)
  local W = EbonBuilds.Widgets
  local btn = W.Kit("icon", row, {
    icon = function(self)
      return self._spellId and select(3, GetSpellInfo(self._spellId)) or nil
    end,
  })
  btn._ring = W.Ring(btn)
  W.SpellTip(btn, function(self) return self._spellId, self._quality end, { describe = true, colored = true })
  btn:HookScript("OnEnter", function(self)
    if self._spellId and self._min then
      GameTooltip:AddLine(self._min)
      GameTooltip:Show()
    end
  end)
  return btn
end

local function Fill(row, pool, entries)
  local W = EbonBuilds.Widgets
  local changed = false
  for i = 1, #entries do
    local entry = entries[i]
    local btn = pool[i]
    if not btn then
      btn = NewIcon(row)
      pool[i] = btn
      changed = true
    end
    if not btn:IsShown() then
      btn:Show()
      changed = true
    end
    if btn._spellId ~= entry.spellId then
      btn._spellId = entry.spellId
      btn:Refresh()
    end
    btn._quality, btn._min = entry.quality, entry.min
    W.SetRing(btn._ring, entry.quality)
    btn:SetDisabledState(entry.sacrificed == true)
    btn:SetCheckedState(entry.found == true)
  end
  for i = #entries + 1, #pool do
    if pool[i]:IsShown() then
      pool[i]:Hide()
      changed = true
    end
  end
  if changed then row:Layout() end
end

local function BudgetTitle()
  return string.format(L.BUDGET, N(State().budget))
end

local function DrawsLine()
  local st = State()
  return string.format(L.HUNT_BUDGET_DRAWS, st.drawsPlanned, S(st.drawsPlanned), N(st.cost))
end

local function Launching(st)
  local mode = Mode(st)
  return mode == "ready" or (mode == "ended" and st.continuable == true)
end

local function ButtonText()
  local st = State()
  if Mode(st) == "running" then return L.HUNT_STOP_BTN end
  if Launching(st) then return Mode(st) == "ended" and L.HUNT_CONTINUE_BTN or L.HUNT_START_BTN end
  return L.HUNT_CLOSE
end

local function OnButton()
  local st = State()
  local mode = Mode(st)
  if mode == "ended" and st.continuable then
    EbonBuilds.Reroll.Continue()
  elseif mode == "ended" then
    frame:Hide()
  else
    EbonBuilds.Reroll.ToggleHunt()
  end
end

local function Build()
  local kit = EbonBuilds.Widgets.Kit
  frame = EbonBuilds.api:Window("hunt", { key = "HUNT_TITLE", layout = "VERTICAL" })
  frame:HookScript("OnHide", function()
    if State().active then EbonBuilds.Reroll.ToggleHunt() end
  end)
  parts = {
    status = kit("status", frame, { text = StatusText }),
    wantedTitle = kit("text", frame, { key = "HUNT_RECHERCHE" }),
    wanted = kit("bar", frame, {}),
    bar = kit("progress", frame, {
      value = function() return State().drawsDone end,
      max = function() return math.max(1, State().drawsPlanned) end,
      text = function()
        local st = State()
        return string.format(L.HUNT_PROGRESS_DRAWS, st.drawsDone, st.drawsPlanned)
      end,
    }),
    orbs = kit("text", frame, {
      text = function()
        local st = State()
        return string.format(L.HUNT_PROGRESS_ORBS, st.spent, st.budget, st.reserve, st.cost)
      end,
    }),
    range = kit("range", frame, {
      min = 1, max = 2,
      text = BudgetTitle,
      get = function() return State().budget end,
      onChange = function(_, value) EbonBuilds.Reroll.SetBudget(value) end,
    }),
    draws = kit("text", frame, { text = DrawsLine }),
    drawTitle = kit("text", frame, { key = "HUNT_LAST_DRAW" }),
    draw = kit("bar", frame, {}),
    button = kit("button", frame, { text = ButtonText, onClick = OnButton }),
  }
end

function HuntWindow.IsOpen()
  return frame ~= nil and frame:IsShown() and true or false
end

function HuntWindow.Refresh()
  if not frame or not frame:IsShown() then return end
  local st = State()
  local mode = Mode(st)
  frame.close[Launching(st) and "Show" or "Hide"](frame.close)
  local choosing = mode == "ready" and st.reserve >= 2
  if choosing then
    parts.range:SetRange(1, st.reserve, 1)
    parts.range:SetValue(st.budget)
    parts.range:SetTitle(BudgetTitle())
  end
  parts.range[choosing and "Show" or "Hide"](parts.range)
  parts.draws[choosing and "Show" or "Hide"](parts.draws)
  parts.bar[mode == "ready" and "Hide" or "Show"](parts.bar)
  parts.orbs[choosing and "Hide" or "Show"](parts.orbs)
  parts.drawTitle[mode == "ready" and "Hide" or "Show"](parts.drawTitle)
  parts.draw[mode == "ready" and "Hide" or "Show"](parts.draw)
  Fill(parts.wanted, pools.wanted, WantedEntries())
  Fill(parts.draw, pools.draw, DrawEntries())
  for name, part in pairs(parts) do
    if name ~= "range" then part:Refresh() end
  end
end

function HuntWindow.Close()
  if frame then frame:Hide() end
end

function HuntWindow.Open()
  if not frame then Build() end
  frame:Show()
  HuntWindow.Refresh()
end
