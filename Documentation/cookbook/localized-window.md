# Localized window

A small frame whose title and buttons follow the shared language, with one button per language on offer. A minimap button opens it.

```lua title="Greeter.lua"
local api = EbonAPI:NewAddon("Greeter", 1, 0)

if not api then
  return
end

local L = api:Locale({
  enUS = {
    LOCALE_NAME = "English",
    TITLE = "Greeter",
    HELLO = "Hello, %s!",
    CLOSE = "Close",
    BUTTON_TIP = "Click: open or close the greeting.",
  },
  frFR = {
    LOCALE_NAME = "Français",
    TITLE = "Salutations",
    HELLO = "Bonjour, %s !",
    CLOSE = "Fermer",
    BUTTON_TIP = "Clic : ouvrir ou fermer les salutations.",
  },
})

local frame = CreateFrame("Frame", "GreeterFrame", UIParent)
frame:SetWidth(280)
frame:SetHeight(150)
frame:SetPoint("CENTER")
frame:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, 0.85)
frame:Hide()

-- Bound labels: EbonAPI sets their text now and at every language change.
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -12)
api:Localized(title, "TITLE")

local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
close:SetWidth(80)
close:SetHeight(22)
close:SetPoint("BOTTOM", 0, 12)
close:SetScript("OnClick", function() frame:Hide() end)
api:Localized(close, "CLOSE")

-- A label built from a format string: refreshed by hand on LANGUAGE_CHANGED.
local greeting = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
greeting:SetPoint("TOP", title, "BOTTOM", 0, -10)

local function refresh()
  greeting:SetText(string.format(L.HELLO, UnitName("player")))
end

api:On("LANGUAGE_CHANGED", refresh)
refresh()

-- One button per language registered so far.
local previous = nil

for _, entry in ipairs(EbonAPI:GetAvailableLanguages()) do
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

  button:SetWidth(90)
  button:SetHeight(22)
  button:SetText(entry.name)
  button:SetScript("OnClick", function() EbonAPI:SetLanguage(entry.code) end)

  if previous then
    button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
  else
    button:SetPoint("BOTTOMLEFT", 12, 44)
  end

  previous = button
end

-- The minimap button opens and closes the frame.
api:MinimapButton({
  tipKey = "BUTTON_TIP",
  onClick = function()
    if frame:IsShown() then
      frame:Hide()
    else
      frame:Show()
    end
  end,
})
```

## What happens

1. `api:Localized(title, "TITLE")` binds the font string to the key. When the language changes, EbonAPI sets its text again. Same for the close button.
2. The greeting is built with `string.format`, so it cannot be bound: `refresh()` runs once at load and again in a `LANGUAGE_CHANGED` handler.
3. `EbonAPI:GetAvailableLanguages()` lists the languages registered so far, with the name each gave in `LOCALE_NAME`; the loop runs once, at load. One click on a button calls `EbonAPI:SetLanguage`, which switches every addon and saves the choice.
4. `api:MinimapButton` adds a button around the minimap. Clicking it shows the frame, or hides it when it is open. The tooltip text `BUTTON_TIP` follows the language too.

!!! tip "🎮 Try it"
    Click the Greeter button on the minimap to open the frame, then click **Français**: the title, the close button and the greeting change together, and **General → Language** in the EbonAPI window now shows the French name. So does the interface of every other addon that registered French.
