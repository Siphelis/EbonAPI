EbonAPI:RegisterSkin("AutoCallboard", {
  background = 0x050505,
  accent = 0xB048F8,
  opacity = 0.96,
  shadow = 0.4,

  palette = {
    bg = { 0x050505, 0.96 },
    bgSoft = { 0x050505, 0.86 },
    card = { 0x050505, 0.92 },
    border = 0x4B2E83,
    borderDim = { 0x4B2E83, 0.65 },
    button = 0x4B2E83,
    buttonBorder = 0x4B2E83,
    buttonHover = 0xE879FF,
    buttonDisabledBorder = { 0x4B2E83, 0 },
    buttonText = 0xD1D1F6,
    buttonDisabledText = { 0xD1D1F6, 0.45 },
    checkbox = 0x050505,
    checkboxBorder = 0x4B2E83,
    checked = 0xB048F8,
    thumb = 0x4B2E83,
    selected = 0xB048F8,
    selectedText = 0x0A0A0A,
    text = 0xD1F6F6,
    muted = { 0xD1E3F6, 0.78 },
    title = 0xD1D1F6,
    heading = 0xB048F8,
    menu = 0xB048F8,
    shadow = 0x000000,
    focus = 0xE879FF,
    buttonHoverFill = 0x4B2E83,
    rowHover = { 0xB048F8, 0.2 },
    headerBg = { 0x050505, 0 },
    navBg = { 0x050505, 0 },
    pageBg = { 0x050505, 0 },
    footerBg = { 0x050505, 0 },
    success = 0x40FF40,
  },

  border = {
    style = "ROUND",
    large = {
      background = "Interface\\Buttons\\WHITE8X8", edge = "Interface\\Tooltips\\UI-Tooltip-Border",
      size = 16, inset = 4, tile = 0,
    },
    small = { background = "Interface\\Buttons\\WHITE8X8", size = 10, inset = 2, tile = 0 },
  },

  window = {
    padding = 14,
  },

  header = {
    height = 44,
    title = { y = 14, align = "SIDE", font = "large" },
    banner = { texture = "", width = 256 },
    version = { show = true },
    search = { width = 200, height = 22, inset = 8 },
    close = { brick = "default", size = 22, width = 22, y = 11 },
    rule = { show = true },
    inset = 0,
  },

  nav = {
    width = 184,
    padding = 0,
    tab = { brick = "fill", height = 24, gap = 4, align = "CENTER", font = "button", padding = 6 },
  },

  page = {
    width = 634,
    height = 528,
    description = { color = "muted" },
    inset = { x = 0, y = 0 },
  },

  widgets = {
    tooltip = { skinned = true },
    button = { brick = "default", padding = 12 },
    execute = { brick = "default", height = 24 },
    toggle = { brick = "box", height = 22, size = 16, gap = 6 },
    range = { brick = "default", height = 50, top = 15, bar = 14 },
    menu = { brick = "fill", inset = 6, title = { align = "CENTER" } },
    input = { brick = "default", field = 22 },
    group = { padding = 10, frame = "LARGE" },
  },
})
