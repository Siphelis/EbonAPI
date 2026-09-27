# Events catalog

Every event EbonAPI emits. Subscribe with `api:On(event, fn)`; the callback receives the event name first, then the arguments listed here. A sticky event replays its last value to any later subscriber.

## Lifecycle

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `READY` | version | yes | EbonAPI's services are enabled, after `PLAYER_LOGIN` |
| `LANGUAGE_CHANGED` | code | yes | the shared language changed |
| `FEATURE_CHANGED` | name, available | no | a ProjectEbonhold probe changed its result |

## Server

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `SERVER_RUN_DATA` | run | yes | run data was received |
| `SERVER_INTENSITY` | intensity | yes | intensity was received |
| `SERVER_ASH` | ash | yes | the Soul Ashes amounts changed |
| `SERVER_MULTIPLIER` | number | yes | the multiplier was received |
| `SERVER_BUILDS` | builds | yes | the build list was received |
| `SERVER_BUILD_ACTIVE` | slot, builds | yes | the active build changed |
| `SERVER_LOADOUT` | loadout | yes | the loadouts were received |
| `SERVER_MESSAGE` | opcode, body, sender | no | any complete server message, parsed or not |
| `STREAM_TIMEOUT` | opcode, id, received, total | no | a multi-part server message did not complete within 20 seconds |

The fields of `run`, `intensity`, `ash`, `builds` and `loadout` are described in the [Server guide](../guides/server.md#parsed-events).

## Channel and whispers

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `CHANNEL_JOINED` | channel index | yes | the shared channel is joined |
| `CHANNEL_LOST` | | no | the client dropped the channel; a rejoin starts |
| `PEER_OFFLINE` | player name, lines dropped | no | a whispered player was reported as not found |
| `SEND_FAILED` | kind, a, b | no | the client refused a line; `kind` is `"server"`, `"channel"` or `"whisper"`, followed by the payload, or the prefix and target for a whisper |

## Sharing

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `SHARE_RECEIVED` | addon, name, state, sender | no | a dataset arrived from another player, for any addon |
| `SHARE_KEY_CHANGED` | addon, name, state or `nil` | no | a key changed on this player, by a call or by a fetch |

## Versions

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `UPDATE_AVAILABLE` | addon name, latest, own, url | no | a newer release of an addon this player runs was seen |

## Echo profile

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `PROFILE_SLOTS` | sender, class, slots | no | a player announced the layout of their build slots |
| `PROFILE_BUILD` | sender, class, slot, hash, echoes | no | a player announced one build |
| `PROFILE_BANS` | sender, class, hash, lists | no | a player announced their ban lists |

## Your own events

`api:Emit(name, ...)` reaches every addon. Prefix the name with your addon name in capitals, and declare it sticky with `EbonAPI:DeclareSticky(name)` if late subscribers should get the last value.
