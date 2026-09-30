# Minimal addon

An addon with saved data, translations, a version and a minimap button, in one file.

## Files

```text title="MyAddon.toc"
## Interface: 30300
## Title: MyAddon
## Notes: Counts logins per character
## Version: 1.0.0
## Dependencies: EbonAPI

MyAddon.lua
```

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

if not api then
  return
end

local L = api:Locale({
  enUS = {
    LOCALE_NAME = "English",
    READY = "ready, EbonAPI %s",
    LOGINS = "logins on this character: %d",
    ASHES = "Soul Ashes: %s",
    RESET = "counter reset",
    RESET_MENU = "Reset the counter",
    BUTTON_TIP = "Click: show the login counter. Right-click: reset it.",
  },
  frFR = {
    LOCALE_NAME = "Français",
    READY = "prêt, EbonAPI %s",
    LOGINS = "connexions sur ce personnage : %d",
    ASHES = "Cendres d'âme : %s",
    RESET = "compteur remis à zéro",
    RESET_MENU = "Remettre le compteur à zéro",
    BUTTON_TIP = "Clic : afficher le compteur de connexions. Clic droit : le remettre à zéro.",
  },
})

local db = api:DB({
  account = { announce = true },
  character = { logins = 0 },
})

api:Version(GetAddOnMetadata("MyAddon", "Version"), "https://github.com/you/MyAddon/releases/latest")

api:On("READY", function(event, version)
  db.char.logins = db.char.logins + 1

  if db.account.announce then
    api:Print(string.format(L.READY, version))
    api:Print(string.format(L.LOGINS, db.char.logins))
  end
end)

api:On("SERVER_RUN_DATA", function(event, run)
  api:Debug(string.format(L.ASHES, EbonAPI.Format.pair(run.soulPoints, run.soulPointsMax)))
end)

api:MinimapButton({
  tipKey = "BUTTON_TIP",
  onClick = function()
    api:Print(string.format(L.LOGINS, db.char.logins))
  end,
  menu = {
    {
      key = "RESET_MENU",
      onClick = function()
        db.char.logins = 0
        api:Success(L.RESET)
      end,
    },
  },
})
```

## What happens

1. `NewAddon` returns the handle, or `nil` when EbonAPI is older than 1.0. The file stops there in that case; the player was told.
2. `api:Locale` registers two languages and returns `L`. A player in German sees English, without changing the language of the other addons.
3. `api:DB` opens the store. `db.account.announce` exists right away; `db.char.logins` from `READY` on.
4. `api:Version` declares the version written in the `.toc`, so it is never out of step with the file.
5. At `READY`, the character's counter grows and two lines print, in the player's language.
6. `SERVER_RUN_DATA` prints the ashes as debug output, visible once you turn on **Diagnostics → Debug messages → For the chosen addon** with **Addon** set to MyAddon (or **All addons**) in the EbonAPI window.
7. `api:MinimapButton` puts a button around the minimap. A left-click prints the counter. A right-click opens a menu with one entry, which resets the counter. The tooltip shows your addon's name and version, then the text of `BUTTON_TIP`.

!!! tip "🎮 Try it"
    Left-click the MyAddon button on the minimap: the counter prints. Right-click it and choose **Reset the counter**. In the EbonAPI window, **Diagnostics → Reports → Saved data** shows `MyAddon  account=1 keys  characters=1`. Choose French under **General → Language**: the tooltip and the menu entry change language.
