EbonAPI = EbonAPI or {}
EbonAPI.QuestLogSelection = {}

local QuestLogSelection = EbonAPI.QuestLogSelection
local QuestLog = EbonAPI.QuestLog
local L = EbonAPI.L

local format = string.format

function QuestLogSelection.busy()
  return QuestLog.isAbandoning()
end

function QuestLogSelection.count()
  return #QuestLog.checkedList()
end

function QuestLogSelection.label()
  local position, size = QuestLog.progress()

  if position then
    return format(L.QUESTLOG_ABANDON_PROGRESS, position, size)
  end

  return format(L.QUESTLOG_ABANDON_SELECTED, QuestLogSelection.count())
end

function QuestLogSelection.canAbandon()
  return QuestLogSelection.count() > 0 and not QuestLogSelection.busy()
end

function QuestLogSelection.refresh(abandon, cancel, active)
  if not active then
    if abandon then
      abandon:Hide()
    end

    if cancel then
      cancel:Hide()
    end

    return
  end

  if abandon then
    abandon:SetText(QuestLogSelection.label())

    if QuestLogSelection.canAbandon() then
      abandon:Enable()
    else
      abandon:Disable()
    end

    abandon:Show()
  end

  if cancel then
    cancel:SetText(L.UI_CANCEL)

    if QuestLogSelection.busy() then
      cancel:Disable()
    else
      cancel:Enable()
    end

    cancel:Show()
  end
end

function QuestLogSelection.abandon()
  if not QuestLogSelection.canAbandon() then
    return
  end

  QuestLog.abandon(QuestLog.checkedList())
end

function QuestLogSelection.cancel(exit)
  if QuestLogSelection.busy() then
    return
  end

  QuestLog.clear()

  if exit then
    exit()
  end
end

function QuestLogSelection.bind(abandon, cancel, exit)
  if abandon then
    abandon:SetScript("OnClick", QuestLogSelection.abandon)
  end

  if cancel then
    cancel:SetScript("OnClick", function()
      QuestLogSelection.cancel(exit)
    end)
  end
end
