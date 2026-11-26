EbonAPI = EbonAPI or {}
EbonAPI.Tiles = EbonAPI.Tiles or {}


local Tiles = EbonAPI.Tiles
local Bricks = EbonAPI.Bricks

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local ipairs = ipairs
local S = Bricks.value
local PAD = 4
local SPACE = 3

Bricks.CONTRACT.synthesis = { "SetGroups", "SetWidth", "Refresh" }

local function borderKey(widget, tile)
  local level = tile.item.level

  if widget.activeId ~= nil and tile.item.id == widget.activeId then
    return S("widgets.synthesis.selected")
  elseif level == "warn" then
    return "caution"
  elseif level == "bad" then
    return "danger"
  end

  return S("widgets.synthesis.border")
end

local function lineHeight(fs, role)
  local size = ceil(S("fonts." .. role .. ".size"))

  return max(size, min(ceil(fs:GetStringHeight() or 0), size * 2))
end

local function wire(box, tile)
  local frame = tile.frame

  frame:SetScript("OnClick", function()
    if type(box.onSelect) == "function" and tile.item then
      box.onSelect(tile.item)
    end
  end)
  frame:SetScript("OnEnter", function(self)
    Bricks.enterTip(self)
  end)
  frame:SetScript("OnLeave", function()
    Bricks.hideTip()
  end)
end

local function newTile(box)
  local frame = CreateFrame("Button", nil, box)
  local labelRole = S("widgets.synthesis.label.font")
  local valueRole = S("widgets.synthesis.value.font")
  local tile = { frame = frame }

  wire(box, tile)

  tile.marker = frame:CreateTexture(nil, "OVERLAY")
  tile.label = Bricks.text(frame, labelRole, "muted")
  tile.value = Bricks.text(frame, valueRole, "text")
  tile.sub = Bricks.text(frame, labelRole, "muted")

  for _, fs in ipairs({ tile.label, tile.value, tile.sub }) do
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
  end

  if tile.sub.SetWordWrap then
    tile.sub:SetWordWrap(true)
  end

  for _, fs in ipairs({ tile.label, tile.value }) do
    if fs.SetWordWrap then
      fs:SetWordWrap(false)
    end
  end

  return tile
end

local function setTip(tile)
  local item = tile.item
  local frame = tile.frame
  local body = item.value or ""

  if item.sub and item.sub ~= "" then
    body = body .. " · " .. item.sub
  end

  if item.tip and item.tip ~= "" then
    body = item.tip
  end

  frame.tipTitle = item.label
  frame.tipBody = body
end

local MARKERS = {
  ok = { texture = "Interface\Buttons\UI-CheckBox-Check", color = "success", scale = 1 },
  warn = { media = "warning", color = "caution", scale = 1 },
  bad = { media = "error", color = "danger", scale = 1 },
  info = { media = "circle", color = "muted", scale = 0.5 },
  net = { media = "arrow", color = "focus", scale = 1 },
}

local function paintMarker(tile, size)
  local spec = MARKERS[tile.item.level]
  local marker = tile.marker

  if not spec then
    marker:Hide()
    marker.level = nil

    return
  end

  local side = max(2, floor(size * spec.scale + 0.5))
  local pad = floor((size - side) / 2)

  marker:SetTexture(spec.texture or Bricks.media(spec.media))
  Bricks.paint(marker, "SetVertexColor", spec.color)
  marker:SetWidth(side)
  marker:SetHeight(side)
  marker:ClearAllPoints()
  marker:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", PAD + pad, -(PAD + pad))
  marker:Show()
  marker.level = tile.item.level
end

local function paintTile(widget, tile, width, height)
  local item = tile.item
  local frame = tile.frame
  local labelRole = S("widgets.synthesis.label.font")
  local valueRole = S("widgets.synthesis.value.font")
  local key = borderKey(widget, tile)

  Bricks.frame(frame, "small", S("widgets.synthesis.fill"), key)
  tile.border = key
  frame:SetWidth(width)
  frame:SetHeight(height)

  Bricks.font(tile.label, labelRole)
  Bricks.font(tile.value, valueRole)
  Bricks.font(tile.sub, labelRole)
  Bricks.paint(tile.label, "SetTextColor", "muted")
  Bricks.paint(tile.value, "SetTextColor", "text")
  Bricks.paint(tile.sub, "SetTextColor", "muted")
  tile.label:SetText(item.label or "")
  tile.value:SetText(item.value or "")
  tile.sub:SetText(item.sub or "")
  setTip(tile)

  local inset = Bricks.insetOf(frame) + PAD
  local inner = max(1, width - inset * 2)
  local first = lineHeight(tile.label, labelRole)
  local second = lineHeight(tile.value, valueRole)
  local small = lineHeight(tile.sub, labelRole)

  paintMarker(tile, first)
  tile.markerSize = first

  tile.label:ClearAllPoints()
  tile.label:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + first + SPACE, -inset)
  tile.label:SetWidth(max(1, inner - first - SPACE))
  tile.label:SetHeight(first)
  tile.value:ClearAllPoints()
  tile.value:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(inset + first + SPACE))
  tile.value:SetWidth(inner)
  tile.value:SetHeight(second)

  local top = inset + first + SPACE + second + SPACE

  tile.sub:ClearAllPoints()
  tile.sub:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -top)
  tile.sub:SetWidth(inner)
  tile.sub:SetHeight(max(small, min(small * 2, height - top - inset)))
end

local function tileHeight(box)
  local want = S("widgets.synthesis.tile.height")
  local first = box.tilePool[1]

  if not first then
    return want
  end

  local labelRole = S("widgets.synthesis.label.font")
  local valueRole = S("widgets.synthesis.value.font")

  Bricks.frame(first.frame, "small", S("widgets.synthesis.fill"), S("widgets.synthesis.border"))

  local inset = Bricks.insetOf(first.frame) + PAD
  local small = ceil(S("fonts." .. labelRole .. ".size"))
  local need = inset * 2 + small + ceil(S("fonts." .. valueRole .. ".size")) + small * 2 + SPACE * 2

  return max(want, need)
end

local function layoutGrid(box)
  local width = max(1, box.boxWidth)
  local gap = S("widgets.synthesis.gap")
  local tw = S("widgets.synthesis.tile.width")
  local th = box.look.height(box)
  local cols = max(1, floor((width + gap) / (tw + gap)))
  local size = (width - (cols - 1) * gap) / cols
  local role = S("widgets.synthesis.label.font")
  local y = 0
  local count = 0

  for index, group in ipairs(box.groups or {}) do
    local label = box.labelPool[index]

    Bricks.font(label, role)
    Bricks.paint(label, "SetTextColor", S("widgets.synthesis.group.color"))
    label:SetText(group.label or "")
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
    label:SetWidth(width)

    local lh = lineHeight(label, role)

    label:SetHeight(lh)
    label:Show()
    y = y + lh + gap

    for position, tile in ipairs(group.tiles) do
      local col = (position - 1) % cols
      local row = floor((position - 1) / cols)

      box.look.paint(box, tile, size, th)
      tile.frame:ClearAllPoints()
      tile.frame:SetPoint("TOPLEFT", box, "TOPLEFT", col * (size + gap), -(y + row * (th + gap)))
      tile.frame:Show()
      count = count + 1
    end

    local rows = ceil(#group.tiles / cols)

    y = y + rows * th + max(0, rows - 1) * gap

    if index < #box.groups then
      y = y + gap
    end
  end

  box:SetHeight(max(1, y))
  box.contentHeight = y

  return y
end

local function layoutColumns(box)
  local width = max(1, box.boxWidth)
  local gap = box.gap or S("widgets.synthesis.gap")
  local th = box.fixedHeight or box.look.height(box)
  local cols = max(1, floor(box.columns))
  local size = (width - (cols - 1) * gap) / cols
  local y = 0

  for index in ipairs(box.labelPool) do
    box.labelPool[index]:Hide()
  end

  for index, group in ipairs(box.groups or {}) do
    for position, tile in ipairs(group.tiles) do
      local col = (position - 1) % cols
      local row = floor((position - 1) / cols)

      box.look.paint(box, tile, size, th)
      tile.frame:ClearAllPoints()
      tile.frame:SetPoint("TOPLEFT", box, "TOPLEFT", col * (size + gap), -(y + row * (th + gap)))
      tile.frame:Show()

      if box.arrange then
        box.arrange(box, tile, size, th)
      end
    end

    local rows = ceil(#group.tiles / cols)

    y = y + rows * th + max(0, rows - 1) * gap

    if index < #box.groups then
      y = y + gap
    end
  end

  box:SetHeight(max(1, y))
  box.contentHeight = y

  return y
end

local function updateTile(box, tile, old)
  local item = tile.item
  local text = item.label ~= old.label or item.value ~= old.value or item.sub ~= old.sub
  local level = item.level ~= old.level

  if text then
    tile.label:SetText(item.label or "")
    tile.value:SetText(item.value or "")
    tile.sub:SetText(item.sub or "")
    setTip(tile)
  end

  if level then
    paintMarker(tile, tile.markerSize or 1)
  end

  local key = borderKey(box, tile)

  if key ~= tile.border then
    Bricks.frame(tile.frame, "small", S("widgets.synthesis.fill"), key)
    tile.border = key
  end
end

local look = { new = newTile, paint = paintTile, update = updateTile, height = tileHeight }

function Tiles.wrap(fs, on)
  if fs and fs.SetWordWrap then
    fs:SetWordWrap(on)
  end
end

Tiles.looks = { default = look }
Tiles.wire = wire
Tiles.borderKey = borderKey
Tiles.setTip = setTip
Tiles.lineHeight = lineHeight
Tiles.PAD, Tiles.SPACE = PAD, SPACE
Tiles.paintMarker = paintMarker
Tiles.layoutGrid = layoutGrid
Tiles.layoutColumns = layoutColumns

local function buildLooked(parent, chosen)
  local box = CreateFrame("Frame", nil, parent)

  if chosen == nil or chosen == look then
    box.look = look
  else
    box.look = {}

    for _, name in ipairs({ "new", "paint", "update", "height", "layout", "card" }) do
      box.look[name] = chosen[name] or look[name]
    end
  end

  local function layout(self)
    if self.columns then
      return layoutColumns(self)
    end

    if self.look.layout then
      return self.look.layout(self)
    end

    return layoutGrid(self)
  end

  box.tiles = {}
  box.labels = {}
  box.groups = {}
  box.tilePool = {}
  box.labelPool = {}
  box.boxWidth = 1
  box.activeId = nil
  box.onSelect = nil
  box.source = nil
  box.onRebuild = nil

  function box:SetGroups(groups, activeId)
    local used, label = 0, 0

    self.activeId = activeId
    self.groups = {}
    self.tiles = {}
    self.labels = {}

    for _, group in ipairs(groups or {}) do
      local entry = { id = group.id, label = group.label, tiles = {} }

      label = label + 1
      self.labelPool[label] = self.labelPool[label] or Bricks.text(self, S("widgets.synthesis.label.font"),
        S("widgets.synthesis.group.color"))
      self.labels[label] = self.labelPool[label]
      self.labels[label].groupId = group.id

      for _, item in ipairs(group.items or {}) do
        used = used + 1
        self.tilePool[used] = self.tilePool[used] or self.look.new(self)

        local tile = self.tilePool[used]

        tile.item, tile.group = item, group.id
        entry.tiles[#entry.tiles + 1] = tile
        self.tiles[#self.tiles + 1] = tile
      end

      self.groups[#self.groups + 1] = entry
    end

    if activeId ~= nil then
      local found = false

      for _, tile in ipairs(self.tiles) do
        if tile.item.id == activeId then
          found = true
        end
      end

      if not found then
        self.activeId = nil
      end
    end

    for index = used + 1, #self.tilePool do
      self.tilePool[index].frame:Hide()
    end

    for index = label + 1, #self.labelPool do
      self.labelPool[index]:Hide()
    end

    return layout(self)
  end

  function box:Refresh()
    return layout(self)
  end

  local function sameShape(self, groups)
    if #groups ~= #self.groups then
      return false
    end

    for index, group in ipairs(groups) do
      local shown = self.groups[index]
      local items = group.items or {}

      if shown.id ~= group.id or #shown.tiles ~= #items then
        return false
      end

      for position, item in ipairs(items) do
        if shown.tiles[position].item.id ~= item.id then
          return false
        end
      end
    end

    return true
  end

  function box:Tick()
    local groups = self.source and self.source()

    if type(groups) ~= "table" then
      return false
    end

    if not sameShape(self, groups) then
      if self.onRebuild then
        self.onRebuild(groups)
      else
        self:SetGroups(groups, self.activeId)
      end

      return true
    end

    for index, group in ipairs(groups) do
      for position, item in ipairs(group.items or {}) do
        local tile = self.groups[index].tiles[position]
        local old = tile.item

        tile.item = item
        self.look.update(self, tile, old)
      end
    end

    return false
  end

  local elapsed = 0

  box:SetScript("OnUpdate", function(self, delta)
    if not self:IsShown() or (self.IsVisible and not self:IsVisible()) then
      return
    end

    elapsed = elapsed + (delta or 0)

    if elapsed >= S("footer.refresh") then
      elapsed = 0
      self:Tick()
    end
  end)

  local setWidth = box.SetWidth

  function box:SetWidth(width)
    self.boxWidth = width
    setWidth(self, width)

    return layout(self)
  end

  return box
end

Bricks.register("synthesis", "default", function(parent)
  return Tiles.build(parent, Tiles.looks.default)
end)

function Tiles.build(parent, arg)
  return buildLooked(parent, arg)
end

return Tiles
