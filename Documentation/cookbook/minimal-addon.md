# Minimal addon

An addon with saved data, translations, a version and a slash command, in one file.

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
    HELP = "/myaddon show | reset",
  },
  frFR = {
    LOCALE_NAME = "Français",
    READY = "prêt, EbonAPI %s",
    LOGINS = "connexions sur ce personnage : %d",
    ASHES = "Cendres d'âme : %s",
    RESET = "compteur remis à zéro",
    HELP = "/myaddon show | reset",
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

SLASH_MYADDON1 = "/myaddon"

SlashCmdList["MYADDON"] = function(input)
  local command = string.lower(string.match(input or "", "^%s*(%S*)"))

  if command == "show" then
    api:Print(string.format(L.LOGINS, db.char.logins))
  elseif command == "reset" then
    db.char.logins = 0
    api:Success(L.RESET)
  else
    api:Print(L.HELP)
  end
end
```

## What happens

1. `NewAddon` returns the handle, or `nil` when EbonAPI is older than 1.0. The file stops there in that case; the player was told.
2. `api:Locale` registers two languages and returns `L`. A player in German sees English, without changing the language of the other addons.
3. `api:DB` opens the store. `db.account.announce` exists right away; `db.char.logins` from `READY` on.
4. `api:Version` declares the version written in the `.toc`, so it is never out of step with the file.
5. At `READY`, the character's counter grows and two lines print, in the player's language.
6. `SERVER_RUN_DATA` prints the ashes as debug output, visible after `/eapi debug MyAddon on`.
7. `/myaddon show` and `/myaddon reset` read and reset the counter.

!!! tip "🎮 Try it"
    `/eapi db` shows `MyAddon  account=1 keys  characters=1`. `/eapi lang frFR` then `/myaddon show` prints the French line.
