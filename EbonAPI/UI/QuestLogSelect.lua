EbonAPI = EbonAPI or {}
EbonAPI.QuestLogSelect = {}

local QuestLogSelect = EbonAPI.QuestLogSelect
local Lib = EbonAPI.Lib
local Kit = EbonAPI.Kit
local QuestLog = EbonAPI.QuestLog
local QuestLogSelection = EbonAPI.QuestLogSelection
local L = EbonAPI.L
local S = EbonAPI.Skins.value

local type, ipairs = type, ipairs

local OWNER = EbonAPI.name

local installed = false
local reported = false
local active = false
local wasBusy = false
local reserved = 0
local panel, scroll, child, search, settings, toggle, bar, abandonButton, cancelButton, abandonProxy, cancelProxy

local function api(name)
  return rawget(_G, name)
end

local function fail(reason)
  if reported then
    return
  end

  reported = true
  Lib.report("QuestLogSelect: " .. reason, OWNER)
end

local function proxy(button)
  local view = {}

  function view:SetText(text)
    button:SetLabel(text)
  end

  function view:Enable()
    button:SetDisabledState(false)
  end

  function view:Disable()
    button:SetDisabledState(true)
  end

  function view:Show()
    button:Show()
  end

  function view:Hide()
    button:Hide()
  end

  function view:SetScript(_, handler)
    button.onClick = function()
      handler()
    end
  end

  return view
end

local function isHeader(frame)
  return frame.toggle ~= nil and frame.track == nil
end

local function isRow(frame)
  return frame.track ~= nil and frame.badge ~= nil
end

local function readZoneIds(header, ids)
  local total = GetNumQuestLogEntries()
  local index = (header._index or 0) + 1

  while index <= total do
    local _, _, _, _, head, _, _, _, questID = GetQuestLogTitle(index)

    if head then
      break
    end

    if questID then
      ids[#ids + 1] = questID
    end

    index = index + 1
  end
end

local function zoneIds(header)
  local ids = {}

  if not header._clientCollapsed then
    readZoneIds(header, ids)
    return ids
  end

  local headerIndex = header._index

  ExpandQuestHeader(headerIndex)
  local ok, err = pcall(readZoneIds, header, ids)
  CollapseQuestHeader(headerIndex)

  if not ok then
    error(err, 0)
  end

  return ids
end

local function zoneChecked(ids)
  if #ids == 0 then
    return false
  end

  for _, questID in ipairs(ids) do
    if not QuestLog.isChecked(questID) then
      return false
    end
  end

  return true
end

local function sized(box, reference)
  local width, height = reference:GetSize()

  if not width or width <= 0 then
    width = S("kit.questlog.check")
    height = width
  end

  box:SetSize(width, height)
end

local function questBox(row)
  local box = row.ebonapiSelect

  if box then
    return box
  end

  box = Kit.create(OWNER, "toggle", row, {
    onChange = function(self, value)
      if row._questID then
        QuestLog.check({ row._questID }, value)
      end
    end,
  })

  box:SetFrameLevel(row:GetFrameLevel() + 2)
  box:ClearAllPoints()
  box:SetPoint("TOPRIGHT", row.track, "TOPRIGHT", 0, 0)
  sized(box, row.track)
  row.ebonapiSelect = box

  return box
end

local function zoneBox(header)
  local box = header.ebonapiSelect

  if box then
    return box
  end

  box = Kit.create(OWNER, "toggle", header, {
    tip = L.QUESTLOG_SELECT_ZONE,
    onChange = function(self, value)
      QuestLog.check(zoneIds(header), value)
    end,
  })

  box:SetFrameLevel(header:GetFrameLevel() + 2)
  box:ClearAllPoints()
  box:SetPoint("RIGHT", header, "RIGHT", -2, 0)
  box:SetSize(S("kit.questlog.check"), S("kit.questlog.check"))
  header.ebonapiSelect = box

  return box
end

local function release(frame)
  if frame.ebonapiSelect then
    frame.ebonapiSelect:Hide()
  end

  if frame.track then
    frame.track:Show()
  end
end

local function decorate(frame)
  if not frame:IsShown() then
    if frame.ebonapiSelect then
      frame.ebonapiSelect:Hide()
    end

    return
  end

  if isHeader(frame) then
    local box = zoneBox(frame)

    box:SetValue(zoneChecked(zoneIds(frame)))
    box:Show()
  elseif isRow(frame) then
    if frame._questID then
      local box = questBox(frame)

      frame.track:Hide()
      box:SetValue(QuestLog.isChecked(frame._questID))
      box:Show()
    else
      release(frame)
    end
  end
end

local function sweep()
  for _, frame in ipairs({ child:GetChildren() }) do
    if isHeader(frame) or isRow(frame) then
      if active then
        decorate(frame)
      else
        release(frame)
      end
    end
  end
end

local function reserve(height)
  if reserved == height then
    return
  end

  reserved = height
  DragonUI.WorldMap.SetListInset(height)
end

local function refreshBar()
  local show = active and QuestLogSelection.count() > 0

  if not show then
    bar:Hide()
    reserve(0)

    return
  end

  bar:Show()
  QuestLogSelection.refresh(abandonProxy, cancelProxy, true)
  reserve(bar:GetHeight())
end

local function setMode(on)
  on = on and true or false

  if on == active then
    return
  end

  active = on
  wasBusy = false
  toggle:SetValue(on)

  if on then
    sweep()
    refreshBar()

    return
  end

  sweep()
  QuestLog.clear()
  refreshBar()
end

local function changed()
  if not active then
    return
  end

  local busy = QuestLogSelection.busy()

  if wasBusy and not busy then
    setMode(false)

    return
  end

  wasBusy = busy
  sweep()
  refreshBar()
end

local function buildToggle()
  toggle = Kit.create(OWNER, "toggle", panel, {
    tip = L.QUESTLOG_SELECT_MODE,
    get = function()
      return active
    end,
    onChange = function(self, value)
      setMode(value)
    end,
  })

  local at, relative, relativeAt, x, y

  for index = 1, search:GetNumPoints() do
    local point, target, targetPoint, px, py = search:GetPoint(index)

    if point == "TOPRIGHT" then
      at, relative, relativeAt, x, y = point, target, targetPoint, px, py
    end
  end

  toggle:ClearAllPoints()
  toggle:SetPoint(at, relative, relativeAt, x, y)
  toggle:SetHeight(search:GetHeight())
  search:SetPoint("TOPRIGHT", toggle, "TOPLEFT", -S("kit.gap"), 0)
end

local function buildBar()
  bar = Kit.create(OWNER, "bar", panel, { frame = "SMALL", layout = "HORIZONTAL" })

  abandonButton = Kit.create(OWNER, "button", bar, {
    text = function()
      return QuestLogSelection.label()
    end,
  })

  cancelButton = Kit.create(OWNER, "button", bar, { text = L.UI_CANCEL })

  abandonProxy = proxy(abandonButton)
  cancelProxy = proxy(cancelButton)

  QuestLogSelection.bind(abandonProxy, cancelProxy, function()
    setMode(false)
  end)

  local list = DragonUI.WorldMap.listFrame

  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, 0)
  bar:SetFrameLevel(panel:GetFrameLevel() + 6)
  bar:Hide()
end

function QuestLogSelect.install()
  if installed then
    return
  end

  local missing

  panel = api("DragonUIWorldMapQuestLog")
  scroll = api("DragonUIWorldMapQuestList")
  search = api("DragonUIWorldMapQuestSearch")
  settings = api("DragonUIWorldMapQuestSettings")

  local manager = api("DragonUI")
  local map = manager and manager.WorldMap

  if not panel then
    missing = "DragonUIWorldMapQuestLog"
  elseif not scroll then
    missing = "DragonUIWorldMapQuestList"
  elseif not search then
    missing = "DragonUIWorldMapQuestSearch"
  elseif not settings then
    missing = "DragonUIWorldMapQuestSettings"
  elseif not map or not map.listFrame then
    missing = "DragonUI.WorldMap.listFrame"
  elseif type(map.SetListInset) ~= "function" then
    missing = "DragonUI.WorldMap.SetListInset"
  elseif not scroll.GetScrollChild or not scroll:GetScrollChild() then
    missing = "DragonUIWorldMapQuestList scroll child"
  elseif type(api("hooksecurefunc")) ~= "function" or not Kit or type(Kit.create) ~= "function" then
    missing = "hooksecurefunc or Kit.create"
  end

  if missing then
    fail("missing " .. missing .. ", selection mode not installed")

    return
  end

  installed = true
  child = scroll:GetScrollChild()

  buildToggle()
  buildBar()

  local previous = QuestLog.onChange

  QuestLog.onChange = function(...)
    if type(previous) == "function" then
      previous(...)
    end

    Lib.safeCall(changed)
  end

  hooksecurefunc(child, "SetHeight", function()
    if active then
      Lib.safeCall(sweep)
    end
  end)

  panel:HookScript("OnHide", function()
    if active then
      setMode(false)
    end
  end)
end
