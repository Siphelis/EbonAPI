# Errors

Every message EbonAPI can raise, what raised it, and how to fix the call.

A raised error means a **contract error**: the calling code passed something EbonAPI cannot accept. It is a bug to fix, not a condition to handle. Runtime conditions never raise; they come back as `false` or `nil`, and as events. See [Concepts: errors and messages](../concepts.md#errors-and-messages).

Errors surface where a developer looks: with `/console scriptErrors 1`, or with an error-display addon. Players with default settings never see them. Every message is in English.

## Handle and events

| Message | Fix |
| --- | --- |
| `EbonAPI:NewAddon expects a non-empty addon name, got nil` | pass your addon name as a string |
| `EbonAPI:NewAddon: addon name "My Addon" must be 1 to 32 letters, digits or "_"` | remove spaces and punctuation, shorten the name |
| `EbonAPI: the event name must be a string, got number` | pass the event name as a string |
| `EbonAPI: the callback for 'READY' must be a function, got nil` | pass a function; check that it is defined before `api:On` |

## WoW events and tickers

| Message | Fix |
| --- | --- |
| `EbonAPI.Bus.on expects an event name, got nil` | pass the WoW event name as a string |
| `EbonAPI.Bus.on expects a function for 'BAG_UPDATE', got table` | pass a function |
| `EbonAPI.Bus.tick expects a ticker id, got number` | pass the id as a string |
| `EbonAPI.Bus.tick expects a function for 'poll', got nil` | pass a function |
| `EbonAPI.Bus.tick: invalid interval for 'poll'` | the interval must be greater than zero |

## Storage

| Message | Fix |
| --- | --- |
| `EbonAPI: the defaults of 'MyAddon' must be a table, got string` | pass `{ account = {...}, character = {...} }` |
| `EbonAPI: the migration key must be a string, got number` | name the migration with a string |
| `EbonAPI: migration 'import' expects a function, got nil` | pass the migration function as the third argument |

`migration 'import' failed: ...` is not raised: it is reported through `api:Error` when the migration function itself raised, and the migration stays pending.

## Localization

| Message | Fix |
| --- | --- |
| `EbonAPI: the translations of 'MyAddon' must be a table, got string` | pass a table keyed by language code |
| `EbonAPI: Localized expects a translation key, got nil` | pass the key as a string |
| `EbonAPI: Localized expects a widget with SetText for the key 'TITLE'` | pass a font string, button or edit box, not a frame |

## Server

| Message | Fix |
| --- | --- |
| `EbonAPI.Bridge.on expects a numeric opcode, got string` | use `EbonAPI.SS.NAME`, a number |
| `EbonAPI.Bridge.on expects a function for opcode 13, got nil` | pass a function |
| `EbonAPI.Bridge.send expects a numeric opcode, got string` | use `EbonAPI.CS.NAME`, a number |
| `EbonAPI.Bridge.send: payload of 260 bytes for opcode 341, the limit is 240` | shorten the body |

## Channel

| Message | Fix |
| --- | --- |
| `EbonAPI.Channel.on expects an alphanumeric op for MyAddon, got my-op` | letters and digits only |
| `EbonAPI.Channel.on expects a function for MyAddon:ROUTE, got nil` | pass a function |
| `EbonAPI.Channel.say expects a text body for MyAddon:ROUTE, got table` | encode the body as a string |
| `EbonAPI.Channel.say: the body of MyAddon:ROUTE contains '|'` | remove or encode the `|` character |
| `EbonAPI.Channel.say: op too long for MyAddon:...` | shorten the op |
| `EbonAPI.Channel.say: body of 4000 characters for MyAddon:ROUTE, the limit is 3648` | split the content, or use a whisper stream |

## Whispers

| Message | Fix |
| --- | --- |
| `EbonAPI.Channel.whisper expects a prefix, got nil` | pass your prefix as a non-empty string |
| `EbonAPI.Channel.whisper: text missing or beyond 246 bytes for prefix MyAddonW` | shorten the text, or use a stream |
| `EbonAPI.Whisper.on expects a prefix, got nil` | pass your prefix |
| `EbonAPI.Whisper.on expects a function for MyAddonW, got nil` | pass a function |
| `EbonAPI.Whisper.onStream expects an alphanumeric op, got my-op` | letters and digits only |
| `EbonAPI.Whisper.onStream expects a function for MyAddonW:ROUTE, got nil` | pass a function |
| `EbonAPI.Whisper.stream expects a text body for MyAddonW:ROUTE, got table` | encode the body as a string |
| `EbonAPI.Whisper.stream: invalid stream id for MyAddonW:ROUTE` | the id is a non-empty string without `:`, or `nil` |
| `EbonAPI.Whisper.stream: header too long for MyAddonW:ROUTE` | shorten the prefix, the op or the id |

## Sharing

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: share key name must be a string, got number` | pass the dataset name as a string |
| `EbonAPI: MyAddon: share key name is empty` | give it a name |
| `EbonAPI: MyAddon: share key "my notes" contains a space (allowed: letters, digits and "_")` | remove the character named in the message |
| `EbonAPI: MyAddon: share key "..." is 40 characters long (maximum 32)` | shorten the name |
| `EbonAPI: MyAddon: share key "notes": state must be a whole number, got table` | pass a number or a string of digits |
| `EbonAPI: MyAddon: share key "notes": state 1.5 is not a whole number (0 to 9007199254740991)` | pass a whole number in range |
| `EbonAPI: MyAddon: share "notes": text must be a string, got table` | encode the content as a string |
| `EbonAPI: MyAddon: share "notes": text is 40000 bytes long (maximum 32768)` | shorten or split the content |
| `EbonAPI: MyAddon: ShareRule expects a function or nil, got string` | pass a function, or `nil` to remove the rule |

## Echo profile

| Message | Fix |
| --- | --- |
| `EbonAPI.Profile.SetBans expects a table of lists, got string` | pass a list of lists of spell ids |

## Messages to the player

These are not errors. They are printed in the player's language, through EbonAPI's own translations.

| Situation | English text |
| --- | --- |
| `NewAddon` asked for a newer EbonAPI | `EbonAPI 1.0.0 is too old for MyAddon, which needs 1.2.` |
| A newer release of an addon was seen | `version 1.3.0 is available (installed: 1.2.0).` followed by the link |
| The channel could not be joined after several requests | `channel ebonapi not joined after 3 requests: the client may have no channel slot left; still trying` |
