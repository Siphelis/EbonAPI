# Modules

The tables of `EbonAPI` an addon may read directly. Everything else under `EbonAPI` is internal and may change without notice.

## `EbonAPI.State`

Also returned by `api:State()`. Guide: [Server](../guides/server.md).

| Function | Returns |
| --- | --- |
| `State.GetRun()` | the run table, or ProjectEbonhold's published run data, or `nil` |
| `State.GetIntensity()` | the intensity table, with the same fallback, or `nil` |
| `State.GetAsh()` | the ash table, or `nil` |
| `State.GetMultiplier()` | the multiplier, `0` by default |
| `State.GetBuilds()` | the builds table, or `nil` |
| `State.GetLoadout()` | the loadout table, or `nil` |
| `State.RunAshes()` | `soulPoints, soulPointsMax` as integers, or `nil` |
| `State.BuildEchoes(build)` | list of `{ spellId, stacks, locked }` for one build; cached on the build |
| `State.sortedBuilds()` | the builds as a list, by slot |
| `State.activeBuild()` | `build, slot` of the active build |
| `State.HasServer()` | `true` once ProjectEbonhold is present or a message was received |
| `State.snapshot(name)` | a deep copy of `"run"`, `"intensity"`, `"ash"`, `"builds"` or `"loadout"` |
| `State.RUN_FIELDS` | the list of run field names, in the order the server sends them |
| `State.MAX_ASH` | the largest ash amount the server can send, as a string |

## `EbonAPI.Ebonhold`

Also returned by `api:Ebonhold()`. Every accessor and its result is listed in the [ProjectEbonhold guide](../guides/ebonhold.md#accessors).

## `EbonAPI.Profile`

Decoders for the echo profile events. Guide: [Echo profile](../guides/echo-profile.md#decoding).

| Function | Returns |
| --- | --- |
| `Profile.DecodeBuild(echoes)` | `ids, stacks, count`, or `nil` |
| `Profile.DecodeBans(lists)` | a list of lists of spell ids, or `nil` |
| `Profile.ClassToken(index)` | the WoW class token for 1 to 10 |
| `Profile.ClassIndex(token)` | 1 to 10 for a WoW class token |
| `Profile.PlayerClass()` | the player's class index |

## `EbonAPI.Format`

Text formatting, in the shared language where it matters.

| Function | Example | Result |
| --- | --- | --- |
| `Format.number(value)` | `Format.number(1234567)` | `1 234 567` |
| `Format.compact(value)` | `Format.compact(12345)` | `12.3k`; `M` and `G` above a million and a billion |
| `Format.percent(value)` | `Format.percent(12.34)` | `12.3%` |
| `Format.pair(current, maximum)` | `Format.pair(150, 300)` | `150 / 300` |
| `Format.rate(value)` | `Format.rate(12345)` | `12.3k/h` |
| `Format.bytes(value)` | `Format.bytes(2048)` | `2 KB`; `MB` above a megabyte |
| `Format.boolean(value)` | `Format.boolean(true)` | `yes`, in the shared language |
| `Format.money(copper)` | `Format.money(12345)` | `1g 23s 45c` |
| `Format.moneyRich(copper)` | `Format.moneyRich(12345)` | the same, with WoW colors |
| `Format.duration(seconds)` | `Format.duration(3725)` | `1h 2m`; `2m 5s` under an hour; `45s` under a minute |
| `Format.seconds(value)` | `Format.seconds(30)` | `30s` |
| `Format.secondsRemaining(untilTime)` | `Format.secondsRemaining(GetTime() + 10)` | `10`, never negative |
| `Format.list(values, separator?)` | `Format.list({ "a", "b" })` | `a, b` |

## `EbonAPI.Lib`

Small utilities EbonAPI uses itself.

| Function | Does |
| --- | --- |
| `Lib.safeCall(fn, a, b, c)` | calls `fn` in a `pcall`, reports an error, returns `true` on success |
| `Lib.safeGet(fn, a, b)` | same, returns the result or `nil` |
| `Lib.report(err)` | sends a message to the game's error handler |
| `Lib.num(value, fallback)` | a finite number, or the fallback, or `0` |
| `Lib.int(value, fallback)` | the same, floored |
| `Lib.bool(value)` | `true` or `false` |
| `Lib.count(t)` | the number of keys in a table |
| `Lib.isEmpty(t)` | `true` for a table without keys |
| `Lib.copyShallow(source, target?)` | copies the keys of `source` into `target` |
| `Lib.copyDeep(source)` | a deep copy, cycles included |
| `Lib.applyDefaults(target, defaults)` | fills the missing keys of `target`, recursively |
| `Lib.indexOf(list, value)` | the index of a value in a list, or `nil` |
| `Lib.removeValue(list, value)` | removes the first occurrence, returns `true` when found |
| `Lib.keys(t)`, `Lib.sortedKeys(t)` | the keys of a table, as a list, sorted or not |
| `Lib.trim(text)` | without leading and trailing spaces |
| `Lib.split(text, separator, into)` | splits into the list `into`, returns `into, count` |
| `Lib.stripColor(text)` | without WoW color codes |
| `Lib.colorize(color, text)` | wrapped in a WoW color code |
| `Lib.splitUtf8(text, budget, into)` | cuts into pieces of at most `budget` bytes, never inside a character |

## Opcodes

`EbonAPI.SS` and `EbonAPI.CS` map opcode names to numbers; both tables are listed in the [Server guide](../guides/server.md#opcodes). `EbonAPI.Opcodes.describe(opcode)` returns `PLAYER_RUN_DATA (13)` for a known number and `opcode 999` for an unknown one.

## Colors

`EbonAPI.Log.COLOR` holds the WoW color codes EbonAPI prints with: `PREFIX`, `TEXT`, `ERROR`, `WARN`, `SUCCESS`, `HIGHLIGHT`, `MUTED` and `RESET`.

## Constants

| Constant | Value |
| --- | --- |
| `EbonAPI.version` | `"1.0.0"` |
| `EbonAPI.MAJOR`, `EbonAPI.MINOR`, `EbonAPI.PATCH` | `1`, `0`, `0` |
| `EbonAPI.NAME_MAX` | `32`, the longest addon name |
