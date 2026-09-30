# Events catalog

Every event EbonAPI emits. Subscribe with `api:On(event, fn)`: the callback receives the event name first, then the arguments listed here, up to six. A sticky event keeps its last value: a function that subscribes later gets it at once. Each group links to its guide.

## Lifecycle

Guide: [Events and tickers](../guides/events.md).

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `READY` | version | yes | after the player logs in, once EbonAPI's services are enabled |
| `LANGUAGE_CHANGED` | code | yes | the shared language changed: through `EbonAPI:SetLanguage`, because the saved choice differs from the active language, or because an addon registered the language that is wanted (the client's or the saved one). EbonAPI also emits it once when it loads, with the language in force, so `api:LastValue("LANGUAGE_CHANGED")` is never `nil`. Not fired when the active language is set again |
| `FEATURE_CHANGED` | name, available | no | a ProjectEbonhold feature appeared or disappeared. After login, EbonAPI reports each feature once, present or not |

## Connection

Guide: [Connecting your addon](../guides/connection.md).

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `ADDON_CONNECTED` | addon name | no | an addon got its handle for the first time. The addons connected earlier are in `EbonAPI:AddonNames()` |

## Interface

Guide: [Interface](../guides/interface.md).

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `PARAMETER_CHANGED` | name, value | no | the player changed an appearance parameter in the EbonAPI window, or reset the parameters: once for each parameter that had a value of the player, with the skin's value. `value` is the value the player sees: their own, else the skin's. Not fired by `api:SetParameter`, nor when the skin changes |
| `OPTIONS_CHANGED` | addon name | no | an addon registered its options with `api:Options`, or called `api:RefreshOptions` |

## Server

Guide: [Server](../guides/server.md).

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `SERVER_RUN_DATA` | run | yes | the server sent the run data (opcode 13). Each event carries its own copy: a table you keep is never changed by a later message |
| `SERVER_INTENSITY` | intensity | yes | the server sent the intensity (opcode 30). A message whose first field is not a number is ignored. Each event carries its own copy |
| `SERVER_ASH` | ash | yes | the Soul Ashes amounts changed, or were received for the first time (opcodes 15 and 3). Not fired when they did not change. Each event carries its own copy of `ash` |
| `SERVER_MULTIPLIER` | number | yes | the server sent the multiplier (opcode 14), every time. A message that is not a number is ignored |
| `SERVER_BUILDS` | builds | yes | the server sent the build list (opcode 540). An empty list is ignored and the held list stays |
| `SERVER_BUILD_ACTIVE` | slot, builds | yes | the server changed the active build (opcode 542) while a build list is held and `slot` is one of its slots. `builds` is a new table with `builds.active` updated: the table sent by `SERVER_BUILDS` is never changed. A subscriber that comes late to `SERVER_BUILDS` gets the list as it was received, and `State.GetBuilds()` holds the current one |
| `SERVER_LOADOUT` | loadout | yes | the server sent the loadouts (opcode 3), right after `SERVER_ASH` when the amounts changed |
| `SERVER_MESSAGE` | opcode, body, sender | no | any complete message from the server arrived, after the listeners of its opcode ran, whether EbonAPI parses it or not |
| `STREAM_TIMEOUT` | opcode, id, received, total | no | a multi-part server message was dropped because no new part arrived within 20 seconds. `id` is a text, `received` and `total` count parts |

The fields of `run`, `intensity`, `ash`, `builds` and `loadout` are described in the [Server guide](../guides/server.md#parsed-events).

## Channel and whispers

Guides: [Channel](../guides/channel.md) and [Whispers](../guides/whispers.md).

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `CHANNEL_JOINED` | channel index | yes | the shared channel is joined, the first time and after each loss. The held value is cleared when the channel is lost |
| `CHANNEL_LOST` | | no | the game dropped the channel. Only fired when it was joined. EbonAPI joins again |
| `PEER_OFFLINE` | player name, lines dropped | no | the game reported a player you whispered in the last 60 seconds as not found. `player name` is written as the game reports it. `lines dropped` is the number of whispers to that player that were waiting and were discarded |
| `SEND_FAILED` | kind, a, b | no | the game refused a queued line. `kind` is `"server"`, `"channel"` or `"whisper"`. `a` is the text of the line that was refused. For `"server"` it is the opcode and body together, and for `"channel"` it is one part of your message, not your `body`. For `"whisper"` it is the prefix. `b` is the target for `"whisper"`, and `nil` otherwise |

## Sharing

Guide: [Sharing](../guides/sharing.md).

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `SHARE_RECEIVED` | addon, name, state, sender | no | a dataset from another player was accepted and stored, for any addon. A state equal to yours is refused, and so is one your share rule refuses. Fired after `SHARE_KEY_CHANGED` when the key changed |
| `SHARE_KEY_CHANGED` | addon, name, state | no | a key was created, changed or removed on this player, by a call or by a dataset received from another player. `state` is `nil` when the key was removed |

## Versions

Guide: [Versions](../guides/versions.md).

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `UPDATE_AVAILABLE` | addon name, latest, own, url | no | a newer release of an addon this player runs is known, once per session and per version. A chat line with the link is printed first. `url` is `nil` when the addon gave none |

## Echo profile

Guide: [Echo profile](../guides/echo-profile.md).

| Event | Arguments | Sticky | Fires when |
| --- | --- | --- | --- |
| `PROFILE_SLOTS` | sender, class, slots | no | a player announced the layout of their build slots. `class` is 1 to 10, and `slots` is a list of slot numbers, 1 to 20 |
| `PROFILE_BUILD` | sender, class, slot, hash, echoes, locked | no | a player announced one build. `echoes` and `locked` are texts to decode with `Profile.DecodeBuild` and `Profile.DecodeLocked` (see [Modules](modules.md)). `locked` is `nil` when the announcement has none |
| `PROFILE_BANS` | sender, class, hash, lists | no | a player announced their ban lists. `lists` is a text to decode with `Profile.DecodeBans` (see [Modules](modules.md)) |

## Your own events

`api:Emit(name, ...)` reaches every addon. Prefix the name with your addon name in capitals, and declare it sticky with `EbonAPI:DeclareSticky(name)` before the first `Emit` if late subscribers should get the last value.
