local Replace = EbonAPI and EbonAPI.Replace

if not Replace then
  return
end

local CONTENT = { icon = true, petTypeIcon = true, typeIcon = true, Icon = true, texture = true, favorite = true, LockIcon = true }

local function hideChrome(frame)
  Replace.hideChrome(frame, CONTENT, nil, true)
end

local placer = Replace.placer()

local function widenModel(display)
  local model = display.ModelFrame
  local info = display.InfoButton

  if not (model and info) then
    return
  end

  local x = tonumber(select(4, info:GetPoint(1))) or 0

  placer.place(model, { { "TOPLEFT", info, "BOTTOMLEFT", -x, 0 }, { "BOTTOMRIGHT", display, "BOTTOMRIGHT", 0, 0 } })
end

local scrollLooks = Replace.scrollLooks()

local function dressRow(button)
  local piece = Replace.wrap(button, "row")

  hideChrome(button)
  Replace.hideButtonArt(button)

  local drag = button.DragButton

  if drag then
    hideChrome(drag)
    Replace.hideButtonArt(drag)
  end

  if Replace.ink then
    Replace.ink(button.name, "text")
  end

  Replace.followSelected(button, piece, button.selectedTexture)
end

local function dressRows(scroll)
  local buttons = scroll and scroll.buttons

  if type(buttons) ~= "table" then
    return
  end

  for _, button in ipairs(buttons) do
    dressRow(button)
  end
end

local function dress()
  scrollLooks:reset()

  local journal = _G.PetJournal

  if not journal then
    return
  end

  local left = journal.LeftInset or _G.PetJournalLeftInset
  local right = journal.RightInset or _G.PetJournalRightInset
  local count = journal.PetCount or _G.PetJournalPetCount
  local status = journal.SubscriptionStatus or _G.PetJournalSubscriptionStatus
  local scroll = journal.ListScrollFrame or _G.PetJournalListScrollFrame
  local search = journal.searchBox or _G.PetJournalSearchBox
  local filter = _G.PetJournalFilterButton
  local summon = journal.SummonButton or _G.PetJournalSummonButton
  local random = journal.SummonRandomFavoritePetButton or _G.PetJournalSummonRandomFavoritePetButton

  for _, inset in ipairs({ left or false, right or false }) do
    if inset then
      Replace.wrap(inset, "panel")
      hideChrome(inset)
    end
  end

  for _, band in ipairs({ count or false, status or false }) do
    if band then
      Replace.wrap(band, "panel", { style = Replace.look("tree.piece.panel") })
      hideChrome(band)
    end
  end

  local display = journal.PetDisplay
  if display then
    hideChrome(display)
    Replace.wrap(display, "panel")
    widenModel(display)
  end

  if scroll then
    Replace.wrap(scroll, "scroll")
    hideChrome(scroll)
    hideChrome(scroll.scrollBar or _G.PetJournalListScrollFrameScrollBar)
    scrollLooks:dress(scroll.scrollBar or _G.PetJournalListScrollFrameScrollBar)

    pcall(dressRows, scroll)
  end

  if search then
    Replace.wrap(search, "input")
    hideChrome(search)
  end

  for _, button in ipairs({ filter or false, summon or false }) do
    if button then
      Replace.wrap(button, "button", { menu = button == filter })
      hideChrome(button)
      Replace.hideButtonArt(button)

      if button == filter then
        Replace.hide(button.Icon)
        pcall(Replace.resetCross, button)
      elseif Replace.ink and button.GetFontString then
        Replace.ink(button:GetFontString(), "buttonText")
      end
    end
  end

  if random then
    Replace.wrap(random, "slot")
    Replace.hide(random.Border or _G.PetJournalSummonRandomFavoritePetButtonBorder)
  end
end

local function undress()
  scrollLooks:undress()
  placer.giveBack()
end

Replace.tab("Companions", { dress = dress, undress = undress })
