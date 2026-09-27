# 💬 Whispers

Send a line, or a long stream, to one player. Nothing shows in anyone's chat.

## What it does

- **Plain whispers**: one addon message to one player, under a prefix you choose.
- **Streams**: a body of any reasonable size, split into parts and reassembled on the other side, with progress.
- Handles players who are offline: their queued lines are dropped and you are told.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
local PREFIX = "MyAddonW"

api:OnWhisper(PREFIX, function(sender, text)
  api:Print(sender .. " whispers: " .. text)
end)

api:Whisper(PREFIX, "Alice", "ping")
```

A stream, for anything longer than a line:

```lua
api:OnWhisperStream(PREFIX, "ROUTE", function(sender, body, id)
  api:Print("route " .. id .. " received from " .. sender .. ", " .. #body .. " bytes")
end, function(sender, id)
  api:Debug("receiving route " .. id .. " from " .. sender)
end)

api:WhisperStream(PREFIX, "Alice", "ROUTE", "frostfire", routeText)
```

## How it works

**Prefix.** The prefix is your addon message prefix, the label the client attaches to addon whispers. Pick one unique to your addon and keep it short: it takes room in every line. EbonAPI registers it with the client the first time you listen on it.

**Plain whispers.** `api:Whisper(prefix, target, text)` queues one line. The receiver's callback gets `fn(sender, text, distribution, prefix)`. The text and the prefix together must fit in one addon message: 255 bytes minus the prefix and a separator.

**Streams.** `api:WhisperStream(prefix, target, op, id, body)` splits the body into parts and queues them all, or none. The receiver's callback gets `fn(sender, body, id, op)` once the last part arrived, and the optional `onPart(sender, id, op)` at every part before that. Parts must arrive within 30 seconds of each other. The `id` is yours: pass a string without `:` to name the stream, or `nil` to let EbonAPI number it. The receiver sees it, which makes replies easy to match.

**Pace.** Every line leaves through the shared queue, one every 0.15 seconds. A stream of 100 parts takes 15 seconds to send.

**Offline players.** When the client answers that the player is not found, EbonAPI drops every line still queued for that player, fires `PEER_OFFLINE(name, dropped)`, and refuses new whispers to that player for 60 seconds. `api:Whisper` and `api:WhisperStream` return `false` during that time.

**Names.** Targets and senders are character names without the realm.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:OnWhisper(prefix, fn)` | prefix, `fn(sender, text, distribution, prefix)` | `true`, or `false` if already registered | prefix empty, fn is not a function |
| `api:OffWhisper(prefix, fn)` | prefix, function | `true` if something was removed | |
| `api:Whisper(prefix, target, text)` | prefix, player name, string | `true` when queued, `false` when refused | prefix empty, text missing or too long |
| `api:WhisperAll(prefix, target, parts, count?)` | prefix, player name, list of strings | `true` when all are queued, `false` otherwise | same as `Whisper` |
| `api:OnWhisperStream(prefix, op, fn, onPart?)` | prefix, op, `fn(sender, body, id, op)`, `onPart(sender, id, op)` | `true`, or `false` if already registered | prefix empty, op not alphanumeric, fn is not a function |
| `api:OffWhisperStream(prefix, op, fn, onPart?)` | same | `true` if something was removed | |
| `api:WhisperStream(prefix, target, op, id, body)` | prefix, player name, op, string or `nil`, string | `true` when queued, `false` when refused or too long | prefix empty, op invalid, body not a string, id contains `:`, prefix and op leave no room |

`api:WhisperAll` sends several plain lines to one player as a block: either every line is queued, or none.

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `PEER_OFFLINE` | player name, lines dropped | no | the client reported the player as not found |
| `SEND_FAILED` | `"whisper"`, prefix, target | no | the client refused a line |

## Limits

| | Value |
| --- | --- |
| Plain whisper | 255 bytes minus the prefix and one separator |
| Stream | 400 parts; about 90 KB with short prefix, op and id |
| Reassembly | parts must arrive within 30 seconds of each other |
| Offline hold | 60 seconds without whispers to a player reported not found |
| Queue | 500 lines for every addon together, one line every 0.15 seconds |

!!! tip "🎮 Try it"
    `/eapi trace 20 wisp` lists the streams received. The queue line of `/eapi status` counts whispers sent and, when some were refused, why: offline player, queue full, client refusal.

## See also

- [Channel](channel.md) to reach everyone at once.
- [Sharing](sharing.md) when the goal is a dataset every player ends up with.
