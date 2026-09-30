# Run tracker

Follow the Soul Ashes of the current run, keep the best per character, and show a summary in a window that a minimap button opens.

```lua title="RunTracker.lua"
local api = EbonAPI:NewAddon("RunTracker", 1, 0)

if not api then
  return
end

local Format = EbonAPI.Format
local State = api:State()

local L = api:Locale({
  enUS = {
    LOCALE_NAME = "English",
    TITLE = "Run summary",
    GAINED = "gained %s Soul Ashes",
    NEW_BEST = "New best: %s Soul Ashes",
    BEST = "Best on this character: %s",
    ASHES = "Soul Ashes: %s",
    LEFT = "Rerolls left: %d, freezes left: %d, next reset: %s",
    CAP = "Level cap reached",
    NO_DATA = "No run data yet",
    BUTTON_TIP = "Click: open or close the run summary.",
  },
  frFR = {
    LOCALE_NAME = "Français",
    TITLE = "Résumé de la run",
    GAINED = "%s Cendres d'âme gagnées",
    NEW_BEST = "Nouveau record : %s Cendres d'âme",
    BEST = "Record de ce personnage : %s",
    ASHES = "Cendres d'âme : %s",
    LEFT = "Relances restantes : %d, gels restants : %d, prochaine remise à zéro : %s",
    CAP = "Niveau maximum atteint",
    NO_DATA = "Pas encore de données de run",
    BUTTON_TIP = "Clic : ouvrir ou fermer le résumé de la run.",
  },
})

local db = api:DB({
  character = { best = 0 },
})

local win = nil

local function build()
  win = api:Window("summary", { key = "TITLE", minWidth = 280 })

  win:Add("text", {
    text = function()
      return string.format(L.BEST, Format.number(db.char.best))
    end,
  })

  win:Add("text", {
    text = function() return L.NO_DATA end,
    hidden = function() return State.GetRun() ~= nil end,
  })

  win:Add("text", {
    text = function()
      local run = State.GetRun()
      return run and string.format(L.ASHES, Format.pair(run.soulPoints, run.soulPointsMax)) or ""
    end,
    hidden = function() return State.GetRun() == nil end,
  })

  win:Add("text", {
    text = function()
      local run = State.GetRun()

      if not run then
        return ""
      end

      return string.format(L.LEFT, run.remainingRerolls, run.remainingFreezes, Format.number(run.costNextReset))
    end,
    hidden = function() return State.GetRun() == nil end,
  })

  win:Add("text", {
    text = function() return L.CAP end,
    hidden = function()
      local run = State.GetRun()
      return not (run and run.hasReachedMaxLevel)
    end,
  })
end

api:On("READY", build)

local previous = nil

api:On("SERVER_RUN_DATA", function(event, run)
  if previous and run.soulPoints > previous.soulPoints then
    api:Debug(string.format(L.GAINED, Format.number(run.soulPoints - previous.soulPoints)))
  end

  previous = State.snapshot("run")

  if run.soulPoints > db.char.best then
    db.char.best = run.soulPoints
    api:Success(string.format(L.NEW_BEST, Format.number(run.soulPoints)))
  end

  if win then
    win:Refresh()
  end
end)

api:MinimapButton({
  tipKey = "BUTTON_TIP",
  onClick = function()
    if win then
      win:Toggle()
    end
  end,
})
```

## What happens

1. `SERVER_RUN_DATA` fires at every run update from the server. It is sticky (a sticky event keeps its last value and gives it at once to a handler added later): if your addon subscribes after a run message has already arrived, your handler is called at once with the last data.
2. The run table is updated in place by EbonAPI. `State.snapshot("run")` keeps a copy of the previous message, which lets the next one be compared to it.
3. `db.char.best` lives in the character scope: each character keeps its own record.
4. At `READY`, your character's saved data is available, so `api:Window` creates the summary window there. The window starts hidden: the minimap button opens it with `win:Toggle()`. Each line is a `text` element whose text is a function: EbonAPI calls it again at every refresh, and the handler refreshes the window after each run message. A `hidden` function hides the line while it returns `true` and shows it while it returns `false`.
5. The summary reads the current run through `State.GetRun()`, which also works before any message when ProjectEbonhold publishes run data itself. Until there is run data, the window says so.
6. `Format.number` groups thousands (1 234 567); `Format.pair` prints `current / maximum`, shortening values from 10 000 up (12.3k, 1.20M).
7. The minimap button opens and closes the window. The window title, the lines and the tooltip follow the player's language.

!!! tip "🎮 Try it"
    Click the RunTracker button on the minimap: the summary window opens, with your best and the run lines once the server has sent data. In the EbonAPI window, **Diagnostics → Reports → Trace**, with **Trace filter** set to `recv`, shows the `PLAYER_RUN_DATA` messages as they arrive, with their size. **Debug messages → For the chosen addon** with **Addon** set to RunTracker shows the gains between two messages.
