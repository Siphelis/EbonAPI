# Modules

The tables of `EbonAPI` an addon may use directly. Everything else under `EbonAPI` is internal and may change in any version.

## `EbonAPI.State`

Also returned by `api:State()`. Guide: [Server](../guides/server.md).

| Function | Returns |
| --- | --- |
| `State.GetRun()` | the run table, or a table EbonAPI fills from ProjectEbonhold's published run data while no message arrived, with the derived `countCan...` and `remaining...` fields added, or `nil` |
| `State.GetIntensity()` | the intensity table, with the same fallback, or `nil` |
| `State.GetAsh()` | the ash table, or `nil` |
| `State.GetMultiplier()` | the multiplier, `0` by default |
| `State.GetBuilds()` | the builds table, or `nil` |
| `State.GetLoadout()` | the loadout table, or `nil` |
| `State.RunAshes()` | `soulPoints, soulPointsMax` as integers, or `nil` |
| `State.BuildEchoes(build)` | list of `{ spellId, stacks, locked }` for one build entry, `locked` being a boolean; `nil` when `build` is not a table |
| `State.sortedBuilds()` | the builds as a list, by slot; an empty list while no build list was received |
| `State.activeBuild()` | `build, slot` of the active build; `nil, slot` when that slot holds no build, `nil` when no build list was received |
| `State.HasServer()` | `true` once ProjectEbonhold is present or a message was received |
| `State.snapshot(name)` | a deep copy of `"run"`, `"intensity"`, `"ash"`, `"builds"` or `"loadout"`; `nil` when that state is empty and for any other name |
| `State.RUN_FIELDS` | the list of run field names, in the order the server sends them |
| `State.MAX_ASH` | the largest ash amount the server can send, as a string: `"18446744073709551615"` |

## `EbonAPI.Ebonhold`

Also returned by `api:Ebonhold()`. Every accessor and its result is listed in the [ProjectEbonhold guide](../guides/ebonhold.md#accessors).

## `EbonAPI.Profile`

Reads and writes the compact texts of the echo profile events, and converts classes. Guide: [Echo profile](../guides/echo-profile.md#decoding).

| Function | Returns |
| --- | --- |
| `Profile.DecodeBuild(echoes)` | `ids, stacks, count`: the list of spell ids, the list of their stack counts (same order) and the number of echoes; `nil` when the text is not a valid compact build |
| `Profile.EncodeEchoes(raw)` | the compact text of a build, made from the `echoes` text of a server build, and how many echoes it holds |
| `Profile.DecodeLocked(locked)` | the list of locked spell ids and their number, or `nil` when the text is not valid |
| `Profile.EncodeLocked(ids)` | the compact text of locked echoes, and how many it holds |
| `Profile.DecodeBans(lists)` | a list of lists of spell ids, or `nil` when the text is not valid |
| `Profile.EncodeBans(lists)` | the compact text of ban lists, and how many lists it kept |
| `Profile.Signature(text)` | the `hash` of a text: the same text always gives the same `hash` |
| `Profile.ClassToken(index)` | the WoW class token for 1 to 10, `nil` otherwise |
| `Profile.ClassIndex(token)` | 1 to 10 for a WoW class token, `nil` for an unknown one |
| `Profile.PlayerClass()` | the player's class index, or `nil` when it is unknown |

Only echo spell ids from 200000 to 204095 are kept. A build holds at most 150 echoes and 63 stacks per echo, a locked list at most 150 ids, and a ban set at most 20 lists of at most 150 ids; the extra ones are left out.

## `EbonAPI.Format`

Text formatting, in the shared language where it matters.

| Function | Example | Result |
| --- | --- | --- |
| `Format.number(value)` | `Format.number(1234567)` | `1 234 567`, rounded to a whole number |
| `Format.compact(value)` | `Format.compact(12345)` | `12.3k`; `1.23M` from a million, `1.23G` from a billion, the unit being chosen after rounding (`Format.compact(999999)` is `1.00M`); below 10000 the number as `Format.number` writes it, such as `5 000`; a negative value keeps a leading `-` |
| `Format.percent(value)` | `Format.percent(12.34)` | `12.3%` |
| `Format.pair(current, maximum)` | `Format.pair(150, 300)` | `150 / 300`, each number as `Format.compact` writes it |
| `Format.rate(value)` | `Format.rate(12345)` | `12.3k/h`, the `/h` in the shared language |
| `Format.bytes(value)` | `Format.bytes(2048)` | `2 KB`; `1.00 MB` from a megabyte |
| `Format.boolean(value)` | `Format.boolean(true)` | `yes`, in the shared language |
| `Format.money(copper)` | `Format.money(12345)` | `1g 23s 45c`; the gold part only above 0, grouped by thousands like `Format.number` (`Format.money(123456789)` is `12 345g 67s 89c`), the silver part from 1 silver or 1 gold, the copper part always; a negative amount gets a leading `-` |
| `Format.moneyRich(copper)` | `Format.moneyRich(12345)` | the same layout with WoW colors on the units; the gold amount is grouped by thousands like `Format.number`, such as `12 345g`; a negative amount gets a leading `-` |
| `Format.duration(seconds)` | `Format.duration(3725)` | `1h 2m`; `2m 5s` under an hour; `45s` under a minute; hours keep counting past 24 |
| `Format.seconds(value)` | `Format.seconds(30)` | `30s` |
| `Format.secondsRemaining(untilTime)` | `Format.secondsRemaining(GetTime() + 10)` | the text `10s`: `Format.duration` of the seconds left, rounded up; `0s` when `untilTime` is `nil` or already past |
| `Format.list(values, separator?)` | `Format.list({ "a", "b" })` | `a, b`; `separator` defaults to `", "` |

A value that is not a number, or is infinite, counts as `0`: no `Format` function raises an error. A result that rounds to zero never gets a minus sign. The units of `Format.duration` and `Format.seconds` follow the shared language.

## `EbonAPI.Lib`

Small helpers EbonAPI uses itself, open to your addon. The others in `EbonAPI.Lib` are internal.

| Function | Does |
| --- | --- |
| `Lib.safeCall(fn, a, b, c)` | calls `fn` with up to three arguments, reports an error instead of raising it, returns `true` on success and `false` after an error |
| `Lib.safeGet(fn, a, b)` | the same with up to two arguments, returns the first result or `nil` after an error |
| `Lib.report(err)` | sends an error to the game's error display, or to the chat when the game has none |
| `Lib.upper(text)` | in capitals, accented letters included: `"élan"` gives `"ÉLAN"` |
| `Lib.icon(value)` | `Interface\Icons\` + the name for an icon name, the path unchanged for a path, `nil` for an empty value |
| `Lib.num(value, fallback)` | the value as a finite number, or the fallback, or `0` |
| `Lib.int(value, fallback)` | the same, rounded down |
| `Lib.bool(value)` | `true` or `false` |
| `Lib.copper(value)` | a non-negative integer copper amount, or `0` |
| `Lib.count(t)` | the number of keys in a table |
| `Lib.isEmpty(t)` | `true` for a table without keys |
| `Lib.copyShallow(source, target?)` | copies the keys of `source` into `target` |
| `Lib.copyDeep(source)` | a deep copy, cycles included |
| `Lib.applyDefaults(target, defaults)` | fills the missing keys of `target`, recursively, and returns `target` |
| `Lib.indexOf(list, value)` | the index of a value in a list, or `nil` |
| `Lib.removeValue(list, value)` | removes the first occurrence, returns `true` when found |
| `Lib.keys(t, into?)` | appends the keys of `t` to `into` (a new list if omitted) and returns it, in no set order |
| `Lib.sortedKeys(t)` | the keys of a table as a list: number keys first in increasing order, then the other keys sorted as text |
| `Lib.trim(text)` | without leading and trailing spaces |
| `Lib.split(text, separator, into)` | splits at each `separator` (plain text, not a pattern) into the list `into`, which it empties first; returns `into, count`; empty parts are kept |
| `Lib.stripColor(text)` | without WoW color codes |
| `Lib.colorize(color, text)` | wrapped in a WoW color code |
| `Lib.cutUtf8(text, start, budget)` | where a piece of at most `budget` bytes starting at `start` must end, never inside a character: the position of its last byte; a character wider than `budget` is kept whole |
| `Lib.splitUtf8(text, budget, into)` | fills the list `into` with pieces of at most `budget` bytes, never inside a character (a character wider than `budget` gets a part of its own); returns `into, count` |

## Opcodes

`EbonAPI.SS` and `EbonAPI.CS` map opcode names to numbers; both tables are listed in the [Server guide](../guides/server.md#opcodes). `EbonAPI.Opcodes.describe(opcode)` returns `PLAYER_RUN_DATA (13)` for a known number and `opcode 999` for an unknown one.

## Colors

`EbonAPI.Log.COLOR` holds the WoW color codes EbonAPI prints with: `PREFIX`, `TEXT`, `ERROR`, `WARN`, `SUCCESS`, `HIGHLIGHT`, `MUTED`, `GOLD`, `SILVER`, `COPPER` and `RESET`. They follow the player's skin, from its [chat colors](skin-parameters.md#chat).

## Constants

| Constant | Value |
| --- | --- |
| `EbonAPI.name` | `"EbonAPI"` |
| `EbonAPI.version` | the `## Version` line of `EbonAPI.toc`, such as `"2.0.0"` |
| `EbonAPI.MAJOR`, `EbonAPI.MINOR`, `EbonAPI.PATCH` | the three numbers of that version, such as `2`, `0`, `0` |
| `EbonAPI.NAME_MAX` | `32`, the longest addon name |
