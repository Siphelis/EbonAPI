local MATIERE = "Interface\\AddOns\\EbonAPI-Skin-Magmathar\\Media\\Matiere\\"
local MEDIA = "Interface\\AddOns\\EbonAPI\\Media\\"
local function matiere(region, file)
  region:SetTexture(MATIERE .. file)
end

local function shown(region, visible)
  if visible then
    region:Show()
  else
    region:Hide()
  end
end

local FACES = {
  repos = { "bouton-repos", "buttonText" },
  survol = { "bouton-survol", "buttonText" },
  enfonce = { "bouton-enfonce", "selectedText" },
  desactive = { "bouton-desactive", "buttonDisabledText" },
  principal = { "bouton-principal", "buttonText" },
}

local function faceOf(button)
  if button.disabledState then
    return FACES.desactive
  end

  if button.selectedState or button.pressed then
    return FACES.enfonce
  end

  if button.hovered then
    return FACES.survol
  end

  if button.toneBg then
    return FACES.principal
  end

  return FACES.repos
end

local function braise(parent, B, template, name)
  local button

  local function visual(self)
    local face = faceOf(self)
    local text = face == FACES.repos and self.textKey or face[2]

    matiere(self.face, face[1])
    B.paint(self.label, "SetTextColor", text)
    B.labelFont(self, text)
  end

  button = B.baseButton(parent, visual, template, name)
  button.face = button:CreateTexture(nil, "BACKGROUND")
  button.face:SetAllPoints(button)
  button.face:SetTexCoord(0, 0.9375, 0, 0.6875)
  button.secureOk = true

  button:SetScript("OnMouseDown", function(self)
    self.pressed = true
    self:Visual()
  end)
  button:SetScript("OnMouseUp", function(self)
    self.pressed = false
    self:Visual()
  end)

  button:Visual()

  return button
end

local function facedButton(parent, B, visual, align, padding, role)
  local button = B.baseButton(parent, visual)

  button.kit = B
  button.face = button:CreateTexture(nil, "BACKGROUND")
  button.face:SetAllPoints(button)
  button.role = role
  button.label:SetJustifyH(align)
  button:SetPadding(padding)
  button:Visual()

  return button
end

local function paintLabel(button, text, B)
  B.paint(button.label, "SetTextColor", text)
  B.labelFont(button, text)
end

local function tabVisual(self)
  local file, text = "onglet-repos", self.textKey or "text"

  if self.selectedState then
    file, text = "onglet-actif", "title"
  elseif self.disabledState then
    text = "muted"
  elseif self.hovered then
    file, text = "onglet-survol", "buttonText"
  end

  matiere(self.face, file)
  paintLabel(self, text, self.kit)
end

local function tabBrick(parent, B)
  return facedButton(parent, B, tabVisual, B.value("nav.tab.align"), B.value("nav.tab.padding"), B.value("nav.tab.font"))
end

local function rowVisual(self)
  local text = self.textKey or "text"
  local file

  if self.selectedState then
    file, text = "selection-v2", "selectedText"
  elseif self.disabledState then
    text = "muted"
  elseif self.hovered then
    file = "survol-ligne"
  end

  if file then
    matiere(self.face, file)
    self.face:Show()
  else
    self.face:Hide()
  end

  paintLabel(self, text, self.kit)
end

local function rowBrick(parent, B)
  local row = facedButton(parent, B, rowVisual, "LEFT", B.value("widgets.menu.inset"), "button")

  function row:SetMarked(marked)
    marked = marked and true or false
    self.markedState = marked

    if not self.mark then
      if not marked then
        return
      end

      self.mark = self:CreateTexture(nil, "BACKGROUND")
      matiere(self.mark, "selection-v2")
      self.mark:SetAllPoints(self)
    end

    shown(self.mark, marked)
  end

  return row
end

local function caseBrick(parent, B)
  local row = B.toggleRow(parent, function(owner)
    local size = B.value("widgets.toggle.size")
    local box = CreateFrame("Frame", nil, owner)

    box:SetWidth(size)
    box:SetHeight(size)
    box:SetPoint("LEFT", owner, "LEFT", 0, 0)
    box.well = box:CreateTexture(nil, "BACKGROUND")
    matiere(box.well, "case")
    box.well:SetAllPoints(box)
    owner.mark = box:CreateTexture(nil, "OVERLAY")
    matiere(owner.mark, "case-coche")
    owner.mark:SetAllPoints(box)

    return box, size
  end)

  function row:Visual()
    shown(self.mark, self.value)
  end

  row:SetValue(false)

  return row
end

local function railDress(slider)
  local track = slider:CreateTexture(nil, "BACKGROUND")
  local filled = slider:CreateTexture(nil, "BORDER")

  matiere(track, "curseur-rail")
  track:SetTexCoord(0, 1, 0, 0.75)
  track:SetHeight(12)
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  matiere(filled, "lave-curseur")
  filled:SetHeight(12)
  filled:SetPoint("LEFT", slider, "LEFT", 0, 0)
  slider:SetThumbTexture(MATIERE .. "curseur-poignee")

  local thumb = slider:GetThumbTexture()

  return {
    track = track,
    fill = filled,
    hover = function(over)
      if thumb then
        thumb:SetAlpha(over and 1 or 0.85)
      end
    end,
  }
end

local function curseurBrick(parent, B)
  return B.rangeBox(parent, railDress)
end

local function wellDress(field)
  local well = field:CreateTexture(nil, "BACKGROUND")

  matiere(well, "champ")
  well:SetAllPoints(field)

  return function(focused)
    matiere(well, (focused and "champ-focus" or "champ"))
  end
end

local function champBrick(parent, B)
  return B.inputBox(parent, wellDress)
end

local function selectVisual(self)
  local text = "text"

  if self.disabledState then
    text = "buttonDisabledText"
  end

  matiere(self.face, ((self.hovered or self.pressed) and not self.disabledState and "champ-focus" or "champ"))
  paintLabel(self, text, self.kit)
end

local function selectBrick(parent, B)
  local box = B.build("select", "default", parent)

  box.button.kit = B
  box.button.face:SetTexCoord(0, 1, 0, 1)
  box.button.Visual = selectVisual
  box.button:Visual()

  return box
end

local function scrollBrick(parent, B)
  local scroll = B.build("scroll", "default", parent)
  local rail = scroll.bar:CreateTexture(nil, "BORDER")
  local thumb = scroll.bar:GetThumbTexture()

  matiere(rail, "defilement-rail")
  rail:SetAllPoints(scroll.bar)

  if thumb then
    matiere(thumb, "defilement-poignee")
    B.unpaint(thumb, "SetVertexColor")
    thumb:SetVertexColor(1, 1, 1, 1)
  end

  return scroll
end

local function sectionBrick(parent, B)
  local section = B.build("section", "default", parent)
  local line = section:CreateTexture(nil, "BORDER")
  local gem = section:CreateTexture(nil, "ARTWORK")

  matiere(line, "separateur-filet")
  line:SetHeight(4)
  line:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", 0, 0)
  matiere(gem, "separateur-losange")
  gem:SetWidth(8)
  gem:SetHeight(8)
  gem:SetPoint("BOTTOM", section, "BOTTOM", 0, -2)

  return section
end

local function builtin(slot, name)
  return function(parent, B)
    return B.build(slot, name, parent)
  end
end

EbonAPI:RegisterSkin("Magmathar", {
  background = 0x0D0B0B,
  accent = 0xFF5A1F,
  scale = 1,
  opacity = 1,
  shadow = 0.8,
  corners = 0,
  tabs = "LEFT",
  locked = false,
  palette = {
    bg = 0x0D0B0B,
    bgSoft = 0x151110,
    card = 0x1C1614,
    border = 0x6E4A22,
    borderDim = 0x3A2A18,
    button = 0x1C1614,
    buttonBorder = 0x6E4A22,
    buttonHover = 0xFF5A1F,
    buttonDisabledBorder = { 0x6E4A22, 0.4 },
    buttonText = 0xE9C88A,
    buttonDisabledText = 0x80786D,
    checkbox = 0x070606,
    checkboxBorder = 0x6E4A22,
    checked = 0xFFB347,
    thumb = 0x6E4A22,
    selected = 0x3A120A,
    selectedText = 0xFFF1C9,
    text = 0xE6DDD0,
    muted = 0xA99D8B,
    title = 0xF1D9A8,
    heading = 0xE9C88A,
    menu = 0xE9C88A,
    shadow = { 0x000000, 0.8 },
    focus = 0xFF5A1F,
    buttonHoverFill = 0x241410,
    rowHover = { 0xFF7A28, 0.16 },
    headerBg = { 0x0D0B0B, 0 },
    navBg = { 0x0D0B0B, 0.35 },
    pageBg = { 0x0D0B0B, 0 },
    footerBg = { 0x0D0B0B, 0 },
    menuBg = { 0x151110, 0.95 },
    success = 0xC9B24A,
    danger = 0xFF4A3A,
    caution = 0xFF9A2A,
    well = 0x070606,
  },
  contrast = {
    minimum = 4.5,
    enforce = true,
    light = 0.96,
    dark = 0.04,
    step = 0.15,
    attempts = 30,
    mutedStep = 0.05,
  },
  fonts = {
    small = {
      file = "game",
      size = 10,
      outline = "NONE",
    },
    normal = {
      file = "game",
      size = 12,
      outline = "NONE",
    },
    large = {
      file = "game",
      size = 16,
      outline = "NONE",
    },
    button = {
      file = "game",
      size = 10,
      outline = "AUTO",
    },
    shadow = {
      x = 1,
      y = -1,
      color = 0x000000,
      alpha = 1,
    },
  },
  media = {
    solid = "Interface\\Buttons\\WHITE8X8",
    rounded = "Interface\\Tooltips\\UI-Tooltip-Border",
    arrow = "Interface\\Buttons\\Arrow-Down-Up",
    shadow = MEDIA .. "Shadow",
    grain = MEDIA .. "Grain",
    circle = MEDIA .. "Circle",
    chevron = MEDIA .. "Chevron",
    ring = MEDIA .. "Ring.tga",
    icons = MEDIA .. "Icons.tga",
    sidebar = MEDIA .. "Sidebar",
    error = MEDIA .. "Error",
    warning = MEDIA .. "Warning",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    addonIcon = "Interface\\Icons\\INV_Misc_QuestionMark",
    pointer = MEDIA .. "Pointer",
    rosace = MEDIA .. "Rosace\\",
  },
  border = {
    size = 1,
    round = {
      base = 4,
      small = 10,
      inset = 0.25,
    },
    style = "TEXTURE",
    large = {
      background = MATIERE .. "fond-fenetre.tga",
      edge = MATIERE .. "bronze-fenetre.tga",
      size = 32,
      inset = 11,
      tile = 256,
    },
    small = {
      background = MATIERE .. "panneau.tga",
      edge = MATIERE .. "bronze-fin.tga",
      size = 16,
      inset = 4,
      tile = 256,
    },
  },
  window = {
    padding = 18,
    spacing = 14,
    card = {
      border = "border",
    },
    strata = "HIGH",
    texture = MATIERE .. "fond-fenetre.tga",
    textureTile = 256,
    textureAlpha = 1,
    gradient = {
      orientation = "NONE",
      color = "text",
      from = 0,
      to = 0.06,
    },
    shadow = {
      base = 4,
      spread = 14,
      alphaBase = 0.25,
      alphaSpread = 0.5,
      x = 0,
      y = 0,
      level = -1,
      attached = false,
    },
    glass = {
      enabled = false,
      tint = 0xFFFFFF,
      darken = 0.35,
      milk = 0.1,
      grain = 0.06,
      sheen = 0.08,
      sheenHeight = 0.4,
      edge = 0.12,
      edgeSize = 1,
    },
    fade = 0,
    sound = {
      open = "",
      close = "",
    },
  },
  windows = {
    detach = {
      header = false,
      nav = false,
      page = false,
      pages = false,
      list = {  },
      footer = false,
    },
    gap = 8,
    snap = 12,
    cascade = 24,
    tile = {
      content = false,
    },
    tilePages = { "skillTreeInset", "ProjectEbonholdEchoJournalMyRunInset+ProjectEbonholdEchoJournalCatalogInset", "WardrobeCollectionFrame", "MountJournal", "PetJournal", "EbonholdPrestigeFrame" },
  },
  header = {
    show = true,
    height = 40,
    controls = "RIGHT",
    title = {
      show = true,
      x = 2,
      y = 2,
      align = "CENTER",
      color = "heading",
      font = "normal",
    },
    banner = {
      texture = "Interface\\DialogFrame\\UI-DialogBox-Header",
      width = 300,
      height = 64,
      y = 12,
      pad = 16,
      titleY = 14,
    },
    version = {
      show = false,
      gap = 8,
      y = 1,
    },
    search = {
      show = true,
      width = 160,
      height = 20,
      gap = 10,
      inset = 6,
      insetY = 2,
      position = "CONTROLS",
    },
    close = {
      show = true,
      size = 32,
      y = 4,
      brick = "native",
      width = 32,
      glyph = "",
      hover = 0xE81123,
      ink = 0x4D0000,
    },
    reset = {
      brick = "close",
    },
    inset = -14,
    spacing = 4,
    history = {
      show = false,
      back = "<",
      forward = ">",
      width = 22,
    },
    minimize = {
      show = false,
      width = 32,
      glyph = "-",
      color = 0xFEBC2E,
      ink = 0x995700,
    },
    zoom = {
      glyph = "+",
      color = 0x28C840,
      ink = 0x006500,
    },
    sidebar = {
      show = false,
      size = 16,
      width = 22,
    },
    rule = {
      show = false,
      size = 1,
    },
  },
  footer = {
    show = false,
    height = 22,
    version = true,
    rule = true,
    ruleSize = 1,
    inset = 2,
    refresh = 1,
    badge = {
      show = false,
      color = "focus",
      text = "selectedText",
      padding = 8,
    },
    items = false,
    gap = 10,
    icon = 12,
  },
  panel = {
    button = {
      width = 240,
      height = 24,
    },
    margin = 16,
    gap = 12,
  },
  gamemenu = {
    gap = 1,
  },
  nav = {
    width = 175,
    inset = 10,
    padding = 6,
    divider = {
      size = 0,
      color = "borderDim",
    },
    frame = "NONE",
    rail = {
      show = false,
      width = 36,
      gap = 4,
      icon = 20,
      spacing = 4,
      indicator = 2,
      color = "headerBg",
      crop = 0.08,
      indicatorColor = "focus",
      desaturate = true,
      dim = 0.6,
      filter = true,
    },
    tree = {
      collapsible = false,
      expanded = true,
      guides = false,
      chevron = 10,
      chevronColor = "text",
      guideColor = "borderDim",
      guideWidth = 1,
      margin = 2,
    },
    section = {
      brick = "default",
      show = true,
      x = 2,
      height = 20,
      before = 6,
      after = 2,
      upper = false,
      color = "muted",
      font = "small",
    },
    tab = {
      brick = "onglet",
      height = 18,
      gap = 1,
      indent = 12,
      align = "LEFT",
      bar = 3,
      font = "normal",
      padding = 8,
      glow = {
        selected = 1,
        hover = 0.5,
      },
    },
  },
  page = {
    width = 600,
    height = 480,
    gutter = 16,
    top = 46,
    title = {
      show = true,
      y = 2,
      color = "heading",
      font = "large",
    },
    description = {
      show = true,
      gap = 6,
      below = 4,
      color = "text",
      font = "small",
    },
    unit = 170,
    gap = {
      x = 14,
      y = 12,
    },
    addons = "CARDS",
    inset = {
      x = 6,
      y = 4,
    },
    layout = "FLOW",
    descriptions = "TOOLTIP",
    strip = {
      show = false,
      height = 26,
      padding = 12,
      border = 1,
      color = "headerBg",
      tab = "pageBg",
      accent = "focus",
      text = "title",
      tabs = 1,
      idle = "headerBg",
      idleText = "muted",
      separator = "borderDim",
      close = 16,
      font = "button",
      separatorWidth = 1,
    },
    close = {
      size = 32,
      width = 32,
      gap = 10,
      glyph = "",
    },
    frame = "NONE",
    crumbs = {
      show = false,
      height = 20,
      separator = ">",
      color = "muted",
      font = "small",
    },
  },
  widgets = {
    disabledAlpha = 0.5,
    tooltip = {
      anchor = "ANCHOR_RIGHT",
      skinned = false,
    },
    button = {
      brick = "braise",
      height = 22,
      padding = 15,
    },
    execute = {
      brick = "braise",
      height = 22,
    },
    toggle = {
      brick = "case",
      height = 26,
      size = 26,
      mark = 3,
      markTexture = "",
      roundKnob = false,
      knob = "thumb",
      gap = 2,
      margin = 2,
      switch = {
        width = 28,
        height = 14,
      },
    },
    range = {
      brick = "curseur",
      height = 52,
      top = 16,
      bar = 17,
      track = 4,
      thumb = {
        width = 16,
        height = 16,
      },
      labels = 3,
      edit = {
        width = 60,
        height = 16,
        y = 2,
      },
      fill = false,
      fillColor = "checked",
      roundThumb = false,
    },
    select = {
      brick = "default",
      height = 42,
      top = 16,
      padding = 8,
      arrow = {
        size = 12,
        right = 22,
        x = 6,
        y = 1,
        gray = false,
      },
    },
    menu = {
      row = 20,
      gap = 1,
      padding = 3,
      inset = 12,
      offset = 2,
      strata = "FULLSCREEN_DIALOG",
      brick = "list",
      title = {
        font = "small",
        color = "heading",
        align = "LEFT",
      },
      color = "menuBg",
      native = {
        dress = true,
        border = "buttonBorder",
        text = "text",
        dim = "muted",
        check = "checked",
        arrow = "text",
        hover = "rowHover",
        font = "normal",
        checkGlyph = "x",
        arrowGlyph = ">",
        separator = "borderDim",
        markX = 0,
        markY = 0,
        levelBelow = 1,
      },
    },
    color = {
      brick = "default",
      height = 22,
      size = 18,
      gap = 6,
      margin = 2,
    },
    input = {
      brick = "champ",
      height = 42,
      top = 16,
      field = 20,
      padding = 6,
      paddingY = 2,
      line = 14,
      lines = 4,
      linePad = 8,
      bottom = 2,
      gap = 2,
    },
    checkBox = {
      fill = 0x0D0D0D,
    },
    echoTile = {
      markColor = 0x9A6B33,
      stacksColor = 0xC8C8C8,
      missingFill = 0x5A1414,
      missingBorder = 0xE03A3A,
    },
    buildCard = {
      selectedFill = 0x0D1A40,
      empty = 0x666666,
      avatar = 0x595966,
      missing = 0xE6594D,
      back = 0x14141A,
    },
    buildRow = {
      neutral = 0x737380,
      fillNormal = 0x141724,
      fillSelected = 0x1A295C,
      edgeNormal = 0x594D1F,
      hole = 0x0D0D14,
      missing = 0xE6594D,
    },
    railDisc = {
      neutral = 0x808080,
      empty = 0x0D0D0D,
    },
    heading = {
      brick = "default",
      height = 22,
      gap = 8,
      lines = "BOTH",
      size = 1,
      upper = false,
      color = "heading",
    },
    text = {
      brick = "default",
      extra = 4,
    },
    synthesis = {
      brick = "slots",
      tile = {
        width = 150,
        height = 54,
      },
      gap = 6,
      label = {
        font = "small",
      },
      value = {
        font = "normal",
      },
      group = {
        color = "heading",
      },
      fill = "card",
      border = "borderDim",
      selected = "focus",
    },
    saves = {
      brick = "default",
      tiled = false,
      view = "grid",
      detail = "dock",
      denseTipAnchor = "ANCHOR_LEFT",
      denseTipGap = 0,
      width = 240,
      fold = 0.3,
      font = "normal",
      small = {
        font = "small",
      },
      row = {
        height = 28,
        gap = 2,
        frame = "FLAT",
        fill = "well",
        border = "borderDim",
        hover = "rowHover",
        selected = "selected",
      },
      cell = {
        size = 50,
        gap = 5,
        frame = "FLAT",
        fill = "card",
      },
      group = {
        frame = "FLAT",
        fill = "card",
        color = "heading",
        upper = false,
      },
      drawer = {
        frame = "SMALL",
        fill = "well",
        border = "borderDim",
      },
      owned = "heading",
      dot = {
        size = 8,
        border = "borderDim",
      },
      coin = {
        size = 6,
        border = "borderDim",
        line = false,
      },
      metric = {
        pad = 4,
        inset = 1,
        gap = 4,
        iconSize = 12,
        chevronSize = 10,
        dotsWidth = 16,
        stateTrim = 4,
        stateShift = 2,
        pctWidth = 32,
        pctGap = 2,
        menuReserve = 18,
        checkReserve = 12,
        slotInset = 3,
        markLeft = 18,
        dotTop = 5,
        coinTop = 6,
        nameTop = 10,
        nameLines = 3,
        miniBar = 3,
        stripWidth = 3,
        coinGap = 6,
        doneWidth = 60,
        toggleMin = 20,
        cursorHeight = 16,
        levelStep = 2,
        listMargin = 8,
        doubleClick = 0.4,
        minBar = 0.01,
        nodesShare = 0.55,
        restShare = 0.42,
        percentSuffix = "%",
        countSeparator = " · ",
        unknown = "?",
      },
      now = "success",
      later = "caution",
      ring = {
        size = 18,
        big = 38,
      },
    },
    stacked = {
      brick = "default",
    },
    choice = {
      brick = "default",
      font = "small",
      segment = {
        height = 22,
        gap = 2,
        frame = "SMALL",
        fill = "well",
        border = "borderDim",
        selected = "selected",
      },
      chips = {
        height = 20,
        gap = 4,
        frame = "SMALL",
        fill = "card",
        border = "borderDim",
        selected = "selected",
        count = "muted",
      },
    },
    pill = {
      brick = "default",
      height = 16,
      frame = "SMALL",
      font = "small",
      fill = "card",
      border = "borderDim",
      ok = "success",
      warn = "caution",
      bad = "danger",
      info = "focus",
    },
    tile = {
      brick = "default",
      width = 150,
      height = 64,
      frame = "SMALL",
      fill = "card",
      border = "borderDim",
      accent = "focus",
      label = {
        font = "small",
      },
      value = {
        font = "large",
      },
      sub = {
        font = "small",
      },
      gauge = {
        height = 6,
        fill = "checked",
        back = "bgSoft",
        warn = "caution",
        bad = "danger",
      },
    },
    bare = {
      brick = "default",
      frame = "FLAT",
      fill = "bg",
      border = "borderDim",
      borderSize = 1,
    },
    counter = {
      brick = "default",
      height = 22,
      frame = "SMALL",
      fill = "card",
      font = "small",
      text = "text",
      dot = 10,
      inset = 3,
      trim = 0.07,
      tint = 0xFFFFFF,
      token = {
        gold = "caution",
        silver = "muted",
        copper = "danger",
        ash = "muted",
        shard = "selected",
        essence = "success",
        artisan = "caution",
      },
    },
    round = {
      brick = "default",
      size = 28,
      fill = "card",
      border = "borderDim",
      activeFill = "selected",
      activeBorder = "focus",
      text = "text",
      activeText = "selectedText",
      hover = "rowHover",
    },
    zoom = {
      brick = "default",
      height = 22,
      gap = 4,
      fill = "card",
      border = "borderDim",
      text = "text",
      button = "button",
    },
    miniview = {
      brick = "default",
      width = 190,
      height = 198,
      fill = "bg",
      border = "border",
      view = "focus",
      viewBorder = "focus",
      dot = "heading",
      viewAlpha = 0.2,
      showDot = false,
    },
    tipcard = {
      brick = "default",
      frame = "SMALL",
      fill = "card",
      border = "borderDim",
      title = "heading",
      text = "text",
      muted = "muted",
      width = 220,
      padding = 8,
    },
    map = {
      brick = "default",
      gap = 1,
      frame = "FLAT",
      border = "borderDim",
      label = {
        font = "small",
        min = 36,
      },
      accent = {
        fill = "focus",
      },
      gray = {
        low = "bgSoft",
        high = "buttonBorder",
      },
    },
    group = {
      brick = "card",
      padding = 12,
      title = 18,
      titleX = 2,
      upper = false,
      color = "heading",
      font = "normal",
      frame = "SMALL",
    },
    list = {
      selected = "selected",
      selectedAlpha = 0.5,
      rowBrick = "list",
    },
    scroll = {
      brick = "default",
      width = 6,
      thumb = 40,
      step = 40,
      trackAlpha = 1,
      arrowUp = "^",
      arrowDown = "v",
      arrowPad = 0,
    },
    cells = {
      shape = "bevel",
    },
    queue = {
      shape = "bevel",
      radius = 0,
      gap = 1,
      pill = {
        height = 16,
        pad = 6,
      },
      dot = {
        size = 8,
      },
      bar = {
        width = 60,
        height = 8,
      },
      range = {
        width = 80,
      },
      ring = {
        size = 36,
        compact = 22,
        color = "success",
      },
      counter = {
        size = 29,
      },
      band = {
        label = {
          size = 10.5,
        },
        value = {
          size = 20,
        },
        sub1 = {
          size = 11.5,
        },
        sub2 = {
          size = 10.5,
        },
      },
      group = {
        headHeight = 34,
        rowHeight = 24,
        headBg = "card",
        headEdge = "borderDim",
        bodyBg = "bgSoft",
        edgeAlpha = 1,
        guide = false,
      },
      table = {
        row = 28,
        style = "line",
        gap = 0,
      },
    },
    strip = {
      shape = "bevel",
      label = 84,
      height = 26,
      gap = 6,
      tile = 74,
    },
    cards = {
      shape = "bevel",
      gap = 6,
      pad = 8,
    },
  },
  kit = {
    quality = {
      ["0"] = 0x9D9D9D,
      ["1"] = 0xFFFFFF,
      ["2"] = 0x1EFF00,
      ["3"] = 0x0070DD,
      ["4"] = 0xA335EE,
      ["5"] = 0xFF8000,
      ["6"] = 0xE6CC80,
    },
    category = {
      offensive = 0xE05A4E,
      defensive = 0x4A9BE0,
      resource = 0x4CC26A,
      utility = 0xF08A28,
      mobility = 0xB06AE0,
    },
    affix = {
      equipped = 0x4DC26B,
      none = 0x808080,
    },
    padding = 8,
    followLevel = 1,
    followAbove = true,
    followLevelInside = 40,
    followLevelBase = 40,
    releaseLevel = 1,
    spacing = 6,
    inset = 4,
    gap = 2,
    columns = 4,
    wrap = 320,
    text = {
      font = "small",
    },
    bar = {
      color = "card",
      border = "borderDim",
    },
    header = 30,
    control = 22,
    icon = {
      size = 32,
      inset = 2,
      trim = 0.08,
      color = "checkbox",
      border = "buttonBorder",
      hover = "buttonHover",
      checked = "checked",
    },
    badge = {
      size = 14,
      level = 3,
      color = "focus",
      text = "selectedText",
    },
    band = {
      height = 22,
      alpha = 0.35,
      text = "text",
    },
    tag = {
      color = "borderDim",
      text = "text",
      font = "small",
      padding = 8,
    },
    questlog = {
      check = 18,
    },
    progress = {
      height = 14,
      color = "checked",
      background = "bgSoft",
      border = "borderDim",
    },
    row = 20,
    rows = {
      action = 18,
      fill = "checked",
      fillAlpha = 0.3,
      mark = "danger",
      markAlpha = 0.2,
      suffix = "muted",
      medium = {
        height = 24,
        font = "normal",
      },
      large = {
        height = 30,
        font = "large",
      },
    },
    slot = 24,
    indent = 12,
    list = 200,
    collection = {
      color = "bgSoft",
      border = "borderDim",
      padding = 4,
    },
    scroll = {
      width = 320,
      height = 240,
    },
    table = {
      row = 18,
      sort = 8,
      column = 20,
      selected = "selected",
      hover = "rowHover",
      indent = 14,
      bar = {
        height = 6,
        fill = "checked",
        back = "bgSoft",
      },
      group = {
        fill = "card",
        chevron = "text",
      },
    },
    toast = {
      width = 260,
      duration = 4,
      top = 120,
      icon = 24,
      fade = 0.5,
    },
    problem = {
      alert = {
        width = 300,
        max = 3,
        color = "bgSoft",
      },
      discreet = {
        duration = 6,
        quiet = 60,
      },
    },
    drag = 12,
    ghost = {
      width = 170,
      color = "selected",
      border = "focus",
    },
    handle = 12,
    dot = {
      color = "thumb",
      hover = "buttonHover",
    },
    pointer = 48,
    aim = {
      every = 0.05,
    },
    timer = {
      every = 0.1,
      font = "small",
    },
    chart = {
      color = "checked",
      height = 60,
      background = "bgSoft",
      border = "borderDim",
      column = "bgSoft",
      label = "muted",
      value = "text",
      font = "small",
      series = {
        s1 = 0xFFD100,
        s2 = 0x0070DD,
        s3 = 0xA335EE,
        s4 = 0x1EFF00,
        s5 = 0xFF8000,
      },
      others = 0x9D9D9D,
      line = 14,
    },
    dialog = {
      width = 320,
      copy = 80,
      button = 80,
      choices = 6,
      offset = 120,
      field = {
        color = "bgSoft",
        border = "borderDim",
      },
      title = {
        font = "normal",
        color = "heading",
        align = "CENTER",
      },
      wide = 440,
      rich = {
        padding = 16,
        spacing = 10,
        title = {
          font = "large",
          color = "heading",
          align = "LEFT",
        },
        text = {
          font = "small",
          color = "muted",
          align = "LEFT",
        },
      },
      danger = {
        color = "danger",
        border = "danger",
      },
    },
    minimap = {
      brick = "native",
      size = 31,
      inset = 4,
      ring = 2,
      offset = 10,
      corner = 10,
      angle = 225,
      group = {
        angle = 245,
        columns = 4,
      },
    },
    model = {
      width = 160,
      height = 220,
      turn = 0.02,
      zoom = {
        step = 0.25,
        min = -1,
        max = 3,
      },
    },
    combatAlpha = 0.3,
    animation = 0.15,
    rescale = {
      delay = 0.01,
    },
  },
  tree = {
    stack = {
      levelStep = 1,
      compact = 500,
    },
    frames = {
      enabled = false,
    },
    piece = {
      fill = "bg",
      frame = "LARGE",
      panel = "FLAT",
      bar = "FLAT",
      scroll = "FLAT",
      slot = "SMALL",
      barBorder = "bg",
    },
    title = {
      top = -10,
      margin = 60,
      drop = -5,
    },
    bottom = {
      height = 40,
      fill = "bgSoft",
      border = "borderDim",
      edge = 0,
      frame = "FLAT",
    },
    search = {
      hide = false,
    },
    tab = {
      trim = 18,
    },
    gauge = {
      text = 0xE6DDD0,
      outline = "OUTLINE",
      shadow = 0x000000,
      shadowAlpha = 1,
      shadowX = 1,
      shadowY = -1,
    },
    button = {
      fill = "button",
      border = "buttonBorder",
      frame = "SMALL",
    },
    banner = {
      fill = "bg",
      border = "danger",
      frame = "FLAT",
    },
    paper = {
      fill = "bg",
      border = "border",
      frame = "FLAT",
    },
    prestige = {
      circleFrame = "LARGE",
      animation = "coeur",
      fill = "bg",
      border = "border",
      barFill = "selected",
      barDesaturate = true,
      previewFill = "",
      text = "",
    },
    dense = {
      pad = 4,
      gap = 4,
      zoomMargin = 8,
      hubSize = 96,
      hubMax = 12,
      hubAuraMargin = 1.25,
      hubAuraOwn = 0.45,
      hubAuraOther = 0.16,
      hubIconScale = 0.94,
      hubRingScale = 1.12,
      hubRadius = 400,
      hubKey = "heading",
      centerIcon = "Interface\\AddOns\\ProjectEbonhold\\modules\\collections\\Interface\\Icons\\INV_7xp_Inscription_TalentTome01",
      centerGlow = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
      hubAura = "Interface\\AddOns\\ProjectEbonhold\\assets\\class_aura",
      hubRing = "Interface\\AddOns\\ProjectEbonhold\\assets\\class_ring",
      nodeHaloTex = "Interface\\Buttons\\WHITE8x8",
      normalHaloTex = "Interface\\AddOns\\ProjectEbonhold\\assets\\class_ring_glow",
      hubIcon = "Interface\\TargetingFrame\\UI-Classes-Circles",
      currencyAsh = "Interface\\Icons\\inv_soulash",
      currencyShard = "Interface\\Icons\\inv_10_jewelcrafting3_soulcage_frost",
      currencyEssence = "Interface\\Icons\\inv_misc_supersoulash",
      currencyArtisan = "Interface\\Icons\\ability_argus_soulbombdebufflarge",
      nodePx = 2,
      hubPx = 4,
      maxDots = 8,
      dotStep = 3,
      dotMin = 1.5,
      linkKey = "borderDim",
      linkLitKey = "success",
      stateActive = "success",
      stateReady = "heading",
      stateNopoints = "caution",
      stateLocked = "borderDim",
      stateUnknown = "muted",
      mapLinkLitKey = "heading",
      pendingAlpha = 0.55,
      haloAlpha = 0.8,
      normalHaloAlpha = 1,
      minimapIdleAlpha = 1,
      lockedAlpha = 0.6,
      fillKey = "bgSoft",
      fillLockedAlpha = 0.5,
      iconMinPx = 16,
      noticeHeight = 20,
      slotWidth = 240,
      tipIcon = 16,
      tipColor = 0xFFD100,
      dotSize = 1,
      minZoom = 0.09,
      maxZoom = 2,
      zoomStep = 1.12,
      defaultZoom = 0.6,
      textMinZoom = 0.45,
      nodeSize = 30,
      nodeMinPx = 3,
      borderPx = 1,
      presetGrow = 3,
      haloGrow = 2,
      nodeHaloGrow = 2,
      viewMargin = 24,
      linkPx = 2,
      linkLitPx = 2,
      linkTexStraight = "Interface\\Buttons\\WHITE8x8",
      linkTexTilted = "Interface\\AddOns\\ProjectEbonhold\\assets\\link_line",
      linkTexFactor = 1.0666666666667,
      presetKey = "danger",
      pendingKey = "caution",
      rankKey = "text",
      noticeKey = "caution",
      navTipFallback = 0xE6DDD0,
    },
    journal = {
      portraitSize = 78,
      portraitLeft = -14,
      portraitTop = 11,
      iconLeft = -6,
      portraitMargin = 2,
      ringColor = "",
      ringInset = 2,
      tabs = { "Echoes", "SkillTree", "Transmog", "Mounts", "Companions", "Prestige" },
      fadeAlpha = 0,
      height = 608,
      footerHeight = 36,
      footer = {
        SkillTree = { "skillTreeBottomBar" },
        Transmog = { "WardrobeTransmogFrame.ApplyButton" },
        Mounts = { "MountJournal.MountButton" },
        Companions = { "PetJournal.SummonButton" },
      },
    },
  },
  board = {
    dress = false,
    portrait = true,
    frame = "LARGE",
    color = "bg",
    border = "border",
    title = {
      font = "normal",
      color = "heading",
      align = "CENTER",
      x = 20,
      y = 15,
    },
    name = {
      font = "large",
      color = "text",
    },
    heading = {
      font = "normal",
      color = "text",
    },
    text = {
      font = "normal",
      color = "text",
    },
    note = {
      font = "small",
      color = "heading",
    },
    objective = {
      done = "muted",
    },
    header = {
      height = 20,
      font = "small",
      color = "heading",
      line = "heading",
      fold = 0.3,
      room = 8,
    },
    row = {
      height = 46,
      gap = 4,
      icon = 30,
      font = "normal",
    },
    panel = {
      color = "bgSoft",
      border = "borderDim",
    },
    strip = {
      color = "card",
      rule = "borderDim",
    },
    tab = {
      idle = "button",
      border = "buttonBorder",
      padding = 4,
    },
    button = {
      idle = "card",
    },
    art = {
      frame = true,
    },
    card = {
      brick = "default",
    },
    cardHeader = {
      brick = "default",
    },
    picture = {
      brick = "default",
    },
    slot = {
      brick = "default",
    },
    pe = {
      row = 46,
      gap = 4,
      head = 20,
      portrait = {
        size = 60,
        left = 7,
        top = -6,
        inset = 2,
      },
      star = {
        size = 14,
        x = 6,
        y = 3,
        color = "heading",
      },
      toggle = {
        size = 14,
        x = 2,
        y = 2,
        color = "heading",
        open = "-",
        close = "+",
      },
      frame = {
        margin = 10,
      },
    },
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
  saves = {
    hoverMarginAdd = 0,
  },
  journal = {
    tab = {
      seat = {
        leftAdd = 0,
        topAdd = 0,
        rightAdd = 0,
        bottomAdd = 0,
      },
      textPadAdd = 0,
    },
    title = {
      gapAdd = 0,
    },
  },
  bricks = {
    bare = { default = builtin("bare", "default") },
    button = { braise = braise },
    card = { default = builtin("card", "default") },
    cardHeader = { default = builtin("cardHeader", "default") },
    choice = { default = builtin("choice", "default") },
    color = { default = builtin("color", "default") },
    counter = { default = builtin("counter", "default") },
    execute = { braise = braise },
    group = { card = builtin("group", "card") },
    heading = { default = builtin("heading", "default") },
    map = { default = builtin("map", "default") },
    miniview = { default = builtin("miniview", "default") },
    picture = { default = builtin("picture", "default") },
    pill = { default = builtin("pill", "default") },
    reset = { close = builtin("reset", "close") },
    round = { default = builtin("round", "default") },
    row = { list = rowBrick },
    tab = { onglet = tabBrick },
    toggle = { case = caseBrick },
    range = { curseur = curseurBrick },
    input = { champ = champBrick },
    saves = { default = builtin("saves", "default") },
    scroll = { default = scrollBrick },
    section = { default = sectionBrick },
    select = { default = selectBrick },
    slot = { default = builtin("slot", "default") },
    stacked = { default = builtin("stacked", "default") },
    text = { default = builtin("text", "default") },
    tile = { default = builtin("tile", "default") },
    tipcard = { default = builtin("tipcard", "default") },
    zoom = { default = builtin("zoom", "default") },
  },
})
