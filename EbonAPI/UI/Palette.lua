EbonAPI = EbonAPI or {}
EbonAPI.Palette = {}

local Palette = EbonAPI.Palette
local Catalog = EbonAPI.Catalog
local Skins = EbonAPI.Skins

local pairs, ipairs, type, setmetatable = pairs, ipairs, type, setmetatable
local floor, max, min = math.floor, math.max, math.min
local format = string.format

local KEYS = Catalog.PALETTE
local BACKGROUND = {
  bg = true, bgSoft = true, card = true, checkbox = true,
  headerBg = true, navBg = true, pageBg = true, footerBg = true,
}
local SCALED = { bg = true, bgSoft = true, card = true, headerBg = true, navBg = true, pageBg = true, footerBg = true }
local FOREGROUND = { text = true, muted = true, title = true }
local FIXED = { buttonText = true, buttonDisabledText = true, selectedText = true, shadow = true, success = true }
local AGAINST_BACKGROUND = { "heading", "buttonHover", "checked", "thumb", "focus", "success" }
local WHITE = { 1, 1, 1 }
local BLACK = { 0, 0, 0 }
local WEAK = { __mode = "k" }

local THEME = {}

for _, key in ipairs(KEYS) do
  THEME[key] = { 0, 0, 0, 1 }
end

Palette.THEME = THEME
Palette.KEYS = KEYS

local painted = {}

function Palette.unpackColor(value)
  return floor(value / 65536) / 255, floor(value / 256) % 256 / 255, value % 256 / 255
end

function Palette.packColor(r, g, b)
  return floor(r * 255 + 0.5) * 65536 + floor(g * 255 + 0.5) * 256 + floor(b * 255 + 0.5)
end

local function luminance(r, g, b)
  local function linear(v)
    return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
  end

  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end

local function lightness(color)
  return luminance(color[1], color[2], color[3])
end

Palette.lightness = lightness

local function ratio(a, b)
  local la, lb = lightness(a), lightness(b)

  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
end

Palette.contrast = ratio

function Palette.readable()
  return Skins.value("contrast.minimum")
end

local function reach(color, against, toward, readable)
  for _ = 1, 30 do
    if ratio(color, against) >= readable then
      return
    end

    for index = 1, 3 do
      color[index] = color[index] + (toward - color[index]) * 0.15
    end
  end
end

local function setGrey(color, value)
  color[1], color[2], color[3] = value, value, value
end

function Palette.blend(color, behind)
  local alpha = color[4] or 1

  return {
    color[1] * alpha + behind[1] * (1 - alpha),
    color[2] * alpha + behind[2] * (1 - alpha),
    color[3] * alpha + behind[3] * (1 - alpha),
  }
end

local function base(key)
  local value = Skins.value("palette." .. key)
  local alpha = 1

  if type(value) == "table" then
    value, alpha = value[1], value[2]
  end

  local r, g, b = Palette.unpackColor(value)

  return r, g, b, alpha
end

function Palette.derive(background, accent, opacity)
  local enforce = Skins.value("contrast.enforce")
  local readable = Skins.value("contrast.minimum")
  local light, dark = Skins.value("contrast.light"), Skins.value("contrast.dark")
  local br, bgreen, bb = Palette.unpackColor(background)
  local ar, ag, ab = Palette.unpackColor(accent)
  local ground = { br, bgreen, bb }
  local neutral = ratio(ground, WHITE) >= ratio(ground, BLACK) and 1 or 0
  local changed, groundChanged = false, false

  for _, key in ipairs(KEYS) do
    local value = THEME[key]
    local reference = Skins.reference("palette." .. key)
    local newGround = background ~= reference.background
    local r, g, b, a = base(key)

    value[1], value[2], value[3], value[4] = r, g, b, a

    if BACKGROUND[key] then
      if newGround then
        value[1], value[2], value[3] = br, bgreen, bb
        changed, groundChanged = true, true
      end

      if SCALED[key] then
        value[4] = min(1, a * opacity / reference.opacity)
      end
    elseif FOREGROUND[key] then
      if newGround then
        setGrey(value, neutral)
        changed, groundChanged = true, true
      end
    elseif not FIXED[key] and accent ~= reference.accent then
      local rr, rg, rb = Palette.unpackColor(reference.accent)
      local top = max(rr, rg, rb)
      local brightness = top > 0 and max(r, g, b) / top or 1

      value[1], value[2], value[3] = min(1, ar * brightness), min(1, ag * brightness), min(1, ab * brightness)
      changed = true
    end
  end

  if accent ~= Skins.reference("palette.buttonText").accent then
    setGrey(THEME.buttonText, light)
    setGrey(THEME.buttonDisabledText, light)
  end

  if enforce then
    local buttonText = THEME.buttonText

    reach(THEME.button, buttonText, lightness(buttonText) > lightness(THEME.button) and 0 or 1, readable)
    reach(THEME.buttonHoverFill, buttonText, lightness(buttonText) > lightness(THEME.buttonHoverFill) and 0 or 1,
      readable)
  end

  local selected = THEME.selected
  local onDark = ratio(selected, { dark, dark, dark }) >= ratio(selected, { light, light, light })

  setGrey(THEME.selectedText, onDark and dark or light)

  if enforce then
    reach(selected, THEME.selectedText, onDark and 1 or 0, readable)
    reach(THEME.menu, BLACK, 1, readable)

    if changed then
      for _, key in ipairs(AGAINST_BACKGROUND) do
        reach(THEME[key], ground, neutral, readable)
      end
    end

    if groundChanged then
      local muted = THEME.muted

      for _ = 1, 20 do
        if muted[4] >= 1 or ratio(Palette.blend(muted, ground), ground) >= readable then
          break
        end

        muted[4] = min(1, muted[4] + 0.05)
      end
    end
  end
end

function Palette.code(key)
  local color = THEME[key] or THEME.heading

  return format("|cff%02x%02x%02x", floor(color[1] * 255 + 0.5), floor(color[2] * 255 + 0.5), floor(color[3] * 255 + 0.5))
end

function Palette.paint(target, method, key)
  local list = painted[method]

  if not list then
    list = setmetatable({}, WEAK)
    painted[method] = list
  end

  list[target] = key

  local color = THEME[key]

  target[method](target, color[1], color[2], color[3], color[4])
end

function Palette.unpaint(target, method)
  local list = painted[method]

  if list then
    list[target] = nil
  end
end

function Palette.repaint()
  for method, list in pairs(painted) do
    for target, key in pairs(list) do
      local color = THEME[key]

      target[method](target, color[1], color[2], color[3], color[4])
    end
  end
end
