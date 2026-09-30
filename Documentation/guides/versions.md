# 🆕 Versions

Tell players that a newer version of your addon is out. EbonAPI learns it from the other players who run your addon.

## What it does

- You declare your version and a download link, with `api:Version` or with the `updates` and `url` options of `NewAddon`.
- When EbonAPI learns that another player runs a newer release of your addon, the player gets one chat line per session, with your link, and your addon gets `UPDATE_AVAILABLE`.
- The newer version also shows on your card in the EbonAPI window, on your minimap button and in the **Updates** count of the window's footer, when the skin has one.

EbonAPI never downloads or installs anything. It tells the player, and the player decides.

## Quick example

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
local L = api:Locale({
  enUS = { UPDATE_BADGE = "New version: %s" },
  frFR = { UPDATE_BADGE = "Nouvelle version : %s" },
})

api:Version(GetAddOnMetadata("MyAddon", "Version"), "https://github.com/you/MyAddon/releases/latest")

local latest = api:AvailableUpdate()
if latest then
  api:Print(string.format(L.UPDATE_BADGE, latest))
end

api:On("UPDATE_AVAILABLE", function(event, name, latest, own, url)
  if name == "MyAddon" then
    api:Print(string.format(L.UPDATE_BADGE, latest))
  end
end)
```

Read the version from your `.toc` with `GetAddOnMetadata`: one number to maintain, and the code can never disagree with the file.

## How it works

### Two ways to declare it

In one call, when you get your handle. The version comes from the `## Version` line of your `.toc`:

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0, {
  url = "https://github.com/you/MyAddon/releases/latest",
  updates = true,
})
```

Or in two calls, which gives the same result:

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

api:Version(GetAddOnMetadata("MyAddon", "Version"), "https://github.com/you/MyAddon/releases/latest")
```

Both declare your version for the notices and keep the link, which also shows on your card in the EbonAPI window. If you call both, the last call wins.

They differ on a bad version text. With `updates = true`, `NewAddon` raises an error, because the mistake is in your code or your `.toc`. `api:Version` returns `false` instead, which suits a version you build at run time.

### Format

A version is `major.minor.patch`, such as `1.2.0`: three whole numbers separated by dots, 20 characters at most. A suffix made of a dash and a whole number, such as `1.2.0-3`, marks a development build. Other suffixes such as `-beta` are not versions. It is compared like the others but never announced as the latest, so players are never told to update to a build that is not released.

### The notice

The notice is one line in the player's language: `[MyAddon] version 1.3.0 is available (installed: 1.2.0). https://...`. The link is left out when you gave none. It shows once per session for a given version. A session starts again after 10 minutes away.

`api:AvailableUpdate()` returns the newer version and your own while one is known, or `nil`.

`UPDATE_AVAILABLE` is sent when the notice is shown, so not again for a version already announced in the current session, for example after a reload. Call `api:AvailableUpdate()` when you draw your badge, and use the event to refresh it.

### What is remembered

The newest release seen is saved for the account, so the notice comes back at the next session even if no one with that version is online. Once the player has updated, it is cleared at the next login.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:Version(text, url?)` | version text, optional link | `true`, or `false` when the text is not a version | |
| `api:AvailableUpdate()` | | `latest, own`, or `nil` | |

`api:Version` also keeps `url` as your addon's link. Without `url`, the notice uses the link given to `NewAddon`. See [Two ways to declare it](#two-ways-to-declare-it) and [Connecting your addon](connection.md).

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `UPDATE_AVAILABLE` | addon name, latest, own, url | no | a newer release of an addon this player runs is known, once per session and per version; `url` is `nil` when you gave none |

## Limits

| | Value |
| --- | --- |
| Version text | `major.minor.patch` or `major.minor.patch-N` (N = digits), 20 characters |
| Notice | once per session and per version |
| Session | starts again after 10 minutes away |

!!! tip "🎮 Try it"
    **Esc → EbonAPI → Diagnostics → Reports → Status**: the `versions:` line lists every declared addon with its version, and `(1.3.0 available)` when a newer one was seen. **Connected addons** shows the newer version on your card.

## See also

- [Connecting your addon](connection.md) for the `updates` and `url` options and your card.
- [Cookbook: update notice](../cookbook/update-notice.md) for a badge that follows `UPDATE_AVAILABLE`.
