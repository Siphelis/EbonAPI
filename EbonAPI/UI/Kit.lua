EbonAPI = EbonAPI or {}
EbonAPI.Kit = {}

local Kit = EbonAPI.Kit
local Lib = EbonAPI.Lib
local Bus = EbonAPI.Bus
local DB = EbonAPI.DB
local Format = EbonAPI.Format
local Locale = EbonAPI.Locale
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Bricks = EbonAPI.Bricks
local Windows = EbonAPI.Windows
local Parameters = EbonAPI.Parameters
local Handle = EbonAPI.Handle
local L = EbonAPI.L

local type, pairs, ipairs, pcall, tostring, tonumber, setmetatable, error =
  type, pairs, ipairs, pcall, tostring, tonumber, setmetatable, error
local floor, ceil, max, min, sin, cos, atan2, deg, rad =
  math.floor, math.ceil, math.max, math.min, math.sin, math.cos, math.atan2, math.deg, math.rad
local format, find, lower, concat, sort = string.format, string.find, string.lower, table.concat, table.sort

local S = Skins.value
local paint = Palette.paint
local THEME = Palette.THEME
local WEAK = { __mode = "k" }
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }
local AIM_EVERY = 0.05
local TIMER_EVERY = 0.1

local KINDS = {}
local elements = setmetatable({}, WEAK)
local pending = {}
local targets = {}
local toasts = {}
local store = nil
local dragging = nil
local ghost = nil
local cursorAnchor = nil
local dialog = nil
local counter = 0
local bindOwner = CreateFrame("Frame")
local relayout

local function report(err)
  Lib.report(err)
end

local function trim(texture)
  local edge = S("kit.icon.trim")

  texture:SetTexCoord(edge, 1 - edge, edge, 1 - edge)
end

Kit.trim = trim

local function callback(element, name, ...)
  local fn = element.spec and element.spec[name]

  if type(fn) == "function" then
    local ok, err = pcall(fn, element, ...)

    if not ok then
      report(err)
    end
  end
end

local function evaluate(element, value)
  if type(value) == "function" then
    local ok, result = pcall(value, element)

    if not ok then
      report(result)
      return nil
    end

    return result
  end

  return value
end

local function localized(owner, key)
  local texts = Locale.get(owner)

  return texts and texts[key] or key
end

local function textOf(element)
  local spec = element.spec

  if not spec then
    return element.label and element.label:GetText() or nil
  end

  if spec.key then
    return localized(element.owner, spec.key)
  end

  local text = evaluate(element, spec.text)

  return text ~= nil and tostring(text) or nil
end

Kit.textOf = textOf

local function saved(owner)
  if not DB.isAttached() then
    return nil
  end

  if not store then
    store = DB.store("EbonAPI", { account = { kit = {} } })
  end

  local kit = store.account.kit

  if type(kit) ~= "table" then
    kit = {}
    store.account.kit = kit
  end

  if type(kit[owner]) ~= "table" then
    kit[owner] = {}
  end

  return kit[owner]
end

Kit.evaluate = evaluate
Kit.localized = localized
Kit.saved = saved

local function inCombat()
  return InCombatLockdown ~= nil and InCombatLockdown() and true or false
end

local function afterCombat(fn)
  if inCombat() then
    pending[#pending + 1] = fn
    return false
  end

  fn()

  return true
end

Kit.afterCombat = afterCombat

function Kit.pending()
  return #pending
end

local Lines = {}
Lines.__index = Lines

function Lines:Add(text, key, wrap)
  local color = THEME[key or "text"] or THEME.text

  self.tooltip:AddLine(tostring(text), color[1], color[2], color[3], wrap and true or false)
end

function Lines:Pair(left, right, leftKey, rightKey)
  local a = THEME[leftKey or "text"] or THEME.text
  local b = THEME[rightKey or "muted"] or THEME.muted

  self.tooltip:AddDoubleLine(tostring(left), tostring(right), a[1], a[2], a[3], b[1], b[2], b[3])
end

function Kit.lines(tooltip)
  return setmetatable({ tooltip = tooltip }, Lines)
end

local lines = Kit.lines(GameTooltip)

local function showTip(element)
  local spec = element.spec

  if not GameTooltip or not spec then
    return
  end

  local link = evaluate(element, spec.link)

  if type(link) == "string" and link ~= "" then
    GameTooltip:SetOwner(element, S("widgets.tooltip.anchor"))
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
    return
  end

  if spec.tip == nil and spec.tipKey == nil then
    return
  end

  local body = spec.tipKey and localized(element.owner, spec.tipKey) or (type(spec.tip) == "string" and spec.tip) or nil

  Bricks.tip(element, textOf(element) or "", body)

  if type(spec.tip) == "function" then
    local ok, err = pcall(spec.tip, lines, element)

    if not ok then
      report(err)
    end

    GameTooltip:Show()
  end
end

Kit.showTip = showTip

local function click(element, mouse, anchor)
  local spec = element.spec

  if not spec or element.disabledState then
    return
  end

  local link = evaluate(element, spec.link)

  if type(link) == "string" and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
    ChatEdit_InsertLink(link)
    return
  end

  if mouse == "RightButton" and spec.menu then
    Kit.openMenu(element.owner, evaluate(element, spec.menu), anchor or element)
    return
  end

  callback(element, "onClick", mouse)
end

Kit.click = click

local function setBadge(element, text)
  if text == nil or text == false or text == "" then
    if element.kitBadge then
      element.kitBadge:Hide()
    end

    return
  end

  local badge = element.kitBadge

  if not badge then
    local size = S("kit.badge.size")

    badge = CreateFrame("Frame", nil, element)
    badge:SetWidth(size)
    badge:SetHeight(size)
    badge:SetPoint("CENTER", element, "TOPRIGHT", -floor(size / 4), -floor(size / 4))
    Bricks.level(badge, element, "kit.badge.level")
    badge.disk = badge:CreateTexture(nil, "ARTWORK")
    badge.disk:SetTexture(Bricks.media("circle"))
    badge.disk:SetAllPoints(badge)
    paint(badge.disk, "SetVertexColor", S("kit.badge.color"))
    badge.text = Bricks.text(badge, "small", S("kit.badge.text"))
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    element.kitBadge = badge
  end

  badge.text:SetText(text == true and "" or tostring(text))
  badge:Show()
end

local common = {}

function common:Refresh()
  local spec = self.spec

  if self.kitRefresh then
    self:kitRefresh()
  end

  local hidden = evaluate(self, spec.hidden)

  if hidden ~= nil then
    local element = self
    local function apply()
      if hidden then
        element:Hide()
      else
        element:Show()
      end
    end

    if self.secure then
      afterCombat(apply)
    else
      apply()
    end
  end

  local disabled = evaluate(self, spec.disabled)

  if disabled ~= nil and self.SetDisabledState then
    self:SetDisabledState(disabled and true or false)
  end

  if spec.badge ~= nil then
    setBadge(self, evaluate(self, spec.badge))
  end

  if self.kitHost and not self.kitHost.kitBusy then
    relayout(self.kitHost, true)
  end

  return self
end

function common:SetBadge(text)
  setBadge(self, text)

  return self
end

function common:Owner()
  return self.owner
end

local function adopt(element, owner, kind, spec)
  element.owner, element.kind, element.spec = owner, kind, spec

  for name, fn in pairs(common) do
    if element[name] == nil then
      element[name] = fn
    end
  end

  if not element.kitOwnTip and (spec.tip ~= nil or spec.tipKey ~= nil or spec.link ~= nil) then
    element:HookScript("OnEnter", showTip)
    element:HookScript("OnLeave", Bricks.hideTip)
  end

  if spec.width then
    element:SetWidth(spec.width)
  end

  if spec.height then
    element:SetHeight(spec.height)
  end

  if spec.point and not element.kitWindow then
    local point = spec.point

    element:ClearAllPoints()
    element:SetPoint(point[1], point[2] or element:GetParent(), point[3] or point[1], point[4] or 0, point[5] or 0)
  end

  elements[element] = true

  return element
end

Kit.adopt = adopt

function Kit.windowOf(frame)
  local at = frame

  while at do
    if at.kitWindow then
      return at
    end

    at = at.GetParent and at:GetParent() or nil
  end

  return nil
end

function relayout(host, upward)
  if host.kitSecure and inCombat() then
    if not host.kitQueued then
      host.kitQueued = true
      afterCombat(function()
        host.kitQueued = false
        relayout(host, upward)
      end)
    end

    return
  end

  local direction = host.kitDirection or "VERTICAL"
  local spacing = host.kitSpacing or S("kit.spacing")
  local columns = host.kitColumns or S("kit.columns")
  local body = host.body or host
  local wrap = host.kitWrap or body:GetWidth() or 0
  local x, y, rowHeight, width, height, column = 0, 0, 0, 0, 0, 0

  if direction ~= "NONE" then
    for _, child in ipairs(host.children) do
      if child:IsShown() then
        local w, h = child:GetWidth() or 0, child:GetHeight() or 0

        child:ClearAllPoints()

        if direction == "HORIZONTAL" then
          child:SetPoint("TOPLEFT", body, "TOPLEFT", x, 0)
          x = x + w + spacing
          width, height = x - spacing, max(height, h)
        elseif direction == "FLOW" then
          if x > 0 and x + w > wrap then
            x, y, rowHeight = 0, y + rowHeight + spacing, 0
          end

          child:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
          x = x + w + spacing
          rowHeight = max(rowHeight, h)
          width, height = max(width, x - spacing), max(height, y + rowHeight)
        elseif direction == "GRID" then
          child:SetPoint("TOPLEFT", body, "TOPLEFT", column * (w + spacing), -y)
          width = max(width, (column + 1) * (w + spacing) - spacing)
          rowHeight = max(rowHeight, h)
          height = max(height, y + rowHeight)
          column = column + 1

          if column >= columns then
            column, y, rowHeight = 0, y + rowHeight + spacing, 0
          end
        else
          child:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
          y = y + h + spacing
          width, height = max(width, w), y - spacing
        end
      end
    end
  end

  host.kitContentWidth, host.kitContentHeight = width, height

  if host.kitResize then
    host:kitResize(width, height)
  end

  if upward and host.kitHost then
    relayout(host.kitHost, true)
  end
end

Kit.relayout = relayout

local function refreshChildren(host)
  host.kitBusy = true

  for _, child in ipairs(host.children) do
    child:Refresh()
  end

  host.kitBusy = false
  relayout(host, false)
end

local container = {}

function container:Add(kind, spec)
  return Kit.create(self.owner, kind, self, spec)
end

function container:Clear()
  for _, child in ipairs(self.children) do
    child:Hide()
    child:ClearAllPoints()
    elements[child] = nil
  end

  self.children = {}
  relayout(self, true)

  return self
end

function container:Children()
  return self.children
end

function container:SetOrientation(direction)
  self.kitDirection = direction
  relayout(self, true)

  return self
end

function container:Layout()
  relayout(self, true)

  return self
end

local function makeContainer(frame, spec, direction)
  frame.children = {}
  frame.kitDirection = spec.layout or direction or "VERTICAL"
  frame.kitSpacing = spec.spacing
  frame.kitColumns = spec.columns
  frame.kitWrap = spec.wrap

  for name, fn in pairs(container) do
    frame[name] = fn
  end

  return frame
end

local SCROLLS = { NONE = true, VERTICAL = true, HORIZONTAL = true, BOTH = true }
local SCROLLING = { group = true, panel = true }

local function checkScroll(owner, spec, level)
  local mode = spec.scroll

  if mode ~= nil and not SCROLLS[mode] then
    error(format("EbonAPI: %s: scroll expects NONE, VERTICAL, HORIZONTAL or BOTH, got %s", owner, tostring(mode)),
      level + 1)
  end
end

-- The scroll parameter of a container: NONE keeps its body as it is; VERTICAL, HORIZONTAL or BOTH
-- put the body in a scroll brick, frozen while secure content is in combat. The caller anchors the
-- returned frame where the body would go.
local function scrollArea(host, parent, spec)
  local mode = spec.scroll or "NONE"

  host.kitScrollMode = mode

  if mode == "NONE" then
    host.kitArea = host.body
    return host.body
  end

  local scroll = Bricks.create("scroll", parent)

  scroll:SetMode(mode)
  scroll.blocked = function()
    return host.kitSecure and inCombat()
  end
  host.body:SetParent(scroll.child)
  host.body:ClearAllPoints()
  host.body:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, 0)
  host.kitScroll, host.kitArea = scroll, scroll

  return scroll
end

local function scrolls(host)
  local mode = host.kitScrollMode

  return Bricks.SCROLL_VERTICAL[mode] == true, Bricks.SCROLL_HORIZONTAL[mode] == true
end

-- Room the bar takes, in each scrolled direction, beside the content.
local function barRoom()
  return S("widgets.scroll.width") + S("kit.gap")
end

-- The view gets the visible size, the child the content: the bars take their room inside the view.
local function fitScroll(host, viewWidth, viewHeight, width, height)
  local scroll = host.kitScroll

  if not scroll then
    return
  end

  local vertical, horizontal = scrolls(host)
  local room = barRoom()

  scroll:SetWidth(max(1, viewWidth))
  scroll:SetHeight(max(1, viewHeight))
  scroll:SetView(max(1, viewWidth - (vertical and room or 0)), max(1, viewHeight - (horizontal and room or 0)))
  scroll:SetContentWidth(width)
  scroll:SetContentHeight(height)
end

function Kit.create(owner, kind, parent, spec)
  local build = KINDS[kind]

  if not build then
    error(format('EbonAPI: %s: unknown element "%s" (known: %s)', owner, tostring(kind), concat(Kit.kinds(), ", ")), 3)
  end

  if spec == nil then
    spec = {}
  elseif type(spec) ~= "table" then
    error(format('EbonAPI: %s: element "%s" expects a table, got %s', owner, kind, type(spec)), 3)
  end

  if SCROLLING[kind] then
    checkScroll(owner, spec, 3)
  end

  local host = parent and parent.children and parent or nil
  local frame = host and (host.body or host) or parent or UIParent
  local element = build(owner, frame, spec)

  adopt(element, owner, kind, spec)
  element.kitTop = host == nil

  if element.secure then
    local at = frame

    while at do
      if at.children or at.kitWindow or at.pages then
        at.kitSecure = true
      end

      at = at.GetParent and at:GetParent() or nil
    end
  end

  if spec.shortcut then
    Kit.bindTarget(element)
  end

  element:Refresh()

  if host then
    element.kitHost = host
    host.children[#host.children + 1] = element
    relayout(host, true)
  end

  return element
end

function Kit.kinds()
  local list = {}

  for name in pairs(KINDS) do
    list[#list + 1] = name
  end

  sort(list)

  return list
end

function Kit.setAction(button, action)
  return afterCombat(function()
    if action.macro then
      button:SetAttribute("type1", "macro")
      button:SetAttribute("macrotext", action.macro)
    elseif action.spell then
      button:SetAttribute("type1", "spell")
      button:SetAttribute("spell", action.spell)
    elseif action.item then
      button:SetAttribute("type1", "item")
      button:SetAttribute("item", action.item)
    end
  end)
end

local function secureCheck(owner)
  if inCombat() then
    error(format("EbonAPI: %s: a secure element cannot be created during combat", owner), 5)
  end
end

local function elementName(owner, spec)
  return spec.name or (spec.shortcut and ("EbonAPIKit" .. owner .. spec.shortcut)) or nil
end

local function secureDisabled(button)
  local show = button.SetDisabledState

  function button:SetDisabledState(disabled)
    self.kitDisabled = disabled and true or false

    if self.kitDisabledQueued then
      return
    end

    self.kitDisabledQueued = inCombat()

    afterCombat(function()
      self.kitDisabledQueued = false
      show(self, self.kitDisabled)

      if self.kitDisabled then
        self:Disable()
      else
        self:Enable()
      end
    end)
  end
end

local function rangeStep(low, high, step)
  return step or ((high - low) >= 10 and 1 or 0.01)
end

local function autoWidth(button)
  if button.secure and inCombat() then
    afterCombat(function()
      autoWidth(button)
    end)
    return
  end

  button:Fit(button.spec.width or max(button.spec.minWidth or 0, button:TextWidth()))
end

KINDS.button = function(owner, parent, spec)
  local button = Bricks.create("button", parent)

  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button.onClick = function(self, mouse)
    click(self, mouse)
  end

  function button:kitRefresh()
    self:SetLabel(textOf(self) or "")
    autoWidth(self)
  end

  return button
end

KINDS.secure = function(owner, parent, spec)
  secureCheck(owner)

  local button = Bricks.dressedButton(parent, "SecureActionButtonTemplate", elementName(owner, spec))

  button.secure = true
  secureDisabled(button)
  button:RegisterForClicks("AnyUp")
  button.onClick = function(self, mouse)
    click(self, mouse)
  end

  if spec.preClick then
    button:SetScript("PreClick", function(self, mouse)
      callback(self, "preClick", mouse)
    end)
  end

  Kit.setAction(button, spec)

  function button:SetAction(action)
    return Kit.setAction(self, action)
  end

  function button:kitRefresh()
    self:SetLabel(textOf(self) or "")
    autoWidth(self)
  end

  return button
end

KINDS.toggle = function(owner, parent, spec)
  local toggle = Bricks.create("toggle", parent)

  toggle.onToggle = function(value)
    callback(toggle, "onChange", value)
  end

  function toggle:kitRefresh()
    local value = evaluate(self, self.spec.get)

    self:SetLabel(textOf(self) or "")

    if value ~= nil then
      self:SetValue(value)
    elseif not self.kitDone then
      self:SetValue(self.spec.value)
    end

    self.kitDone = true

    if not self.spec.width then
      self:SetWidth(self:TextWidth())
    end
  end

  return toggle
end

KINDS.range = function(owner, parent, spec)
  local range = Bricks.create("range", parent)
  local low, high = spec.min or 0, spec.max or 1

  range:SetWidth(spec.width or S("page.unit"))
  range:SetFormat(spec.format)
  range:SetRange(low, high, rangeStep(low, high, spec.step), spec.percent)
  range.onCommit = function(value)
    callback(range, "onChange", value)
  end

  function range:kitRefresh()
    local value = evaluate(self, self.spec.get)

    self:SetTitle(textOf(self) or "")

    if value ~= nil then
      self:SetValue(value)
    elseif not self.kitDone then
      self:SetValue(self.spec.value or low)
    end

    self.kitDone = true
  end

  return range
end

local function itemsOf(owner, values)
  if type(values) ~= "table" then
    return {}
  end

  if values[1] then
    local list = {}

    for index, item in ipairs(values) do
      list[index] = { key = item.value ~= nil and item.value or item.key, text = item.textKey and localized(owner, item.textKey) or item.text }
    end

    return list
  end

  local list = {}

  for key, text in pairs(values) do
    list[#list + 1] = { key = key, text = tostring(text) }
  end

  sort(list, function(a, b)
    return lower(a.text) < lower(b.text)
  end)

  return list
end

KINDS.select = function(owner, parent, spec)
  local box = Bricks.create("select", parent)

  box:SetWidth(spec.width or S("page.unit"))
  box.onPick = function(key)
    callback(box, "onChange", key)
  end

  function box:kitRefresh()
    local value = evaluate(self, self.spec.get)

    self:SetTitle(textOf(self) or "")
    self:SetItems(itemsOf(owner, evaluate(self, self.spec.values)))

    if value ~= nil then
      self:SetValue(value)
    elseif not self.kitDone then
      self:SetValue(self.spec.value)
    else
      self:SetValue(self.value)
    end

    self.kitDone = true
  end

  return box
end

KINDS.color = function(owner, parent, spec)
  local row = Bricks.create("color", parent)

  row.hasAlpha = spec.alpha and true or false
  row.onPick = function(r, g, b, a)
    callback(row, "onChange", r, g, b, a)
  end

  function row:kitRefresh()
    local value = evaluate(self, self.spec.get) or (not self.kitDone and self.spec.value) or nil

    self:SetLabel(textOf(self) or "")

    if type(value) == "table" then
      self:SetColor(value[1], value[2], value[3], value[4])
    end

    self.kitDone = true

    if not self.spec.width then
      self:SetWidth(self:TextWidth())
    end
  end

  return row
end

KINDS.input = function(owner, parent, spec)
  local box = Bricks.create("input", parent)

  box:SetWidth(spec.width or S("page.unit"))
  box:SetLines(spec.lines)
  box.onCommit = function(text)
    callback(box, "onChange", text)
  end

  function box:kitRefresh()
    local value = evaluate(self, self.spec.get)

    self:SetTitle(textOf(self) or "")

    if value ~= nil then
      self:SetValue(value)
    elseif not self.kitDone then
      self:SetValue(self.spec.value or "")
    end

    self.kitDone = true
  end

  return box
end

KINDS.heading = function(owner, parent, spec)
  local box = Bricks.create("heading", parent)

  box:SetWidth(spec.width or S("page.unit") * 2)

  function box:kitRefresh()
    self:SetLabel(textOf(self) or "")
  end

  return box
end

local function textKind(parent, spec, color)
  local box = Bricks.create("text", parent)

  function box:kitRefresh()
    self:SetContent(textOf(self) or "", self.spec.width or S("page.unit") * 2, self.spec.size or "small",
      self.spec.color or color)
  end

  return box
end

KINDS.text = function(owner, parent, spec)
  return textKind(parent, spec, nil)
end

KINDS.status = function(owner, parent, spec)
  return textKind(parent, spec, "muted")
end

KINDS.bar = function(owner, parent, spec)
  local bar = CreateFrame("Frame", nil, parent)
  local pad = spec.padding or (spec.frame and S("kit.padding")) or 0

  if spec.frame then
    Bricks.frame(bar, lower(spec.frame), "card", "borderDim")
  end

  bar.body = CreateFrame("Frame", nil, bar)
  bar.body:SetPoint("TOPLEFT", bar, "TOPLEFT", pad, -pad)
  makeContainer(bar, spec, "HORIZONTAL")

  function bar:kitResize(width, height)
    self.body:SetWidth(max(1, width))
    self.body:SetHeight(max(1, height))

    if not self.spec.width then
      self:SetWidth(width + pad * 2)
    end

    if not self.spec.height then
      self:SetHeight(height + pad * 2)
    end
  end

  bar.kitRefresh = refreshChildren

  return bar
end

KINDS.grid = function(owner, parent, spec)
  local grid = KINDS.bar(owner, parent, spec)

  grid.kitDirection = "GRID"
  grid.kitColumns = spec.columns or S("kit.columns")

  return grid
end

KINDS.group = function(owner, parent, spec)
  local group = Bricks.create("group", parent)
  local pad = S("widgets.group.padding")

  group:SetInnerHeight(0)
  group.kitChrome = group:GetHeight()
  group.body = CreateFrame("Frame", nil, group.box)
  makeContainer(group, spec, "VERTICAL")
  scrollArea(group, group.box, spec):SetPoint("TOPLEFT", group.box, "TOPLEFT", pad, -pad)

  function group:kitResize(width, height)
    local title = self.title and (self.title:GetStringWidth() or 0) or 0
    local vertical, horizontal = scrolls(self)
    local room = barRoom()
    local outer = self.spec.width
      or (horizontal and max(S("kit.scroll.width"), title + pad))
      or max(width + (vertical and room or 0) + pad * 2, title + pad)
    local inner = height + (horizontal and room or 0) + pad * 2

    if vertical then
      inner = max(pad * 2 + 1, (self.spec.height or S("kit.scroll.height")) - self.kitChrome)
    end

    self.body:SetWidth(max(1, width))
    self.body:SetHeight(max(1, height))

    if not self.spec.width then
      self:SetWidth(outer)
    end

    fitScroll(self, outer - pad * 2, inner - pad * 2, width, height)
    self:SetInnerHeight(inner)
  end

  function group:kitRefresh()
    self:SetLabel(textOf(self) or "")
    refreshChildren(self)
  end

  return group
end

local function animateHeight(frame, target, done)
  local duration = S("kit.animation")

  frame.kitTarget = target

  if duration <= 0 then
    frame:SetHeight(target)

    if done then
      done()
    end

    return
  end

  frame.kitFrom, frame.kitElapsed, frame.kitAnimating = frame:GetHeight(), 0, true
  frame:SetScript("OnUpdate", function(self, elapsed)
    self.kitElapsed = self.kitElapsed + (elapsed or 0)

    local share = min(1, self.kitElapsed / duration)

    self:SetHeight(self.kitFrom + (self.kitTarget - self.kitFrom) * share)

    if self.kitHost then
      relayout(self.kitHost, true)
    end

    if share >= 1 then
      self:SetScript("OnUpdate", nil)
      self.kitAnimating = false

      if done then
        done()
      end
    end
  end)
end

KINDS.panel = function(owner, parent, spec)
  local panel = CreateFrame("Frame", nil, parent)
  local spacing = S("kit.spacing")
  local head = Bricks.create("row", panel)
  local size = S("nav.tree.chevron")
  local inset = S("kit.inset")

  head:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  head:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  head.chevron = head:CreateTexture(nil, "OVERLAY")
  head.chevron:SetTexture(Bricks.media("chevron"))
  head.chevron:SetWidth(size)
  head.chevron:SetHeight(size)
  head.chevron:SetPoint("LEFT", head, "LEFT", inset, 0)
  paint(head.chevron, "SetVertexColor", "text")
  head.label:ClearAllPoints()
  head.label:SetPoint("LEFT", head, "LEFT", size + inset * 2, 0)
  head.label:SetPoint("RIGHT", head, "RIGHT", -inset, 0)
  head.label:SetJustifyH("LEFT")
  panel.head = head
  panel.body = CreateFrame("Frame", nil, panel)
  makeContainer(panel, spec, "VERTICAL")
  scrollArea(panel, panel, spec):SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -spacing)
  panel.expanded = spec.expanded ~= false
  Bricks.turn(head.chevron, panel.expanded)

  if not panel.expanded then
    panel.kitArea:Hide()
  end

  head.onClick = function()
    panel:SetExpanded(not panel.expanded)
  end

  function panel:kitTargetHeight()
    return head:GetHeight() + (self.expanded and (spacing + (self.kitViewHeight or self.kitContentHeight or 0)) or 0)
  end

  function panel:kitResize(width, height)
    local vertical, horizontal = scrolls(self)
    local room = barRoom()
    local least = ceil(head.label:GetStringWidth() or 0) + size + inset * 3
    local outer = self.spec.width
      or (horizontal and max(S("kit.scroll.width"), least))
      or max(width + (vertical and room or 0), least)
    local view = height + (horizontal and room or 0)

    if vertical then
      view = max(1, (self.spec.height or S("kit.scroll.height")) - head:GetHeight() - spacing)
    end

    self.body:SetWidth(max(1, width))
    self.body:SetHeight(max(1, height))

    if not self.spec.width then
      self:SetWidth(outer)
    end

    self.kitViewHeight = view
    fitScroll(self, outer, view, width, height)

    if not self.kitAnimating then
      self:SetHeight(self:kitTargetHeight())
    end
  end

  function panel:SetExpanded(state)
    local target

    if self.kitSecure and inCombat() then
      afterCombat(function()
        panel:SetExpanded(state)
      end)
      return self
    end

    self.expanded = state and true or false
    Bricks.turn(head.chevron, self.expanded)

    if not self.expanded then
      self.kitArea:Hide()
    end

    target = self:kitTargetHeight()
    animateHeight(self, target, function()
      if panel.expanded then
        panel.kitArea:Show()
      end

      if panel.kitHost then
        relayout(panel.kitHost, true)
      end
    end)
    callback(self, "onToggle", self.expanded)

    return self
  end

  function panel:kitRefresh()
    head:SetLabel(textOf(self) or "")
    refreshChildren(self)
  end

  return panel
end

KINDS.tabs = function(owner, parent, spec)
  local frame = CreateFrame("Frame", nil, parent)
  local height = S("nav.tab.height")
  local spacing = S("kit.spacing")

  frame.strip = CreateFrame("Frame", nil, frame)
  frame.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.strip:SetHeight(height)
  frame.tabs, frame.pages, frame.order = {}, {}, {}

  function frame:kitSize()
    local page = self.current and self.pages[self.current]
    local width = max(self.kitTabsWidth or 0, page and page:GetWidth() or 0)

    if not self.spec.width then
      self:SetWidth(width)
    end

    if not self.spec.height then
      self:SetHeight(height + spacing + (page and page:GetHeight() or 0))
    end

    if self.kitHost then
      relayout(self.kitHost, true)
    end
  end

  function frame:kitLayoutTabs()
    local x = 0

    for _, id in ipairs(self.order) do
      local button = self.tabs[id]
      local page = self.pages[id]

      button:SetLabel(textOf(page) or id)
      button:SetPadding(S("page.strip.padding"))
      button:Fit()
      button:SetHeight(height)
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", self.strip, "TOPLEFT", x, 0)
      button:SetSelected(id == self.current)
      x = x + button:GetWidth() + S("kit.gap")
    end

    self.kitTabsWidth = x
  end

  function frame:AddTab(id, tabSpec)
    local button = Bricks.create("tab", self.strip)
    local page = CreateFrame("Frame", nil, self)

    tabSpec = tabSpec or {}
    page:SetPoint("TOPLEFT", self.strip, "BOTTOMLEFT", 0, -spacing)
    makeContainer(page, tabSpec, "VERTICAL")
    adopt(page, owner, "page", tabSpec)
    function page:kitResize(width, contentHeight)
      self:SetWidth(max(1, width))
      self:SetHeight(max(1, contentHeight))
      frame:kitSize()
    end

    page.kitRefresh = refreshChildren
    button.onClick = function()
      frame:Select(id)
    end
    self.tabs[id], self.pages[id] = button, page
    self.order[#self.order + 1] = id

    if not self.current then
      self.current = id
    else
      page:Hide()
    end

    self:kitLayoutTabs()
    self:kitSize()

    return page
  end

  function frame:Select(id)
    if not self.pages[id] then
      return self
    end

    if self.kitSecure and inCombat() then
      afterCombat(function()
        frame:Select(id)
      end)
      return self
    end

    self.current = id

    for key, page in pairs(self.pages) do
      if key == id then
        page:Show()
      else
        page:Hide()
      end
    end

    self:kitLayoutTabs()
    self:kitSize()
    callback(self, "onSelect", id)

    return self
  end

  function frame:Selected()
    return self.current
  end

  function frame:kitRefresh()
    for _, page in pairs(self.pages) do
      page:Refresh()
    end

    self:kitLayoutTabs()
    self:kitSize()
  end

  return frame
end

local function flatten(nodes, depth, out)
  for _, node in ipairs(nodes or {}) do
    node.kitDepth = depth
    out[#out + 1] = node

    if node.expanded and node.children then
      flatten(node.children, depth + 1, out)
    end
  end

  return out
end

local function anchorsOf(region)
  local points = { justify = region:GetJustifyH() }

  for index = 1, region:GetNumPoints() do
    points[index] = { region:GetPoint(index) }
  end

  return points
end

local function restoreAnchors(region, points)
  region:ClearAllPoints()

  for _, point in ipairs(points) do
    region:SetPoint(point[1], point[2], point[3], point[4], point[5])
  end

  region:SetJustifyH(points.justify)
end

local function listCheck(frame, row, item, rowHeight)
  local check = row.kitCheck

  if item.checked == nil then
    if check and check:IsShown() then
      check:Hide()
      restoreAnchors(row.label, row.kitLabelPoints)
    end

    return
  end

  if not check then
    row.kitLabelPoints = anchorsOf(row.label)
    check = Bricks.create("toggle", row)
    check:SetLabel("")
    row.kitCheck = check
  end

  check:ClearAllPoints()
  check:SetPoint("LEFT", row, "LEFT", frame.kitTree and (S("nav.tree.chevron") + S("kit.gap")) or S("kit.inset"), 0)
  check:SetWidth(check:TextWidth())
  check:SetHeight(rowHeight)
  check:SetValue(item.checked)
  check:SetDisabledState(item.disabled and true or false)
  check.onToggle = function(value)
    frame:kitCheck(item, value)
  end
  check:Show()
  row.label:ClearAllPoints()
  row.label:SetPoint("LEFT", check, "RIGHT", 0, 0)
  row.label:SetPoint("RIGHT", row, "RIGHT", -S("kit.inset"), 0)
  row.label:SetJustifyH("LEFT")
end

local function listRender(frame)
  local owner, spec = frame.owner, frame.spec
  local rows = frame.rowsPool
  local rowHeight = spec.rowHeight or S("kit.row")
  local indent, inset = S("kit.indent"), S("kit.inset")
  local width = frame:GetWidth() - S("widgets.scroll.width") - S("kit.gap")
  local child = frame.scroll.child
  local items = frame.visible or frame.items
  local y = 0

  rows:releaseAll()
  frame.scroll:SetView(width, frame:GetHeight())

  for _, item in ipairs(items) do
    local row = rows:acquire(child)
    local depth = item.kitDepth or 0
    local payload = item.drag

    if payload == nil and type(spec.drag) == "function" then
      payload = spec.drag(item)
    end

    row:SetWidth(max(1, width - depth * indent))
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", child, "TOPLEFT", depth * indent, -y)
    row:SetLabel(item.key and localized(owner, item.key) or tostring(item.text or ""))
    row:SetSelected(frame.selected == item)
    row:SetDisabledState(item.disabled and true or false)

    if item.color ~= nil and not THEME[item.color] then
      error(format('EbonAPI: %s: list item color "%s" is not a palette color (known: %s)', owner, tostring(item.color),
        concat(Palette.KEYS, ", ")), 0)
    end

    row:SetTextKey(item.color)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.kitItem = item
    row.tipTitle = item.tip and (item.key and localized(owner, item.key) or item.text) or nil
    row.tipBody = item.tip
    row.onClick = function(_, mouse)
      frame:kitPick(item, mouse)
    end

    if frame.kitTree then
      local branch = item.children ~= nil and #item.children > 0

      if not row.kitChevron then
        row.kitChevron = row:CreateTexture(nil, "OVERLAY")
        row.kitChevron:SetTexture(Bricks.media("chevron"))
        row.kitChevron:SetWidth(S("nav.tree.chevron"))
        row.kitChevron:SetHeight(S("nav.tree.chevron"))
        row.kitChevron:SetPoint("LEFT", row, "LEFT", S("kit.gap"), 0)
        paint(row.kitChevron, "SetVertexColor", "text")
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", S("nav.tree.chevron") + S("kit.gap") + inset, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -inset, 0)
        row.label:SetJustifyH("LEFT")
      end

      if branch then
        Bricks.turn(row.kitChevron, item.expanded and true or false)
        row.kitChevron:Show()
      else
        row.kitChevron:Hide()
      end
    end

    listCheck(frame, row, item, rowHeight)

    if payload ~= nil then
      row:RegisterForDrag("LeftButton")
      row:SetScript("OnDragStart", function(self)
        Kit.beginDrag(owner, payload, self)
      end)
      row:SetScript("OnDragStop", function()
        Kit.endDrag()
      end)
    else
      row:SetScript("OnDragStart", nil)
      row:SetScript("OnDragStop", nil)
    end

    y = y + rowHeight
  end

  if #items == 0 and (spec.empty or spec.emptyKey) then
    frame.emptyText:SetText(spec.emptyKey and localized(owner, spec.emptyKey) or spec.empty)
    frame.emptyText:Show()
  else
    frame.emptyText:Hide()
  end

  frame.scroll:SetContentHeight(y)
end

local function newList(owner, parent, spec, tree)
  local frame = CreateFrame("Frame", nil, parent)

  frame:SetWidth(spec.width or S("page.unit") * 2)
  frame:SetHeight(spec.height or S("kit.list"))
  frame.scroll = Bricks.create("scroll", frame)
  frame.scroll:SetAllPoints(frame)
  frame.rowsPool = Bricks.slotPool("row")
  frame.items = {}
  frame.nodes = {}
  frame.kitTree = tree
  frame.emptyText = Bricks.text(frame, "small", "muted")
  frame.emptyText:SetPoint("TOPLEFT", frame, "TOPLEFT", S("kit.inset"), -S("kit.inset"))
  frame.emptyText:Hide()

  function frame:SetItems(items)
    self.items = items or {}
    self.visible = nil
    listRender(self)

    return self
  end

  function frame:SetNodes(nodes)
    self.nodes = nodes or {}
    self.visible = flatten(self.nodes, 0, {})
    listRender(self)

    return self
  end

  function frame:Selected()
    return self.selected
  end

  function frame:Select(item)
    self.selected = item
    listRender(self)

    return self
  end

  function frame:kitPick(item, mouse)
    local menu = item.menu or (type(self.spec.menu) == "function" and self.spec.menu(item)) or self.spec.menu

    if item.disabled then
      return
    end

    if mouse == "RightButton" and menu then
      Kit.openMenu(owner, menu)
      return
    end

    if self.kitTree and item.children and #item.children > 0 then
      item.expanded = not item.expanded
      self.visible = flatten(self.nodes, 0, {})
    end

    self.selected = item

    if type(item.onClick) == "function" then
      local ok, err = pcall(item.onClick, item, mouse)

      if not ok then
        report(err)
      end
    end

    callback(self, "onSelect", item, mouse)
    listRender(self)
  end

  function frame:kitCheck(item, value)
    item.checked = value

    if type(item.onCheck) == "function" then
      local ok, err = pcall(item.onCheck, item, value)

      if not ok then
        report(err)
      end
    end

    callback(self, "onCheck", item, value)
  end

  function frame:kitRefresh()
    local items = evaluate(self, self.spec.items)

    if type(items) == "table" then
      if self.kitTree then
        self.nodes = items
        self.visible = flatten(items, 0, {})
      else
        self.items = items
      end
    end

    listRender(self)
  end

  return frame
end

KINDS.list = function(owner, parent, spec)
  return newList(owner, parent, spec, false)
end

KINDS.tree = function(owner, parent, spec)
  return newList(owner, parent, spec, true)
end

local function compare(a, b)
  local na, nb = tonumber(a), tonumber(b)

  if na and nb then
    return na < nb
  end

  return lower(tostring(a or "")) < lower(tostring(b or ""))
end

KINDS.table = function(owner, parent, spec)
  local frame = CreateFrame("Frame", nil, parent)
  local rowHeight = S("kit.table.row")
  local inset, arrow = S("kit.inset"), S("kit.table.sort")

  frame:SetWidth(spec.width or S("page.unit") * 3)
  frame:SetHeight(spec.height or S("kit.list"))
  frame.columns = spec.columns or {}
  frame.rows = {}
  frame.rowFrames = {}
  frame.head = CreateFrame("Frame", nil, frame)
  frame.head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.head:SetHeight(rowHeight)
  frame.rule = frame:CreateTexture(nil, "ARTWORK")
  frame.rule:SetTexture(Bricks.media("solid"))
  frame.rule:SetHeight(1)
  frame.rule:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, 0)
  frame.rule:SetPoint("TOPRIGHT", frame.head, "BOTTOMRIGHT", 0, 0)
  paint(frame.rule, "SetVertexColor", "borderDim")
  frame.scroll = Bricks.create("scroll", frame)
  frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(rowHeight + 1))
  frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  frame.headers = {}

  for index, column in ipairs(frame.columns) do
    local header = Bricks.flatButton(frame.head)

    header.label:ClearAllPoints()
    header.label:SetPoint("LEFT", header, "LEFT", inset, 0)
    header.label:SetPoint("RIGHT", header, "RIGHT", -(arrow + inset * 2), 0)
    header.label:SetJustifyH(column.align or "LEFT")
    header.sort = header:CreateTexture(nil, "OVERLAY")
    header.sort:SetTexture(Bricks.media("chevron"))
    header.sort:SetWidth(arrow)
    header.sort:SetHeight(arrow)
    header.sort:SetPoint("RIGHT", header, "RIGHT", -inset, 0)
    paint(header.sort, "SetVertexColor", "muted")
    header.sort:Hide()
    header.onClick = function()
      if column.sort ~= false then
        frame:SortBy(column.id)
      end
    end
    frame.headers[index] = header
  end

  local function paintRow(row)
    local selected = row.kitRow ~= nil and row.kitRow == frame.selected
    local key = selected and "selectedText" or "text"

    if selected then
      paint(row.fill, "SetVertexColor", "selected")
      row.fill:Show()
    elseif row.hovered then
      paint(row.fill, "SetVertexColor", "rowHover")
      row.fill:Show()
    else
      row.fill:Hide()
    end

    for _, cell in pairs(row.cells) do
      paint(cell, "SetTextColor", key)
    end
  end

  local function rowFrame(index)
    local row = frame.rowFrames[index]

    if row then
      return row
    end

    row = CreateFrame("Button", nil, frame.scroll.child)
    row:SetHeight(rowHeight)
    row.fill = row:CreateTexture(nil, "BACKGROUND")
    row.fill:SetTexture(Bricks.media("solid"))
    row.fill:SetAllPoints(row)
    row.fill:Hide()
    row.cells = {}
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function(self)
      self.hovered = true
      paintRow(self)

      if self.kitRow and self.kitRow.tip then
        Bricks.tip(self, self.cells[1] and self.cells[1]:GetText() or "", self.kitRow.tip)
      end
    end)
    row:SetScript("OnLeave", function(self)
      self.hovered = false
      paintRow(self)
      Bricks.hideTip()
    end)
    row:SetScript("OnClick", function(self, mouse)
      local data = self.kitRow

      if not data then
        return
      end

      if mouse == "RightButton" and (data.menu or frame.spec.menu) then
        Kit.openMenu(owner, data.menu or evaluate(frame, frame.spec.menu))
        return
      end

      frame.selected = data

      if type(data.onClick) == "function" then
        local ok, err = pcall(data.onClick, data, mouse)

        if not ok then
          report(err)
        end
      end

      callback(frame, "onSelect", data, mouse)
      frame:kitDraw()
    end)
    frame.rowFrames[index] = row

    return row
  end

  local function widths()
    local total = frame:GetWidth() - S("widgets.scroll.width") - S("kit.gap")
    local fixed, flexible = 0, 0
    local list = {}

    for _, column in ipairs(frame.columns) do
      if column.width then
        fixed = fixed + column.width
      else
        flexible = flexible + 1
      end
    end

    local share = flexible > 0 and max(S("kit.table.column"), (total - fixed) / flexible) or 0

    for index, column in ipairs(frame.columns) do
      list[index] = column.width or share
    end

    return list, total
  end

  function frame:SetRows(rows)
    self.rows = rows or {}
    self:kitDraw()

    return self
  end

  function frame:SortBy(id)
    if self.sortId == id then
      self.sortDesc = not self.sortDesc
    else
      self.sortId, self.sortDesc = id, false
    end

    self:kitDraw()

    return self
  end

  function frame:Selected()
    return self.selected
  end

  function frame:Sorted()
    local list = {}

    for index, row in ipairs(self.rows) do
      list[index] = row
    end

    if self.sortId then
      local id, descending = self.sortId, self.sortDesc

      sort(list, function(a, b)
        if descending then
          return compare(b[id], a[id])
        end

        return compare(a[id], b[id])
      end)
    end

    return list
  end

  function frame:kitDraw()
    local sizes, total = widths()
    local x = 0

    for index, column in ipairs(self.columns) do
      local header = self.headers[index]

      header:SetWidth(sizes[index])
      header:SetHeight(rowHeight)
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", self.head, "TOPLEFT", x, 0)
      header:SetLabel(column.key and localized(owner, column.key) or tostring(column.text or column.id or ""))

      if self.sortId == column.id then
        Bricks.turn(header.sort, self.sortDesc and "DOWN" or "UP")
        header.sort:Show()
      else
        header.sort:Hide()
      end

      x = x + sizes[index]
    end

    local rows = self:Sorted()
    local y = 0

    self.scroll:SetView(total, self:GetHeight() - rowHeight - 1)

    for index, data in ipairs(rows) do
      local row = rowFrame(index)
      local cx = 0

      row:SetWidth(total)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, -y)
      row.kitRow = data

      for column, spec2 in ipairs(self.columns) do
        local cell = row.cells[column]

        if not cell then
          cell = Bricks.text(row, "small", "text")
          row.cells[column] = cell
        end

        cell:ClearAllPoints()
        cell:SetPoint("LEFT", row, "LEFT", cx + inset, 0)
        cell:SetWidth(max(1, sizes[column] - inset * 2))
        cell:SetJustifyH(spec2.align or "LEFT")
        cell:SetText(data[spec2.id] ~= nil and tostring(data[spec2.id]) or "")
        cx = cx + sizes[column]
      end

      paintRow(row)
      row:Show()
      y = y + rowHeight
    end

    for index = #rows + 1, #self.rowFrames do
      self.rowFrames[index]:Hide()
      self.rowFrames[index].kitRow = nil
    end

    self.scroll:SetContentHeight(y)
  end

  function frame:kitRefresh()
    local rows = evaluate(self, self.spec.rows)

    if type(rows) == "table" then
      self.rows = rows
    end

    self:kitDraw()
  end

  return frame
end

KINDS.progress = function(owner, parent, spec)
  local bar = CreateFrame("Frame", nil, parent)
  local edge = S("border.size")

  bar:SetWidth(spec.width or S("page.unit"))
  bar:SetHeight(spec.height or S("kit.progress.height"))
  Bricks.frame(bar, "flat", "bgSoft", "borderDim")
  bar.fill = bar:CreateTexture(nil, "ARTWORK")
  bar.fill:SetTexture(Bricks.media("solid"))
  bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", edge, -edge)
  bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", edge, edge)
  paint(bar.fill, "SetVertexColor", spec.color or S("kit.progress.color"))
  bar.text = Bricks.text(bar, "small", "text")
  bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  bar.value, bar.max = 0, 1

  function bar:SetValue(value, maximum)
    self.value = tonumber(value) or 0

    if maximum ~= nil then
      self.max = tonumber(maximum) or self.max
    end

    self:kitDraw()

    return self
  end

  function bar:kitDraw()
    local inner = max(0, self:GetWidth() - edge * 2)
    local share = self.max > 0 and max(0, min(1, self.value / self.max)) or 0

    if share * inner < 1 then
      self.fill:Hide()
    else
      self.fill:SetWidth(share * inner)
      self.fill:Show()
    end

    self.text:SetText(textOf(self) or "")
  end

  function bar:kitRefresh()
    local value, maximum = evaluate(self, self.spec.value), evaluate(self, self.spec.max)

    if value ~= nil then
      self.value = tonumber(value) or 0
    end

    if maximum ~= nil then
      self.max = tonumber(maximum) or 1
    end

    self:kitDraw()
  end

  return bar
end

KINDS.timer = function(owner, parent, spec)
  local box = Bricks.create("text", parent)

  counter = counter + 1
  box.kitTicker = "EbonAPI.kit.timer." .. counter

  function box:kitShow(remaining)
    local label = textOf(self)
    local duration = Format.duration(ceil(remaining))

    if label and find(label, "%s", 1, true) then
      label = format(label, duration)
    elseif label then
      label = label .. " " .. duration
    end

    self:SetContent(label or duration, self.spec.width or S("page.unit"), self.spec.size or "medium", self.spec.color)
  end

  function box:Remaining()
    return self.endsAt and max(0, self.endsAt - GetTime()) or 0
  end

  function box:Stop()
    Bus.untick(self.kitTicker)
    self.endsAt = nil

    return self
  end

  function box:kitTick()
    local remaining = self:Remaining()

    self:kitShow(remaining)

    if self.endsAt and remaining <= 0 then
      local done = self.onDone

      self:Stop()

      if type(done) == "function" then
        local ok, err = pcall(done, self)

        if not ok then
          report(err)
        end
      end

      callback(self, "onDone")
    end
  end

  function box:Start(seconds, onDone)
    self.endsAt = GetTime() + (tonumber(seconds) or 0)
    self.onDone = onDone
    Bus.tick(self.kitTicker, TIMER_EVERY, function()
      box:kitTick()
    end)
    self:kitTick()

    return self
  end

  function box:kitRefresh()
    self:kitShow(self:Remaining())
  end

  return box
end

KINDS.chart = function(owner, parent, spec)
  local frame = CreateFrame("Frame", nil, parent)

  frame:SetWidth(spec.width or S("page.unit") * 2)
  frame:SetHeight(spec.height or S("kit.chart.height"))
  Bricks.frame(frame, "flat", "bgSoft", "borderDim")
  frame.bars = {}
  frame.values = {}

  function frame:SetValues(values)
    self.values = values or {}
    self:kitDraw()

    return self
  end

  function frame:kitDraw()
    local values = self.values
    local count = #values
    local inset, gap = S("border.size") + 1, S("kit.gap")
    local width, height = self:GetWidth() - inset * 2, self:GetHeight() - inset * 2
    local top = 0

    for _, value in ipairs(values) do
      top = max(top, tonumber(value) or 0)
    end

    local barWidth = count > 0 and max(1, (width - gap * (count - 1)) / count) or 0

    for index, value in ipairs(values) do
      local bar = self.bars[index]

      if not bar then
        bar = self:CreateTexture(nil, "ARTWORK")
        bar:SetTexture(Bricks.media("solid"))
        paint(bar, "SetVertexColor", self.spec.color or S("kit.chart.color"))
        self.bars[index] = bar
      end

      bar:ClearAllPoints()
      bar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", inset + (index - 1) * (barWidth + gap), inset)
      bar:SetWidth(barWidth)
      bar:SetHeight(top > 0 and max(1, height * (tonumber(value) or 0) / top) or 1)
      bar:Show()
    end

    for index = count + 1, #self.bars do
      self.bars[index]:Hide()
    end
  end

  function frame:kitRefresh()
    local values = evaluate(self, self.spec.values)

    if type(values) == "table" then
      self.values = values
    end

    self:kitDraw()
  end

  return frame
end

KINDS.icon = function(owner, parent, spec)
  local secure = spec.macro ~= nil or spec.spell ~= nil or spec.item ~= nil
  local size = spec.size or S("kit.icon.size")
  local inset = S("kit.icon.inset")

  if secure then
    secureCheck(owner)
  end

  local button = CreateFrame("Button", elementName(owner, spec), parent, secure and "SecureActionButtonTemplate" or nil)

  button:SetWidth(size)
  button:SetHeight(size)
  Bricks.frame(button, "small", "checkbox", "checkboxBorder")
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
  button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  trim(button.icon)
  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints(button.icon)
  button.cooldown:Hide()
  button.count = Bricks.text(button, "small", "text")
  button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  button:RegisterForClicks("AnyUp")

  local function border(self)
    paint(self, "SetBackdropBorderColor", self.hovered and "buttonHover" or (self.checkedState and "checked" or "checkboxBorder"))
  end

  button:SetScript("OnEnter", function(self)
    self.hovered = true
    border(self)
  end)
  button:SetScript("OnLeave", function(self)
    self.hovered = false
    border(self)
  end)

  if secure then
    button.secure = true
    button:SetScript("PostClick", function(self, mouse)
      click(self, mouse)
    end)

    if spec.preClick then
      button:SetScript("PreClick", function(self, mouse)
        callback(self, "preClick", mouse)
      end)
    end

    Kit.setAction(button, spec)
  else
    button:SetScript("OnClick", function(self, mouse)
      click(self, mouse)
    end)
  end

  function button:SetDisabledState(disabled)
    self.disabledState = disabled and true or false
    self.icon:SetDesaturated(self.disabledState)
    self:SetAlpha(self.disabledState and S("widgets.disabledAlpha") or 1)
  end

  if secure then
    secureDisabled(button)
  end

  function button:SetCooldown(start, duration)
    if start and duration and duration > 0 then
      self.cooldown:SetCooldown(start, duration)
      self.cooldown:Show()
    else
      self.cooldown:Hide()
    end

    return self
  end

  function button:SetCheckedState(state)
    self.checkedState = state and true or false
    border(self)

    return self
  end

  function button:SetAction(action)
    return Kit.setAction(self, action)
  end

  function button:kitRefresh()
    local count = evaluate(self, self.spec.count)
    local checked = evaluate(self, self.spec.checked)
    local cooldown = evaluate(self, self.spec.cooldown)

    self.icon:SetTexture(Lib.icon(evaluate(self, self.spec.icon)) or Bricks.media("addonIcon"))
    self.count:SetText(count ~= nil and tostring(count) or "")

    if checked ~= nil then
      self:SetCheckedState(checked)
    end

    if type(cooldown) == "table" then
      self:SetCooldown(cooldown[1], cooldown[2])
    end
  end

  return button
end

KINDS.slot = function(owner, parent, spec)
  local slot = Bricks.create("row", parent)
  local height = spec.height or S("kit.slot")
  local inset = S("kit.inset")

  slot:SetWidth(spec.width or S("page.unit"))
  slot:SetHeight(height)
  slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  slot:RegisterForDrag("LeftButton")
  slot.onClick = function(self, mouse)
    click(self, mouse)
  end

  if spec.icon ~= nil then
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetWidth(height - inset)
    slot.icon:SetHeight(height - inset)
    slot.icon:SetPoint("LEFT", slot, "LEFT", floor(inset / 2), 0)
    trim(slot.icon)
    slot.label:ClearAllPoints()
    slot.label:SetPoint("LEFT", slot.icon, "RIGHT", inset, 0)
    slot.label:SetPoint("RIGHT", slot, "RIGHT", -inset, 0)
    slot.label:SetJustifyH("LEFT")
  end

  slot:SetScript("OnDragStart", function(self)
    local payload = evaluate(self, self.spec.drag)

    if payload ~= nil then
      Kit.beginDrag(owner, payload, self)
    end
  end)
  slot:SetScript("OnDragStop", function()
    Kit.endDrag()
  end)
  slot:SetScript("OnReceiveDrag", function(self)
    Kit.receive(self)
  end)

  function slot:kitRefresh()
    self:SetLabel(textOf(self) or "")

    if self.icon then
      self.icon:SetTexture(Lib.icon(evaluate(self, self.spec.icon)) or Bricks.media("addonIcon"))
    end
  end

  return slot
end

KINDS.handle = function(owner, parent, spec)
  local size = spec.size or S("kit.handle")
  local handle = CreateFrame("Button", nil, parent)

  handle:SetWidth(size)
  handle:SetHeight(size)
  handle.dot = handle:CreateTexture(nil, "ARTWORK")
  handle.dot:SetTexture(Bricks.media("circle"))
  handle.dot:SetAllPoints(handle)
  paint(handle.dot, "SetVertexColor", "thumb")
  handle:RegisterForDrag("LeftButton")
  handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  handle:SetScript("OnEnter", function(self)
    paint(self.dot, "SetVertexColor", "buttonHover")
  end)
  handle:SetScript("OnLeave", function(self)
    paint(self.dot, "SetVertexColor", "thumb")
  end)
  handle:SetScript("OnDragStart", function(self)
    local window = Kit.windowOf(self)

    if window and not Parameters.value(nil, "locked") and not (window.kitSecure and inCombat()) then
      window:StartMoving()
      self.kitMoving = window
    end
  end)
  handle:SetScript("OnDragStop", function(self)
    local window = self.kitMoving

    self.kitMoving = nil

    if window then
      window:StopMovingOrSizing()

      if window.onMoved then
        window.onMoved(window)
      end
    end
  end)
  handle:SetScript("OnClick", function(self, mouse)
    click(self, mouse)
  end)

  return handle
end

KINDS.shortcut = function(owner, parent, spec)
  local button = Bricks.create("button", parent)

  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:EnableKeyboard(false)
  button.onClick = function(self, mouse)
    if mouse == "RightButton" then
      self.waiting = false
      self:EnableKeyboard(false)
      Kit.setShortcut(owner, self.spec.target, nil)
    else
      self.waiting = true
      self:EnableKeyboard(true)
    end

    self:Refresh()
  end
  button:SetScript("OnKeyDown", function(self, key)
    if not self.waiting or MODIFIERS[key] then
      return
    end

    self.waiting = false
    self:EnableKeyboard(false)

    if key ~= "ESCAPE" then
      local combo = (IsAltKeyDown and IsAltKeyDown() and "ALT-" or "")
        .. (IsControlKeyDown and IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or "") .. key

      Kit.setShortcut(owner, self.spec.target, combo)
    end

    self:Refresh()
  end)
  button:HookScript("OnHide", function(self)
    self.waiting = false
    self:EnableKeyboard(false)
  end)

  function button:kitRefresh()
    local key = Kit.shortcut(owner, self.spec.target)
    local shown = L.UI_SHORTCUT_NONE
    local label = textOf(self)

    if self.waiting then
      shown = L.UI_SHORTCUT_WAIT
    elseif key then
      shown = GetBindingText and GetBindingText(key, "KEY_") or key
    end

    self:SetLabel(label and format(L.UI_SHORTCUT_LINE, label, shown) or shown)
    self.tipTitle, self.tipBody = label or shown, L.UI_SHORTCUT_TIP
    autoWidth(self)
  end

  return button
end

local function rotate(texture, angle)
  local c, s = cos(angle), sin(angle)

  local function corner(u, v)
    return 0.5 + u * c - v * s, 0.5 + u * s + v * c
  end

  local ulx, uly = corner(-0.5, -0.5)
  local llx, lly = corner(-0.5, 0.5)
  local urx, ury = corner(0.5, -0.5)
  local lrx, lry = corner(0.5, 0.5)

  texture:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

Kit.rotate = rotate

KINDS.arrow = function(owner, parent, spec)
  local size = spec.size or S("kit.pointer")
  local frame = CreateFrame("Frame", nil, parent)

  frame:SetWidth(size)
  frame:SetHeight(size)
  frame.pointer = frame:CreateTexture(nil, "ARTWORK")
  frame.pointer:SetTexture(Bricks.media("pointer"))
  frame.pointer:SetAllPoints(frame)
  paint(frame.pointer, "SetVertexColor", spec.color or "heading")
  frame.text = Bricks.text(frame, "small", "text")
  frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -S("kit.gap"))
  frame.kitElapsed = 0

  function frame:kitAim()
    if self.fixed then
      self.angle = self.fixed
      rotate(self.pointer, self.fixed)
      return
    end

    if not self.targetX or not GetPlayerMapPosition or not GetPlayerFacing then
      return
    end

    local px, py = GetPlayerMapPosition("player")

    if not px or (px == 0 and py == 0) then
      self.pointer:Hide()
      return
    end

    self.angle = atan2(-(self.targetX - px), -(self.targetY - py)) - (GetPlayerFacing() or 0)
    self.pointer:Show()
    rotate(self.pointer, self.angle)
  end

  function frame:SetTarget(x, y)
    self.targetX, self.targetY, self.fixed = x, y, nil
    self:kitAim()

    return self
  end

  function frame:SetAngle(angle)
    self.fixed, self.targetX, self.targetY = angle, nil, nil
    self.pointer:Show()
    self:kitAim()

    return self
  end

  function frame:ClearTarget()
    self.targetX, self.targetY, self.fixed = nil, nil, nil
    self.pointer:Hide()

    return self
  end

  frame:SetScript("OnUpdate", function(self, elapsed)
    self.kitElapsed = self.kitElapsed + (elapsed or 0)

    if self.kitElapsed >= AIM_EVERY then
      self.kitElapsed = 0
      self:kitAim()
    end
  end)

  function frame:kitRefresh()
    self.text:SetText(textOf(self) or "")
  end

  return frame
end

KINDS.model = function(owner, parent, spec)
  local model = CreateFrame(spec.dress and "DressUpModel" or "PlayerModel", nil, parent)

  model:SetWidth(spec.width or S("kit.model.width"))
  model:SetHeight(spec.height or S("kit.model.height"))
  model.kitFacing, model.kitZoom = 0, 0
  model:EnableMouse(true)
  model:EnableMouseWheel(true)
  model:SetScript("OnMouseDown", function(self)
    self.kitDrag = GetCursorPosition()
  end)
  model:SetScript("OnMouseUp", function(self)
    self.kitDrag = nil
  end)
  model:SetScript("OnUpdate", function(self)
    if self.kitDrag then
      local x = GetCursorPosition()

      self.kitFacing = self.kitFacing + (x - self.kitDrag) * S("kit.model.turn")
      self.kitDrag = x
      self:SetFacing(self.kitFacing)
    end
  end)
  model:SetScript("OnMouseWheel", function(self, delta)
    self.kitZoom = max(S("kit.model.zoom.min"), min(S("kit.model.zoom.max"), self.kitZoom + delta * S("kit.model.zoom.step")))
    self:SetPosition(self.kitZoom, 0, 0)
  end)

  function model:kitRefresh()
    local unit = evaluate(self, self.spec.unit)
    local creature = evaluate(self, self.spec.creature)
    local path = evaluate(self, self.spec.model)

    if unit and self.SetUnit then
      self:SetUnit(unit)
    end

    if creature and self.SetCreature then
      self:SetCreature(creature)
    end

    if path then
      self:SetModel(path)
    end

    self:SetFacing(self.kitFacing)
  end

  return model
end

local function canMove(frame)
  local mode = frame.spec and frame.spec.move or "ALWAYS"

  if mode == "NONE" or mode == "HANDLE" or Parameters.value(nil, "locked") then
    return false
  end

  if frame.kitSecure and inCombat() then
    return false
  end

  if mode == "SHIFT" then
    return IsShiftKeyDown ~= nil and IsShiftKeyDown() and true or false
  end

  return true
end

Kit.canMove = canMove

function Kit.window(owner, id, spec)
  local key = "addon:" .. owner .. ":" .. id
  local existing = Windows.get(key)

  if existing and existing.kitWindow then
    return existing
  end

  local header = spec.header ~= false
  local escape = spec.escape

  if escape == nil then
    escape = header
  end

  local frame = Windows.create(key, escape and ("EbonAPIKit" .. owner .. id) or nil, owner)
  local pad = spec.padding or S("kit.padding")
  local top = pad

  frame.kitWindow = true
  frame.body = CreateFrame("Frame", nil, frame)

  if header then
    local height = S("kit.header")
    local control = min(S("kit.control"), height)
    local left = S("header.controls") == "LEFT"
    local side, facing, sign = "RIGHT", "LEFT", -1
    local head = CreateFrame("Frame", nil, frame)
    local close = Bricks.create("close", head)
    local anchor = close

    if left then
      side, facing, sign = "LEFT", "RIGHT", 1
    end

    head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    head:SetHeight(height)
    frame.head = head
    frame.title = Bricks.text(head, "normal", "heading")
    frame.titleCentered = S("header.title.align") == "CENTER"

    if frame.titleCentered then
      frame.title:SetPoint("CENTER", head, "CENTER", 0, 0)
    else
      frame.title:SetPoint(facing, head, facing, -sign * pad, 0)
    end

    close:SetWidth(S("header.close.width"))
    close:SetHeight(min(S("header.close.size"), height))
    close:SetPoint(side, head, side, sign * floor(pad / 2), 0)
    close:SetLabel(S("header.close.glyph"))
    close.onClick = function()
      frame:Close()
    end
    close.onShade = function()
      frame:SetShaded(not frame.kitShaded)
    end
    close.tipTitle = L.UI_CLOSE
    frame.close = close
    frame.headButtons = {}

    for index, button in ipairs(spec.buttons or {}) do
      local element = Kit.create(owner, button.icon ~= nil and "icon" or "button", head, button)

      element:SetHeight(control)

      if button.icon ~= nil then
        element:SetWidth(control)
      end

      element:ClearAllPoints()
      element:SetPoint(side, anchor, facing, sign * floor(pad / 2), 0)
      anchor = element
      frame.headButtons[index] = element
    end

    top = height + S("kit.spacing")
  end

  makeContainer(frame, spec, "VERTICAL")
  scrollArea(frame, frame, spec):SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top)
  adopt(frame, owner, "window", spec)

  frame:SetScript("OnDragStart", function(self)
    if canMove(self) then
      self:StartMoving()
    end
  end)

  function frame:kitResize(width, height)
    local minimum = self.spec.minWidth or 0

    if self.title then
      local buttons = (self.close and self.close:GetWidth() or 0) + pad

      for _, element in ipairs(self.headButtons) do
        buttons = buttons + element:GetWidth() + floor(pad / 2)
      end

      local title = self.title:GetStringWidth() or 0

      if self.titleCentered then
        minimum = max(minimum, title + buttons * 2)
      else
        minimum = max(minimum, title + pad * 2 + buttons)
      end
    end

    local vertical, horizontal = scrolls(self)
    local room = barRoom()
    local outerWidth = self.spec.width
      or (horizontal and max(minimum, S("kit.scroll.width")))
      or max(minimum, width + (vertical and room or 0) + pad * 2)
    local outerHeight = self.spec.height
      or (vertical and S("kit.scroll.height"))
      or (top + height + (horizontal and room or 0) + pad)

    self.body:SetWidth(max(1, width))
    self.body:SetHeight(max(1, height))
    fitScroll(self, outerWidth - pad * 2, outerHeight - top - pad, width, height)

    if self.kitShaded then
      self:Resize(outerWidth, self.head:GetHeight())
    else
      self:Resize(outerWidth, outerHeight)
    end
  end

  function frame:SetShaded(state)
    self.kitShaded = state and self.head ~= nil or false

    if self.kitShaded then
      self.kitArea:Hide()
    else
      self.kitArea:Show()
    end

    relayout(self, false)

    return self
  end

  function frame:kitRefresh()
    if self.title then
      self.title:SetText(textOf(self) or "")
    end

    for _, element in ipairs(self.headButtons or {}) do
      element:Refresh()
    end

    refreshChildren(self)
  end

  function frame:Open()
    local window = self

    afterCombat(function()
      window:Show()
    end)
    self:Refresh()

    return self
  end

  function frame:Close()
    local window = self

    if self.kitSecure then
      afterCombat(function()
        window:Hide()
      end)
    else
      self:Hide()
    end

    return self
  end

  function frame:Toggle()
    if self:IsShown() then
      return self:Close()
    end

    return self:Open()
  end

  function frame:SetTitle(text)
    self.spec.text = text
    self:Refresh()

    return self
  end

  Windows.place(frame, function(window)
    local point = spec.point or { "CENTER" }

    window:SetPoint(point[1], point[2] or UIParent, point[3] or point[1], point[4] or 0, point[5] or 0)
  end)

  frame.kitTop = true
  frame:Refresh()

  local shown = spec.shown

  if shown == nil then
    shown = not header
  end

  if shown then
    frame:Show()
  end

  return frame
end

local function ensureCursorAnchor()
  if not cursorAnchor then
    cursorAnchor = CreateFrame("Frame", nil, UIParent)
    cursorAnchor:SetHeight(1)
  end

  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale() or 1

  cursorAnchor:SetWidth(S("page.unit"))
  cursorAnchor:ClearAllPoints()
  cursorAnchor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)

  return cursorAnchor
end

function Kit.openMenu(owner, items, anchor)
  if type(items) ~= "table" then
    return false
  end

  local list, current = {}, nil

  for index, item in ipairs(items) do
    local entry = {
      key = index,
      text = item.key and localized(owner, item.key) or tostring(item.text or ""),
      title = item.title,
      disabled = item.disabled,
    }

    if type(item.range) == "table" then
      local range = item.range
      local low, high = range.min or 0, range.max or 1

      entry.range = {
        min = low, max = high, step = rangeStep(low, high, range.step), percent = range.percent,
        value = range.value or low, format = range.format,
      }
      entry.onChange = function(value)
        if type(item.onChange) == "function" then
          local ok, err = pcall(item.onChange, value, item)

          if not ok then
            report(err)
          end
        end
      end
    end

    list[index] = entry

    if item.checked then
      current = index
    end
  end

  Bricks.openMenu(anchor or ensureCursorAnchor(), list, current, function(index)
    local item = items[index]

    if item and not item.disabled and type(item.onClick) == "function" then
      local ok, err = pcall(item.onClick, item)

      if not ok then
        report(err)
      end
    end
  end)

  return true
end

local function ensureGhost()
  if ghost then
    return ghost
  end

  ghost = CreateFrame("Frame", nil, UIParent)
  ghost:SetFrameStrata("TOOLTIP")
  ghost:SetWidth(S("page.unit"))
  ghost:SetHeight(S("kit.row"))
  Bricks.frame(ghost, "small", "selected", "focus")
  ghost.text = Bricks.text(ghost, "small", "selectedText")
  ghost.text:SetPoint("CENTER", ghost, "CENTER", 0, 0)
  ghost:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1

    self:ClearAllPoints()
    self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / scale + S("kit.drag"), y / scale)
  end)
  ghost:Hide()

  return ghost
end

function Kit.beginDrag(owner, payload, source)
  local frame = ensureGhost()

  dragging = { owner = owner, payload = payload, source = source }
  frame.text:SetText(source and (textOf(source) or "") or "")
  frame:Show()

  return true
end

function Kit.dragging()
  return dragging
end

function Kit.endDrag()
  local current = dragging

  dragging = nil

  if ghost then
    ghost:Hide()
  end

  if not current then
    return false
  end

  local focus = GetMouseFocus and GetMouseFocus()
  local item = nil

  while focus do
    if item == nil and focus.kitItem ~= nil then
      item = focus.kitItem
    end

    if elements[focus] and focus.spec and focus.spec.onDrop and focus.owner == current.owner then
      if focus == current.source then
        return false
      end

      callback(focus, "onDrop", current.payload, current.source, item)

      return true
    end

    focus = focus.GetParent and focus:GetParent() or nil
  end

  return false
end

function Kit.receive(target)
  if dragging then
    return Kit.endDrag()
  end

  if not GetCursorInfo then
    return false
  end

  local kind, id, detail = GetCursorInfo()

  if not kind then
    return false
  end

  if ClearCursor then
    ClearCursor()
  end

  callback(target, "onDrop", { kind = kind, id = id, detail = detail })

  return true
end

function Kit.bindTarget(element)
  local owner, id = element.owner, element.spec.shortcut
  local name = element:GetName()

  if not name then
    local proxy = CreateFrame("Button", "EbonAPIKit" .. owner .. id, UIParent)

    proxy:SetScript("OnClick", function()
      click(element, "LeftButton")
    end)
    name = proxy:GetName()
  end

  targets[owner] = targets[owner] or {}
  targets[owner][id] = name
  Kit.applyShortcuts()
end

function Kit.applyShortcuts()
  if not DB.isAttached() then
    return false
  end

  return afterCombat(function()
    if ClearOverrideBindings then
      ClearOverrideBindings(bindOwner)
    end

    for owner, list in pairs(targets) do
      local keys = saved(owner).shortcuts or {}

      for id, name in pairs(list) do
        local key = keys[id]

        if type(key) == "string" and key ~= "" and SetOverrideBindingClick then
          SetOverrideBindingClick(bindOwner, false, key, name, "LeftButton")
        end
      end
    end
  end)
end

function Kit.shortcut(owner, id)
  local data = saved(owner)

  return data and data.shortcuts and data.shortcuts[id]
end

function Kit.setShortcut(owner, id, key)
  local data = saved(owner)

  if not data then
    return false
  end

  data.shortcuts = data.shortcuts or {}
  data.shortcuts[id] = key
  Kit.applyShortcuts()

  return true
end

local function buildDialog()
  local frame = Bricks.Container("EbonAPIKitDialog")
  local copyField = CreateFrame("Frame", nil, frame)
  local copy = CreateFrame("EditBox", nil, copyField)

  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)

  if type(UISpecialFrames) == "table" then
    UISpecialFrames[#UISpecialFrames + 1] = "EbonAPIKitDialog"
  end

  frame.title = Bricks.text(frame, "normal", "heading")
  frame.text = Bricks.text(frame, "normal", "text")
  frame.text:SetJustifyH("CENTER")
  frame.choices = CreateFrame("Frame", nil, frame)
  frame.choices.scroll = Bricks.create("scroll", frame.choices)
  frame.choices.scroll:SetAllPoints(frame.choices)
  frame.rows = Bricks.slotPool("row")
  frame.input = Bricks.create("input", frame)
  frame.input.edit:SetScript("OnEnterPressed", function()
    Kit.closeDialog(true)
  end)
  copy:SetMultiLine(true)
  copy:SetAutoFocus(false)
  Bricks.font(copy, "small")
  copy:SetTextInsets(S("widgets.input.padding"), S("widgets.input.padding"), S("widgets.input.paddingY"),
    S("widgets.input.paddingY"))
  Bricks.frame(copyField, "small", "bgSoft", "borderDim")
  paint(copy, "SetTextColor", "text")
  copy:SetScript("OnTextChanged", function(self)
    if self:GetText() ~= frame.copyText then
      self:SetText(frame.copyText or "")
      self:HighlightText()
    end
  end)
  copy:SetScript("OnEscapePressed", function()
    Kit.closeDialog(false)
  end)
  frame.copy, frame.copyField = copy, copyField
  frame.copyArea = Bricks.editArea(copyField, copy)
  frame.copyArea:SetMultiLine(true)
  frame.hint = Bricks.text(frame, "small", "muted")
  frame.accept = Bricks.create("button", frame)
  frame.cancel = Bricks.create("button", frame)
  frame.accept.onClick = function()
    Kit.closeDialog(true)
  end
  frame.cancel.onClick = function()
    Kit.closeDialog(false)
  end
  frame:HookScript("OnHide", function(self)
    if self.options then
      local options = self.options

      self.options = nil

      if type(options.onCancel) == "function" then
        local ok, err = pcall(options.onCancel)

        if not ok then
          report(err)
        end
      end
    end
  end)

  return frame
end

function Kit.openDialog(options)
  dialog = dialog or buildDialog()

  if dialog.options then
    Kit.closeDialog(false)
  end

  local pad, spacing = S("kit.padding"), S("kit.spacing")
  local width = S("kit.dialog.width")
  local inner = width - pad * 2
  local buttonHeight = S("widgets.button.height")
  local y = pad

  dialog.options = options
  dialog.choice = options.value

  if options.title and options.title ~= "" then
    Bricks.font(dialog.title, S("kit.dialog.title.font"))
    paint(dialog.title, "SetTextColor", S("kit.dialog.title.color"))
    dialog.title:SetJustifyH(S("kit.dialog.title.align"))
    dialog.title:SetWidth(inner)
    dialog.title:SetText(options.title)
    dialog.title:ClearAllPoints()
    dialog.title:SetPoint("TOP", dialog, "TOP", 0, -y)
    dialog.title:Show()
    y = y + (dialog.title:GetStringHeight() or 0) + spacing
  else
    dialog.title:Hide()
  end

  dialog.text:SetWidth(inner)
  dialog.text:SetText(options.text or "")
  dialog.text:ClearAllPoints()
  dialog.text:SetPoint("TOP", dialog, "TOP", 0, -y)
  y = y + (dialog.text:GetStringHeight() or 0) + spacing

  dialog.rows:releaseAll()

  if type(options.choices) == "table" and #options.choices > 0 then
    local rowHeight = S("kit.row")
    local height = min(#options.choices, S("kit.dialog.choices")) * rowHeight
    local rowWidth = inner - S("widgets.scroll.width") - S("kit.gap")
    local scroll = dialog.choices.scroll

    dialog.choices:SetWidth(inner)
    dialog.choices:SetHeight(height)
    dialog.choices:ClearAllPoints()
    dialog.choices:SetPoint("TOPLEFT", dialog, "TOPLEFT", pad, -y)
    scroll:SetView(rowWidth, height)
    scroll:SetOffset(0)

    for index, choice in ipairs(options.choices) do
      local row = dialog.rows:acquire(scroll.child)

      row:SetWidth(rowWidth)
      row:SetHeight(rowHeight)
      row:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 0, -(index - 1) * rowHeight)
      row:SetLabel(choice.text)
      row:SetTextKey(nil)
      row:SetDisabledState(false)
      row:SetSelected(choice.value == dialog.choice)
      row.kitValue = choice.value
      row.onClick = function()
        dialog.choice = choice.value

        for _, other in ipairs(dialog.rows.used) do
          other:SetSelected(other.kitValue == dialog.choice)
        end

        dialog.accept:SetDisabledState(false)
      end
    end

    scroll:SetContentHeight(#options.choices * rowHeight)
    dialog.choices:Show()
    dialog.accept:SetDisabledState(dialog.choice == nil)
    y = y + height + spacing
  else
    dialog.choices:Hide()
    dialog.accept:SetDisabledState(false)
  end

  if options.input ~= nil then
    dialog.input:SetWidth(inner)
    dialog.input:SetTitle("")
    dialog.input:SetLines(nil)
    dialog.input.edit:SetMaxLetters(options.maxLetters or 0)
    dialog.input:SetValue(options.input)
    dialog.input:ClearAllPoints()
    dialog.input:SetPoint("TOPLEFT", dialog, "TOPLEFT", pad, -y)
    dialog.input:Show()
    dialog.input.edit:SetFocus()
    y = y + dialog.input:GetHeight() + spacing
  else
    dialog.input:Hide()
  end

  if options.copy ~= nil then
    dialog.copyText = options.copy
    dialog.copyField:SetWidth(inner)
    dialog.copyField:SetHeight(S("kit.dialog.copy"))
    dialog.copyField:ClearAllPoints()
    dialog.copyField:SetPoint("TOPLEFT", dialog, "TOPLEFT", pad, -y)
    dialog.copy:SetText(options.copy)
    dialog.copyArea:Fit()
    dialog.copyArea.scroll:SetOffset(0)
    dialog.copyField:Show()
    dialog.copy:Show()
    dialog.copy:SetFocus()
    dialog.copy:HighlightText()
    y = y + S("kit.dialog.copy") + spacing
    dialog.hint:SetText(L.UI_COPY_HINT)
    dialog.hint:ClearAllPoints()
    dialog.hint:SetPoint("TOP", dialog, "TOP", 0, -y)
    dialog.hint:Show()
    y = y + (dialog.hint:GetStringHeight() or 0) + spacing
  else
    dialog.copyField:Hide()
    dialog.copy:Hide()
    dialog.hint:Hide()
  end

  for _, button in ipairs({ dialog.accept, dialog.cancel }) do
    button:SetHeight(buttonHeight)
    button:ClearAllPoints()
  end

  dialog.accept:SetLabel(options.accept or L.UI_OK)
  dialog.accept:Fit(max(S("kit.dialog.button"), dialog.accept:TextWidth()))

  if options.cancel then
    dialog.cancel:SetLabel(options.cancel)
    dialog.cancel:Fit(max(S("kit.dialog.button"), dialog.cancel:TextWidth()))
    dialog.accept:SetPoint("TOPRIGHT", dialog, "TOP", -floor(spacing / 2), -y)
    dialog.cancel:SetPoint("TOPLEFT", dialog, "TOP", floor(spacing / 2), -y)
    dialog.cancel:Show()
  else
    dialog.accept:SetPoint("TOP", dialog, "TOP", 0, -y)
    dialog.cancel:Hide()
  end

  y = y + buttonHeight + pad
  dialog:Resize(width, y)
  dialog:Show()

  return dialog
end

function Kit.closeDialog(accepted)
  if not dialog or not dialog.options then
    return false
  end

  local options = dialog.options
  local value = nil
  local fn = accepted and options.onAccept or options.onCancel

  if options.input ~= nil then
    value = dialog.input.edit:GetText() or ""
  elseif options.choices ~= nil then
    value = dialog.choice
  end

  dialog.options = nil
  dialog:Hide()

  if type(fn) == "function" then
    local ok, err = pcall(fn, value)

    if not ok then
      report(err)
    end
  end

  return true
end

function Kit.dialog()
  return dialog
end

local function stackToasts()
  local y = S("kit.toast.top")

  for _, toast in ipairs(toasts) do
    if toast:IsShown() then
      toast:ClearAllPoints()
      toast:SetPoint("TOP", UIParent, "TOP", 0, -y)
      y = y + toast:GetHeight() + S("kit.spacing")
    end
  end
end

function Kit.dismiss(toast)
  toast:Hide()
  toast.onClick = nil
  stackToasts()
end

local function toastFrame()
  for _, toast in ipairs(toasts) do
    if not toast:IsShown() then
      return toast
    end
  end

  local toast = CreateFrame("Button", nil, UIParent)

  toast:SetFrameStrata("FULLSCREEN_DIALOG")
  Bricks.frame(toast, "small", "bg", "border")
  toast.icon = toast:CreateTexture(nil, "ARTWORK")
  trim(toast.icon)
  toast.title = Bricks.text(toast, "small", "heading")
  toast.title:SetJustifyH("LEFT")
  toast.text = Bricks.text(toast, "normal", "text")
  toast.text:SetJustifyH("LEFT")
  toast:SetScript("OnClick", function(self)
    local fn = self.onClick

    Kit.dismiss(self)

    if type(fn) == "function" then
      local ok, err = pcall(fn)

      if not ok then
        report(err)
      end
    end
  end)
  toast:SetScript("OnUpdate", function(self)
    local left = (self.expires or 0) - GetTime()
    local fade = S("kit.toast.fade")

    if left <= 0 then
      Kit.dismiss(self)
    elseif left < fade then
      self:SetAlpha(left / fade)
    end
  end)
  toast:Hide()
  toasts[#toasts + 1] = toast

  return toast
end

function Kit.notify(owner, text, spec)
  local toast = toastFrame()
  local pad = S("kit.padding")
  local width = S("kit.toast.width")
  local left = pad
  local iconSize = S("kit.toast.icon")

  spec = spec or {}

  local icon = Lib.icon(spec.icon) or EbonAPI:AddonIcon(owner)

  if icon then
    toast.icon:SetTexture(icon)
    toast.icon:SetWidth(iconSize)
    toast.icon:SetHeight(iconSize)
    toast.icon:ClearAllPoints()
    toast.icon:SetPoint("TOPLEFT", toast, "TOPLEFT", pad, -pad)
    toast.icon:Show()
    left = pad * 2 + iconSize
  else
    toast.icon:Hide()
  end

  toast.title:SetWidth(width - left - pad)
  toast.title:SetText(spec.title or owner)
  toast.title:ClearAllPoints()
  toast.title:SetPoint("TOPLEFT", toast, "TOPLEFT", left, -pad)
  toast.text:SetWidth(width - left - pad)
  toast.text:SetText(tostring(text or ""))
  toast.text:ClearAllPoints()
  toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -S("kit.gap"))
  toast:SetWidth(width)
  toast:SetHeight(max(pad * 2 + (icon and iconSize or 0),
    pad * 2 + (toast.title:GetStringHeight() or 0) + S("kit.gap") + (toast.text:GetStringHeight() or 0)))
  toast.expires = GetTime() + (spec.duration or S("kit.toast.duration"))
  toast.onClick = spec.onClick
  toast:SetAlpha(1)
  toast:Show()
  stackToasts()

  if spec.sound and PlaySound then
    PlaySound(spec.sound)
  end

  return toast
end

function Kit.combat(active)
  for element in pairs(elements) do
    local mode = element.kitWindow and element.spec and element.spec.combat

    if mode == "HIDE" then
      if active then
        element.kitCombatShown = element:IsShown()
        element:Hide()
      elseif element.kitCombatShown then
        element.kitCombatShown = nil
        element:Show()
      end
    elseif mode == "FADE" then
      element:SetAlpha(active and S("kit.combatAlpha") or 1)
    end
  end
end

function Kit.refreshAll(owner)
  for element in pairs(elements) do
    if element.kitTop and (not owner or element.owner == owner) then
      element:Refresh()
    end
  end
end

Bus.on("PLAYER_REGEN_DISABLED", function()
  Kit.combat(true)
end)

Bus.on("PLAYER_REGEN_ENABLED", function()
  local waiting = pending

  pending = {}

  for _, fn in ipairs(waiting) do
    Lib.safeCall(fn)
  end

  Kit.combat(false)
end)

EbonAPI:On("LANGUAGE_CHANGED", function()
  Kit.refreshAll()
end)

local RESCALE = "EbonAPI.Kit.rescale"

local function remeasure()
  Bus.tick(RESCALE, 0.01, function()
    Bus.untick(RESCALE)
    Kit.refreshAll()
  end)
end

Bus.on("UI_SCALE_CHANGED", remeasure)
Bus.on("DISPLAY_SIZE_CHANGED", remeasure)
Bus.on("PLAYER_ENTERING_WORLD", remeasure)

EbonAPI:On("PARAMETER_CHANGED", function(_, name)
  if name == "scale" then
    remeasure()
  end
end)

EbonAPI:On("READY", function()
  Kit.refreshAll()
  Kit.applyShortcuts()
end)

local function checkId(owner, id, what)
  if type(id) ~= "string" or not find(id, "^[%w_]+$") then
    error(format("EbonAPI: %s: %s expects an id of letters, digits or _, got %s", owner, what, tostring(id)), 3)
  end
end

function Handle:Window(id, spec)
  checkId(self.addonName, id, "api:Window")

  if spec ~= nil and type(spec) ~= "table" then
    error(format("EbonAPI: %s: api:Window expects a table, got %s", self.addonName, type(spec)), 2)
  end

  checkScroll(self.addonName, spec or {}, 2)

  return Kit.window(self.addonName, id, spec or {})
end

function Handle:Create(kind, parent, spec)
  return Kit.create(self.addonName, kind, parent, spec)
end

function Handle:Elements()
  return Kit.kinds()
end

function Handle:OpenMenu(items, anchor)
  return Kit.openMenu(self.addonName, items, anchor)
end

function Handle:Dialog(spec)
  if type(spec) ~= "table" then
    error(format("EbonAPI: %s: api:Dialog expects a table, got %s", self.addonName, type(spec)), 2)
  end

  local owner = self.addonName
  local choices = nil

  local function text(value, key)
    return key and localized(owner, key) or value
  end

  if type(spec.choices) == "table" then
    choices = {}

    for index, choice in ipairs(spec.choices) do
      choices[index] = { value = choice.value, text = text(tostring(choice.text or ""), choice.key) }
    end
  end

  return Kit.openDialog({
    title = text(spec.title, spec.titleKey),
    text = text(spec.text, spec.textKey),
    accept = text(spec.accept, spec.acceptKey),
    cancel = text(spec.cancel, spec.cancelKey),
    input = spec.input,
    maxLetters = spec.maxLetters,
    choices = choices,
    value = spec.value,
    onAccept = spec.onAccept,
    onCancel = spec.onCancel,
  })
end

function Handle:Confirm(text, onYes, onNo)
  return self:Dialog({ text = text, accept = L.UI_YES, cancel = L.UI_NO, onAccept = onYes, onCancel = onNo })
end

function Handle:Prompt(text, default, onAccept, onCancel)
  return self:Dialog({
    text = text, input = default or "", accept = L.UI_OK, cancel = L.UI_CANCEL,
    onAccept = onAccept, onCancel = onCancel,
  })
end

function Handle:CopyBox(text, title)
  return Kit.openDialog({ text = title or "", copy = tostring(text or ""), accept = L.UI_CLOSE })
end

function Handle:Notify(text, spec)
  return Kit.notify(self.addonName, text, spec)
end

function Handle:AfterCombat(fn)
  if type(fn) ~= "function" then
    error(format("EbonAPI: %s: api:AfterCombat expects a function, got %s", self.addonName, type(fn)), 2)
  end

  return afterCombat(fn)
end

function Handle:GetShortcut(id)
  return Kit.shortcut(self.addonName, id)
end

function Handle:SetShortcut(id, key)
  checkId(self.addonName, id, "api:SetShortcut")

  return Kit.setShortcut(self.addonName, id, key)
end

function Handle:RefreshUI()
  Kit.refreshAll(self.addonName)
end
