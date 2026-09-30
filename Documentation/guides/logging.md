# 📝 Logging

Talk to the player in chat under your addon's tag, keep debug output silent until someone asks for it, and read the trace when something went wrong.

## What it does

- Prints to the default chat frame with the tag `[MyAddon]` in EbonAPI's colors.
- Five levels: print, success, warning, error, debug.
- A debug switch per addon, from code or from the EbonAPI window.
- A trace: the last 128 things that happened inside EbonAPI, your warnings and errors included.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

local L = api:Locale({
  enUS = {
    SAVED = "Route saved:",
    IMPORTED = "Import complete",
    NOTHING = "Nothing to export",
  },
  frFR = {
    SAVED = "Trajet enregistré :",
    IMPORTED = "Import terminé",
    NOTHING = "Rien à exporter",
  },
})

api:Print(L.SAVED, "Frostfire")          -- [MyAddon] Route saved: Frostfire
api:Success(L.IMPORTED)
api:Warn(L.NOTHING)
api:Debug("payload", 1024, "bytes")      -- silent until debug is on for MyAddon
```

## How it works

Every method takes any number of values. They are converted to text and joined with single spaces. The chat line starts with your addon's name in square brackets.

### Levels

| Method | Color | Goes to | Use it for |
| --- | --- | --- | --- |
| `api:Print(...)` | text color | chat | ordinary messages to the player |
| `api:Success(...)` | success color | chat | a completed action |
| `api:Warn(...)` | warning color | chat and the trace | something the player should know, without stopping |
| `api:Error(...)` | none | the game's error handler and the trace | a failure a developer must see |
| `api:Debug(...)` | muted color | chat, only when debug is on | what you need while developing |

The colors come from the player's skin.

!!! note
    `api:Error` does not print in chat. It sends `[MyAddon] your text` to the game's error handler, the same place Lua errors go. Use `api:Warn` to tell the player something.

### Debug output

`api:Debug` prints nothing until debug is on for your addon. Turn it on from code, or in the EbonAPI window:

```lua
api:SetDebug(true)      -- true: debug is now on for this addon
api:IsDebug()           -- true
```

`api:SetDebug(enabled)` switches debug for your addon: any true value turns it on, `false` or `nil` turns it off. It returns what `api:IsDebug()` returns right after the change, so `true` when debug is on for your addon or for all addons. `api:IsDebug()` returns `true` when debug is on for your addon or for all addons.

In the EbonAPI window, under **Diagnostics → Debug messages**:

| Control | Effect |
| --- | --- |
| **All addons** | debug on for every addon at once |
| **Addon** | chooses which addon the next control acts on; the list holds every connected addon and EbonAPI itself |
| **For the chosen addon** | debug on for the addon chosen above; it cannot be changed while **All addons** is on |

The switches are not saved: every reload turns debug off again.

### The trace

EbonAPI keeps the last 128 things that happened, the oldest being dropped first. Your `api:Warn` and `api:Error` land there too, under your addon name, and so does an error raised inside one of your callbacks, such as an event handler or a ticker function. `api:Print`, `api:Success` and `api:Debug` do not.

In the EbonAPI window, **Diagnostics → Reports → Trace** shows the last 30 entries, the newest first. Set **Trace filter** to one kind, such as `warn`, to keep only those. The filter lists **Everything** and every kind that has appeared since the game started.

Each line shows how long ago it happened, its kind, the addon concerned and a short description. The kinds are:

| Kind | What it records |
| --- | --- |
| `boot` | EbonAPI starting up |
| `recv`, `send`, `fail` | server messages received, sent, and sends that failed |
| `chan` | the shared channel |
| `wisp` | whisper streams |
| `offline` | players found offline |
| `share` | datasets shared |
| `repair` | saved data repaired at load |
| `skin` | a skin that could not be applied |
| `warn`, `error` | `api:Warn` and `api:Error`, and errors raised inside your callbacks |

When nothing matches, the window shows `empty trace`.

### Messages in the player's language

The strings you print to the player belong in your translations, so they follow the shared language:

```lua
local L = api:Locale({
  enUS = { ROUTE_SAVED = "Route saved: %s" },
  frFR = { ROUTE_SAVED = "Trajet enregistré : %s" },
})

local name = "Frostfire"

api:Print(string.format(L.ROUTE_SAVED, name))
```

See [Localization](localization.md).

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:Print(...)` | any values | | |
| `api:Success(...)` | any values | | |
| `api:Warn(...)` | any values | | |
| `api:Error(...)` | any values | | |
| `api:Debug(...)` | any values | | |
| `api:SetDebug(enabled)` | any value | `true` when debug is on for this addon or for all addons, as `api:IsDebug()` | |
| `api:IsDebug()` | | `true` when debug is on for this addon, or for all addons | |

Colors are available for your own strings in `EbonAPI.Log.COLOR`: `PREFIX`, `TEXT`, `ERROR`, `WARN`, `SUCCESS`, `HIGHLIGHT`, `MUTED` and `RESET`, as WoW color codes. All but `RESET` come from the player's skin and change when the skin changes: read them when you print, not once at load.

```lua
local COLOR = EbonAPI.Log.COLOR

api:Print(COLOR.HIGHLIGHT .. "Frostfire" .. COLOR.RESET .. " saved")
```

## Events

Logging emits no event.

## Limits

| | Value |
| --- | --- |
| Entries kept in the trace | 128 |
| Entries shown by **Diagnostics → Reports → Trace** | 30 |

!!! tip "🎮 Try it"
    In the EbonAPI window, open **Diagnostics**. Under **Debug messages**, choose your addon in **Addon** and switch on **For the chosen addon**: your `api:Debug` lines appear in chat. Press **Trace** under **Reports** to see your `api:Warn` lines, and set **Trace filter** to `warn` or `error` to keep only those. When a player reports a problem, ask for a screenshot of **Diagnostics → Reports** after **Status**, then after **Trace**.

## See also

- [Options window](../reference/options-window.md) for every diagnostic of the EbonAPI window.
- [Concepts: errors and messages](../concepts.md#errors-and-messages) for which message goes where.
- [Performance](performance.md) for the other report of the **Diagnostics** page.
