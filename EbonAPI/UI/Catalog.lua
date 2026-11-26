EbonAPI = EbonAPI or {}
EbonAPI.Catalog = {}

local Catalog = EbonAPI.Catalog
local Lib = EbonAPI.Lib

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local format, concat, sub, len = string.format, table.concat, string.sub, string.len
local floor = math.floor

local COLOR_MAX = 0xFFFFFF

local STRATA = {
  BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
  FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true,
}
-- R7d
Catalog.strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local OUTLINE = { NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true }
local AUTO_OUTLINE = { AUTO = true, NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROME = true }
local SIDE = { LEFT = true, RIGHT = true }
local ALIGN = { LEFT = true, CENTER = true, RIGHT = true }
local GRADIENT = { NONE = true, VERTICAL = true, HORIZONTAL = true }
local LINES = { BOTH = true, AFTER = true, NONE = true }
local ANCHOR = {
  ANCHOR_RIGHT = true, ANCHOR_LEFT = true, ANCHOR_TOPRIGHT = true, ANCHOR_TOPLEFT = true,
  ANCHOR_BOTTOMRIGHT = true, ANCHOR_BOTTOMLEFT = true, ANCHOR_CURSOR = true,
}

local PALETTE = {
  "bg", "bgSoft", "card", "border", "borderDim", "button", "buttonBorder", "buttonHover",
  "buttonDisabledBorder", "buttonText", "buttonDisabledText", "checkbox", "checkboxBorder", "checked",
  "thumb", "selected", "selectedText", "text", "muted", "title", "heading", "menu", "shadow",
  "focus", "buttonHoverFill", "rowHover", "headerBg", "navBg", "pageBg", "footerBg", "menuBg", "success", "danger", "caution",
  "well",
}

local ROLES = { small = true, normal = true, large = true, button = true }
local PALETTE_SET = {}

for _, name in ipairs(PALETTE) do
  PALETTE_SET[name] = true
end

local LIST = {}

local function add(key, kind, fields)
  local entry = fields or {}

  entry.key, entry.kind = key, kind
  LIST[#LIST + 1] = entry
end

local function number(key, low, high)
  add(key, "number", { min = low, max = high })
end

local function whole(key, low, high)
  add(key, "number", { min = low, max = high, whole = true })
end

local function choice(key, values)
  add(key, "choice", { values = values })
end

local function brick(key, slot)
  add(key, "brick", { slot = slot })
end

add("background", "color", { player = true })
add("accent", "color", { player = true })
add("scale", "number", { player = true, min = 0.2, max = 1.4, step = 0.05, isPercent = true })
add("opacity", "number", { player = true, min = 0.25, max = 1, step = 0.01, isPercent = true })
add("shadow", "number", { player = true, min = 0, max = 1, step = 0.05, isPercent = true })
add("corners", "number", { player = true, min = 0, max = 16, whole = true, step = 1 })
add("tabs", "choice", { player = true, values = SIDE })
add("locked", "boolean", { player = true })

for _, name in ipairs(PALETTE) do
  add("palette." .. name, "rgba", { palette = name })
end

number("contrast.minimum", 1, 21)
add("contrast.enforce", "boolean")
number("contrast.light", 0, 1)
number("contrast.dark", 0, 1)
number("contrast.step", 0.01, 1)
whole("contrast.attempts", 1, 200)
number("contrast.mutedStep", 0.01, 1)

for _, role in ipairs({ "small", "normal", "large", "button" }) do
  add("fonts." .. role .. ".file", "font")
  whole("fonts." .. role .. ".size", 6, 40)
  choice("fonts." .. role .. ".outline", role == "button" and AUTO_OUTLINE or OUTLINE)
end

number("fonts.shadow.x", -4, 4)
number("fonts.shadow.y", -4, 4)
add("fonts.shadow.color", "color")
number("fonts.shadow.alpha", 0, 1)

add("media.solid", "texture")
add("media.rounded", "texture")
add("media.arrow", "texture")
add("media.shadow", "texture")
add("media.grain", "texture")
add("media.circle", "texture")
add("media.chevron", "texture")
add("media.ring", "texture")
add("media.icons", "texture")
add("media.sidebar", "texture")
add("media.error", "texture")
add("media.warning", "texture")
add("media.icon", "texture")
add("media.addonIcon", "texture")
add("media.pointer", "texture")
add("media.rosace", "texture")

whole("border.size", 1, 8)
whole("border.round.base", 0, 32)
whole("border.round.small", 2, 64)
number("border.round.inset", 0, 0.5)
choice("border.style", { ROUND = true, TEXTURE = true })

for _, size in ipairs({ "large", "small" }) do
  add("border." .. size .. ".background", "texture")
  add("border." .. size .. ".edge", "texture")
  whole("border." .. size .. ".size", 1, 64)
  whole("border." .. size .. ".inset", 0, 32)
  whole("border." .. size .. ".tile", 0, 256)
end

whole("window.padding", 0, 60)
whole("window.spacing", 0, 60)
add("window.card.border", "key")
choice("window.strata", STRATA)
add("window.texture", "texture")
whole("window.textureTile", 0, 1024)
number("window.textureAlpha", 0, 1)
choice("window.gradient.orientation", GRADIENT)
add("window.gradient.color", "key")
number("window.gradient.from", 0, 1)
number("window.gradient.to", 0, 1)
number("window.shadow.base", 0, 64)
number("window.shadow.spread", 0, 64)
number("window.shadow.alphaBase", 0, 1)
number("window.shadow.alphaSpread", 0, 1)
number("window.shadow.x", -32, 32)
number("window.shadow.y", -32, 32)
whole("window.shadow.level", -8, 0)
add("window.shadow.attached", "boolean")
add("window.glass.enabled", "boolean")
add("window.glass.tint", "color")
number("window.glass.darken", 0, 1)
number("window.glass.milk", 0, 1)
number("window.glass.grain", 0, 1)
number("window.glass.sheen", 0, 1)
number("window.glass.sheenHeight", 0, 1)
number("window.glass.edge", 0, 1)
whole("window.glass.edgeSize", 1, 8)
number("window.fade", 0, 2)
add("window.sound.open", "sound")
add("window.sound.close", "sound")

add("windows.detach.header", "boolean")
add("windows.detach.nav", "boolean")
add("windows.detach.page", "boolean")
add("windows.detach.pages", "boolean")
add("windows.detach.list", "list")
whole("windows.gap", 0, 60)
whole("windows.snap", 0, 60)
whole("windows.cascade", 0, 120)

add("header.show", "boolean")
whole("header.height", 16, 160)
choice("header.controls", SIDE)
add("header.title.show", "boolean")
number("header.title.x", -60, 200)
number("header.title.y", -60, 160)
choice("header.title.align", { SIDE = true, CENTER = true })
add("header.title.color", "key")
add("header.title.font", "role")
add("header.banner.texture", "texture")
whole("header.banner.width", 16, 1024)
whole("header.banner.height", 8, 256)
number("header.banner.y", -100, 100)
whole("header.banner.pad", 0, 200)
number("header.banner.titleY", -100, 100)
add("header.version.show", "boolean")
number("header.version.gap", 0, 60)
number("header.version.y", -20, 20)
add("header.search.show", "boolean")
whole("header.search.width", 40, 600)
whole("header.search.height", 12, 60)
number("header.search.gap", 0, 60)
number("header.search.inset", 0, 30)
number("header.search.insetY", 0, 20)
choice("header.search.position", { CONTROLS = true, CENTER = true, OPPOSITE = true })
add("header.close.show", "boolean")
whole("header.close.size", 10, 60)
number("header.close.y", -60, 160)
brick("header.close.brick", "close")
brick("header.reset.brick", "reset")
whole("header.close.width", 10, 120)
add("header.close.glyph", "text")
add("header.close.hover", "color")
add("header.close.ink", "color")
number("header.inset", -60, 60)
whole("header.spacing", 0, 40)
add("header.history.show", "boolean")
add("header.history.back", "text")
add("header.history.forward", "text")
whole("header.history.width", 10, 80)
add("header.minimize.show", "boolean")
whole("header.minimize.width", 10, 120)
add("header.minimize.glyph", "text")
add("header.minimize.color", "color")
add("header.minimize.ink", "color")
add("header.zoom.glyph", "text")
add("header.zoom.color", "color")
add("header.zoom.ink", "color")
add("header.sidebar.show", "boolean")
whole("header.sidebar.size", 6, 40)
whole("header.sidebar.width", 10, 120)
add("header.rule.show", "boolean")
whole("header.rule.size", 1, 8)

add("footer.show", "boolean")
whole("footer.height", 8, 80)
add("footer.version", "boolean")
add("footer.rule", "boolean")
whole("footer.ruleSize", 1, 8)
number("footer.inset", -60, 60)
number("footer.refresh", 0.1, 60)
add("footer.badge.show", "boolean")
add("footer.badge.color", "key")
add("footer.badge.text", "key")
number("footer.badge.padding", 0, 40)
add("footer.items", "boolean")
whole("footer.gap", 0, 60)
whole("footer.icon", 6, 40)

whole("panel.button.width", 40, 600)
whole("panel.button.height", 16, 60)
number("panel.margin", 0, 60)
number("panel.gap", 0, 60)
number("gamemenu.gap", 0, 20)

whole("nav.width", 60, 500)
whole("nav.inset", 0, 40)
whole("nav.padding", 0, 60)
whole("nav.divider.size", 0, 8)
add("nav.divider.color", "key")
choice("nav.frame", { NONE = true, LARGE = true, SMALL = true })
add("nav.rail.show", "boolean")
whole("nav.rail.width", 16, 120)
whole("nav.rail.gap", 0, 40)
whole("nav.rail.icon", 8, 80)
whole("nav.rail.spacing", 0, 40)
whole("nav.rail.indicator", 0, 8)
add("nav.rail.color", "key")
number("nav.rail.crop", 0, 0.45)
add("nav.rail.indicatorColor", "key")
add("nav.rail.desaturate", "boolean")
number("nav.rail.dim", 0, 1)
add("nav.rail.filter", "boolean")
add("nav.tree.collapsible", "boolean")
add("nav.tree.expanded", "boolean")
add("nav.tree.guides", "boolean")
whole("nav.tree.chevron", 4, 40)
add("nav.tree.chevronColor", "key")
add("nav.tree.guideColor", "key")
whole("nav.tree.guideWidth", 1, 8)
whole("nav.tree.margin", 0, 20)
brick("nav.section.brick", "section")
add("nav.section.show", "boolean")
number("nav.section.x", -20, 60)
whole("nav.section.height", 8, 60)
whole("nav.section.before", 0, 60)
whole("nav.section.after", 0, 60)
add("nav.section.upper", "boolean")
add("nav.section.color", "key")
add("nav.section.font", "role")
brick("nav.tab.brick", "tab")
whole("nav.tab.height", 12, 80)
whole("nav.tab.gap", 0, 40)
whole("nav.tab.indent", 0, 80)
choice("nav.tab.align", ALIGN)
whole("nav.tab.bar", 1, 16)
add("nav.tab.font", "role")
number("nav.tab.padding", 0, 60)
number("nav.tab.glow.selected", 0, 1)
number("nav.tab.glow.hover", 0, 1)

whole("page.width", 200, 1600)
whole("page.height", 150, 1200)
whole("page.gutter", 0, 60)
whole("page.top", 0, 200)
add("page.title.show", "boolean")
number("page.title.y", -40, 40)
add("page.description.show", "boolean")
number("page.description.gap", 0, 40)
whole("page.unit", 60, 600)
whole("page.gap.x", 0, 80)
whole("page.gap.y", 0, 80)
choice("page.addons", { LIST = true, CARDS = true })
whole("page.inset.x", 0, 120)
whole("page.inset.y", 0, 120)
choice("page.layout", { FLOW = true, LIST = true })
choice("page.descriptions", { TOOLTIP = true, INLINE = true, BOTH = true })
number("page.description.below", 0, 40)
add("page.title.color", "key")
add("page.title.font", "role")
add("page.description.color", "key")
add("page.description.font", "role")
add("page.strip.show", "boolean")
whole("page.strip.height", 10, 80)
number("page.strip.padding", 0, 60)
whole("page.strip.border", 0, 8)
add("page.strip.color", "key")
add("page.strip.tab", "key")
add("page.strip.accent", "key")
add("page.strip.text", "key")
whole("page.strip.tabs", 1, 12)
add("page.strip.idle", "key")
add("page.strip.idleText", "key")
add("page.strip.separator", "key")
whole("page.strip.close", 0, 40)
add("page.strip.font", "role")
whole("page.strip.separatorWidth", 1, 8)
whole("page.close.size", 10, 60)
whole("page.close.width", 10, 120)
number("page.close.gap", 0, 60)
add("page.close.glyph", "text")
choice("page.frame", { NONE = true, LARGE = true, SMALL = true })
add("page.crumbs.show", "boolean")
whole("page.crumbs.height", 8, 60)
add("page.crumbs.separator", "text")
add("page.crumbs.color", "key")
add("page.crumbs.font", "role")

number("widgets.disabledAlpha", 0, 1)
choice("widgets.tooltip.anchor", ANCHOR)
add("widgets.tooltip.skinned", "boolean")

brick("widgets.button.brick", "button")
whole("widgets.button.height", 10, 80)
number("widgets.button.padding", 0, 40)

brick("widgets.execute.brick", "execute")
whole("widgets.execute.height", 10, 80)

brick("widgets.toggle.brick", "toggle")
whole("widgets.toggle.height", 10, 80)
whole("widgets.toggle.size", 6, 60)
number("widgets.toggle.mark", -16, 20)
add("widgets.toggle.markTexture", "texture")
add("widgets.toggle.roundKnob", "boolean")
add("widgets.toggle.knob", "key")
number("widgets.toggle.gap", 0, 40)
number("widgets.toggle.margin", 0, 40)
whole("widgets.toggle.switch.width", 10, 120)
whole("widgets.toggle.switch.height", 6, 60)

brick("widgets.range.brick", "range")
whole("widgets.range.height", 20, 160)
number("widgets.range.top", 0, 60)
whole("widgets.range.bar", 4, 60)
whole("widgets.range.track", 1, 30)
whole("widgets.range.thumb.width", 2, 60)
whole("widgets.range.thumb.height", 2, 60)
number("widgets.range.labels", 0, 30)
whole("widgets.range.edit.width", 20, 200)
whole("widgets.range.edit.height", 10, 60)
number("widgets.range.edit.y", 0, 30)
add("widgets.range.fill", "boolean")
add("widgets.range.fillColor", "key")
add("widgets.range.roundThumb", "boolean")

brick("widgets.select.brick", "select")
whole("widgets.select.height", 20, 160)
number("widgets.select.top", 0, 60)
number("widgets.select.padding", 0, 40)
whole("widgets.select.arrow.size", 4, 40)
number("widgets.select.arrow.right", 0, 60)
number("widgets.select.arrow.x", 0, 40)
number("widgets.select.arrow.y", -20, 20)
add("widgets.select.arrow.gray", "boolean")

whole("widgets.menu.row", 10, 60)
whole("widgets.menu.gap", 0, 20)
whole("widgets.menu.padding", 0, 30)
number("widgets.menu.inset", 0, 40)
number("widgets.menu.offset", -20, 40)
choice("widgets.menu.strata", STRATA)
brick("widgets.menu.brick", "row")
add("widgets.menu.title.font", "role")
add("widgets.menu.title.color", "key")
add("widgets.menu.color", "key")
choice("widgets.menu.title.align", ALIGN)
-- Replace: drop-down lists of the client (DropDownList1..3) opened from the Filter / weapon menus of the PE Collections tabs
add("widgets.menu.native.dress", "boolean")
add("widgets.menu.native.border", "key")
add("widgets.menu.native.text", "key")
add("widgets.menu.native.dim", "key")
add("widgets.menu.native.check", "key")
add("widgets.menu.native.arrow", "key")
add("widgets.menu.native.hover", "key")
add("widgets.menu.native.font", "role")
add("widgets.menu.native.checkGlyph", "text")
add("widgets.menu.native.arrowGlyph", "text")
add("widgets.menu.native.separator", "key")
whole("widgets.menu.native.markX", -20, 20)
whole("widgets.menu.native.markY", -20, 20)
whole("widgets.menu.native.levelBelow", 0, 20)

brick("widgets.color.brick", "color")
whole("widgets.color.height", 10, 80)
whole("widgets.color.size", 6, 60)
number("widgets.color.gap", 0, 40)
number("widgets.color.margin", 0, 40)

brick("widgets.input.brick", "input")
whole("widgets.input.height", 20, 160)
number("widgets.input.top", 0, 60)
whole("widgets.input.field", 10, 80)
number("widgets.input.padding", 0, 40)
number("widgets.input.paddingY", 0, 20)
whole("widgets.input.line", 8, 40)
whole("widgets.input.lines", 2, 30)
whole("widgets.input.linePad", 0, 40)
whole("widgets.input.bottom", 0, 40)
whole("widgets.input.gap", 0, 20)

add("widgets.checkBox.fill", "color")
add("widgets.echoTile.markColor", "color")
add("widgets.echoTile.stacksColor", "color")
add("widgets.echoTile.missingFill", "color")
add("widgets.echoTile.missingBorder", "color")
add("widgets.echoTile.round", "boolean")
add("widgets.echoTile.nameQualityColor", "boolean")
add("widgets.echoTile.disc.0", "texture")
add("widgets.echoTile.ring.0", "texture")
add("widgets.echoTile.disc.1", "texture")
add("widgets.echoTile.ring.1", "texture")
add("widgets.echoTile.disc.2", "texture")
add("widgets.echoTile.ring.2", "texture")
add("widgets.echoTile.disc.3", "texture")
add("widgets.echoTile.ring.3", "texture")
add("widgets.echoTile.book", "texture")
whole("widgets.echoTile.width", 20, 200)
whole("widgets.echoTile.height", 20, 300)
whole("widgets.echoTile.nameTop", 0, 200)
whole("widgets.echoTile.nameHeight", 8, 100)
number("widgets.echoTile.discScale", 0.5, 3)
number("widgets.echoTile.iconScale", 0.3, 2)
number("widgets.echoTile.ringScale", 0.5, 6)
number("widgets.echoTile.ringShift", -10, 10)
number("widgets.echoTile.markScale", 0.1, 1)
number("widgets.echoTile.bookScale", 0, 1)
number("widgets.echoTile.bookCorner", -6, 10)
add("widgets.buildCard.selectedFill", "color")
add("widgets.buildCard.empty", "color")
add("widgets.buildCard.avatar", "color")
add("widgets.buildCard.missing", "color")
add("widgets.buildCard.back", "color")
add("widgets.buildRow.neutral", "color")
add("widgets.buildRow.fillNormal", "color")
add("widgets.buildRow.fillSelected", "color")
add("widgets.buildRow.edgeNormal", "color")
add("widgets.buildRow.hole", "color")
add("widgets.buildRow.missing", "color")
add("widgets.railDisc.neutral", "color")
add("widgets.railDisc.empty", "color")

brick("widgets.heading.brick", "heading")
whole("widgets.heading.height", 10, 80)
number("widgets.heading.gap", 0, 60)
choice("widgets.heading.lines", LINES)
whole("widgets.heading.size", 1, 8)
add("widgets.heading.upper", "boolean")
add("widgets.heading.color", "key")

brick("widgets.text.brick", "text")
whole("widgets.text.extra", 0, 40)

brick("widgets.synthesis.brick", "synthesis")
whole("widgets.synthesis.tile.width", 80, 400)
whole("widgets.synthesis.tile.height", 30, 120)
whole("widgets.synthesis.gap", 0, 30)
add("widgets.synthesis.label.font", "role")
add("widgets.synthesis.value.font", "role")
add("widgets.synthesis.group.color", "key")
add("widgets.synthesis.fill", "key")
add("widgets.synthesis.border", "key")
add("widgets.synthesis.selected", "key")

local LOOK_FRAME = { LARGE = true, SMALL = true, FLAT = true }

brick("widgets.saves.brick", "saves")
add("widgets.saves.tiled", "boolean") -- true = the saves panel is laid out in tiles (read by the STAL module)
brick("widgets.stacked.brick", "stacked")
choice("widgets.saves.view", { list = true, grid = true, gauge = true })
choice("widgets.saves.detail", { inline = true, dock = true })
choice("widgets.saves.denseTipAnchor", ANCHOR)
number("widgets.saves.denseTipGap", -100, 100)
whole("widgets.saves.width", 160, 400)
number("widgets.saves.fold", 0, 2)
add("widgets.saves.font", "role")
add("widgets.saves.small.font", "role")
whole("widgets.saves.row.height", 20, 48)
whole("widgets.saves.row.gap", 0, 10)
choice("widgets.saves.row.frame", LOOK_FRAME)
add("widgets.saves.row.fill", "key")
add("widgets.saves.row.border", "key")
add("widgets.saves.row.hover", "key")
add("widgets.saves.row.selected", "key")
whole("widgets.saves.cell.size", 36, 80)
whole("widgets.saves.cell.gap", 0, 12)
choice("widgets.saves.cell.frame", LOOK_FRAME)
add("widgets.saves.cell.fill", "key")
choice("widgets.saves.group.frame", LOOK_FRAME)
add("widgets.saves.group.fill", "key")
add("widgets.saves.group.color", "key")
add("widgets.saves.group.upper", "boolean")
choice("widgets.saves.drawer.frame", LOOK_FRAME)
add("widgets.saves.drawer.fill", "key")
add("widgets.saves.drawer.border", "key")
add("widgets.saves.owned", "key")
whole("widgets.saves.dot.size", 4, 24)
add("widgets.saves.dot.border", "key")
whole("widgets.saves.coin.size", 4, 24)
add("widgets.saves.coin.border", "key")
add("widgets.saves.coin.line", "boolean")
whole("widgets.saves.metric.pad", 0, 20)
whole("widgets.saves.metric.inset", 0, 5)
whole("widgets.saves.metric.gap", 0, 20)
whole("widgets.saves.metric.iconSize", 4, 32)
whole("widgets.saves.metric.chevronSize", 4, 32)
whole("widgets.saves.metric.dotsWidth", 8, 40)
whole("widgets.saves.metric.stateTrim", 0, 12)
whole("widgets.saves.metric.stateShift", 0, 12)
whole("widgets.saves.metric.pctWidth", 16, 64)
whole("widgets.saves.metric.pctGap", 0, 12)
whole("widgets.saves.metric.menuReserve", 0, 40)
whole("widgets.saves.metric.checkReserve", 0, 30)
whole("widgets.saves.metric.slotInset", 0, 12)
whole("widgets.saves.metric.markLeft", 0, 40)
whole("widgets.saves.metric.dotTop", 0, 20)
whole("widgets.saves.metric.coinTop", 0, 20)
whole("widgets.saves.metric.nameTop", 0, 30)
whole("widgets.saves.metric.nameLines", 1, 6)
whole("widgets.saves.metric.miniBar", 1, 10)
whole("widgets.saves.metric.stripWidth", 1, 10)
whole("widgets.saves.metric.coinGap", 0, 20)
whole("widgets.saves.metric.doneWidth", 20, 120)
whole("widgets.saves.metric.toggleMin", 8, 60)
whole("widgets.saves.metric.cursorHeight", 8, 40)
whole("widgets.saves.metric.levelStep", 0, 5)
whole("widgets.saves.metric.listMargin", 0, 30)
number("widgets.saves.metric.doubleClick", 0.1, 2) -- seconds between two clicks counted as a double click
number("widgets.saves.metric.minBar", 0, 1) -- narrowest width of a progress bar, px
number("widgets.saves.metric.nodesShare", 0.1, 1) -- share of the drawer width given to the nodes text
number("widgets.saves.metric.restShare", 0.1, 1) -- share of the drawer width given to the remaining-cost text
add("widgets.saves.metric.percentSuffix", "text")
add("widgets.saves.metric.countSeparator", "text")
add("widgets.saves.metric.unknown", "text")

brick("widgets.choice.brick", "choice")
add("widgets.choice.font", "role")
whole("widgets.choice.segment.height", 16, 48)
whole("widgets.choice.segment.gap", 0, 10)
choice("widgets.choice.segment.frame", LOOK_FRAME)
add("widgets.choice.segment.fill", "key")
add("widgets.choice.segment.border", "key")
add("widgets.choice.segment.selected", "key")
whole("widgets.choice.chips.height", 14, 40)
whole("widgets.choice.chips.gap", 0, 12)
choice("widgets.choice.chips.frame", LOOK_FRAME)
add("widgets.choice.chips.fill", "key")
add("widgets.choice.chips.border", "key")
add("widgets.choice.chips.selected", "key")
add("widgets.choice.chips.count", "key")

brick("widgets.pill.brick", "pill")
whole("widgets.pill.height", 10, 32)
choice("widgets.pill.frame", LOOK_FRAME)
add("widgets.pill.font", "role")
add("widgets.pill.fill", "key")
add("widgets.pill.border", "key")
add("widgets.pill.ok", "key")
add("widgets.pill.warn", "key")
add("widgets.pill.bad", "key")
add("widgets.pill.info", "key")

brick("widgets.tile.brick", "tile")
whole("widgets.tile.width", 80, 400)
whole("widgets.tile.height", 30, 160)
choice("widgets.tile.frame", LOOK_FRAME)
add("widgets.tile.fill", "key")
add("widgets.tile.border", "key")
add("widgets.tile.accent", "key")
add("widgets.tile.label.font", "role")
add("widgets.tile.value.font", "role")
add("widgets.tile.sub.font", "role")
whole("widgets.tile.gauge.height", 2, 20)
add("widgets.tile.gauge.fill", "key")
add("widgets.tile.gauge.back", "key")
add("widgets.tile.gauge.warn", "key")
add("widgets.tile.gauge.bad", "key")

brick("widgets.bare.brick", "bare")
choice("widgets.bare.frame", LOOK_FRAME)
add("widgets.bare.fill", "key")
add("widgets.bare.border", "key")
whole("widgets.bare.borderSize", 0, 8)
brick("widgets.counter.brick", "counter")
whole("widgets.counter.height", 12, 48)
choice("widgets.counter.frame", LOOK_FRAME)
add("widgets.counter.fill", "key")
add("widgets.counter.font", "role")
add("widgets.counter.text", "key")
whole("widgets.counter.dot", 4, 24)
whole("widgets.counter.inset", 0, 12)
number("widgets.counter.trim", 0, 0.45)
add("widgets.counter.tint", "color")
add("widgets.counter.token.gold", "key")
add("widgets.counter.token.silver", "key")
add("widgets.counter.token.copper", "key")
add("widgets.counter.token.ash", "key")
add("widgets.counter.token.shard", "key")
add("widgets.counter.token.essence", "key")
add("widgets.counter.token.artisan", "key")
brick("widgets.round.brick", "round")
whole("widgets.round.size", 16, 64)
add("widgets.round.fill", "key")
add("widgets.round.border", "key")
add("widgets.round.activeFill", "key")
add("widgets.round.activeBorder", "key")
add("widgets.round.text", "key")
add("widgets.round.activeText", "key")
add("widgets.round.hover", "key")
brick("widgets.zoom.brick", "zoom")
whole("widgets.zoom.height", 14, 40)
whole("widgets.zoom.gap", 0, 16)
add("widgets.zoom.fill", "key")
add("widgets.zoom.border", "key")
add("widgets.zoom.text", "key")
add("widgets.zoom.button", "key")
brick("widgets.miniview.brick", "miniview")
whole("widgets.miniview.width", 60, 400)
whole("widgets.miniview.height", 40, 300)
add("widgets.miniview.fill", "key")
add("widgets.miniview.border", "key")
add("widgets.miniview.view", "key")
add("widgets.miniview.viewBorder", "key")
add("widgets.miniview.dot", "key")
number("widgets.miniview.viewAlpha", 0, 1)
add("widgets.miniview.showDot", "boolean")
brick("widgets.tipcard.brick", "tipcard")
choice("widgets.tipcard.frame", LOOK_FRAME)
add("widgets.tipcard.fill", "key")
add("widgets.tipcard.border", "key")
add("widgets.tipcard.title", "key")
add("widgets.tipcard.text", "key")
add("widgets.tipcard.muted", "key")
whole("widgets.tipcard.width", 120, 480)
whole("widgets.tipcard.padding", 2, 24)

brick("widgets.map.brick", "map")
whole("widgets.map.gap", 0, 8)
choice("widgets.map.frame", LOOK_FRAME)
add("widgets.map.border", "key")
add("widgets.map.label.font", "role")
whole("widgets.map.label.min", 16, 200)
add("widgets.map.accent.fill", "key")
add("widgets.map.gray.low", "key")
add("widgets.map.gray.high", "key")
add("widgets.saves.now", "key")
add("widgets.saves.later", "key")
whole("widgets.saves.ring.size", 12, 32)
whole("widgets.saves.ring.big", 24, 64)

brick("widgets.group.brick", "group")
whole("widgets.group.padding", 0, 60)
whole("widgets.group.title", 0, 80)
number("widgets.group.titleX", -20, 60)
add("widgets.group.upper", "boolean")
add("widgets.group.color", "key")
add("widgets.group.font", "role")
choice("widgets.group.frame", { LARGE = true, SMALL = true, FLAT = true })

add("widgets.list.selected", "key")
number("widgets.list.selectedAlpha", 0, 1)
-- S2 (A99.T6): brick of the rows that dress a native list (Replace); a transparent list row keeps the names readable
choice("widgets.list.rowBrick", { list = true, fill = true })
brick("widgets.scroll.brick", "scroll")
whole("widgets.scroll.width", 1, 40)
whole("widgets.scroll.thumb", 4, 200)
whole("widgets.scroll.step", 1, 400)
number("widgets.scroll.trackAlpha", 0, 1)
add("widgets.scroll.arrowUp", "text")
add("widgets.scroll.arrowDown", "text")
whole("widgets.scroll.arrowPad", 0, 40)

choice("widgets.cells.shape", { round = true, bevel = true, square = true })

choice("widgets.queue.shape", { round = true, bevel = true, square = true })
whole("widgets.queue.radius", 0, 16)
whole("widgets.queue.gap", 0, 20)
whole("widgets.queue.pill.height", 8, 40)
whole("widgets.queue.pill.pad", 0, 20)
whole("widgets.queue.dot.size", 4, 24)
whole("widgets.queue.bar.width", 20, 300)
whole("widgets.queue.bar.height", 2, 24)
whole("widgets.queue.range.width", 20, 300)
whole("widgets.queue.ring.size", 12, 96)
whole("widgets.queue.ring.compact", 12, 48)
whole("widgets.queue.counter.size", 12, 64)
number("widgets.queue.band.label.size", 6, 40)
number("widgets.queue.band.value.size", 6, 40)
number("widgets.queue.band.sub1.size", 6, 40)
number("widgets.queue.band.sub2.size", 6, 40)
add("widgets.queue.ring.color", "key")
whole("widgets.queue.group.headHeight", 16, 80)
whole("widgets.queue.group.rowHeight", 12, 60)
add("widgets.queue.group.headBg", "key")
add("widgets.queue.group.headEdge", "key")
add("widgets.queue.group.bodyBg", "key")
number("widgets.queue.group.edgeAlpha", 0, 1)
add("widgets.queue.group.guide", "boolean")
whole("widgets.queue.table.row", 10, 80)
choice("widgets.queue.table.style", { line = true, plain = true, pill = true, card = true, zebra = true, flat = true })
whole("widgets.queue.table.gap", 0, 12)

choice("widgets.strip.shape", { square = true, bevel = true, round = true, pill = true, flat = true })
whole("widgets.strip.label", 20, 300)
whole("widgets.strip.height", 10, 80)
whole("widgets.strip.gap", 0, 30)
whole("widgets.strip.tile", 20, 300)

choice("widgets.cards.shape", { square = true, bevel = true, round = true, pill = true, flat = true, line = true })
whole("widgets.cards.gap", 0, 30)
whole("widgets.cards.pad", 0, 30)

add("kit.quality.0", "color")
add("kit.quality.1", "color")
add("kit.quality.2", "color")
add("kit.quality.3", "color")
add("kit.quality.4", "color")
add("kit.quality.5", "color")
add("kit.quality.6", "color")
add("kit.category.offensive", "color")
add("kit.category.defensive", "color")
add("kit.category.resource", "color")
add("kit.category.utility", "color")
add("kit.category.mobility", "color")
add("kit.affix.equipped", "color")
add("kit.affix.none", "color")

whole("kit.padding", 0, 40)
whole("kit.followLevel", 0, 100)
add("kit.followAbove", "boolean")
whole("kit.followLevelInside", 0, 200)
whole("kit.followLevelBase", 0, 200)
whole("kit.releaseLevel", 0, 20)
whole("tree.stack.levelStep", 0, 5) -- frame levels the tree chrome, surface and bottom frame sit above the native frame
-- R7g: frame levels of waste tolerated between the lowest and the highest window before the order is packed again
whole("tree.stack.compact", 10, 10000)
whole("kit.spacing", 0, 40)
whole("kit.inset", 0, 20)
whole("kit.gap", 0, 20)
whole("kit.columns", 1, 20)
whole("kit.wrap", 40, 2000)
add("kit.text.font", "role")
add("kit.bar.color", "key")
add("kit.bar.border", "key")
whole("kit.header", 12, 60)
whole("kit.control", 8, 60)
whole("kit.icon.size", 12, 96)
whole("kit.icon.inset", 0, 12)
number("kit.icon.trim", 0, 0.2)
add("kit.icon.color", "key")
add("kit.icon.border", "key")
add("kit.icon.hover", "key")
add("kit.icon.checked", "key")
whole("kit.badge.size", 6, 40)
whole("kit.badge.level", 1, 10)
add("kit.badge.color", "key")
add("kit.badge.text", "key")
whole("kit.band.height", 12, 60)
number("kit.band.alpha", 0, 1)
add("kit.band.text", "key")
add("kit.tag.color", "key")
add("kit.tag.text", "key")
add("kit.tag.font", "role")
whole("kit.tag.padding", 0, 20)
whole("kit.questlog.check", 8, 32)
whole("kit.progress.height", 4, 60)
add("kit.progress.color", "key")
add("kit.progress.background", "key")
add("kit.progress.border", "key")
whole("kit.row", 10, 60)
whole("kit.rows.action", 8, 60)
add("kit.rows.fill", "key")
number("kit.rows.fillAlpha", 0, 1)
add("kit.rows.mark", "key")
number("kit.rows.markAlpha", 0, 1)
add("kit.rows.suffix", "key")
whole("kit.slot", 10, 80)
whole("kit.indent", 0, 60)
whole("kit.list", 40, 800)
add("kit.collection.color", "key")
add("kit.collection.border", "key")
whole("kit.collection.padding", 0, 30)
whole("kit.rows.medium.height", 10, 80)
add("kit.rows.medium.font", "role")
whole("kit.rows.large.height", 10, 80)
add("kit.rows.large.font", "role")
whole("kit.scroll.width", 40, 2000)
whole("kit.scroll.height", 40, 2000)
whole("kit.table.row", 10, 60)
whole("kit.table.sort", 4, 24)
whole("kit.table.column", 10, 200)
add("kit.table.selected", "key")
add("kit.table.hover", "key")
whole("kit.table.indent", 0, 40)
whole("kit.table.bar.height", 2, 20)
add("kit.table.bar.fill", "key")
add("kit.table.bar.back", "key")
add("kit.table.group.fill", "key")
add("kit.table.group.chevron", "key")
whole("kit.toast.width", 100, 600)
number("kit.toast.duration", 1, 30)
whole("kit.toast.top", 0, 600)
whole("kit.toast.icon", 12, 64)
number("kit.toast.fade", 0, 5)
whole("kit.problem.alert.width", 100, 600)
whole("kit.problem.alert.max", 1, 10)
add("kit.problem.alert.color", "key")
number("kit.problem.discreet.duration", 1, 30)
number("kit.problem.discreet.quiet", 0, 3600)
whole("kit.drag", 0, 60)
whole("kit.ghost.width", 20, 600)
add("kit.ghost.color", "key")
add("kit.ghost.border", "key")
whole("kit.handle", 6, 40)
add("kit.dot.color", "key")
add("kit.dot.hover", "key")
whole("kit.pointer", 16, 160)
number("kit.aim.every", 0.01, 1)
number("kit.timer.every", 0.01, 1)
add("kit.timer.font", "role")
add("kit.chart.color", "key")
whole("kit.chart.height", 20, 400)
add("kit.chart.background", "key")
add("kit.chart.border", "key")
add("kit.chart.column", "key")
add("kit.chart.label", "key")
add("kit.chart.value", "key")
add("kit.chart.font", "role")
add("kit.chart.series.s1", "color")
add("kit.chart.series.s2", "color")
add("kit.chart.series.s3", "color")
add("kit.chart.series.s4", "color")
add("kit.chart.series.s5", "color")
add("kit.chart.others", "color")
whole("kit.chart.line", 8, 40)
whole("kit.dialog.width", 160, 800)
whole("kit.dialog.copy", 20, 400)
whole("kit.dialog.button", 20, 200)
whole("kit.dialog.choices", 1, 20)
number("kit.dialog.offset", -600, 600)
add("kit.dialog.field.color", "key")
add("kit.dialog.field.border", "key")
add("kit.dialog.title.font", "role")
add("kit.dialog.title.color", "key")
choice("kit.dialog.title.align", ALIGN)
whole("kit.dialog.wide", 160, 900)
whole("kit.dialog.rich.padding", 0, 60)
whole("kit.dialog.rich.spacing", 0, 40)
add("kit.dialog.rich.title.font", "role")
add("kit.dialog.rich.title.color", "key")
choice("kit.dialog.rich.title.align", ALIGN)
add("kit.dialog.rich.text.font", "role")
add("kit.dialog.rich.text.color", "key")
choice("kit.dialog.rich.text.align", ALIGN)
add("kit.dialog.danger.color", "key")
add("kit.dialog.danger.border", "key")
brick("kit.minimap.brick", "minimap")
whole("kit.minimap.size", 16, 48)
whole("kit.minimap.inset", 0, 16)
whole("kit.minimap.ring", 0, 12)
number("kit.minimap.offset", -40, 60)
number("kit.minimap.corner", 0, 40)
number("kit.minimap.angle", 0, 360)
number("kit.minimap.group.angle", 0, 360)
whole("kit.minimap.group.columns", 1, 12)
whole("kit.model.width", 40, 800)
whole("kit.model.height", 40, 800)
number("kit.model.turn", 0, 1)
number("kit.model.zoom.step", 0, 2)
number("kit.model.zoom.min", -10, 0)
number("kit.model.zoom.max", 0, 10)
number("kit.combatAlpha", 0, 1)
number("kit.animation", 0, 2)
number("kit.rescale.delay", 0, 1)

add("board.dress", "boolean")
add("board.portrait", "boolean")
choice("board.frame", { LARGE = true, SMALL = true, FLAT = true })
add("board.color", "key")
add("board.border", "key")
add("board.title.font", "role")
add("board.title.color", "key")
choice("board.title.align", { SIDE = true, CENTER = true })
number("board.title.x", -60, 200)
number("board.title.y", 0, 60)
add("board.name.font", "role")
add("board.name.color", "key")
add("board.heading.font", "role")
add("board.heading.color", "key")
add("board.text.font", "role")
add("board.text.color", "key")
add("board.note.font", "role")
add("board.note.color", "key")
add("board.objective.done", "key")
whole("board.header.height", 10, 60)
add("board.header.font", "role")
add("board.header.color", "key")
add("board.header.line", "key")
number("board.header.fold", 0, 2)
whole("board.header.room", 0, 40)
whole("board.row.height", 20, 120)
whole("board.row.gap", 0, 40)
whole("board.row.icon", 12, 64)
add("board.row.font", "role")
add("board.panel.color", "key")
add("board.panel.border", "key")
add("board.strip.color", "key")
add("board.strip.rule", "key")
add("board.tab.idle", "key")
add("board.tab.border", "key")
whole("board.tab.padding", 0, 40)
add("board.button.idle", "key")
add("board.art.frame", "boolean")
brick("board.card.brick", "card")
brick("board.cardHeader.brick", "cardHeader")
brick("board.picture.brick", "picture")
brick("board.slot.brick", "slot")

add("chat.prefix", "color")
add("chat.text", "color")
add("chat.error", "color")
add("chat.warn", "color")
add("chat.success", "color")
add("chat.highlight", "color")
add("chat.muted", "color")
add("chat.gold", "color")
add("chat.silver", "color")
add("chat.copper", "color")

-- T10 (A99.T10): false = no frame (edge) drawn around the pieces of the Journal, the fills stay
add("tree.frames.enabled", "boolean")
-- T12 (E1): fill of the panels that ProjectEbonhold pieces are replaced with, when the caller gives none
add("tree.piece.fill", "key")
number("tree.title.top", -60, 60)
whole("tree.bottom.height", 16, 100)
add("tree.bottom.fill", "key")
add("tree.bottom.border", "key")
add("tree.search.hide", "boolean")
whole("tree.bottom.edge", 0, 40)
whole("tree.tab.trim", 0, 60)
whole("tree.title.margin", 0, 200)
number("tree.title.drop", -60, 60)
add("tree.gauge.text", "color")
choice("tree.gauge.outline", OUTLINE)
add("tree.gauge.shadow", "color")
number("tree.gauge.shadowAlpha", 0, 1)
number("tree.gauge.shadowX", -4, 4)
number("tree.gauge.shadowY", -4, 4)
add("tree.button.fill", "key")
add("tree.button.border", "key")
add("tree.banner.fill", "key")
add("tree.banner.border", "key")
add("tree.paper.fill", "key")
choice("tree.prestige.circleFrame", LOOK_FRAME)
add("tree.prestige.animation", "text") -- "" = none; any other name is an animation a skin registers in EbonAPI.PrestigeAnimations (unknown name = none)
add("tree.prestige.fill", "key")
add("tree.prestige.border", "key")
add("tree.prestige.barFill", "text") -- palette color name; "" leaves the native art as it is
add("tree.prestige.barDesaturate", "boolean")
add("tree.prestige.previewFill", "text") -- palette key behind the reward model; "" = tree.prestige.fill
add("tree.prestige.text", "text") -- palette key of the texts of the Prestige panels; "" leaves the native colour
add("tree.paper.border", "key")
whole("tree.dense.pad", 0, 20)
whole("tree.dense.gap", 0, 20)
whole("tree.dense.zoomMargin", 0, 40)
whole("tree.dense.hubSize", 16, 256)
whole("tree.dense.hubMax", 1, 40)
number("tree.dense.hubAuraMargin", 0.5, 3)
number("tree.dense.hubAuraOwn", 0, 1)
number("tree.dense.hubAuraOther", 0, 1)
number("tree.dense.hubIconScale", 0.2, 2)
number("tree.dense.hubRingScale", 0.5, 2)
whole("tree.dense.hubRadius", 50, 3000)
add("tree.dense.hubKey", "key")
add("tree.dense.centerIcon", "texture")
add("tree.dense.centerGlow", "texture")
add("tree.dense.hubAura", "texture")
add("tree.dense.hubRing", "texture")
add("tree.dense.nodeHaloTex", "texture")
add("tree.dense.normalHaloTex", "texture")
add("tree.dense.hubIcon", "texture")
add("tree.dense.currencyAsh", "texture")
add("tree.dense.currencyShard", "texture")
add("tree.dense.currencyEssence", "texture")
add("tree.dense.currencyArtisan", "texture")
whole("tree.dense.nodePx", 1, 8)
whole("tree.dense.hubPx", 1, 16)
whole("tree.dense.maxDots", 1, 32)
number("tree.dense.dotStep", 1, 10)
number("tree.dense.dotMin", 0, 10)
add("tree.dense.linkKey", "key")
add("tree.dense.linkLitKey", "key")
add("tree.dense.stateActive", "key")
add("tree.dense.stateReady", "key")
add("tree.dense.stateNopoints", "key")
add("tree.dense.stateLocked", "key")
add("tree.dense.stateUnknown", "key")
add("tree.dense.mapLinkLitKey", "key")
number("tree.dense.pendingAlpha", 0, 1)
number("tree.dense.haloAlpha", 0, 1)
number("tree.dense.normalHaloAlpha", 0, 1)
number("tree.dense.minimapIdleAlpha", 0, 1)
number("tree.dense.lockedAlpha", 0, 1)
add("tree.dense.fillKey", "key")
number("tree.dense.fillLockedAlpha", 0, 1)
whole("tree.dense.iconMinPx", 1, 64)
whole("tree.dense.noticeHeight", 8, 60)
whole("tree.dense.slotWidth", 100, 600)
whole("tree.dense.tipIcon", 8, 64)
add("tree.dense.tipColor", "color")
number("tree.dense.dotSize", 0.5, 8)
choice("tree.bottom.frame", LOOK_FRAME)
choice("tree.button.frame", LOOK_FRAME)
choice("tree.banner.frame", LOOK_FRAME)
choice("tree.paper.frame", LOOK_FRAME)
choice("tree.piece.frame", LOOK_FRAME)
choice("tree.piece.panel", LOOK_FRAME)
choice("tree.piece.bar", LOOK_FRAME)
choice("tree.piece.scroll", LOOK_FRAME)
choice("tree.piece.slot", LOOK_FRAME)
-- S4 (A99.T9): palette key of the edge of the Transmogrify bar piece (the bg key = no visible frame around the bar)
add("tree.piece.barBorder", "key")
number("tree.dense.minZoom", 0.01, 1)
number("tree.dense.maxZoom", 1, 10)
number("tree.dense.zoomStep", 1.01, 2)
number("tree.dense.defaultZoom", 0.05, 5)
number("tree.dense.textMinZoom", 0, 5)
whole("tree.dense.nodeSize", 8, 128)
whole("tree.dense.nodeMinPx", 1, 16)
whole("tree.dense.borderPx", 0, 8)
whole("tree.dense.presetGrow", 0, 32)
whole("tree.dense.haloGrow", 0, 64)
whole("tree.dense.nodeHaloGrow", 0, 64)
whole("tree.dense.viewMargin", 0, 200)
whole("tree.dense.linkPx", 1, 16)
whole("tree.dense.linkLitPx", 1, 16)
add("tree.dense.linkTexStraight", "texture")
add("tree.dense.linkTexTilted", "texture")
number("tree.dense.linkTexFactor", 0.5, 2)
add("tree.dense.presetKey", "key")
add("tree.dense.pendingKey", "key")
add("tree.dense.rankKey", "key")
add("tree.dense.noticeKey", "key")
add("tree.dense.navTipFallback", "color")
whole("tree.journal.portraitSize", 20, 200)
number("tree.journal.portraitLeft", -100, 100)
number("tree.journal.portraitTop", -100, 100)
number("tree.journal.iconLeft", -100, 100)
whole("tree.journal.portraitMargin", 0, 20)
add("tree.journal.ringColor", "text")
whole("tree.journal.ringInset", 0, 20) -- px the ring disc spans beyond the icon on each side
add("tree.journal.tabs", "list")
number("tree.journal.fadeAlpha", 0, 1)
-- T14: tuile journal.footer (barre du bas de l'onglet actif : noms globaux des pieces natives a y poser, par onglet)
add("windows.detach.footer", "boolean")
add("windows.tile.content", "boolean") -- R7f
-- R7h: content frame of each journal page, "+" joins frames whose union is the content
add("windows.tilePages", "list")
-- R7h end
whole("tree.journal.height", 400, 1200)
whole("tree.journal.footerHeight", 10, 200)
add("tree.journal.footer.SkillTree", "list")
add("tree.journal.footer.Transmog", "list")
add("tree.journal.footer.Mounts", "list")
add("tree.journal.footer.Companions", "list")
-- T16: skin share of the Saves hover margin (px, added to Common saves.hoverMargin)
number("saves.hoverMarginAdd", -100, 100)
whole("journal.tab.seat.leftAdd", -50, 50)
whole("journal.tab.seat.topAdd", -50, 50)
whole("journal.tab.seat.rightAdd", -50, 50)
whole("journal.tab.seat.bottomAdd", -50, 50)
whole("journal.tab.textPadAdd", -50, 50)
-- R7a
whole("journal.title.gapAdd", -50, 50)
whole("board.pe.row", 20, 120)
whole("board.pe.gap", 0, 20)
whole("board.pe.head", 10, 60)
whole("board.pe.portrait.size", 20, 120)
whole("board.pe.portrait.left", -20, 40)
whole("board.pe.portrait.top", -40, 20)
whole("board.pe.portrait.inset", 0, 10)
whole("board.pe.star.size", 6, 40)
whole("board.pe.star.x", -20, 20)
whole("board.pe.star.y", -20, 20)
add("board.pe.star.color", "key")
whole("board.pe.toggle.size", 6, 40)
whole("board.pe.toggle.x", -20, 20)
whole("board.pe.toggle.y", -20, 20)
add("board.pe.toggle.color", "key")
add("board.pe.toggle.open", "text")
add("board.pe.toggle.close", "text")
whole("board.pe.frame.margin", 0, 30)

local BY_KEY = {}
local SECTIONS = {}
local SLOTS = {}
local SLOT_NAMES = {}
local PLAYER = {}

for _, entry in ipairs(LIST) do
  BY_KEY[entry.key] = entry

  local key = entry.key

  for index = 1, len(key) do
    if sub(key, index, index) == "." then
      SECTIONS[sub(key, 1, index - 1)] = true
    end
  end

  if entry.kind == "brick" then
    SLOTS[entry.slot] = key
    SLOT_NAMES[#SLOT_NAMES + 1] = entry.slot
  end

  if entry.player then
    PLAYER[#PLAYER + 1] = entry
  end
end

table.sort(SLOT_NAMES)

Catalog.LIST = LIST
Catalog.PALETTE = PALETTE
Catalog.PLAYER = PLAYER

function Catalog.entry(key)
  return BY_KEY[key]
end

function Catalog.isSection(path)
  return SECTIONS[path] == true
end

function Catalog.slotKey(slot)
  return SLOTS[slot]
end

function Catalog.slotNames()
  return SLOT_NAMES
end

local function isColor(value)
  return type(value) == "number" and value == floor(value) and value >= 0 and value <= COLOR_MAX
end

local function isAlpha(value)
  return type(value) == "number" and value >= 0 and value <= 1
end

function Catalog.problem(entry, value)
  local name, kind = entry.key, entry.kind

  if kind == "color" then
    if not isColor(value) then
      return format('parameter "%s" expects a color 0xRRGGBB (0 to %d), got %s', name, COLOR_MAX, tostring(value))
    end
  elseif kind == "rgba" then
    local ok = isColor(value)
      or (type(value) == "table" and isColor(value[1]) and isAlpha(value[2]) and value[3] == nil)

    if not ok then
      return format('parameter "%s" expects a color 0xRRGGBB or { 0xRRGGBB, alpha from 0 to 1 }, got %s',
        name, tostring(value))
    end
  elseif kind == "number" then
    if type(value) ~= "number" or value ~= value or value < entry.min or value > entry.max
        or (entry.whole and value ~= floor(value)) then
      return format('parameter "%s" expects a %s from %s to %s, got %s', name,
        entry.whole and "whole number" or "number", tostring(entry.min), tostring(entry.max), tostring(value))
    end
  elseif kind == "choice" then
    if not entry.values[value] then
      return format('parameter "%s" expects one of %s, got %s', name,
        concat(Lib.sortedKeys(entry.values), ", "), tostring(value))
    end
  elseif kind == "boolean" then
    if type(value) ~= "boolean" then
      return format('parameter "%s" expects a boolean, got %s', name, type(value))
    end
  elseif kind == "font" then
    if type(value) ~= "string" or value == "" then
      return format('parameter "%s" expects a font file or "game", got %s', name, tostring(value))
    end
  elseif kind == "texture" or kind == "sound" then
    if type(value) ~= "string" then
      return format('parameter "%s" expects a %s path, or "" for none, got %s', name, kind, type(value))
    end
  elseif kind == "list" then
    if type(value) ~= "table" then
      return format('parameter "%s" expects a list of texts, got %s', name, type(value))
    end

    local count = 0

    for index, item in pairs(value) do
      if type(index) ~= "number" or type(item) ~= "string" then
        return format('parameter "%s" expects a list of texts, got %s at %s', name, type(item), tostring(index))
      end

      count = count + 1
    end

    if count ~= #value then
      return format('parameter "%s" expects a list of texts numbered 1, 2, 3 without gaps', name)
    end
  elseif kind == "brick" then
    if type(value) ~= "string" or value == "" then
      return format('parameter "%s" expects a brick name, got %s', name, tostring(value))
    end
  elseif kind == "key" then
    if not PALETTE_SET[value] then
      return format('parameter "%s" expects a palette color name (%s), got %s', name, concat(PALETTE, ", "),
        tostring(value))
    end
  elseif kind == "role" then
    if not ROLES[value] then
      return format('parameter "%s" expects one of %s, got %s', name, concat(Lib.sortedKeys(ROLES), ", "),
        tostring(value))
    end
  elseif kind == "text" then
    if type(value) ~= "string" then
      return format('parameter "%s" expects a text, got %s', name, type(value))
    end
  else
    return format('parameter "%s" has an unknown kind "%s"', name, tostring(kind))
  end

  return nil
end

-- Common: the values EbonAPI keeps for EVERY skin (neither colours nor sizes of a look, so no skin token): stacking
-- order relative to a parent frame, technical timer delays, behaviour flags, native frames recognised by size or
-- texture name, and the work limits of the dense tree. They are declared ONCE, here. The code reads them with
-- EbonAPI.Common.get(name) (or api:Common(name)) at the moment of use; a skin or another addon replaces one with
-- EbonAPI.Common.set(name, value) (or api:Common(name, value)), the new value must have the declared type.
EbonAPI.Common = {}

local Common = EbonAPI.Common

local DECLARED = {
  -- DressTreeBody / DressTree: frame levels, relative to the parent frame
  ["tree.gaugeFillLevel"] = 1,        -- the gauge fill piece sits this many levels under the gauge
  ["tree.gaugeLevel"] = 40,           -- the dressed gauge sits this many levels over the surface
  ["tree.progressTexture"] = "progression_bar", -- part of the texture path of the native gauge art (found, then replaced)
  ["tree.searchIcon"] = "Interface\\Common\\UI-Searchbox-Icon", -- magnifier of the skin search field (replaces the native one)
  ["tree.searchIconSize"] = 14,       -- its size and the space around it, in the field (px)
  ["tree.searchIconGap"] = 4,
  -- every dress: technical delay of the timers that wait for the native frame to settle
  ["dress.timerDelay"] = 0.01,
  -- Saves: status line (lines of room, padding under them, inset from the bottom edge) in px / font lines
  ["saves.statusLines"] = 2,
  ["saves.statusPad"] = 4,
  -- T16: Saves hover zone: margin (px) added on the 4 sides of the visible list; the skin token saves.hoverMarginAdd is added to it
  ["saves.hoverMargin"] = 8,
  -- R7c
  ["journal.nativeArt"] = "framegeneral",
  -- R7f: depth of sub-frames swept under the native gauge
  ["tree.gaugeDepth"] = 6,
  -- R7a
  ["journal.title.gap"] = 8,
  ["journal.tab.seat.left"] = 9,
  ["journal.tab.seat.top"] = -6,
  ["journal.tab.seat.right"] = -8,
  ["journal.tab.seat.bottom"] = 4,
  ["journal.tab.textPad"] = 8,
  ["saves.statusInset"] = 2,
  -- DressTree: smallest height of a piece drawn from a measure (a zero height would hide it)
  ["tree.pieceMinHeight"] = 1,
  -- Dress: the board is replaced by every skin (false: only when the skin sets board.dress)
  ["dress.replaceAll"] = true,
  -- DressMounts: offset of the filter reset cross from the top right corner of the filter button (SharedUIPanelTemplates.xml:633-636)
  ["mounts.resetCrossX"] = -3,
  ["mounts.resetCrossY"] = 0,
  -- DressCompanions: same offset for the filter reset cross of the Companions tab
  ["companions.resetCrossX"] = -3,
  ["companions.resetCrossY"] = 0,
  -- DressTransmog: same offset for the filter reset cross of the Transmog tab
  ["transmog.resetCrossX"] = -3,
  ["transmog.resetCrossY"] = 0,
  -- Dress: icon of the board portrait, constant ICON_BOARD of ProjectEbonhold (callboard_ui.lua:63); used when the
  -- hook of SetPortraitToTexture did not keep the path of the native portrait
  ["board.portraitIcon"] = "Interface\\Icons\\INV_Misc_Note_01",
  -- Dress: icon of the travel button drawn over the native one (size, offset from the left edge, texture trim)
  ["board.travelIconSize"] = 18,
  ["board.travelIconX"] = 8,
  ["board.travelIconTrim"] = 0.08,
  ["board.travelIconLevel"] = 4,
  -- Dress: tabs of the board (text width cap, height, minimum middle part, padding around the text, outer padding)
  ["board.tabTextMax"] = 120,
  ["board.tabHeight"] = 32,
  ["board.tabMiddleMin"] = 40,
  ["board.tabTextPad"] = 20,
  ["board.tabOuterPad"] = 40,
  -- Dress: column of the list's scroll bar, right of the rows (callboard_ui.lua:874-877)
  ["board.listBar"] = 22,
  -- Dress: quest paper behind the detail (used width and width of the file, in pixels) and its three border lines
  ["board.paperWidth"] = 326,
  ["board.paperTexture"] = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-QUESTPAPER",
  ["board.paperFileWidth"] = 512,
  ["board.paperLineDark"] = { 0.16, 0.11, 0.06 },
  ["board.paperLineLight"] = { 0.42, 0.32, 0.20 },
  -- Dress: thickness of the paper lines, frame levels above the host frame
  ["board.paperLineThickness"] = 1,
  ["board.levelBox"] = 1,
  ["board.levelRow"] = 2,
  ["board.levelMap"] = 6,
  -- DressPrestige: native frames recognised by size (width, height) and tolerance in pixels
  ["prestige.tolerance"] = 1,
  ["prestige.circleTexture"] = "dragonflightmajorfactionstuskarr",
  ["prestige.separator"] = { 100, 1 },     -- height 1, wider than 100
  ["prestige.deal"] = { 420, 42 },
  ["prestige.preview"] = { 240, 310 },
  ["prestige.previewButton"] = { 26, 26 },
  ["prestige.button"] = { 170, 34 },
  ["prestige.bar"] = { 690, 42 },
  ["prestige.bubble"] = { 30, 30 },
  -- STAL dense tree: stacking, data limits, geometry maths and behaviour (nothing drawn)
  ["stal.haloSublevel"] = -8,         -- lowest drawing sublevel of the engine (3.3.5): the halo goes under all the BACKGROUND art of its button
  ["stal.controlLevel"] = 6,          -- zoom control over the node view
  ["stal.viewLevel"] = 1,             -- node view sits this many levels over the dense root
  ["stal.miniLevel"] = 6,             -- minimap sits this many levels over the node view
  ["stal.miniMargin"] = 8,            -- minimap distance from the bottom right corner of the node view (px)
  ["stal.zoomGaugeGap"] = 24,         -- zoom control sits this far left of the soul gauge, on the gauge row (the gauge plate is wider than its frame)
  ["stal.zoomReadout"] = 44,         -- zoom control: width of the percent readout, room for "100 %" between the - and + buttons (px)
  ["stal.spacingScale"] = 0.8,        -- data units to pixels, before the zoom
  ["stal.defaultWidth"] = 1000,       -- view size used before the first layout
  ["stal.defaultHeight"] = 640,
  ["stal.maxButtons"] = 300,          -- pool of node buttons (never created beyond)
  ["stal.maxLinks"] = 350,
  ["stal.linkMinLength"] = 1,
  ["stal.linkAxisTolerance"] = 0.5,   -- under this many pixels a link is drawn straight
  ["stal.dragThreshold"] = 2,
  ["stal.dragInterval"] = 0.016,
  ["stal.centerSeconds"] = 0.25,
  ["stal.minimapMiddle"] = 0.5,       -- middle of each part of a segment (minimap dots)
  ["stal.roundSizeKey"] = "widgets.round.size", -- name of the skin token of the class buttons
  ["stal.rankOffsetX"] = -2,          -- rank text offset from the node's bottom right corner (PE skillTree.lua:2972)
  ["stal.rankOffsetY"] = 2,
  ["stal.iconTint"] = { 1, 1, 1 },    -- vertex colour of the node icon
  ["stal.iconTrim"] = 0.07,           -- texture trim of the node icon (PE skillTree.lua:3910)
  ["stal.defaultCurrency"] = "ash",   -- currency key used when a balance has none
}

local current = {}

for name, value in pairs(DECLARED) do
  current[name] = value
end

function Common.get(name)
  local value = current[name]

  if value == nil then
    error(format('EbonAPI: Common: "%s" is not declared', tostring(name)), 2)
  end

  return value
end

function Common.set(name, value)
  if DECLARED[name] == nil then
    error(format('EbonAPI: Common: "%s" is not declared', tostring(name)), 2)
  end

  if type(value) ~= type(DECLARED[name]) then
    error(format('EbonAPI: Common: "%s" expects a %s, got %s', name, type(DECLARED[name]), type(value)), 2)
  end

  current[name] = value
end

function Common.reset(name)
  Common.set(name, DECLARED[name])
end

function Common.names()
  return Lib.sortedKeys(DECLARED)
end

-- Public API: api:Common(name) reads, api:Common(name, value) replaces and returns the value now in force.
function EbonAPI.Handle:Common(name, value)
  if value ~= nil then
    Common.set(name, value)
  end

  return Common.get(name)
end
