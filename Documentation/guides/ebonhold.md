# 🏰 ProjectEbonhold

Detect the Ebonhold client addon and reach its services without crashing when they are absent.

## What it does

ProjectEbonhold is the client addon of the Ebonhold server: perks, skill tree, objectives, checkpoints, hardmode, orbs. EbonAPI probes it at login and each time you enter the world, and gives you:

- **features**: a flag per service, with `api:HasFeature(name)` and the `FEATURE_CHANGED` event;
- **accessors**: one function per service, returning the service or `nil`;
- a safe way to **hook** its functions and to **send** through its own channel to the server.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
local Ebonhold = api:Ebonhold()

api:On("READY", function()
  if not api:HasFeature("PerkDatabase") then
    api:Warn("ProjectEbonhold is not running: perk names unavailable")
    return
  end

  local perks = Ebonhold.PerkDatabase()
  api:Print("perk database loaded")
end)

api:On("FEATURE_CHANGED", function(event, name, available)
  api:Debug("feature " .. name .. " is now " .. tostring(available))
end)
```

## Features

Each feature is a probe on one piece of ProjectEbonhold. `api:HasFeature(name)` returns the last result; `FEATURE_CHANGED(name, available)` fires when a result changes. Probing happens at `PLAYER_LOGIN`, before `READY`, and again at every `PLAYER_ENTERING_WORLD`. `Ebonhold.Detect()` probes now and returns the whole table.

| Feature | Present when |
| --- | --- |
| `ProjectEbonhold` | the client addon is loaded |
| `Objectives` | its objectives service exists |
| `Checkpoints` | its checkpoint service exists |
| `Hardmode` | its hardmode service exists |
| `Perks` | its perk service exists |
| `PerkDatabase` | its perk database exists |
| `PerkUI` | its perk window exists |
| `Orbs` | its orb service exists |
| `EchoJournal` | its echo journal exists |
| `PlayerRun` | its run service exists |
| `SkillTree` | its skill tree service exists |
| `SkillTreeFrame` | the skill tree window exists |
| `TalentDatabase` | the talent database is loaded with its nodes |
| `Utils` | its encoding helpers exist |
| `RequestLoadout` | it can ask the server for the loadouts |
| `sendToServer` | it can send messages to the server |

## Accessors

`api:Ebonhold()` returns the module; `EbonAPI.Ebonhold` is the same table. Every accessor returns the object or `nil`. Test the result, or test the feature first.

| Function | Returns |
| --- | --- |
| `IsPresent()` | `true` when ProjectEbonhold is loaded |
| `Raw()` | the `ProjectEbonhold` table itself |
| `Objectives()`, `ObjectivesUI()` | objectives service and window |
| `Checkpoints()` | checkpoint service |
| `Hardmode()`, `CurrentHardmodeTier()` | hardmode service, current tier |
| `Perks()`, `PerkDatabase()`, `PerkUI()`, `PerkFrame()` | perk service, database, window logic, window frame |
| `PerkDropSources()`, `PerkDropSourceByGroup()` | where perks drop |
| `PlayerRun()`, `PublishedRunData()`, `PublishedIntensity()` | run service and the data it publishes globally |
| `SkillTree()`, `SkillTreeFrame()`, `SkillTreeImportButton()`, `TalentDatabase()` | skill tree service, window, import button, talent database |
| `WorldMapBounds()` | map bounds |
| `Orbs()` | orb service |
| `EchoJournal()` | echo journal |
| `OptionsService()` | options service |
| `Utils()` | encoding helpers, with `EncodeVarInt` and `Base64Encode` |
| `CanRequestLoadout()`, `RequestLoadout()` | whether loadouts can be requested, and the request itself |
| `OpcodeCS(name)` | the number ProjectEbonhold uses for one of its outgoing opcodes |
| `Detect()` | probes now, returns the feature table |
| `Summary()` | two lists: features present, features missing |

!!! note
    These objects belong to ProjectEbonhold. Their contents follow the client's own versions. EbonAPI guarantees that the accessors never raise and that the features tell you what is there; it does not document what is inside.

## Hooking a function

```lua
Ebonhold.Hook("PerkUI", "Show", function(original, ...)
  api:Debug("perk window opening")
  return original(...)
end)
```

`Ebonhold.Hook(path, key, wrapper)` replaces `target[key]` with your wrapper, which receives the original function first. It returns `false` when the target or the function is missing, or when that function is already hooked: one hook per function, the first one wins.

`path` is a service name, `nil` for the `ProjectEbonhold` table itself, or any table. `Ebonhold.IsHooked(path, key)` tells you whether a hook is in place.

## Sending through ProjectEbonhold

```lua
local ok, reason = Ebonhold.SendToServer("REFRESH_BUILDS", "")
```

This uses ProjectEbonhold's own sender and its own opcode names. It returns `false, "no_send"` when the client cannot send, `false, "no_opcode"` for a name it does not know. Prefer `api:SendServer` with `EbonAPI.CS`; keep this path for opcodes EbonAPI does not list.

## API

| Method | Arguments | Returns |
| --- | --- | --- |
| `api:Ebonhold()` | | the module |
| `api:HasFeature(name)` | feature name | `true` or `false` |
| `Ebonhold.Hook(path, key, wrapper)` | service name, `nil` or table; function name; `wrapper(original, ...)` | `true` when hooked |
| `Ebonhold.IsHooked(path, key)` | same path and key | `true` or `false` |
| `Ebonhold.SendToServer(name, body)` | opcode name, string | `true`, or `false, reason` |
| `Ebonhold.RequestLoadout()` | | `true` when the request was made |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `FEATURE_CHANGED` | name, available | no | a probe changed its result |

!!! tip "🎮 Try it"
    `/eapi status` prints `ProjectEbonhold: detected` or `absent`, then the features present and, in grey, the ones missing.

## See also

- [Server](server.md) for the messages the server sends, parsed by EbonAPI.
