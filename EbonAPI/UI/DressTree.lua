EbonAPI = EbonAPI or {}
EbonAPI.DressTree = {}

local DressTree = EbonAPI.DressTree
local Bus = EbonAPI.Bus
local Skins = EbonAPI.Skins
local Bricks = EbonAPI.Bricks
local Common = EbonAPI.Common
local Ebonhold = EbonAPI.Ebonhold
local Handle = EbonAPI.Handle
local Dress = EbonAPI.Dress
local Frame = Ebonhold.Frame

local type, pairs, ipairs, select, pcall, unpack = type, pairs, ipairs, select, pcall, unpack
local setmetatable, getmetatable = setmetatable, getmetatable
local abs, max, min = math.abs, math.max, math.min

local S = Skins.value

local OWNER = EbonAPI.name
local HOOKED = { "UpdateTotalSoulPoints", "RefreshTree", "RefreshTreeIfShown" }
local TAB_NAME = "CollectionsJournalTab"
local TIMER = "EbonAPI:dresstree"

local handle = setmetatable({ addonName = OWNER }, Handle)

local state = "waiting"
local installed, wanted, applied = false, true, false
local forcedSearch = nil
local tree, plate, chrome, surface, bottomFrame, bottomFill, title
local clearPortrait = false
local blocked = {}
local cover
local titleHooked = false
local journalOn = false
local overlays = {}
local followed = {}

local list = Dress.list

local GET, SET = {}, {}

GET.alpha, SET.alpha = Dress.getAlpha, Dress.setAlpha
GET.points, SET.points = Dress.getPoints, Dress.setPoints

function GET.shown(region) return region:IsShown() and true or false end
function SET.shown(region, value)
  if value then
    region:Show()
  else
    region:Hide()
  end
end

function GET.level(frame) return frame:GetFrameLevel() end
function SET.level(frame, value) frame:SetFrameLevel(value) end

local same = Dress.same

local memory = {}
local order = {}

local function capture(region, prop)
  local held = memory[region]

  if not held then
    held = {}
    memory[region] = held
    order[#order + 1] = region
  end

  local value = GET[prop](region)
  local entry = held[prop]

  if not entry then
    held[prop] = { orig = value }
  elseif not entry.done or not same(value, entry.mine) then
    entry.orig = value
  end
end

local function set(region, prop, value)
  capture(region, prop)
  SET[prop](region, value)

  local entry = memory[region][prop]

  entry.mine, entry.done = GET[prop](region), true
end

local function restoreOne(region)
  local held = memory[region]

  if not held then
    return
  end

  for prop, entry in pairs(held) do
    SET[prop](region, entry.orig)
  end

  memory[region] = nil
end

local walked = setmetatable({}, { __mode = "k" })

local function restoreAll()
  walked = setmetatable({}, { __mode = "k" })

  for index = #order, 1, -1 do
    local region = order[index]

    pcall(restoreOne, region)
    order[index] = nil
  end
end

local function hide(region)
  if region and region:GetAlpha() ~= 0 then
    set(region, "alpha", 0)
  end
end

local FRAME_KEYS = {
  "Bg", "TitleBg", "portrait", "PortraitFrame", "TopRightCorner", "TopLeftCorner",
  "TopBorder", "TopTileStreaks", "BotLeftCorner", "BotRightCorner",
  "BottomBorder", "LeftBorder", "RightBorder",
}

local function noop() end

local function remove(region)
  if not region or not region.Hide then
    return
  end

  if region:IsShown() then
    set(region, "shown", false)
  end

  if blocked[region] == nil then
    blocked[region] = { saved = rawget(region, "Show") }
    region.Show = noop
  end
end

local function unblock()
  for region, held in pairs(blocked) do
    region.Show = held.saved
    blocked[region] = nil
  end
end

local function keepOrHide(region, keep)
  if keep then
    restoreOne(region)
  else
    hide(region)
  end
end

local function hideRegions(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    hide(region)
  end
end

local function heightOf(text)
  if not text then
    return 0
  end

  return (text.GetStringHeight and text:GetStringHeight()) or text:GetHeight() or 0
end

local function isMine(frame)
  return frame == plate or frame == chrome or frame == surface or frame == bottomFrame or frame == bottomFill
end

local function findCover()
  if cover and cover:GetParent() == tree then
    return cover
  end

  cover = nil

  for _, child in ipairs({ tree:GetChildren() }) do
    if not isMine(child) and abs(child:GetWidth() - 1) < 0.01 and abs(child:GetHeight() - 1) < 0.01
        and child:GetNumPoints() == 1 and select(2, child:GetPoint(1)) == Frame("CollectionsJournal") then
      cover = child

      return cover
    end
  end

  return nil
end

local function topLevel()
  local top = tree:GetFrameLevel()
  local skip = findCover()

  for _, child in ipairs({ tree:GetChildren() }) do
    if not isMine(child) and child ~= skip then
      top = max(top, child:GetFrameLevel())
    end
  end

  return top
end

local function build()
  if plate then
    return
  end

  plate = CreateFrame("Frame", nil, tree)
  plate:SetAllPoints(tree)
  chrome = CreateFrame("Frame", nil, tree)
  chrome:SetAllPoints(tree)
  surface = CreateFrame("Frame", nil, tree)
  bottomFrame = CreateFrame("Frame", nil, tree)
  title = chrome:CreateFontString(nil, "OVERLAY")
end

local function follow(button)
  if followed[button] then
    return
  end

  followed[button] = true

  local function track(script, hovered, pressed)
    button:HookScript(script, function()
      local widget = overlays[button]

      if (applied or journalOn) and widget then
        if hovered ~= nil then
          widget.hovered = hovered
        end

        if pressed ~= nil then
          widget.pressed = pressed
        end

        Dress.guard(OWNER, widget.Visual, widget)
      end
    end)
  end

  track("OnEnter", true, nil)
  track("OnLeave", false, false)
  track("OnMouseDown", nil, true)
  track("OnMouseUp", nil, false)
end



local function layoutPlate(top)
  local level = max(0, tree:GetFrameLevel() - 1)

  plate:SetFrameLevel(level)

  local journal = Frame("CollectionsJournal")

  plate:ClearAllPoints()

  if journal then
    plate:SetPoint("TOPLEFT", journal, "TOPLEFT", 0, 0)
    plate:SetPoint("BOTTOMRIGHT", journal, "BOTTOMRIGHT", 0, 0)
  else
    plate:SetAllPoints(tree)
  end

  plate:Show()

  for _, frame in ipairs({ chrome, surface, bottomFrame }) do
    frame:SetFrameLevel(top + S("tree.stack.levelStep"))
    frame:Show()
  end
end

local bottomClaimed, dressBottom
do
local function searchHidden()
  if forcedSearch ~= nil then
    return forcedSearch
  end

  return S("tree.search.hide") and true or false
end

function bottomClaimed()
  return clearPortrait and bottomFrame ~= nil and bottomFrame:GetNumChildren() > 0
end

function DressTree.searchShown()
  return not searchHidden()
end

local reachers = setmetatable({}, { __mode = "k" })
local reachDriver

local function reachPlace(piece, native)
  if piece.released then
    return true
  end

  local journal = Frame("CollectionsJournal")

  if not journal then
    return true
  end

  local low, top = journal:GetBottom(), native:GetTop()

  if not (low and top) then
    return false
  end

  local edge = S("tree.bottom.edge")
  local scale = piece:GetEffectiveScale() or 1
  local height = (top * native:GetEffectiveScale() - low * journal:GetEffectiveScale()) / scale - edge

  piece:ClearAllPoints()
  piece:SetPoint("BOTTOMLEFT", journal, "BOTTOMLEFT", edge, edge)
  piece:SetPoint("BOTTOMRIGHT", journal, "BOTTOMRIGHT", -edge, edge)
  piece:SetHeight(max(height, Common.get("tree.pieceMinHeight")))

  return true
end

local function reachAll(native)
  local late = false

  for _, piece in ipairs(reachers[native] or {}) do
    if not reachPlace(piece, native) then
      late = true
    end
  end

  if late then
    reachDriver = reachDriver or CreateFrame("Frame")
    reachDriver:SetScript("OnUpdate", function(self)
      local again = false

      for native in pairs(reachers) do
        for _, piece in ipairs(reachers[native]) do
          if not reachPlace(piece, native) then
            again = true
          end
        end
      end

      if not again then
        self:SetScript("OnUpdate", nil)
      end
    end)
  end
end

function DressTree.reach(piece, native)
  local list = reachers[native]

  if not list then
    list = {}
    reachers[native] = list

    local function ping()
      reachAll(native)
    end

    for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight" }) do
      if type(hooksecurefunc) == "function" and type(native[method]) == "function" then
        pcall(hooksecurefunc, native, method, ping)
      end
    end

    if type(native.HookScript) == "function" then
      pcall(native.HookScript, native, "OnSizeChanged", ping)
    end

    local journal = Frame("CollectionsJournal")

    if journal and type(journal.HookScript) == "function" then
      pcall(journal.HookScript, journal, "OnSizeChanged", ping)
    end
  end

  list[#list + 1] = piece
  reachAll(native)
end

local searchAfter
local searchOrigin

function DressTree.setSearchAfter(frame)
  searchAfter = frame
end

local function searchRelease(search)
  if not (search and searchOrigin and searchOrigin.native == search) then
    return
  end

  SET.points(search, searchOrigin.points)

  searchOrigin = nil
end

local function searchDock(search, after)
  if not searchOrigin then
    searchOrigin = { native = search, points = GET.points(search) }
  end

  search:ClearAllPoints()
  search:SetPoint("LEFT", after, "RIGHT", S("tree.dense.gap"), 0)
end

-- Niveau le plus haut de la barre native de PE et de ses enfants : posee dans la tuile journal.footer (skins a tuiles), elle
-- n'est plus enfant de l'arbre et topLevel() ne la voit pas ; les compteurs et le bouton de STAL doivent la depasser.
local function barTop(bar)
  if not bar then
    return 0
  end

  local top = bar:GetFrameLevel()

  for _, child in ipairs({ bar:GetChildren() }) do
    top = max(top, child:GetFrameLevel())
  end

  return top
end

-- Les enfants de bottomFrame (compteurs et boutons de STAL) sont crees a bas niveau : bottomFill (frere, niveau de topLevel())
-- les recouvrirait. Chaque enfant et sous-cadre est releve au-dessus de bottomFrame ; l'ordre relatif des freres est conserve.
function DressTree.liftChildren(frame, floor)
  local children = { frame:GetChildren() }
  local low

  for _, child in ipairs(children) do
    local level = child:GetFrameLevel()
    low = low and min(low, level) or level
  end

  if not low then
    return
  end

  local delta = floor - low

  for _, child in ipairs(children) do
    if delta > 0 then
      child:SetFrameLevel(child:GetFrameLevel() + delta)
    end

    DressTree.liftChildren(child, child:GetFrameLevel() + 1)
  end
end

function DressTree.liftBottom()
  if bottomFrame and bottomFill and bottomFill:IsShown() then
    DressTree.liftChildren(bottomFrame, bottomFrame:GetFrameLevel() + 1)
  end
end

function dressBottom(bar, search)
  local searchShown = search and not searchHidden()
  local docked = bar and searchShown and bottomClaimed() and searchAfter ~= nil

  if not docked then
    searchRelease(search)
  end

  bottomFrame:ClearAllPoints()

  if bar then
    bottomFrame:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)

    if searchShown and not docked and not bottomClaimed() then
      bottomFrame:SetPoint("BOTTOMRIGHT", search, "BOTTOMLEFT", 0, 0)
    else
      bottomFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    end
  else
    bottomFrame:SetPoint("BOTTOMLEFT", tree, "BOTTOMLEFT", 0, 0)
    bottomFrame:SetPoint("BOTTOMRIGHT", tree, "BOTTOMRIGHT", 0, 0)
  end

  bottomFrame:SetHeight(S("tree.bottom.height"))
  local keep = not bottomClaimed()

  if keep then
    Bricks.unframe(bottomFrame)

    if bottomFill then
      bottomFill:Hide()
    end
  else
    if not bottomFill then
      bottomFill = CreateFrame("Frame", nil, tree)
    end

    Bricks.frame(bottomFill, EbonAPI.Replace.look("tree.bottom.frame"), S("tree.bottom.fill"), Bricks.edge(S("tree.bottom.border"), S("tree.bottom.fill")))
    bottomFill:SetFrameLevel(max(0, topLevel(), barTop(bar)))
    bottomFill:Show()
    Bricks.unframe(bottomFrame)

    if not bottomFill.reached then
      bottomFill.reached = true
      DressTree.reach(bottomFill, bottomFrame)
    end
  end

  bottomFrame:SetFrameLevel(keep and tree:GetFrameLevel() or (max(topLevel(), barTop(bar)) + S("tree.stack.levelStep")))

  if docked then
    searchDock(search, searchAfter)
  end

  DressTree.liftBottom()

  local searchPiece = DressTree.searchPiece

  if searchPiece and search and searchPiece.SetFrameLevel then
    searchPiece:SetFrameLevel(max(0, docked and (bottomFrame:GetFrameLevel() + S("tree.stack.levelStep")) or search:GetFrameLevel()))
  end

  if bar then
    hideRegions(bar)

    for _, child in ipairs({ bar:GetChildren() }) do
      if child ~= search and child ~= DressTree.searchPiece then
        keepOrHide(child, keep)
      end
    end
  end

  local pools = tree.poolTexts

  if type(pools) == "table" then
    for _, text in ipairs(pools) do
      keepOrHide(text, keep)
    end
  end

  keepOrHide(tree.pointsText, keep)

  if search then
    keepOrHide(search, not searchHidden())

    local piece = DressTree.searchPiece

    if piece and piece.syncSearch then
      piece.syncSearch()
    end
  end
end
end

local function dressFrame()
  local journal = Frame("CollectionsJournal")

  if journal then
    for _, key in ipairs(FRAME_KEYS) do
      remove(journal[key])
    end
  end

  if tree then
    remove(findCover())
  end
end

local function isNativeArt(region)
  local texture = region.GetTexture and region:GetTexture()

  return type(texture) == "string" and texture:lower():find(Common.get("journal.nativeArt"), 1, true) ~= nil
end

local function dressNatives()
  local inset = Frame("skillTreeInset")

  dressFrame()

  if inset then
    hideRegions(inset)
  end

  for _, child in ipairs({ tree:GetChildren() }) do
    if not isMine(child) then
      for _, region in ipairs({ child:GetRegions() }) do
        if isNativeArt(region) then
          hide(child)
          break
        end
      end
    end
  end
end

local TAB_LIMIT = 12

local function tabsOf()
  local out = {}
  local journal = Frame("CollectionsJournal")
  local limit = max(TAB_LIMIT, journal and tonumber(journal.numTabs) or 0)

  for index = 1, limit do
    local tab = Frame(TAB_NAME .. index)

    if tab then
      out[#out + 1] = tab
    end
  end

  return out
end

local function activeTab(tab)
  local journal = Frame("CollectionsJournal")

  if journal and journal.selectedTab ~= nil then
    return journal.selectedTab == tab:GetID()
  end

  local mark = Frame((tab:GetName() or "") .. "LeftDisabled")

  return mark ~= nil and mark:IsShown() and true or false
end

local jfondOf
local jplate, jchrome, jportrait, jhead, jnav, jfoot, tabHome
local footMoved = {}

local function journalShown()
  local journal = Frame("CollectionsJournal")

  return journal ~= nil and journal:IsShown() and true or false
end

local function buildJournal(journal)
  if jplate then
    return
  end

  jplate = CreateFrame("Frame", nil, journal)
  jplate:SetAllPoints(journal)
  jchrome = CreateFrame("Frame", nil, journal)
  jchrome:SetAllPoints(journal)
  jhead = CreateFrame("Frame", nil, journal)
  jnav = CreateFrame("Frame", nil, jchrome)
  jfoot = CreateFrame("Frame", nil, journal)
end

local function titleOf()
  return Frame("CollectionsJournalTitleText")
end

local function closeOf()
  local journal = Frame("CollectionsJournal")

  return Frame("CollectionsJournalCloseButton") or (journal and journal.CloseButton)
end

local portraitGeometry
local panelSide = nil
local panelSideSet = false

local function mirrored()
  return panelSide == "LEFT" and jhead ~= nil and not jhead.adoptOrigin
end

local function portraitEdge()
  if mirrored() then
    local journal = Frame("CollectionsJournal")

    if not journal then
      return 0
    end

    local width, _, _, x = portraitGeometry(journal)

    return width + math.abs(x or 0)
  end

  if jportrait and jportrait.GetWidth then
    local left = jhead and jhead.GetLeft and jhead:GetLeft()
    local right = jportrait.GetRight and jportrait:GetRight()

    if left and right then
      return max(0, right - left)
    end

    local point, _, _, x = jportrait:GetPoint(1)

    if type(point) == "string" and point:find("LEFT") then
      return (x or 0) + jportrait:GetWidth()
    end

    return 0
  end

  local journal = Frame("CollectionsJournal")

  if not journal then
    return 0
  end

  local width, _, point, x = portraitGeometry(journal)

  if type(point) == "string" and point:find("LEFT") then
    return x + width
  end

  return 0
end

local notice, noticeText, placeNotice, titleListeners, hideNativeArt, dressTitle
do
local carrier, carrierHooked = nil, false
notice, noticeText = nil, ""

function placeNotice()
  if not jhead then
    return
  end

  if noticeText == "" then
    if notice then
      notice:Hide()
    end

    return
  end

  local native = titleOf()

  if not native then
    return
  end

  if not notice then
    notice = Bricks.text(jhead, "small", "danger")
  end

  local ref = (jhead.adoptOrigin and carrier) or native

  notice:SetJustifyH("CENTER")
  notice:SetPoint("TOP", ref, "BOTTOM", 0, -S("kit.gap"))
  notice:SetText(noticeText)
  notice:Show()
end

local function carryTitle(native)
  if not jhead.adoptOrigin then
    if carrier then
      carrier:Hide()
    end

    return
  end

  if not carrier then
    carrier = Bricks.text(jhead, S("page.title.font"), S("page.title.color"))
    carrier:SetWordWrap(false)
  end

  if not carrierHooked and type(hooksecurefunc) == "function" then
    carrierHooked = pcall(hooksecurefunc, native, "SetText", function(_, text)
      carrier:SetText(text or "")
      placeNotice()
    end)
  end

  Bricks.font(carrier, S("page.title.font"))
  Bricks.paint(carrier, "SetTextColor", S("page.title.color"))
  carrier:SetJustifyH(native:GetJustifyH())
  carrier:SetText(native:GetText() or "")
  SET.points(carrier, GET.points(native))
  hide(native)
  carrier:Show()
end

local placing, nativeHooked, hookedText, hookedPoint = false, false, false, false
titleListeners = {}
local TWIN_DEPTH = 8

local function placeTitle(native)
  local pieces = EbonAPI.DressPieces
  local clear = portraitEdge()
  local half = S("header.banner.width") / 2 - S("header.banner.pad")
  local top = S("header.banner.y") - S("header.banner.titleY")

  placing = true
  local ok, err = pcall(function()
    native:SetJustifyH("CENTER")
    set(native, "points", {
      n = 2,
      { "TOPLEFT", jhead, "TOP", -half, top },
      { "TOPRIGHT", jhead, "TOP", half, top },
    })

    native:Show()

    if pieces and pieces.title then
      Dress.guard(OWNER, pieces.title, { title = native, frame = Frame("CollectionsJournal"), clear = clear, anchor = jhead })
    end
  end)
  placing = false

  if not ok then
    Dress.guard(OWNER, function() error(err, 0) end)
  end
end

local function ours(frame)
  local fname = frame.GetName and frame:GetName()

  return fname and (fname:find("^EbonAPI") or fname:find("^STAL")) and true or false
end

local function hideTwins(native)
  local text = native:GetText()

  if not text or text == "" then
    return
  end

  local skip = { [native] = true, [jplate] = true, [jchrome] = true, [jhead] = true, [jnav] = true, [jfoot] = true }

  if tree then
    skip[tree] = true
  end

  if carrier then
    skip[carrier] = true
  end

  for _, tab in ipairs(tabsOf()) do
    skip[tab] = true
  end

  local function walk(frame, depth)
    if skip[frame] or depth > TWIN_DEPTH or (depth > 0 and ours(frame)) then
      return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
      if not skip[region] and region.GetObjectType and region:GetObjectType() == "FontString" and region:GetText() == text then
        hide(region)
      end
    end

    for _, child in ipairs({ frame:GetChildren() }) do
      walk(child, depth + 1)
    end
  end

  walk(Frame("CollectionsJournal"), 0)
end

local function hookNativeTitle(native)
  if nativeHooked or type(hooksecurefunc) ~= "function" then
    return
  end

  local function again()
    Dress.guard(OWNER, function()
      if journalOn and not placing and jhead then
        placeTitle(native)
        hideTwins(native)
        placeNotice()
      end

      for _, listener in ipairs(titleListeners) do
        listener()
      end
    end)
  end

  if not hookedText then
    hookedText = pcall(hooksecurefunc, native, "SetText", again)
  end

  if not hookedPoint then
    hookedPoint = pcall(hooksecurefunc, native, "SetPoint", again)
  end

  nativeHooked = hookedText and hookedPoint
end

function hideNativeArt()
  local journal = Frame("CollectionsJournal")

  if not journal then
    return
  end

  local skip = {}

  for _, piece in ipairs({ jplate or false, jchrome or false, jhead or false, jnav or false, jfoot or false,
      jportrait or false, carrier or false, tree or false, closeOf() or false }) do
    if piece then
      skip[piece] = true
    end
  end

  for _, tab in ipairs(tabsOf()) do
    skip[tab] = true
  end

  local function walk(frame, depth)
    if not walked[frame] then
      walked[frame] = true

      for _, region in ipairs({ frame:GetRegions() }) do
        if isNativeArt(region) then
          hide(region)
        end
      end
    end

    if depth >= 8 then
      return
    end

    for _, child in ipairs({ frame:GetChildren() }) do
      if not skip[child] and not isMine(child) and not ours(child) then
        walk(child, depth + 1)
      end
    end
  end

  walk(journal, 0)
end

function dressTitle()
  local native = titleOf()

  if not native then
    return
  end

  placeTitle(native)
  hookNativeTitle(native)
  carryTitle(native)
  hideTwins(native)
  placeNotice()
end
end

local dressTabs
do
local TAB_PARTS = Dress.TAB_PARTS
local dragged = {}

local function liftTabs()
  local level = jnav:GetFrameLevel() + 1

  for _, tab in ipairs(tabsOf()) do
    if tab:GetFrameLevel() < level then
      tab:SetFrameLevel(level)
    end
  end
end

local seenTab = setmetatable({}, { __mode = "k" })

local function hideNativeTab(tab)
  local name = tab:GetName() or ""

  for _, suffix in ipairs(TAB_PARTS) do
    hide(Frame(name .. suffix))
  end

  hide(tab.GetFontString and tab:GetFontString())
  hideRegions(tab)
end

local function guardTab(tab)
  if seenTab[tab] then
    return
  end

  seenTab[tab] = true
  tab:HookScript("OnShow", function()
    if journalOn then
      hideNativeTab(tab)

      local widget = overlays[tab]

      if widget then
        widget:SetSelected(activeTab(tab))
        widget:Show()
      end
    end
  end)
end

local function dragThrough(tab)
  if dragged[tab] then
    return
  end

  dragged[tab] = true
  tab:RegisterForDrag("LeftButton")

  for _, script in ipairs({ "OnDragStart", "OnDragStop" }) do
    tab:HookScript(script, function()
      local run = journalOn and jnav and jnav.adoptOrigin and jnav:GetScript(script)

      if run then
        run(jnav)
        liftTabs()
      end
    end)
  end
end

function dressTabs()
  local natives = tabsOf()
  local pieces = EbonAPI.DressPieces
  local P = { tabs = {} }
  local width, height = 0, 0

  if natives[1] and not jnav.adoptOrigin then
    jnav:ClearAllPoints()
    jnav:SetPoint("TOPLEFT", natives[1], "TOPLEFT", 0, 0)
  end

  jnav:SetFrameLevel(jchrome:GetFrameLevel())
  liftTabs()

  for _, tab in ipairs(natives) do
    local widget = overlays[tab]

    guardTab(tab)

    if tab:IsShown() then
      local parts = {}
      local name = tab:GetName() or ""

      for _, suffix in ipairs(TAB_PARTS) do
        local part = Frame(name .. suffix)

        if part then
          parts[suffix] = part
          hide(part)
        end
      end

      local text = tab.GetFontString and tab:GetFontString()

      hide(text)
      hideRegions(tab)
      width = width + tab:GetWidth() - S("tree.tab.trim")
      height = max(height, tab:GetHeight())

      if pieces and pieces.overlay and parts.LeftDisabled then
        overlays[tab] = pieces.overlay(tab, "tab")
        follow(tab)
        dragThrough(tab)
        P.tabs[#P.tabs + 1] = { button = tab, parts = parts, text = text }
      end
    else
      hideNativeTab(tab)

      if widget then
        widget:Hide()
      end
    end
  end

  if pieces and pieces.dressTabs and #P.tabs > 0 then
    Dress.guard(OWNER, pieces.dressTabs, P)
  end

  for _, entry in ipairs(P.tabs) do
    local widget = overlays[entry.button]

    if widget then
      for _, piece in ipairs({ entry.button:GetChildren() }) do
        if piece ~= widget and not piece.SetBackdropColor then
          piece:ClearAllPoints()
          piece:SetPoint("TOPLEFT", entry.button, "TOPLEFT", 0, 0)
          piece:SetPoint("BOTTOMRIGHT", entry.button, "BOTTOMRIGHT", 0, 0)
          piece:SetWidth(entry.button:GetWidth())
          piece:SetHeight(entry.button:GetHeight())
        end
      end

      local active = activeTab(entry.button)

      for _, piece in ipairs({ entry.button:GetChildren() }) do
        if piece ~= widget and piece.SetBackdropColor then
          Dress.paintUnder(piece, active)
        end
      end

      widget:SetSelected(active)
      widget:Show()
    end
  end

  jnav:SetSize(max(width, 1), max(height, 1))
end
end

local function dressHead(journal)
  if not jhead.adoptOrigin then
    jhead:ClearAllPoints()
    jhead:SetPoint("TOPLEFT", journal, "TOPLEFT", 0, 0)
    jhead:SetPoint("TOPRIGHT", journal, "TOPRIGHT", 0, 0)
  end

  local native = closeOf()

  jhead:SetFrameLevel(journal:GetFrameLevel() + 1)
  jhead:SetWidth(max(journal:GetWidth() or 0, 1))
  jhead:SetHeight(max(-S("tree.title.drop") + heightOf(titleOf()), S("window.padding") + (native and native:GetHeight() or 0), 1))
  local portraitInset = jportrait and jportrait:GetWidth() or 0
  local crossInset = (native and native:GetWidth() or 0) + S("window.padding")

  if mirrored() then
    jhead:SetHitRectInsets(crossInset, portraitInset, 0, 0)
  else
    jhead:SetHitRectInsets(portraitInset, crossInset, 0, 0)
  end
end

local dressPortrait, crossUnpin, dressCross, crossPlace
do
local portraitIcon, portraitPath

local function paintPortrait(path)
  if path and jportrait then
    jportrait:SetIcon(path)
  end
end

Dress.onPortrait(function(texture, path)
  if jportrait and texture == jportrait.icon then
    return
  end

  if texture == portraitIcon or texture == rawget(_G, "CollectionsJournalPortrait") then
    portraitPath = path

    if journalOn then
      paintPortrait(path)
    end
  end
end)

portraitGeometry = function(journal)
  local frame = journal.PortraitFrame
  local width, height = S("tree.journal.portraitSize"), S("tree.journal.portraitSize")
  local point, x, y = "TOPLEFT", S("tree.journal.portraitLeft"), S("tree.journal.portraitTop")

  if frame and frame.GetWidth and frame:GetWidth() and frame:GetWidth() > 0 then
    width, height = frame:GetWidth(), frame:GetHeight()
  end

  if frame and frame.GetPoint then
    local p, _, _, px, py = frame:GetPoint(1)

    if p then
      point, x, y = p, px or 0, py or 0
    end
  end

  return width, height, point, x, y
end

function dressPortrait(journal)
  local icon = journal.portrait
  local width, height, point, x, y = portraitGeometry(journal)
  local ix = S("tree.journal.iconLeft")

  if icon and icon.GetPoint then
    local _, _, _, px = icon:GetPoint(1)

    ix = px or ix
  end

  local ringColor = S("tree.journal.ringColor")
  local inset = max(0, ix - x)
  local ringInset = S("tree.journal.ringInset")
  local key = width .. ":" .. inset .. ":" .. ringInset

  if not jportrait or jportrait.geometry ~= key then
    if jportrait then
      jportrait:Hide()
    end

    jportrait = EbonAPI.Kit.create("EbonAPI", "portrait", jchrome, { size = width, round = true, inset = inset, ringInset = ringInset })
    jportrait.geometry = key
  end

  jportrait:ClearAllPoints()
  if mirrored() then
    point = point:gsub("LEFT", "RIGHT")
    x = -x
  end

  jportrait:SetPoint(point, jhead, point, x, y)
  jportrait:SetSize(width)
  jportrait:SetRing(type(ringColor) == "string" and ringColor ~= "" and ringColor or nil)

  portraitIcon = icon

  local path = portraitPath or (icon and Dress.portraitPath(icon))

  paintPortrait(path)
  jportrait:Show()

  -- controls=LEFT : la croix du skin est a gauche du Journal, sous le portrait qui deborde de l'entete ; elle passe au-dessus.
  local native = S("header.controls") == "LEFT" and closeOf()

  if native then
    local want = jportrait:GetFrameLevel() + S("tree.stack.levelStep")

    if native:GetFrameLevel() < want then
      native:SetFrameLevel(want)
      Bricks.relevel()
    end
  end
end

local crossSaved = nil

local function crossKeep(native)
  if journalOn then
    crossSaved = crossSaved or GET.points(native)
  end
end

function crossUnpin(native)
  if crossSaved and native then
    SET.points(native, crossSaved)
  end

  crossSaved = nil
end

function dressCross()
  local native = closeOf()
  local pieces = EbonAPI.DressPieces

  if not native or not (pieces and pieces.cross) then
    return
  end

  local parts = {}

  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    local part = native[getter] and native[getter](native)

    if part then
      parts[#parts + 1] = part
      hide(part)
    end
  end

  if not overlays[native] then
    follow(native)
  end

  crossKeep(native)
  Dress.guard(OWNER, pieces.cross, { cross = { button = native, parts = parts }, frame = Frame("CollectionsJournal") })
  overlays[native] = pieces.overlay(native, "close")
end

function crossPlace()
  local native, journal = closeOf(), Frame("CollectionsJournal")

  if not (native and journal and jhead and S("windows.tile.content")) then
    return
  end

  local left = S("header.controls") == "LEFT"
  local edge = Dress.controlsEdge()
  local y = Dress.middleOffset(native, journal)

  native:ClearAllPoints()
  native:SetPoint(left and "LEFT" or "RIGHT", jhead, left and "TOPLEFT" or "TOPRIGHT", left and edge or -edge, y)
end
end

local stackHook, tilesApply
do
local BOARD_FRAME = "EbonholdCallboardFrame"

local function layerRoots(names)
  return function()
    local out = {}

    if journalOn then
      for _, name in ipairs(names) do
        local frame = Frame(name)

        if frame and frame.GetFrameStrata then
          out[#out + 1] = frame
        end
      end
    end

    return out
  end
end

function stackHook()
  local Windows = EbonAPI.Windows

  Windows.layer("journal", layerRoots({ "CollectionsJournal", "skillTreeFrame" }), { shallow = { skillTreeFrame = true } })
  Windows.layer("callboard", layerRoots({ BOARD_FRAME }))
end

local TILE_GROUP = "journal"

local function footItems(journal)
  local name = S("tree.journal.tabs")[journal.selectedTab or 0]
  local names = name and Skins.value("tree.journal.footer." .. name)
  local out = {}

  for _, path in ipairs(names or {}) do
    local node = _G
    local first = true

    for part in tostring(path):gmatch("[^.]+") do
      if first then
        node = rawget(_G, part)
        first = false
      else
        node = type(node) == "table" and node[part] or nil
      end
    end

    if type(node) == "table" and node.SetParent then
      out[#out + 1] = node
    end
  end

  return out
end

local function footGive(entry)
  local frame, origin = entry[1], entry[2]

  frame:SetParent(origin.parent)
  SET.points(frame, origin.points)
  frame:SetFrameLevel(origin.level)
end

local function footRelease(keep)
  for index = #footMoved, 1, -1 do
    local entry = footMoved[index]

    if not (keep and keep[entry[1]]) then
      footGive(entry)
      table.remove(footMoved, index)
    end
  end
end

local function footFill(items, gap)
  local keep = {}

  for _, item in ipairs(items) do
    keep[item] = true
  end

  footRelease(keep)

  local previous

  for _, item in ipairs(items) do
    local origin

    for _, entry in ipairs(footMoved) do
      if entry[1] == item then
        origin = entry[2]
      end
    end

    if not origin then
      local points = GET.points(item)

      origin = { parent = item:GetParent(), points = points, level = item:GetFrameLevel(), bar = points.n > 1 }
      footMoved[#footMoved + 1] = { item, origin }
    end

    item:SetParent(jfoot)
    item:ClearAllPoints()
    item:SetFrameLevel(jfoot:GetFrameLevel() + 2)

    if origin and origin.bar then
      item:SetPoint("BOTTOMLEFT", jfoot, "BOTTOMLEFT", gap, gap)
      item:SetPoint("BOTTOMRIGHT", jfoot, "BOTTOMRIGHT", -gap, gap)
    elseif previous then
      item:SetPoint("LEFT", previous, "RIGHT", gap, 0)
    else
      item:SetPoint("LEFT", jfoot, "LEFT", gap, 0)
    end

    previous = item
  end
end

function tilesApply(on)
  local journal = Frame("CollectionsJournal")
  local Windows = EbonAPI.Windows

  if not (journal and jhead and jnav and jfoot and Windows and Windows.apply) or (InCombatLockdown and InCombatLockdown()) then
    return
  end

  local function wish(key)
    return on ~= false and EbonAPI.Window.detached(key)
  end

  local gap = Skins.value("windows.gap")
  local first = Frame(TAB_NAME .. "1")

  jhead:EnableMouse(wish("header"))
  Windows.apply("journal.header", jhead, TILE_GROUP, wish("header"), function(frame)
    frame:SetPoint("BOTTOMLEFT", journal, "TOPLEFT", 0, gap)
    frame:SetPoint("BOTTOMRIGHT", journal, "TOPRIGHT", 0, gap)
  end)

  if first and not wish("nav") and tabHome then
    SET.points(first, tabHome)
    tabHome = nil
  end

  if first and wish("nav") and not tabHome then
    tabHome = GET.points(first)
  end

  jnav:EnableMouse(wish("nav"))
  Windows.apply("journal.nav", jnav, TILE_GROUP, wish("nav"), function(frame)
    local home = tabHome and tabHome[1]

    frame:SetPoint("TOPLEFT", journal, "BOTTOMLEFT", home and home[4] or 0, (home and home[5] or 0) - gap)
  end)

  if first and wish("nav") and jnav.adoptOrigin then
    first:ClearAllPoints()
    first:SetPoint("TOPLEFT", jnav, "TOPLEFT", 0, 0)
  end

  Windows.apply("journal.page", journal, TILE_GROUP, wish("page"))

  local items = wish("footer") and journalShown() and footItems(journal) or {}

  if #items > 0 then
    jfoot:SetFrameLevel(journal:GetFrameLevel() + 1)
    jfoot:SetSize(max(journal:GetWidth() or 0, 1), max(Skins.value("tree.journal.footerHeight") or 1, 1))
  end

  local footOn = #items > 0

  jfoot:EnableMouse(footOn)
  Windows.apply("journal.footer", jfoot, TILE_GROUP, footOn, function(frame)
    local anchor = jnav.adoptOrigin and jnav or nil

    if anchor then
      frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    else
      frame:SetPoint("TOPLEFT", journal, "BOTTOMLEFT", 0, -gap)
    end
  end)

  if #items > 0 and jfoot.adoptOrigin then
    footFill(items, gap)
    jfoot:Show()
  else
    footRelease()
    jfoot:Hide()
  end
end

local fondKinds = { "journal.header", "journal.nav", "journal.page", "journal.footer" }

local function fondPlace(kind, frame, target, margin)
  local pieces = EbonAPI.DressPieces
  local fond = pieces and pieces.tile and pieces.tile(kind, frame)

  if not fond then
    return nil
  end

  fond:ClearAllPoints()
  fond:SetPoint("TOPLEFT", target, "TOPLEFT", -margin, margin)
  fond:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", margin, -margin)
  fond:Show()

  return fond
end

local fondShown = {}

local function fondHide(kind)
  local fond = fondShown[kind]

  if fond then
    fond:Hide()
    fondShown[kind] = nil
  end
end

local jspan

local function spanOf(journal, frames)
  if #frames == 1 then
    return frames[1]
  end

  jspan = jspan or CreateFrame("Frame", nil, journal)
  jspan:ClearAllPoints()

  local first, last = frames[1], frames[#frames]
  local left, top, right, bottom

  for _, frame in ipairs(frames) do
    local l, t, r, b = frame:GetLeft(), frame:GetTop(), frame:GetRight(), frame:GetBottom()

    if not (l and t and r and b) then
      jspan:SetPoint("TOPLEFT", first, "TOPLEFT", 0, 0)
      jspan:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 0, 0)

      return jspan
    end

    left, top = left and min(left, l) or l, top and max(top, t) or t
    right, bottom = right and max(right, r) or r, bottom and min(bottom, b) or b
  end

  jspan:SetPoint("TOPLEFT", first, "TOPLEFT", left - first:GetLeft(), top - first:GetTop())
  jspan:SetPoint("BOTTOMRIGHT", first, "BOTTOMRIGHT", right - first:GetRight(), bottom - first:GetBottom())

  return jspan
end

local function pageFrames(entry)
  local frames = {}

  for name in entry:gmatch("[^+]+") do
    local frame = Frame(name)

    if frame and frame:IsShown() then
      frames[#frames + 1] = frame
    elseif not entry:find("+", 1, true) then
      return nil
    end
  end

  return #frames > 0 and frames or nil
end

local function contentOf(journal)
  if not S("windows.tile.content") then
    return nil
  end

  for _, entry in ipairs(S("windows.tilePages")) do
    local frames = pageFrames(entry)

    if frames then
      return spanOf(journal, frames)
    end
  end

  return nil
end

jfondOf = function(journal)
  if not journal then
    for _, kind in ipairs(fondKinds) do
      fondHide(kind)
    end

    return
  end

  local content = contentOf(journal)
  local wants = {}

  if content then
    wants["journal.page"] = { journal, content, true }
  elseif not S("windows.tile.content") then
    wants["journal.page"] = { journal, journal, journal.adoptOrigin }
  end

  if jhead.adoptOrigin then
    wants["journal.header"] = { jhead, jhead, true }
  end

  if jnav.adoptOrigin then
    wants["journal.nav"] = { jnav, jnav, true }
  end

  if jfoot.adoptOrigin and jfoot:IsShown() then
    wants["journal.footer"] = { jfoot, jfoot, true }
  end

  for _, kind in ipairs(fondKinds) do
    local want = wants[kind]

    if want then
      local margin = want[3] and S("window.padding") or 0

      fondShown[kind] = fondPlace(kind, want[1], want[2], margin)
    else
      fondHide(kind)
    end
  end
end
end

local function dressJournal()
  local journal = Frame("CollectionsJournal")

  if not wanted or not journal then
    return false
  end

  local fresh = not journalOn

  buildJournal(journal)
  journalOn = true

  local top = journal:GetFrameLevel()

  for _, child in ipairs({ journal:GetChildren() }) do
    if child ~= jplate and child ~= jchrome then
      top = max(top, child:GetFrameLevel())
    end
  end

  jplate:SetFrameLevel(journal:GetFrameLevel())
  jplate:Show()
  jchrome:SetFrameLevel(top + S("tree.stack.levelStep"))
  jchrome:Show()
  dressFrame()
  hideNativeArt()
  dressPortrait(journal)
  dressTitle()
  dressHead(journal)
  dressTabs()
  dressCross()
  crossPlace()
  jhead:Show()
  jnav:Show()
  tilesApply()
  jfondOf(journal)
  stackHook()

  if fresh then
    EbonAPI.Windows.front("journal")
  end

  return true
end

local PANEL_WIDTH = "UIPanelLayout-width"
local PANEL_OFFSET = "UIPanelLayout-xoffset"
local panelOrigin

local function panelDeclare(journal, width)
  if journal:GetAttribute(PANEL_WIDTH) == width then
    return
  end

  journal:SetAttribute(PANEL_WIDTH, width)

  if journal:IsShown() and type(UpdateUIPanelPositions) == "function" then
    UpdateUIPanelPositions(journal)
  end
end

local function panelSync(journal)
  if panelOrigin == nil then
    panelOrigin = journal:GetAttribute(PANEL_WIDTH) or false
  end

  local width = journal:GetWidth()

  if panelOrigin and width and width > 0 then
    panelDeclare(journal, width + 2 * (journal:GetAttribute(PANEL_OFFSET) or 0))
  end
end

local function panelRestore()
  local journal = Frame("CollectionsJournal")

  if journal and panelOrigin then
    panelDeclare(journal, panelOrigin)
  end
end

local function journalOff()
  journalOn = false
  panelRestore()
  crossUnpin(closeOf())
  unblock()
  restoreAll()

  for _, widget in pairs(overlays) do
    widget:Hide()
  end

  if jplate then
    jhead:Hide()
    jnav:Hide()
    jfoot:Hide()
    jplate:Hide()
    jchrome:Hide()
    if jportrait then
      jportrait:Hide()
    end

    jfondOf(nil)
  end

  if EbonAPI.Replace and EbonAPI.Replace.undressAll then
    pcall(EbonAPI.Replace.undressAll)
  end
end

local journalUpdate, dressSurface
do
local stretched = {}

local function spreadPrestige(frame, delta)
  local tops = {}

  for _, list in ipairs({ { frame:GetRegions() }, { frame:GetChildren() } }) do
    for _, item in ipairs(list) do
      local point, relative, relPoint, x, y = item:GetPoint(1)

      if point == "TOP" and relative == frame and relPoint == "TOP" and y then
        tops[#tops + 1] = { item = item, x = x, y = y }
      end
    end
  end

  table.sort(tops, function(a, b)
    return a.y > b.y
  end)

  for index, top in ipairs(tops) do
    local share = index == 1 and delta / 3 or delta * 2 / 3
    top.item:ClearAllPoints()
    top.item:SetPoint("TOP", frame, "TOP", top.x, top.y - share)
  end
end

local function unify(journal)
  local H = S("tree.journal.height")

  if not H then
    return
  end

  local cur = journal:GetHeight()

  if cur == H then
    return
  end

  local delta = H - cur
  journal:SetHeight(H)

  for _, nom in ipairs({"ProjectEbonholdEchoJournal", "skillTreeFrame", "WardrobeFrame", "EbonholdPrestigeFrame"}) do
    local f = rawget(_G, nom)

    if f and f:IsShown() and f:GetHeight() ~= stretched[nom] then
      f:SetHeight(f:GetHeight() + delta)
      stretched[nom] = f:GetHeight()

      if nom == "EbonholdPrestigeFrame" then
        spreadPrestige(f, delta)
      end
    end
  end
end

function journalUpdate()
  local journal = Frame("CollectionsJournal")

  if not wanted or not journal or not journal:IsShown() then
    return
  end

  if not (InCombatLockdown and InCombatLockdown()) then
    unify(journal)
  end

  Dress.guard(OWNER, dressJournal)
  Dress.guard(OWNER, panelSync, journal)

  local name = S("tree.journal.tabs")[journal.selectedTab or 0]

  if name and EbonAPI.Replace and EbonAPI.Replace.dressTab then
    Dress.guard(OWNER, EbonAPI.Replace.dressTab, name)
  end
end


local function portraitDrop(offset)
  if not (clearPortrait or (surface:GetNumChildren() or 0) > 0) or not jportrait or not tree or (jhead.adoptOrigin and S("header.controls") ~= "LEFT") then
    return 0
  end

  local owner = jportrait:GetParent() and jportrait:GetParent():GetParent()
  local bottom = jportrait:GetBottom()
  local top = tree:GetTop()

  if not (owner and bottom and top) or not jportrait:IsShown() then
    return 0
  end

  return max(0, (top + offset) - bottom + S("tree.journal.portraitMargin"))
end

function dressSurface(offset)
  local drop = portraitDrop(offset)

  surface:ClearAllPoints()
  surface:SetPoint("TOPLEFT", tree, "TOPLEFT", 0, offset - drop)
  surface:SetPoint("TOPRIGHT", tree, "TOPRIGHT", 0, offset - drop)
  surface:SetPoint("BOTTOMLEFT", bottomFrame, "TOPLEFT", 0, 0)
  surface:SetPoint("BOTTOMRIGHT", bottomFrame, "TOPRIGHT", 0, 0)

  local gauge = tree.progressBar

  if gauge then
    set(gauge, "points", { n = 1, list("TOP", tree, "TOP", 0, offset) })
    set(gauge, "level", surface:GetFrameLevel() + EbonAPI.Common.get("tree.gaugeLevel"))
  end
end
end

local function titleOffset()
  return tree:IsShown() and (S("tree.title.top") - heightOf(titleOf())) or 0
end

local function teardown(full)
  unblock()
  restoreAll()

  if plate then
    plate:Hide()
    chrome:Hide()
    surface:Hide()
    bottomFrame:Hide()

    if bottomFill then
      bottomFill:Hide()
    end
  end

  local was = applied

  applied = false

  if tree and state ~= "absent" then
    state = "undressed"
  end

  if was then
    EbonAPI:Emit("TREE_UI_UNDRESSED")
  end

  if not full and journalOn and journalShown() and wanted then
    Dress.guard(OWNER, dressJournal)
  else
    journalOff()
  end
end

local function pass(force)
  build()

  local fresh = force or not applied
  local top = topLevel()
  local bar = Frame("skillTreeBottomBar")
  local search = Frame("skillTreeSearchBox")

  layoutPlate(top)
  dressNatives()
  dressBottom(bar, search)

  local offset = 0

  Dress.guard(OWNER, dressJournal)

  offset = titleOffset()

  dressSurface(offset)
  applied = true
  state = "dressed"

  if fresh then
    EbonAPI:Emit("TREE_UI_DRESSED", surface, bottomFrame)

    if bottomClaimed() then
      Bus.after(TIMER .. ".claim", EbonAPI.Common.get("dress.timerDelay"), function()
        if applied and tree then
          Dress.guard(OWNER, dressBottom, Frame("skillTreeBottomBar"), Frame("skillTreeSearchBox"))
        end
      end)
    end
  end
end

local function attempt(force)
  if not tree or not wanted then
    return false
  end

  local ok = Dress.guard(OWNER, pass, force)

  if not ok then
    Dress.guard(OWNER, teardown)
    state = "undressed"
  end

  return ok
end

local function shownTree()
  return tree and tree:IsShown()
end

local function birth()
  if tree then
    return true
  end

  if type(rawget(_G, "skillTreeFrame")) ~= "table" then
    return false
  end

  local frame = Ebonhold.SkillTreeFrame()

  if not frame then
    return false
  end

  tree = frame

  Dress.guard(OWNER, function()
    tree:HookScript("OnShow", function()
      if wanted then
        attempt(false)
      end
    end)
    tree:HookScript("OnHide", function()
      if applied then
        Dress.guard(OWNER, teardown)
      end
    end)
  end)

  Dress.guard(OWNER, EbonAPI.Emit, EbonAPI, "TREE_UI_CREATED", frame)

  return true
end

local function after()
  birth()

  if wanted and shownTree() then
    attempt(false)
  end
end

local function redress()
  if wanted and tree and (applied or shownTree()) then
    attempt(true)
  elseif wanted and journalOn and journalShown() then
    local journal = Frame("CollectionsJournal")
    local name = S("tree.journal.tabs")[journal.selectedTab or 0]

    Dress.guard(OWNER, dressJournal)

    if name and EbonAPI.Replace and EbonAPI.Replace.dressTab then
      Dress.guard(OWNER, EbonAPI.Replace.dressTab, name)
    end
  end
end

local function hookTitle()
  if titleHooked or type(hooksecurefunc) ~= "function" or type(rawget(_G, "CollectionsJournal_UpdateSelectedTab")) ~= "function" then
    return
  end

  titleHooked = true

  hooksecurefunc("CollectionsJournal_UpdateSelectedTab", function()
    if wanted and tree and applied and tree:IsShown() then
      attempt(true)
    end

    journalUpdate()
  end)

  local journal = Frame("CollectionsJournal")

  if journal and journal.HookScript then
    journal:HookScript("OnShow", function()
      journalUpdate()
    end)
    journal:HookScript("OnHide", function()
      if journalOn then
        Dress.guard(OWNER, journalOff)
      end
    end)
    journal:HookScript("OnSizeChanged", function()
      if journalOn and wanted then
        Dress.guard(OWNER, panelSync, journal)
      end
    end)
  end
end

local function install()
  Bus.offCore("PLAYER_LOGIN", install)
  hookTitle()

  if installed then
    return
  end

  installed = true

  local hooked = false

  for _, key in ipairs(HOOKED) do
    if Dress.after(handle, "SkillTree", key, after) then
      hooked = true
    end
  end

  if not hooked then
    state = "absent"
  end

  birth()

  if wanted and shownTree() then
    attempt(false)
  end
end

Bus.onCore("PLAYER_LOGIN", install)

EbonAPI:DeclareSticky("TREE_UI_CREATED")
EbonAPI:DeclareSticky("TREE_UI_DRESSED")
EbonAPI:DeclareSticky("TREE_UI_UNDRESSED")

local function retile()
  if jhead and journalOn and wanted then
    Dress.guard(OWNER, dressJournal)
  elseif jhead then
    Dress.guard(OWNER, tilesApply)
  end
end

local tileWatch = CreateFrame("Frame")

tileWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
tileWatch:SetScript("OnEvent", function()
  journalUpdate()
  retile()
end)

for _, owner in ipairs({ Skins, Bricks }) do
  local name = owner == Skins and "resolve" or "apply"

  if type(hooksecurefunc) == "function" and type(owner[name]) == "function" then
    hooksecurefunc(owner, name, function()
      retile()
    end)
  end
end

if type(hooksecurefunc) == "function" and type(rawget(_G, "UpdateUIPanelPositions")) == "function" then
  hooksecurefunc("UpdateUIPanelPositions", function()
    local journal = Frame("CollectionsJournal")
    local adopted = jhead and (jhead.adoptOrigin or jnav.adoptOrigin or jfoot.adoptOrigin or (journal and journal.adoptOrigin))

    if adopted and journalShown() then
      Dress.guard(OWNER, tilesApply)
    end
  end)
end

EbonAPI:On("PARAMETER_CHANGED", function()
  retile()
  Bus.after(TIMER, EbonAPI.Common.get("dress.timerDelay"), redress)
end)

function DressTree.state()
  if journalOn and state ~= "absent" and not (tree and applied) then
    return "dressed"
  end

  return state
end

function DressTree.journal()
  return jplate, jchrome, titleOf(), jportrait
end

function DressTree.frame()
  return plate
end

function DressTree.clearPortrait(on)
  clearPortrait = on and true or false

  if applied and tree and surface then
    Dress.guard(OWNER, function()
      dressSurface(titleOffset())
      dressBottom(Frame("skillTreeBottomBar"), Frame("skillTreeSearchBox"))
    end)
  end
end

function DressTree.surface()
  return surface
end

function DressTree.bottom()
  return bottomFrame
end

function DressTree.dress()
  wanted = true
  birth()

  if tree then
    attempt(true)
  end

  return state
end

local panelTiled = false

function DressTree.journalFrame()
  return Frame("CollectionsJournal")
end

function DressTree.getPanelSide()
  if not panelSideSet or panelTiled then
    return nil
  end

  return panelSide == "LEFT" and "LEFT" or "RIGHT"
end

function DressTree.setPanelSide(side)
  local want = side == "LEFT" and "LEFT" or nil

  panelSideSet = true
  panelTiled = side == nil

  if want == panelSide then
    return
  end

  panelSide = want

  if journalOn and jhead then
    local journal = Frame("CollectionsJournal")

    if journal then
      Dress.guard(OWNER, function()
        dressPortrait(journal)
        dressTitle()
        dressHead(journal)
      end)
    end
  end
end

function DressTree.setNotice(text)
  text = text and tostring(text) or ""

  if text == noticeText then
    return
  end

  noticeText = text

  if journalOn and jhead then
    Dress.guard(OWNER, placeNotice)
  end
end

function DressTree.title()
  return titleOf()
end

-- called each time PE writes the journal title (tab change), after the title is placed
function DressTree.onTitle(listener)
  titleListeners[#titleListeners + 1] = listener
end

function DressTree.undress()
  wanted = false

  if applied then
    Dress.guard(OWNER, teardown, true)
  end

  journalOff()

  if jhead then
    Dress.guard(OWNER, tilesApply, false)
  end

  if tree and state ~= "absent" then
    state = "undressed"
  end

  return state
end

function DressTree.setSearchHidden(value)
  if value == nil then
    forcedSearch = nil
  else
    forcedSearch = value and true or false
  end

  if applied then
    attempt(true)
  end
end

function EbonAPI:TreeDress()
  return DressTree.dress()
end
