# Slash commands

`/eapi` and `/ebonapi` are the same command. Its output is in the player's language, except the trace and the saved-data summary, which are diagnostic and stay in English.

| Command | Effect |
| --- | --- |
| `/eapi` or `/eapi help` | lists the commands |
| `/eapi status` | the state of every service and of the registered addons |
| `/eapi trace [n] [kind]` | the last `n` trace entries, 20 by default, filtered by kind when given |
| `/eapi debug [addon] on\|off` | turns debug output on or off for one addon; `/eapi debug on` for all; `/eapi debug` shows the state |
| `/eapi lang [code]` | shows the shared language and the codes on offer, or switches to `code` |
| `/eapi db` | a summary of the saved data, one line per addon |
| `/eapi opcodes` | the known opcodes, server to client then client to server |
| `/eapi senders` | the senders observed on the server bridge, with counts |
| `/eapi perf [addon] [label\|reset\|gc]` | memory, running frames and CPU; see [Performance](../guides/performance.md) |

## Reading `/eapi status`

| Line | Meaning |
| --- | --- |
| `version 1.0.0` | EbonAPI's version |
| `consumers: AutoCallboard, MyAddon` | the addons that called `NewAddon` |
| `server bridge: 42 messages received, last 3s ago` | server messages seen this session; `no message received yet` before the first |
| `sent=5 queued=0 streams=0` | messages sent to the server, waiting, and multi-part messages being reassembled |
| `channel ebonapi: joined (index 5, for 120s)` | the shared channel; `joining... (2 requests)` while trying; `not needed by any consumer` without addons |
| `queue: server=0 peers=3  sent channel=12 whispers=40` | lines waiting, and lines sent since login |
| `refused: offline=2 queue full=0 failed=0  lines dropped=0` | only when something was refused |
| `profile: sent P=1 D=3 X=0, received 8, rejected 0` | echo profile announcements sent, received, and rejected as malformed |
| `versions: MyAddon 1.2.0 (1.3.0 available)` | every addon that declared a version |
| `shares: 4 key(s) from 2 addon(s), 6 player(s) seen, 3 received, 0 refused` | the sharing service |
| `rejected=...` and `unreadable bodies=...` | only when a server message or a saved entry had to be dropped or repaired |
| `ProjectEbonhold: detected` | followed by the features present, then the missing ones in grey |
| `character scope: Alice-Ebonhold` | the key of the character's saved data |

## Reading `/eapi trace`

Each line gives the age of the entry, its kind, the addon concerned and a description. Kinds: `boot`, `recv`, `send`, `fail`, `chan`, `wisp`, `offline`, `share`, `repair`, `warn`, `error`.

```text
/eapi trace 30
/eapi trace 30 recv
/eapi trace 10 error
```

When a player reports a problem, ask for `/eapi status` and `/eapi trace 30`.
