local Replace = _G.EbonAPI and _G.EbonAPI.Replace
local Skins = _G.EbonAPI and _G.EbonAPI.Skins
local Bricks = _G.EbonAPI and _G.EbonAPI.Bricks

if not Replace then
  return
end

local type, pairs, ipairs, pcall, tonumber = type, pairs, ipairs, pcall, tonumber
local _G = _G

local KEEP = {
  icon = true, texture = true, factionIcon = true, favorite = true, iconBorder = true, unusable = true,
  SubscriptionOverlay = true, AccountOverlay = true, newGlow = true, LockIcon = true,
  Icon = true, NewGlow = true, ActiveTexture = true,
}

local function hideChrome(frame, keep)
  Replace.hideChrome(frame, KEEP, keep)
end

local hideButtonArt = Replace.hideButtonArt

local function swap(native, kind, opts, keep)
  if not native then
    return
  end

  local piece = Replace.piece(native, kind, opts or {})

  hideChrome(native, keep)

  if kind == "button" or kind == "tab" or kind == "close" or kind == "reset" or kind == "row" then
    hideButtonArt(native)
  end

  return Replace.mirror(native, piece)
end

local placer = Replace.placer()
local place, giveBack = placer.place, placer.giveBack

local function placeNeighbours(journal)
  local summon = journal.SummonRandomFavoriteButton
  local text = summon and summon.spellname
  local between = journal.SubscriptionStatus

  if text and between then
    place(text, { { "RIGHT", summon, "LEFT" }, { "LEFT", between, "RIGHT" } })
    text:SetJustifyH("RIGHT")
  end
end

local function placeInfoText(display)
  local info = display.InfoButton
  local first = info and info.SubscriptionInfo
  local margin = tonumber(Skins.value("panel.margin"))

  if first then
    place(first, { { "TOPLEFT", display, "TOPLEFT", margin, -margin } })
  end
end

local function widenModel(display)
  local model = display.ModelFrame
  local info = display.InfoButton

  if model and info then
    placeInfoText(display)
    place(model, { { "TOPLEFT", display, "TOPLEFT" }, { "BOTTOMRIGHT", display, "BOTTOMRIGHT" } })
  end
end

local function rotateArrow(native, left)
  Replace.arrowLabel(swap(native, "button"), left)

  if Bricks and Bricks.fadeNative then
    Bricks.fadeNative(native, 0)
  end
end

local function dressFilter(journal)
  local filter = journal.FilterButton or _G.MountJournalFilterButton

  if not filter then
    return
  end

  swap(filter, "button", { menu = true })

  Replace.hide(filter.Icon)

  Replace.resetCross(filter, "mounts")
end

local function dressScaling(journal)
  local mark = journal.MountButton and journal.MountButton.SubscriptionOverlay

  if mark then
    swap(mark, "slot")
  end
end

local scrollLooks = Replace.scrollLooks()

local inkedRows = setmetatable({}, { __mode = "k" })

local function inkName(row)
  local font = type(row.name.GetFontObject) == "function" and row.name:GetFontObject() or nil
  local off = font ~= nil and font == _G.GameFontDisable

  Replace.ink(row.name, off and "muted" or "text")
end

local hoverPieces = setmetatable({}, { __mode = "k" })
local hoverHooked = setmetatable({}, { __mode = "k" })

local function setHovered(row, over)
  local piece = hoverPieces[row]

  if piece and not piece.released and type(piece.Visual) == "function" then
    piece.hovered = over
    piece:Visual()
  end
end

local function followHover(row, piece)
  hoverPieces[row] = piece

  if hoverHooked[row] or type(row.HookScript) ~= "function" then
    return
  end

  hoverHooked[row] = true
  pcall(row.HookScript, row, "OnEnter", function()
    setHovered(row, true)
  end)
  pcall(row.HookScript, row, "OnLeave", function()
    setHovered(row, false)
  end)
end

local function dressRows(journal)
  local scroll = journal.ListScrollFrame

  for _, row in ipairs(scroll and scroll.buttons or {}) do
    local piece = swap(row, "row")

    Replace.followSelected(row, piece, row.selectedTexture)
    followHover(row, piece)

    if Replace.ink and row.name then
      inkName(row)

      if not inkedRows[row] then
        inkedRows[row] = true

        if type(hooksecurefunc) == "function" then
          -- the native list update calls name:SetFontObject on every refresh, which resets the colour
          if type(row.name.SetFontObject) == "function" then
            pcall(hooksecurefunc, row.name, "SetFontObject", function()
              inkName(row)
            end)
          end

          if row.selectedTexture then
            pcall(hooksecurefunc, row.selectedTexture, "Show", function()
              inkName(row)
            end)
            pcall(hooksecurefunc, row.selectedTexture, "Hide", function()
              inkName(row)
            end)
          end
        end
      end
    end
  end
end

local function dress()
  scrollLooks:reset()

  local journal = rawget(_G, "MountJournal")

  if not journal then
    return
  end

  pcall(dressRows, journal)

  swap(journal.LeftInset, "panel")
  swap(journal.RightInset, "panel")
  swap(journal.MountCount, "panel")
  swap(journal.SubscriptionStatus, "panel")

  local display = journal.MountDisplay

  if display then
    swap(display, "panel")

    if display.ShadowOverlay then
      Replace.hide(display.ShadowOverlay)
    end

    local info = display.InfoButton

    if info then
      hideChrome(info)
      hideButtonArt(info)
      Replace.hide(info.Icon)
      Replace.hide(info.Name)
    end

    for _, key in ipairs({ "RotateLeftButton", "RotateRightButton" }) do
      local rotate = display.ModelFrame and display.ModelFrame[key]

      if rotate then
        rotateArrow(rotate, key == "RotateLeftButton")
      end
    end

    widenModel(display)
  end

  swap(journal.SummonRandomFavoriteButton, "button")
  swap(journal.searchBox, "input")
  dressFilter(journal)
  swap(journal.MountButton, "button")

  if journal.MountButton and journal.MountButton.GetFontString and Replace.ink then
    Replace.ink(journal.MountButton:GetFontString(), "buttonText")
  end

  dressScaling(journal)
  placeNeighbours(journal)

  local scroll = journal.ListScrollFrame

  if scroll then
    scrollLooks:dress(scroll.scrollBar)

    hideChrome(scroll)
  end
end

local function undress()
  scrollLooks:undress()
  giveBack()
end

Replace.tab("Mounts", { dress = dress, undress = undress })
