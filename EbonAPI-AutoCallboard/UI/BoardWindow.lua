local Core = AutoCallboardCore
local Skin = AutoCallboardSkin
local L = AutoCallboardLocale
local RT = AutoCallboardRuntime
local state = RT.state

local Bricks = EbonAPI.Bricks
local Ebonhold = EbonAPI.Ebonhold


local FRAME = "EbonholdCallboardFrame"
local TAB = FRAME .. "Tab"
local MAX_TABS = 20
local BAR_GAP = 8
local PARTIAL_ALPHA = Core.PARTIAL_ALPHA
local MENU_ENTRIES_PER_LEVEL = 20
local PE_ROW_INSET, PE_HEADER_INSET = 12, 4
local WEAK = Core.WEAK

local window
local built, broken = false, false
local parts = {}
local own = setmetatable({}, WEAK)
local rowBoxes = setmetatable({}, WEAK)
local headerBoxes = setmetatable({}, WEAK)
local hookedRows = setmetatable({}, WEAK)
local offCards = {}
local offHeader, takeBox, statusLine, startButton
local selectedQuest
local actionHooked, actionWriting, actionGrafted, peText, peClick
local statusShown, statusFull = "", ""
local lastDress
local OFF_VOLET = "acb:off"
local offShare, offGoal
local offDriver
local offWatch = 0

local function VoletMoving()
  local accordion = EbonAPI.BoardAccordion

  if type(accordion) == "table" and type(accordion.state) == "function" then
    local ok, _, moving = pcall(accordion.state)

    return ok and moving == true
  end

  return false
end
local redrawBoard

local function IsType(object, kind)
  return type(object) == "table" and type(object.GetObjectType) == "function" and object:GetObjectType() == kind
end

local QuestKey = Core.questIndexKey

local function IsRow(child)
  return not own[child] and not child.spec and IsType(child, "Button") and child.glow ~= nil and child.edge ~= nil
      and IsType(child.title, "FontString") and IsType(child.sub, "FontString")
end

local function IsHeader(child)
  if own[child] or child.spec or not IsType(child.text, "FontString") then
    return false
  end

  if child.glow ~= nil or child.edge ~= nil then
    return false
  end

  if IsType(child, "Button") then
    return IsType(child.toggle, "Texture")
  end

  return IsType(child, "Frame")
end

local function HeaderKeys(header)
  local board = RT.GetBoard()
  local key = header.key

  if type(key) ~= "string" or not board or type(board.quests) ~= "table" then
    return nil
  end

  local category, cadence, zone = key:match("^(%d+):(%d+):(.*)$")

  if not category then
    category, cadence = key:match("^(%d+):(%d+)$")
  end

  if not category then
    return nil
  end

  category, cadence = tonumber(category), tonumber(cadence)

  local keys = {}

  for _, quest in ipairs(board.quests) do
    if quest.state ~= Core.STATE.EXHAUSTED and tonumber(quest.category) == category
        and tonumber(quest.cadence) == cadence
        and (zone == nil or (EbonAPI.State.CallboardZone(quest) or "") == zone) then
      local questKey = QuestKey(quest)

      if questKey then
        keys[#(keys) + 1] = questKey
      end
    end
  end

  return keys
end

local function TopOf(region)
  local _, _, _, _, y = region:GetPoint(1)

  return -(tonumber(y) or 0)
end

local function ShownItems(content)
  local items = {}

  for _, child in ipairs({ content:GetChildren() }) do
    if child:IsShown() then
      if IsRow(child) then
        items[#(items) + 1] = { frame = child, row = true, top = TopOf(child) }
      elseif IsHeader(child) then
        items[#(items) + 1] = { frame = child, top = TopOf(child) }
      end
    end
  end

  table.sort(items, function(a, b)
    if a.top ~= b.top then
      return a.top < b.top
    end

    return not a.row and b.row
  end)

  return items
end

local function ShownCategory()
  local categories = EbonAPI.State.CallboardCategories()

  for index, category in ipairs(categories) do
    local left = Ebonhold.Frame(TAB .. index .. "LeftDisabled")

    if left and left:IsShown() then
      return category.id
    end
  end

  return nil
end

local function CategoryIcon(quest)
  local category = Core.displayCategory(quest)

  for _, entry in ipairs(EbonAPI.State.CallboardCategories()) do
    if entry.id == category then
      return entry.icon
    end
  end

  return nil
end

local Fit = Skin.FitText

local function SquareBox(parent, spec)
  local box = RT.api:Create("toggle", parent, spec)
  local width, height = box.box:GetWidth(), box.box:GetHeight()

  box.acbSquare = { width, height }
  box.spec.width = width
  box:SetWidth(width)
  box:SetHeight(height)
  own[box] = true

  return box
end

local function FitBox(box, holder)
  local width, height = box.acbSquare[1], box.acbSquare[2]
  local room = holder:GetHeight()

  if room > 0 and height > room then
    width, height = width * room / height, room
  end

  box.box:SetWidth(width)
  box.box:SetHeight(height)
  box.spec.width = width
  box:SetWidth(width)
  box:SetHeight(height)
end

local function PartialCount(keys)
  if RT.GetWantedState(keys) ~= "some" then
    return nil
  end

  local count = 0

  for i = 1, #(keys) do
    if RT.IsWanted(keys[i]) then
      count = count + 1
    end
  end

  return count .. "/" .. #(keys)
end

local function ShowGroup(box, keys, withCount)
  local wanted = RT.GetWantedState(keys)

  box:SetValue(wanted ~= "none")

  if box.mark then
    box.mark:SetAlpha(wanted == "some" and PARTIAL_ALPHA or 1)
  end

  if not withCount then
    return
  end

  if not box.acbCount then
    box.acbCount = Bricks.text(box, "small", "muted")
    box.acbCount:SetPoint("RIGHT", box, "LEFT", -4, 0)
  end

  local count = PartialCount(keys)

  box.acbCount:SetText(count or "")

  if count then
    box.acbCount:Show()
  else
    box.acbCount:Hide()
  end
end

local function ToggleGroup(keys)
  if type(keys) == "table" and #(keys) > 0 then
    RT.SetWantedKeys(keys, RT.GetWantedState(keys) ~= "all")
  end

  RT.RefreshBoardGraft()
end


local function QuestLabel(quest)
  local title = Core.questTitle(quest)
  local questID = tonumber(quest and quest.questId)

  if title == "" then
    title = L.QUEST_UNKNOWN_TITLE
  end

  if questID and questID > 0 then
    return title .. " (" .. tostring(math.floor(questID)) .. ")"
  end

  return title
end

local questContextMenu
local BuildQuestCollectionMenu

local QuestContextKey = Core.questIndexKey

local function EnsureQuestContextMenu()
  if not questContextMenu then
    questContextMenu = Skin.Menu("AutoCallboardQuestContextMenu")
    RT.questContextMenu = questContextMenu
  end

  return questContextMenu
end

local function AddCollectionItems(menu, quest, key, groupId)
  local entries = Core.selectionsInContainer(RT.GetAccountProfile(), groupId)
  local shown = 0

  for i = 1, #(entries) do
    if shown >= MENU_ENTRIES_PER_LEVEL then
      menu:AddItem(string.format(L.QUEST_MENU_MORE, #(entries) - shown), { disabled = true })
      break
    end

    local entry = entries[i]
    local inside = Core.selectionHasQuest(entry, key)
    shown = shown + 1

    menu:AddItem(entry.name, {
      checked = inside,
      keepOpen = true,
      onClick = function()
        RT.RequestSetQuestInSelection(entry, key, not inside)
        BuildQuestCollectionMenu(menu, quest, groupId)
        end,
    })
  end

  return #(entries)
end

BuildQuestCollectionMenu = function(menu, quest, groupId)
  local key = QuestContextKey(quest)
  local profile = RT.GetAccountProfile()
  local group = nil

  if groupId then
    group = Core.findGroup(profile, groupId)
  end

  menu:Reset()
  menu:AddItem(QuestLabel(quest), { header = true })

  if group then
    menu:AddItem("< " .. group.name, {
      keepOpen = true,
      onClick = function()
        BuildQuestCollectionMenu(menu, quest, nil)
        end,
    })
  end

  local count = AddCollectionItems(menu, quest, key, groupId)

  if not group then
    local groups = profile.groups

    for i = 1, #(groups) do
      local entry = groups[i]
      count = count + Core.selectionCount(profile, entry.id)

      menu:AddItem(entry.name, {
        arrow = true,
        keepOpen = true,
        onClick = function()
          BuildQuestCollectionMenu(menu, quest, entry.id)
          end,
      })
    end
  end

  if count == 0 then
    menu:AddItem(L.QUEST_MENU_NO_COLLECTION, { disabled = true })
  end

  menu:AddItem(L.QUEST_MENU_NEW, {
    onClick = function()
      RT.RequestCreateSelectionWithQuest(key, groupId)
      end,
  })

  menu:Layout()
end

local function ShowQuestContextMenu(row, quest)
  if not QuestContextKey(quest) then
    return
  end

  local menu = EnsureQuestContextMenu()
  BuildQuestCollectionMenu(menu, quest, nil)
  menu:OpenAt(row, "TOPLEFT", "BOTTOMLEFT", 8, -2)
end

RT.ShowQuestContextMenu = ShowQuestContextMenu


local function AddRewardLines(quest)
  local lines = {}
  local function add(field, key)
    local value = tonumber(quest[field]) or 0

    if value > 0 then
      lines[#(lines) + 1] = string.format(L[key], RT.FormatNumber(value))
    end
  end

  add("ashes", "REWARD_ASHES")
  add("xp", "REWARD_XP")

  if (tonumber(quest.copper) or 0) > 0 then
    lines[#(lines) + 1] = GetCoinTextureString(quest.copper)
  end

  add("artisan", "REWARD_ARTISAN")
  add("orbs", "REWARD_ORBS")
  add("shards", "REWARD_SHARDS")

  local item = tonumber(quest.item) or 0

  if item > 0 then
    local _, link = GetItemInfo(item)
    local label = link or string.format(L.REWARD_ITEM, item)
    local itemCount = tonumber(quest.itemCount) or 1

    lines[#(lines) + 1] = itemCount > 1 and (label .. " x" .. itemCount) or label
  end

  if #(lines) == 0 then
    return
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.QUEST_TOOLTIP_REWARDS, 1, 0.82, 0)

  for i = 1, #(lines) do
    GameTooltip:AddLine(lines[i], 1, 1, 1)
  end
end

local function BoardStateText(quest)
  if not RT.GetBoard() then
    return nil
  end

  local contract = RT.GetBoardQuest(quest.questId)

  if not contract then
    return L.QUEST_TOOLTIP_NOT_POSTED
  end

  local text = L.CONTRACT_STATE_NAMES[contract.state] or ""

  if contract.cadence ~= Core.CADENCE.ONCE then
    text = text .. string.format(L.CONTRACT_COUNTER, contract.done, contract.max)
  end

  return text
end

local function AddQuestLines(quest)
  if type(quest) ~= "table" then
    return
  end

  if tonumber(quest.questId) and tonumber(quest.questId) > 0 then
    GameTooltip:AddDoubleLine(L.QUEST_TOOLTIP_ID, tostring(math.floor(tonumber(quest.questId))), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  GameTooltip:AddDoubleLine(L.QUEST_TOOLTIP_CATEGORY, RT.GetQuestCategoryName(Core.displayCategory(quest)), 0.8, 0.8, 0.8, 1, 1, 1)

  local cadence = quest.cadence and L.CADENCE_NAMES[quest.cadence]
  if cadence then
    GameTooltip:AddDoubleLine(L.QUEST_TOOLTIP_CADENCE, quest.accountWide and (cadence .. L.QUEST_TOOLTIP_ACCOUNT_WIDE) or cadence,
      0.8, 0.8, 0.8, 1, 1, 1)
  end

  local boardState = BoardStateText(quest)
  if boardState then
    GameTooltip:AddDoubleLine(L.QUEST_TOOLTIP_STATE, boardState, 0.8, 0.8, 0.8, 1, 1, 1)
  end

  local contract = RT.GetBoardQuest(quest.questId)
  local outleveled = Core.outleveledAbove(contract)

  if outleveled > 0 then
    if Core.paysNothing(contract) then
      GameTooltip:AddLine(string.format(L.QUEST_TOOLTIP_OUTLEVELED, outleveled), 1, 0.25, 0.25, true)
    else
      GameTooltip:AddLine(string.format(L.QUEST_TOOLTIP_OUTLEVELED_PARTIAL,
        math.floor(tonumber(contract.payPct) or 0), outleveled), 1, 0.82, 0.25, true)
    end
  end

  local objectiveText = Core.objectiveText(quest)
  if objectiveText ~= "" then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(objectiveText, 1, 1, 1, true)
  end

  local description = Core.trim(quest.description)

  if description == "" and contract then
    description = Core.trim(contract.description)
  end

  if description ~= "" and description ~= objectiveText then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(description, 0.8, 0.8, 0.8, true)
  end

  AddRewardLines(quest)

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.QUEST_TOOLTIP_RIGHT_CLICK, 0.8, 0.8, 0.8)
end

local function BoardLine(quest)
  local text = BoardStateText(quest)
  local cadence = quest.cadence and L.CADENCE_NAMES[quest.cadence]

  if text and cadence then
    return text .. "  -  " .. cadence
  end

  return text or cadence or ""
end

RT.AddQuestTooltipLines = AddQuestLines
RT.QuestCategoryIcon = CategoryIcon
RT.QuestBoardLine = BoardLine


local function RowMouseUp(row, mouse)
  if mouse == "RightButton" and row.quest and not broken then
    ShowQuestContextMenu(row, row.quest)
  end
end

local function onBoxChange(element, value)
  if element.acbKey then
    RT.SetWanted(element.acbKey, value)
  end

  RT.RefreshBoardGraft()
end

local function RowBox(row)
  local box = rowBoxes[row]

  if box then
    return box
  end

  box = SquareBox(row, {
    text = "",
    onChange = onBoxChange,
  })
  box:ClearAllPoints()
  box:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  box:HookScript("OnEnter", function()
    local enter = row:GetScript("OnEnter")

    if enter then
      enter(row)
    end
  end)
  box:HookScript("OnLeave", function()
    local leave = row:GetScript("OnLeave")

    if leave then
      leave(row)
    end
  end)
  box:HookScript("OnMouseUp", function(_, mouse)
    RowMouseUp(row, mouse)
  end)
  rowBoxes[row] = box

  if not hookedRows[row] then
    hookedRows[row] = true
    row:HookScript("OnMouseUp", RowMouseUp)
  end

  return box
end

local function HeaderBox(header)
  local box = headerBoxes[header]

  if box then
    return box
  end

  box = SquareBox(header, {
    text = "",
    onChange = function(element)
      ToggleGroup(element.acbKeys)
    end,
  })
  box:ClearAllPoints()
  box:SetPoint("RIGHT", header, "RIGHT", -4, 0)
  headerBoxes[header] = box

  return box
end

local function DecorateRow(row)
  local box = RowBox(row)
  local key = QuestKey(row.quest)

  FitBox(box, row)
  box.acbKey = key
  box.tipTitle, box.tipBody = L.BOARD_TAKE_AUTO, L.BOARD_TAKE_AUTO_TIP

  if key then
    box:SetValue(RT.IsWanted(key))
    box:Show()
  else
    box:Hide()
  end

  RT.api:BoardRowInset(row, box:GetWidth() + 12)

  return key
end

local function DecorateHeader(header, keys)
  local box = HeaderBox(header)
  local room

  FitBox(box, header)
  box.acbKeys = keys
  box.tipTitle, box.tipBody = L.BOARD_GROUP_BOX, L.BOARD_GROUP_BOX_TIP

  if #(keys) == 0 then
    box:Hide()
  else
    ShowGroup(box, keys, true)
    box:Show()
  end

  room = box:GetWidth() + 8

  if box:IsShown() and box.acbCount and box.acbCount:IsShown() then
    room = room + box.acbCount:GetStringWidth() + 4
  end

  RT.api:BoardHeaderInset(header, room)
end

local function DecorateTake(selected)
  if not takeBox then
    return
  end

  local key = selected and QuestKey(selected.quest)

  takeBox.acbKey = key
  takeBox.tipTitle, takeBox.tipBody = L.BOARD_TAKE_AUTO, L.BOARD_TAKE_AUTO_TIP

  if key then
    takeBox:SetValue(RT.IsWanted(key))
    takeBox:Show()
  else
    takeBox:Hide()
  end
end


local function CardSub(quest)
  local contract = RT.GetBoardQuest(quest.questId)
  local text = contract and contract.state == Core.STATE.EXHAUSTED and L.CONTRACT_STATE_NAMES[Core.STATE.EXHAUSTED]
      or L.QUEST_TOOLTIP_NOT_POSTED
  local cadence = quest.cadence and L.CADENCE_NAMES[quest.cadence]

  if cadence then
    text = text .. "  -  " .. cadence
  end

  return text
end

local function LevelOf(quest)
  local level = tonumber(quest.level)

  if level == nil then
    local posted = RT.GetBoardQuest(quest.questId)

    level = posted and tonumber(posted.level)
  end

  if level == nil then
    return nil
  end

  if level > 0 then
    return level
  end

  return UnitLevel("player")
end

local function LevelTag(quest)
  local level = type(quest) == "table" and LevelOf(quest)

  if not level then
    return ""
  end

  local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)

  if type(color) ~= "table" then
    return string.format("[%d] ", level)
  end

  return string.format("|cff%02x%02x%02x[%d]|r ", (color.r or 1) * 255, (color.g or 1) * 255, (color.b or 1) * 255,
    level)
end

local function OffCard(content, index)
  local card = offCards[index]

  if card then
    return card
  end

  card = RT.api:Create("card", content, {
    icon = function(element) return CategoryIcon(element.acbQuest) end,
    round = true,
    title = function(element)
      local title = Core.questTitle(element.acbQuest)

      return LevelTag(element.acbQuest) .. (title ~= "" and title or L.QUEST_UNKNOWN_TITLE)
    end,
    sub = function(element) return element.acbQuest and CardSub(element.acbQuest) or "" end,
    checked = function(element) return RT.IsWanted(QuestKey(element.acbQuest)) end,
    onCheck = function(element, checked)
      local key = QuestKey(element.acbQuest)

      if key then
        RT.SetWanted(key, checked)
      end

      RT.RefreshBoardGraft()
    end,
    onClick = function(element, mouse)
      if mouse == "RightButton" then
        ShowQuestContextMenu(element, element.acbQuest)
      end
    end,
    tip = function(_, element) AddQuestLines(element.acbQuest) end,
  })
  own[card] = true
  offCards[index] = card

  return card
end

local function OffHeader(content)
  if offHeader then
    return offHeader
  end

  offHeader = RT.api:Create("cardHeader", content, {
    text = function(element)
      local total = #(element.acbKeys or {})

      if element.acbOpen or total == 0 then
        return L.BOARD_OFF_BOARD
      end

      return L.BOARD_OFF_BOARD .. "  |cffffffff+" .. total .. "|r"
    end,
    open = function(element) return element.acbOpen and true or false end,
    checked = function(element) return RT.GetWantedState(element.acbKeys or {}) ~= "none" end,
    count = function(element) return PartialCount(element.acbKeys or {}) end,
    onCheck = function(element) ToggleGroup(element.acbKeys) end,
    onClick = function(element, mouse)
      if mouse == "RightButton" then
        return
      end

      RT.api:BoardVoletSet(element.acbOpen and false or OFF_VOLET)
    end,
  })
  own[offHeader] = true

  return offHeader
end

local function HideOffBoard()
  if offHeader then
    offHeader:Hide()
  end

  for i = 1, #(offCards) do
    offCards[i]:Hide()
  end
end

local function OffBoardList()
  if not state.showOffBoard or not RT.GetBoard() then
    return {}
  end

  local category = ShownCategory()

  if not category then
    return {}
  end

  return RT.GetKnownOffBoard(category)
end

local function ListBottom(frame, items)
  local bottom = 0

  for i = 1, #(items) do
    bottom = math.max(bottom, items[i].top + items[i].frame:GetHeight())
  end

  if bottom > 0 then
    return bottom + 4
  end

  local empty = frame.emptyText

  if empty and empty:IsShown() and (empty:GetText() or "") ~= "" then
    return TopOf(empty) + empty:GetHeight() + 8
  end

  return 0
end

local function LayoutOffBoard(frame, items)
  local content = frame.content
  local base = ListBottom(frame, items)
  local list = OffBoardList()

  if #(list) == 0 then
    HideOffBoard()
    content:SetHeight(math.max(1, base))
    return
  end

  local first = items[1] and items[1].frame
  local x = first and tonumber((select(4, first:GetPoint(1)))) or 3
  local width = first and first:GetWidth() or (content:GetWidth() - 8)
  local gap = Bricks.value("board.row.gap") or 4
  local keys = {}

  for i = 1, #(list) do
    keys[i] = QuestKey(list[i])
  end

  local active = RT.api:BoardVoletActive()
  local open = active == OFF_VOLET or (#(items) == 0 and active ~= false)
  local goal = open and 1 or 0
  local fold = tonumber(Bricks.value("board.header.fold")) or 0

  if offShare == nil or fold <= 0 then
    offShare = goal
  end

  offGoal = goal

  local header = OffHeader(content)

  header.acbKeys = keys
  header.acbOpen = open
  header:SetWidth(width)
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", content, "TOPLEFT", x, -base)
  header:Refresh()
  header:Show()

  if header.kitBox then
    ShowGroup(header.kitBox, keys)
    header.kitBox.tipTitle, header.kitBox.tipBody = L.BOARD_GROUP_BOX, L.BOARD_GROUP_BOX_TIP
  end

  local top = base + header:GetHeight()
  local y = top
  local cards = {}

  for i = 1, #(list) do
    local card = OffCard(content, i)

    card.acbQuest = list[i]
    card:SetWidth(width)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", content, "TOPLEFT", x, -(y + gap))
    card:Refresh()

    if card.kitBox then
      card.kitBox.tipTitle, card.kitBox.tipBody = L.BOARD_TAKE_AUTO, L.BOARD_TAKE_AUTO_TIP
    end

    y = y + card:GetHeight() + gap
    cards[i] = y
  end

  local reach = top + (y - top) * offShare

  for i = 1, #(list) do
    if offShare > 0 and cards[i] <= reach + 0.5 then
      offCards[i]:Show()
    else
      offCards[i]:Hide()
    end
  end

  for i = #(list) + 1, #(offCards) do
    offCards[i]:Hide()
  end

  content:SetHeight(reach + 4)

  if (offShare ~= offGoal or offWatch > 0 or VoletMoving()) and fold > 0 then
    offDriver = offDriver or CreateFrame("Frame")
    offDriver.fold = fold
    offDriver:SetScript("OnUpdate", function(self, elapsed)
      local step = (elapsed or 0) / self.fold

      if offShare < offGoal then
        offShare = math.min(offGoal, offShare + step)
      else
        offShare = math.max(offGoal, offShare - step)
      end

      if offWatch > 0 then
        offWatch = offWatch - 1
      end

      if offShare == offGoal and offWatch == 0 and not VoletMoving() then
        self:SetScript("OnUpdate", nil)
      end

      if redrawBoard then
        redrawBoard()
      end
    end)
  end
end


local function CloseButton(frame)
  for _, child in ipairs({ frame:GetChildren() }) do
    if IsType(child, "Button") and child ~= frame.claimAll and not own[child]
        and not string.find(child:GetName() or "", "^" .. TAB) then
      local point, relative = child:GetPoint(1)

      if point == "BOTTOMRIGHT" and relative == frame then
        return child
      end
    end
  end

  return nil
end

local function DecorateStatus()
  if not statusLine then
    return
  end

  statusFull = RT.GetBoardStatusText() .. RT.FormatDifficultyStatus()

  local left = window and window.claimAll and window.claimAll:GetRight()
  local right = startButton and startButton:GetLeft()
  local room = (left and right) and (right - left - 2 * BAR_GAP) or statusLine.spec.width

  room = math.max(20, math.floor(room))
  statusLine.spec.width = room
  statusShown = Fit(statusLine.text, statusFull, room)
  statusLine:Refresh()
end

local function WantedIn(category)
  local known = state.knownQuests or {}
  local count = 0

  for i = 1, #(known) do
    if Core.displayCategory(known[i]) == category and RT.IsWanted(QuestKey(known[i])) then
      count = count + 1
    end
  end

  return count
end

local function TabTip(index)
  if broken then
    return
  end

  local category = EbonAPI.State.CallboardCategories()[index]
  local count = category and WantedIn(category.id) or 0

  if count > 0 then
    local color = EbonAPI.Palette.THEME.heading

    GameTooltip:AddLine(string.format(L.BOARD_TAB_WANTED, count), color[1], color[2], color[3])
    GameTooltip:Show()
  end
end


local function HideAll()
  for _, box in pairs(rowBoxes) do
    box:Hide()
  end

  for _, box in pairs(headerBoxes) do
    box:Hide()
  end

  HideOffBoard()

  for _, part in pairs({ takeBox or false, statusLine or false, startButton or false }) do
    if part then
      part:Hide()
    end
  end

  for row in pairs(rowBoxes) do
    RT.api:BoardRowInset(row, PE_ROW_INSET)
  end

  for header in pairs(headerBoxes) do
    RT.api:BoardHeaderInset(header, PE_HEADER_INSET)
  end
end

local function BuildNow(frame)
  if IsType(frame.content, "Frame") and IsType(frame.scroll, "ScrollFrame") then
    parts.list = true
  end

  local panel = frame.panel
  local strip = panel and panel.strip

  if IsType(panel, "Frame") and IsType(strip, "Frame") and IsType(panel.action, "Button") then
    takeBox = RT.api:Create("toggle", strip, {
      text = function() return L.BOARD_TAKE_AUTO end,
      onChange = onBoxChange,
    })
    takeBox:SetPoint("BOTTOMRIGHT", IsType(panel.travel, "Button") and panel.travel or panel.action, "TOPRIGHT", 0, BAR_GAP)
    takeBox:Hide()
    own[takeBox] = true
  end

  if IsType(frame.claimAll, "Button") then
    local close = CloseButton(frame)

    startButton = Skin.MakeButton(frame, {
      text = L.BUTTON_START,
      tipKey = "BOARD_START_TOOLTIP",
      onClick = function()
        if RT.IsStarted() then
          RT.Stop()
        else
          RT.Start()
        end
      end,
    })

    if close then
      startButton:SetPoint("RIGHT", close, "LEFT", -BAR_GAP, 0)
    else
      startButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -94, 13)
    end

    own[startButton] = true
    RT.boardStartButton = startButton

    statusLine = RT.api:Create("status", frame, {
      text = function() return statusShown end,
      width = 200,
    })
    statusLine:SetPoint("LEFT", frame.claimAll, "RIGHT", BAR_GAP, 0)

    if statusLine.text.SetWordWrap then
      statusLine.text:SetWordWrap(false)
    end

    statusLine:EnableMouse(true)
    statusLine:SetScript("OnEnter", function(self)
      Bricks.tip(self, L.ADDON_NAME_TOOLTIP, statusFull)
    end)
    statusLine:SetScript("OnLeave", Bricks.hideTip)
    own[statusLine] = true
  end

  for index = 1, MAX_TABS do
    local tab = Ebonhold.Frame(TAB .. index)

    if not tab then
      break
    end

    tab:HookScript("OnEnter", function()
      TabTip(index)
    end)
  end
end

local function DecorateNow(frame)
  local selected

  if parts.list then
    local items = ShownItems(frame.content)
    local group

    for _, item in ipairs(items) do
      if item.row then
        local key = DecorateRow(item.frame)

        if group and key then
          group.keys[#(group.keys) + 1] = key
        end

        if item.frame.selected then
          selected = item.frame
        end
      else
        group = { header = item.frame, keys = {} }
        item.group = group
      end
    end

    for _, item in ipairs(items) do
      if item.group then
        DecorateHeader(item.group.header, HeaderKeys(item.group.header) or item.group.keys)
      end
    end

    LayoutOffBoard(frame, items)
  end

  selectedQuest = selected and type(selected.quest) == "table" and selected.quest or nil
  DecorateTake(selected)
  RT.UpdateStartButtonState(startButton, RT.IsBoardAvailable())
  DecorateStatus()

  RT.SetTravelSelection(selected and type(selected.quest) == "table" and selected.quest.questId or nil)
end

local function Guard(fn, frame)
  if broken then
    return
  end

  local ok, err = pcall(fn, frame)

  if not ok then
    broken = true
    pcall(HideAll)
    EbonAPI.Lib.report(err, RT.api:GetName())
  end
end

local function NoteDress()
  local name, reason = RT.api:BoardDress()
  local seen = tostring(name) .. ":" .. tostring(reason)

  if seen ~= lastDress then
    lastDress = seen

    if RT.RefreshOptions then
      RT.RefreshOptions()
    end
  end
end

local function LotMode(questId)
  local posted = RT.GetBoardQuest(questId)

  if posted then
    if posted.state == Core.STATE.ACCEPTED then
      return "abandon"
    end

    return posted.state == Core.STATE.AVAILABLE and "accept" or nil
  end

  return RT.FindQuestLogIndexByID(questId) and "abandon" or "accept"
end

local function BoardLot()
  local shown = selectedQuest and selectedQuest.questId
  local mode = shown and LotMode(shown)

  if not mode then
    return nil, nil
  end

  local ids, seen = { shown }, { [shown] = true }
  local category = ShownCategory()
  local board = RT.GetBoard()
  local lists = { board and board.quests or {}, OffBoardList() }

  for l = 1, 2 do
    local list = lists[l]

    for i = 1, #(list) do
      local quest = list[i]
      local id = type(quest) == "table" and tonumber(quest.questId)

      if id and not seen[id] and Core.displayCategory(quest) == category
          and RT.IsWanted(QuestKey(quest)) and LotMode(id) == mode then
        seen[id] = true
        ids[#ids + 1] = id
      end
    end
  end

  return ids, mode, category
end

local function LotClick(button, ...)
  local ids, mode, category = BoardLot()

  if not ids or #ids < 2 then
    if mode == "abandon" and ids then
      RT.ExpectBoardAbandon(ids)
    end

    if peClick then
      peClick(button, ...)
    end

    return
  end

  if mode == "abandon" then
    RT.AbandonBoardLot(ids, category)
  else
    RT.AcceptBoardLot(ids)
  end
end

local function ApplyActionGraft(action)
  local ids = BoardLot()

  actionWriting = true

  if ids then
    action:SetText(#ids > 1 and string.format(L.BOARD_LOT_FORMAT, peText or "", #ids) or (peText or ""))
    action:SetScript("OnClick", LotClick)
    actionGrafted = true
  elseif actionGrafted then
    actionGrafted = false
    action:SetText(peText or "")
    action:SetScript("OnClick", peClick)
  end

  actionWriting = false
end

local function GraftActionButton(panel)
  local action = IsType(panel, "Frame") and panel.action

  if not IsType(action, "Button") then
    return
  end

  if not actionHooked then
    actionHooked = true
    peText, peClick = action:GetText(), action:GetScript("OnClick")

    hooksecurefunc(action, "SetText", function(self, text)
      if actionWriting then
        return
      end

      peText = text
      Guard(ApplyActionGraft, self)
    end)

    hooksecurefunc(action, "SetScript", function(self, name, fn)
      if actionWriting or name ~= "OnClick" then
        return
      end

      peClick = fn
      Guard(ApplyActionGraft, self)
    end)
  end

  ApplyActionGraft(action)
end

local function Decorate(frame)
  if built and frame == window and frame:IsShown() then
    Guard(DecorateNow, frame)
    Guard(GraftActionButton, frame.panel)
  end
end

local function Build(frame)
  if built or not IsType(frame, "Frame") then
    return
  end

  built, window = true, frame
  Guard(BuildNow, frame)
  Decorate(frame)
  NoteDress()
end

redrawBoard = function()
  if window then
    Decorate(window)
  end
end

function RT.RefreshBoardGraft()
  if window then
    Decorate(window)
  end

  RT.RefreshCollections()
end

function RT.RefreshBoardStatus()
  if built and not broken and window and window:IsShown() then
    Guard(DecorateStatus)
  end
end

function RT.IsBoardGraftBroken()
  return broken
end

function RT.ToggleBoardWindow()
  local ui = Ebonhold.CallboardUI()

  if type(ui) ~= "table" or type(ui.Show) ~= "function" then
    RT.Error(L.STATUS_BOARD_UNAVAILABLE)
    return
  end

  if RT.IsBoardWindowShown() then
    ui.Hide()
  else
    ui.Show()
  end
end

RT.api:On("CALLBOARD_UI_CREATED", function(_, frame)
  Build(frame)
end)

RT.api:On("CALLBOARD_VOLET_CHANGED", function()
  offWatch = 3
  redrawBoard()
end)

RT.api:On("CALLBOARD_UI_REFRESHED", function(_, frame)
  Decorate(frame)
  NoteDress()
end)
