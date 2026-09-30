# Cookbook

Complete addons, small enough to read in one go and ready to paste. Each one is followed by what happens, line by line. None of them needs a slash command: what the player does goes through windows, the minimap button and the EbonAPI window.

| Recipe | Shows |
| --- | --- |
| [Minimal addon](minimal-addon.md) | the handle, saved data with defaults, translations, a version, a minimap button that shows a summary |
| [Run tracker](run-tracker.md) | server events, the server state, snapshots, number formatting, a summary window opened by the minimap button |
| [Shared dataset](shared-dataset.md) | publishing a dataset, a state, a rule, reacting to what arrives |
| [Localized window](localized-window.md) | a frame opened by the minimap button, whose labels follow the language, with buttons to change it |
| [Update notice](update-notice.md) | declaring a version from the `.toc`, reacting to `UPDATE_AVAILABLE`, a minimap button that shows the release link |
| [Addon window](addon-window.md) | a Kit window, a list with menus, a prompt, a notification, a minimap button with a badge |
| [Settings page](settings-page.md) | every setting in the EbonAPI window with `api:Options`, names in the player's language, a reset with confirmation |
| [Run board](run-board.md) | a Kit window with tabs, progress bars and a sortable table, refreshed by the server events |

Every recipe starts the same way, with its own addon name (some add your icon as a fourth argument):

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

if not api then
  return
end
```

Each one needs this line in its `.toc`:

```text
## Dependencies: EbonAPI
```
