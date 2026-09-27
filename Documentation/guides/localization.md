# 🌍 Localization

One language for every addon. Register your translations, read them from one table, and let widgets refresh themselves.

## What it does

- Registers your strings per language code: `enUS`, `frFR`, `deDE`, `esES`, and any other WoW code.
- Gives you one live table `L`: English underneath, the active language on top.
- Follows the language the player chose, from any addon's menu or from `/eapi lang`.
- Refreshes the widgets you bound when the language changes.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

local L = api:Locale({
  enUS = {
    LOCALE_NAME = "English",
    GREETING = "Welcome, %s!",
    BUTTON_SAVE = "Save",
  },
  frFR = {
    LOCALE_NAME = "Français",
    GREETING = "Bienvenue, %s !",
    BUTTON_SAVE = "Enregistrer",
  },
})

api:On("READY", function()
  api:Print(string.format(L.GREETING, UnitName("player")))
end)
```

## How it works

**Registering.** `api:Locale(translations)` takes a table keyed by language code. Call it as often as you like: each call merges into what is already registered, so one file per language works too. It returns your `L` table; `api:L()` returns the same table.

```lua title="Locales/deDE.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

api:Locale({
  deDE = {
    LOCALE_NAME = "Deutsch",
    GREETING = "Willkommen, %s!",
    BUTTON_SAVE = "Speichern",
  },
})
```

**Fallback.** `L` always holds every English key. The keys of the active language overlay them. A key missing in `frFR` shows its English text. Nothing else changes for the other addons.

**The active language.** At load, EbonAPI uses the client's language if any addon registered it, else English. Then it restores the language the player saved. Then it follows every change, and emits `LANGUAGE_CHANGED`.

**The table is live.** `L` is updated in place. Keep the reference and read `L.KEY` when you need the text. A string copied into a local at file load stays in the language of that moment.

`esMX` is treated as `esES`.

## Widgets that follow the language

```lua
local button = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")

api:Localized(button, "BUTTON_SAVE")
```

`api:Localized(widget, key)` sets the widget's text now and again at every language change. Any widget with `SetText` works: font strings, buttons, edit boxes. It returns the widget, so it fits inside a chain.

## Offering a language menu

The languages on offer are the union of every addon's translations. Each entry carries the display name from the `LOCALE_NAME` key:

```lua
for _, entry in ipairs(EbonAPI:GetAvailableLanguages()) do
  api:Print(entry.code .. " = " .. entry.name)     -- frFR = Français
end

EbonAPI:SetLanguage("frFR")
```

`EbonAPI:SetLanguage(code)` changes the language for every addon, saves the choice and emits `LANGUAGE_CHANGED`. It returns `false` for a code nobody registered. Pass `false` as a second argument to change without saving, for a preview.

`api:IsLanguageChosen()` tells you whether the player made an explicit choice. When it is `false`, the client's language is in use. `api:GetLanguage()` returns the active code.

## Reacting to a change

```lua
api:On("LANGUAGE_CHANGED", function(event, code)
  MyAddon:RefreshWindow()
end)
```

`LANGUAGE_CHANGED` is sticky: a late subscriber gets the current code right away. Bound widgets need no handler; they refresh on their own.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:Locale(translations)` | `{ enUS = {...}, frFR = {...} }` | the `L` table | translations is not a table |
| `api:L()` | | the `L` table | |
| `api:Localized(widget, key)` | widget with `SetText`, key | the widget | key is not a string, widget has no `SetText` |
| `api:GetLanguage()` | | active code | |
| `api:IsLanguageChosen()` | | `true` when the player chose one | |
| `EbonAPI:SetLanguage(code, persist?)` | code, optional `false` | `true`, or `false` for an unknown code | |
| `EbonAPI:GetLanguage()` | | active code | |
| `EbonAPI:GetAvailableLanguages()` | | list of `{ code, name }`, sorted by name | |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `LANGUAGE_CHANGED` | code | yes | the shared language changed |

!!! tip "🎮 Try it"
    `/eapi lang` shows the active language and every code on offer. `/eapi lang frFR` switches every addon at once.

## See also

- [Cookbook: localized window](../cookbook/localized-window.md) for a frame whose labels follow the language, with a menu to change it.
- [Logging](logging.md) for printing translated messages.
