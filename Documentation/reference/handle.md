# Handle

Every method of the handle returned by `EbonAPI:NewAddon`, grouped by service, followed by the global functions. Each group links to its guide. In the tables, `?` marks an optional argument, and "Raises when" lists the cases where the call stops with an error. The error messages are in [Errors](errors.md). The words sticky, opcode, op, prefix, dataset and stream are explained in the [Glossary](glossary.md).

## Getting the handle

| Function | Returns | Raises when |
| --- | --- | --- |
| `EbonAPI:NewAddon(name, major?, minor?, options?)` | the handle for `name`. The same name always gives the same handle. Returns `nil` when EbonAPI is older than `major.minor`, and prints a chat line that says so. `major` defaults to EbonAPI's major version and `minor` to `0`. A lower `major` is accepted, and the patch number is never compared. `options`: see [Connecting your addon](../guides/connection.md) | `name` is not 1 to 32 letters, digits or `_`, `major` or `minor` is given and is not a number, or an option is invalid |
| `api:GetName()` | the addon name | never |
| `api:IsReady()` | `true` after `READY` | never |

## Lifecycle and events

Guide: [Events and tickers](../guides/events.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:On(event, fn)` | `true`, or `false` if your addon already subscribed this `fn` to this event. `fn` is called as `fn(event, a, b, c, d, e, f)`. If the event is sticky and holds a value, `fn` is called at once, inside the `On` call | `event` is not a string or `fn` is not a function |
| `api:Off(event, fn?)` | `true` if something was removed. Without `fn`, it removes all your subscriptions to that event | never |
| `api:OffAll()` | nothing. Removes everything your handle registered, in every service: events, WoW events, tickers, server, channel and whisper listeners, and your share rule | never |
| `api:Emit(event, a?, b?, c?, d?, e?, f?)` | the number of callbacks called, across all addons. An event carries up to six arguments after its name | never. An error inside a callback is reported and the next callback still runs |
| `api:LastValue(event)` | the six values held by a sticky event (the unused ones are `nil`), or `nil` when it holds nothing | never |
| `api:HasFeature(name)` | `true` when the ProjectEbonhold feature is present | never |
| `api:OnEvent(event, fn)` | `true`, or `false` if your addon already registered `fn` for this WoW event. Another addon can register the same `fn`. `fn` receives the event's arguments, without the event name. An error inside `fn` is reported and the other functions still run | `event` is not a string or `fn` is not a function |
| `api:OffEvent(event, fn)` | `true` if something was removed. It removes only your registration | never |
| `api:Tick(id, every, fn)` | `true`. A ticker with the same `id` in your addon is replaced, and its countdown restarts when `every` is different. `fn(every)` runs about every `every` seconds, starting after one full interval | `id` is not a string, `fn` is not a function, or `every` is not a number above `0` |
| `api:Untick(id)` | `true` if the ticker existed | `id` is not a string |

## Logging

Guide: [Logging](../guides/logging.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Print(...)` | nothing. Any number of values, joined with one space | never |
| `api:Success(...)` | nothing | never |
| `api:Warn(...)` | nothing. Also recorded in the Trace | never |
| `api:Error(...)` | nothing. Also recorded in the Trace, and sent to the game's error display as `[MyAddon] text` | never |
| `api:Debug(...)` | nothing. Shown only when debug is on for your addon or for all addons | never |
| `api:SetDebug(enabled)` | the same as `api:IsDebug()` returns right after the change: `true` when debug is on for your addon or for all addons | never |
| `api:IsDebug()` | `true` when debug is on for your addon or for all addons | never |

## Storage

Guide: [Storage](../guides/storage.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:DB(defaults?)` | your store, the same table on every call. `defaults` is `{ account = {...}, character = {...} }` | `defaults` is given and is not a table, or its `account` or `character` part is given and is not a table. The error comes at the call, before any store exists |

The store gives you `db.account` and `db.char`, and these methods:

| Method | Returns | Raises when |
| --- | --- | --- |
| `db:CharacterKeys()` | sorted list of the character keys (`Name-Realm`) known to your store | never |
| `db:CharacterAt(key)` | the saved table of that character, or `nil` | never |
| `db:ResetCharacter()` | `true` after emptying the current character's data and applying your defaults again. `db.char` and `db.account` stay the same tables. `false` when the character is not known yet | never |
| `db:MigrateOnce(key, legacy, fn)` | `false` when the migration was already done, when `fn` failed or when `fn` returned `nil` or `false` (it runs again next time). Otherwise `true` and the result of `fn`, which is called as `fn(db, legacy, characterName, characterKey)` | `key` is not a string or `fn` is not a function |
| `db:MigrateOncePerCharacter(key, legacy, fn)` | the same, once per character. `false` without running anything while the character is not known yet | the same as `MigrateOnce` |
| `db:IsMigrated(key, perCharacter?)` | `true` when that migration is done. Pass `true` to ask about the current character | `key` is `nil` |

## Localization

Guide: [Localization](../guides/localization.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Locale(translations)` | your live `L` table. `translations` is `{ [languageCode] = { KEY = "text" } }`. Entries that are not tables are ignored. A second call adds keys and replaces the ones that exist, and never removes any | `translations` is not a table |
| `api:L()` | the same table, or `nil` if `api:Locale` was never called | never |
| `api:Localized(widget, key)` | the widget, with its text bound to the key | `key` is not a string, or `widget` has no `SetText` method |
| `api:GetLanguage()` | the active language code | never |
| `api:IsLanguageChosen()` | `true` when the player chose a language explicitly | never |

## Interface

Guide: [Interface](../guides/interface.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Options(options)` | the same options table, drawn in the EbonAPI window. A second call replaces the first tree | `options` is not a valid options table |
| `api:RefreshOptions()` | nothing. The window redraws your options | never |
| `api:OpenOptions(key?)` | the EbonAPI window, open on your tab or on the group `key`. An unknown or hidden `key` opens your main page | your addon has no options yet |
| `api:GetParameter(name)` | the value that applies to your addon: the player's, else the one you set with `api:SetParameter`, else the skin's | `name` is not one of the eight parameters |
| `api:GetParameters()` | a new table, parameter name to value, with the same rule | never |
| `api:SetParameter(name, value)` | the value that applies after the change. The player's own value always wins, so it can differ from `value`. Pass `nil` to remove your value. `PARAMETER_CHANGED` is not emitted | `name` is unknown or `value` is not valid for it |

The eight parameters are `background`, `accent`, `scale`, `opacity`, `shadow`, `corners`, `tabs` and `locked`. Their ranges are in [Limits](limits.md#interface).

## Connection

Guide: [Connecting your addon](../guides/connection.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Link()` | the project link of your addon: the `url` option, or the `url` of your latest valid `api:Version` call, or `nil` | never |
| `api:Icon()` | the full path of your icon, built from the `icon` option, or `nil` | never |
| `api:OpenLink(url)` | `"open"` when the game opens the address, `"copy"` when it copies it, or `nil` when it can do neither, or when the game's function failed (the error is reported, not raised) | `url` is not a non-empty string |
| `api:LinkMethod()` | `"open"`, `"copy"` or `nil` | never |
| `api:LinkTip()` | the sentence that explains the method, in the player's language, or `nil` | never |

## Kit

Guide: [Kit](../guides/kit.md). Every element: [Elements](elements.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Window(id, fields?)` | the window `id` of your addon. The same `id` gives the same window, and the fields of later calls are ignored | `id` is not a string of letters, digits and `_`, `fields` is not a table, or a field is invalid, for example `scroll` is not `NONE`, `VERTICAL`, `HORIZONTAL` or `BOTH`. See [Errors](errors.md) |
| `api:Create(kind, parent?, fields?)` | a new element. Without `parent`, it is placed on the screen | `kind` or `fields` is invalid. Every field is checked before the element is built, see [Errors](errors.md) |
| `api:Elements()` | sorted list of the element kinds | never |
| `api:RefreshUI()` | nothing. Refreshes every element of your addon | never |
| `api:Dialog(fields)` | the dialog. There is one dialog at a time: opening one cancels the open one | `fields` is not a table, or a choice is not a table |
| `api:Confirm(text, onYes?, onNo?)` | the dialog, with **Yes** and **No** | never |
| `api:Prompt(text, default?, onAccept?, onCancel?)` | the dialog, with a text field that starts with `default` | never |
| `api:CopyBox(text, title?)` | the dialog, with the text in a field the player can select and copy | never |
| `api:OpenMenu(items, anchor?)` | `true`, or `false` when `items` is not a table. Without `anchor`, the menu opens at the cursor, and a menu that is already open closes first | never |
| `api:Notify(text, fields?)` | the notification | `fields` is given and is not a table |
| `api:GetShortcut(id)` | the key of a shortcut, or `nil` | never |
| `api:SetShortcut(id, key)` | `true` when saved, `false` when your saved data is not ready yet. `key` `nil` clears the shortcut | `id` is not letters, digits and `_` |
| `api:AfterCombat(fn)` | `true` when `fn` ran now, `false` when it waits for the end of combat. An error inside `fn` is reported and never reaches your call | `fn` is not a function |

## Minimap button

Guide: [Minimap button](../guides/minimap.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:MinimapButton(fields?)` | your addon's button. A second call updates the same button and returns it | `fields` is not a table, or `display` is not `BUTTON`, `GROUP` or `HIDDEN` |

## Server

Guide: [Server](../guides/server.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:OnServer(opcode, fn)` | `true`, or `false` if this `fn` is already registered for this opcode. `fn` is called as `fn(body, opcode, sender, distribution)` | `opcode` is not a number or `fn` is not a function |
| `api:OffServer(opcode, fn)` | `true` if something was removed. It removes only a listener that your addon added with `api:OnServer`. For any other listener it returns `false` and leaves it registered | never |
| `api:SendServer(opcode, body?)` | `true` when the message is queued. `body` is a string, a number or `nil` | `opcode` is not a number, the message is too long, or `body` is of another type |
| `api:RequestServer(opcode, body, minInterval)` | `false` when the same request (same opcode and body, from any addon) was accepted less than `minInterval` seconds ago. Otherwise the result of `SendServer`. A `minInterval` of `0` or less, or none, never throttles | the same as `SendServer` |
| `api:State()` | the `EbonAPI.State` object, see [Modules](modules.md) | never |

## ProjectEbonhold

Guide: [ProjectEbonhold](../guides/ebonhold.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Ebonhold()` | the `EbonAPI.Ebonhold` object, see [Modules](modules.md) | never |

## Channel

Guide: [Channel](../guides/channel.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:OnChannel(op, fn)` | `true`, or `false` if this `fn` is already registered for this `op`. `fn` is called as `fn(sender, body, addon, op)`. Registering also asks EbonAPI to join the shared channel | `op` is not letters and digits, or `fn` is not a function |
| `api:OffChannel(op, fn)` | `true` if something was removed | never |
| `api:Say(op, body?)` | `true` when queued. Otherwise `false` and a reason: `"not_joined"` when the channel is not joined yet (nothing is queued, and joining is requested), or `"full"` when the queue has no room for the message. The arguments are checked first, whatever the state of the channel | `op` is not letters and digits, `body` is not a string, contains `\|`, or is too long |
| `api:IsChannelJoined()` | `true` while EbonAPI is in the shared channel | never |

## Whispers

Guide: [Whispers](../guides/whispers.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:OnWhisper(prefix, fn)` | `true`, or `false` if this `fn` is already registered for this prefix. `fn` is called as `fn(sender, text, distribution, prefix)` | `prefix` is not a non-empty string, or `fn` is not a function |
| `api:OffWhisper(prefix, fn)` | `true` if something was removed | never |
| `api:Whisper(prefix, target, text)` | `true` when queued. `false` when `target` is not a usable name, is known to be offline, or the queue is full | `prefix` is not a non-empty string, or `text` is not a string or is too long |
| `api:WhisperAll(prefix, target, parts, count?)` | `true` when every part is queued (also when `count` is `0`). `false`, with nothing queued, when `target` is unusable or offline or the queue lacks room for all of them. `count` defaults to `#parts` | `prefix` is not a non-empty string, or a part is not a string or is too long. Every part is checked before anything is queued |
| `api:OnWhisperStream(prefix, op, fn, onPart?)` | `true`, or `false` if this `fn` is already registered for this prefix and op. `fn(sender, body, id, op)` runs when a stream is complete, and `onPart(sender, id, op)` on each part that does not complete it | `prefix` is invalid, `op` is not letters and digits, or `fn` is not a function |
| `api:OffWhisperStream(prefix, op, fn)` | `true` if something was removed. The `onPart` function registered with `fn` is removed with it | never |
| `api:WhisperStream(prefix, target, op, id, body)` | `true` when queued. `false` when `target` is unusable or offline, or the queue lacks room. `id` is `nil` (EbonAPI picks one) or a non-empty string without `:` | `prefix`, `op` or `id` is invalid, `body` is not a string, or `body` needs more than 400 parts |

## Sharing

Guide: [Sharing](../guides/sharing.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Share(name, state, text)` | `true` when the text or the state changed, `false` when both are the same as before | `name` or `state` is invalid, `text` is not a string or is over 32,768 bytes, or the `state` is the same as before and the `text` is different (raise the state to share a new text) |
| `api:Unshare(name)` | `true` if the dataset existed | never |
| `api:GetShared(name, addon?)` | `text, state`. `text` is `nil` when only a share key exists (`api:SetShareKey`). Both are `nil` when nothing is stored. The state is a string of digits. `addon` defaults to your addon | never |
| `api:SharedNames(addon?)` | sorted list of the names of your datasets and share keys. `addon` defaults to your addon | never |
| `api:ShareRule(fn)` | `true`. `fn(name, theirs, mine)` returns a true value to fetch the data of another player. `theirs` is the state they offer and `mine` your state (or `nil`), both as strings of digits. Pass `nil` to restore the default rule | `fn` is neither `nil` nor a function |
| `api:SyncShares()` | `true` when your datasets were announced. `false` within 30 seconds of the previous call, when the channel is not joined, or when the announcement could not be queued. An announcement that is too large lists as many addons as fit | never |
| `api:SetShareKey(name, state)` | `true` when the key was created or its state changed | `name` or `state` is invalid |
| `api:RemoveShareKey(name)` | `true` if the key existed | never |
| `api:GetShareKey(name, addon?)` | the state as a string of digits, or `nil` | never |

## Versions

Guide: [Versions](../guides/versions.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Version(text, url?)` | `true`, or `false` when `text` is not a version: `major.minor.patch`, optionally followed by `-` and digits, at most 20 characters. A version with the `-digits` ending is registered but not announced to other players. `url` becomes your addon's link only when `text` is a version | never |
| `api:AvailableUpdate()` | `latest, own`, or `nil` when nothing newer is known or your addon registered no version | never |

## Echo profile

Guide: [Echo profile](../guides/echo-profile.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:SetProfileBans(lists)` | `true` when the lists are kept, even when they cannot be sent yet: they go out as soon as they can. `false` when the player's class is not known yet, and nothing is kept. `lists` is a table of lists of echo ids. An id that is not a whole number in range is ignored | `lists` is not a table, or one of its elements is not a table |

## Performance

Guide: [Performance](../guides/performance.md).

| Method | Returns | Raises when |
| --- | --- | --- |
| `api:Track(name, frame)` | `true`, or `false` if `frame` is not a table. Tracking the same frame again only renames the entry | never |
| `api:TrackFunction(name, fn)` | `true`, or `false` if `fn` is not a function. Tracking the same function again only renames the entry | never |
| `api:Perf(label?)` | the lines of the report. The report is also printed in the chat and saved | never |

## Global functions

Calls that belong to no addon. They are made on `EbonAPI` itself.

| Function | Returns | Raises when |
| --- | --- | --- |
| `EbonAPI:GetVersion()` | `"2.0.0", 2, 0, 0`: the text, then major, minor, patch | never |
| `EbonAPI:IsReady()` | `true` after `READY` | never |
| `EbonAPI:AddonNames()` | sorted list of the connected addon names | never |
| `EbonAPI:On(event, fn)`, `EbonAPI:Off(event, fn?)` | like the handle's, owned by EbonAPI itself. Prefer the handle | like the handle's `On` |
| `EbonAPI:Emit(event, ...)` | like `api:Emit` | never |
| `EbonAPI:LastValue(event)` | like `api:LastValue` | never |
| `EbonAPI:DeclareSticky(event)` | nothing. Makes an event sticky. Declare it before the first `Emit` of that event | never |
| `EbonAPI:ClearSticky(event?)` | nothing. Forgets the held value of one event, or of all events | never |
| `EbonAPI:AddTeardown(fn)` | nothing. `fn(handle)` runs each time a handle calls `OffAll` | never |
| `EbonAPI:RegisterFeature(name, available)` | nothing. Sets a feature flag. Emits `FEATURE_CHANGED` when the value differs from the stored one, and on the first registration | never |
| `EbonAPI:HasFeature(name)` | `true` or `false` | never |
| `EbonAPI:Features()` | a copy of the feature table, name to `true` or `false` | never |
| `EbonAPI:SetLanguage(code, persist?)` | `true` when the code is available, including when it is already active. `false` for an unknown code. The choice is saved, also when the code is already active, unless `persist` is `false`. `esMX` becomes `esES` when no addon registers `esMX` | never |
| `EbonAPI:GetLanguage()` | the active language code | never |
| `EbonAPI:GetAvailableLanguages()` | list of `{ code, name }`, sorted by name, one entry per language code registered by any addon | never |
| `EbonAPI:IsLanguageChosen()` | `true` when the player chose a language explicitly | never |
| `EbonAPI:OpenOptions(addon?, key?)` | the EbonAPI window, open on the tab of `addon`. Without `addon`, the window opens on the page already shown | `addon` is given and has no options registered with `api:Options`, an unknown name included |
| `EbonAPI:GetParameter(name)` | the value of a parameter in the EbonAPI window: the player's, else the skin's. No addon's own value counts | `name` is not one of the eight parameters |
| `EbonAPI:AddonLink(name)` | the project link of an addon: its `url` option, or the `url` of its latest `Version` call, or `nil` | never |
| `EbonAPI:AddonIcon(name)` | the full path of an addon's icon, or `nil` | never |
| `EbonAPI:OpenLink(url)`, `EbonAPI:LinkMethod()`, `EbonAPI:LinkTip()` | like the handle's | like the handle's `OpenLink` |
| `EbonAPI:RegisterSkin(name, values)` | `true` when nothing was wrong. `false` when at least one problem was found: the skin is still registered, without the faulty entries, and each problem is reported. See [Skins](../guides/skins.md) | `name` is not a non-empty string, `values` is not a table, or the name is already registered |

Constants: `EbonAPI.version` (the `## Version` line of `EbonAPI.toc`, such as `"2.0.0"`), `EbonAPI.MAJOR`, `EbonAPI.MINOR`, `EbonAPI.PATCH`, `EbonAPI.NAME_MAX` (32).
