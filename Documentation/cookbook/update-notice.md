# Update notice

Declare the version written in the `.toc`, and give players a command that tells them where they stand.

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

if not api then
  return
end

local RELEASES = "https://github.com/you/MyAddon/releases/latest"

api:Version(GetAddOnMetadata("MyAddon", "Version"), RELEASES)

local pending = nil

api:On("UPDATE_AVAILABLE", function(event, name, latest, own, url)
  if name == "MyAddon" then
    pending = latest          -- EbonAPI printed the notice; remember it for your own interface
  end
end)

SLASH_MYADDONUPDATE1 = "/myaddonupdate"

SlashCmdList["MYADDONUPDATE"] = function()
  local latest, own = api:AvailableUpdate()

  if latest then
    api:Print("Version " .. latest .. " is out, you run " .. own .. ": " .. RELEASES)
  else
    api:Print("You run the latest version known")
  end
end
```

## What happens

1. `GetAddOnMetadata("MyAddon", "Version")` reads the `## Version:` line of the `.toc`. One number to maintain.
2. At the first login of a session, EbonAPI announces the versions of every addon that declared one. A player who runs an older version than one seen gets one chat line, with the link.
3. `UPDATE_AVAILABLE` fires at the same moment. The recipe only remembers the version; a real addon would light a badge or change a title.
4. `api:AvailableUpdate()` answers at any time, for a command or a tooltip.
5. A development build such as `1.1.0-2` in the `.toc` is never announced as the latest: players on `1.0.0` are not told to update to it.

!!! tip "🎮 Try it"
    The versions line of `/eapi status` shows `MyAddon 1.0.0 (1.1.0 available)` once a newer release was seen on the channel.
