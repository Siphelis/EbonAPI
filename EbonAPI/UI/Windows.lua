EbonAPI = EbonAPI or {}
EbonAPI.Windows = {}

local Windows = EbonAPI.Windows
local Bricks = EbonAPI.Bricks
local Skins = EbonAPI.Skins
local DB = EbonAPI.DB

local type, ipairs, abs = type, ipairs, math.abs

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

function Windows.create(id, name, group)
  local frame = containers[id]

  if frame then
    return frame
  end

  frame = Bricks.Container(name)
  frame.id = id
  frame.group = group
  frame.onMoved = function(self)
    Windows.snap(self)
    save(self)
  end

  if name and type(UISpecialFrames) == "table" then
    UISpecialFrames[#UISpecialFrames + 1] = name
  end

  frame:HookScript("OnHide", function()
    Bricks.closeMenu()

    if not group and not anyShown() then
      Bricks.sound("window.sound.close")
    end
  end)

  containers[id] = frame
  list[#list + 1] = frame

  return frame
end

function Windows.place(frame, initial)
  local saved = positions()
  local position = saved and saved[frame.id]

  frame:ClearAllPoints()

  if type(position) == "table" and position.point then
    frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
  elseif initial then
    initial(frame)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
