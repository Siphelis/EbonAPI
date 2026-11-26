EbonAPI = EbonAPI or {}
EbonAPI.Windows = {}

local Windows = EbonAPI.Windows
local Bricks = EbonAPI.Bricks
local Skins = EbonAPI.Skins
local DB = EbonAPI.DB
local Catalog = EbonAPI.Catalog

local type, ipairs, pairs, abs, select = type, ipairs, pairs, math.abs, select

local S = Skins.value

local containers = {}
local list = {}
local store = nil

local function positions()
  if not DB.isAttached() then
    return nil
  end

  if not store then
    store = DB.store("EbonAPI", { account = { windows = {} } })
  end

  if type(store.account.windows) ~= "table" then
    store.account.windows = {}
  end

  return store.account.windows
end

local function save(frame)
  local saved = positions()

  if not saved then
    return
  end

  local point, _, relativePoint, x, y = frame:GetPoint(1)

  saved[frame.id] = { point = point, relativePoint = relativePoint, x = x, y = y }
end

Windows.save = save

local function nearest(best, candidate, distance)
  if abs(candidate) <= distance and (best == nil or abs(candidate) < abs(best)) then
    return candidate
  end

  return best
end

function Windows.snap(frame)
  local distance = S("windows.snap")
  local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()

  if distance <= 0 or not (left and right and top and bottom) then
    return false
  end

  local gap = S("windows.gap")
  local dx, dy = nil, nil

  for _, other in ipairs(list) do
    if other ~= frame and other:IsShown() then
      local oLeft, oRight, oTop, oBottom = other:GetLeft(), other:GetRight(), other:GetTop(), other:GetBottom()

      if oLeft and oRight and oTop and oBottom then
        local sideBySide = bottom < oTop + distance and top > oBottom - distance
        local stacked = left < oRight + distance and right > oLeft - distance

        if sideBySide then
          dx = nearest(dx, oRight + gap - left, distance)
          dx = nearest(dx, oLeft - gap - right, distance)
          dy = nearest(dy, oTop - top, distance)
          dy = nearest(dy, oBottom - bottom, distance)
        end

        if stacked then
          dy = nearest(dy, oBottom - gap - top, distance)
          dy = nearest(dy, oTop + gap - bottom, distance)
          dx = nearest(dx, oLeft - left, distance)
          dx = nearest(dx, oRight - right, distance)
        end
      end
    end
  end

  if dx == nil and dy == nil then
    return false
  end

  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + (dx or 0), top + (dy or 0))

  return true
end

local function anyShown(group)
  for _, frame in ipairs(list) do
    if frame.group == group and frame:IsShown() then
      return true
    end
  end

  return false
end

Windows.anyShown = anyShown

local function moved(self)
  Windows.snap(self)
  save(self)

  if self.afterMoved then
    self.afterMoved(self)
  end
end

local pending = {}
local waiter = nil

local function later(run)
  pending[#pending + 1] = run

  if not waiter then
    waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    waiter:SetScript("OnEvent", function()
      local queue = pending

      pending = {}

      for _, job in ipairs(queue) do
        job()
      end
    end)
  end
end

local function locked()
  return InCombatLockdown and InCombatLockdown()
end

local layers = {}

function Windows.layer(key, roots)
  if type(roots) == "function" then
    layers[key] = roots
  end
end

local function protectedNow(frame)
  return locked() and frame.IsProtected and frame:IsProtected()
end

local function raise(frame)
  if frame and frame.Raise and frame:IsShown() then
    if protectedNow(frame) then
      if not frame.raiseOwed then
        frame.raiseOwed = true
        later(function()
          frame.raiseOwed = nil
          raise(frame)
        end)
      end

      return
    end

    frame:Raise()
  end
end

local function layerOf(frame)
  while frame do
    for key, roots in pairs(layers) do
      for _, root in ipairs(roots()) do
        if root == frame then
          return key
        end
      end
    end

    frame = frame.GetParent and frame:GetParent() or nil
  end

  return nil
end

local pile = {}
local propagates = nil

local function container(frame)
  while frame do
    if frame.frontOnShow then
      return frame
    end

    frame = frame.GetParent and frame:GetParent() or nil
  end

  return nil
end

local function managed(frame)
  return frame:GetParent() == UIParent and not frame.kitAttach
end

local function visit(old, new, ...)
  for i = 1, select("#", ...) do
    local child = select(i, ...)

    if child:GetFrameStrata() == old then
      child:SetFrameStrata(new)
    end

    visit(old, new, child:GetChildren())
  end
end

local function sameStrata(old, ...)
  for i = 1, select("#", ...) do
    local child = select(i, ...)

    if child:GetFrameStrata() == old then
      return child
    end
  end

  return nil
end

local function place(root, strata)
  local old = root:GetFrameStrata()

  if old == strata then
    return false
  end

  if protectedNow(root) then
    return true
  end

  local probe = nil

  if propagates == nil then
    probe = sameStrata(old, root:GetChildren())
  end

  root:SetFrameStrata(strata)

  if probe then
    propagates = probe:GetFrameStrata() == strata
  end

  if propagates == false then
    visit(old, strata, root:GetChildren())
  end

  return false
end

local settle
local owedSettle = false

settle = function()
  local top = nil

  for index = #pile, 1, -1 do
    if managed(pile[index]) then
      top = pile[index]
      break
    end
  end

  if not top then
    return
  end

  local high = S("window.strata")
  local low = high

  for index, name in ipairs(Catalog.strataOrder) do
    if name == high and index > 1 then
      low = Catalog.strataOrder[index - 1]
    end
  end

  local deferred = false

  for _, window in ipairs(pile) do
    if managed(window) and place(window, window == top and high or low) then
      deferred = true
    end
  end

  if deferred and not owedSettle then
    owedSettle = true
    later(function()
      owedSettle = false
      settle()
    end)
  end
end

local function stack(window)
  if pile[#pile] == window then
    return
  end

  for index, candidate in ipairs(pile) do
    if candidate == window then
      table.remove(pile, index)
      break
    end
  end

  pile[#pile + 1] = window
  settle()
end

local function unstack(window)
  for index, candidate in ipairs(pile) do
    if candidate == window then
      table.remove(pile, index)
      settle()
      return
    end
  end
end

function Windows.front(target)
  local key = layers[target] and target or (type(target) == "table" and layerOf(target)) or nil

  if key then
    for _, root in ipairs(layers[key]()) do
      raise(root)
    end
  elseif type(target) == "table" then
    local window = container(target)

    if window then
      stack(window)
    end

    raise(target)
  end
end

Bricks.front = Windows.front
Bricks.opened = Windows.front

function Windows.create(id, name, group)
  local frame = containers[id]

  if frame then
    return frame
  end

  frame = Bricks.Container(name)
  frame.id = id
  frame.group = group
  frame.onMoved = moved

  if name and type(UISpecialFrames) == "table" then
    UISpecialFrames[#UISpecialFrames + 1] = name
  end

  frame:HookScript("OnHide", function(self)
    unstack(self)
    Bricks.closeMenu()

    if not group and not anyShown() then
      Bricks.sound("window.sound.close")
    end
  end)

  containers[id] = frame
  list[#list + 1] = frame

  return frame
end

local function unlist(frame)
  for index, candidate in ipairs(list) do
    if candidate == frame then
      table.remove(list, index)
      return true
    end
  end

  return false
end

local function restore(frame, origin)
  frame:ClearAllPoints()

  for _, p in ipairs(origin) do
    frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
end

local function placeNow(frame, initial)
  local saved = positions()
  local position = saved and saved[frame.id]

  frame:ClearAllPoints()

  if type(position) == "table" and position.point then
    frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
  elseif initial then
    initial(frame)
  elseif frame.adoptOrigin and #frame.adoptOrigin.points > 0 then
    restore(frame, frame.adoptOrigin.points)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

function Windows.place(frame, initial)
  frame.placeInitial = initial

  if (frame.adoptOrigin or frame.adoptPending) and locked() then
    later(function()
      placeNow(frame, initial)
    end)

    return
  end

  placeNow(frame, initial)
end

local tick = 0
local follow

local function adoptNow(id, frame, group)
  follow()

  if frame.adoptOrigin and containers[id] == frame then
    frame.group = group
    return
  end

  local origin = { points = {}, movable = frame:IsMovable() and true or false }

  for i = 1, frame:GetNumPoints() do
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
    origin.points[i] = { point, relativeTo, relativePoint, x, y }
  end

  origin.dragStart = frame:GetScript("OnDragStart")
  origin.dragStop = frame:GetScript("OnDragStop")
  origin.parent = frame:GetParent()

  local other = containers[id]

  if other and other ~= frame then
    unlist(other)
  end

  frame.adoptOrigin = origin
  frame.adoptPending = nil
  frame.id = id
  frame.group = group
  frame.onMoved = moved
  Bricks.drag(frame)

  containers[id] = frame

  for _, candidate in ipairs(list) do
    if candidate == frame then
      return
    end
  end

  list[#list + 1] = frame
end

function Windows.adopt(id, frame, group)
  frame.adoptTick = tick

  if frame.adoptOrigin and containers[id] == frame then
    frame.group = group
    return frame
  end

  if locked() then
    frame.adoptPending = true
    later(function()
      adoptNow(id, frame, group)
    end)

    return frame
  end

  adoptNow(id, frame, group)

  return frame
end

local function releaseNow(frame)
  local origin = frame.adoptOrigin

  if not origin then
    frame.adoptPending = nil
    return
  end

  if containers[frame.id] == frame then
    containers[frame.id] = nil
  end

  unlist(frame)
  restore(frame, origin.points)
  frame:SetMovable(origin.movable)
  frame:SetScript("OnDragStart", origin.dragStart)
  frame:SetScript("OnDragStop", origin.dragStop)

  if not origin.dragStart and not origin.dragStop then
    frame:RegisterForDrag()
  end

  frame.adoptOrigin = nil
  frame.adoptPending = nil
  frame.id = nil
  frame.group = nil
  frame.onMoved = nil
end

function Windows.release(frame)
  if not (frame.adoptOrigin or frame.adoptPending) then
    return
  end

  if locked() then
    later(function()
      releaseNow(frame)
    end)

    return
  end

  releaseNow(frame)
end

function Windows.apply(id, frame, group, enabled, initial)
  if enabled then
    Windows.adopt(id, frame, group)
    Windows.place(frame, initial)
  else
    Windows.release(frame)
  end

  return frame
end

function Windows.reset()
  local saved = positions()

  if saved then
    for key in pairs(saved) do
      saved[key] = nil
    end
  end

  local frames = {}

  for _, frame in ipairs(list) do
    if not frame.kitAttach then
      frames[#frames + 1] = frame
    end
  end

  for pass = 1, 2 do
    for _, frame in ipairs(frames) do
      if (frame.placeInitial ~= nil) == (pass == 2) then
        Windows.place(frame, frame.placeInitial)
      end
    end
  end
end

function Windows.get(id)
  return containers[id]
end

function Windows.all()
  return list
end

function Windows.hideAll(group)
  for _, frame in ipairs(list) do
    if frame.group == group then
      frame:Hide()
    end
  end
end

local followers = {}
local seen = nil
local owed = false

function Windows.onSkin(run)
  if type(run) == "function" then
    followers[#followers + 1] = run
  end
end

local function adopted(stale)
  local found, known = {}, {}

  for _, group in ipairs({ list, containers }) do
    for _, frame in pairs(group) do
      if (frame.adoptOrigin or frame.adoptPending) and not known[frame] and (not stale or frame.adoptTick ~= tick) then
        known[frame] = true
        found[#found + 1] = frame
      end
    end
  end

  return found
end

function Windows.releaseAll()
  for _, frame in ipairs(adopted(false)) do
    Windows.release(frame)
  end
end

local function changed(name, before)
  settle()

  for _, frame in ipairs(adopted(true)) do
    Windows.release(frame)
  end

  for _, run in ipairs(followers) do
    local ok, err = pcall(run, name, before)

    if not ok and EbonAPI.Lib and EbonAPI.Lib.report then
      EbonAPI.Lib.report(err, "EbonAPI")
    end
  end
end

local function skinFollowed()
  local name = Skins.active()

  if name == seen then
    return
  end

  local before = seen

  seen = name

  if before == nil then
    return
  end

  if locked() then
    if not owed then
      owed = true
      later(function()
        owed = false
        changed(Skins.active(), before)
      end)
    end

    return
  end

  changed(name, before)
end

follow = function()
  if Windows.following then
    return
  end

  Windows.following = true
  seen = Skins.active()

  local resolve = Skins.resolve

  Skins.resolve = function(...)
    tick = tick + 1

    local result = resolve(...)

    skinFollowed()

    return result
  end
end
