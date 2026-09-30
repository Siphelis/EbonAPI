# 🔌 Connecting your addon

Tell EbonAPI who your addon is when you get your handle: its icon, its project page, and whether to watch for updates. EbonAPI shows them on your card in its window, on your minimap button, on your notifications and in update notices.

## What it does

- `EbonAPI:NewAddon` takes a fourth argument: the **connection options** `icon`, `url`, `updates` and `version`.
- Your addon gets a **card** under **Connected addons** in the EbonAPI window: icon, name, version, the `## Notes` and `## Author` lines of your `.toc`, a newer version when one was seen, and buttons to your settings and your project page.
- Your icon is the default icon of your minimap button and of your notifications.
- `api:OpenLink` opens a link in the player's browser when the Ebonhold client can, or copies it otherwise.
- `ADDON_CONNECTED` tells every addon that another one got its handle.

## Quick example

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0, {
  icon = "INV_Misc_Map_01",
  url = "https://github.com/you/MyAddon/releases/latest",
  updates = true,
})
```

This gives MyAddon an icon and a **Project page** button on its card, and lets EbonAPI tell players about new versions. `updates = true` reads the version from the `## Version` line of your `.toc`.

## How it works

`EbonAPI:NewAddon(name, major, minor, options?)` returns your handle. It is the object you call every service on, `api` in these pages.

- `name` is the name of your addon's folder. It has 1 to 32 letters, digits or `_`.
- `major` and `minor` are the lowest EbonAPI version your addon accepts. When EbonAPI is older, `NewAddon` returns `nil` and the player sees a chat line such as `[EbonAPI] EbonAPI 1.0.0 is too old for MyAddon, which needs 1.2.`. Leave both out to accept the current version.
- `options` is the table of connection options below. It is optional, and so is each option.
- Calling `NewAddon` again with the same name, from any file of your addon, gives back the same handle. A later call with options sets the ones it gives and keeps the others.

### Connection options

| Option | Kind | Effect |
| --- | --- | --- |
| `icon` | text | the icon of your addon: a name from `Interface\Icons`, such as `"INV_Misc_Map_01"`, or a full texture path |
| `url` | text | the page of your project, where players download it |
| `updates` | boolean | `true` declares your version for update notices, as `api:Version` does |
| `version` | text | the version declared with `updates`; without it, EbonAPI reads the `## Version` line of your `.toc` |

- `icon` is used as given: a name without `\` or `/` is looked for in `Interface\Icons`, anything else is a path. EbonAPI does not check that the file exists.
- `updates = true` needs a version in the form `major.minor.patch` with an optional `-N` suffix, such as `1.2.0` or `1.2.0-3`. The [Versions](versions.md) guide explains the notice.
- An unknown option, a value of the wrong kind or an empty text is a contract error. See [Errors](../reference/errors.md#handle-and-events).

!!! note
    The card reads `## Version`, `## Notes` and `## Author` from the `.toc` of the addon whose folder has the name you gave to `NewAddon`. Give `NewAddon` the name of your addon's folder.

### Your card

**Esc → EbonAPI → Connected addons** shows one card per addon that got a handle, sorted by name. Before any addon connects, the page says `No addon uses EbonAPI yet.`

| Part | Comes from |
| --- | --- |
| Title | your icon, your addon name and the `## Version` of your `.toc` |
| Text | the `## Notes` line, then `By` and the `## Author` line |
| `Version 1.3.0 available.` | shown when a newer version of your addon was seen |
| **Settings** | shown when you registered options with `api:Options`; opens your tab |
| **Project page** | shown when you gave a `url` and the client can open or copy a link; becomes **Download version 1.3.0** when a newer version was seen |
| **Minimap button** | shown when your addon has a minimap button: where it appears, lock, reset. See [Minimap button](minimap.md) |

When the client can neither open nor copy a link, there is no button and the card shows the link as text.

### Links

```lua
local function openProject()
  local method = api:OpenLink(api:Link())

  if not method then
    api:Print(api:Link())
  end
end
```

`api:OpenLink(url)` opens the link in the player's browser when the Ebonhold client can, and copies it to the clipboard otherwise. It returns `"open"`, `"copy"`, or `nil` when the client can do neither. `api:LinkMethod()` tells you which one applies before you offer a button, and `api:LinkTip()` returns the sentence that explains it to the player, in their language:

| Method | `api:LinkTip()`, in English |
| --- | --- |
| `"open"` | `Opens this link in your browser.` |
| `"copy"` | `Copies this link: paste it into your browser.` |
| `nil` | `nil` |

The feature `openLink` is present when the client can open or copy, once EbonAPI has checked the client at login: `api:HasFeature("openLink")`.

`api:Version(text, url)` keeps its `url` as your link too. Without `url`, the notice uses the one given to `NewAddon`.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `EbonAPI:NewAddon(name, major, minor, options?)` | addon name, lowest EbonAPI version, connection options | the handle, or `nil` when EbonAPI is too old | the name or an option is invalid |
| `api:Link()` | | your `url`, or `nil` | |
| `api:Icon()` | | the path of your icon, or `nil` | |
| `api:OpenLink(url)` | link | `"open"`, `"copy"` or `nil` | url is not a non-empty string |
| `api:LinkMethod()` | | `"open"`, `"copy"` or `nil` | |
| `api:LinkTip()` | | a sentence in the player's language, or `nil` | |
| `EbonAPI:AddonLink(name)` | addon name | that addon's `url`, or `nil` | |
| `EbonAPI:AddonIcon(name)` | addon name | the path of that addon's icon, or `nil` | |
| `EbonAPI:AddonNames()` | | sorted list of the addons that got a handle | |
| `EbonAPI:OpenLink(url)`, `EbonAPI:LinkMethod()`, `EbonAPI:LinkTip()` | | the same, for code that belongs to no addon | url is not a non-empty string |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `ADDON_CONNECTED` | addon name | no | an addon got its handle for the first time |

`ADDON_CONNECTED` is not replayed to addons that subscribe later (it is not sticky): the addons connected before you subscribed are in `EbonAPI:AddonNames()`.

## Limits

| | Value |
| --- | --- |
| Addon name | 1 to 32 letters, digits or `_` |
| Options | `icon`, `url`, `updates`, `version` |
| Version text | `major.minor.patch`, with an optional `-N` suffix (N = digits), 20 characters |

!!! tip "🎮 Try it"
    **Esc → EbonAPI → Connected addons** shows your card. Hover **Project page** to read the tooltip given by `api:LinkTip()`.

## See also

- [Versions](versions.md) for the update notice.
- [Minimap button](minimap.md), which shows your icon.
- [Options window](../reference/options-window.md) for the pages of the EbonAPI window.
