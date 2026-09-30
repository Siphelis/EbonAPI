# Update notice

Declare the version written in the `.toc`, and give players a minimap button that tells them where they stand.

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

if not api then
  return
end

local RELEASES = "https://github.com/you/MyAddon/releases/latest"

local L = api:Locale({
  enUS = {
    LOCALE_NAME = "English",
    AVAILABLE = "Version %s is available",
    OUT = "Version %s is out, you run %s. Copy the link:",
    LATEST = "You run the latest version known",
    BUTTON_TIP = "Click: check for a new version.",
  },
  frFR = {
    LOCALE_NAME = "Français",
    AVAILABLE = "La version %s est disponible",
    OUT = "La version %s est sortie, vous utilisez la %s. Copiez le lien :",
    LATEST = "Vous utilisez la dernière version connue",
    BUTTON_TIP = "Clic : chercher une nouvelle version.",
  },
})

api:Version(GetAddOnMetadata("MyAddon", "Version"), RELEASES)

api:On("UPDATE_AVAILABLE", function(event, name, latest, own, url)
  if name == "MyAddon" then
    api:Notify(string.format(L.AVAILABLE, latest))
  end
end)

api:MinimapButton({
  tipKey = "BUTTON_TIP",
  onClick = function()
    local latest, own = api:AvailableUpdate()

    if latest then
      api:CopyBox(RELEASES, string.format(L.OUT, latest, own))
    else
      api:Notify(L.LATEST)
    end
  end,
})
```

## What happens

1. `GetAddOnMetadata("MyAddon", "Version")` reads the `## Version:` line of the `.toc`. One number to maintain.
2. A player who runs an older version than one EbonAPI has learned about from other players gets one chat line per session, with the link. EbonAPI prints it; the recipe has nothing to do for that.
3. `UPDATE_AVAILABLE` fires at the same moment. The recipe adds a notification at the top of the screen; your addon could light a badge or change a title instead.
4. The minimap button shows a dot on its corner while a newer version is known, and its tooltip says so. EbonAPI does that for you.
5. A click calls `api:AvailableUpdate()`, which answers at any time. When a newer version is known, `api:CopyBox` shows the link selected in a field, ready to copy with Ctrl+C. Otherwise a notification says that the player runs the latest version known.
6. A development build such as `1.1.0-2` in the `.toc` is never announced as the latest: players on `1.0.0` are not told to update to it.

!!! tip "🎮 Try it"
    The versions line of **Diagnostics → Reports → Status**, in the EbonAPI window, shows `MyAddon 1.0.0 (1.1.0 available)` once EbonAPI has learned of a newer release from another player. At that point the MyAddon button on the minimap carries a dot, and a click on it opens the link box.
