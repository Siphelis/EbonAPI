# 🧩 EbonAPI

**One foundation under every Ebonhold addon.**

EbonAPI is the shared runtime of Siphelis's Ebonhold addons:
[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad) and EbonStat.
It pools what each of them used to do on its own, without touching what makes
them who they are: every addon keeps its interface, its purpose and its logic.
Since 1.1 it also carries everything that travels between players: a single
hidden channel, a single send queue, and the Echo profile that EbonBuilds'
matrix reads from other players.

EbonAPI does not replace Ace3 and does not duplicate ProjectEbonhold.

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

---

## Table of Contents

- [Why this addon](#-why-this-addon)
- [Features](#-features)
- [Installation](#-installation)
- [Slash commands](#-slash-commands)
- [For addon authors](#-for-addon-authors)
- [Code anatomy](#-code-anatomy--how-it-works)
- [Known limitations](#-known-limitations)
- [What EbonAPI won't do](#-what-ebonapi-wont-do)
- [Languages](#-languages)
- [License & credits](#-license--credits)

---

## 🔥 Why this addon

You don't install EbonAPI for its own sake: AutoCallboard, EbonBuilds,
SkillTreeAutoLoad and EbonStat refuse to load without it.

Each of them used to bring its own server bridge, its own send queue, its own
storage and its own language setting. Three bridges read every server message
three times. Three queues each stayed under the flood limit on their own, and
went over it together. EbonAPI keeps one of each, for all of them.

## ✨ Features

- **One send queue for the whole client** — messages to the server go first,
  then channel lines and whispers, one send every 0.15 s. The flood limit
  counts the client, not each addon: three independent queues went over it,
  one stays under.
- **One server bridge** — each server message is read once and handed to the
  addons that asked for it. A message nobody listens to costs nothing.
- **One hidden channel** — `ebonapi`, removed from your chat windows: no
  message and no notice ever shows up in them.
- **One language choice** — pick it once, every addon follows. An addon that
  doesn't ship that language falls back to English on its own, without forcing
  English on the others.
- **Update notices** — when another player runs a newer release of one of your
  addons, you are told once per session, with the download link your installed
  addon provides. Never a link coming from another player.
- **Your Echo builds, shared once** — your class and the Echo builds the server
  keeps for your character go out on the channel for other players' EbonBuilds
  matrix, and only go out again when they change.
- **Errors stay visible** — a bug in one addon never takes the others down, and
  never vanishes: it is passed on, with its stack, to BugSack, Swatter or
  Blizzard's error frame.
- **Diagnostics built in** — `/eapi status` shows the bridge, the channel, the
  queue and ProjectEbonhold at a glance; `/eapi perf` measures memory and CPU
  per addon.

## 📦 Installation

1. [**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest) — download the latest version.
2. Unzip the `EbonAPI` folder into
   `Interface/AddOns/`.
3. Check the AddOns selection screen to make sure **EbonAPI** is ticked,
   alongside the addons that use it.

EbonAPI shows nothing on its own. It only joins its channel once an addon
registers with it.

## 💬 Slash commands

Aliases: `/eapi` and `/ebonapi`.

| Command | Effect |
| --- | --- |
| `/eapi` (or `help`) | Lists the commands. |
| `/eapi status` | Runtime summary: registered addons, server bridge, channel, send queue, profile, versions, ProjectEbonhold services, rejected messages. |
| `/eapi trace [n]` | The last `n` diagnostic entries (20 by default). |
| `/eapi debug [addon\|*] on\|off` | Toggles verbose output, for one addon or for all of them. |
| `/eapi lang [code]` | Shows or sets the shared language (`enUS`, `frFR`, `deDE`, `esES`). |
| `/eapi db` | Summary of the saved data. |
| `/eapi opcodes` | Known server opcodes. |
| `/eapi senders` | Senders observed on the server bridge. |
| `/eapi perf [addon] [label\|reset\|gc]` | Memory, running frames and CPU, per addon. |

The diagnostic buffer keeps the last 128 events, even with debug off: what
matters is what happened *before* anyone thought of turning tracing on. When
reporting a problem, `/eapi status` and `/eapi trace 30` are the two outputs
worth copying.

## 🔌 For addon authors

Everything below is the contract between EbonAPI and the addons that use it.

### Getting started

EbonAPI is a hard dependency. In each consumer's `.toc`:

```
## Dependencies: EbonAPI
```

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 1)   -- name, required major, required minor

if not api then
  return   -- incompatible version; EbonAPI has already said why in chat
end
```

The major must match exactly; the minor must be at least the one requested.
Everything then goes through this handle, which lets `api:OffAll()` take
everything back in one call.

### Errors

An error is something to fix. So EbonAPI decides nothing in its place: it
makes the error visible to whoever can fix it, and steps aside.

**A bad call blows up immediately.** Passing something other than a function to
`api:On`, a string opcode to `Bridge.on`, a missing table to `api:DB`: these are
bugs in the calling code. They raise an error pointing at **the offending
addon's line** (`error(..., 2)`), not at a line of EbonAPI where there would be
nothing to fix. None of these functions silently returns `false`.

**A subscriber's error is caught, then released.** The `pcall` exists only so
that a bug in AutoCallboard doesn't take EbonStat down with it. Right after,
the error goes back out through `geterrorhandler()`: Swatter, BugSack or
Blizzard's error frame receive it with its stack, as if it had never been
caught.

There is no deduplication, no muting, no automatic quarantine. A failing
subscriber is skipped for that dispatch only and called again on the next
event: every event is a new attempt.

**Outside data is not an error.** An unreadable server message, a corrupted
save, a missing ProjectEbonhold service: that is a client's everyday life. They
are validated, handled, and **counted**. The count shows in `/eapi status`,
because a rejection nobody sees would be an error with no fix behind it.

### Events

```lua
api:On("READY", function(event, version) end)
api:Off("READY", fn)
api:OffAll()
```

Some events are **sticky**: they replay their last state at subscription time.
Without that, an addon loaded after a piece of server data arrived would stay
blind until the next message, which may never come.

| Event | Sticky | Payload |
|---|---|---|
| `READY` | yes | version |
| `LANGUAGE_CHANGED` | yes | code |
| `FEATURE_CHANGED` | no | name, available |
| `SERVER_RUN_DATA` | yes | run table |
| `SERVER_ASH` | yes | `{ spendable, committed, source }`, published only when the balance changes |
| `SERVER_BUILDS` | yes | build list |
| `SERVER_BUILD_ACTIVE` | yes | slot, list |
| `SERVER_LOADOUT` | yes | tree loadout |
| `SERVER_INTENSITY` | yes | intensity table |
| `SERVER_MULTIPLIER` | yes | number |
| `SERVER_MESSAGE` | no | opcode, body, sender |
| `STREAM_TIMEOUT` | no | opcode, id, received, total |
| `SEND_FAILED` | no | kind, then the line (channel, server) or the prefix and target (whisper) |
| `CHANNEL_JOINED` | yes | index of the common channel |
| `CHANNEL_LOST` | no | — |
| `PEER_OFFLINE` | no | name, sends removed from the queue |
| `UPDATE_AVAILABLE` | no | addon, available version, installed version, link |
| `PROFILE_SLOTS` | no | sender, class, slots |
| `PROFILE_BUILD` | no | sender, class, slot, hash, echoes |
| `PROFILE_BANS` | no | sender, class, hash, lists |

A callback may subscribe or unsubscribe while it runs.

### Client events and timers

```lua
api:OnEvent("PLAYER_REGEN_DISABLED", fn)
api:OffEvent("PLAYER_REGEN_DISABLED", fn)

api:Tick("refresh", 0.5, fn)   -- the id is prefixed with the addon's name
api:Untick("refresh")
```

A single frame carries everything. Its `OnUpdate` only runs while at least one
timer is alive.

The bus keeps two registries per event. Consumer subscribers go through a
protected call, so a bug in one doesn't take the others down. Core subscribers
(`Bus.onCore`, reserved for EbonAPI) are called directly: protecting them from
themselves would protect no one, and cost one more protected call on every
event. An event with no consumer subscriber therefore costs **no** protection.

### Server bridge

```lua
api:OnServer(EbonAPI.SS.PLAYER_RUN_DATA, function(body, opcode, sender) end)
api:SendServer(EbonAPI.CS.BUILD_SELECT, "3")
api:RequestServer(EbonAPI.CS.REFRESH_BUILDS, "", 30)   -- coalesced over 30 s
```

Sends go through the single queue of `Net/Queue` (see
[Common channel](#common-channel)): five requests issued in the same frame by
three addons would get lost or cut the connection. Messages to the server go
ahead of everything else. `RequestServer` coalesces across addons: the server
receives the request only once per interval. Two requests are the same if they
carry the same opcode and the same body.

The receiving grammar is the union of what the three original implementations
accepted: a message without a body is delivered (two of the three dropped it),
and both fixed and variable fragment widths are accepted.

Cost of a received message, whatever the number of subscribers: **one**
protected call, **one** pattern evaluated, **one** clock read, and **no**
allocation beyond the body itself. An opcode nobody listens to costs no
protection.

### Common channel

```lua
api:OnChannel("A", "H", function(sender, body, letter, op) end)
api:OffChannel("A", "H", fn)
api:Say("H", "digests")                 -- under the addon's letter, split if needed
api:IsChannelJoined()
```

A single hidden channel, `ebonapi`, for everything addressed to everyone. Each
addon speaks under its letter (`A` AutoCallboard, `B` EbonBuilds,
`S` SkillTreeAutoLoad, `G` EbonStat, `E` EbonAPI) and only hears what it asks
for: a line with another letter or another op stops at a table lookup.

A line has the form `EA1:<letter>:<op>:<no>.<k>/<n>:<chunk>`, 255 characters at
most. A longer message goes out in packets, sixteen at most, reassembled per
sender and per number; a message still incomplete after 30 s is dropped. An
accented character is never split: the cut steps back one byte if needed, and
`<n>` counts the packets actually produced. The body never contains `|`, since
the client refuses that character, and `Say` blows up if given one. A marker
injected by the server in front of the line (`[HCIV]`) is ignored.

The channel is joined as soon as an addon registers through `NewAddon`, because
EbonAPI then sends the Echo profile on it; EbonAPI alone does not join it. It
is removed from the chat windows, so neither message nor notice shows up. The
join is checked every second until it succeeds, and requested again every ten.

**The queue.** Everything leaving the client goes through `Net/Queue`: messages
to the server first, then channel lines and whispers, one send every 0.15 s.
The anti-flood counts the whole client, not each addon: three independent
queues went over the limit, a single one stays under. The peer queue is capped
at 500 sends; a message that doesn't fit whole is refused whole, never cut
(`Say` and `WhisperAll` return `false`).

**Players who left.** When the client answers "no player named X" to a whisper,
whispers to X are removed from the queue, refused for 60 s, and `PEER_OFFLINE`
tells the addon. The system message is only listened to in the minute following
a whisper: at rest, nothing runs.

### Whispers

```lua
api:Whisper("ACBR", "Bob", "G:abc")          -- one addon whisper, through the queue
api:WhisperAll("ACBR", "Bob", parts, n)      -- several, all or none
api:OnWhisper("ACBR", function(sender, text, distribution, prefix) end)

api:WhisperStream("ACBR", "Bob", "C", hash, code)   -- a long body, in chunks
api:OnWhisperStream("ACBR", "C", function(sender, body, id, op) end, onPart)
```

What one player asks another for (a public EbonBuilds build, an AutoCallboard
route) goes out as a whisper, through the same queue as everything else. The
client limits an addon message to 255 bytes **prefix and tab included**:
`Whisper` blows up beyond `255 - #prefix - 1`.

A stream has the form `EAS:<op>:<id>:<k>/<n>:<chunk>`. It goes out in four
hundred chunks at most, all or none; `WhisperStream` returns `false` if it
doesn't fit in the queue or if the recipient was just reported offline. On
arrival, chunks are reassembled per sender, prefix, op and id; `onPart` is
called on every chunk but the last, for a progress bar; a stream still
incomplete after 30 s is dropped. As on the channel, an accented character is
never split and `<n>` is the real number of chunks.

### Echo profile

EbonAPI itself sends, under the letter `E`, what EbonBuilds' matrix reads from
other players: the class and the Echo builds the server keeps for the character
(opcode 540), plus the ban lists EbonBuilds hands it through
`api:SetProfileBans(lists)`. One EbonAPI per client, so nothing left to
arbitrate between addons, and the format is written only once.

| Op | Body | Role |
|---|---|---|
| `P` | `<class>:<slots>` (`8:1.2.5`) | the occupied slots |
| `D` | `<class>:<slot>:<hash>:<echoes>` | one build |
| `X` | `<class>:<hash>:<list>;<list>...` | the ban lists |

An Echo fits in three characters of the alphabet `0-9 A-Z a-z - _`: two for the
gap between its id and 200000, one for its stacks. Echoes are sorted, so the
same build always gives the same text and the same hash
(`EbonAPI.Profile.Signature`, eight characters). Classes run from `WARRIOR` 1
to `DRUID` 10, the matrix's order (`EbonAPI.Profile.ClassIndex`).

**When it goes out.** What has already been sent is kept in `EbonAPIDB`, per
character: the hash of each slot, the announced slots, the ban hash. A line is
recorded only once it has left the queue, not when it enters it: a `/reload`
that empties the queue before it was served therefore loses nothing, and the
line goes out again on the next load. Outside that case, a `/reload` sends
nothing again; only a build that changes goes out again, and `P` only goes out
again if a slot appears or disappears.

A new session sends everything again, for players who didn't know this
character yet, and asks the server for the build list ten seconds after login.
A session is new when the login comes more than ten minutes after the end of the
previous one. The end is the logout or the `/reload` (`PLAYER_LOGOUT`); without
a clean logout (crash, disconnection), it counts from the previous login. A
`/reload` after two hours of play therefore does not open a session.

**On receipt**, EbonAPI checks the bounds (class 1 to 10, slot 1 to 20, 150
echoes per build, 20 lists of 150) and recomputes the hash; a damaged message
is counted and dropped. The rest reaches the subscribers of `PROFILE_SLOTS`,
`PROFILE_BUILD` and `PROFILE_BANS` decoded, echoes and lists as compact text;
`EbonAPI.Profile.DecodeBuild` and `DecodeBans` read them back when an addon
needs to. EbonAPI keeps nothing of the profiles it receives.

The profile goes out as soon as any addon is registered: EbonStat alone is
enough.

### Versions

```lua
api:Version("2.6.0", "https://...")   -- the installed version, and where to find it
api:AvailableUpdate()                 -- "2.7.0", "2.6.0" if a newer one is around
```

A single `V` line goes out under the letter `E` per session, for all addons at
once: `A=2.6.0,E=1.1.0,S=1.8.0`. Only releases (`x.y.z`) appear in it; a work
build (`x.y.z-n`) keeps to itself. Whoever hears a version newer than their own
keeps it in `EbonAPIDB` for the whole account, tells the player once per
session and emits `UPDATE_AVAILABLE`; the link shown is always the one the
installed addon gave, never another player's. Whoever hears a player running
behind answers after two to eight seconds, unless someone already did. A kept
version is forgotten as soon as the installed version catches up.

### Normalized server state

```lua
local State = EbonAPI.State

State.GetRun()          -- 19 fields + derived values (remainingRerolls, ...)
State.GetAsh()          -- a single balance, with its source
State.GetBuilds()       -- each slot carries `echoes`, the server's raw list
State.activeBuild()
State.GetLoadout()
State.GetIntensity()
State.GetMultiplier()
State.snapshot("builds")   -- stable copy
```

Getters return live tables: read them, don't modify them. For a detached copy,
go through `State.snapshot()`.

The Soul Ash balance used to arrive by two independent paths (opcode 15 on
EbonStat's side, opcode 3 on SkillTreeAutoLoad's) with no reconciliation. It is
now unique, and `ash.source` tells which message set it.

`SERVER_ASH` is only published if the spendable or committed balance changes.
The same balance repeated, by either opcode, updates `ash.source` and `ash.at`
without publishing anything: EbonStat records balance differences and keeps
them forever, so a balance republished unchanged would only be noise there. A
late subscriber always gets the current balance through the replay.

`State.GetIntensity()` always returns the same table when it falls back on
`EbonholdIntensityData`: EbonStat's window reads it four times a second.

### Storage

```lua
local db = api:DB({
  account   = { size = 10 },
  character = { position = 1 },
})

db.account.size
db.char.position        -- nil before PLAYER_LOGIN, resolved afterwards
api:Shared().account    -- space shared by all addons
```

Everything lives in `EbonAPIDB`: the data survives regardless of which
consumers are installed. A default added in a later version never overwrites a
choice the player already made.

This is where the addons are moving what they keep: EbonBuilds' received
profiles first, then AutoCallboard's routes and collections, SkillTreeAutoLoad's
saves and EbonBuilds' builds, one addon at a time. Each addon keeps its format;
what is shared between addons goes through a declared format, never by reading
another addon's table.

#### Migrations

```lua
db:MigrateOnce("from-MyAddonDB", MyAddonDB, function(store, legacy)
  -- read legacy, write into store
  return migratedCount   -- nil = not done, will be replayed
end)

db:MigrateOncePerCharacter("key", legacy, function(store, legacy, name, key) end)
```

**Absolute rule, learned the hard way on SkillTreeAutoLoad**: the "already
migrated" marker lives in the same file as the data it protects. When the
marker outlives what it guards, the migration no longer replays and the data
is lost for good. Here both are in `EbonAPIDB`. Corollary: an original database
is never modified, only read.

A migration that returns `nil` or fails does not set its marker: it will be
retried on the next load.

### Localization

```lua
local L = api:Locale({
  enUS = { HELLO = "hello" },
  frFR = { HELLO = "bonjour" },
})

api:Localized(widget, "HELLO")   -- translates itself again when the language changes
```

The returned table is live: it is emptied and refilled in place, so a
`local L = api:Locale(...)` kept at the top of a file stays valid.

The **choice** of language is shared and persisted; the translation tables stay
with each addon. Each registry falls back on *its own* `enUS` base,
independently: if the shared language is `deDE` and an addon doesn't provide
it, that addon speaks English without forcing English on the others.

### Diagnostics

Writing a diagnostic entry only stores five raw values. Formatting happens only
on reading, so a server message allocates nothing.

An addon declares what it wants measured: `api:Track("map", frame)` for a frame,
`api:TrackFunction("OnUpdate", fn)` for a function, then
`api:Perf("after combat")` or `/eapi perf MyAddon after combat` for a report,
kept in `EbonAPIDB` (twenty per addon). CPU is only read with the profiler on
(`/console scriptProfile 1`, then `/reload`).

## 🧠 Code anatomy — how it works

EbonAPI loads in the order of its `.toc`: primitives first, then the languages,
the queue, the server, the network, and `Boot.lua` last, which starts
everything at login. Everything hangs off the global table `EbonAPI`.

### `Core/` — the foundation

| File | Exact role |
| --- | --- |
| `Lib.lua` | Dependency-free primitives: coercion, tables, strings, UTF-8 splitting, a `pcall` that reports. |
| `Api.lua` | Namespace, version guard, consumer handles, callback bus. |
| `Listeners.lua` | Subscriber lists that can be modified while they run. |
| `Log.lua` | Prefixed log and circular diagnostic buffer. |
| `Bus.lua` | A single frame for every client event and every timer. |
| `Assembler.lua` | Reassembly of chunked messages, with expiry. |
| `DB.lua` | `EbonAPIDB`: account and character scopes, defaults, migrations. |
| `Session.lua` | Tells whether the login opens a new session. |
| `Format.lua` | Common formatters (numbers, money, durations). |
| `Perf.lua` | Memory, running frames and CPU per addon (`/eapi perf`). |

### `Language/` and `Locales/` — the multilingual system

| File | Exact role |
| --- | --- |
| `Language/Locale.lua` | The language engine and the **shared language choice**. |
| `Locales/enUS.lua`, `frFR.lua`, `deDE.lua`, `esES.lua` | EbonAPI's own messages, in four languages. |

### `Net/` — between players

| File | Exact role |
| --- | --- |
| `Queue.lua` | **The one** send queue: server, channel, whispers. |
| `Channel.lua` | The common `ebonapi` channel, its packets, simple whispers. |
| `Whisper.lua` | Whisper reception by prefix, and chunked streams. |
| `Profile.lua` | The player's Echo profile, encoded, sent and read back in one place. |
| `Version.lua` | Addon versions, announced once per session. |

### `Server/` — talking to the server

| File | Exact role |
| --- | --- |
| `Opcodes.lua` | Map of the observed AAM0x9 opcodes. |
| `Bridge.lua` | **The one** server bridge: parser, reassembler, sending through the queue. |
| `Ebonhold.lua` | ProjectEbonhold facade, with detection and graceful degradation. |
| `State.lua` | Normalized server state, published once for everyone. |

### At the root

| File | Exact role |
| --- | --- |
| `Boot.lua` | Startup: attaches `EbonAPIDB` on load; starts the bridge, the state, the channel, the profile and the versions at login; emits `READY`; interprets the `/eapi` commands. |
| `EbonAPI.toc` | The WoW manifest: metadata, saved variable (`EbonAPIDB`), and file load order. |

## 🚧 Known limitations

- **Chunked sending to the server is not implemented.** No addon in production
  emits it, so nothing proves the server can reassemble it. The 240-byte limit
  is therefore real and final: exceeding it is a calling bug, and `Bridge.send`
  raises an error naming the size and the limit. The common channel, for its
  part, does split (sixteen packets at most).
- **The sender filter is on by default.** Only a whisper from the player to
  themselves is read as coming from the server: without the filter, any player
  in the party, raid or guild could post on `AAM0x9`. It has been checked in
  game (the build list arrives, the profile goes out). If the server ever
  answered under another name, the bridge would go silent: `/eapi senders`
  shows the names received, and `EbonAPI.Bridge.setStrictSender(false)` turns
  the filter off.
- **A version announced on the channel is believed.** Nothing signs a `V` line:
  a player announcing `A=99.0.0` makes the AutoCallboard users who hear it see
  "version 99.0.0 is available", and the value stays kept until the installed
  version catches up. The link shown, however, never comes from the channel.
- **The profile only carries Echoes 200000 to 204095.** An id outside that range
  is removed from the build sent, without a message.
- **The opcode map is maintained by hand.** `Server/Opcodes.lua` copies the
  observed ones (`EbonAPI.SS`, `EbonAPI.CS`); if ProjectEbonhold changes them,
  it won't follow on its own. The ones ProjectEbonhold defines can also be read
  at runtime through `EbonAPI.Ebonhold.OpcodeCS(name)`, and
  `EbonAPI.Ebonhold.SendToServer(name, body)` sends through ProjectEbonhold
  itself.
- **An incomplete chunked server message can survive up to 22 s** (20 s of
  expiry plus one sweep period) before being freed.

## 🚫 What EbonAPI won't do

Configuration, high-level timers, generic hooks, serialization: Ace3 does it
better. EbonStat's column format, AutoCallboard's travel data,
SkillTreeAutoLoad's tree reading, EbonBuilds' matrix notes: that's business
logic, and it stays with them. EbonAPI carries and stores; it doesn't judge.

## 🌍 Languages

English, French, German and Spanish ship complete for EbonAPI's own messages.
The language picked with `/eapi lang`, or from an addon's own language menu,
applies to every addon that relies on EbonAPI for its translations.

## 📜 License & credits

Addon by **Siphelis**.
Built against ProjectEbonhold, the client-side interface of the Ebonhold server.

EbonAPI is published under the [PolyForm Strict License 1.0.0](LICENSE): you may
use it for noncommercial purposes, but you may **not sell, modify, or
redistribute it**. This includes publishing it on an addon site, bundling it in
a pack, or distributing a modified version. Ask for permission before any such
use.

---
