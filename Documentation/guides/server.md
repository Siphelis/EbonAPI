# 🛰️ Server

Receive what the Ebonhold server tells the client, either as ready-to-use tables and events or as raw messages. Send it requests without flooding it.

## What it does

The Ebonhold server sends the client short messages. Each one carries an **opcode**, a number that says what the message is about, and a **body**, its content as text. A long message can arrive in several parts: EbonAPI puts them back together and you only see the complete body. EbonAPI then:

- parses the important messages into **state** you can read at any time, and into sticky **events** (events that replay their last value to a late subscriber, see the [glossary](../reference/glossary.md));
- hands every complete message, parsed or not, to the functions registered for its opcode;
- sends your own messages to the server, and can skip a request you already sent a moment ago.

## Quick example

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

local L = api:Locale({
  enUS = {
    ASHES = "Soul Ashes: %s / %s",
    ASH_SPLIT = "%s to spend, %s committed",
  },
  frFR = {
    ASHES = "Cendres d'âme : %s / %s",
    ASH_SPLIT = "%s à dépenser, %s engagées",
  },
})

api:On("SERVER_RUN_DATA", function(event, run)
  api:Print(string.format(L.ASHES, run.soulPoints, run.soulPointsMax))
end)

api:On("SERVER_ASH", function(event, ash)
  api:Print(string.format(L.ASH_SPLIT, ash.spendable, ash.committed))
end)

api:On("READY", function()
  -- Ask the server for the list of builds, at most once every 30 seconds.
  api:RequestServer(EbonAPI.CS.REFRESH_BUILDS, "", 30)
end)
```

## How it works

When a complete message arrives, the functions registered with `api:OnServer` for its opcode receive the body. For an opcode EbonAPI knows, the matching event, such as `SERVER_RUN_DATA`, carries the parsed table. `SERVER_MESSAGE` fires last, for every message, after all the functions and events.

To work with the new values of a known opcode, subscribe to its event. Use `api:OnServer` to read the `body` yourself, or for opcodes EbonAPI does not parse.

## Parsed events

These events carry ready-to-use tables. All of them are sticky: a late subscriber gets the last value at once.

| Event | Argument | Fed by |
| --- | --- | --- |
| `SERVER_RUN_DATA` | run | `SS.PLAYER_RUN_DATA` |
| `SERVER_INTENSITY` | intensity | `SS.PLAYER_INTENSITY_POINTS` |
| `SERVER_ASH` | ash, only when the amounts changed | `SS.COMMITTED_SOUL_POINTS`, `SS.SEND_LOADOUTS` |
| `SERVER_MULTIPLIER` | number | `SS.SOUL_POINTS_MULTIPLIER` |
| `SERVER_BUILDS` | builds | `SS.BUILD_LIST` |
| `SERVER_BUILD_ACTIVE` | slot, builds | `SS.BUILD_ACTIVE` |
| `SERVER_LOADOUT` | loadout | `SS.SEND_LOADOUTS` |

A run message with too few fields, an ash message without two numbers, an intensity message with fewer than two fields, or a build list with a malformed first entry changes nothing and fires no event. The previous state stays.

### Run

Every field is a number unless noted. A field the server did not send is `0`.

| Field | Meaning |
| --- | --- |
| `soulPoints`, `soulPointsMax` | Soul Ashes of the run and the cap |
| `acceptedRezs`, `acceptedRezsMax`, `countCanAcceptedRezs` | resurrections accepted, allowed, remaining |
| `selfRezs`, `selfRezsMax`, `countCanSelfRezs` | self-resurrections used, allowed, remaining |
| `classRezs`, `classRezsMax`, `countCanClassRezs` | class resurrections used, allowed, remaining |
| `avoidedFatalAttacks`, `avoidedFatalAttacksMax`, `countCanAvoidFatalAttacks` | fatal attacks avoided, allowed, remaining |
| `nbResetAvoided`, `costNextReset` | numbers sent by the server as they are |
| `usedRerolls`, `totalRerolls`, `remainingRerolls` | rerolls used, granted, remaining |
| `remainingBanishes` | banishes left |
| `catchupMultiplierPct` | number sent by the server as it is |
| `usedFreezes`, `totalFreezes`, `remainingFreezes` | freezes used, granted, remaining |
| `hasReachedMaxLevel` | `true` once the run reached the level cap, `false` otherwise |
| `fieldCount` | how many fields the server sent; older servers send fewer |

The "remaining" fields are never negative. When the server sends no banish count, `remainingBanishes` is `1`.

### Intensity

`intensity` (number, `0` when the server sent none), `areaName` (string), `onCooldown` (boolean).

### Ash

`spendable` and `committed` (numbers), `source` (the opcode that delivered them), `at` (the `GetTime()` of the delivery).

### Builds

`active` (slot number), `maxSlots`, `unlocked`, `prices` (list of numbers), and `slots`, a table keyed by slot number where each entry has `slot`, `name` and `echoes`. Use the state helpers to read the echoes:

```lua
local State = api:State()

for _, build in ipairs(State.sortedBuilds()) do
  local echoes = State.BuildEchoes(build)        -- { { spellId, stacks, locked }, ... }
  api:Print(build.slot .. " " .. build.name .. ": " .. #echoes .. " echoes")
end

local build, slot = State.activeBuild()
```

`locked` is a boolean.

### Loadout

`nodes` (a table keyed by node id giving the rank, only ranks above `0`), `id` and `name`, and `spendable` and `committed` when the message carried them. `id` and `name` describe the loadout the server selected; if none has that id, the first loadout with id `0` is used. They are absent when no loadout qualifies or its name is empty or contains `|`.

## Reading the state at any time

`api:State()` returns the state module. Every `Get` function and `State.RunAshes()` return `nil` while nothing has been received, except `State.GetMultiplier()`.

| Function | Returns |
| --- | --- |
| `State.GetRun()` | the run table, or ProjectEbonhold's published run data when no message arrived yet |
| `State.GetIntensity()` | the intensity table, with the same fallback |
| `State.GetAsh()` | the ash table |
| `State.GetMultiplier()` | the multiplier, `0` by default |
| `State.GetBuilds()` | the builds table |
| `State.GetLoadout()` | the loadout table |
| `State.RunAshes()` | `soulPoints, soulPointsMax` as integers |
| `State.BuildEchoes(build)` | list of `{ spellId, stacks, locked }` for one build entry, `locked` being a boolean; `nil` when `build` is not a table |
| `State.sortedBuilds()` | the builds as a list, by slot; an empty list while no build list was received |
| `State.activeBuild()` | `build, slot` of the active build; `nil, slot` when that slot holds no build, `nil` when no build list was received |
| `State.HasServer()` | `true` once ProjectEbonhold is present or a message was received |
| `State.snapshot(name)` | a deep copy of `"run"`, `"intensity"`, `"ash"`, `"builds"` or `"loadout"`, `nil` for anything else |

`State.RUN_FIELDS` (the run field names) and `State.MAX_ASH` are described in [Modules](../reference/modules.md#ebonapistate).

## Raw messages

For opcodes EbonAPI does not parse, or to read the body yourself:

```lua
api:OnServer(EbonAPI.SS.HARDMODE_DATA, function(body, opcode, sender)
  api:Debug("hardmode: " .. body)
end)
```

The function receives the complete body, `opcode`, `sender` (your own character's name) and `distribution` (`"WHISPER"`); either may be `nil`. `api:OffServer(opcode, fn)` removes it, and so does `api:OffAll()`. `SERVER_MESSAGE(opcode, body, sender)` fires for every message, whatever its opcode. `STREAM_TIMEOUT(opcode, id, received, total)` fires when a message in several parts stopped coming: no new part for 20 seconds. `id` is the text that tells the messages apart, `received` and `total` count the parts.

A function that raises an error is reported and does not stop the others.

## Sending

```lua
api:SendServer(EbonAPI.CS.BUILD_SELECT, "3")
api:RequestServer(EbonAPI.CS.REFRESH_PERKS, "", 30)
```

- `api:SendServer(opcode, body)` queues the message and returns `true`. The body is optional: `nil` and `""` mean no body, a number is sent as its text.
- `api:RequestServer(opcode, body, minInterval)` does the same, but returns `false` without sending when the same opcode and body were accepted less than `minInterval` seconds ago, by your addon or by any other. A `nil` body and `""` are the same request. Without `minInterval`, or with `0`, nothing is skipped. Use it for refresh requests that several places of your addon may trigger.
- The opcode written as text, one separator byte when there is a body, and the body together cannot exceed 240 bytes: with a one-digit opcode the body holds at most 238 bytes. A longer message raises `EbonAPI.Bridge.send: payload of <n> bytes for opcode <opcode>, the limit is 240`.

## Opcodes

`EbonAPI.SS` names the opcodes the server sends, `EbonAPI.CS` the ones the client sends. Use the names; the numbers appear in the EbonAPI window, under **Diagnostics → Reports → Trace** and **Diagnostics → Reports → Opcodes**. `EbonAPI.Opcodes.describe(opcode)` gives the name and number of one opcode, such as `PLAYER_RUN_DATA (13)`.

| `EbonAPI.SS` | Number | Content |
| --- | --- | --- |
| `SEND_LOADOUTS` | 3 | loadouts of the skill tree, with the ashes; parsed into `SERVER_LOADOUT` |
| `INSTANCE_ENTERED` | 9 | not parsed by EbonAPI |
| `INSTANCE_ENCOUNTERS_COMPLETED` | 10 | not parsed by EbonAPI |
| `JUNK_SOLD` | 12 | not parsed by EbonAPI |
| `PLAYER_RUN_DATA` | 13 | the run, parsed into `SERVER_RUN_DATA` |
| `SOUL_POINTS_MULTIPLIER` | 14 | parsed into `SERVER_MULTIPLIER` |
| `COMMITTED_SOUL_POINTS` | 15 | parsed into `SERVER_ASH` |
| `PLAYER_PERK_CHOICE` | 16 | not parsed by EbonAPI |
| `PLAYER_PERK_GRANTED` | 18 | not parsed by EbonAPI |
| `PLAYER_INTENSITY_POINTS` | 30 | parsed into `SERVER_INTENSITY` |
| `PLAYER_SPEC_INDEX` | 32 | not parsed by EbonAPI |
| `OBJECTIVES_PROPOSALS` | 101 | not parsed by EbonAPI |
| `CURRENT_OBJECTIVE` | 102 | not parsed by EbonAPI |
| `HARDMODE_DATA` | 500 | not parsed by EbonAPI |
| `BUILD_LIST` | 540 | parsed into `SERVER_BUILDS` |
| `BUILD_ACK` | 541 | not parsed by EbonAPI |
| `BUILD_ACTIVE` | 542 | parsed into `SERVER_BUILD_ACTIVE` |
| `CHECKPOINTS_DATA` | 800 | not parsed by EbonAPI |
| `ORBS` | 1220 | not parsed by EbonAPI |

| `EbonAPI.CS` | Number |
| --- | --- |
| `PERK_SELECT` | 17 |
| `REFRESH_PERKS` | 330 |
| `REFRESH_BUILDS` | 340 |
| `BUILD_SAVE` | 341 |
| `BUILD_SELECT` | 344 |
| `ORBS` | 1220 |
| `ORB_FORGET` | 1221 |

The opcodes EbonAPI does not parse reach your addon as raw bodies, through `api:OnServer`.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:OnServer(opcode, fn)` | number, `fn(body, opcode, sender, distribution)` | `true`, or `false` if this function is already registered for this opcode | `EbonAPI.Bridge.on expects a numeric opcode, got <type>`; `EbonAPI.Bridge.on expects a function for opcode <opcode>, got <type>` |
| `api:OffServer(opcode, fn)` | number, function | `true` if something was removed, `false` otherwise | never |
| `api:SendServer(opcode, body?)` | number, string, number or `nil` | `true` | `EbonAPI.Bridge.send expects a numeric opcode, got <type>`; message over 240 bytes; a Lua error when the body is another type, such as a table or a boolean |
| `api:RequestServer(opcode, body, minInterval)` | number, string, seconds | `true`, or `false` when skipped | same as `SendServer` |
| `api:State()` | | the state module | never |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `SERVER_RUN_DATA` | run | yes | run data received |
| `SERVER_INTENSITY` | intensity | yes | intensity received |
| `SERVER_ASH` | ash | yes | the ash amounts changed |
| `SERVER_MULTIPLIER` | number | yes | multiplier received |
| `SERVER_BUILDS` | builds | yes | build list received |
| `SERVER_BUILD_ACTIVE` | slot, builds | yes | the server sent the active build slot |
| `SERVER_LOADOUT` | loadout | yes | loadouts received |
| `SERVER_MESSAGE` | opcode, body, sender | no | any complete message |
| `STREAM_TIMEOUT` | opcode, id, received, total | no | a message in several parts stopped coming |

## Limits

| | Value |
| --- | --- |
| Outgoing message: the opcode as text, one separator byte when there is a body, and the body | 240 bytes; with a one-digit opcode the body holds at most 238 bytes |
| Message in several parts | a message that stops coming for 20 seconds fires `STREAM_TIMEOUT` |
| Ash amount | up to `18446744073709551615`, available as `State.MAX_ASH`, a text |

!!! tip "🎮 Try it"
    In the EbonAPI window, **Diagnostics → Reports → Trace** with **Trace filter** on `recv` lists the last messages received with their opcode names and sizes, such as `PLAYER_RUN_DATA (13)  45B`. **Opcodes** lists both tables, one line per opcode, `S>C` for the server's and `C>S` for the client's. The bridge lines of **Status** show `server bridge: <n> messages received, last <s>s ago`, then `sent`, `queued` and `streams`.

## See also

- [ProjectEbonhold](ebonhold.md) for the client's own services and its way of sending.
- [Modules](../reference/modules.md) for every function of `EbonAPI.State`.
- [Cookbook: run tracker](../cookbook/run-tracker.md) for a complete example built on `SERVER_RUN_DATA`.
