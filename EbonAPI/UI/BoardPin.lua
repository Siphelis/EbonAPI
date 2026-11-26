EbonAPI = EbonAPI or {}
EbonAPI.BoardPin = {}

local BoardPin = EbonAPI.BoardPin
local Pin = EbonAPI.Pin
local Dress = EbonAPI.Dress
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local Ebonhold = EbonAPI.Ebonhold

local type, ipairs, pcall, unpack, setmetatable = type, ipairs, pcall, unpack, setmetatable
local max = math.max
local sort = table.sort

local OWNER = EbonAPI.name
local LINE = { "HORIZONTAL", 1, 0.82, 0, 0.45, 1, 0.82, 0, 0 }
local SOLID = "Solid Texture"

local pin, spacer, scroll, content
local state = "waiting"
local busy = false
local hooked = {}
local refreshed = setmetatable({}, { __mode = "k" })
local maps = setmetatable({}, { __mode = "k" })

local function isType(object, kind)
  return type(object) == "table" and type(object.GetObjectType) == "function" and object:GetObjectType() == kind
end

local function placeOf(region)
  local point, relative, _, x, y = region:GetPoint(1)

  if point ~= "TOPLEFT" or relative ~= content then
    return nil
  end

  return -(y or 0), x or 0
end

local function isHeader(child)
  if child.spec and child.owner then
    return child.kind == "cardHeader"
  end

  return Dress.listHeader(child)
end

local function headers()
  local list = {}

  for _, child in ipairs({ content:GetChildren() }) do
    if child:IsShown() and isHeader(child) then
      local top, x = placeOf(child)

      if top then
        list[#list + 1] = { frame = child, key = child, top = top, x = x, width = child:GetWidth(),
          height = child:GetHeight() }
      end
    end
  end

  sort(list, function(a, b) return a.top < b.top end)

  return list
end

local function mapped(map, relative)
  return map[relative] or relative
end

local function points(region, map)
  local out = {}

  for index = 1, region:GetNumPoints() do
    local point, relative, relativePoint, x, y = region:GetPoint(index)

    out[index] = { point, mapped(map, relative), relativePoint, x, y }
  end

  return out
end

local function anchor(region, list)
  region:ClearAllPoints()

  for _, each in ipairs(list) do
    region:SetPoint(each[1], each[2], each[3], each[4], each[5])
  end
end

local function shown(region, value)
  if value then
    region:Show()
  else
    region:Hide()
  end
end

local function mirrorText(from, to)
  local font, size, flags = from:GetFont()

  if font then
    to:SetFont(font, size, flags)
  end

  to:SetText(from:GetText())
  to:SetTextColor(from:GetTextColor())
  to:SetShadowColor(from:GetShadowColor())
  to:SetShadowOffset(from:GetShadowOffset())
  to:SetJustifyH(from:GetJustifyH())
  to:SetJustifyV(from:GetJustifyV())
end

local function mirrorTexture(from, to)
  local path = from:GetTexture()

  if path == SOLID then
    to:SetTexture(1, 1, 1, 1)
    to:SetGradientAlpha(unpack(LINE))
  else
    to:SetTexture(path)
    to:SetTexCoord(from:GetTexCoord())
    to:SetVertexColor(from:GetVertexColor())
  end

  to:SetBlendMode(from:GetBlendMode())
  to:SetDesaturated(from:IsDesaturated())
end

local function lift(frame, by)
  frame:SetFrameLevel(max(0, frame:GetFrameLevel() + by))

  for _, child in ipairs({ frame:GetChildren() }) do
    lift(child, by)
  end
end

local function regionOf(copy, index, from)
  local list = copy.pinRegions
  local region = list[index]
  local kind = from:GetObjectType()
  local layer = from:GetDrawLayer()

  if region and (region:GetObjectType() ~= kind or region:GetDrawLayer() ~= layer) then
    region:Hide()
    region = nil
  end

  if not region then
    if kind == "FontString" then
      region = copy:CreateFontString(nil, layer)
    else
      region = copy:CreateTexture(nil, layer)
    end

    list[index] = region
  end

  return region
end

local function mirrorRegions(copy, real)
  local regions = { real:GetRegions() }
  local map, back = { [real] = copy }, { [copy] = real }
  local made = {}

  copy.pinRegions = copy.pinRegions or {}
  copy:SetHeight(real:GetHeight())

  for index, from in ipairs(regions) do
    local kind = from:GetObjectType()

    if kind == "FontString" or kind == "Texture" then
      local to = regionOf(copy, index, from)

      map[from], back[to] = to, from
      made[#made + 1] = { from = from, to = to, kind = kind }
    end
  end

  for index = #regions + 1, #copy.pinRegions do
    copy.pinRegions[index]:Hide()
  end

  for _, each in ipairs(made) do
    local from, to = each.from, each.to

    if each.kind == "FontString" then
      mirrorText(from, to)
    else
      mirrorTexture(from, to)
      to:SetWidth(from:GetWidth())
      to:SetHeight(from:GetHeight())
    end

    to:SetAlpha(from:GetAlpha())
    anchor(to, points(from, map))
    shown(to, from:IsShown())
  end

  maps[copy] = { map = map, back = back }
end

local function moveChildren(copy, real)
  local moved = {}

  copy.pinMoved, copy.pinReal = moved, real

  for _, child in ipairs({ real:GetChildren() }) do
    local raise = child:GetFrameLevel() - real:GetFrameLevel()
    local list = points(child, maps[copy].map)

    moved[#moved + 1] = { frame = child, raise = raise }
    child:SetParent(copy)
    lift(child, copy:GetFrameLevel() + raise - child:GetFrameLevel())
    anchor(child, list)
  end
end

local function giveBack(copy)
  local real = copy.pinReal

  if not real then
    return
  end

  local back = maps[copy] and maps[copy].back or { [copy] = real }

  for _, each in ipairs(copy.pinMoved or {}) do
    local child = each.frame

    if child:GetParent() == copy then
      local list = points(child, back)

      child:SetParent(real)
      lift(child, real:GetFrameLevel() + each.raise - child:GetFrameLevel())
      anchor(child, list)
    end
  end

  copy.pinMoved, copy.pinReal = nil, nil
end

local function watch(real)
  if real.spec and real.owner and type(real.Refresh) == "function" and not refreshed[real] then
    refreshed[real] = true
    hooksecurefunc(real, "Refresh", function(self)
      BoardPin.touched(self)
    end)
  end
end

local function mirror(copy, real)
  watch(real)
  mirrorRegions(copy, real)
  moveChildren(copy, real)
end

local function syncSpacer()
  local height = max(1, content:GetHeight() or 1)

  spacer:SetWidth(max(1, content:GetWidth() or 1))

  if spacer:GetHeight() ~= height then
    spacer:SetHeight(height)
    scroll:UpdateScrollChildRect()
  end
end

local function wheel(delta)
  local fn = scroll:GetScript("OnMouseWheel")

  if fn then
    fn(scroll, delta)
  end
end

local function build()
  pin = Pin.new(scroll, scroll, {
    offset = function() return scroll:GetVerticalScroll() end,
    headers = headers,
    width = function() return scroll:GetWidth() end,
    height = function() return content:GetHeight() end,
    viewHeight = function() return scroll:GetHeight() end,
    wheel = wheel,
    kind = function() return "mirror" end,
    -- a header of the list folds its section on a click (ProjectEbonhold's own OnClick): the copy is a
    -- button that hands the click to the header it mirrors
    copy = function(band)
      local copy = CreateFrame("Button", nil, band)

      copy:EnableMouse(true)

      copy:SetScript("OnClick", function(self)
        local real = self.pinReal

        if real and isType(real, "Button") and real:GetScript("OnClick") then
          real:Click()
        end
      end)

      return copy
    end,
    fill = function(copy, header) mirror(copy, header.frame) end,
    sync = function(copy, header) mirrorRegions(copy, header.frame) end,
    clear = function(copy) giveBack(copy) end,
  }, OWNER)
  spacer = CreateFrame("Frame", nil, scroll)
  spacer:SetWidth(1)
  spacer:SetHeight(1)
end

local function hookOnce(object, script, fn)
  hooked[object] = hooked[object] or {}

  if hooked[object][script] then
    return
  end

  hooked[object][script] = true
  object:HookScript(script, fn)
end

local function release()
  if state ~= "pinned" then
    return
  end

  local offset = scroll:GetVerticalScroll()

  pin:Clear()
  pin.clip:Hide()
  content:SetParent(scroll)
  content:ClearAllPoints()
  scroll:SetScrollChild(content)
  scroll:SetVerticalScroll(offset)
  state = "released"
end

local function take()
  local offset = scroll:GetVerticalScroll()

  if not pin then
    build()
  end

  syncSpacer()
  scroll:SetScrollChild(spacer)
  pin:Hold(content)
  pin.clip:Show()
  scroll:SetVerticalScroll(offset)
  state = "pinned"
end

local function update()
  if state == "cut" then
    return
  end

  local frame = Ebonhold.Frame("EbonholdCallboardFrame")

  if not frame then
    return
  end

  local list, child = frame.scroll, frame.content

  if not isType(list, "ScrollFrame") or not isType(child, "Frame") or (scroll and list ~= scroll)
      or (content and child ~= content) then
    if state == "pinned" then
      release()
    end

    state = "cut"
    Log.trace("pin", OWNER, "Hero's Call Board list not pinned: its pieces are not as known")
    return
  end

  scroll, content = list, child

  local held = scroll:GetScrollChild()

  if state ~= "pinned" then
    if held ~= content then
      state = "cut"
      Log.trace("pin", OWNER, "Hero's Call Board list not pinned: its scroll holds another frame")
      return
    end

    take()
    hookOnce(scroll, "OnVerticalScroll", function()
      if state == "pinned" then
        BoardPin.refresh()
      end
    end)
    hookOnce(content, "OnSizeChanged", function()
      if state == "pinned" then
        BoardPin.refresh()
      end
    end)
  elseif held ~= spacer then
    release()
    state = "cut"
    Log.trace("pin", OWNER, "Hero's Call Board list not pinned: its scroll holds another frame")
    return
  end

  syncSpacer()
  pin:Update()
end

local function guarded(fn)
  if busy then
    return
  end

  busy = true

  local ok, err = pcall(fn)

  busy = false

  if not ok then
    Lib.report(err, OWNER)

    if state == "pinned" then
      local given, problem = pcall(release)

      if not given then
        Lib.report(problem, OWNER)
      end
    end

    state = "cut"
    Log.trace("pin", OWNER, "Hero's Call Board list not pinned: an error, given to the error display")
  end
end

function BoardPin.refresh()
  guarded(update)
end

function BoardPin.redraw()
  guarded(function()
    if pin then
      pin:Invalidate()
    end

    update()
  end)
end

function BoardPin.touched(frame)
  if state ~= "pinned" or not pin then
    return
  end

  guarded(function()
    pin:Touched(frame)
  end)
end

function BoardPin.holds(frame)
  return state == "pinned" and frame ~= nil and frame == content
end

function BoardPin.state()
  return state, pin and pin:State() or nil
end

function BoardPin.pinned(index)
  if not pin then
    return nil
  end

  return pin:Pinned(index)
end

function BoardPin.parts()
  if not pin then
    return nil
  end

  return { clip = pin.clip, band = pin.band, child = pin.child, sheet = pin.sheet, spacer = spacer }
end

EbonAPI:On("CALLBOARD_UI_REFRESHED", function()
  Bus.after("EbonAPI:pin", 0.01, BoardPin.redraw)
end)
