local DOTS = {
  { color = 0xFF5F57, glyph = "×", ink = 0x4D0000 },
  { color = 0xFEBC2E, glyph = "-", ink = 0x995700 },
  { color = 0x28C840, glyph = "+", ink = 0x006500 },
}

local function rgb(value)
  return math.floor(value / 65536) / 255, math.floor(value / 256) % 256 / 255, value % 256 / 255
end

local function dot(button, B, spec)
  local disk = button:CreateTexture(nil, "ARTWORK")

  disk:SetTexture(B.media("circle"))
  disk:SetPoint("LEFT", button, "LEFT", 0, 0)
  disk:SetVertexColor(rgb(spec.color))
  button.disk = disk
  B.font(button.label, "button", "")
  button.label:ClearAllPoints()
  button.label:SetPoint("CENTER", disk, "CENTER", 0, 0)
  button.label:SetTextColor(rgb(spec.ink))
end

local function lights(parent, B)
  local close = B.baseButton(parent, function(self)
    local over = self.hovered or self.others[1].hovered or self.others[2].hovered

    self.label:SetAlpha(over and 1 or 0)

    for _, other in ipairs(self.others) do
      other.label:SetAlpha(over and 1 or 0)
    end
  end)

  close.others = {}
  dot(close, B, DOTS[1])

  for index = 2, 3 do
    local other = CreateFrame("Button", nil, close)

    other.label = other:CreateFontString(nil, "OVERLAY")
    dot(other, B, DOTS[index])
    other.label:SetText(DOTS[index].glyph)
    other:SetScript("OnEnter", function(self)
      self.hovered = true
      close:Visual()
    end)
    other:SetScript("OnLeave", function(self)
      self.hovered = false
      close:Visual()
    end)
    close.others[index - 1] = other
  end

  close.others[1]:SetScript("OnClick", function()
    if close.onShade then
      close.onShade(close)
    end
  end)

  local setWidth, setHeight = close.SetWidth, close.SetHeight

  local function layout(self)
    local size = self:GetHeight()
    local gap = math.max(0, (self:GetWidth() - size * 3) / 2)

    self.disk:SetWidth(size)
    self.disk:SetHeight(size)

    for index, other in ipairs(self.others) do
      other:SetWidth(size)
      other:SetHeight(size)
      other.disk:SetWidth(size)
      other.disk:SetHeight(size)
      other:ClearAllPoints()
      other:SetPoint("LEFT", self, "LEFT", index * (size + gap), 0)
    end

    self:SetHitRectInsets(0, math.max(0, self:GetWidth() - size), 0, 0)
  end

  function close:SetWidth(width)
    setWidth(self, width)
    layout(self)
  end

  function close:SetHeight(size)
    setHeight(self, size)
    layout(self)
  end

  function close:TextWidth()
    return self:GetWidth()
  end

  close:Visual()

  return close
end

EbonAPI:RegisterSkin("Porcelain", {
  parent = "AutoCallboard",

  background = 0xF6F6F6,
  accent = 0x007AFF,
  opacity = 0.94,
  shadow = 0.6,
  corners = 8,
  tabs = "LEFT",

  palette = {
    bg = 0xF6F6F6,
    bgSoft = 0xFFFFFF,
    card = 0xFFFFFF,
    border = 0xC4C4C4,
    borderDim = 0xDADADA,
    button = 0xFFFFFF,
    buttonBorder = 0xC6C6C6,
    buttonHover = 0x007AFF,
    buttonHoverFill = 0xF2F2F2,
    buttonDisabledBorder = { 0xC6C6C6, 0.5 },
    buttonText = 0x1D1D1F,
    buttonDisabledText = { 0x1D1D1F, 0.4 },
    checkbox = 0xFFFFFF,
    checkboxBorder = 0xB8B8BD,
    checked = 0x007AFF,
    thumb = 0x8E8E93,
    selected = 0x007AFF,
    selectedText = 0xFFFFFF,
    text = 0x1D1D1F,
    muted = 0x6E6E73,
    title = 0x1D1D1F,
    heading = 0x1D1D1F,
    menu = 0x007AFF,
    shadow = 0x000000,
    focus = 0x007AFF,
    rowHover = { 0x000000, 0.06 },
    headerBg = { 0xEBEBEB, 0.92 },
    navBg = { 0xE3E3E8, 0.85 },
    pageBg = { 0xF2F2F7, 0.9 },
    footerBg = { 0xEBEBEB, 0 },
    success = 0x137333,
  },

  fonts = {
    small = { file = "Fonts\\ARIALN.TTF", size = 11 },
    normal = { file = "Fonts\\ARIALN.TTF", size = 12 },
    large = { file = "Fonts\\ARIALN.TTF", size = 17 },
    button = { file = "Fonts\\ARIALN.TTF", size = 12, outline = "NONE" },
    shadow = { alpha = 0 },
  },

  window = {
    padding = 0,
    spacing = 0,
    shadow = { base = 10, spread = 20, alphaBase = 0.12, alphaSpread = 0.3, y = -8 },
    glass = {
      enabled = true, tint = 0xFFFFFF, darken = 0, milk = 0.18, grain = 0.02,
      sheen = 0.12, sheenHeight = 0.25, edge = 0.35,
    },
    fade = 0.12,
  },

  header = {
    height = 38,
    controls = "LEFT",
    inset = 14,
    title = { align = "CENTER", y = 13, font = "normal", color = "title" },
    version = { show = false },
    search = { position = "OPPOSITE", width = 170, height = 22, inset = 8 },
    close = { brick = "lights", size = 12, width = 52, y = 13, glyph = "×" },
  },

  nav = {
    width = 190,
    inset = 4,
    padding = 10,
    divider = { size = 1, color = "borderDim" },
    section = { x = 6, height = 20, before = 10, after = 2, color = "muted" },
    tab = { brick = "list", height = 24, gap = 2, indent = 12, align = "LEFT", font = "normal", padding = 10 },
  },

  page = {
    width = 620,
    height = 520,
    gutter = 10,
    top = 44,
    inset = { x = 24, y = 18 },
    title = { color = "title" },
    gap = { x = 16, y = 14 },
  },

  widgets = {
    button = { height = 22, padding = 12 },
    toggle = {
      brick = "switch", height = 22, gap = 8, mark = 2, roundKnob = true,
      switch = { width = 30, height = 16 },
    },
    range = { fill = true, fillColor = "checked", roundThumb = true, track = 3, thumb = { width = 14, height = 14 } },
    menu = { brick = "list", padding = 4, inset = 12, gap = 1, title = { align = "LEFT" } },
    heading = { lines = "NONE", color = "muted", upper = true, height = 20 },
    group = { brick = "card", frame = "LARGE", padding = 12, title = 20, titleX = 4, color = "title" },
    scroll = { width = 6, thumb = 30, trackAlpha = 0 },
  },

  kit = {
    header = 24,
    control = 18,
  },

  chat = {
    prefix = 0x007AFF,
  },

  bricks = {
    close = { lights = lights },
  },
})
