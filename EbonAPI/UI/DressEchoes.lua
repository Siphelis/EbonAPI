local EbonAPI = _G.EbonAPI

local Replace = EbonAPI.Replace
local ipairs, type, rawget, _G = ipairs, type, rawget, _G

local NAMES = {
  myRunInset = "ProjectEbonholdEchoJournalMyRunInset",
  catalogInset = "ProjectEbonholdEchoJournalCatalogInset",
  myRunScroll = "ProjectEbonholdEchoJournalMyRunScroll",
  catalogScroll = "ProjectEbonholdEchoJournalScroll",
  search = "ProjectEbonholdEchoJournalSearchBox",
  filter = "ProjectEbonholdEchoJournalFilterButton",
  loadout = "ProjectEbonholdEchoJournalLoadoutDD",
}

local EDGE_KEYS = {
  "Left", "Middle", "Right", "Top", "Bottom", "Track", "Bg", "Background",
  "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle", "BottomMiddle", "MiddleLeft", "MiddleRight", "MiddleMiddle",
}

local function hideEdges(frame)
  local name = frame and frame.GetName and frame:GetName()

  for _, key in ipairs(EDGE_KEYS) do
    local part = frame[key]

    if type(part) ~= "table" and name then
      part = rawget(_G, name .. key)
    end

    if type(part) == "table" and part.GetAlpha then
      Replace.hide(part)
    end
  end
end

local function scrollBar(scroll)
  if not scroll then
    return nil
  end

  local name = scroll.GetName and scroll:GetName()

  return scroll.ScrollBar or (name and rawget(_G, name .. "ScrollBar")) or nil
end

local scrollLooks = Replace.scrollLooks()

local function hideBarArt(bar, look)
  if type(bar.GetRegions) ~= "function" then
    return
  end

  local thumb = type(bar.GetThumbTexture) == "function" and bar:GetThumbTexture() or nil

  for _, region in ipairs({ bar:GetRegions() }) do
    if region ~= thumb and region ~= (look and look.track) and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture" then
      Replace.hide(region)
    end
  end
end

local function dress()
  scrollLooks:reset()

  for _, key in ipairs({ "myRunInset", "catalogInset" }) do
    local native = rawget(_G, NAMES[key])

    if native then
      Replace.piece(native, "panel", { cover = true })
    end
  end

  for _, key in ipairs({ "myRunScroll", "catalogScroll" }) do
    local bar = scrollBar(rawget(_G, NAMES[key]))

    if bar then
      hideBarArt(bar, scrollLooks:dress(bar))
      hideEdges(bar)
    end
  end

  local search = rawget(_G, NAMES.search)

  if search then
    Replace.piece(search, "input")
    hideEdges(search)
  end

  local filter = rawget(_G, NAMES.filter)

  if filter then
    Replace.piece(filter, "button", { menu = true })
    hideEdges(filter)

    if type(filter.Icon) == "table" and filter.Icon.GetAlpha then
      Replace.hide(filter.Icon)
    end

    Replace.hideButtonArt(filter)
  end
end

local function dressLoadout()
  local dd = rawget(_G, NAMES.loadout)

  if not dd then
    return
  end

  Replace.piece(dd, "button", { menu = true })
  hideEdges(dd)

  local arrow = rawget(_G, NAMES.loadout .. "Button")

  Replace.hideButtonArt(arrow)

  local label = rawget(_G, NAMES.loadout .. "Text")

  if label and label.SetTextColor and EbonAPI.Palette and EbonAPI.Palette.paint then
    EbonAPI.Palette.paint(label, "SetTextColor", "text")
  end
end

local function undress()
  scrollLooks:undress()
end

Replace.tab("Echoes", { dress = function() dress() pcall(dressLoadout) end, undress = undress })
