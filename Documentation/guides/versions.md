# 🆕 Versions

Tell players that a newer version of your addon is out, from what the other players are running.

## What it does

- You declare your version and a download link.
- EbonAPI exchanges versions between players once per session.
- A player who runs an older version than one seen on the channel gets one chat line per session, with your link, and your addon gets `UPDATE_AVAILABLE`.

Nothing is downloaded. Players are told, and decide.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

api:Version(GetAddOnMetadata("MyAddon", "Version"), "https://github.com/you/MyAddon/releases/latest")

api:On("UPDATE_AVAILABLE", function(event, name, latest, own, url)
  if name == "MyAddon" then
    MyAddon:ShowUpdateBadge(latest)
  end
end)
```

Read the version from your `.toc` with `GetAddOnMetadata`: one number to maintain, no drift between the file and the code.

## How it works

**Format.** `major.minor.patch`, such as `1.2.0`. A suffix `-build`, such as `1.2.0-3`, marks a development build: it is compared like the others but never announced as the latest, so players are never told to update to a build that is not released.

**Exchange.** At the first login of a session, EbonAPI announces the versions of every addon that declared one, on the channel. Every player compares:

- a newer release than theirs is remembered, and the notice shows once for that version;
- an older version than theirs makes them answer once, after a few seconds, so the other player learns.

A session starts again after 10 minutes away.

**The notice.** One line in the player's language: `[MyAddon] version 1.3.0 is available (installed: 1.2.0). https://...`. It shows once per session for a given version. `api:AvailableUpdate()` returns the newer version and your own while one is known, or `nil`.

**Memory.** The newest version seen is saved. When the player updates, the record is cleared at the next login.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:Version(text, url?)` | version text, optional link | `true`, or `false` when the text is not a version | |
| `api:AvailableUpdate()` | | `latest, own`, or `nil` | |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `UPDATE_AVAILABLE` | addon name, latest, own, url | no | a newer release of an addon this player runs was seen |

## Limits

| | Value |
| --- | --- |
| Version text | 20 characters |
| Notice | once per session and per version |

!!! tip "🎮 Try it"
    The versions line of `/eapi status` lists every declared addon with its version, and `(1.3.0 available)` when a newer one was seen.

## See also

- [Cookbook: update notice](../cookbook/update-notice.md) for a badge that follows `UPDATE_AVAILABLE`.
