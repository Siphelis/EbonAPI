local Lib = EbonAPI.Lib
EbonAPI:RegisterSkin("VSCode", {
  tree = {
    paper = { fill = "pageBg" },
    -- Neutral values of the Azeroth-only tokens.
    tab = { trim = 0 },
    -- Native blue art of the Prestige bar.
    prestige = { animation = "saut", circleFrame = "LARGE", border = "border", barFill = "", barDesaturate = false },
    journal = {
      ringColor = "border",
    },
    dense = {
minimapIdleAlpha = 0.45,
    },
  },

  background = 0x1F1F1F,
  accent = 0x0078D4,
  opacity = 1,
  shadow = 0.35,
  corners = 6,
  tabs = "RIGHT",

  palette = {
    bg = 0x181818,
    bgSoft = 0x313131,
    card = 0x181818,
    border = 0x2B2B2B,
    borderDim = 0x3C3C3C,
    button = 0x313131,
    buttonBorder = 0x3C3C3C,
    buttonHover = 0x0078D4,
    buttonHoverFill = 0x3C3C3C,
    buttonDisabledBorder = { 0x3C3C3C, 0.5 },
    buttonText = 0xCCCCCC,
    buttonDisabledText = { 0xCCCCCC, 0.5 },
    checkbox = 0x313131,
    checkboxBorder = 0x6B6B6B,
    checked = 0xCCCCCC,
    thumb = { 0x797979, 0.4 },
    selected = 0x04395E,
    selectedText = 0xFFFFFF,
    text = 0xCCCCCC,
    title = 0xFFFFFF,
    heading = 0xE7E7E7,
    menu = 0x0078D4,
    focus = 0x0078D4,
    rowHover = 0x2A2D2E,
    headerBg = { 0x181818, 0 },
    navBg = 0x1F1F1F,
    pageBg = 0x1F1F1F,
    footerBg = { 0x181818, 0 },
    muted = { 0xFFFFFF, 0.78 },
    success = 0x89D185,
    caution = 0xD18616,
  },

  fonts = {
    small = { file = "Fonts\\ARIALN.TTF", size = 11 },
    normal = { file = "Fonts\\ARIALN.TTF" },
    large = { file = "Fonts\\ARIALN.TTF", size = 18 },
    button = { file = "Fonts\\ARIALN.TTF", size = 12, outline = "NONE" },
    shadow = { alpha = 0 },
  },

  border = {
    style = "ROUND",
    large = {
      background = "Interface\\Buttons\\WHITE8X8", edge = "Interface\\Tooltips\\UI-Tooltip-Border",
      size = 16, inset = 4, tile = 0,
    },
    small = { background = "Interface\\Buttons\\WHITE8X8", size = 10, inset = 2, tile = 0 },
    round = { small = 6 },
  },

  window = {
    padding = 5,
    spacing = 5,
    shadow = { base = 6, spread = 16, alphaBase = 0.2, alphaSpread = 0.4, y = -2 },
  },

  header = {
    height = 30,
    inset = -5,
    spacing = 0,
    title = { x = 8, y = 9, align = "SIDE", font = "normal", color = "text" },
    banner = { texture = "", width = 256, height = 30, y = 0, pad = 8, titleY = 2 },
    version = { show = true, gap = 6, y = 0 },
    search = { position = "CENTER", width = 300, height = 20, insetY = 1, inset = 8 },
    close = { brick = "flat", size = 30, width = 40, y = 0, glyph = "×" },
    minimize = { show = true, width = 40, glyph = "—" },
    sidebar = { show = true, size = 14, width = 24 },
    history = { show = true, back = "<", forward = ">", width = 24 },
    rule = { show = false },
  },

  footer = {
    show = true,
    rule = false,
    badge = { show = true },
    items = true,
    gap = 12,
  },

  nav = {
    width = 220,
    inset = 0,
    padding = 6,
    frame = "LARGE",
    rail = { show = true, gap = 5, spacing = 6, dim = 0.55 },
    tree = { collapsible = true, guides = true },
    section = { x = 8, height = 26, color = "text", font = "normal" },
    tab = { brick = "list", height = 22, gap = 0, align = "LEFT", font = "normal", padding = 20 },
  },

  page = {
    width = 640,
    height = 540,
    gutter = 12,
    top = 40,
    frame = "LARGE",
    close = { size = 30, width = 40, glyph = "×" },
    inset = { x = 22, y = 10 },
    title = { y = 0, color = "title" },
    description = { color = "muted", gap = 4, below = 2 },
    unit = 240,
    gap = { x = 12, y = 16 },
    layout = "LIST",
    descriptions = "INLINE",
    strip = { show = true, height = 30, tabs = 6, color = "card", idle = "card", separator = "border" },
    crumbs = { show = true, height = 22, separator = "›" },
  },

  widgets = {
    cells = { shape = "square" }, queue = { shape = "square", table = { style = "flat" } }, strip = { shape = "square" }, cards = { shape = "flat" },
    tooltip = { skinned = true },
    button = { brick = "default", padding = 10 },
    execute = { brick = "default", height = 24 },
    input = { brick = "default", field = 22 },
    toggle = {
      brick = "box", height = 20, size = 14, gap = 8, mark = -3,
      markTexture = "Interface\\Buttons\\UI-CheckBox-Check",
    },
    range = {
      brick = "default", height = 46, top = 16, bar = 12, track = 2, fill = true, fillColor = "focus",
      thumb = { width = 6, height = 12 },
      edit = { width = 50, height = 18 },
    },
    select = { height = 40, arrow = { gray = true } },
    menu = { brick = "list", color = "bg", gap = 0, padding = 2, inset = 10, title = { align = "LEFT" }, native = { border = "border", separator = "border" } },
    heading = { lines = "NONE", color = "title", height = 26 },
    group = { brick = "plain", padding = 0, title = 22, titleX = 0, color = "title", frame = "FLAT" },
    scroll = { width = 8, thumb = 30, trackAlpha = 0 },
    synthesis = { brick = "barItems", tile = { width = 210 } },
    -- Saves: flat list; the transparent palette key stands for "no fill, no border".
    saves = {
      view = "list", cell = { frame = "SMALL" },
      row = { frame = "FLAT", fill = "headerBg", border = "headerBg" },
      -- Presets: small square flat markers, like the status-bar items.
      dot = { border = "borderDim" },
      coin = { border = "borderDim" },
    },
    choice = {
      segment = { frame = "FLAT", fill = "bgSoft", border = "borderDim" },
      chips = { frame = "FLAT", fill = "bgSoft", border = "borderDim", count = "heading" },
    },
    pill = { frame = "FLAT", fill = "bgSoft", border = "borderDim", info = "focus" },
    tile = {
      frame = "FLAT", fill = "card", accent = "focus", border = "border",
      gauge = { fill = "focus",},
    },
    map = { border = "border", accent = { fill = "buttonHover" }, gray = { high = "muted" } },
  },

  bricks = {
    -- The summary tiles as status-bar items: one line each (level marker, label, value), laid out one after the
    -- other in a flat row with a 1 px vertical separator on the right of every item except the last of its row.
    -- The row wraps when the next item does not fit; an item is never wider than the box. The sub-text is only
    -- in the tooltip. The selected item is a plain fill of the selection key.
    synthesis = {
      barItems = function(parent, B)
        local Tiles = EbonAPI.Tiles
        local MARGIN, SPACE = 4, 4
        local look = {}

        local labelRole, valueRole, selected = EbonAPI.Skins.synthesisRoles(B)

        -- The marker sits on the line of the text, centred in the height of the item.
        local function placeMarker(tile)
          local marker = tile.marker

          Tiles.paintMarker(tile, tile.markerSide or 1)

          if marker:IsShown() then
            local inset = B.insetOf(tile.frame)
            local inner = tile.frame:GetHeight() - 2 * inset
            local side = tile.markerSide or 1

            marker:ClearAllPoints()
            marker:SetPoint("TOPLEFT", tile.frame, "TOPLEFT", inset + MARGIN + math.floor((side - marker:GetWidth()) / 2),
              -(inset + math.floor((inner - marker:GetHeight()) / 2)))
          end
        end

        local function paintFrame(box, tile)
          local key = Tiles.borderKey(box, tile)
          local fill = selected(box, tile) and B.value("widgets.synthesis.selected") or B.value("widgets.synthesis.fill")

          if key ~= tile.border or fill ~= tile.fillKey then
            B.frame(tile.frame, "flat", fill, key)
            tile.border = key
            tile.fillKey = fill
          end
        end

        local function paintLook(box, tile)
          paintFrame(box, tile)
          B.paint(tile.label, "SetTextColor", "text")
          B.paint(tile.value, "SetTextColor", selected(box, tile) and "text" or "muted")
          B.paint(tile.sep, "SetVertexColor", "borderDim")
          placeMarker(tile)
          Tiles.setTip(tile)
        end

        function look.new(box)
          local frame = CreateFrame("Button", nil, box)
          local tile = { frame = frame, lookName = "barItems", margin = MARGIN }

          Tiles.wire(box, tile)
          tile.marker = frame:CreateTexture(nil, "OVERLAY")
          tile.sep = frame:CreateTexture(nil, "OVERLAY")
          tile.sep:SetTexture(B.media("solid"))
          tile.label = B.text(frame, labelRole(), "text")
          tile.label:SetJustifyH("LEFT")
          tile.label:SetJustifyV("MIDDLE")
          EbonAPI.Tiles.wrap(tile.label, false)
          tile.value = B.text(frame, valueRole(), "muted")
          tile.value:SetJustifyH("LEFT")
          tile.value:SetJustifyV("MIDDLE")
          EbonAPI.Tiles.wrap(tile.value, false)
          -- the sub-text is never drawn: it carries the full text of the item for the readers of the tile
          tile.sub = B.text(frame, labelRole(), "muted")
          tile.sub:Hide()

          return tile
        end

        -- One line of text and a margin above and below.
        function look.height(box)
          return math.max(math.ceil(B.value("fonts." .. labelRole() .. ".size")),
            math.ceil(B.value("fonts." .. valueRole() .. ".size"))) + 2 * MARGIN
        end

        -- Paints and sizes one item: width is the room of the box, the item takes its measured width.
        function look.paint(box, tile, width, height)
          local frame = tile.frame
          local item = tile.item
          local lr, vr = labelRole(), valueRole()

          tile.border = nil
          paintFrame(box, tile)
          B.font(tile.label, lr)
          B.font(tile.value, vr)
          B.font(tile.sub, lr)
          tile.label:SetText(item.label or "")
          tile.value:SetText(item.value or "")
          tile.sub:SetText(item.sub or "")
          EbonAPI.Tiles.wrap(tile.label, false)
          EbonAPI.Tiles.wrap(tile.value, false)
          tile.label:SetWidth(4096)
          tile.value:SetWidth(4096)

          local inset = B.insetOf(frame)
          local inner = math.max(1, height - 2 * inset)
          local side = math.ceil(B.value("fonts." .. lr .. ".size"))
          local lw = math.ceil(tile.label:GetStringWidth() or 0)
          local vw = (item.value ~= nil and item.value ~= "") and math.ceil(tile.value:GetStringWidth() or 0) or 0
          local ll = math.min(Tiles.lineHeight(tile.label, lr), inner)
          local vl = math.min(Tiles.lineHeight(tile.value, vr), inner)

          frame:SetHeight(height)
          tile.markerSide = side
          paintLook(box, tile)

          local left = inset + MARGIN + (tile.marker:IsShown() and side + SPACE or 0)
          local want = left + lw + (vw > 0 and SPACE + vw or 0) + MARGIN + inset
          local total = math.min(width, want)
          local room = total - left - MARGIN - inset
          local labelWidth = math.max(1, math.min(lw, room))
          local rest = room - labelWidth - SPACE

          frame:SetWidth(total)
          tile.label:ClearAllPoints()
          tile.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -(inset + math.floor((inner - ll) / 2)))
          tile.label:SetWidth(labelWidth)
          tile.label:SetHeight(ll)
          tile.value:ClearAllPoints()
          tile.value:SetPoint("TOPLEFT", frame, "TOPLEFT", left + labelWidth + SPACE, -(inset + math.floor((inner - vl) / 2)))
          tile.value:SetWidth(math.max(1, math.min(vw, rest)))
          tile.value:SetHeight(vl)

          Lib.setShown(tile.value, vw > 0 and rest >= 4)

          tile.sep:ClearAllPoints()
          tile.sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
          tile.sep:SetWidth(1)
          tile.sep:SetHeight(inner)
        end

        -- Hook of the four-line card of the send-queue band: the separator would cover the right border of the card.
        function look.card(tile)
          tile.sep:Hide()
        end

        -- A text or a marker slot that changes the width of the item lays the flow out again (nothing is created).
        function look.update(box, tile, old)
          local item = tile.item

          if item.label ~= old.label or item.value ~= old.value or (item.level == nil) ~= (old.level == nil) then
            box:Refresh()

            return
          end

          tile.sub:SetText(item.sub or "")
          paintLook(box, tile)
        end

        -- The flow: items one after the other without a gap, the row wraps when the next one does not fit.
        function look.layout(box)
          local width = math.max(1, box.boxWidth)
          local gap = B.value("widgets.synthesis.gap")
          local th = box.look.height(box)
          local role = labelRole()
          local y = 0

          for index, group in ipairs(box.groups or {}) do
            local lh = EbonAPI.Skins.groupLabel(B, box, index, group.label or "", role, width, y)

            y = y + lh + gap

            local x, row, previous = 0, 0, nil

            for _, tile in ipairs(group.tiles) do
              box.look.paint(box, tile, width, th)

              local w = tile.frame:GetWidth()

              if x > 0 and x + w > width + 0.01 then
                x = 0
                row = row + 1

                if previous then
                  previous.sep:Hide()
                end
              end

              tile.frame:ClearAllPoints()
              tile.frame:SetPoint("TOPLEFT", box, "TOPLEFT", x, -(y + row * th))
              tile.frame:Show()
              tile.sep:Show()
              x = x + w
              previous = tile
            end

            if previous then
              previous.sep:Hide()
            end

            local rows = #group.tiles > 0 and row + 1 or 0

            y = y + rows * th

            if index < #box.groups then
              y = y + gap
            end
          end

          return EbonAPI.Skins.finishLayout(box, y)
        end

        return Tiles.build(parent, look)
      end,
    },

  },

  chat = {
    prefix = 0x0078D4,
    text = 0xCCCCCC,
    muted = 0x9D9D9D,
  },

  kit = {
    followAbove = false,
    problem = { alert = { color = "bg" } },
    -- D1 (A99.T97): progress bars (Skill Tree gauge) in the blue of the skin, edge = back key (no frame).
    progress = { color = "focus", border = "bgSoft" },
    chart = { series = { s1 = 0x0078D4, s2 = 0xB180D7, s3 = 0xCCA700, s4 = 0x89D185, s5 = 0xD18616 }, others = 0x9D9D9D },
    table = {
      bar = { fill = "focus",},
      group = { fill = "bgSoft", chevron = "title" },
    },
  },

  board = {
    tab = { idle = "card", border = "card" },
    dress = true,
    portrait = false,
    title = { align = "SIDE", x = 12, y = 9, font = "normal", color = "text" },
    name = { color = "title" },
    heading = { color = "title" },
    header = { height = 22, color = "text", line = "border" },
    note = { color = "muted" },
    row = { height = 40, gap = 2 },
    strip = { color = "pageBg", rule = "border" },
  },
})
