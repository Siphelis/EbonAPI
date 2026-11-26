local Core = AutoCallboardCore
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local state = RT.state

local Bricks = EbonAPI.Bricks
local Palette = EbonAPI.Palette


local ICON_COLLECTION = "INV_Misc_Book_09"
local ICON_SELECTION = "INV_Misc_Note_01"
local ICON_UNKNOWN = "INV_Misc_QuestionMark"
local LIST_SIZE = { 322, 444 }
local DETAIL_SIZE = { 546, 448 }
local PAD, GAP = 12, 6
local BAR_HEIGHT = 22
local TITLE_TOP, SUB_TOP, BUTTONS_TOP, TOGGLE_TOP, CONTENT_TOP = 12, 36, 56, 86, 118
local PARTIAL_ALPHA = Core.PARTIAL_ALPHA
local DROP_LINE = 2
local SEPARATOR = "  -  "
local STATES = { loaded = "COLLECTIONS_LOADED", modified = "COLLECTIONS_MODIFIED" }
local STATE_COLORS = { loaded = "success", modified = "caution" }

local NONE_KEY = "none"
local CLOSED = 0
local NO_GROUP = 0

local page
local broken = false
local shownId
local allKnown = false
local left = { offsets = {}, blocks = {} }
local right = {}
local Draw

local function Guarded(fn, ...)
  if broken then
    return
  end

  local ok, err = pcall(fn, ...)

  if not ok then
    broken = true
    EbonAPI.Lib.report(err, RT.api:GetName())

    if page then
      pcall(page.Release, page)
    end
  end
end

local function SizeOf(frame, fallback)
  local width, height = frame:GetWidth(), frame:GetHeight()

  if not width or width <= 0 then
    width = fallback[1]
  end

  if not height or height <= 0 then
    height = fallback[2]
  end

  return width, height
end

local function BarRoom()
  return Bricks.value("widgets.scroll.width") + Bricks.value("kit.gap")
end

local function RowGap()
  return Bricks.value("board.row.gap") or 4
end

local function HeaderKey(container)
  return "g:" .. tostring(container or NO_GROUP)
end

local function QuestKey(quest)
  if type(quest.key) == "string" and quest.key ~= "" then
    return quest.key
  end

  return Core.questKey(quest)
end


local function CollectionSub(entry)
  local parts = { string.format(L.COLLECTIONS_COUNT, Core.desiredQuestCount(entry.desiredQuests)) }
  local tier = Core.sanitizeDifficulty(entry.difficulty)
  local collectionState = RT.CollectionState(entry)
  local stateKey = STATES[collectionState]

  if tier then
    parts[#parts + 1] = Core.difficultyLabel(tier)
  end

  if stateKey then
    parts[#parts + 1] = Palette.code(STATE_COLORS[collectionState]) .. L[stateKey] .. "|r"
  end

  return table.concat(parts, SEPARATOR)
end

local function CollectionTip(lines, card)
  if card.acbNone then
    lines:Add(L.LISTS_ROW_CLEAR_ENTRY, "text", true)
    lines:Add(L.LISTS_ROW_LEFT_CLICK_CLEAR, "muted", true)
    return
  end

  local entry = card.acbEntry
  local tier = Core.sanitizeDifficulty(entry.difficulty)
  local collectionState = RT.CollectionState(entry)
  local stateKey = STATES[collectionState]

  lines:Add(string.format(L.COLLECTIONS_COUNT, Core.desiredQuestCount(entry.desiredQuests)), "text")

  if tier then
    lines:Add(string.format(L.LISTS_ROW_TARGET_DIFFICULTY, Core.difficultyLabel(tier)), "heading")
  end

  if stateKey then
    lines:Add(L[stateKey], STATE_COLORS[collectionState])
  end

  if RT.IsSelectionDifficultyLocked(entry) then
    lines:Add(L.LISTS_ROW_NEED_RESTED, "danger", true)
  end

  lines:Add(L.COLLECTIONS_CARD_HINT, "muted", true)
end

local function ClickCollection(card, mouse)
  if card.acbNone then
    if mouse ~= "RightButton" then
      RT.RequestLoadCollection(nil)
    end

    return
  end

  if mouse == "RightButton" then
    RT.ShowSelectionContextMenu(card, card.acbEntry)
    return
  end

  shownId = card.acbEntry.id
  Draw()
end



local function UpperHalf(frame)
  local top, bottom = frame:GetTop(), frame:GetBottom()

  if not top or not bottom then
    return true
  end

  local _, y = GetCursorPosition()

  return y / (frame:GetEffectiveScale() or 1) > (top + bottom) / 2
end

local function Above(item)
  return left.stack:TopOf(item) - RowGap() / 2
end

local function Below(item)
  return left.stack:BottomOf(item) + RowGap() / 2
end

local function Stays(entries, id, beforeId)
  for index, each in ipairs(entries) do
    if each.id == id then
      local after = entries[index + 1]

      return beforeId == id or (after and after.id or nil) == beforeId
    end
  end

  return false
end

local function PlanCollection(profile, target, id)
  local entry = Core.findSelection(profile, id)

  if not entry or target.acbNone then
    return nil
  end

  local groupId, beforeId, line

  if target.acbHeader then
    local first = Core.selectionsInContainer(profile, target.acbGroup and target.acbGroup.id or nil)[1]

    groupId, beforeId, line = target.acbGroup and target.acbGroup.id or nil, first and first.id, Below(target)
  else
    local over = target.acbEntry

    if over.id == entry.id then
      return nil
    end

    groupId = over.groupId

    if UpperHalf(target) then
      beforeId, line = over.id, Above(target)
    else
      local entries = Core.selectionsInContainer(profile, groupId)

      for index, each in ipairs(entries) do
        if each.id == over.id then
          beforeId = entries[index + 1] and entries[index + 1].id or nil
        end
      end

      line = Below(target)
    end
  end

  local moving = not Core.sameContainer(entry.groupId, groupId)

  if not moving and Stays(Core.selectionsInContainer(profile, groupId), entry.id, beforeId) then
    return nil
  end

  return {
    line = line,
    refused = moving and Core.selectionsFull(profile, groupId),
    apply = function() RT.RequestMoveSelectionTo(entry, groupId, beforeId) end,
  }
end

local function PlanGroup(profile, target, id)
  local group = Core.findGroup(profile, id)
  local from = Core.findGroupIndex(profile, id)
  local over

  if target.acbHeader then
    over = target.acbGroup and target.acbGroup.id or nil
  elseif target.acbEntry then
    over = target.acbEntry.groupId
  end

  local to = over and Core.findGroupIndex(profile, over) or 1

  local block = profile.groups[to] and left.blocks[profile.groups[to].id]

  if not group or not from or not block or to == from then
    return nil
  end

  return {
    line = to < from and Above(block.head) or Below(block.last),
    refused = false,
    apply = function() RT.RequestMoveGroupTo(group, to) end,
  }
end

local function Plan(target, payload)
  local profile = RT.GetAccountProfile()

  if type(payload) ~= "table" or not target or not target.acbLeft then
    return nil
  end

  if payload.collection ~= nil then
    return PlanCollection(profile, target, payload.collection)
  end

  if payload.group ~= nil then
    return PlanGroup(profile, target, payload.group)
  end

  return nil
end

local function Hovered()
  local focus = GetMouseFocus and GetMouseFocus()

  while focus do
    if focus.acbLeft then
      return focus:IsVisible() and focus or nil
    end

    focus = focus.GetParent and focus:GetParent() or nil
  end

  return nil
end

local function StopFollowing()
  left.payload = nil
  left.drop:Hide()
  left.follow:SetScript("OnUpdate", nil)
end

local function Follow()
  local current = EbonAPI.Kit.dragging()

  if broken or not current or current.payload ~= left.payload then
    StopFollowing()
    return
  end

  local plan = Plan(Hovered(), current.payload)

  if not plan then
    left.drop:Hide()
    return
  end

  local color = plan.refused and "danger" or "checked"

  if left.drop.color ~= color then
    left.drop.color = color
    Palette.paint(left.drop.line, "SetVertexColor", color)
  end

  left.drop:ClearAllPoints()
  left.drop:SetPoint("TOPLEFT", left.stack.child, "TOPLEFT", 0, -(plan.line - left.drop:GetHeight() / 2))
  left.drop:SetWidth(left.view)
  left.drop:Show()
end

local function Carried(item)
  local payload

  if item.acbHeader and item.acbGroup then
    payload = { group = item.acbGroup.id }
  elseif item.acbEntry then
    payload = { collection = item.acbEntry.id }
  end

  if payload then
    left.payload = payload
    left.follow:SetScript("OnUpdate", function() Guarded(Follow) end)
  end

  return payload
end

local function Dropped(target, payload)
  StopFollowing()

  local plan = Plan(target, payload)

  if plan then
    plan.apply()
  end
end

local function CollectionCard(parent)
  local card = RT.api:Create("card", parent, {
    icon = function(element) return element.acbIcon end,
    title = function(element) return element.acbTitle end,
    sub = function(element) return element.acbSub end,
    selected = function(element) return element.acbSelected end,
    onClick = function(element, mouse) Guarded(ClickCollection, element, mouse) end,
    drag = function(element) return Carried(element) end,
    onDrop = function(element, payload) Guarded(Dropped, element, payload) end,
    tip = function(lines, element) CollectionTip(lines, element) end,
  })

  card.acbLeft = true

  return card
end

local ToggleContainer

local function GroupClick(header, mouse)
  if mouse == "RightButton" then
    if header.acbGroup then
      RT.ShowGroupContextMenu(header, header.acbGroup)
    end

    return
  end

  ToggleContainer(header.acbContainer)
end

local function GroupHeader(parent)
  local header = RT.api:Create("cardHeader", parent, {
    text = function(element) return element.acbText end,
    count = function(element) return element.acbCount end,
    open = function(element) return element.acbOpen end,
    onClick = function(element, mouse) Guarded(GroupClick, element, mouse) end,
    drag = function(element) return Carried(element) end,
    onDrop = function(element, payload) Guarded(Dropped, element, payload) end,
  })

  header.acbLeft, header.acbHeader = true, true
  header:SetScript("OnEnter", function(self)
    local body = string.format(L.LISTS_ROW_QUEST_COUNT_GROUP, self.acbCount or 0) .. "\n" .. L.COLLECTIONS_FOLD_HINT

    if self.acbGroup then
      body = body .. "\n" .. L.COLLECTIONS_GROUP_HINT
    end

    Bricks.tip(self, self.acbText or "", body)
  end)
  header:SetScript("OnLeave", Bricks.hideTip)

  return header
end

local function ShownEntry(profile)
  local entry = shownId and Core.findSelection(profile, shownId)

  if not entry then
    entry = Core.findSelection(profile, RT.GetActiveSelectionId()) or Core.selectionsInContainer(profile, nil)[1]

    for _, group in ipairs(profile.groups or {}) do
      if entry then
        break
      end

      entry = Core.selectionsInContainer(profile, group.id)[1]
    end
  end

  shownId = entry and entry.id or nil

  return entry
end

local function OpenContainer(profile)
  local stored = RT.GetOpenGroupId()

  if #(profile.groups or {}) == 0 then
    return nil
  end

  if stored == nil then
    return NO_GROUP
  end

  if stored == CLOSED then
    return false
  end

  return stored
end

local function LeftItems(profile, shown)
  local groups = profile.groups or {}
  local base = Core.selectionsInContainer(profile, nil)
  local open = OpenContainer(profile)
  local items = { { key = NONE_KEY, kind = "card", none = true } }

  local function cards(entries, container)
    if open ~= nil and open ~= container then
      return
    end

    for _, entry in ipairs(entries) do
      items[#(items) + 1] = {
        key = "c:" .. tostring(entry.id), kind = "card", entry = entry, container = container,
        selected = shown ~= nil and entry.id == shown.id,
      }
    end
  end

  if #(groups) > 0 then
    items[#(items) + 1] = {
      key = HeaderKey(NO_GROUP), kind = "header", header = true, text = L.LISTS_MOVE_TO_LIST, count = #(base),
      container = NO_GROUP, open = open == NO_GROUP,
    }
  end

  cards(base, NO_GROUP)

  for _, group in ipairs(groups) do
    local entries = Core.selectionsInContainer(profile, group.id)

    items[#(items) + 1] = {
      key = HeaderKey(group.id), kind = "header", header = true, text = group.name, count = #(entries), group = group,
      container = group.id, open = open == group.id,
    }
    cards(entries, group.id)
  end

  return items
end

local function FillLeft(element, item)
  if item.header then
    element.acbText, element.acbCount, element.acbGroup = item.text, item.count, item.group
    element.acbContainer, element.acbOpen = item.container, item.open
    return
  end

  element.acbEntry, element.acbNone = item.entry, item.none and true or false

  if item.none then
    element.acbIcon, element.acbTitle = ICON_SELECTION, L.LISTS_NONE_ENTRY
    element.acbSub = string.format(L.LISTS_ROW_QUEST_COUNT, Core.desiredQuestCount(state.desiredQuests))
    element.acbSelected = false
  else
    element.acbIcon, element.acbTitle, element.acbSub = ICON_COLLECTION, item.entry.name, CollectionSub(item.entry)
    element.acbSelected = item.selected
  end
end

local function Blocks(items)
  local blocks, block = {}, nil

  for _, item in ipairs(items) do
    local element = left.stack:Element(item.key)

    if item.header then
      block = { head = element, last = element }
      blocks[item.container] = block
    elseif block and element then
      block.last = element
    end
  end

  left.blocks = blocks
end

local function DrawLeft(profile, shown, options)
  local width, height = SizeOf(page.list, LIST_SIZE)
  local view = width - math.max(page.bar:GetWidth(), BarRoom())
  local items = LeftItems(profile, shown)
  local empty = #(profile.savedSelections or {}) == 0

  options = options or {}
  options.tail = 0

  if empty then
    left.empty:SetWidth(view)
    left.empty:SetText(L.LISTS_WINDOW_EMPTY)
    options.tail = GAP + (left.empty:GetHeight() or 0)
  end

  left.view = view
  left.stack:SetView(view, height - BAR_HEIGHT - GAP)
  left.stack:SetItems(items, options)
  Blocks(items)

  if empty then
    left.empty:ClearAllPoints()
    left.empty:SetPoint("TOPLEFT", left.stack.child, "TOPLEFT", 4, -(left.stack:ContentHeight() + GAP))
    left.empty:Show()
  else
    left.empty:Hide()
  end
end

ToggleContainer = function(container)
  local profile = RT.GetAccountProfile()
  local stack = left.stack
  local offset = stack:Offset()
  local open = OpenContainer(profile)
  local head = stack:Element(HeaderKey(container))
  local screen = head and math.max(0, stack:TopOf(head) - offset) or 0

  if open ~= nil and open ~= false then
    local current = stack:Element(HeaderKey(open))

    if current then
      left.offsets[open] = math.max(0, offset - stack:TopOf(current))
    end
  end

  local inside = 0

  if open == container then
    RT.SetOpenGroupId(CLOSED)
  else
    RT.SetOpenGroupId(container ~= NO_GROUP and container or nil)
    inside = left.offsets[container] or 0
  end

  DrawLeft(profile, ShownEntry(profile), {
    animate = true,
    offset = function(self)
      local top = self:LayoutTop(HeaderKey(container))

      if not top then
        return nil
      end

      if inside > 0 then
        return top + inside
      end

      return math.max(0, top - screen)
    end,
  })
end


local function Share(desired, keys)
  local inside = 0

  for i = 1, #(keys) do
    if desired[keys[i]] == true then
      inside = inside + 1
    end
  end

  if inside == 0 then
    return "none", nil
  end

  if inside == #(keys) then
    return "all", nil
  end

  return "some", inside .. "/" .. #(keys)
end

local function UnknownTitle(key)
  local id = string.match(key, "^id:(%d+)$")

  return L.QUEST_UNKNOWN_TITLE .. " (" .. (id or key) .. ")"
end

local function Contents(entry)
  local desired = entry.desiredQuests or {}
  local byKey, groups, order = {}, {}, {}
  local unknown = { id = "unknown", name = L.COLLECTIONS_UNKNOWN, items = {} }

  for _, quest in ipairs(state.knownQuests or {}) do
    local key = QuestKey(quest)

    if key and not byKey[key] then
      byKey[key] = quest
    end
  end

  for _, category in ipairs(EbonAPI.State.CallboardCategories()) do
    local group = { id = category.id, name = RT.GetQuestCategoryName(category.id), items = {} }

    groups[category.id] = group
    order[#(order) + 1] = group
  end

  local function add(quest, key)
    local category = Core.displayCategory(quest)
    local group = groups[category]

    if not group then
      group = { id = category, name = RT.GetQuestCategoryName(category), items = {} }
      groups[category] = group
      order[#(order) + 1] = group
    end

    group.items[#(group.items) + 1] = { quest = quest, key = key }
  end

  for key, quest in pairs(byKey) do
    if allKnown or desired[key] == true then
      add(quest, key)
    end
  end

  for key, value in pairs(desired) do
    if value == true and not byKey[key] then
      unknown.items[#(unknown.items) + 1] = { key = key }
    end
  end

  for _, group in ipairs(order) do
    table.sort(group.items, function(a, b)
      local first, second = Core.questTitle(a.quest), Core.questTitle(b.quest)

      if first ~= second then
        return first < second
      end

      return a.key < b.key
    end)
  end

  table.sort(unknown.items, function(a, b) return a.key < b.key end)
  order[#(order) + 1] = unknown

  return order
end

local function ContractCard(parent)
  return RT.api:Create("card", parent, {
    icon = function(element) return element.acbIcon end,
    round = function(element) return element.acbQuest ~= nil end,
    title = function(element) return element.acbTitle end,
    sub = function(element) return element.acbSub end,
    checked = function(element) return element.acbIn end,
    onCheck = function(element, checked)
      Guarded(RT.RequestSetQuestInSelection, element.acbEntry, element.acbKey, checked)
    end,
    onClick = function(element, mouse)
      if mouse == "RightButton" and element.acbQuest then
        Guarded(RT.ShowQuestContextMenu, element, element.acbQuest)
      end
    end,
    tip = function(_, element)
      if element.acbQuest then
        RT.AddQuestTooltipLines(element.acbQuest)
      end
    end,
  })
end

local function CategoryHeader(parent)
  return RT.api:Create("cardHeader", parent, {
    text = function(element) return element.acbText end,
    checked = function(element) return element.acbShare ~= "none" end,
    count = function(element) return element.acbCount end,
    onCheck = function(element)
      Guarded(RT.RequestSetQuestsInSelection, element.acbEntry, element.acbKeys, element.acbShare ~= "all")
    end,
  })
end

local function RightItems(entry)
  local desired = entry.desiredQuests or {}
  local items = {}

  for _, group in ipairs(Contents(entry)) do
    if #(group.items) > 0 then
      local keys = {}

      for i, item in ipairs(group.items) do
        keys[i] = item.key
      end

      local share, count = Share(desired, keys)

      items[#(items) + 1] = {
        key = "h:" .. tostring(group.id), kind = "header", header = true, text = group.name, keys = keys, entry = entry,
        share = share, count = count,
      }

      for _, item in ipairs(group.items) do
        items[#(items) + 1] = {
          key = "q:" .. item.key, kind = "card", entry = entry, quest = item.quest, questKey = item.key,
          wanted = desired[item.key] == true,
        }
      end
    end
  end

  return items
end

local function FillRight(element, item)
  if item.header then
    element.acbText, element.acbKeys, element.acbEntry = item.text, item.keys, item.entry
    element.acbShare, element.acbCount = item.share, item.count
    return
  end

  local quest = item.quest

  element.acbEntry, element.acbKey, element.acbQuest, element.acbIn = item.entry, item.questKey, quest, item.wanted

  if quest then
    local title = Core.questTitle(quest)

    element.acbIcon = RT.QuestCategoryIcon(quest) or ICON_UNKNOWN
    element.acbTitle = title ~= "" and title or L.QUEST_UNKNOWN_TITLE
    element.acbSub = RT.QuestBoardLine(quest)
  else
    element.acbIcon, element.acbTitle, element.acbSub = ICON_UNKNOWN, UnknownTitle(item.questKey), ""
  end
end

local function FinishRight(element, item)
  local box = element.kitBox

  if not box then
    return
  end

  if item.header then
    box.tipTitle, box.tipBody = L.COLLECTIONS_CATEGORY_BOX, L.COLLECTIONS_CATEGORY_BOX_TIP

    if box.mark then
      box.mark:SetAlpha(element.acbShare == "some" and PARTIAL_ALPHA or 1)
    end
  else
    box.tipTitle, box.tipBody = L.COLLECTIONS_IN_BOX, L.COLLECTIONS_IN_BOX_TIP
  end
end

local function DrawContents(entry)
  local items = RightItems(entry)
  local cards = 0

  for _, item in ipairs(items) do
    if not item.header then
      cards = cards + 1
    end
  end

  right.stack:SetItems(items)

  return cards
end

local function Row(elements, top)
  local x = PAD

  for _, element in ipairs(elements) do
    element:ClearAllPoints()
    element:SetPoint("TOPLEFT", page.detail, "TOPLEFT", x, -top)
    element:Refresh()
    element:Show()
    x = x + element:GetWidth() + GAP
  end
end

local function ShowEmpty(text)
  right.empty:SetText(text)
  right.empty:Show()
end

local function DrawRight(entry)
  local width, height = SizeOf(page.detail, DETAIL_SIZE)
  local view = width - PAD * 2 - BarRoom()

  right.entry = entry
  right.stack:SetView(view, height - CONTENT_TOP - PAD)
  right.empty:Hide()

  if not entry then
    right.title:SetText(L.COLLECTIONS_TAB)
    right.sub:SetText("")

    for _, element in ipairs({ right.load, right.revert, right.save, right.more, right.all }) do
      element:Hide()
    end

    right.stack:SetItems({})
    ShowEmpty(L.LISTS_WINDOW_EMPTY .. "\n" .. string.format(L.COLLECTIONS_NONE_HINT, L.COLLECTIONS_NEW))
    return
  end

  right.title:SetText(entry.name)
  right.sub:SetText(CollectionSub(entry))

  local row = { right.load }

  if RT.CollectionState(entry) == "modified" then
    row[#(row) + 1] = right.revert
  else
    right.revert:Hide()
  end

  row[#(row) + 1] = right.save
  row[#(row) + 1] = right.more
  Row(row, BUTTONS_TOP)
  Row({ right.all }, TOGGLE_TOP)

  if DrawContents(entry) == 0 then
    ShowEmpty(allKnown and L.COLLECTIONS_NO_KNOWN or string.format(L.COLLECTIONS_EMPTY, L.COLLECTIONS_ALL_KNOWN))
  end
end

Draw = function()
  if not page or broken or not page:IsSelected() or not page:IsVisible() then
    return
  end

  local profile = RT.GetAccountProfile()
  local shown = ShownEntry(profile)

  DrawLeft(profile, shown)
  DrawRight(shown)
end


local function BuildLeft()
  local list = page.list

  left.new = RT.api:Create("button", list, {
    text = function() return L.COLLECTIONS_NEW end,
    onClick = function() Guarded(RT.RequestCreateSelection, nil) end,
    tip = function(lines) lines:Add(L.LISTS_ADD_SELECTION_TOOLTIP, "text", true) end,
  })
  left.new:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
  left.group = RT.api:Create("button", list, {
    text = function() return L.COLLECTIONS_NEW_GROUP end,
    disabled = function() return Core.groupsFull(RT.GetAccountProfile()) end,
    onClick = function() Guarded(RT.RequestCreateGroup) end,
    tip = function(lines) lines:Add(L.LISTS_NEW_GROUP_TOOLTIP, "text", true) end,
  })
  left.group:SetPoint("LEFT", left.new, "RIGHT", GAP, 0)
  left.stack = RT.api:Create("stack", list, {
    kinds = {
      card = function(parent) return CollectionCard(parent) end,
      header = function(parent) return GroupHeader(parent) end,
    },
    fill = FillLeft,
  })
  left.stack:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(BAR_HEIGHT + GAP))
  left.stack:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
  left.empty = Bricks.text(left.stack.child, "small", "muted")
  left.empty:SetJustifyH("LEFT")
  left.drop = CreateFrame("Frame", nil, left.stack.child)
  left.drop:SetFrameLevel(left.stack.child:GetFrameLevel() + 10)
  left.drop:SetHeight(DROP_LINE)
  left.drop.line = left.drop:CreateTexture(nil, "OVERLAY")
  left.drop.line:SetTexture(Bricks.media("solid"))
  left.drop.line:SetAllPoints(left.drop)
  left.drop:Hide()
  left.follow = CreateFrame("Frame", nil, list)
end

local function LoadClicked()
  local entry = right.entry

  if not entry then
    return
  end

  if RT.IsSelectionActive(entry) then
    RT.RequestLoadCollection(nil)
  else
    RT.RequestLoadCollection(entry.id)
  end
end

local function LoadTip(lines)
  local entry = right.entry

  if not entry then
    return
  end

  if RT.IsSelectionActive(entry) then
    lines:Add(L.LISTS_ROW_CLEAR_ENTRY, "text", true)
  elseif RT.IsSelectionDifficultyLocked(entry) then
    lines:Add(L.LISTS_ROW_NEED_RESTED, "danger", true)
  else
    lines:Add(L.COLLECTIONS_LOAD_TIP, "text", true)
  end
end

local function BuildRight()
  local detail = page.detail

  right.title = Bricks.text(detail, "large", "heading")
  right.title:SetPoint("TOPLEFT", detail, "TOPLEFT", PAD, -TITLE_TOP)
  right.title:SetPoint("RIGHT", detail, "RIGHT", -PAD, 0)
  right.sub = Bricks.text(detail, "small", "muted")
  right.sub:SetPoint("TOPLEFT", detail, "TOPLEFT", PAD, -SUB_TOP)
  right.sub:SetPoint("RIGHT", detail, "RIGHT", -PAD, 0)

  for _, text in ipairs({ right.title, right.sub }) do
    text:SetJustifyH("LEFT")

    if text.SetWordWrap then
      text:SetWordWrap(false)
    end
  end

  right.load = RT.api:Create("button", detail, {
    text = function()
      return right.entry and RT.IsSelectionActive(right.entry) and L.COLLECTIONS_UNLOAD or L.COLLECTIONS_LOAD
    end,
    disabled = function() return right.entry ~= nil and RT.IsSelectionDifficultyLocked(right.entry) end,
    onClick = function() Guarded(LoadClicked) end,
    tip = function(lines) LoadTip(lines) end,
  })
  right.revert = RT.api:Create("button", detail, {
    text = function() return L.COLLECTIONS_REVERT end,
    onClick = function()
      if right.entry then
        Guarded(RT.LoadCollection, right.entry.id)
      end
    end,
    tip = function(lines) lines:Add(L.COLLECTIONS_REVERT_TIP, "text", true) end,
  })
  right.save = RT.api:Create("button", detail, {
    text = function() return L.LISTS_MENU_UPDATE end,
    onClick = function() Guarded(RT.RequestOverwriteSelection, right.entry) end,
    tip = function(lines) lines:Add(L.COLLECTIONS_SAVE_TIP, "text", true) end,
  })
  right.more = RT.api:Create("button", detail, {
    text = function() return L.COLLECTIONS_OPTIONS end,
    onClick = function(element) Guarded(RT.ShowSelectionContextMenu, element, right.entry) end,
  })
  right.all = RT.api:Create("toggle", detail, {
    text = function() return L.COLLECTIONS_ALL_KNOWN end,
    get = function() return allKnown end,
    onChange = function(_, value)
      allKnown = value and true or false
      Guarded(Draw)
    end,
    tip = function(lines) lines:Add(L.COLLECTIONS_ALL_KNOWN_TIP, "text", true) end,
  })
  right.stack = RT.api:Create("stack", detail, {
    kinds = {
      card = function(parent) return ContractCard(parent) end,
      header = function(parent) return CategoryHeader(parent) end,
    },
    fill = FillRight,
    finish = FinishRight,
  })
  right.stack:SetPoint("TOPLEFT", detail, "TOPLEFT", PAD, -CONTENT_TOP)
  right.stack:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -PAD, PAD)
  right.empty = Bricks.text(detail, "normal", "muted")
  right.empty:SetPoint("TOPLEFT", detail, "TOPLEFT", PAD, -CONTENT_TOP)
  right.empty:SetPoint("RIGHT", detail, "RIGHT", -PAD, 0)
  right.empty:SetJustifyH("LEFT")
  right.empty:Hide()
end

local function Build()
  if page or broken then
    return
  end

  page = RT.api:BoardTab({
    text = function() return L.COLLECTIONS_TAB end,
    onSelect = function() Guarded(Draw) end,
  })

  if not page then
    return
  end

  page.acbLeft, page.acbRight = left, right
  RT.collectionsPage = page
  BuildLeft()
  BuildRight()
end


function RT.RefreshCollections()
  if page and not broken and page:IsSelected() and page:IsVisible() then
    Guarded(Draw)
  end
end

function RT.IsCollectionsShown()
  return page ~= nil and not broken and page:IsSelected() and page:IsVisible() and true or false
end

function RT.ShowCollection(id)
  shownId = id
end

RT.api:On("CALLBOARD_UI_CREATED", function()
  Guarded(Build)
end)

RT.api:On("CALLBOARD_UI_REFRESHED", function()
  RT.RefreshCollections()
end)
