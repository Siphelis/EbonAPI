EbonAPI = EbonAPI or {}
EbonAPI.Dress = {}


local Dress = EbonAPI.Dress
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local Bus = EbonAPI.Bus
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit
local Ebonhold = EbonAPI.Ebonhold
local Handle = EbonAPI.Handle

local type, pairs, ipairs, select, pcall, unpack, error = type, pairs, ipairs, select, pcall, unpack, error
local setmetatable, getmetatable, tostring = setmetatable, getmetatable, tostring
local abs, max = math.abs, math.max
local find, gsub, lower, format = string.find, string.gsub, string.lower, string.format

local S = Skins.value
local THEME = Palette.THEME
local WEAK = { __mode = "k" }

local OWNER = EbonAPI.name
local FRAME = "EbonholdCallboardFrame"
local STYLES = Bricks.GROUP_FRAMES

local CODES = {
  ["1eff00"] = "success",
  ["6fa8ff"] = "active",
  ["ff4040"] = "danger",
  ["ffd100"] = "heading",
  ["888888"] = "muted",
  ["ffffff"] = "text",
}

local ART = {
  chrome = "ui%-questlogdualpane%-",
  cross = "ui%-panel%-minimizebutton%-",
  button = "ui%-panel%-button%-",
  tab = "ui%-character%-",
  knob = "ui%-scrollbar%-knob",
  barBorder = "ui%-achievement%-progressbar%-border",
  paper = "ui%-lfg%-background%-questpaper",
  frame = "ui%-achievement%-iconframe",
  quickslot = "ui%-quickslot2",
  ring = "ui%-lfg%-icon%-rewardring",
  category = "ui%-achievement%-category%-background",
  glow = "ui%-questlogtitlehighlight",
}

local TAB_PARTS = { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }
Dress.TAB_PARTS = TAB_PARTS

local handle = setmetatable({ addonName = OWNER }, Handle)

local state, reason = "waiting", nil
local installed, held, dressed = false, false, false
local born = setmetatable({}, WEAK)

local pages = {}
local shownPage = nil
local bandBar = nil
local applyPages
local tilesApply, tilesRelease


local function list(...)
  return { n = select("#", ...), ... }
end
Dress.list = list

local GET, SET = {}, {}

function GET.alpha(region) return region:GetAlpha() end
Dress.getAlpha = GET.alpha
function SET.alpha(region, value) region:SetAlpha(value) end
Dress.setAlpha = SET.alpha

function GET.shown(region) return region:IsShown() and true or false end

function SET.shown(region, value)
  if value then
    region:Show()
  else
    region:Hide()
  end
end

function GET.font(region) return list(region:GetFont()) end

function SET.font(region, value)
  if value[1] then
    region:SetFont(value[1], value[2], value[3])
  end
end

function GET.shadow(region)
  local x, y = region:GetShadowOffset()
  local r, g, b, a = region:GetShadowColor()

  return list(x, y, r, g, b, a)
end

function SET.shadow(region, value)
  region:SetShadowOffset(value[1] or 0, value[2] or 0)
  region:SetShadowColor(value[3] or 0, value[4] or 0, value[5] or 0, value[6] or 0)
end

function GET.textColor(region) return list(region:GetTextColor()) end
function SET.textColor(region, value) region:SetTextColor(value[1], value[2], value[3], value[4]) end
function GET.text(region) return region:GetText() end
function SET.text(region, value) region:SetText(value) end

function GET.justify(region) return region:GetJustifyH() end
function SET.justify(region, value) region:SetJustifyH(value) end

function GET.points(region)
  local out = { n = region:GetNumPoints() }

  for index = 1, out.n do
    out[index] = list(region:GetPoint(index))
  end

  return out
end
Dress.getPoints = GET.points

function SET.points(region, value)
  region:ClearAllPoints()

  for index = 1, value.n or #value do
    local point = value[index]

    region:SetPoint(point[1], point[2], point[3], point[4] or 0, point[5] or 0)
  end
end
Dress.setPoints = SET.points

function GET.width(region) return region:GetWidth() end
function SET.width(region, value) region:SetWidth(value) end
function GET.height(region) return region:GetHeight() end
function SET.height(region, value) region:SetHeight(value) end
function GET.texture(region) return region:GetTexture() end
function SET.texture(region, value) region:SetTexture(value) end
function GET.coords(region) return list(region:GetTexCoord()) end
function SET.coords(region, value) region:SetTexCoord(unpack(value, 1, value.n)) end
function GET.vertex(region) return list(region:GetVertexColor()) end
function SET.vertex(region, value) region:SetVertexColor(value[1], value[2], value[3], value[4]) end
function GET.mouse(region) return region:IsMouseEnabled() and true or false end
function SET.mouse(region, value) region:EnableMouse(value) end

function GET.bar(region)
  local texture = region:GetStatusBarTexture()

  return texture and texture:GetTexture()
end

function SET.bar(region, value) region:SetStatusBarTexture(value) end
function GET.barColor(region) return list(region:GetStatusBarColor()) end
function SET.barColor(region, value) region:SetStatusBarColor(value[1], value[2], value[3], value[4]) end

local function same(a, b)
  if a == b then
    return true
  end

  if type(a) == "number" and type(b) == "number" then
    return abs(a - b) < 0.0005
  end

  if type(a) ~= "table" or type(b) ~= "table" or a.n == nil or b.n == nil or getmetatable(a) or getmetatable(b)
      or a.n ~= b.n then
    return false
  end

  for index = 1, a.n do
    if not same(a[index], b[index]) then
      return false
    end
  end

  return true
end
Dress.same = same

local memory = {}
local order = {}

local function capture(region, ...)
  local kept = memory[region]

  if not kept then
    kept = {}
    memory[region] = kept
    order[#order + 1] = region
  end

  for index = 1, select("#", ...) do
    local prop = select(index, ...)
    local value = GET[prop](region)
    local entry = kept[prop]

    if not entry then
      kept[prop] = { orig = value }
    elseif not entry.done or not same(value, entry.mine) then
      entry.orig = value
    end
  end
end

local function commit(region, ...)
  local kept = memory[region]

  for index = 1, select("#", ...) do
    local prop = select(index, ...)
    local entry = kept[prop]

    entry.mine, entry.done = GET[prop](region), true
  end
end

local function set(region, prop, value)
  capture(region, prop)
  SET[prop](region, value)
  commit(region, prop)
end

local function peValue(region, prop)
  local kept = memory[region]
  local entry = kept and kept[prop]
  local value = GET[prop](region)

  if entry and entry.done and same(value, entry.mine) then
    return entry.orig
  end

  return value
end

local function restore()
  for index = #order, 1, -1 do
    local region = order[index]

    for prop, entry in pairs(memory[region]) do
      if entry.done and same(GET[prop](region), entry.mine) then
        SET[prop](region, entry.orig)
      end
    end

    memory[region] = nil
    order[index] = nil
  end
end


local seen = setmetatable({}, WEAK)

local function original(frame)
  local own = seen[frame]

  if not own then
    own = { regions = { frame:GetRegions() }, children = { frame:GetChildren() } }
    seen[frame] = own
  end

  return own
end

local function frameOf(name)
  return Ebonhold.Frame(name)
end

local function isType(object, kind)
  return type(object) == "table" and type(object.GetObjectType) == "function" and object:GetObjectType() == kind
end

local framed = {}
local worn = {}
local texturesOf, markOf, scan

do
local function drawn(region, pattern)
  local texture = peValue(region, "texture")

  return type(texture) == "string" and find(lower(texture), pattern) ~= nil
end

local function want(ok, piece)
  if not ok then
    error({ piece = piece }, 0)
  end
end


local function bare(frame, piece)
  want(framed[frame] or worn[frame] or not frame:GetBackdrop(), piece)
end

function texturesOf(frame, layer, pattern)
  local out = {}

  for _, region in ipairs(original(frame).regions) do
    if isType(region, "Texture") and region:GetDrawLayer() == layer and (not pattern or drawn(region, pattern)) then
      out[#out + 1] = region
    end
  end

  return out
end

local function textsOf(frame)
  local out = {}

  for _, region in ipairs(original(frame).regions) do
    if isType(region, "FontString") then
      out[#out + 1] = region
    end
  end

  return out
end

local function panelButton(button, piece)
  want(isType(button, "Button"), piece)

  local parts = texturesOf(button, "BORDER", ART.button)
  local glow, text = button:GetHighlightTexture(), button:GetFontString()

  want(#parts == 3 and glow ~= nil and text ~= nil, piece)
  parts[#parts + 1] = glow

  return { button = button, parts = parts, text = text }
end

local function travelButton(button)
  local piece = panelButton(button, "panel.travel")

  want(isType(button.icon, "Texture"), "panel.travel")
  piece.icon = button.icon

  return piece
end

local function scanFrame(frame, P)
  want(isType(frame, "Frame"), "frame")
  want(isType(frame.cacheInfo, "FontString"), "cacheInfo")
  want(isType(frame.resets, "FontString"), "resets")

  local chrome = texturesOf(frame, "BORDER")
  local portrait = texturesOf(frame, "BACKGROUND")
  local titles = {}

  for _, region in ipairs(chrome) do
    want(drawn(region, ART.chrome), "chrome")
  end

  for _, text in ipairs(textsOf(frame)) do
    if text ~= frame.cacheInfo and text ~= frame.resets then
      titles[#titles + 1] = text
    end
  end

  want(#chrome == 12, "chrome")
  want(#portrait == 1, "portrait")
  want(#titles == 1, "title")
  P.chrome, P.portrait, P.title = chrome, portrait[1], titles[1]
  P.cacheInfo, P.resets = frame.cacheInfo, frame.resets

  local crosses, closes = {}, {}

  for _, child in ipairs(original(frame).children) do
    if isType(child, "Button") and child ~= frame.claimAll and not find(child:GetName() or "", "^" .. FRAME .. "Tab") then
      local normal = child:GetNormalTexture()

      if normal and drawn(normal, ART.cross) then
        crosses[#crosses + 1] = child
      elseif #texturesOf(child, "BORDER", ART.button) == 3 then
        closes[#closes + 1] = child
      end
    end
  end

  want(#crosses == 1, "cross")
  want(#closes == 1, "close")

  local cross = crosses[1]
  local parts = {}

  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    local texture = cross[getter](cross)

    if texture then
      parts[#parts + 1] = texture
    end
  end

  P.cross = { button = cross, parts = parts }
  P.close = panelButton(closes[1], "close")
  P.claimAll = panelButton(frame.claimAll, "claimAll")
end

local function scanBand(frame, P)
  local bar = frame.cacheBar

  want(isType(bar, "StatusBar"), "cacheBar")
  want(isType(bar.text, "FontString"), "cacheBar.text")

  local fill = bar:GetStatusBarTexture()
  local tracks, borders = {}, texturesOf(bar, "OVERLAY", ART.barBorder)

  for _, region in ipairs(texturesOf(bar, "BACKGROUND")) do
    if region ~= fill then
      tracks[#tracks + 1] = region
    end
  end

  want(fill ~= nil and #tracks == 1 and #borders == 1, "cacheBar")
  if not bar.kitNative then
    bare(bar, "cacheBar")
  end
  P.bar = { bar = bar, track = tracks[1], border = borders[1], text = bar.text }
end

local verified = setmetatable({}, WEAK)

local function scanItem(child)
  if isType(child, "Button") and (child.bg ~= nil or child.glow ~= nil or child.edge ~= nil or child.badge ~= nil) then
    want(type(child.bg) == "table" and #child.bg == 9 and isType(child.glow, "Texture") and drawn(child.glow, ART.glow),
      "row")
    want(type(child.edge) == "table" and #child.edge == 4 and isType(child.icon, "Texture"), "row")
    want(isType(child.badge, "Texture") and isType(child.title, "FontString") and isType(child.sub, "FontString"), "row")

    for _, piece in ipairs(child.bg) do
      want(isType(piece, "Texture") and drawn(piece, ART.category), "row")
    end

    local rings = texturesOf(child, "ARTWORK", ART.ring)

    want(#rings == 1, "row.ring")

    return { row = child, ring = rings[1] }
  end

  local lines = texturesOf(child, "ARTWORK")

  want(isType(child.text, "FontString") and #lines == 1, "header")

  if isType(child, "Button") then
    want(isType(child.toggle, "Texture"), "header")
  end

  return { header = child, line = lines[1] }
end

function markOf(child)
  if child.spec and child.owner then
    return nil
  end

  if isType(child, "Button") then
    if child.bg ~= nil or child.glow ~= nil or child.edge ~= nil or child.badge ~= nil then
      return "row"
    end

    if isType(child.text, "FontString") and isType(child.toggle, "Texture") and #texturesOf(child, "ARTWORK") == 1 then
      return "header"
    end

    return nil
  end

  if isType(child, "Frame") and isType(child.text, "FontString") and #texturesOf(child, "ARTWORK") > 0 then
    return "header"
  end

  return nil
end

function Dress.listHeader(child)
  return markOf(child) == "header"
end

local function anyShown(pieces, key)
  for _, piece in ipairs(pieces) do
    if piece[key]:IsShown() then
      return true
    end
  end

  return false
end

local function scanList(frame, P)
  local scroll, content = frameOf(FRAME .. "Scroll"), frame.content

  want(isType(scroll, "ScrollFrame") and scroll == frame.scroll, "scroll")
  want(isType(content, "Frame") and (scroll:GetScrollChild() == content or EbonAPI.BoardPin.holds(content)), "content")
  want(isType(frame.emptyText, "FontString"), "emptyText")

  local bar = frameOf(FRAME .. "ScrollScrollBar")

  want(isType(bar, "Slider"), "scrollBar")

  local up, down = frameOf(FRAME .. "ScrollScrollBarScrollUpButton"), frameOf(FRAME .. "ScrollScrollBarScrollDownButton")
  local thumb = bar:GetThumbTexture()

  want(isType(up, "Button") and isType(down, "Button") and thumb ~= nil and drawn(thumb, ART.knob), "scrollBar")
  P.scroll = { scroll = scroll, bar = bar, up = up, down = down, thumb = thumb }
  P.content, P.emptyText = content, frame.emptyText
  P.rows, P.headers = {}, {}

  for _, child in ipairs({ content:GetChildren() }) do
    local piece = verified[child] or (markOf(child) and scanItem(child))

    if piece then
      verified[child] = piece

      if piece.row then
        P.rows[#P.rows + 1] = piece
      else
        P.headers[#P.headers + 1] = piece
      end
    end
  end

  if not frame.emptyText:IsShown() then
    local opened = false

    for _, piece in ipairs(P.headers) do
      if piece.header:IsShown() and piece.header.open ~= false then
        opened = true
      end
    end

    want(anyShown(P.headers, "header"), "header")

    if opened then
      want(anyShown(P.rows, "row"), "row")
    end
  end
end

local function scanPanel(frame, P)
  local panel = frame.panel

  want(isType(panel, "Frame"), "panel")

  local papers = texturesOf(panel, "BACKGROUND", ART.paper)
  local outlines = texturesOf(panel, "BORDER")

  want(#papers == 1 and #outlines == 12, "panel")
  bare(panel, "panel")
  want(isType(panel.art, "Texture"), "panel.art")
  want(isType(panel.title, "FontString") and isType(panel.desc, "FontString") and isType(panel.meta, "FontString"),
    "panel.texts")

  local strip, boxes = panel.strip, {}

  want(isType(strip, "Frame"), "panel.strip")

  for _, child in ipairs(original(panel).children) do
    if child ~= strip and isType(child, "Frame") then
      boxes[#boxes + 1] = child
    end
  end

  want(#boxes == 1 and #texturesOf(boxes[1], "OVERLAY", ART.frame) == 8, "panel.frame")
  want(type(panel.objectives) == "table" and #panel.objectives >= 1, "panel.objectives")
  want(type(panel.rewards) == "table" and #panel.rewards >= 1, "panel.rewards")
  want(isType(panel.money, "FontString"), "panel.money")

  local known, heads = { [panel.money] = true }, {}

  for _, text in ipairs(panel.objectives) do
    want(isType(text, "FontString"), "panel.objectives")
    known[text] = true
  end

  for _, text in ipairs(textsOf(strip)) do
    if not known[text] then
      heads[#heads + 1] = text
    end
  end

  local shades, rules = texturesOf(strip, "BACKGROUND"), texturesOf(strip, "BORDER")

  want(#heads == 2 and #shades == 1 and #rules == 1, "panel.strip")

  local rewards = {}

  for index, box in ipairs(panel.rewards) do
    local borders = isType(box, "Frame") and texturesOf(box, "OVERLAY", ART.quickslot) or {}

    want(#borders == 1 and isType(box.icon, "Texture") and isType(box.count, "FontString"), "panel.rewards")
    bare(box, "panel.rewards")
    rewards[index] = { box = box, border = borders[1] }
  end

  P.panel = {
    panel = panel, papers = papers, outlines = outlines, frame = boxes[1], strip = strip, heads = heads,
    shade = shades[1], rule = rules[1], rewards = rewards, action = panelButton(panel.action, "panel.action"),
    travel = travelButton(panel.travel),
  }
end

local function scanTabs(P)
  P.tabs = {}

  for index = 1, 20 do
    local name = FRAME .. "Tab" .. index
    local tab = frameOf(name)

    if not tab then
      break
    end

    local parts = {}

    want(isType(tab, "Button") and isType(frameOf(name .. "Text"), "FontString"), "tabs")

    for _, part in ipairs(TAB_PARTS) do
      local texture = frameOf(name .. part)

      want(isType(texture, "Texture") and drawn(texture, ART.tab), "tabs")
      parts[part] = texture
    end

    P.tabs[index] = { button = tab, parts = parts, text = frameOf(name .. "Text"), glow = tab:GetHighlightTexture() }
  end

  want(#P.tabs >= 1, "tabs")

  local zoneName = FRAME .. "TabStartZone"
  local zone = frameOf(zoneName)

  if zone and isType(zone, "Button") and isType(frameOf(zoneName .. "Text"), "FontString") then
    local zoneParts = {}
    local whole = true

    for _, part in ipairs(TAB_PARTS) do
      local texture = frameOf(zoneName .. part)

      whole = whole and isType(texture, "Texture") and drawn(texture, ART.tab)
      zoneParts[part] = texture
    end

    if whole then
      P.tabs[#P.tabs + 1] = { button = zone, parts = zoneParts, text = frameOf(zoneName .. "Text"), glow = zone:GetHighlightTexture() }
    end
  end
end

function scan(frame)
  local P = { frame = frame }

  scanFrame(frame, P)
  scanBand(frame, P)
  scanList(frame, P)
  scanPanel(frame, P)
  scanTabs(P)

  return P
end
end


local plate = nil
local overlays = {}
local looks = {}
local extras = {}
local natives = {}
local hooked = setmetatable({}, WEAK)
local hovered = setmetatable({}, WEAK)

local function recode(text)
  return (gsub(text, "|c[fF][fF](%x%x%x%x%x%x)", function(hex)
    local key = CODES[lower(hex)]

    if key then
      return Palette.code(key)
    end
  end))
end

local function recodeText(text)
  local value = text:GetText()
  local kept = memory[text]
  local entry = kept and kept.text

  if not value then
    return
  end

  local source = value

  if entry and entry.done and value == entry.mine and type(entry.orig) == "string" then
    source = entry.orig
  end

  local coded = recode(source)

  if coded ~= value then
    set(text, "text", coded)
  end
end

local function hide(region)
  if region and region:GetAlpha() ~= 0 then
    set(region, "alpha", 0)
  end
end

local function restyle(text, roleKey, key)
  local value = THEME[key] or THEME.text

  capture(text, "font", "shadow", "textColor")
  Bricks.font(text, S(roleKey))
  text:SetTextColor(value[1], value[2], value[3], value[4])
  commit(text, "font", "shadow", "textColor")
end

function Dress.guard(owner, fn, ...)
  local ok, result = pcall(fn, ...)

  if not ok then
    Lib.report(result, owner)
  end

  return ok, result
end

local function attempt(fn, ...)
  return (Dress.guard(OWNER, fn, ...))
end

local function hook(object, script, name, fn)
  local done = hooked[object]
  local key = script .. ":" .. name

  if not done then
    done = {}
    hooked[object] = done
  end

  if done[key] then
    return
  end

  done[key] = true
  object:HookScript(script, function(...)
    if dressed then
      attempt(fn, ...)
    end
  end)
end

local function skinTip()
  if not S("widgets.tooltip.skinned") or not GameTooltip or not GameTooltip.SetBackdropColor then
    return
  end

  local bg, border = THEME.bg, THEME.border

  GameTooltip:SetBackdropColor(bg[1], bg[2], bg[3], 1)
  GameTooltip:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function mute(frame)
  frame:EnableMouse(false)

  for _, child in ipairs({ frame:GetChildren() }) do
    mute(child)
  end
end
Dress.mute = mute

local function follow(button)
  hook(button, "OnEnter", "overlay", function(self)
    local widget = overlays[self]

    widget.hovered = true
    widget:Visual()
  end)
  hook(button, "OnLeave", "overlay", function(self)
    local widget = overlays[self]

    widget.hovered, widget.pressed = false, false
    widget:Visual()
  end)
  hook(button, "OnMouseDown", "overlay", function(self)
    local widget = overlays[self]

    widget.pressed = true
    widget:Visual()
  end)
  hook(button, "OnMouseUp", "overlay", function(self)
    local widget = overlays[self]

    widget.pressed = false
    widget:Visual()
  end)
end

local function overlay(button, slot)
  local widget = overlays[button]

  if not widget then
    widget = Bricks.create(slot, button)

    if slot == "tab" then
      widget:SetPadding(S("board.tab.padding"))
      widget.label:SetJustifyH("CENTER")
    end

    mute(widget)
    overlays[button] = widget
    follow(button)
  end

  widget:Show()

  return widget
end

local function wear(host, slot, guards, finish, dynamic)
  local fresh = not worn[host]
  local watched = fresh and guards or dynamic or {}

  for region, props in pairs(watched) do
    capture(region, unpack(props))
  end

  local look = looks[host]

  if not look then
    look = Bricks.create(slot, host)
    looks[host] = look
  elseif fresh then
    look:Dress()
  end

  worn[host] = true

  if finish then
    finish(look)
  end

  for region, props in pairs(watched) do
    commit(region, unpack(props))
  end

  return look
end

local function frameIt(frame, style, bgKey, borderKey)
  if not framed[frame] then
    framed[frame] = true
    Bricks.frame(frame, style, bgKey, borderKey)
  end
end

local function extra(key, build)
  local region = extras[key]

  if not region then
    region = build()
    extras[key] = region
  end

  region:Show()

  return region
end

local function conceal(region)
  hide(region)
  natives[#natives + 1] = region
end

local function lift(frame, by)
  frame:SetFrameLevel(frame:GetFrameLevel() + by)

  for _, child in ipairs({ frame:GetChildren() }) do
    lift(child, by)
  end
end

local function seat(button, widget, key, left, top, right, bottom, borderKey)
  local under = extra(button, function()
    local frame = CreateFrame("Frame", nil, button)

    frame:EnableMouse(false)

    return frame
  end)
  local level = button:GetFrameLevel() + 1
  local gap = level + 1 - widget:GetFrameLevel()

  frameIt(under, "small", S(key), S(borderKey or key))
  under:SetFrameLevel(level)

  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", button, "TOPLEFT", left, top)
  widget:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", right, bottom)
  widget:SetHeight(button:GetHeight() + top - bottom)
  under:ClearAllPoints()
  under:SetAllPoints(widget)

  if gap ~= 0 then
    lift(widget, gap)
  end
end

local function dressButton(piece)
  for _, part in ipairs(piece.parts) do
    hide(part)
  end

  conceal(piece.text)

  local widget = overlay(piece.button, "button")

  seat(piece.button, widget, "board.button.idle", 0, 0, 0, 0)
  widget:SetLabel(recode(piece.button:GetText() or ""))
  widget:SetDisabledState(not piece.button:IsEnabled())
end

local function newTravelIcon(owner, button, spec)
  local holder = CreateFrame("Frame", nil, button)
  local texture = holder:CreateTexture(nil, "OVERLAY")

  holder:EnableMouse(false)
  holder:SetWidth(spec.size)
  holder:SetHeight(spec.size)
  holder:SetPoint("LEFT", button, "LEFT", spec.x, 0)
  holder:SetFrameLevel(button:GetFrameLevel() + spec.level)
  texture:SetAllPoints(holder)
  holder.texture = texture

  function holder:SetPicture(path, trim, grey)
    self.texture:SetTexture(path)
    self.texture:SetTexCoord(trim, 1 - trim, trim, 1 - trim)
    self.texture:SetDesaturated(grey and true or false)

    return self
  end

  return holder
end

Kit.addKind("boardtravel", newTravelIcon)

local function dressTravel(piece)
  dressButton(piece)

  local icon = piece.icon
  local holder = extra(icon, function()
    return Kit.create(OWNER, "boardtravel", piece.button, {
      size = EbonAPI.Common.get("board.travelIconSize"),
      x = EbonAPI.Common.get("board.travelIconX"),
      level = EbonAPI.Common.get("board.travelIconLevel"),
    })
  end)

  holder:SetPicture(icon:GetTexture(), EbonAPI.Common.get("board.travelIconTrim"), not piece.button:IsEnabled())
  hide(icon)
end

local function dresses()
  return EbonAPI.Common.get("dress.replaceAll") or S("board.dress") and true or false
end

function Dress.replaceAll(on)
  EbonAPI.Common.set("dress.replaceAll", on and true or false)
end


local portraitPaths = setmetatable({}, { __mode = "k" })
local portraitListeners = {}

function Dress.portraitPath(texture)
  return portraitPaths[texture]
end

function Dress.onPortrait(listener)
  portraitListeners[#portraitListeners + 1] = listener
end

if type(hooksecurefunc) == "function" and type(SetPortraitToTexture) == "function" then
  hooksecurefunc("SetPortraitToTexture", function(texture, path)
    if type(path) ~= "string" or not texture then
      return
    end

    portraitPaths[texture] = path

    for index = 1, #portraitListeners do
      portraitListeners[index](texture, path)
    end
  end)
end

local function portraitSpec()
  return { size = S("board.pe.portrait.size"), inset = S("board.pe.portrait.inset"), round = false }
end

local function portraitPlace(box, frame)
  box:ClearAllPoints()
  box:SetPoint("TOPLEFT", frame, "TOPLEFT", S("board.pe.portrait.left"), S("board.pe.portrait.top"))
end

local function dressPortrait(P)
  local frame, native = P.frame, P.portrait
  local box = extra(native, function()
    local made = Kit.create(OWNER, "portrait", frame, portraitSpec())

    portraitPlace(made, frame)

    return made
  end)
  local path = Dress.portraitPath(native) or EbonAPI.Common.get("board.portraitIcon")

  frameIt(box, "flat", "card", "border")
  box:SetFrameLevel(frame:GetFrameLevel() + EbonAPI.Common.get("board.levelBox"))

  if path then
    box:SetIcon(path)
  end

  hide(native)
end

function Dress.middleOffset(object, frame)
  local top, bottom, base = object:GetTop(), object:GetBottom(), frame:GetTop()

  if top and bottom and base then
    return (top + bottom) / 2 - base
  end

  return 0
end

function Dress.controlsEdge()
  return S("window.padding") + S("header.inset")
end

local function dressTitle(P, keep)
  local texture, host = S("header.banner.texture"), P.title:GetParent()

  if texture ~= "" and host then
    local plaque = extra(P.title, function()
      return host:CreateTexture(nil, "ARTWORK")
    end)

    plaque:SetTexture(texture)
    plaque:SetWidth(S("header.banner.width"))
    plaque:SetHeight(S("header.banner.height"))
    plaque:ClearAllPoints()
    plaque:SetPoint("TOP", P.anchor or host, "TOP", 0, S("header.banner.y"))
  end

  local title = P.title

  restyle(title, "page.title.font", S("page.title.color"))

  if P.anchor then return end

  if S("header.title.align") == "CENTER" then
    return
  end

  set(title, "justify", "LEFT")

  if not keep then
    local y = Dress.middleOffset(title, P.frame)
    local x = Dress.controlsEdge()

    if S("header.controls") == "LEFT" then
      x = x + S("header.close.width") + S("header.spacing")
    end

    if P.clear then
      x = max(x, P.clear + EbonAPI.Common.get("journal.title.gap") + S("journal.title.gapAdd"))
    end

    set(title, "points", { n = 1, { "LEFT", P.frame, "TOPLEFT", x, y } })
  end
end

local function dressCross(P)
  for _, part in ipairs(P.cross.parts) do
    hide(part)
  end

  local button, frame = P.cross.button, P.frame
  local cross = overlay(button, "close")
  local left = S("header.controls") == "LEFT"
  local edge = Dress.controlsEdge()

  local side = left and "LEFT" or "RIGHT"
  local size = S("header.close.size")

  set(button, "width", size)
  set(button, "height", size)
  set(button, "points", { n = 1, { side, frame, left and "TOPLEFT" or "TOPRIGHT", left and edge or -edge, Dress.middleOffset(button, frame) } })
  cross:ClearAllPoints()
  cross:SetWidth(max(size, S("header.close.width")))
  cross:SetHeight(size)
  cross:SetPoint(side, button, side, 0, 0)
  cross:SetLabel(S("header.close.glyph"))
end

local function dressFrame(P)
  local frame = P.frame
  local level = max(0, frame:GetFrameLevel() - 1)

  if not plate then
    plate = CreateFrame("Frame", nil, frame)
    plate:SetAllPoints(frame)
    plate:SetFrameLevel(level)
    Bricks.frame(plate, STYLES[S("board.frame")], S("board.color"), S("board.border"))
    Bricks.decorate(plate)
    Bricks.shadow(plate)
  elseif plate:GetFrameLevel() ~= level then
    plate:SetFrameLevel(level)
    Bricks.relevel()
  end

  plate:Show()

  for _, region in ipairs(P.chrome) do
    hide(region)
  end

  dressPortrait(P)

  dressTitle(P, true)
  dressCross(P)
  dressButton(P.close)
  dressButton(P.claimAll)
  hook(P.claimAll.button, "OnEnter", "tip", skinTip)
end

local function dressBand(P)
  local band = P.bar

  restyle(P.cacheInfo, "board.note.font", S("board.note.color"))
  restyle(P.resets, "board.note.font", S("board.note.color"))
  recodeText(P.cacheInfo)
  recodeText(P.resets)
  hide(band.track)
  hide(band.border)

  if not band.bar.kitNative then
    local mine = bandBar

    if mine and mine.bar == band.bar then
      if band.bar.text == mine.before then
        band.bar.text = mine.kitText
      end
    else
      mine = { bar = band.bar, before = band.bar.text }
      bandBar = mine
    end

    Kit.create(OWNER, "progress", band.bar:GetParent(), { bar = band.bar })
    mine.kitText = band.bar.text

    if band.bar.text ~= band.text then
      band.bar.text:Hide()
      band.bar.text = band.text
    end

    band.bar.kitDraw = function() end
  end

  restyle(band.text, "board.note.font", S("board.text.color"))
  hook(band.bar, "OnEnter", "tip", skinTip)
end

local function dressScroll(P)
  local piece = P.scroll
  local look

  capture(piece.thumb, "texture", "coords", "width", "height", "vertex")
  capture(piece.bar, "width")
  look = Bricks.scrollOn(piece.bar)

  if look then
    if not look.dressed then
      look:Dress()
    else
      look:Refresh()
    end

    looks[piece.bar] = look
    worn[piece.bar] = true
  end

  commit(piece.thumb, "texture", "coords", "width", "height", "vertex")
  commit(piece.bar, "width")
end

local function badgeOf(texture)
  local path = lower(texture:GetTexture() or "")

  if find(path, "criteria%-check") then
    return "ready"
  elseif find(path, "dailyactivequesticon") then
    return "dailyActive"
  elseif find(path, "activequesticon") then
    return "active"
  elseif find(path, "dailyquesticon") then
    return "daily"
  elseif find(path, "availablequesticon") then
    return "take"
  end

  return nil
end

local function rowState(row, look)
  look:SetState(hovered[row] and true or false, row.edge[1]:IsShown() and true or false)
end

local function hover(row, state)
  hovered[row] = state or nil
  capture(row.title, "textColor")
  rowState(row, looks[row])
  commit(row.title, "textColor")
end

local function dressRow(piece)
  local row = piece.row

  for _, part in ipairs(row.bg) do
    hide(part)
  end

  for _, line in ipairs(row.edge) do
    hide(line)
  end

  if select(4, row.glow:GetVertexColor()) ~= 0 then
    set(row.glow, "vertex", list(0, 0, 0, 0))
  end

  hide(piece.ring)
  hide(row.badge)

  wear(row, "card", {
    [row.title] = { "font", "shadow", "textColor", "points" },
    [row.sub] = { "font", "shadow", "textColor", "points" },
    [row.icon] = { "width", "height", "points" },
  }, function(look)
    look:SetRound(true)
    look:SetBadge(badgeOf(row.badge))
    rowState(row, look)

    for region, props in pairs({ [row.icon] = { "width", "height", "points" }, [row.title] = { "points" },
        [row.sub] = { "points" } }) do
      for _, prop in ipairs(props) do
        local entry = memory[region] and memory[region][prop]

        if entry then
          SET[prop](region, entry.orig)
        end
      end
    end
  end, { [row.title] = { "textColor" } })
  recodeText(row.sub)
  hook(row, "OnEnter", "hover", function(self)
    hover(self, true)
  end)
  hook(row, "OnEnter", "cost", function()
    EbonAPI.Replace.tooltipCost(GameTooltip)
  end)
  if row.unlockBtn then
    hook(row.unlockBtn, "OnEnter", "cost", function()
      EbonAPI.Replace.tooltipCost(GameTooltip)
    end)
  end
  hook(row, "OnLeave", "hover", function(self)
    hover(self, false)
  end)
end

local function hostChevron(host, texture)
  host.glyph = texture or host.glyph
end

local function dressHeader(piece)
  local header = piece.header

  hide(piece.line)

  local sign = extra(header.toggle, function()
    local holder = CreateFrame("Frame", nil, header)

    holder:EnableMouse(false)
    holder:SetWidth(S("board.pe.toggle.size"))
    holder:SetHeight(S("board.pe.toggle.size"))
    holder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", S("board.pe.toggle.x"), S("board.pe.toggle.y"))

    return holder
  end)
  local path = peValue(header.toggle, "texture") or header.toggle:GetTexture() or ""

  hide(header.toggle)
  sign:SetFrameLevel(header:GetFrameLevel() + EbonAPI.Common.get("board.levelRow"))
  Lib.setShown(sign, header.toggle:IsShown())

  local look = wear(header, "cardHeader", { [header.text] = { "font", "shadow", "textColor" } })

  hostChevron(sign, look:Chevron(sign))
  look:SetOpen(find(lower(tostring(path)), "minus") and true or false)

  recodeText(header.text)

  if isType(header, "Button") then
    local function again(self)
      capture(self.text, "textColor")
      look:Dress()
      commit(self.text, "textColor")
    end

    hook(header, "OnEnter", "header", again)
    hook(header, "OnLeave", "header", again)
  end
end

local function offset(region)
  local point = peValue(region, "points")[1]

  if not point then
    return 0, 0
  end

  return -(point[5] or 0), point[4] or 0
end

local function relayout(P)
  local rowHeight, gap, headHeight = S("board.pe.row"), S("board.pe.gap"), S("board.pe.head")
  local items = {}

  for _, piece in ipairs(P.headers) do
    if piece.header:IsShown() then
      local y, x = offset(piece.header)

      items[#items + 1] = { region = piece.header, y = y, x = x, header = true }
    end
  end

  for _, piece in ipairs(P.rows) do
    if piece.row:IsShown() then
      local y, x = offset(piece.row)

      items[#items + 1] = { region = piece.row, y = y, x = x }
    end
  end

  if #items == 0 then
    return
  end

  table.sort(items, function(a, b)
    if a.y ~= b.y then
      return a.y < b.y
    end

    return a.header and not b.header
  end)

  local peRow, peHead, peGap

  for index, item in ipairs(items) do
    local own = peValue(item.region, "height")
    local following = items[index + 1]

    if item.header then
      peHead = peHead or own

      if peGap == nil and following and not following.header then
        peGap = following.y - item.y - own
      end
    else
      peRow = peRow or own
    end
  end

  if (peRow == nil or rowHeight == peRow) and (peHead == nil or headHeight == peHead)
      and (peGap == nil or gap == peGap) then
    return
  end

  local y = 0

  for index, item in ipairs(items) do
    if item.header then
      if index > 1 then
        y = y + 4
      end

      set(item.region, "points", { n = 1, list("TOPLEFT", P.content, "TOPLEFT", item.x, -y) })
      set(item.region, "height", headHeight)
      y = y + headHeight
    else
      set(item.region, "points", { n = 1, list("TOPLEFT", P.content, "TOPLEFT", item.x, -(y + gap)) })
      set(item.region, "height", rowHeight)
      y = y + rowHeight + gap
    end
  end

  if #items > 0 then
    y = y + 4
  end

  set(P.content, "height", max(1, y))
end

local function dressList(P)
  dressScroll(P)
  relayout(P)

  for _, piece in ipairs(P.headers) do
    if piece.header:IsShown() then
      dressHeader(piece)
    else
      recodeText(piece.header.text)
    end
  end

  for _, piece in ipairs(P.rows) do
    if piece.row:IsShown() then
      dressRow(piece)
    else
      recodeText(piece.row.sub)
    end
  end

  restyle(P.emptyText, "board.text.font", S("board.note.color"))
end

local function dressStrip(strip)
  frameIt(strip, "flat", S("board.strip.color"), S("board.strip.rule"))
end

local function dressPanel(P)
  local piece = P.panel
  local panel, strip = piece.panel, piece.strip

  for _, region in ipairs(piece.papers) do
    hide(region)
  end

  for _, region in ipairs(piece.outlines) do
    hide(region)
  end

  frameIt(panel, "small", S("board.panel.color"), S("board.panel.border"))
  hide(piece.frame)

  for _, region in ipairs({ piece.frame:GetRegions() }) do
    if isType(region, "Texture") then
      hide(region)
    end
  end

  do
    local picture = extra("picture", function()
      local box = CreateFrame("Frame", nil, panel)

      box:SetPoint("TOPLEFT", panel.art, "TOPLEFT", -S("board.pe.frame.margin"), S("board.pe.frame.margin"))
      box:SetPoint("BOTTOMRIGHT", panel.art, "BOTTOMRIGHT", S("board.pe.frame.margin"), -S("board.pe.frame.margin"))
      box:EnableMouse(false)

      return box
    end)

    if panel.map and panel.map.GetFrameLevel then
      picture:SetFrameLevel(panel.map:GetFrameLevel() + EbonAPI.Common.get("board.levelMap"))
    end

    wear(picture, "picture", {})
  end

  restyle(panel.title, "board.name.font", S("board.name.color"))
  restyle(panel.desc, "board.text.font", S("board.text.color"))
  restyle(panel.meta, "board.note.font", "meta")
  recodeText(panel.meta)
  hide(piece.shade)
  hide(piece.rule)
  dressStrip(strip)

  for _, head in ipairs(piece.heads) do
    restyle(head, "board.heading.font", S("board.heading.color"))
  end

  for _, text in ipairs(panel.objectives) do
    local done = peValue(text, "textColor")[1] < 0.9

    restyle(text, "board.text.font", S(done and "board.objective.done" or "board.text.color"))
  end

  for _, reward in ipairs(piece.rewards) do
    local box = reward.box

    hide(reward.border)
    wear(box, "slot", {
      [box.icon] = { "points", "coords" },
      [box.count] = { "font", "shadow", "textColor", "points" },
    })
    hook(box, "OnEnter", "tip", skinTip)
  end

  restyle(panel.money, "board.text.font", S("board.text.color"))
  recodeText(panel.money)
  EbonAPI.Replace.numberText(panel.money)
  dressButton(piece.action)
  dressTravel(piece.travel)
end

function Dress.paintUnder(piece, selected)
  Bricks.paint(piece, "SetBackdropColor", selected and "selected" or S("board.tab.idle"))
  Bricks.paint(piece, "SetBackdropBorderColor", selected and "selected" or S("board.tab.border"))
end

local function followTab(button, widget)
  if not hooked[widget] or not hooked[widget].follow then
    hooked[widget] = hooked[widget] or {}
    hooked[widget].follow = true

    hooksecurefunc(widget, "SetSelected", function(_, selected)
      local under = extras[button]

      if not dressed or not under or not under.SetBackdropColor then
        return
      end

      if not EbonAPI.Window.detached("nav") then
        return
      end

      attempt(Dress.paintUnder, under, selected)
    end)
  end
end

local tabSeat = {}

function tabSeat.edge(edge)
  return EbonAPI.Common.get("journal.tab.seat." .. edge) + (S("journal.tab.seat." .. edge .. "Add") or 0)
end

function tabSeat.edges()
  return tabSeat.edge("left"), tabSeat.edge("top"), tabSeat.edge("right"), tabSeat.edge("bottom")
end

function tabSeat.pad()
  return EbonAPI.Common.get("journal.tab.textPad") + (S("journal.tab.textPadAdd") or 0)
end

function tabSeat.step()
  local left, _, right = tabSeat.edges()

  return S("nav.tab.gap") - left + right
end

function tabSeat.margin()
  return tabSeat.pad() + S("board.tab.padding")
end

function tabSeat.fit(button, widget)
  local left, top, right, bottom = tabSeat.edges()
  local need = widget:TextWidth() + left - right + 2 * tabSeat.pad()
  local height = math.ceil(widget.label:GetStringHeight() or 0) + 2 * tabSeat.margin() - top + bottom

  if button:GetWidth() < need then
    button:SetWidth(need)
  end

  button:SetHeight(height)
end

local function dressTab(tab, button, label, selected)
  for _, part in pairs(tab.parts) do
    hide(part)
  end

  hide(tab.glow)
  conceal(tab.text)

  local widget = overlay(button, "tab")

  local left, top, right, bottom = tabSeat.edges()

  seat(button, widget, "board.tab.idle", left, top, right, bottom, "board.tab.border")
  followTab(button, widget)
  widget:SetLabel(label)
  tabSeat.fit(button, widget)
  widget:SetSelected(selected)
  hook(button, "OnEnter", "tip", skinTip)
end

local function dressTabs(P)
  for index, tab in ipairs(P.tabs) do
    if index > 1 then
      set(tab.button, "points", { n = 1, { "LEFT", P.tabs[index - 1].button, "RIGHT", tabSeat.step(), 0 } })
    end

    dressTab(tab, tab.button, recode(tab.button:GetText() or ""), tab.parts.LeftDisabled:IsShown())
  end
end

local function dressPages()
  for _, page in ipairs(pages) do
    dressTab(page.tab, page.tab, page.tab:GetText() or "", page == shownPage)

    hide(page.paper)

    frameIt(page.detail, "small", S("board.panel.color"), S("board.panel.border"))
  end
end

local function undressBand()
  local mine = bandBar

  if not mine or not mine.bar then
    return
  end

  local bar = mine.bar

  if type(bar.Undress) == "function" then
    if mine.kitText then
      bar.text = mine.kitText
    end

    local text = mine.before
    local shown = text and text.IsShown and text:IsShown()

    pcall(bar.Undress, bar)
    bar.text = text

    if shown and text.Show then
      text:Show()
    end
  end
end

local function undress()
  dressed = false
  undressBand()

  if plate then
    plate:Hide()
  end

  for _, widget in pairs(overlays) do
    widget:Hide()
  end

  for host, look in pairs(looks) do
    if worn[host] then
      attempt(look.Undress, look)

      worn[host] = nil
    end
  end

  for frame in pairs(framed) do
    Bricks.unframe(frame)
    framed[frame] = nil
  end

  for _, region in pairs(extras) do
    region:Hide()
  end

  restore()
  tilesRelease()
end

local function cut(piece)
  attempt(undress)

  state, reason = "cut", piece
  Log.trace("dress", OWNER, "Hero's Call Board not dressed: the piece " .. tostring(piece) .. " is not as known")
end

local function dressAll(P)
  dressed = true
  natives = {}
  dressFrame(P)
  dressBand(P)
  dressList(P)
  dressPanel(P)
  dressTabs(P)
  dressPages()
  tilesApply(P)
end

local function settle()
  if not dressed then
    return
  end

  local again = 0

  for _, region in ipairs(natives) do
    if region:GetAlpha() ~= 0 then
      hide(region)
      again = again + 1
    end
  end

  if again > 0 then
    Log.trace("dress", OWNER, "native texts of the board shown again after the dress, hidden again: " .. again)
  end
end

local function pass()
  local frame = frameOf(FRAME)

  if not frame or state == "cut" then
    return
  end

  if held then
    state = "held"
    return
  end

  if not dresses() then
    state = "skin"
    tilesRelease()
    return
  end

  local ok, P = pcall(scan, frame)

  if not ok then
    if type(P) == "table" then
      cut(P.piece)
    else
      Lib.report(P, OWNER)
      cut("error")
    end

    return
  end

  if not Dress.guard(OWNER, dressAll, P) then
    cut("error")
    return
  end

  state, reason = "dressed", nil
  Bus.after("EbonAPI:dress.natives", 0.1, settle)
end


local function pack(...)
  return { n = select("#", ...), ... }
end

function Dress.after(owner, path, key, fn)
  return owner:HookEbonhold(path, key, function(originalFn, ...)
    local results = pack(originalFn(...))
    Dress.guard(owner.addonName, fn, ...)

    return unpack(results, 1, results.n)
  end)
end

local function record(frame)
  original(frame)

  for _, child in ipairs({ frame:GetChildren() }) do
    record(child)
  end
end

local function birth(frame)
  if born[frame] then
    return
  end

  born[frame] = true
  record(frame)
  EbonAPI:Emit("CALLBOARD_UI_CREATED", frame)
end

local function afterShow()
  local frame = frameOf(FRAME)

  if frame then
    birth(frame)
  end
end

local function passAndTell(frame)
  applyPages()
  pass()
  EbonAPI:Emit("CALLBOARD_UI_REFRESHED", frame)
end

local function afterRefresh()
  local frame = frameOf(FRAME)

  if not frame then
    return
  end

  birth(frame)

  if not frame:IsShown() then
    return
  end

  passAndTell(frame)
end

local function afterTimers()
  local frame = frameOf(FRAME)

  if dressed and frame and frame:IsShown() and isType(frame.resets, "FontString") then
    recodeText(frame.resets)
  end
end

local function redress()
  local frame = frameOf(FRAME)

  if dressed and frame and frame:IsShown() then
    passAndTell(frame)
  end
end

local function install()
  Bus.offCore("PLAYER_LOGIN", install)

  if installed then
    return
  end

  installed = true

  local ok = Dress.after(handle, "CallboardUI", "Refresh", afterRefresh)

  if not ok then
    state = "absent"
    return
  end

  Dress.after(handle, "CallboardUI", "Show", afterShow)
  Dress.after(handle, "CallboardUI", "RefreshTimers", afterTimers)
end

Bus.onCore("PLAYER_LOGIN", install)

EbonAPI:On("PARAMETER_CHANGED", function()
  Bus.after("EbonAPI:dress", 0.01, redress)
end)

EbonAPI:DeclareSticky("CALLBOARD_UI_CREATED")


function Dress.state()
  if state == "cut" or state == "absent" then
    return state, reason
  end

  if held then
    return "held", nil
  end

  if not dresses() then
    return "skin", nil
  end

  if state ~= "dressed" or not frameOf(FRAME) then
    return "waiting", nil
  end

  return "dressed", nil
end

function Dress.hold()
  local was = dressed

  held = true
  undress()

  if state ~= "cut" and state ~= "absent" then
    state = "held"
  end

  local frame = frameOf(FRAME)

  if was and frame and frame:IsShown() then
    EbonAPI:Emit("CALLBOARD_UI_REFRESHED", frame)
  end
end

function Dress.release()
  held = false

  if state == "held" then
    state = "waiting"
  end

  local frame = frameOf(FRAME)

  if frame and frame:IsShown() then
    passAndTell(frame)
  end
end

function Dress.touched()
  return #order
end


local TAB_FIELDS = {
  text = { string = true, ["function"] = true },
  key = { string = true },
  tip = { string = true, ["function"] = true },
  tipKey = { string = true },
  onSelect = { ["function"] = true },
  onLeave = { ["function"] = true },
}

do
local function rightAt(region, item, inset)
  local points, out = GET.points(region), { n = 0 }

  for index = 1, points.n do
    if points[index][1] ~= "RIGHT" then
      out.n = out.n + 1
      out[out.n] = points[index]
    end
  end

  out.n = out.n + 1
  out[out.n] = list("RIGHT", item, "RIGHT", -inset, 0)

  return out
end

function Dress.inset(row, inset)
  local frame = frameOf(FRAME)

  if not frame or type(inset) ~= "number" or inset < 0 or not isType(row, "Button") or markOf(row) ~= "row"
      or row:GetParent() ~= frame.content or not isType(row.title, "FontString") or not isType(row.sub, "FontString") then
    return false
  end

  local look = worn[row] and looks[row]

  if look then
    capture(row.title, "points")
    capture(row.sub, "points")
    look:SetInset(inset)
    commit(row.title, "points")
    commit(row.sub, "points")
  else
    set(row.title, "points", rightAt(row.title, row, inset))
    set(row.sub, "points", rightAt(row.sub, row, inset))
  end

  return true
end

function Dress.headerInset(header, inset)
  local frame = frameOf(FRAME)

  if not frame or type(inset) ~= "number" or inset < 0 or not (isType(header, "Frame") or isType(header, "Button"))
      or markOf(header) ~= "header"
      or header:GetParent() ~= frame.content then
    return false
  end

  local lines = texturesOf(header, "ARTWORK")

  if #lines ~= 1 then
    return false
  end

  local look = worn[header] and looks[header]

  if look then
    look:SetInset(inset)
  else
    set(lines[1], "points", rightAt(lines[1], header, inset))
  end

  EbonAPI.BoardPin.touched(header)

  return true
end


local TAB_TEXT_MAX = EbonAPI.Common.get("board.tabTextMax")
local LIST_BAR = EbonAPI.Common.get("board.listBar")

local made = 0
local covered = false
local watched = setmetatable({}, WEAK)

local function boardTabs()
  local out = {}

  for index = 1, 20 do
    local tab = frameOf(FRAME .. "Tab" .. index)

    if not tab then
      break
    end

    out[index] = tab
  end

  local startZone = frameOf(FRAME .. "TabStartZone")

  if startZone then
    out[#out + 1] = startZone
  end

  return out
end


local GROUP = "callboard"
local IDS = {
  header = "callboard.header", list = "callboard.list", detail = "callboard.detail",
  actions = "callboard.actions", nav = "callboard.nav",
}
local KINDS = { "header", "list", "detail", "actions", "nav" }
local geo, owed, waiter, linked = nil, false, nil, false
local hosts = {}
local engaged = { header = false, list = false, detail = false, actions = false, nav = false }
local rehomed = { header = {}, list = {}, detail = {}, actions = {}, nav = {} }
local mouseWas = nil

local function inCombat()
  return InCombatLockdown and InCombatLockdown() and true or false
end

local function rehome(kind, region, frame, tile)
  local map = rehomed[kind]

  if not map[region] then
    map[region] = GET.points(region)
  end

  local points = GET.points(region)

  for index = 1, points.n do
    if points[index][2] == frame or points[index][2] == nil then
      points[index][2] = tile
    end
  end

  SET.points(region, points)
end

local function giveBack(map)
  for region, points in pairs(map) do
    SET.points(region, points)
    map[region] = nil
  end
end

-- Strate et niveau de l'hote derives de sa fenetre (racine) : a la creation et a chaque passage devant de la racine
-- (Windows.follow), pour que l'hote suive la fenetre ouverte ou cliquee en dernier.
local function host(kind, frame)
  local tile = hosts[kind]

  local function align(piece, root)
    local level = max(0, root:GetFrameLevel() - 1)

    piece:SetFrameStrata(root:GetFrameStrata())

    if piece:GetFrameLevel() ~= level then
      piece:SetFrameLevel(level)
      Bricks.relevel()
    end
  end

  if not tile then
    tile = CreateFrame("Frame", nil, frame)
    tile:EnableMouse(true)
    Bricks.frame(tile, STYLES[S("board.frame")], S("board.color"), S("board.border"))
    Bricks.decorate(tile)
    Bricks.shadow(tile)
    hosts[kind] = tile

    if EbonAPI.Windows and EbonAPI.Windows.follow then
      EbonAPI.Windows.follow(frame, function(root)
        align(tile, root)
      end)
    end
  end

  align(tile, frame)

  return tile
end

EbonAPI.DressPieces = {
  overlay = overlay,
  wear = wear,
  seat = seat,
  SetLabel = function(widget, text)
    return widget:SetLabel(text)
  end,
  SetSelected = function(widget, selected)
    return widget:SetSelected(selected)
  end,
  tile = host,
  title = dressTitle,
  cross = dressCross,
  dressTabs = dressTabs,
  dressPages = dressPages,
}

local rectOf

rectOf = function(frame, region)
  local fl, ft, rl, rt = frame:GetLeft(), frame:GetTop(), region:GetLeft(), region:GetTop()
  local w, h = region:GetWidth() or 0, region:GetHeight() or 0

  if fl and ft and rl and rt then
    return { x = rl - fl, y = rt - ft, w = w, h = h }
  end

  local point, relativeTo, relativePoint, x, y = region:GetPoint(1)

  if not point then
    return { x = 0, y = 0, w = w, h = h }
  end

  relativePoint = relativePoint or point

  local bx, by, bw, bh = 0, 0, frame:GetWidth(), frame:GetHeight()

  if relativeTo and relativeTo ~= frame and relativeTo ~= region and relativeTo.GetPoint and relativeTo.GetWidth then
    local r = rectOf(frame, relativeTo)

    bx, by, bw, bh = r.x, r.y, r.w, r.h
  end

  local fx = bx + (find(relativePoint, "LEFT", 1, true) and 0 or (find(relativePoint, "RIGHT", 1, true) and bw or bw / 2))
  local fy = by + (find(relativePoint, "TOP", 1, true) and 0 or (find(relativePoint, "BOTTOM", 1, true) and -bh or -bh / 2))
  local left = fx + (x or 0) - (find(point, "LEFT", 1, true) and 0 or (find(point, "RIGHT", 1, true) and w or w / 2))
  local top = fy + (y or 0) + (find(point, "TOP", 1, true) and 0 or (find(point, "BOTTOM", 1, true) and h or h / 2))

  return { x = left, y = top, w = w, h = h }
end

local function partsOf(P)
  return {
    list = { P.scroll.scroll },
    detail = { P.panel.panel },
    actions = { P.claimAll.button, P.close.button },
  }
end

local function measure(P)
  local frame = P.frame
  local band = nil

  for _, part in ipairs({ P.scroll.scroll, P.panel.panel }) do
    local _, _, _, _, y = part:GetPoint(1)

    if y and (band == nil or -y < band) then
      band = -y
    end
  end

  local out = {
    width = frame:GetWidth(), height = frame:GetHeight(), left = frame:GetLeft(), top = frame:GetTop(),
    band = band or 0, tab = GET.points(boardTabs()[1]), rect = {}, box = {},
  }

  for kind, parts in pairs(partsOf(P)) do
    local x1, y1, x2, y2 = nil, nil, nil, nil
    local more = { unpack(parts) }

    if kind == "list" and P.scroll.bar then
      more[#more + 1] = P.scroll.bar
    end

    for _, part in ipairs(more) do
      local r = rectOf(frame, part)

      if part ~= P.scroll.bar then
        out.rect[part] = r
      end

      x1 = x1 and math.min(x1, r.x) or r.x
      y1 = y1 and math.max(y1, r.y) or r.y
      x2 = x2 and max(x2, r.x + r.w) or r.x + r.w
      y2 = y2 and math.min(y2, r.y - r.h) or r.y - r.h
    end

    out.box[kind] = { x = x1, y = y1, w = x2 - x1, h = y1 - y2 }
  end

  return out
end

local function size(kind)
  local pad = S("window.padding")

  return geo.box[kind].w + 2 * pad, geo.box[kind].h + 2 * pad
end

local function firstPlace(kind)
  local gap = S("windows.gap")
  local listW = engaged.list and size("list") or 0
  local top = geo.top - (geo.band + gap)
  local rows = 0

  if engaged.list then
    rows = select(2, size("list"))
  end

  if engaged.detail then
    rows = max(rows, select(2, size("detail")))
  end

  local x, y = geo.left, top

  if kind == "detail" and engaged.list then
    x = x + listW + gap
  elseif kind == "actions" then
    y = top - (rows > 0 and (rows + gap) or 0)
  elseif kind == "nav" then
    y = top - (rows > 0 and (rows + gap) or 0)

    if engaged.actions then
      y = y - select(2, size("actions")) - gap
    end
  end

  return x, y
end

local function followTitle(P, tile)
  local frame, title = P.frame, P.title
  local plaque, seat = extras[title], title:GetParent()
  local left, top, wanted, wantedTop = tile:GetLeft(), tile:GetTop(), frame:GetLeft(), frame:GetTop()
  local home = not (left and top and wanted and wantedTop) or (abs(left - wanted) < 1 and abs(top - wantedTop) < 1)

  if home then
    if rehomed.header[title] then
      SET.points(title, rehomed.header[title])
    end

    if plaque and rehomed.header[plaque] then
      SET.points(plaque, rehomed.header[plaque])
    end
  else
    rehome("header", title, frame, tile)

    if plaque and seat then
      rehome("header", plaque, seat, tile)
    end
  end
end

local function engageHeader(P)
  local frame = P.frame
  local tile = host("header", frame)
  local first = not engaged.header
  local parts = { P.title, P.cacheInfo, P.resets, P.cross.button, P.bar.bar, extras.portrait }

  if first then
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  end

  tile:SetWidth(geo.width)
  tile:SetHeight(geo.band)

  for _, part in ipairs(parts) do
    rehome("header", part, frame, tile)
  end

  if extras[P.title] and P.title:GetParent() then
    rehome("header", extras[P.title], P.title:GetParent(), tile)
  end

  if first then
    EbonAPI.Windows.apply(IDS.header, tile, GROUP, true, function(self)
      if geo.left and geo.top then
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", geo.left, geo.top)
      else
        self:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
      end
    end)
    engaged.header = true
    tile:HookScript("OnDragStop", function()
      followTitle(P, tile)
    end)
  end

  followTitle(P, tile)
  tile:Show()
end

local function engagePart(kind, P)
  local frame = P.frame
  local tile = host(kind, frame)
  local first = not engaged[kind]
  local pad = S("window.padding")
  local box = geo.box[kind]
  local ox, oy = box.x - pad, box.y + pad
  local width, height = size(kind)

  tile:SetWidth(width)
  tile:SetHeight(height)

  if first then
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", frame, "TOPLEFT", ox, oy)
  end

  for _, part in ipairs(partsOf(P)[kind]) do
    if not rehomed[kind][part] then
      rehomed[kind][part] = GET.points(part)
    end

    SET.points(part, { n = 1, { "TOPLEFT", tile, "TOPLEFT", geo.rect[part].x - ox, geo.rect[part].y - oy } })
  end

  if first then
    engaged[kind] = true
    EbonAPI.Windows.apply(IDS[kind], tile, GROUP, true, function(self)
      if geo.left and geo.top then
        local x, y = firstPlace(kind)

        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
      else
        self:SetPoint("TOPLEFT", frame, "TOPLEFT", ox, oy)
      end
    end)
  end

  tile:Show()
end

local function engageNav(P)
  local frame = P.frame
  local tile = host("nav", frame)
  local first = not engaged.nav
  local pad = S("window.padding")
  local tabs = boardTabs()
  local origin = geo.tab[1]

  if first then
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", (origin[4] or 0) - pad, (origin[5] or 0) + pad)
  end

  for _, page in ipairs(pages) do
    tabs[#tabs + 1] = page.tab
  end

  local width, height, count = 0, 0, 0

  for _, tab in ipairs(tabs) do
    if tab:IsShown() then
      width = width + tab:GetWidth() + (count > 0 and tabSeat.step() or 0)
      height = max(height, tab:GetHeight())
      count = count + 1
    end
  end

  tile:SetWidth(width + 2 * pad)
  tile:SetHeight(height + 2 * pad)

  if not rehomed.nav[tabs[1]] then
    rehomed.nav[tabs[1]] = geo.tab
  end

  SET.points(tabs[1], { n = 1, { "TOPLEFT", tile, "TOPLEFT", pad, -pad } })

  if first then
    engaged.nav = true
    EbonAPI.Windows.apply(IDS.nav, tile, GROUP, true, function(self)
      if geo.left and geo.top then
        local x, y = firstPlace("nav")

        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
      else
        self:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", (origin[4] or 0) - pad, (origin[5] or 0) + pad)
      end
    end)
  end

  tile:Show()
end

local function leaveKind(kind)
  giveBack(rehomed[kind])
  EbonAPI.Windows.apply(IDS[kind], hosts[kind], GROUP, false)
  hosts[kind]:Hide()
  engaged[kind] = false
end

local function anyEngaged()
  for _, kind in ipairs(KINDS) do
    if engaged[kind] then
      return true
    end
  end

  return false
end

local function shell(frame, on)
  if on and mouseWas == nil then
    mouseWas = frame:IsMouseEnabled() and true or false
    frame:EnableMouse(false)
  elseif not on and mouseWas ~= nil then
    frame:EnableMouse(mouseWas)
    mouseWas = nil
  end
end

local function watch()
  if waiter then
    return
  end

  waiter = CreateFrame("Frame")
  waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
  waiter:SetScript("OnEvent", function()
    if not owed then
      return
    end

    local frame = frameOf(FRAME)
    attempt(function()
      if dressed and frame and frame:IsShown() then
        redress()
      else
        tilesRelease()
      end
    end)
  end)
end

local function link(frame)
  if linked then
    return
  end

  linked = true
  frame:HookScript("OnShow", function()
    for _, kind in ipairs(KINDS) do
      local tile = hosts[kind]

      if tile and engaged[kind] then
        tile:Show()
      end
    end
  end)
  frame:HookScript("OnHide", function()
    for _, kind in ipairs(KINDS) do
      local tile = hosts[kind]

      if tile and engaged[kind] then
        tile:Hide()
      end
    end
  end)
end

tilesApply = function(P)
  local wanted = EbonAPI.Window.detachedAll()

  if not (wanted.header or wanted.nav or wanted.page or geo) then
    return
  end

  if inCombat() then
    owed = true
    watch()
    return
  end

  owed = false

  if not geo then
    geo = measure(P)
  end

  link(P.frame)

  if wanted.header then
    engageHeader(P)
  elseif engaged.header then
    leaveKind("header")
  end

  for _, kind in ipairs({ "list", "detail", "actions" }) do
    if wanted.page then
      engagePart(kind, P)
    elseif engaged[kind] then
      leaveKind(kind)
    end
  end

  if wanted.page then
    shell(P.frame, true)

    if plate then
      plate:Hide()
    end
  else
    shell(P.frame, false)
  end

  if wanted.nav then
    engageNav(P)
  elseif engaged.nav then
    leaveKind("nav")
  end

  if not anyEngaged() then
    geo = nil
  end
end

tilesRelease = function()
  if not geo then
    return
  end

  if inCombat() then
    owed = true
    watch()
    return
  end

  owed = false

  local frame = frameOf(FRAME)

  for _, kind in ipairs(KINDS) do
    if engaged[kind] then
      leaveKind(kind)
    end
  end

  if frame then
    shell(frame, false)
  end

  geo = nil
end

local function skinApplied()
  local frame = frameOf(FRAME)

  if dressed and frame and frame:IsShown() then
    passAndTell(frame)
  elseif geo then
    tilesRelease()
  end
end

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Skins, "resolve", function()
    pcall(skinApplied)
  end)

  if Bricks.apply then
    hooksecurefunc(Bricks, "apply", function()
      pcall(skinApplied)
    end)
  end
end

local function tabLook(tab, selected)
  local name = tab:GetName()

  for _, part in ipairs({ "Left", "Middle", "Right" }) do
    local idle, chosen = frameOf(name .. part), frameOf(name .. part .. "Disabled")

    if idle and chosen then
      if selected then
        idle:Hide()
        chosen:Show()
      else
        idle:Show()
        chosen:Hide()
      end
    end
  end

  tab:SetNormalFontObject(selected and GameFontHighlightSmall or GameFontNormalSmall)
end

local function sizeTab(tab)
  local text = tab.text
  local width = text:GetStringWidth() or 0

  text:SetWidth(width > TAB_TEXT_MAX and TAB_TEXT_MAX or 0)

  local middle = max(EbonAPI.Common.get("board.tabMiddleMin"), math.min(TAB_TEXT_MAX, width) + EbonAPI.Common.get("board.tabTextPad"))

  tab.parts.Middle:SetWidth(middle)
  tab.parts.MiddleDisabled:SetWidth(middle)
  tab:SetWidth(middle + EbonAPI.Common.get("board.tabOuterPad"))

  if overlays[tab] then
    tabSeat.fit(tab, overlays[tab])
  end
end

local function call(page, name)
  local fn = page.fields[name]

  if fn then
    Dress.guard(page.owner, fn, page)
  end
end

local function textOf(page, field, keyField)
  local fields = page.fields

  if fields[keyField] then
    return EbonAPI.Kit.localized(page.owner, fields[keyField])
  end

  local value = fields[field]

  if type(value) == "function" then
    local ok, result = Dress.guard(page.owner, value, page)

    if not ok then
      return nil
    end

    value = result
  end

  return value ~= nil and tostring(value) or nil
end

applyPages = function()
  local frame = frameOf(FRAME)

  if not frame or #pages == 0 then
    return
  end

  local page = shownPage

  if page then
    for _, tab in ipairs(boardTabs()) do
      tabLook(tab, false)
    end
  end

  for _, each in ipairs(pages) do
    local label = textOf(each, "text", "key") or ""

    if each.tab:GetText() ~= label then
      each.tab:SetText(label)
    end

    sizeTab(each.tab)
    tabLook(each.tab, each == page)

    if each == page then
      each:Show()
    else
      each:Hide()
    end
  end

  if page then
    frame.scroll:Hide()
    frame.panel:Hide()
    covered = true

    local picker = Ebonhold.CallboardStartZone()

    if type(picker) == "table" and type(picker.Hide) == "function" then
      picker.Hide()
    end
  elseif covered then
    frame.scroll:Show()
    frame.panel:Show()
    covered = false
  end
end

local function redressShown()
  local frame = frameOf(FRAME)

  if frame and frame:IsShown() then
    passAndTell(frame)
  else
    applyPages()
  end
end

local function choose(page)
  shownPage = page
  applyPages()
  call(page, "onSelect")
  redressShown()
end

local function leave()
  local page = shownPage

  if not page then
    return
  end

  shownPage = nil
  applyPages()
  call(page, "onLeave")

  local ui = Ebonhold.CallboardUI()

  if type(ui) == "table" and type(ui.Refresh) == "function" then
    ui.Refresh()
  end
end

local function watchBoardTabs()
  for _, tab in ipairs(boardTabs()) do
    if not watched[tab] then
      watched[tab] = true
      tab:HookScript("OnClick", function()
        attempt(leave)
      end)
    end
  end
end

local function placeTabs()
  local tabs = boardTabs()
  local previous = tabs[#tabs]

  for _, page in ipairs(pages) do
    page.tab:ClearAllPoints()
    page.tab:SetPoint("LEFT", previous, "RIGHT", tabSeat.step(), 0)
    previous = page.tab
  end
end

Kit.addKind("boardpaper", function(owner, detail)
  local holder = CreateFrame("Frame", nil, detail)
  local background = holder:CreateTexture(nil, "BACKGROUND")

  holder:EnableMouse(false)
  holder:SetAllPoints(detail)
  background:SetAllPoints(holder)
  background:SetTexture(EbonAPI.Common.get("board.paperTexture"))
  background:SetTexCoord(0, EbonAPI.Common.get("board.paperWidth") / EbonAPI.Common.get("board.paperFileWidth"), 0, 1)

  local dark, light = EbonAPI.Common.get("board.paperLineDark"), EbonAPI.Common.get("board.paperLineLight")

  for _, line in ipairs({ { 0, dark[1], dark[2], dark[3] }, { 1, dark[1], dark[2], dark[3] }, { 2, light[1], light[2], light[3] } }) do
    local inset = line[1]
    local sides = {
      { "TOPLEFT", inset, -inset, "TOPRIGHT", -inset, -inset, "height" },
      { "BOTTOMLEFT", inset, inset, "BOTTOMRIGHT", -inset, inset, "height" },
      { "TOPLEFT", inset, -inset, "BOTTOMLEFT", inset, inset, "width" },
      { "TOPRIGHT", -inset, -inset, "BOTTOMRIGHT", -inset, inset, "width" },
    }

    for _, side in ipairs(sides) do
      local texture = holder:CreateTexture(nil, "BORDER")

      texture:SetTexture(line[2], line[3], line[4], 1)
      texture:SetPoint(side[1], holder, side[1], side[2], side[3])
      texture:SetPoint(side[4], holder, side[4], side[5], side[6])

      if side[7] == "height" then
        texture:SetHeight(EbonAPI.Common.get("board.paperLineThickness"))
      else
        texture:SetWidth(EbonAPI.Common.get("board.paperLineThickness"))
      end
    end
  end

  return holder
end)

local function paper(detail)
  return Kit.create(OWNER, "boardpaper", detail, {})
end

local Page = {}

function Page:Select()
  choose(self)

  return self
end

function Page:IsSelected()
  return shownPage == self
end

function Page:Release()
  if shownPage == self then
    leave()
  end

  for index, page in ipairs(pages) do
    if page == self then
      table.remove(pages, index)
      break
    end
  end

  for _, region in ipairs({ overlays[self.tab] or false, extras[self.tab] or false, self.tab, self }) do
    if region then
      region:Hide()
    end
  end

  placeTabs()
end

local function newPage(owner, fields)
  local frame = frameOf(FRAME)
  local tabs = boardTabs()

  if not isType(frame, "Frame") or not isType(frame.scroll, "ScrollFrame") or not isType(frame.panel, "Frame")
      or #tabs == 0 then
    return nil
  end

  made = made + 1

  local name = "EbonAPIBoardTab" .. made
  local tab = CreateFrame("Button", name, frame, "CharacterFrameTabButtonTemplate")
  local page = CreateFrame("Frame", nil, frame)

  page.owner, page.fields, page.tab = owner, fields, tab
  page:SetPoint("TOPLEFT", frame.scroll, "TOPLEFT", 0, 0)
  page:SetPoint("BOTTOMRIGHT", frame.panel, "BOTTOMRIGHT", 0, 0)
  page:Hide()
  page.list = CreateFrame("Frame", nil, page)
  page.list:SetPoint("TOPLEFT", frame.scroll, "TOPLEFT", 0, 0)
  page.list:SetPoint("BOTTOMRIGHT", frame.scroll, "BOTTOMRIGHT", LIST_BAR, 0)
  page.bar = CreateFrame("Frame", nil, page.list)
  page.bar:SetWidth(LIST_BAR)
  page.bar:SetPoint("TOPRIGHT", page.list, "TOPRIGHT", 0, 0)
  page.bar:SetPoint("BOTTOMRIGHT", page.list, "BOTTOMRIGHT", 0, 0)
  page.detail = CreateFrame("Frame", nil, page)
  page.detail:SetAllPoints(frame.panel)
  page.paper = paper(page.detail)

  for method, fn in pairs(Page) do
    page[method] = fn
  end

  tab.parts = {}

  for _, part in ipairs(TAB_PARTS) do
    tab.parts[part] = frameOf(name .. part)
  end

  tab.text, tab.glow = frameOf(name .. "Text"), tab:GetHighlightTexture()
  tab:SetHeight(EbonAPI.Common.get("board.tabHeight"))
  tab:SetScript("OnShow", sizeTab)
  tab:SetScript("OnEvent", sizeTab)
  tab:SetScript("OnClick", function()
    PlaySound("igCharacterInfoTab")
    choose(page)
  end)
  tab:SetScript("OnEnter", function(self)
    local body = textOf(page, "tip", "tipKey")

    if body then
      Bricks.tip(self, textOf(page, "text", "key"), body)
    end
  end)
  tab:SetScript("OnLeave", Bricks.hideTip)

  pages[#pages + 1] = page
  placeTabs()
  watchBoardTabs()
  applyPages()

  Bus.after("EbonAPI:dress.tab", 0.01, function()
    if dressed then
      redressShown()
    end
  end)

  return page
end

function Dress.tab(owner, fields)
  return newPage(owner, fields)
end
end

function Handle:BoardTab(fields)
  local owner = self.addonName

  if type(fields) ~= "table" then
    error(format("EbonAPI: %s: api:BoardTab expects a table, got %s", owner, type(fields)), 2)
  end

  for field, value in pairs(fields) do
    local kinds = TAB_FIELDS[field]

    if not kinds then
      error(format('EbonAPI: %s: api:BoardTab does not know the field "%s"', owner, tostring(field)), 2)
    end

    if not kinds[type(value)] then
      error(format('EbonAPI: %s: api:BoardTab field "%s" does not take %s', owner, tostring(field), type(value)), 2)
    end
  end

  return Dress.tab(owner, fields)
end

function EbonAPI:BoardDress()
  return Dress.state()
end

function Handle:BoardDress()
  return Dress.state()
end

function EbonAPI:BoardRowInset(row, inset)
  return Dress.inset(row, inset)
end

function Handle:BoardRowInset(row, inset)
  return Dress.inset(row, inset)
end

function EbonAPI:BoardHeaderInset(header, inset)
  return Dress.headerInset(header, inset)
end

function Handle:BoardHeaderInset(header, inset)
  return Dress.headerInset(header, inset)
end
