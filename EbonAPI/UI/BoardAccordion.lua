EbonAPI = EbonAPI or {}
EbonAPI.BoardAccordion = {}

-- The one open volet of the Hero's Call Board list (ProjectEbonhold callboard_ui.lua:454-476, 1155-1190).
--
-- ProjectEbonhold folds a group of the list on a click of its header (sectionOpen, local to it) and only
-- builds the rows of the groups it holds for open; its pieces are not reachable. The accordion therefore
-- drives it by its own gesture: after each CALLBOARD_UI_REFRESHED it compares the headers (header.key,
-- header.open) with the volet wanted and clicks the headers that differ (header:Click()), at most
-- (headers open + 1) times, under a reentrance guard. The click of the player is heard by a HookScript
-- after ProjectEbonhold's own OnClick, and decides the active volet of the category of the tab.
--
-- State, per category (the number before the first ":" of header.key), for the session only:
--   nil     ProjectEbonhold's rule, at most one group kept: the one it opened for the zone of the player
--           (an open group with no contract taken), else the first with a contract taken, else the first;
--   false   everything closed;
--   key     that header.key. A key that is no header of ProjectEbonhold and has no category ("acb:off")
--           closes every group of ProjectEbonhold and stays active.
-- Nothing is compared by name: keys and contract states only.
--
-- Changing the volet moves the rows over board.header.fold seconds (the curve of the Kit stack): the
-- rows of a group opened leave its header, the headers below move, the rows of a group closed stay shown
-- until the end when ProjectEbonhold kept their frames (a row frame ProjectEbonhold gives to another
-- contract is not kept, the rows of a volet that closes while another opens leave at once). A refresh of
-- the board during the animation ends it at once; a duration of 0 does not animate.
--
-- For an addon (api:BoardVoletActive(), api:BoardVoletSet(key|false|nil), event CALLBOARD_VOLET_CHANGED
-- with the active key or false): see the end of the file. Active under every skin, Azeroth included;
-- cut for the session when the list is not as known, without a word in the chat.

local Accordion = EbonAPI.BoardAccordion
local BoardPin = EbonAPI.BoardPin
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local Skins = EbonAPI.Skins
local Ebonhold = EbonAPI.Ebonhold
local Handle = EbonAPI.Handle

local type, ipairs, pairs, pcall, setmetatable, tostring, error = type, ipairs, pairs, pcall, setmetatable, tostring, error
local min, floor = math.min, math.floor
local format, match = string.format, string.match
local sort = table.sort

local OWNER = EbonAPI.name
local FRAME = "EbonholdCallboardFrame"
local EVENT = "CALLBOARD_VOLET_CHANGED"
local NONE = "_"

local S = Skins.value

local active = {}
local lastCategory = NONE
local cut = false
local busy = false
local hooked = setmetatable({}, { __mode = "k" })
local last
local anim
local driver

local function isType(object, kind)
  return type(object) == "table" and type(object.GetObjectType) == "function" and object:GetObjectType() == kind
end

local function categoryOf(key)
  return type(key) == "string" and match(key, "^(%d+):") or nil
end

local function takenState(state)
  local known = EbonAPI.State and EbonAPI.State.CALLBOARD_STATE or { ACCEPTED = 1, COMPLETE = 2 }

  return state == known.ACCEPTED or state == known.COMPLETE
end

-- ------------------------------------------------------------ the list as it is ----

local function pieceOf(child, content)
  if child.spec ~= nil or not child:IsShown() or child:GetNumPoints() ~= 1 then
    return nil
  end

  local point, relative, relativePoint, x, y = child:GetPoint(1)

  if point ~= "TOPLEFT" or relative ~= content or relativePoint ~= "TOPLEFT" then
    return nil
  end

  if isType(child, "Button") and type(child.key) == "string" and type(child.open) == "boolean"
      and isType(child.toggle, "Texture") and isType(child.text, "FontString") then
    return { kind = "header", key = "h:" .. child.key, id = child.key, frame = child, top = -(y or 0), x = x or 0,
      height = child:GetHeight(), open = child.open }
  end

  if isType(child, "Button") and type(child.quest) == "table" and type(child.quest.questId) == "number" then
    return { kind = "row", key = "q:" .. child.quest.questId, id = child.quest.questId, frame = child,
      top = -(y or 0), x = x or 0, height = child:GetHeight(), taken = takenState(child.quest.state) }
  end

  return nil
end

-- { heads = {sorted}, items = { key -> piece } } of the board list; nil when it is not on view.
local function scan()
  local frame = Ebonhold.Frame(FRAME)

  if not frame or not isType(frame.content, "Frame") or not frame.content:IsVisible() then
    return nil
  end

  local content = frame.content
  local heads, rows, items = {}, {}, {}

  for _, child in ipairs({ content:GetChildren() }) do
    local piece = pieceOf(child, content)

    if piece then
      items[piece.key] = piece

      if piece.kind == "header" then
        heads[#heads + 1] = piece
      else
        rows[#rows + 1] = piece
      end
    end
  end

  sort(heads, function(a, b) return a.top < b.top end)

  for _, row in ipairs(rows) do
    for _, head in ipairs(heads) do
      if head.top <= row.top then
        row.header = head.key
        head.taken = head.taken or row.taken
      end
    end
  end

  return { content = content, heads = heads, items = items }
end

-- ------------------------------------------------------------ the volet wanted ----

local function wanted(view, category)
  local heads, value = view.heads, active[category]

  if value == false then
    return nil
  end

  if type(value) == "string" then
    for _, head in ipairs(heads) do
      if head.id == value then
        return value
      end
    end

    if not categoryOf(value) then
      return nil -- an external key: every group of ProjectEbonhold closed
    end
  end

  -- ProjectEbonhold's rule, one group only
  local first, taken
  for _, head in ipairs(heads) do
    if head.open then
      if not head.taken then
        return head.id
      end

      taken = taken or head.id
    end
  end

  first = heads[1] and heads[1].id

  return taken or first
end

-- ------------------------------------------------------------ animation ----

local function eased(share)
  return 1 - (1 - share) * (1 - share)
end

local function put(move, top)
  move.frame:SetPoint("TOPLEFT", anim.content, "TOPLEFT", move.x, -top)

  if move.header then
    BoardPin.touched(move.frame)
  end
end

-- mode "finish": every piece to its place, ghosts hidden; "drop": ghosts hidden, the rest left to the
-- layout that follows; "keep": nothing touched (ProjectEbonhold just laid the list out again).
local function endAnimation(mode)
  local running = anim
  local write = mode == "finish"

  anim = nil

  if driver then
    driver:SetScript("OnUpdate", nil)
  end

  if not running then
    return
  end

  anim = running

  for _, move in ipairs(running.moves) do
    if move.ghost then
      if mode ~= "keep" then
        move.frame:Hide()
      end
    elseif write then
      put(move, move.to)
    end
  end

  anim = nil

  if write then
    BoardPin.redraw()
  end
end

local function tick(_, elapsed)
  if not anim then
    return
  end

  anim.elapsed = anim.elapsed + (elapsed or 0)

  local share = min(1, anim.elapsed / anim.duration)

  if share >= 1 then
    endAnimation("finish")
    return
  end

  local factor = eased(share)

  for _, move in ipairs(anim.moves) do
    put(move, move.from + (move.to - move.from) * factor)
  end
end

local function animate(before, after)
  local duration = S("board.header.fold") or 0

  if duration <= 0 or not before or not after.content:IsVisible() then
    return
  end

  local moves = {}

  for key, item in pairs(after.items) do
    local old = before.items[key]
    local from

    if old then
      from = old.top
    elseif item.kind == "row" and item.header then
      local head, was = after.items[item.header], before.items[item.header]

      from = (was and was.top or head.top) + head.height
    end

    if from and from ~= item.top then
      moves[#moves + 1] = { frame = item.frame, from = from, to = item.top, x = item.x, header = item.kind == "header" }
    end
  end

  -- rows of a group that closes: their frames are kept by ProjectEbonhold (hidden, still bound to the
  -- contract) unless it gave them to another one
  for key, old in pairs(before.items) do
    if old.kind == "row" and not after.items[key] and old.header then
      local head = after.items[old.header]
      local frame = old.frame

      if head and not frame:IsShown() and type(frame.quest) == "table" and frame.quest.questId == old.id
          and frame:GetParent() == after.content then
        moves[#moves + 1] = { frame = frame, from = old.top, to = head.top + head.height, x = old.x, ghost = true }
      end
    end
  end

  if #moves == 0 then
    return
  end

  if not driver then
    driver = CreateFrame("Frame")
  end

  anim = { content = after.content, moves = moves, elapsed = 0, duration = duration }

  for _, move in ipairs(moves) do
    if move.ghost then
      move.frame:Show()
    end

    put(move, move.from)
  end

  driver:SetScript("OnUpdate", tick)
end

-- ------------------------------------------------------------ the work ----

local function cutFor(why)
  cut = true
  endAnimation("drop")
  Log.trace("pin", OWNER, "Hero's Call Board volet not driven: " .. why)
end

local hook

local function reconcile(clicked)
  if cut or busy then
    return
  end

  local view = scan()

  if not view or #view.heads == 0 then
    if view then
      last = view
    end

    return
  end

  local category = categoryOf(view.heads[1].id) or NONE

  lastCategory = category

  for _, head in ipairs(view.heads) do
    hook(head.frame)
  end

  endAnimation("drop")
  busy = true

  local before = last
  local want = wanted(view, category)
  local toggled, converged = 0, false
  local ok, err = pcall(function()
    local limit = #view.heads + 2

    for _ = 1, limit do
      local target

      for _, head in ipairs(view.heads) do
        if head.open and head.id ~= want then
          target = head
          break
        end
      end

      if not target and want then
        for _, head in ipairs(view.heads) do
          if head.id == want and not head.open then
            target = head
            break
          end
        end
      end

      if not target then
        converged = true
        return
      end

      if not target.frame:GetScript("OnClick") then
        return
      end

      toggled = toggled + 1
      target.frame:Click()

      view = scan()

      if not view then
        return
      end
    end
  end)

  busy = false

  if not ok then
    Lib.report(err, OWNER)
    cutFor("an error, given to the error display")
    return
  end

  if not converged then
    cutFor("the headers did not reach the volet wanted")
    return
  end

  view = scan() or view
  last = view

  if toggled > 0 or clicked then
    animate(before, view)
  end
end

function hook(header)
  if hooked[header] then
    return
  end

  hooked[header] = true
  header:HookScript("OnClick", function(self)
    if busy or cut then
      return
    end

    local category = categoryOf(self.key)

    if not category then
      return
    end

    local was = active[category]

    -- ProjectEbonhold already ran its own OnClick and laid the list out again: self.open is the new state
    if self.open then
      active[category] = self.key
    elseif was == nil or was == false or was == self.key then
      active[category] = false
    end

    if active[category] ~= was then
      EbonAPI:Emit(EVENT, active[category])
    end

    reconcile(true)
  end)
end

EbonAPI:On("CALLBOARD_UI_REFRESHED", function()
  if anim then
    endAnimation("keep")
  end

  Bus.after("EbonAPI:volet", 0.01, function()
    -- the click that moved the volet gave its own animation: this refresh was its own
    if not anim then
      reconcile(false)
    end
  end)
end)

-- ------------------------------------------------------------ for an addon ----

function Accordion.active()
  local value = active[lastCategory]

  if value == nil then
    return nil
  end

  return value
end

function Accordion.set(key)
  local category = categoryOf(key) or lastCategory
  local view = scan()

  if view and #view.heads > 0 then
    category = categoryOf(key) or categoryOf(view.heads[1].id) or NONE
    lastCategory = categoryOf(view.heads[1].id) or lastCategory
  end

  local was = active[category]

  active[category] = key

  if key ~= was then
    EbonAPI:Emit(EVENT, key)
  end

  reconcile(true)
end

function Accordion.state()
  return cut and "cut" or "ready", anim ~= nil
end

local function check(owner, key)
  if key ~= nil and key ~= false and type(key) ~= "string" then
    error(format("EbonAPI: %s: api:BoardVoletSet takes a header key, false or nil, got %s", tostring(owner),
      type(key)), 3)
  end
end

-- The key of the volet open in the list of the tab on view: a header.key of the board, an external key an
-- addon gave (api:BoardVoletSet), false when everything is closed by the player, nil while the board's
-- own rule decides. CALLBOARD_VOLET_CHANGED(key) is sent when the player or an addon changes it.
function EbonAPI:BoardVoletActive()
  return Accordion.active()
end

function Handle:BoardVoletActive()
  return Accordion.active()
end

-- Opens the volet of header.key (closing the others), closes everything (false), or gives the choice back
-- to the board's rule (nil). A key that is no header of the board closes all its groups and stays active.
function EbonAPI:BoardVoletSet(key)
  check("EbonAPI", key)
  Accordion.set(key)
end

function Handle:BoardVoletSet(key)
  check(self.addonName, key)
  Accordion.set(key)
end
