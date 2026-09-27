# Handle

Every method of the handle returned by `EbonAPI:NewAddon`, grouped by service, followed by the global functions. Each group links to its guide.

## Getting the handle

| Function | Returns |
| --- | --- |
| `EbonAPI:NewAddon(name, major?, minor?)` | the handle for `name`, or `nil` when EbonAPI is older than `major.minor`. Same name, same handle. Raises for an invalid name. |
| `api:GetName()` | the addon name |
| `api:IsReady()` | `true` after `READY` |

## Lifecycle and events

Guide: [Events and tickers](../guides/events.md).

| Method | Returns |
| --- | --- |
| `api:On(event, fn)` | `true`, or `false` if already subscribed |
| `api:Off(event, fn?)` | `true` if something was removed; without `fn`, removes all of yours for that event |
| `api:OffAll()` | removes everything the handle registered, in every service |
| `api:Emit(event, a?, b?, c?, d?, e?)` | number of callbacks served, across all addons |
| `api:LastValue(event)` | the held values of a sticky event, or `nil` |
| `api:HasFeature(name)` | `true` when the ProjectEbonhold feature is present |
| `api:OnEvent(event, fn)` | WoW event; `true`, or `false` if already registered |
| `api:OffEvent(event, fn)` | `true` if something was removed |
| `api:Tick(id, every, fn)` | `true`; replaces an existing ticker with the same id |
| `api:Untick(id)` | `true` if the ticker existed |

## Logging

Guide: [Logging](../guides/logging.md).

| Method | Returns |
| --- | --- |
| `api:Print(...)` | |
| `api:Success(...)` | |
| `api:Warn(...)` | |
| `api:Error(...)` | |
| `api:Debug(...)` | |
| `api:SetDebug(enabled)` | the new state |
| `api:IsDebug()` | `true` when debug is on for this addon or for all |

## Storage

Guide: [Storage](../guides/storage.md).

| Method | Returns |
| --- | --- |
| `api:DB(defaults?)` | the store: `db.account`, `db.char`, `db:CharacterKeys()`, `db:CharacterAt(key)`, `db:ResetCharacter()`, `db:MigrateOnce(key, legacy, fn)`, `db:MigrateOncePerCharacter(key, legacy, fn)`, `db:IsMigrated(key, perCharacter?)` |

## Localization

Guide: [Localization](../guides/localization.md).

| Method | Returns |
| --- | --- |
| `api:Locale(translations)` | the live `L` table |
| `api:L()` | the same table |
| `api:Localized(widget, key)` | the widget, its text bound to the key |
| `api:GetLanguage()` | the active language code |
| `api:IsLanguageChosen()` | `true` when the player chose a language explicitly |

## Server

Guide: [Server](../guides/server.md).

| Method | Returns |
| --- | --- |
| `api:OnServer(opcode, fn)` | `true`, or `false` if already registered |
| `api:OffServer(opcode, fn)` | `true` if something was removed |
| `api:SendServer(opcode, body?)` | `true` when queued |
| `api:RequestServer(opcode, body, minInterval)` | `true` when queued, `false` when throttled |
| `api:State()` | the server state module |

## ProjectEbonhold

Guide: [ProjectEbonhold](../guides/ebonhold.md).

| Method | Returns |
| --- | --- |
| `api:Ebonhold()` | the ProjectEbonhold access module |

## Channel

Guide: [Channel](../guides/channel.md).

| Method | Returns |
| --- | --- |
| `api:OnChannel(op, fn)` | `true`, or `false` if already registered |
| `api:OffChannel(op, fn)` | `true` if something was removed |
| `api:Say(op, body?)` | `true` when queued, `false` when not joined or no room |
| `api:IsChannelJoined()` | `true` while joined |

## Whispers

Guide: [Whispers](../guides/whispers.md).

| Method | Returns |
| --- | --- |
| `api:OnWhisper(prefix, fn)` | `true`, or `false` if already registered |
| `api:OffWhisper(prefix, fn)` | `true` if something was removed |
| `api:Whisper(prefix, target, text)` | `true` when queued, `false` when refused |
| `api:WhisperAll(prefix, target, parts, count?)` | `true` when every line is queued |
| `api:OnWhisperStream(prefix, op, fn, onPart?)` | `true`, or `false` if already registered |
| `api:OffWhisperStream(prefix, op, fn, onPart?)` | `true` if something was removed |
| `api:WhisperStream(prefix, target, op, id, body)` | `true` when queued, `false` when refused or too long |

## Sharing

Guide: [Sharing](../guides/sharing.md).

| Method | Returns |
| --- | --- |
| `api:Share(name, state, text)` | `true` when something changed |
| `api:Unshare(name)` | `true` if it existed |
| `api:GetShared(name, addon?)` | `text, state`, or `nil` |
| `api:SharedNames(addon?)` | sorted list of dataset names |
| `api:ShareRule(fn)` | `true` |
| `api:SyncShares()` | `true` when announced |
| `api:SetShareKey(name, state)` | `true` when changed |
| `api:RemoveShareKey(name)` | `true` if it existed |
| `api:GetShareKey(name, addon?)` | the state, or `nil` |

## Versions

Guide: [Versions](../guides/versions.md).

| Method | Returns |
| --- | --- |
| `api:Version(text, url?)` | `true`, or `false` for a text that is not a version |
| `api:AvailableUpdate()` | `latest, own`, or `nil` |

## Echo profile

Guide: [Echo profile](../guides/echo-profile.md).

| Method | Returns |
| --- | --- |
| `api:SetProfileBans(lists)` | `true` when everything pending is queued |

## Performance

Guide: [Performance](../guides/performance.md).

| Method | Returns |
| --- | --- |
| `api:Track(name, frame)` | `true`, or `false` if frame is not a table |
| `api:TrackFunction(name, fn)` | `true`, or `false` if fn is not a function |
| `api:Perf(label?)` | the lines of the report |

## Global functions

Calls that belong to no addon.

| Function | Returns |
| --- | --- |
| `EbonAPI:GetVersion()` | `"1.0.0", 1, 0, 0`: the text, then major, minor, patch |
| `EbonAPI:IsReady()` | `true` after `READY` |
| `EbonAPI:AddonNames()` | sorted list of the registered addon names |
| `EbonAPI:On(event, fn)`, `EbonAPI:Off(event, fn?)` | like the handle's, owned by EbonAPI itself; prefer the handle |
| `EbonAPI:Emit(event, ...)` | like `api:Emit` |
| `EbonAPI:LastValue(event)` | like `api:LastValue` |
| `EbonAPI:DeclareSticky(event)` | makes an event sticky |
| `EbonAPI:ClearSticky(event?)` | forgets the held value of one event, or of all |
| `EbonAPI:RegisterFeature(name, available)` | sets a feature flag; emits `FEATURE_CHANGED` when it changes |
| `EbonAPI:HasFeature(name)` | `true` or `false` |
| `EbonAPI:Features()` | a copy of the feature table |
| `EbonAPI:SetLanguage(code, persist?)` | `true`, or `false` for an unknown code |
| `EbonAPI:GetLanguage()` | the active language code |
| `EbonAPI:GetAvailableLanguages()` | list of `{ code, name }`, sorted by name |
| `EbonAPI:IsLanguageChosen()` | `true` when the player chose a language explicitly |

Constants: `EbonAPI.version` (`"1.0.0"`), `EbonAPI.MAJOR`, `EbonAPI.MINOR`, `EbonAPI.PATCH`, `EbonAPI.NAME_MAX` (32).
