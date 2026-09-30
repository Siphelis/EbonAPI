# 🏰 ProjectEbonhold

Find out which parts of ProjectEbonhold are running, and use them without breaking your addon when they are missing.

## What it does

ProjectEbonhold is the addon that ships with the Ebonhold client: perks, skill tree, objectives, checkpoints, hardmode, orbs. Its content changes with the client's versions, and a player may run without it. EbonAPI checks what is there at login and each time the player enters the world, and gives you:

- **features**: a flag per piece of ProjectEbonhold, with `api:HasFeature(name)` and the `FEATURE_CHANGED` event;
- **accessors**: one function per piece of ProjectEbonhold, returning that piece or `nil`;
- a safe way to **hook** its functions, and a way to **send** to the server through its own sender.

## Quick example

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
local Ebonhold = api:Ebonhold()

local L = api:Locale({
  enUS = {
    NO_PERKS = "ProjectEbonhold is not running: perk names are unavailable.",
    PERKS_READY = "Perk database loaded.",
  },
  frFR = {
    NO_PERKS = "ProjectEbonhold n'est pas lancé : les noms des bonus sont indisponibles.",
    PERKS_READY = "Base de données des bonus chargée.",
  },
})

api:On("READY", function()
  if not api:HasFeature("PerkDatabase") then
    api:Warn(L.NO_PERKS)
    return
  end

  local perks = Ebonhold.PerkDatabase()
  api:Print(L.PERKS_READY)
end)

api:On("FEATURE_CHANGED", function(event, name, available)
  api:Debug("feature " .. name .. " is now " .. tostring(available))
end)
```

## Features

Each feature says whether one piece of ProjectEbonhold is there. `api:HasFeature(name)` returns the last answer, `true` or `false`; an unknown name gives `false`. `FEATURE_CHANGED(name, available)` fires when an answer differs from the previous one. EbonAPI checks at login, before `READY`, and again every time the player enters the world. `Ebonhold.Detect()` checks now and returns a copy of the whole table, feature name to boolean.

The first check has no previous answer, so at login `FEATURE_CHANGED` fires once for every feature, the missing ones included, in the order of the table below.

| Feature | Present when |
| --- | --- |
| `ProjectEbonhold` | the client addon is loaded |
| `Objectives` | its objectives exist |
| `Checkpoints` | its checkpoints exist |
| `Hardmode` | its hardmode exists |
| `Perks` | its perks exist |
| `PerkDatabase` | its perk database exists |
| `PerkUI` | its perk window logic exists |
| `Orbs` | its orbs exist |
| `EchoJournal` | its echo journal exists |
| `PlayerRun` | its run exists |
| `SkillTree` | its skill tree exists |
| `SkillTreeFrame` | the skill tree window exists |
| `TalentDatabase` | the talent database is loaded with its nodes |
| `Utils` | its encoding helpers exist |
| `RequestLoadout` | it can ask the server for the loadouts |
| `sendToServer` | it can send messages to the server |
| `openLink` | the client can open a link in the browser, or copy it; see [Connecting your addon](connection.md#links) |

## Accessors

`api:Ebonhold()` returns the module; `EbonAPI.Ebonhold` is the same table. Most accessors return the object or `nil`; the table below says what each one returns. `PerkFrame()`, `SkillTreeImportButton()` and `SkillTreeFrame()` return the game's own object as it is when it is a table, and `nil` otherwise. Test the result, or test the feature first.

| Function | Returns |
| --- | --- |
| `IsPresent()` | `true` when ProjectEbonhold is loaded |
| `Raw()` | the `ProjectEbonhold` table itself, or `nil` |
| `Objectives()`, `ObjectivesUI()` | the objectives and the objectives window |
| `Checkpoints()` | the checkpoints |
| `Hardmode()`, `CurrentHardmodeTier()` | the hardmode, the current tier (`nil` when ProjectEbonhold is absent) |
| `Perks()`, `PerkDatabase()`, `PerkUI()`, `PerkFrame()` | the perks, the perk database, the perk window logic, the perk window frame |
| `PerkDropSources()`, `PerkDropSourceByGroup()` | the `PerkDropSources` and `PerkDropSourceByGroup` entries of ProjectEbonhold |
| `PlayerRun()`, `PublishedRunData()`, `PublishedIntensity()` | the run, and the run and intensity data it publishes (`PublishedRunData()` is `nil` while that data is empty) |
| `SkillTree()`, `SkillTreeFrame()`, `SkillTreeImportButton()`, `TalentDatabase()` | the skill tree, its window, its import button, the talent database |
| `WorldMapBounds()` | the `WorldMapBounds` entry of ProjectEbonhold |
| `Orbs()` | the orbs |
| `EchoJournal()` | the `EchoJournal` entry of ProjectEbonhold |
| `OptionsService()` | the options |
| `Utils()` | encoding helpers, with `EncodeVarInt` and `Base64Encode` |
| `CanRequestLoadout()`, `RequestLoadout()` | whether loadouts can be requested, and the request itself |
| `OpcodeCS(name)` | the number ProjectEbonhold uses for one of its outgoing opcodes, or `nil` |
| `LinkMethod()`, `OpenLink(url)`, `LinkTip()` | what the client can do with a link (`"open"`, `"copy"` or `nil`), doing it, and the sentence that explains it to the player |
| `Detect()` | probes now, returns the feature table |
| `Summary()` | two lists, each sorted by name: features present, features missing |

!!! note
    These objects belong to ProjectEbonhold. Their contents follow the client's own versions. EbonAPI guarantees that the features tell you what is there; it does not document what is inside.

## Opening a link

`api:OpenLink(url)` opens the link in the player's browser when the client offers it, or copies it when the client can only copy. It returns `"open"`, `"copy"`, or `nil` when the client can do neither and nothing happens, or when the client's function raised an error (the error is reported, not raised). `api:LinkMethod()` tells which one applies without acting. `api:LinkTip()` returns the sentence to show the player next to your link, in their language, or `nil` when nothing applies:

| Method | English text of `api:LinkTip()` |
| --- | --- |
| `"open"` | Opens this link in your browser. |
| `"copy"` | Copies this link: paste it into your browser. |

`api:OpenLink` raises `EbonAPI: <addonName>: api:OpenLink expects a URL text, got <type>` when `url` is not a non-empty text; for an empty text the message ends with `got an empty string`. `EbonAPI:OpenLink(url)`, `EbonAPI:LinkMethod()` and `EbonAPI:LinkTip()` do the same without a handle; the error then reads `EbonAPI:OpenLink expects a URL text, got <type>` or `got an empty string`.

## Hooking a function

```lua
Ebonhold.Hook("PerkUI", "Show", function(original, ...)
  api:Debug("perk window opening")
  return original(...)
end)
```

`Ebonhold.Hook(path, key, wrapper)` replaces `target[key]` with a function that calls your wrapper, giving it the original function first, and returns whatever your wrapper returns. `Hook` returns `true` when the hook is in place. Otherwise it returns `false` and a reason: `"no_target"` when the target is missing or `target[key]` is not a function, `"no_wrapper"` when `wrapper` is not a function (nothing is replaced), and `"already_hooked"` when that function is already hooked: one hook per function, the first one wins.

`path` is one of these:

- `nil`, for the `ProjectEbonhold` table itself;
- a text, the name of an entry of the `ProjectEbonhold` table, such as `"PerkUI"` or `"PerkService"`. It is the entry's own name, not the accessor's: the perk service is `"PerkService"`, while its accessor is `Perks()`;
- any table.

`Ebonhold.IsHooked(path, key)` tells you whether a hook is in place.

## Sending through ProjectEbonhold

```lua
local name = "REFRESH_BUILDS"

if Ebonhold.OpcodeCS(name) then
  local ok, reason = Ebonhold.SendToServer(name, "")
end
```

This uses ProjectEbonhold's own sender and its own opcode names. It returns `true` when the call went through, `false, "no_send"` when the client cannot send, `false, "no_opcode"` for a name it does not know, and `false, "error"` when ProjectEbonhold's sender raised an error (the error is reported). Prefer `api:SendServer` with `EbonAPI.CS`; keep this path for opcodes EbonAPI does not list.

`Ebonhold.RequestLoadout()` asks the server for the loadouts through ProjectEbonhold. It returns `true` when the request was made, `false, "no_request"` when ProjectEbonhold has no such function, and `false, "error"` when it raised an error (the error is reported).

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:Ebonhold()` | | the module | never |
| `api:HasFeature(name)` | feature name | `true` or `false` | never |
| `api:OpenLink(url)` | non-empty text | `"open"`, `"copy"` or `nil` | `EbonAPI: <addonName>: api:OpenLink expects a URL text, got <type>` |
| `api:LinkMethod()` | | `"open"`, `"copy"` or `nil` | never |
| `api:LinkTip()` | | the sentence for the player, or `nil` | never |
| `Ebonhold.Hook(path, key, wrapper)` | `nil`, text or table; function name; `wrapper(original, ...)` | `true` when hooked, otherwise `false` with `"no_target"`, `"no_wrapper"` or `"already_hooked"` | never |
| `Ebonhold.IsHooked(path, key)` | same path and key | `true` or `false` | never |
| `Ebonhold.SendToServer(name, body)` | opcode name, string | `true`, or `false` with `"no_send"`, `"no_opcode"` or `"error"` | never |
| `Ebonhold.RequestLoadout()` | | `true` when the request was made, otherwise `false` with `"no_request"` or `"error"` | never |
| `Ebonhold.Detect()` | | copy of the feature table | never |
| `Ebonhold.Summary()` | | list of features present, list of features missing | never |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `FEATURE_CHANGED` | name, available | no | a feature appeared or disappeared, and once per feature at login |

!!! tip "🎮 Try it"
    **Diagnostics → Reports → Status** in the EbonAPI window shows `ProjectEbonhold: detected` or `ProjectEbonhold: absent`, then the features present and, in grey, `none:` followed by the ones missing. **Diagnostics → Reports → Trace** with **Trace filter** on `send` shows each `Ebonhold.SendToServer` call as `PE:` followed by the opcode name.

## See also

- [Server](server.md) for the messages the server sends, parsed by EbonAPI.
- [Connecting your addon](connection.md#links) for links.
