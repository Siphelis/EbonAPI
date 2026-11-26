EbonAPI = EbonAPI or {}
EbonAPI.MiniView = {}

local MiniView = EbonAPI.MiniView
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit

local format, min, max = string.format, math.min, math.max
local pcall, type, tostring, pairs = pcall, type, tostring, pairs
local S = Bricks.value

Bricks.CONTRACT.miniview = { "SetViewport", "GetViewport", "Canvas", "Refresh", "PixelToUnit" }

local function clamp(value, low, high)
  return min(max(value, low), high)
end

local function viewKey(name)
  return S("widgets.miniview." .. name)
end

local FUNCTIONS = {}

function FUNCTIONS:Canvas()
  return self.canvas
end

function FUNCTIONS:PixelToUnit(px, py)
  local width, height = self:GetWidth(), self:GetHeight()

  if not width or not height or width <= 0 or height <= 0 then
    return 0, 0
  end

  return clamp(px / width, 0, 1), clamp(py / height, 0, 1)
end

function FUNCTIONS:GetViewport()
  return self.vx, self.vy, self.vw, self.vh
end

function FUNCTIONS:layoutView()
  local width, height = self:GetWidth(), self:GetHeight()
  local edge = max(Bricks.insetOf(self), 1)
  local x, y, w, h = self.vx, self.vy, self.vw, self.vh

  if x + w <= 0 or x >= 1 or y + h <= 0 or y >= 1 then
    self.viewer:Hide()

    return
  end

  local left, top = clamp(x, 0, 1) * width, clamp(y, 0, 1) * height
  local right, bottom = clamp(x + w, 0, 1) * width, clamp(y + h, 0, 1) * height
  local rw, rh = max(right - left, edge), max(bottom - top, edge)
  local box = self.viewer
  local edges = self.edges

  box:ClearAllPoints()
  box:SetPoint("TOPLEFT", self, "TOPLEFT", left, -top)
  box:SetWidth(rw)
  box:SetHeight(rh)
  edges[1]:ClearAllPoints()
  edges[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  edges[1]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
  edges[1]:SetHeight(edge)
  edges[2]:ClearAllPoints()
  edges[2]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
  edges[2]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
  edges[2]:SetHeight(edge)
  edges[3]:ClearAllPoints()
  edges[3]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  edges[3]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
  edges[3]:SetWidth(edge)
  edges[4]:ClearAllPoints()
  edges[4]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
  edges[4]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
  edges[4]:SetWidth(edge)
  self.dot:SetWidth(2 * edge)
  self.dot:SetHeight(2 * edge)
  self.dot:ClearAllPoints()
  self.dot:SetPoint("CENTER", box, "CENTER", 0, 0)
  if self.showDot == false then
    self.dot:Hide()
  else
    self.dot:Show()
  end
  box:Show()
end

function FUNCTIONS:SetViewport(xn, yn, wn, hn)
  for _, value in pairs({ xn, yn, wn, hn }) do
    if type(value) ~= "number" then
      error(format("EbonAPI: miniview SetViewport expects four numbers, got %s", tostring(value)), 2)
    end
  end

  self.vx, self.vy, self.vw, self.vh = xn, yn, max(wn, 0), max(hn, 0)
  self:layoutView()
end

function FUNCTIONS:Refresh()
  local spec = self.spec or {}

  if type(spec.draw) == "function" then
    local ok, err = pcall(spec.draw, self.canvas, self)

    if not ok and EbonAPI.Lib and EbonAPI.Lib.report then
      EbonAPI.Lib.report("miniview draw", err)
    end
  end

  self:layoutView()
end

function FUNCTIONS:kitRefresh()
  self:applySize()
  self:Refresh()
end

function FUNCTIONS:applySize()
  local spec = self.spec or {}

  self:SetWidth(spec.width or viewKey("width"))
  self:SetHeight(spec.height or viewKey("height"))
end

function FUNCTIONS:panFromCursor()
  local scale = self:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  local px = clamp(cx / scale - self:GetLeft(), 0, self:GetWidth())
  local py = clamp(self:GetTop() - cy / scale, 0, self:GetHeight())

  if px == self.lastPx and py == self.lastPy then
    return
  end

  self.lastPx, self.lastPy = px, py

  local xn, yn = self:PixelToUnit(px, py)
  local spec = self.spec or {}

  if type(spec.onPan) == "function" then
    pcall(spec.onPan, xn, yn)
  end
end

function FUNCTIONS:panTo(px, py)
  local xn, yn = self:PixelToUnit(px, py)
  local spec = self.spec or {}

  if type(spec.onPan) == "function" then
    pcall(spec.onPan, xn, yn)
  end
end

local function stopDrag(self)
  self:SetScript("OnUpdate", nil)
end

function MiniView.build(parent)
  local box = CreateFrame("Frame", nil, parent)

  for name, fn in pairs(FUNCTIONS) do
    box[name] = fn
  end

  box.vx, box.vy, box.vw, box.vh = 0, 0, 1, 1
  box:SetFrameLevel(parent:GetFrameLevel() + 1)
  box:EnableMouse(true)
  box:SetWidth(viewKey("width"))
  box:SetHeight(viewKey("height"))
  Bricks.frame(box, "flat", viewKey("fill"), viewKey("border"))

  local inset = Bricks.insetOf(box)

  box.canvas = CreateFrame("Frame", nil, box)
  box.canvas:SetFrameLevel(box:GetFrameLevel() + 1)
  box.canvas:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
  box.canvas:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)

  box.viewer = CreateFrame("Frame", nil, box)
  box.viewer:SetFrameLevel(box.canvas:GetFrameLevel() + 1)
  box.view = box.viewer:CreateTexture(nil, "BACKGROUND")
  box.view:SetTexture(Bricks.media("solid"))
  box.view:SetAllPoints(box.viewer)
  Bricks.paint(box.view, "SetVertexColor", viewKey("view"))
  -- Fill alpha of the view rectangle (mockup: 0.2); absent key = opaque as before.
  local viewAlpha = viewKey("viewAlpha")
  if type(viewAlpha) == "number" then
    EbonAPI.Palette.alpha(box.view, viewAlpha)
  end
  box.edges = {}

  for index = 1, 4 do
    local edge = box.viewer:CreateTexture(nil, "BORDER")

    edge:SetTexture(Bricks.media("solid"))
    Bricks.paint(edge, "SetVertexColor", viewKey("viewBorder"))
    box.edges[index] = edge
  end

  box.dot = box.viewer:CreateTexture(nil, "OVERLAY")
  box.dot:SetTexture(Bricks.media("circle"))
  Bricks.paint(box.dot, "SetVertexColor", viewKey("dot"))
  box.showDot = viewKey("showDot") ~= false
  box.viewer:Hide()

  box:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then
      return
    end

    self.lastPx, self.lastPy = nil, nil
    self:panFromCursor()
    self:SetScript("OnUpdate", self.panFromCursor)
  end)
  box:SetScript("OnMouseUp", stopDrag)
  box:SetScript("OnHide", stopDrag)

  return box
end

Bricks.register("miniview", "default", MiniView.build)

local function checkMiniView(owner, spec, level)
  for _, name in pairs({ "width", "height" }) do
    local item = spec[name]

    if item ~= nil and type(item) ~= "number" then
      error(format("EbonAPI: %s: miniview %s expects a number, got %s", owner, name, tostring(item)), level + 1)
    end
  end

  for _, name in pairs({ "onPan", "draw" }) do
    local item = spec[name]

    if item ~= nil and type(item) ~= "function" then
      error(format("EbonAPI: %s: miniview %s expects a function, got %s", owner, name, tostring(item)), level + 1)
    end
  end
end

local function newMiniView(owner, parent, spec)
  local box = Bricks.create("miniview", parent)

  box.owner, box.spec = owner, spec
  box:applySize()
  box:Refresh()

  return box
end

Kit.addKind("miniview", newMiniView, checkMiniView)
