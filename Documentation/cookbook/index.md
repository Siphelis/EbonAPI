# Cookbook

Complete addons, small enough to read in one go and ready to paste. Each recipe was run against EbonAPI's test client before it was published.

| Recipe | Shows |
| --- | --- |
| [Minimal addon](minimal-addon.md) | the handle, saved data with defaults, translations, a version, a slash command |
| [Run tracker](run-tracker.md) | server events, the server state, snapshots, number formatting |
| [Shared dataset](shared-dataset.md) | publishing a dataset, a state, a rule, reacting to what arrives |
| [Localized window](localized-window.md) | a frame whose labels follow the language, with buttons to change it |
| [Update notice](update-notice.md) | declaring a version from the `.toc`, reacting to `UPDATE_AVAILABLE` |

Every recipe starts the same way:

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

if not api then
  return
end
```

and needs this line in the `.toc`:

```text
## Dependencies: EbonAPI
```
