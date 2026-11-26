EbonAPI = EbonAPI or {}
EbonAPI.Replace = {}

local Replace = EbonAPI.Replace
local Skins = EbonAPI.Skins
local Bricks = EbonAPI.Bricks
local DressTree = EbonAPI.DressTree

local type, pairs, ipairs, pcall, rawget, tonumber = type, pairs, ipairs, pcall, rawget, tonumber
local max = math.max

local SLOTS = { button = "button", tab = "tab", close = "close", reset = "reset", row = "row", header = "heading", input = "input" }
local LOOKS = { LARGE = "large", SMALL = "small", FLAT = "flat" }
local STYLES = { frame = "tree.piece.frame", panel = "tree.piece.panel", bar = "tree.piece.bar", scroll = "tree.piece.scroll", slot = "tree.piece.slot" }

local hidden = {}
local hooked = {}
local list = {}
local follows = {}
local inks = {}
local handlers = {}
local current, context
local syncing = false

function Replace.look(token)
  return LOOKS[Skins.value(token)]
end

local function call(obj, method, ...)
  if obj and type(obj[method]) == "function" then
    return obj[method](obj, ...)
  end
end

local function hookOnce(obj, method, fn)
  if type(hooksecurefunc) == "function" and type(obj[method]) == "function" then
    pcall(hooksecurefunc, obj, method, fn)
  end
end

local function enforce(obj)
  local state = hidden[obj]

  if state and not state.busy then
    state.busy = true
    call(obj, "SetAlpha", 0)
    state.busy = false
  end
end

function Replace.hide(obj)
  if not obj then
    return obj
  end

  if not hidden[obj] then
    hidden[obj] = { alpha = call(obj, "GetAlpha") or 1, owner = context }

    if not hooked[obj] then
      hooked[obj] = true
      hookOnce(obj, "Show", function(self) enforce(self) end)
      hookOnce(obj, "SetAlpha", function(self) enforce(self) end)
      hookOnce(obj, "SetTexture", function(self) enforce(self) end)
      hookOnce(obj, "SetVertexColor", function(self) enforce(self) end)
    end
  end

  enforce(obj)

  return obj
end

function Replace.hideButtonArt(button)
  if type(button) ~= "table" then
    return
  end

  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    local texture = call(button, getter)

    if texture then
      Replace.hide(texture)
    end
  end
end

function Replace.hideChrome(frame, keys, extra, skipThumb)
  if not frame or type(frame.GetRegions) ~= "function" then
    return
  end

  local thumb = skipThumb and type(frame.GetThumbTexture) == "function" and frame:GetThumbTexture() or nil

  for _, region in ipairs({ frame:GetRegions() }) do
    if region and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture" and region ~= thumb then
      local key
      for k, v in pairs(frame) do
        if v == region and type(k) == "string" then
          key = k
          break
        end
      end
      if not (key and ((keys and keys[key]) or (extra and extra[key]))) then
        Replace.hide(region)
      end
    end
  end
end

function Replace.restore(obj)
  local state = obj and hidden[obj]

  if state then
    hidden[obj] = nil
    call(obj, "SetAlpha", state.alpha)
  end

  return obj
end

function Replace.hidden(obj)
  return hidden[obj] ~= nil
end

local function resync(native, piece)
  if syncing or piece.released then
    return
  end

  syncing = true
  piece:ClearAllPoints()

  for index = 1, (native:GetNumPoints() or 0) do
    local point, relative, relPoint, x, y = native:GetPoint(index)

    if point then
      if relative == native then
        relative = native:GetParent()
      end

      piece:SetPoint(point, relative, relPoint, x, y)
    end
  end

  local width, height = native:GetWidth(), native:GetHeight()

  if width and width > 0 then
    piece:SetWidth(width)
  end

  if height and height > 0 then
    piece:SetHeight(height)
  end

  syncing = false
end

local function follow(native, piece)
  local group = follows[native]

  if not group then
    group = {}
    follows[native] = group

    local function update(self)
      for _, each in ipairs(group) do
        resync(self, each)
      end
    end

    for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight" }) do
      hookOnce(native, method, update)
    end

    if type(native.HookScript) == "function" then
      pcall(native.HookScript, native, "OnSizeChanged", update)
    end

    local function shown(self)
      for _, each in ipairs(group) do
        if not each.released then
          if self:IsShown() then
            local level = call(self, "GetFrameLevel")

            if level then
              call(each, "SetFrameLevel", max(0, level - 1))
            end

            call(each, "Show")
          else
            call(each, "Hide")
          end
        end
      end
    end

    hookOnce(native, "Show", shown)
    hookOnce(native, "Hide", shown)
  end

  group[#group + 1] = piece
end

local function ink(target, key)
  if not target or type(target.SetTextColor) ~= "function" or type(target.GetTextColor) ~= "function" then
    return
  end

  if not inks[target] then
    inks[target] = { color = { target:GetTextColor() }, owner = context }
  end

  Bricks.paint(target, "SetTextColor", key)
end

Replace.ink = ink

local function inkSearch(native)
  ink(native, "text")
  ink(native.Instructions or native.instructions, "muted")
end

function Replace.piece(native, kind, opts)
  opts = opts or {}
  kind = kind or "frame"

  local parent = native:GetParent() or UIParent
  local piece
  local slot = SLOTS[kind]

  if slot and Bricks.create then
    local ok, widget

    if kind == "row" and Bricks.build then
      ok, widget = pcall(Bricks.build, slot, Skins.value("widgets.list.rowBrick"), parent)
    else
      ok, widget = pcall(Bricks.create, slot, parent)
    end

    if ok and widget then
      piece = widget

      if kind == "button" and type(widget.SetTone) == "function" then
        local fill, edge = Skins.value("tree.button.fill"), Skins.value("tree.button.border")

        if type(fill) == "string" and type(edge) == "string" and (fill ~= "button" or edge ~= "buttonBorder") then
          widget:SetTone(fill, edge)
        end
      end
    end
  end

  if not piece then
    piece = CreateFrame("Frame", nil, parent)
    local fill = opts.bg

    if fill == nil and kind == "panel" then
      fill = Skins.value("tree.piece.fill")
    end

    Bricks.frame(piece, opts.style or Replace.look(STYLES[kind] or STYLES.frame), fill, Bricks.edge(opts.border, fill))
  end

  piece.replaceKind = kind
  piece.replaceNative = native
  piece.replaceOwner = context
  call(piece, "EnableMouse", false)

  local level = call(native, "GetFrameLevel")

  if not level then
    level = call(parent, "GetFrameLevel") or 1
  end

  call(piece, "SetFrameLevel", max(0, level - 1))
  call(piece, "SetFrameStrata", call(native, "GetFrameStrata") or call(parent, "GetFrameStrata") or "MEDIUM")
  resync(native, piece)
  follow(native, piece)

  if type(piece.HookScript) == "function" then
    pcall(piece.HookScript, piece, "OnShow", function(self)
      if type(native.IsShown) == "function" and not native:IsShown() then
        self:Hide()
      end
    end)
  end

  if kind == "input" and type(piece.field) == "table" and piece.field.SetPoint then
    piece.field:ClearAllPoints()
    piece.field:SetPoint("TOPLEFT", piece, "TOPLEFT", 0, 0)
    piece.field:SetPoint("BOTTOMRIGHT", piece, "BOTTOMRIGHT", 0, 0)
    call(piece.title, "Hide")
    call(piece.edit, "Hide")
  end

  if opts.menu and kind == "button" and Bricks.dropArrow and type(piece.CreateTexture) == "function" then
    Bricks.dropArrow(piece)
  end

  if kind == "input" and not opts.cover then
    inkSearch(native)
  end

  call(piece, "Show")

  if type(native.IsShown) == "function" and not native:IsShown() then
    call(piece, "Hide")
  end

  list[#list + 1] = piece

  if opts.cover then
    Replace.hide(native)
  end

  return piece
end

function Replace.mirror(native, piece)
  if type(native.IsShown) ~= "function" then
    return piece
  end

  if not native:IsShown() then
    piece:Hide()
  end

  if type(native.HookScript) == "function" then
    pcall(native.HookScript, native, "OnShow", function()
      if not piece.released then
        piece:Show()
      end
    end)
    pcall(native.HookScript, native, "OnHide", function()
      if not piece.released then
        piece:Hide()
      end
    end)
  end

  return piece
end

function Replace.wrap(native, kind, opts)
  if not native then
    return nil
  end

  return Replace.mirror(native, Replace.piece(native, kind, opts))
end

function Replace.pieces()
  local copy = {}

  for index, piece in ipairs(list) do
    copy[index] = piece
  end

  return copy
end

local function release(piece)
  piece.released = true
  call(piece, "Hide")
end

local function releaseOwned(owner)
  local kept = {}

  for _, piece in ipairs(list) do
    if piece.replaceOwner == owner then
      release(piece)
    else
      kept[#kept + 1] = piece
    end
  end

  list = kept

  for obj, state in pairs(hidden) do
    if state.owner == owner then
      Replace.restore(obj)
    end
  end

  for target, state in pairs(inks) do
    if state.owner == owner then
      inks[target] = nil
      Bricks.unpaint(target, "SetTextColor")
      target:SetTextColor(state.color[1], state.color[2], state.color[3], state.color[4])
    end
  end
end

function Replace.tab(name, handler)
  handlers[name] = handler

  return handler
end

function Replace.active()
  if Skins and Skins.value and Skins.value("board.dress") then
    return true
  end

  return DressTree ~= nil and DressTree.state ~= nil and DressTree.state() == "dressed"
end

local dressed = {}

local function undressTab(name)
  local handler = handlers[name]

  if handler and handler.undress then
    pcall(handler.undress)
  end

  releaseOwned(name)
end

function Replace.dressTab(name)
  if not Replace.active() then
    return false
  end

  local handler = handlers[name]

  if not handler then
    return false
  end

  local key = Skins and Skins.active and Skins.active() or false

  if dressed[name] == key then
    current = name
    return true
  end

  for other, was in pairs(dressed) do
    if was ~= key then
      undressTab(other)
      dressed[other] = nil
    end
  end

  current = name
  context = name

  local ok = pcall(handler.dress)

  context = nil
  dressed[name] = key

  return ok
end

function Replace.current()
  return current
end

function Replace.resetCross(filter)
  local reset = filter and filter.ResetButton

  if not reset or type(reset.GetObjectType) ~= "function" then
    return
  end

  Replace.hideChrome(reset)
  Replace.hideButtonArt(reset)
  Replace.hide(reset)
end

function Replace.arrowLabel(piece, left)
  if piece and piece.SetLabel then
    if piece.SetPadding then
      piece:SetPadding(0)
    end

    piece:SetLabel(Skins.value(left and "header.history.back" or "header.history.forward") or "")
  end
end

function Replace.placer()
  local moved = {}
  local set = {}

  function set.place(frame, points)
    if not frame or type(frame.SetPoint) ~= "function" then
      return
    end

    if not moved[frame] then
      local saved = {}

      for index = 1, frame:GetNumPoints() do
        saved[index] = { frame:GetPoint(index) }
      end

      moved[frame] = saved
    end

    frame:ClearAllPoints()

    for _, point in ipairs(points) do
      frame:SetPoint(point[1], point[2], point[3], point[4] or 0, point[5] or 0)
    end
  end

  function set.giveBack()
    for frame, saved in pairs(moved) do
      frame:ClearAllPoints()

      for _, point in ipairs(saved) do
        frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
      end

      moved[frame] = nil
    end
  end

  return set
end

local hookedSelected = setmetatable({}, { __mode = "k" })

function Replace.followSelected(row, piece, selected)
  if not (piece and piece.SetMarked and selected and selected.IsShown) then
    return
  end

  Replace.hide(selected)

  local entry = hookedSelected[selected]

  if entry then
    entry.piece = piece
  else
    entry = { piece = piece }
    hookedSelected[selected] = entry

    local function sync()
      local marked = entry.piece

      if marked and not marked.released then
        marked:SetMarked(selected:IsShown() and true or false)
      end
    end

    hookOnce(selected, "Show", sync)
    hookOnce(selected, "Hide", sync)
  end

  local marked = entry.piece

  if marked and not marked.released then
    marked:SetMarked(selected:IsShown() and true or false)
  end
end

function Replace.scrollLooks()
  local set = {}

  function set:reset()
    for i = #self, 1, -1 do
      self[i] = nil
    end
  end

  function set:dress(bar)
    local look = bar and Bricks.scrollOn(bar)

    if look then
      self[#self + 1] = look
      look:Dress()
    end

    return look
  end

  function set:undress()
    for i = #self, 1, -1 do
      local look = self[i]

      if look and look.Undress then
        pcall(look.Undress, look)
      end

      self[i] = nil
    end
  end

  return set
end

local DROP_NAMES = {
  WardrobeFilterDropDown = true, MountJournalFilterDropDown = true, PetJournalFilterDropDown = true,
  WardrobeCollectionFrameWeaponDropDown = true,
}
local DROP_LEVELS = 3
local function dropList(level) return rawget(_G, "DropDownList" .. level) end
local dropLooks = {}
local dropHooked = {}

local function dropWanted()
  local open = rawget(_G, "UIDROPDOWNMENU_OPEN_MENU")

  if type(open) == "string" then
    open = rawget(_G, open)
  end

  local name = type(open) == "table" and call(open, "GetName") or nil

  return name ~= nil and DROP_NAMES[name] == true and Replace.active() and Skins.value("widgets.menu.native.dress") == true
end

local function dropOne(list, wanted)
  if wanted then
    local look = Bricks.dressMenu(list)

    if look then
      dropLooks[list] = look
      look:Dress()
      look:Sync()
    end
  elseif dropLooks[list] then
    dropLooks[list]:Undress()
  end
end

local function dropRefresh()
  local wanted = dropWanted()

  for level = 1, DROP_LEVELS do
    local frame = dropList(level)

    if frame then
      if not dropHooked[frame] and type(frame.HookScript) == "function" then
        dropHooked[frame] = true
        pcall(frame.HookScript, frame, "OnShow", dropRefresh)
      end

      pcall(dropOne, frame, wanted)
    end
  end
end

function Replace.dropdowns()
  dropRefresh()
end

local function dropRestoreAll()
  for _, look in pairs(dropLooks) do
    pcall(look.Undress, look)
  end
end

if type(hooksecurefunc) == "function" and type(_G.ToggleDropDownMenu) == "function" then
  hooksecurefunc("ToggleDropDownMenu", dropRefresh)

  for _, fname in ipairs({ "UIDropDownMenu_AddButton", "UIDropDownMenu_Refresh" }) do
    if type(_G[fname]) == "function" then
      hooksecurefunc(fname, function()
        if dropWanted() then
          dropRefresh()
        end
      end)
    end
  end
  dropRefresh()
end

local numbered = setmetatable({}, { __mode = "k" })
local numbering = false

local function groupDigits(text)
  return (text:gsub("(%d%d%d%d+)(|T)", function(digits, tail)
    return EbonAPI.Format.number(tonumber(digits)) .. tail
  end))
end

function Replace.numberText(fontString)
  if not fontString or type(fontString.GetText) ~= "function" then
    return
  end

  local fresh = numbered[fontString] == nil

  numbered[fontString] = true

  local function apply()
    if numbering or not numbered[fontString] then
      return
    end

    local value = fontString:GetText()

    if type(value) ~= "string" then
      return
    end

    local grouped = groupDigits(value)

    if grouped ~= value then
      numbering = true
      pcall(fontString.SetText, fontString, grouped)
      numbering = false
    end
  end

  if fresh then
    hookOnce(fontString, "SetText", apply)
  end

  apply()
end

function Replace.tooltipCost(tooltip)
  if not tooltip or type(tooltip.NumLines) ~= "function" or type(tooltip.GetName) ~= "function" then
    return
  end

  local name = tooltip:GetName()

  if not name then
    return
  end

  for i = 1, tooltip:NumLines() do
    local line = _G[name .. "TextLeft" .. i]
    local value = line and line.GetText and line:GetText()

    if type(value) == "string" then
      local changed = value:gsub("(|cffffd700)(%d%d%d%d+)( gold|r)", function(open, digits, close)
        return open .. EbonAPI.Format.number(tonumber(digits)) .. close
      end)

      if changed ~= value then
        line:SetText(changed)
        tooltip:Show()
        return
      end
    end
  end
end

function Replace.undressAll()
  dropRestoreAll()

  for key in pairs(numbered) do
    numbered[key] = false
  end

  for name in pairs(handlers) do
    undressTab(name)
  end

  releaseOwned(nil)

  for obj in pairs(hidden) do
    Replace.restore(obj)
  end

  for _, piece in ipairs(list) do
    release(piece)
  end

  list = {}
  dressed = {}
  current = nil
  context = nil
end
