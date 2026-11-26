local Lib = EbonAPI.Lib
local PANEL = "Interface\\Buttons\\UI-Panel-Button-"
local SLICES = { { 0, 0.09375 }, { 0.09375, 0.53125 }, { 0.53125, 0.625 } }
local CAP = 12

local function wirePress(button)
  button:SetScript("OnMouseDown", function(self)
    self.pressed = true
    self:Visual()
  end)
  button:SetScript("OnMouseUp", function(self)
    self.pressed = false
    self:Visual()
  end)

  button:Visual()
end

function EbonAPI.Skins.synthesisCards(parent, B)
  local Tiles = EbonAPI.Tiles
  local MARGIN, SPACE = 6, 6
  local look = {}
  local LEVEL_KEY = { ok = "success", warn = "caution", bad = "danger", info = "muted", net = "focus" }

  local function mainRole()
    return B.value("widgets.synthesis.value.font")
  end

  local function disc()
    return math.ceil(B.value("fonts." .. mainRole() .. ".size")) + math.ceil(B.value("fonts.small.size"))
  end

  local function paintRing(tile)
    tile.ringKey = LEVEL_KEY[tile.item.level] or "muted"
    B.paint(tile.ring, "SetVertexColor", tile.ringKey)
  end

  local function paintMarker(tile)
    Tiles.paintMarker(tile, tile.ring:GetHeight() * 0.6)
    tile.marker:ClearAllPoints()
    tile.marker:SetPoint("CENTER", tile.ring, "CENTER", 0, 0)
  end

  local function paintTexts(tile)
    local item = tile.item
    local width = tile.cardWidth or 1
    local x0 = MARGIN + tile.ring:GetWidth() + SPACE
    local avail = math.max(1, width - x0 - MARGIN)

    tile.label:SetText(item.label or "")
    tile.value:SetText(item.value or "")
    tile.sub:SetText(item.sub or "")
    Tiles.setTip(tile)

    local first = math.ceil(B.value("fonts." .. mainRole() .. ".size"))
    tile.label:SetWidth(4096)

    local lw = math.min(math.max(1, math.ceil(tile.label:GetStringWidth() or 0) + 1), math.max(1, avail - SPACE - 1))

    tile.label:ClearAllPoints()
    tile.label:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", x0, -MARGIN)
    tile.label:SetWidth(lw)
    tile.label:SetHeight(first)
    tile.value:ClearAllPoints()
    tile.value:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", x0 + lw + SPACE, -MARGIN)
    tile.value:SetWidth(math.max(1, avail - lw - SPACE))
    tile.value:SetHeight(first)
    tile.sub:ClearAllPoints()
    tile.sub:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", x0, -(MARGIN + first))
    tile.sub:SetWidth(avail)
    tile.sub:SetHeight(math.ceil(B.value("fonts.small.size")))
  end

  function look.new(box)
    local frame = CreateFrame("Button", nil, box)
    local tile = { frame = frame, lookName = "cards", discKey = "well" }

    Tiles.wire(box, tile)
    tile.ring = frame:CreateTexture(nil, "BACKGROUND")
    tile.disc = frame:CreateTexture(nil, "BORDER")
    tile.marker = frame:CreateTexture(nil, "OVERLAY")
    tile.ring:SetTexture(B.media("circle"))
    tile.disc:SetTexture(B.media("circle"))
    tile.label = B.text(frame, mainRole(), "text")
    tile.value = B.text(frame, mainRole(), "muted")
    tile.sub = B.text(frame, "small", "muted")

    for _, fs in ipairs({ tile.label, tile.value, tile.sub }) do
      fs:SetJustifyH("LEFT")
      fs:SetJustifyV("TOP")
      EbonAPI.Tiles.wrap(fs, false)
    end

    return tile
  end

  function look.height(box)
    return disc() + 2 * MARGIN
  end

  function look.paint(box, tile, width, height)
    local frame = tile.frame
    local key = Tiles.borderKey(box, tile)
    local size = disc()
    local ring = 4

    B.frame(frame, "small", B.value("widgets.synthesis.fill"), key)
    tile.border = key
    frame:SetWidth(width)
    frame:SetHeight(height)
    tile.cardWidth = width

    tile.ring:SetWidth(size)
    tile.ring:SetHeight(size)
    tile.ring:ClearAllPoints()
    tile.ring:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -MARGIN)
    tile.disc:SetWidth(size - ring)
    tile.disc:SetHeight(size - ring)
    tile.disc:ClearAllPoints()
    tile.disc:SetPoint("CENTER", tile.ring, "CENTER", 0, 0)
    B.paint(tile.disc, "SetVertexColor", tile.discKey)
    paintRing(tile)

    B.font(tile.label, mainRole())
    B.font(tile.value, mainRole())
    B.font(tile.sub, "small")
    B.paint(tile.label, "SetTextColor", "text")
    B.paint(tile.value, "SetTextColor", "muted")
    B.paint(tile.sub, "SetTextColor", "muted")
    paintTexts(tile)
    paintMarker(tile)
  end

  function look.update(box, tile, old)
    local item = tile.item

    if item.label ~= old.label or item.value ~= old.value or item.sub ~= old.sub then
      paintTexts(tile)
    end

    if item.level ~= old.level then
      paintRing(tile)
      paintMarker(tile)
    end

    local key = Tiles.borderKey(box, tile)

    if key ~= tile.border then
      B.frame(tile.frame, "small", B.value("widgets.synthesis.fill"), key)
      tile.border = key
    end
  end

  return Tiles.build(parent, look)
end

function EbonAPI.Skins.groupLabel(B, box, index, text, role, width, y)
  local label = box.labelPool[index]

  B.font(label, role)
  B.paint(label, "SetTextColor", B.value("widgets.synthesis.group.color"))
  label:SetText(text)
  label:ClearAllPoints()
  label:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -y)
  label:SetWidth(width)

  local lh = EbonAPI.Tiles.lineHeight(label, role)

  label:SetHeight(lh)
  label:Show()

  return lh
end

function EbonAPI.Skins.finishLayout(box, y)
  box:SetHeight(math.max(1, y))
  box.contentHeight = y

  return y
end

local function panelButton(parent, B, template, name)
  local button = B.baseButton(parent, function(self)
    local state = "Up"
    local text = self.hovered and "text" or "heading"

    if self.disabledState then
      state, text = "Disabled", "muted"
    elseif self.pressed then
      state = "Down"
    end

    for _, part in ipairs(self.parts) do
      part:SetTexture(PANEL .. state)

      -- A toned button (the accept of a dangerous dialog) tints the game's art with its tone.
      if self.toneBg then
        B.paint(part, "SetVertexColor", self.toneBg)
      else
        B.unpaint(part, "SetVertexColor")
        part:SetVertexColor(1, 1, 1)
      end
    end

    B.paint(self.label, "SetTextColor", text)
    B.labelFont(self, text)
  end, template, name)

  button.secureOk = true
  button.role = "normal"
  button.parts = {}

  for index, slice in ipairs(SLICES) do
    local part = button:CreateTexture(nil, "BACKGROUND")

    part:SetTexCoord(slice[1], slice[2], 0, 0.6875)
    button.parts[index] = part
  end

  local left, middle, right = button.parts[1], button.parts[2], button.parts[3]

  left:SetWidth(CAP)
  left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  right:SetWidth(CAP)
  right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
  middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

  local glow = button:CreateTexture(nil, "HIGHLIGHT")

  glow:SetTexture(PANEL .. "Highlight")
  glow:SetTexCoord(0, 0.625, 0, 0.6875)
  glow:SetBlendMode("ADD")
  glow:SetAllPoints(button)

  wirePress(button)

  return button
end

EbonAPI:RegisterSkin("Azeroth", {
  background = 0x000000,
  accent = 0xFFD100,
  scale = 1,
  opacity = 1,
  shadow = 0.5,
  corners = 0,
  tabs = "LEFT",
  locked = false,

  palette = {
    bg = 0x000000,
    bgSoft = { 0x0C0C1A, 1 },
    well = { 0x0C0C1A, 0.9 },
    card = { 0x191919, 1 },
    border = 0x000000, -- S4 (A99.T9): black contour (Azeroth only; the other skins set their own border)
    borderDim = 0x666666,
    button = 0x2A1A0A,
    buttonBorder = 0x8C6E3C,
    buttonHover = 0xFFD100,
    buttonDisabledBorder = { 0x8C6E3C, 0.4 },
    buttonText = 0xFFD100,
    buttonDisabledText = { 0x808080, 1 },
    checkbox = 0x000000,
    checkboxBorder = 0x8C6E3C,
    checked = 0xFFD100,
    thumb = 0x8C6E3C,
    selected = 0x3263CC,
    selectedText = 0xFFFFFF,
    text = 0xFFFFFF,
    muted = 0x9D9D9D,
    title = 0xFFD100,
    heading = 0xFFD100,
    menu = 0xFFD100,
    shadow = 0x000000,
    focus = 0xFFD100,
    buttonHoverFill = 0x3A2410,
    rowHover = { 0x3263CC, 0.45 },
    headerBg = { 0x000000, 0 },
    navBg = { 0x000000, 0.35 },
    pageBg = { 0x000000, 0 },
    footerBg = { 0x000000, 0 },
    menuBg = { 0x000000, 0.8 },
    success = 0x40FF40,
    danger = 0xFF4444,
    caution = 0xFF9900,
  },

  contrast = { minimum = 4.5, enforce = true, light = 0.96, dark = 0.04, step = 0.15, attempts = 30, mutedStep = 0.05 },

  fonts = {
    small = { file = "game", size = 10, outline = "NONE" },
    normal = { file = "game", size = 12, outline = "NONE" },
    large = { file = "game", size = 16, outline = "NONE" },
    button = { file = "game", size = 10, outline = "AUTO" },
    shadow = { x = 1, y = -1, color = 0x000000, alpha = 1 },
  },

  media = {
    solid = "Interface\\Buttons\\WHITE8X8",
    rounded = "Interface\\Tooltips\\UI-Tooltip-Border",
    arrow = "Interface\\Buttons\\Arrow-Down-Up",
    shadow = "Interface\\AddOns\\EbonAPI\\Media\\Shadow",
    grain = "Interface\\AddOns\\EbonAPI\\Media\\Grain",
    circle = "Interface\\AddOns\\EbonAPI\\Media\\Circle",
    chevron = "Interface\\AddOns\\EbonAPI\\Media\\Chevron",
    ring = "Interface\\AddOns\\EbonAPI\\Media\\Ring.tga",
    rosace = "Interface\\AddOns\\EbonAPI\\Media\\Rosace\\",
    icons = "Interface\\AddOns\\EbonAPI\\Media\\Icons.tga",
    sidebar = "Interface\\AddOns\\EbonAPI\\Media\\Sidebar",
    error = "Interface\\AddOns\\EbonAPI\\Media\\Error",
    warning = "Interface\\AddOns\\EbonAPI\\Media\\Warning",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    addonIcon = "Interface\\Icons\\INV_Misc_QuestionMark",
    pointer = "Interface\\AddOns\\EbonAPI\\Media\\Pointer",
  },

  border = {
    size = 1,
    round = { base = 4, small = 10, inset = 0.25 },
    style = "TEXTURE",
    large = {
      background = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edge = "Interface\\DialogFrame\\UI-DialogBox-Border",
      size = 32, inset = 11, tile = 32,
    },
    small = {
      background = "Interface\\Tooltips\\UI-Tooltip-Background",
      edge = "Interface\\Tooltips\\UI-Tooltip-Border",
      size = 16, inset = 4, tile = 16,
    },
  },

  window = {
    padding = 18,
    spacing = 14,
    card = { border = "border" },
    strata = "HIGH",
    texture = "",
    textureTile = 0,
    textureAlpha = 1,
    gradient = { orientation = "NONE", color = "text", from = 0, to = 0.06 },
    shadow = { base = 4, spread = 14, alphaBase = 0.25, alphaSpread = 0.5, x = 0, y = 0, level = -1, attached = false },
    glass = {
      enabled = false, tint = 0xFFFFFF, darken = 0.35, milk = 0.1, grain = 0.06,
      sheen = 0.08, sheenHeight = 0.4, edge = 0.12, edgeSize = 1,
    },
    fade = 0,
    sound = { open = "", close = "" },
  },

  windows = {
    detach = { header = false, nav = false, page = false, pages = false, list = {}, footer = false }, -- T14: footer
    tile = { content = false }, -- R7f
    -- R7h
    tilePages = {
      "skillTreeInset",
      "ProjectEbonholdEchoJournalMyRunInset+ProjectEbonholdEchoJournalCatalogInset",
      "WardrobeCollectionFrame",
      "MountJournal",
      "PetJournal",
      "EbonholdPrestigeFrame",
    },
    -- R7h end
    gap = 8,
    snap = 12,
    cascade = 24,
  },

  header = {
    show = true,
    height = 40,
    controls = "RIGHT",
    title = { show = true, x = 2, y = 2, align = "CENTER", color = "heading", font = "normal" },
    banner = { texture = "Interface\\DialogFrame\\UI-DialogBox-Header", width = 300, height = 64, y = 12, pad = 16, titleY = 14 },
    version = { show = false, gap = 8, y = 1 },
    search = { show = true, width = 160, height = 20, gap = 10, inset = 6, insetY = 2, position = "CONTROLS" },
    reset = { brick = "close" },
    close = { brick = "native", show = true, size = 32, width = 32, y = 4, glyph = "", hover = 0xE81123, ink = 0x4D0000 },
    rule = { show = false, size = 1 },
    inset = -14,
    spacing = 4,
    history = { show = false, back = "<", forward = ">", width = 22 },
    minimize = { show = false, width = 32, glyph = "-", color = 0xFEBC2E, ink = 0x995700 },
    zoom = { glyph = "+", color = 0x28C840, ink = 0x006500 },
    sidebar = { show = false, size = 16, width = 22 },
  },

  footer = {
    show = false,
    height = 22,
    version = true,
    rule = true,
    ruleSize = 1,
    inset = 2,
    refresh = 1,
    badge = { show = false, color = "focus", text = "selectedText", padding = 8 },
    items = false,
    gap = 10,
    icon = 12,
  },

  panel = { button = { width = 240, height = 24 }, margin = 16, gap = 12 },
  gamemenu = { gap = 1 },

  nav = {
    width = 175,
    inset = 10,
    padding = 6,
    divider = { size = 0, color = "borderDim" },
    frame = "NONE",
    rail = {
      show = false, width = 36, gap = 4, icon = 20, spacing = 4, indicator = 2,
      color = "headerBg", desaturate = true, dim = 0.6, filter = true, crop = 0.08, indicatorColor = "focus",
    },
    tree = {
      collapsible = false, expanded = true, guides = false, chevron = 10, chevronColor = "text",
      guideColor = "borderDim", guideWidth = 1, margin = 2,
    },
    section = {
      brick = "default", show = true, x = 2, height = 20, before = 6, after = 2,
      upper = false, color = "muted", font = "small",
    },
    tab = {
      brick = "native", height = 18, gap = 1, indent = 12, align = "LEFT", bar = 3,
      font = "normal", padding = 8, glow = { selected = 1, hover = 0.5 },
    },
  },

  page = {
    width = 600,
    height = 480,
    gutter = 16,
    top = 46,
    title = { show = true, y = 2, color = "heading", font = "large" },
    description = { show = true, gap = 6, below = 4, color = "text", font = "small" },
    unit = 170,
    gap = { x = 14, y = 12 },
    inset = { x = 6, y = 4 },
    layout = "FLOW",
    descriptions = "TOOLTIP",
    addons = "CARDS",
    strip = {
      show = false, height = 26, padding = 12, border = 1,
      color = "headerBg", tab = "pageBg", accent = "focus", text = "title",
      tabs = 1, idle = "headerBg", idleText = "muted", separator = "borderDim", close = 16,
      font = "button", separatorWidth = 1,
    },
    close = { size = 32, width = 32, gap = 10, glyph = "" },
    frame = "NONE",
    crumbs = { show = false, height = 20, separator = ">", color = "muted", font = "small" },
  },

  -- T16: px added to the common Saves hover margin (Common saves.hoverMargin)
  saves = { hoverMarginAdd = 0 },

  -- R7a
  journal = { tab = { seat = { leftAdd = 0, topAdd = 0, rightAdd = 0, bottomAdd = 0 } }, title = { gapAdd = 0 } },

  widgets = {
    disabledAlpha = 0.5,
    checkBox = { fill = 0x0D0D0D },
    echoTile = {
      markColor = 0x9A6B33,
      stacksColor = 0xC8C8C8,
      missingFill = 0x5A1414,
      missingBorder = 0xE03A3A,
      round = true,
      width = 60,
      height = 84,
      nameTop = 58,
      nameHeight = 24,
      disc = {
        ["0"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_quality_0",
        ["1"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_quality_1",
        ["2"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_quality_2",
        ["3"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_quality_3",
      },
      ring = {
        ["0"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_border_quality_0",
        ["1"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_border_quality_1",
        ["2"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_border_quality_2",
        ["3"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_border_quality_3",
      },
      discScale = 1.2,
      iconScale = 0.8,
      ringScale = 110 / 32,
      ringShift = 2,
      markScale = 0.4,
      book = "Interface\\Icons\\INV_Misc_Book_09",
      bookScale = 11 / 36,
      bookCorner = 2,
      nameQualityColor = true,
    },
    buildCard = { selectedFill = 0x0D1A40, empty = 0x666666, avatar = 0x595966, missing = 0xE6594D, back = 0x14141A },
    buildRow = { neutral = 0x737380, fillNormal = 0x141724, fillSelected = 0x1A295C, edgeNormal = 0x594D1F, hole = 0x0D0D14, missing = 0xE6594D },
    railDisc = { neutral = 0x808080, empty = 0x0D0D0D },
    tooltip = { anchor = "ANCHOR_RIGHT", skinned = false },
    button = { brick = "native", height = 22, padding = 15 },
    execute = { brick = "native", height = 22 },
    toggle = {
      brick = "native", height = 26, size = 26, mark = 3, gap = 2, margin = 2,
      markTexture = "", roundKnob = false, knob = "thumb",
      switch = { width = 28, height = 14 },
    },
    range = {
      brick = "native", height = 52, top = 16, bar = 17, track = 4, labels = 3,
      fill = false, fillColor = "checked", roundThumb = false,
      thumb = { width = 32, height = 32 },
      edit = { width = 60, height = 16, y = 2 },
    },
    select = {
      brick = "default", height = 42, top = 16, padding = 8,
      arrow = { size = 12, right = 22, x = 6, y = 1, gray = false },
    },
    menu = {
      brick = "list", color = "menuBg", row = 20, gap = 1, padding = 3, inset = 12, offset = 2, strata = "FULLSCREEN_DIALOG",
      title = { font = "small", color = "heading", align = "LEFT" },
      native = { dress = true, border = "buttonBorder", text = "text", dim = "muted", check = "checked", arrow = "text", hover = "rowHover", font = "normal", checkGlyph = "x", arrowGlyph = ">", separator = "borderDim", markX = 0, markY = 0, levelBelow = 1 },
    },
    color = { brick = "default", height = 22, size = 18, gap = 6, margin = 2 },
    input = {
      brick = "native", height = 42, top = 16, field = 20, padding = 6, paddingY = 2,
      line = 14, lines = 4, linePad = 8, bottom = 2, gap = 2,
    },
    heading = {
      brick = "default", height = 22, gap = 8, lines = "BOTH", size = 1, upper = false, color = "heading",
    },
    text = { brick = "default", extra = 4 },
    synthesis = {
      brick = "slots", tile = { width = 150, height = 54 }, gap = 6,
      label = { font = "small" }, value = { font = "normal" }, group = { color = "heading" },
      fill = "card", border = "borderDim", selected = "focus",
    },
    stacked = { brick = "default" },
    saves = {
      brick = "default", view = "grid", detail = "dock", denseTipAnchor = "ANCHOR_LEFT", denseTipGap = 0, width = 240, fold = 0.3,
      font = "normal", small = { font = "small" },
      tiled = false, -- read by the STAL module: true = saves laid out as tiles
      row = {
        height = 28, gap = 2, frame = "FLAT", fill = "well", border = "borderDim",
        hover = "rowHover", selected = "selected",
      },
      cell = { size = 50, gap = 5, frame = "FLAT", fill = "card" },
      group = { frame = "FLAT", fill = "card", color = "heading", upper = false },
      drawer = { frame = "SMALL", fill = "well", border = "borderDim" },
      owned = "heading", now = "success", later = "caution",
      ring = { size = 18, big = 38 },
      -- coin.line (true = own line in the sheet) is optional: absent = false.
      dot = { size = 8, border = "borderDim" },
      coin = { size = 6, border = "borderDim", line = false },
      -- metric: sizes, offsets and texts of the saves views (SavesViews.lua); a skin may override any of them.
      metric = { pad = 4, inset = 1, gap = 4, iconSize = 12, chevronSize = 10, dotsWidth = 16, stateTrim = 4, stateShift = 2, pctWidth = 32, pctGap = 2, menuReserve = 18, checkReserve = 12, slotInset = 3, markLeft = 18, dotTop = 5, coinTop = 6, nameTop = 10, nameLines = 3, miniBar = 3, stripWidth = 3, coinGap = 6, doneWidth = 60, toggleMin = 20, cursorHeight = 16, levelStep = 2, listMargin = 8, doubleClick = 0.4, minBar = 0.01, nodesShare = 0.55, restShare = 0.42, percentSuffix = "%", countSeparator = " · ", unknown = "?" },
    },
    choice = {
      brick = "default", font = "small",
      segment = { height = 22, gap = 2, frame = "SMALL", fill = "well", border = "borderDim", selected = "selected" },
      chips = { height = 20, gap = 4, frame = "SMALL", fill = "card", border = "borderDim", selected = "selected", count = "muted" },
    },
    pill = {
      brick = "default", height = 16, frame = "SMALL", font = "small", fill = "card", border = "borderDim",
      ok = "success", warn = "caution", bad = "danger", info = "focus",
    },
    tile = {
      brick = "default", width = 150, height = 64, frame = "SMALL", fill = "card", border = "borderDim", accent = "focus",
      label = { font = "small" }, value = { font = "large" }, sub = { font = "small" },
      gauge = { height = 6, fill = "checked", back = "bgSoft", warn = "caution", bad = "danger" },
    },
    bare = { brick = "default", frame = "FLAT", fill = "bg", border = "borderDim", borderSize = 1 },
    counter = {
      brick = "default", height = 22, frame = "SMALL", fill = "card", font = "small", text = "text", dot = 10, inset = 3, trim = 0.07, tint = 0xFFFFFF,
      token = { gold = "caution", silver = "muted", copper = "danger", ash = "muted", shard = "selected", essence = "success", artisan = "caution" },
    },
    round = {
      brick = "default", size = 28, fill = "card", border = "borderDim", activeFill = "selected", activeBorder = "focus",
      text = "text", activeText = "selectedText", hover = "rowHover",
    },
    zoom = { brick = "default", height = 22, gap = 4, fill = "card", border = "borderDim", text = "text", button = "button" },
    miniview = { brick = "default", width = 190, height = 198, fill = "bg", border = "border", view = "focus", viewAlpha = 0.2, viewBorder = "focus", dot = "heading", showDot = false },
    tipcard = { brick = "default", frame = "SMALL", fill = "card", border = "borderDim", title = "heading", text = "text", muted = "muted", width = 220, padding = 8 },
    map = {
      brick = "default", gap = 1, frame = "FLAT", border = "borderDim", label = { font = "small", min = 36 },
      accent = { fill = "focus" }, gray = { low = "bgSoft", high = "buttonBorder" }, -- S4 (A99.T9): high end keeps the former gold (border is black now); the 6 other skins set gray.high themselves
    },
    group = {
      brick = "card", padding = 12, title = 18, titleX = 2,
      upper = false, color = "heading", font = "normal", frame = "SMALL",
    },
    -- S2 (A99.T6): rowBrick = brick of the rows that replace the native list rows
    list = { selected = "selected", selectedAlpha = 0.5, rowBrick = "list" },
    scroll = { brick = "default", width = 6, thumb = 40, step = 40, trackAlpha = 1, arrowUp = "^", arrowDown = "v", arrowPad = 0 },
    cells = { shape = "bevel" },
    queue = {
      shape = "bevel", gap = 1,
      pill = { height = 16, pad = 6 },
      dot = { size = 8 },
      bar = { width = 60 },
      range = { width = 80 },
      ring = { size = 36, color = "success", compact = 22 },
      counter = { size = 29 },
      band = { label = { size = 10.5 }, value = { size = 20 }, sub1 = { size = 11.5 }, sub2 = { size = 10.5 } },
      group = { headHeight = 34, rowHeight = 24, headBg = "card", headEdge = "borderDim", bodyBg = "bgSoft" },
      table = { row = 28 },
    },
    strip = { shape = "bevel", label = 84, height = 26, gap = 6, tile = 74 },
    cards = { shape = "bevel", gap = 6, pad = 8 },
  },

  tree = {
    -- R7g: compact = frame levels of waste between the lowest and the highest window before the order is packed again
    stack = { levelStep = 1, compact = 500 },
    frames = { enabled = false }, -- T10 (A99.T10): no skin turns the frames of the Journal on
    title = { top = -10, margin = 60, drop = -5 },
    tab = { trim = 18 },
    prestige = { animation = "rosace", circleFrame = "FLAT", fill = "bg", border = "buttonBorder", barFill = "buttonBorder", barDesaturate = true, previewFill = "", text = "" },
    bottom = { frame = "FLAT", height = 40, edge = 0, fill = "bgSoft", border = "borderDim" },
    search = { hide = false },
    piece = { frame = "LARGE", panel = "FLAT", bar = "FLAT", scroll = "FLAT", slot = "SMALL", fill = "bg", barBorder = "bg" }, -- S4 (A99.T9): barBorder = same key as the bar back: no frame
    gauge = { text = 0xFFFFFF, outline = "OUTLINE", shadow = 0x000000, shadowAlpha = 1, shadowX = 1, shadowY = -1 },
    button = { frame = "SMALL", fill = "button", border = "buttonBorder" },
    banner = { frame = "FLAT", fill = "bg", border = "danger" },
    paper = { frame = "FLAT", fill = "bg", border = "border" },
    journal = {
      portraitSize = 78, portraitLeft = -14, portraitTop = 11, iconLeft = -6,
      portraitMargin = 2,
      ringColor = "", ringInset = 2, fadeAlpha = 0,
      -- T14: barre du bas posee dans la tuile journal.footer, par onglet
      height = 608, footerHeight = 36,
      footer = {
        SkillTree = { "skillTreeBottomBar" }, Transmog = { "WardrobeTransmogFrame.ApplyButton" },
        Mounts = { "MountJournal.MountButton" }, Companions = { "PetJournal.SummonButton" },
      },
      tabs = { "Echoes", "SkillTree", "Transmog", "Mounts", "Companions", "Prestige" },
    },
    dense = {
      pad = 4, gap = 4, zoomMargin = 8, hubSize = 96, minimapIdleAlpha = 1,
      hubMax = 12, hubAuraMargin = 1.25, hubAuraOwn = 0.45, hubAuraOther = 0.16,
      hubIconScale = 0.94, hubRingScale = 1.12, hubRadius = 400, hubKey = "heading",
      centerIcon = "Interface\\AddOns\\ProjectEbonhold\\modules\\collections\\Interface\\Icons\\INV_7xp_Inscription_TalentTome01", centerGlow = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", hubAura = "Interface\\AddOns\\ProjectEbonhold\\assets\\class_aura", hubRing = "Interface\\AddOns\\ProjectEbonhold\\assets\\class_ring",
      hubIcon = "Interface\\TargetingFrame\\UI-Classes-Circles", currencyAsh = "Interface\\Icons\\inv_soulash", currencyShard = "Interface\\Icons\\inv_10_jewelcrafting3_soulcage_frost", currencyEssence = "Interface\\Icons\\inv_misc_supersoulash",
      currencyArtisan = "Interface\\Icons\\ability_argus_soulbombdebufflarge", nodePx = 2, hubPx = 4, maxDots = 8,
      dotStep = 3, dotMin = 1.5, linkKey = "borderDim", linkLitKey = "success",
      stateActive = "success", stateReady = "heading", stateNopoints = "caution", stateLocked = "borderDim",
      stateUnknown = "muted",
      mapLinkLitKey = "heading", pendingAlpha = 0.55, haloAlpha = 0.8, lockedAlpha = 0.6,
      fillKey = "bgSoft", fillLockedAlpha = 0.5, iconMinPx = 16, noticeHeight = 20, slotWidth = 240,
      tipIcon = 16, tipColor = 0xFFD100, dotSize = 1,
      minZoom = 0.09, maxZoom = 2.0, zoomStep = 1.12, defaultZoom = 0.6, textMinZoom = 0.45, nodeSize = 30, nodeMinPx = 3, borderPx = 1, presetGrow = 3,
      haloGrow = 2, nodeHaloGrow = 2, nodeHaloTex = "Interface\\Buttons\\WHITE8x8", normalHaloAlpha = 1, normalHaloTex = "Interface\\AddOns\\ProjectEbonhold\\assets\\class_ring_glow", viewMargin = 24, linkPx = 2, linkLitPx = 2, linkTexStraight = "Interface\\Buttons\\WHITE8x8",
      linkTexTilted = "Interface\\AddOns\\ProjectEbonhold\\assets\\link_line", linkTexFactor = 32 / 30, presetKey = "danger", pendingKey = "caution",
      rankKey = "text", noticeKey = "caution", navTipFallback = 0xFFFFFF,
    },
  },

  kit = {
    quality = { ["0"] = 0x9D9D9D, ["1"] = 0xFFFFFF, ["2"] = 0x1EFF00, ["3"] = 0x0070DD, ["4"] = 0xA335EE, ["5"] = 0xFF8000, ["6"] = 0xE6CC80 },
    category = { offensive = 0xE05A4E, defensive = 0x4A9BE0, resource = 0x4CC26A, utility = 0xF08A28, mobility = 0xB06AE0 },
    affix = { equipped = 0x4DC26B, none = 0x808080 },
    followLevel = 1,
    followAbove = true,
    followLevelInside = 40,
    followLevelBase = 40,
    releaseLevel = 1,
    padding = 8,
    spacing = 6,
    inset = 4,
    gap = 2,
    columns = 4,
    wrap = 320,
    text = { font = "small" },
    bar = { color = "card", border = "borderDim" },
    header = 30,
    control = 22,
    icon = {
      size = 32, inset = 2, trim = 0.08,
      color = "checkbox", border = "buttonBorder", hover = "buttonHover", checked = "checked",
    },
    badge = { size = 14, level = 3, color = "focus", text = "selectedText" },
    tag = { color = "borderDim", text = "text", font = "small", padding = 8 },
    questlog = { check = 18 },
    progress = { height = 14, color = "checked", background = "bgSoft", border = "borderDim" },
    row = 20,
    rows = {
      action = 18, fill = "checked", fillAlpha = 0.3, mark = "danger", markAlpha = 0.2, suffix = "muted",
      medium = { height = 24, font = "normal" }, large = { height = 30, font = "large" },
    },
    slot = 24,
    indent = 12,
    list = 200,
    collection = { color = "bgSoft", border = "borderDim", padding = 4 },
    scroll = { width = 320, height = 240 },
    table = {
      row = 18, sort = 8, column = 20, selected = "selected", hover = "rowHover", indent = 14,
      bar = { height = 6, fill = "checked", back = "bgSoft" },
      group = { fill = "card", chevron = "text" },
    },
    toast = { width = 260, duration = 4, top = 120, icon = 24, fade = 0.5 },
    problem = { alert = { width = 300, max = 3, color = "bgSoft" }, discreet = { duration = 6, quiet = 60 } },
    band = { height = 22, alpha = 0.35, text = "text" },
    drag = 12,
    ghost = { width = 170, color = "selected", border = "focus" },
    handle = 12,
    dot = { color = "thumb", hover = "buttonHover" },
    pointer = 48,
    aim = { every = 0.05 },
    timer = { every = 0.1, font = "small" },
    chart = { color = "checked", height = 60, background = "bgSoft", border = "borderDim", column = "bgSoft", label = "muted", value = "text", font = "small", line = 14, series = { s1 = 0xFFD100, s2 = 0x0070DD, s3 = 0xA335EE, s4 = 0x1EFF00, s5 = 0xFF8000 }, others = 0x9D9D9D },
    dialog = {
      width = 320, copy = 80, button = 80, choices = 6, offset = 120,
      title = { font = "normal", color = "heading", align = "CENTER" },
      field = { color = "bgSoft", border = "borderDim" },
      wide = 440,
      rich = {
        padding = 16, spacing = 10,
        title = { font = "large", color = "heading", align = "LEFT" },
        text = { font = "small", color = "muted", align = "LEFT" },
      },
      danger = { color = "danger", border = "danger" },
    },
    minimap = {
      brick = "native", size = 31, inset = 4, ring = 2, offset = 10, corner = 10, angle = 225,
      group = { angle = 245, columns = 4 },
    },
    model = { width = 160, height = 220, turn = 0.02, zoom = { step = 0.25, min = -1, max = 3 } },
    combatAlpha = 0.3,
    animation = 0.15,
    rescale = { delay = 0.01 },
  },

  board = {
  pe = {
    row = 46, gap = 4, head = 20, frame = { margin = 10 },
    portrait = { size = 60, left = 7, top = -6, inset = 2 },
    star = { size = 14, x = 6, y = 3, color = "heading" },
    toggle = { size = 14, x = 2, y = 2, color = "heading", open = "-", close = "+" },
  },
    dress = false,
    portrait = true,
    frame = "LARGE",
    color = "bg",
    border = "border",
    title = { font = "normal", color = "heading", align = "CENTER", x = 20, y = 15 },
    name = { font = "large", color = "text" },
    heading = { font = "normal", color = "text" },
    text = { font = "normal", color = "text" },
    note = { font = "small", color = "heading" },
    objective = { done = "muted" },
    panel = { color = "bgSoft", border = "borderDim" },
    strip = { color = "card", rule = "borderDim" },
    tab = { idle = "button", border = "buttonBorder", padding = 4 },
    button = { idle = "card" },
    art = { frame = true },
    picture = { brick = "default" },
    slot = { brick = "default" },
    header = { height = 20, font = "small", color = "heading", line = "heading", fold = 0.3, room = 8 },
    row = { height = 46, gap = 4, icon = 30, font = "normal" },
    card = { brick = "default" },
    cardHeader = { brick = "default" },
  },

  chat = {
    prefix = 0x8A6FD4,
    text = 0xD1D1F6,
    error = 0xFF4444,
    warn = 0xFF9900,
    success = 0x40FF40,
    highlight = 0xFFD200,
    muted = 0x9090A0,
    gold = 0xFFD700,
    silver = 0xC7C7CF,
    copper = 0xEDA55F,
  },

  bricks = {
    button = { native = panelButton },

    -- The minimap button of the game, as LibDBIcon-1.0 lays it out for a 31 px button: the tracking
    -- border in gold, its dark background and the icon, scaled to the size of the skin.
    minimap = {
      native = function(button, B)
        local size = B.value("kit.minimap.size")
        local unit = size / 31
        local edge = B.value("kit.icon.trim")
        local border = button:CreateTexture(nil, "OVERLAY")
        local background = button:CreateTexture(nil, "BACKGROUND")

        button:SetWidth(size)
        button:SetHeight(size)
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetWidth(53 * unit)
        border:SetHeight(53 * unit)
        border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        background:SetWidth(20 * unit)
        background:SetHeight(20 * unit)
        background:SetPoint("TOPLEFT", button, "TOPLEFT", 7 * unit, -5 * unit)
        button.icon:ClearAllPoints()
        button.icon:SetWidth(17 * unit)
        button.icon:SetHeight(17 * unit)
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7 * unit, -6 * unit)
        button.icon:SetTexCoord(edge, 1 - edge, edge, 1 - edge)

        return button
      end,
    },
    execute = { native = panelButton },

    close = {
      native = function(parent, B)
        local button = B.baseButton(parent, function(self)
          self.icon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-" .. (self.pressed and "Down" or "Up"))
          B.paint(self.label, "SetTextColor", "heading")
          B.labelFont(self, "heading")
        end)
        local glow = button:CreateTexture(nil, "HIGHLIGHT")

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints(button)
        glow:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        glow:SetBlendMode("ADD")
        glow:SetAllPoints(button)
        button:SetPadding(0)
        wirePress(button)

        return button
      end,
    },

    tab = {
      native = function(parent, B)
        local padding = B.value("nav.tab.padding")
        local button = B.baseButton(parent, function(self)
          local text = "heading"

          if self.disabledState then
            text = "muted"
          elseif self.selectedState or self.hovered then
            text = "text"
          end

          B.paint(self.label, "SetTextColor", text)
          B.labelFont(self, text)

          if self.selectedState or self.hovered then
            B.alpha(self.glow, B.value(self.selectedState and "nav.tab.glow.selected" or "nav.tab.glow.hover"))
            self.glow:Show()
          else
            self.glow:Hide()
          end
        end)

        button.role = B.value("nav.tab.font")
        button.glow = button:CreateTexture(nil, "BACKGROUND")
        button.glow:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        button.glow:SetBlendMode("ADD")
        button.glow:SetAllPoints(button)
        B.paint(button.glow, "SetVertexColor", "selected")
        button.label:SetJustifyH("LEFT")
        button:SetPadding(padding)
        button:Visual()

        return button
      end,
    },

    toggle = {
      native = function(parent, B)
        local row = B.toggleRow(parent, function(owner)
          local size = B.value("widgets.toggle.size")
          local texture = B.value("widgets.toggle.markTexture")
          local box = CreateFrame("Frame", nil, owner)
          local up = box:CreateTexture(nil, "ARTWORK")
          local check = box:CreateTexture(nil, "OVERLAY")
          local glow = box:CreateTexture(nil, "OVERLAY")

          box:SetWidth(size)
          box:SetHeight(size)
          box:SetPoint("LEFT", owner, "LEFT", 0, 0)
          up:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
          up:SetAllPoints(box)
          check:SetTexture(texture ~= "" and texture or "Interface\\Buttons\\UI-CheckBox-Check")
          check:SetAllPoints(box)
          glow:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
          glow:SetBlendMode("ADD")
          glow:SetAllPoints(box)
          owner.mark, owner.glow = check, glow

          return box, size
        end)

        function row:Visual()
          Lib.setShown(self.mark, self.value)

          Lib.setShown(self.glow, self.hovered and not self.disabledState)
        end

        row:SetValue(false)

        return row
      end,
    },

    range = {
      native = function(parent, B)
        return B.rangeBox(parent, function(slider)
          slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 },
          })
          slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

          return {}
        end)
      end,
    },

    -- The summary tiles as bag slots: a 40 px square (marker in the centre, counter at the bottom right)
    -- with the label under it; the full value and the sub-text are in the tooltip.
    synthesis = {
      slots = function(parent, B)
        local Tiles = EbonAPI.Tiles
        local SQUARE, CELL, LEAD, COUNTER = 40, 84, 4, 2
        local look = {}

        local labelRole = EbonAPI.Skins.synthesisRoles(B)
        local function counterOf(item)
          local token = string.match(item.value or "", "^[%d][%d%.,]*")

          return token and string.gsub(token, "[%.,]+$", "") or nil
        end

        local function paintCounter(tile)
          local token = counterOf(tile.item)

          if token then
            tile.count:SetText(token)
            tile.count:Show()
          else
            tile.count:SetText("")
            tile.count:Hide()
          end
        end

        local function paintMarker(tile)
          Tiles.paintMarker(tile, SQUARE * 0.6)
          tile.marker:ClearAllPoints()
          tile.marker:SetPoint("CENTER", tile.slot, "CENTER", 0, 0)
        end

        local function paintTexts(tile)
          local item = tile.item

          tile.label:SetText(item.label or "")
          tile.value:SetText(item.value or "")
          tile.sub:SetText(item.sub or "")
          paintCounter(tile)
          Tiles.setTip(tile)
        end

        function look.new(box)
          local frame = CreateFrame("Button", nil, box)
          local slot = CreateFrame("Frame", nil, frame)
          local tile = { frame = frame, slot = slot, lookName = "slots", fillKey = "well" }

          Tiles.wire(box, tile)
          slot:SetWidth(SQUARE)
          slot:SetHeight(SQUARE)
          slot:SetPoint("TOPLEFT", frame, "TOPLEFT", (CELL - SQUARE) / 2, 0)
          tile.marker = slot:CreateTexture(nil, "OVERLAY")
          tile.count = B.text(slot, "small", "text")
          tile.count:SetJustifyH("RIGHT")
          tile.count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -COUNTER, COUNTER)
          tile.label = B.text(frame, labelRole(), "muted")
          tile.label:SetJustifyH("CENTER")
          tile.label:SetJustifyV("TOP")
          -- Kept for the readers of tile.value / tile.sub, never shown: the tooltip carries them.
          tile.value = B.text(frame, labelRole(), "text")
          tile.sub = B.text(frame, labelRole(), "muted")
          tile.value:Hide()
          tile.sub:Hide()

          return tile
        end

        function look.height(box)
          return SQUARE + LEAD + 2 * math.ceil(B.value("fonts." .. labelRole() .. ".size"))
        end

        function look.paint(box, tile, width, height)
          local frame = tile.frame
          local key = Tiles.borderKey(box, tile)

          frame:SetWidth(width)
          frame:SetHeight(height)
          B.frame(tile.slot, "small", tile.fillKey, key)
          tile.border = key
          B.font(tile.count, "small")
          B.paint(tile.count, "SetTextColor", "text")
          B.font(tile.label, labelRole())
          B.paint(tile.label, "SetTextColor", "muted")
          EbonAPI.Tiles.wrap(tile.label, true)
          tile.label:ClearAllPoints()
          tile.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(SQUARE + LEAD))
          tile.label:SetWidth(width)
          paintTexts(tile)
          tile.label:SetHeight(Tiles.lineHeight(tile.label, labelRole()))
          paintMarker(tile)
        end

        function look.update(box, tile, old)
          local item = tile.item

          if item.label ~= old.label or item.value ~= old.value or item.sub ~= old.sub then
            paintTexts(tile)
            tile.label:SetHeight(Tiles.lineHeight(tile.label, labelRole()))
          end

          if item.level ~= old.level then
            paintMarker(tile)
          end

          local key = Tiles.borderKey(box, tile)

          if key ~= tile.border then
            B.frame(tile.slot, "small", tile.fillKey, key)
            tile.border = key
          end
        end

        -- Cells of a fixed width, laid out from the left under the group label.
        function look.layout(box)
          local width = math.max(1, box.boxWidth)
          local gap = B.value("widgets.synthesis.gap")
          local cols = math.max(1, math.floor((width + gap) / (CELL + gap)))
          local cellHeight = look.height(box)
          local role = labelRole()
          local y = 0

          for index, group in ipairs(box.groups or {}) do
            local lh = EbonAPI.Skins.groupLabel(B, box, index, group.label or "", role, width, y)

            y = y + lh + gap

            for position, tile in ipairs(group.tiles) do
              local col = (position - 1) % cols
              local row = math.floor((position - 1) / cols)

              box.look.paint(box, tile, CELL, cellHeight)
              tile.frame:ClearAllPoints()
              tile.frame:SetPoint("TOPLEFT", box, "TOPLEFT", col * (CELL + gap), -(y + row * (cellHeight + gap)))
              tile.frame:Show()
            end

            local rows = math.ceil(#group.tiles / cols)

            y = y + rows * cellHeight + math.max(0, rows - 1) * gap

            if index < #box.groups then
              y = y + gap
            end
          end

          return EbonAPI.Skins.finishLayout(box, y)
        end

        return Tiles.build(parent, look)
      end,
    },


    input = {
      native = function(parent, B)
        local parts = {}
        local box = B.inputBox(parent, function(field)
          for index, slice in ipairs({ { 0, 0.0625 }, { 0.0625, 0.9375 }, { 0.9375, 1 } }) do
            local part = field:CreateTexture(nil, "BACKGROUND")

            part:SetTexture("Interface\\Common\\Common-Input-Border")
            part:SetTexCoord(slice[1], slice[2], 0, 0.625)
            parts[index] = part
          end

          parts[1]:SetWidth(8)
          parts[1]:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
          parts[1]:SetPoint("BOTTOMLEFT", field, "BOTTOMLEFT", 0, 0)
          parts[3]:SetWidth(8)
          parts[3]:SetPoint("TOPRIGHT", field, "TOPRIGHT", 0, 0)
          parts[3]:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", 0, 0)
          parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT", 0, 0)
          parts[2]:SetPoint("BOTTOMRIGHT", parts[3], "BOTTOMLEFT", 0, 0)
        end)

        box.parts = parts

        return box
      end,
    },
  },
})
