# 🌍 Localization

One language for every addon. Register your translations, read them from one table, and let your texts change language on their own.

## What it does

- Registers your strings per language code: `enUS`, `frFR`, `deDE`, `esES`, and any other WoW code.
- Gives you one live table `L`: English underneath, the active language on top.
- Follows the language the player chose, from any addon's menu or from **General → Language** in the EbonAPI window.
- Refreshes the widgets you bound when the language changes.

## Quick example

```lua title="MyAddon.lua"
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

**Registering.** `api:Locale(translations)` takes a table keyed by language code. Call it as often as you like: each call merges into what is already registered, so one file per language works too. It returns your `L` table; `api:L()` returns the same table, or `nil` if you never called `api:Locale`. A call adds keys and overwrites existing ones, it never removes any. An entry whose value is not a table is ignored. `api:Locale` raises `EbonAPI: the translations of 'MyAddon' must be a table, got <type>` when its argument is not a table.

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

**Fallback.** `L` always holds your English keys, and the keys of the active language cover them. A key missing in `frFR` shows its English text. The other addons are not affected.

**The active language.** At load, EbonAPI uses the client's language when EbonAPI itself has texts for it (`enUS`, `frFR`, `deDE` or `esES`; `esMX` counts as `esES`), and English otherwise. It then restores the language the player saved and emits `LANGUAGE_CHANGED` if that language differs from the one in use. The client's language at load does not emit the event. After that, every change emits `LANGUAGE_CHANGED`.

**The table changes in place.** When the language changes, EbonAPI rewrites the content of `L`; the table itself stays the same. Keep `L` and read `L.KEY` at the moment you need the text. A string copied into a variable when your file loads stays in the language of that moment:

```lua
local title = L.TITLE           -- frozen: stays in the language active at load

local function titleNow()
  return L.TITLE                -- always the current language
end
```

A language is on offer as soon as one addon registers it. If EbonAPI has no text for it, EbonAPI's own window stays in English.

## Widgets that follow the language

```lua
local button = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")

api:Localized(button, "BUTTON_SAVE")
```

`api:Localized(widget, key)` sets the widget's text now and again at every language change. Any widget with `SetText` works: font strings, buttons, edit boxes. It returns the widget, so it fits inside a chain. When `key` is missing from `L`, the widget shows the key itself.

It raises `EbonAPI: Localized expects a translation key, got <type>` when `key` is not a string, and `EbonAPI: Localized expects a widget with SetText for the key '<key>'` when the widget is missing or has no `SetText`.

## Offering a language menu

The languages on offer are the union of every addon's translations. Each entry carries the display name from the `LOCALE_NAME` key (the language code when no addon sets it), and the list is sorted by name:

```lua
for _, entry in ipairs(EbonAPI:GetAvailableLanguages()) do
  api:Print(entry.code .. " = " .. entry.name)     -- frFR = Français
end

EbonAPI:SetLanguage("frFR")
```

`EbonAPI:SetLanguage(code)` changes the language for every addon, saves the choice and emits `LANGUAGE_CHANGED`. It returns `true`, or `false` for a code nobody registered. Pass `false` as a second argument to change without saving, for a preview.

`api:IsLanguageChosen()` tells you whether the player made an explicit choice. When it is `false`, the client's language is in use. `api:GetLanguage()` returns the active code.

## Reacting to a change

```lua
api:On("LANGUAGE_CHANGED", function(event, code)
  MyAddon:RefreshWindow()
end)
```

`LANGUAGE_CHANGED` is sticky: a late subscriber gets the current code right away once a change has happened. Bound widgets and `L` are refreshed before the event is emitted, and need no handler.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:Locale(translations)` | `{ enUS = {...}, frFR = {...} }` | the `L` table | `translations` is not a table |
| `api:L()` | | the `L` table, or `nil` before `api:Locale` | |
| `api:Localized(widget, key)` | widget with `SetText`, key | the widget | `key` is not a string, the widget is missing or has no `SetText` |
| `api:GetLanguage()` | | active code | |
| `api:IsLanguageChosen()` | | `true` when the player chose one | |
| `EbonAPI:SetLanguage(code, persist?)` | code, optional `false` | `true`, or `false` for an unknown code | |
| `EbonAPI:GetLanguage()` | | active code | |
| `EbonAPI:IsLanguageChosen()` | | `true` when the player made an explicit choice | |
| `EbonAPI:GetAvailableLanguages()` | | list of `{ code, name }`, sorted by name | |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `LANGUAGE_CHANGED` | code | yes | the shared language changed |

## Limits

- A key missing in every language is `nil` in `L`. Only widgets bound with `api:Localized` show the key itself.
- `esMX` is treated as `esES`, unless an addon registered `esMX`.
- `SetLanguage` and `GetAvailableLanguages` exist on `EbonAPI` only, not on your handle.
- English is the fallback language for every addon.

!!! tip "🎮 Try it"
    **General → Language**, in the EbonAPI window, shows the active language and every language on offer. Choosing one switches every addon at once.

## See also

- [Cookbook: localized window](../cookbook/localized-window.md) for a frame whose labels follow the language, with a menu to change it.
- [Logging](logging.md) for printing translated messages.
