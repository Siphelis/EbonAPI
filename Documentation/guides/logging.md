# 📝 Logging

Talk to the player in chat under your addon's tag, keep debug output silent until someone asks for it, and read the trace when something went wrong.

## What it does

- Prints to the default chat frame with the tag `[MyAddon]` in EbonAPI's colors.
- Five levels: print, success, warning, error, debug.
- A debug switch per addon, from code or from `/eapi debug`.
- A trace: the last 128 things that happened inside EbonAPI, including your warnings and errors.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

api:Print("Route saved:", "Frostfire")   -- [MyAddon] Route saved: Frostfire
api:Success("Import complete")
api:Warn("Nothing to export")
api:Debug("payload", 1024, "bytes")      -- silent until /eapi debug MyAddon on
```

Every method takes any number of values. They are converted with `tostring` and joined with spaces.

## Levels

| Method | Color | Goes to | Use it for |
| --- | --- | --- | --- |
| `api:Print(...)` | text | chat | ordinary messages to the player |
| `api:Success(...)` | green | chat | a completed action |
| `api:Warn(...)` | orange | chat and the trace | something the player should know, without stopping |
| `api:Error(...)` | red | the game's error handler and the trace | a failure a developer must see |
| `api:Debug(...)` | muted | chat, only when debug is on | what you need while developing |

!!! note
    `api:Error` behaves like a Lua error: it goes to the error handler, so players with default settings do not see it in chat. It is for failures, not for telling the player something. Use `api:Warn` for that.

## Debug output

`api:Debug` prints nothing until debug is on for your addon. Turn it on from code or from the command line:

```lua
api:SetDebug(true)      -- returns the new state
api:IsDebug()           -- true
```

```text
/eapi debug MyAddon on
/eapi debug MyAddon off
/eapi debug on            every addon at once
/eapi debug               shows the current state
```

The switch is not saved: it resets at every reload. That is on purpose. Debug output is for the session where you need it.

## The trace

EbonAPI keeps the last 128 events of its own life in a ring: server messages received and sent, channel lines, whisper streams, offline peers, sharing exchanges, saved-data repairs, warnings and errors. Your `api:Warn` and `api:Error` land there too, under your addon name.

```text
/eapi trace              last 20 entries
/eapi trace 50           last 50
/eapi trace 30 warn      last 30 warnings only
```

Each line shows how long ago it happened, its kind, the addon concerned and a short description. The kinds are `boot`, `recv`, `send`, `fail`, `chan`, `wisp`, `offline`, `share`, `repair`, `warn` and `error`.

!!! tip "🎮 Try it"
    Ask players who report a problem for the output of `/eapi status` and `/eapi trace 30`. The first shows the state of every service, the second what happened just before.

## Messages in the player's language

The strings you print to the player belong in your translations, so they follow the shared language:

```lua
local L = api:Locale({
  enUS = { ROUTE_SAVED = "Route saved: %s" },
  frFR = { ROUTE_SAVED = "Trajet enregistré : %s" },
})

api:Print(string.format(L.ROUTE_SAVED, name))
```

See [Localization](localization.md).

## API

| Method | Arguments | Returns |
| --- | --- | --- |
| `api:Print(...)` | any values | |
| `api:Success(...)` | any values | |
| `api:Warn(...)` | any values | |
| `api:Error(...)` | any values | |
| `api:Debug(...)` | any values | |
| `api:SetDebug(enabled)` | boolean | the new state |
| `api:IsDebug()` | | `true` when debug is on for this addon, or for all |

Colors are available for your own strings in `EbonAPI.Log.COLOR`: `PREFIX`, `TEXT`, `ERROR`, `WARN`, `SUCCESS`, `HIGHLIGHT`, `MUTED` and `RESET`, as WoW color codes.

## See also

- [Slash commands](../reference/slash-commands.md) for every `/eapi` command.
- [Concepts: errors and messages](../concepts.md#errors-and-messages) for which message goes where.
