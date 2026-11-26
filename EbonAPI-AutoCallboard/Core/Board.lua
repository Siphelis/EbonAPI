local Core = AutoCallboardCore or {}
AutoCallboardCore = Core

local ipairs, type = ipairs, type
local table = table


local STATE_ORDER = { [2] = 1, [1] = 2, [0] = 3, [3] = 4 }

local function contractOrder(a, b)
  local ca, cb = Core.categoryRank(a.category), Core.categoryRank(b.category)

  if ca ~= cb then
    return ca < cb
  end

  local sa, sb = STATE_ORDER[a.state] or 9, STATE_ORDER[b.state] or 9

  if sa ~= sb then
    return sa < sb
  end

  local ta, tb = a.title or "", b.title or ""

  if ta ~= tb then
    return ta < tb
  end

  return a.questId < b.questId
end

local HEADER = {
  "receivedAt", "dailyResetIn", "weeklyResetIn", "highestIlvl", "equippedIlvl", "cacheProgress",
  "cachesOpened", "claimable",
}

function Core.boardView(board)
  if type(board) ~= "table" or type(board.quests) ~= "table" then
    return nil
  end

  local view = { cacheRequired = board.cacheRequired or 1, quests = {}, accepted = {}, ready = {} }

  for _, field in ipairs(HEADER) do
    view[field] = board[field] or 0
  end

  local quests = view.quests

  for i = 1, #(board.quests) do
    quests[i] = board.quests[i]
  end

  table.sort(quests, contractOrder)

  local byId = board.byId

  if type(byId) ~= "table" then
    byId = {}

    for i = 1, #(quests) do
      byId[quests[i].questId] = byId[quests[i].questId] or quests[i]
    end
  end

  view.byId = byId

  for i = 1, #(quests) do
    if quests[i].state == Core.STATE.ACCEPTED then
      view.accepted[#(view.accepted) + 1] = quests[i]
    elseif quests[i].state == Core.STATE.COMPLETE then
      view.ready[#(view.ready) + 1] = quests[i]
    end
  end

  return view
end

function Core.boardResetIn(board, now)
  if type(board) ~= "table" then
    return nil
  end

  local elapsed = (now or board.receivedAt) - board.receivedAt
  local nearest

  for _, seconds in ipairs({ board.dailyResetIn, board.weeklyResetIn }) do
    if seconds > 0 and (not nearest or seconds < nearest) then
      nearest = seconds
    end
  end

  if not nearest then
    return nil
  end

  if nearest - elapsed < 0 then
    return 0
  end

  return nearest - elapsed
end
