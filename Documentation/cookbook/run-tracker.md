# Run tracker

Follow the Soul Ashes of the current run, keep the best per character, and print a summary on demand.

```lua title="RunTracker.lua"
local api = EbonAPI:NewAddon("RunTracker", 1, 0)

if not api then
  return
end

local Format = EbonAPI.Format
local State = api:State()

local db = api:DB({
  character = { best = 0 },
})

local previous = nil

api:On("SERVER_RUN_DATA", function(event, run)
  if previous and run.soulPoints > previous.soulPoints then
    api:Debug("gained " .. Format.number(run.soulPoints - previous.soulPoints) .. " Soul Ashes")
  end

  previous = State.snapshot("run")

  if run.soulPoints > db.char.best then
    db.char.best = run.soulPoints
    api:Success("New best: " .. Format.number(run.soulPoints) .. " Soul Ashes")
  end
end)

SLASH_RUNTRACKER1 = "/runs"

SlashCmdList["RUNTRACKER"] = function()
  local run = State.GetRun()

  api:Print("Best on this character: " .. Format.number(db.char.best))

  if not run then
    api:Print("No run data yet")
    return
  end

  api:Print("Soul Ashes: " .. Format.pair(run.soulPoints, run.soulPointsMax))
  api:Print("Rerolls left: " .. run.remainingRerolls .. ", freezes left: " .. run.remainingFreezes
    .. ", next reset: " .. Format.number(run.costNextReset))

  if run.hasReachedMaxLevel then
    api:Print("Level cap reached")
  end
end
```

## What happens

1. `SERVER_RUN_DATA` fires at every run update from the server. It is sticky, so a `/reload` in the middle of a run gets the last data at once.
2. The run table is updated in place by EbonAPI. `State.snapshot("run")` keeps a copy of the previous message, which lets the next one be compared to it.
3. `db.char.best` lives in the character scope: each character keeps its own record.
4. `/runs` reads the current run through `State.GetRun()`, which also works before any message when ProjectEbonhold publishes run data itself.
5. `Format.number` groups thousands, `Format.pair` prints `current / maximum`.

!!! tip "🎮 Try it"
    `/eapi trace 20 recv` shows the `PLAYER_RUN_DATA` messages as they arrive, with their size. `/eapi debug RunTracker on` shows the gains between two messages.
