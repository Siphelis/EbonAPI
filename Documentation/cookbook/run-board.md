# Run board

A window with two tabs. **Run** shows the Soul Ashes, rerolls and freezes of the current run as bars. **Builds** lists the Echo builds in a table the player can sort, with the active one marked. Everything updates by itself when the server sends new values.

```lua title="RunBoard.lua"
local api = EbonAPI:NewAddon("RunBoard", 1, 0, { icon = "INV_Misc_Book_09" })

if not api then
  return
end

local State = api:State()
local Format = EbonAPI.Format

local L = api:Locale({
  enUS = {
    TITLE = "Run board", RUN = "Run", BUILDS = "Builds", WAITING = "Waiting for the server...",
    ASHES = "Soul Ashes %s", REROLLS = "Rerolls left %s", FREEZES = "Freezes left %s", SPENDABLE = "Spendable: %s",
    SLOT = "Slot", NAME = "Name", ECHOES = "Echoes", ACTIVE = "Active",
  },
  frFR = {
    TITLE = "Tableau de run", RUN = "Run", BUILDS = "Builds", WAITING = "En attente du serveur...",
    ASHES = "Cendres d'âme %s", REROLLS = "Relances restantes %s", FREEZES = "Gels restants %s", SPENDABLE = "Disponibles : %s",
    SLOT = "Emplacement", NAME = "Nom", ECHOES = "Échos", ACTIVE = "Actif",
  },
})

local function run()
  return State.GetRun() or {}
end

local function bar(page, key, current, total)
  return page:Add("progress", {
    width = 320,
    value = function()
      return run()[current] or 0
    end,
    max = function()
      return math.max(run()[total] or 0, 1)
    end,
    text = function()
      return string.format(L[key], Format.pair(run()[current] or 0, run()[total] or 0))
    end,
  })
end

local win = api:Window("main", { key = "TITLE" })
local tabs = win:Add("tabs")
local runPage = tabs:AddTab("run", { key = "RUN" })
local buildPage = tabs:AddTab("builds", { key = "BUILDS" })

runPage:Add("status", {
  key = "WAITING",
  hidden = function()
    return State.GetRun() ~= nil
  end,
})

bar(runPage, "ASHES", "soulPoints", "soulPointsMax")
bar(runPage, "REROLLS", "remainingRerolls", "totalRerolls")
bar(runPage, "FREEZES", "remainingFreezes", "totalFreezes")

runPage:Add("text", {
  text = function()
    local ash = State.GetAsh()

    return ash and string.format(L.SPENDABLE, Format.number(ash.spendable)) or ""
  end,
})

buildPage:Add("table", {
  columns = {
    { id = "slot", key = "SLOT", width = 80, align = "CENTER" },
    { id = "name", key = "NAME" },
    { id = "echoes", key = "ECHOES", width = 70, align = "RIGHT" },
    { id = "active", key = "ACTIVE", width = 60, align = "CENTER", sort = false },
  },
  rows = function()
    local rows = {}
    local _, activeSlot = State.activeBuild()

    for _, build in ipairs(State.sortedBuilds() or {}) do
      rows[#rows + 1] = {
        slot = build.slot,
        name = build.name,
        echoes = #State.BuildEchoes(build),
        active = build.slot == activeSlot and "*" or "",
      }
    end

    return rows
  end,
})

local function refresh()
  win:Refresh()
end

api:On("SERVER_RUN_DATA", refresh)
api:On("SERVER_ASH", refresh)
api:On("SERVER_BUILDS", refresh)
api:On("SERVER_BUILD_ACTIVE", refresh)

api:MinimapButton({
  tip = function(lines)
    lines:Add(string.format(L.ASHES, Format.pair(run().soulPoints or 0, run().soulPointsMax or 0)))
  end,
  onClick = function()
    win:Toggle()
  end,
})
```

## What happens

1. `tabs:AddTab` returns a page, a container like the window itself: the elements go into the page, not into the window.
2. Every value is a function that reads `api:State()`, the latest values received from the server. Nothing is copied: each time the elements are redrawn, they read them again.
3. The four server events call `win:Refresh()`, which redraws every element of the window, in both tabs. They are sticky: a sticky event remembers its last value and hands it to anyone who subscribes later. So `refresh` also runs once as soon as it subscribes, with the values already received, and the window is filled even when the player logs in during a run.
4. The events are subscribed **after** the elements exist, since a sticky event may call `refresh` inside `api:On`.
5. The status line hides itself once run data has arrived, through its `hidden` function.
6. A click on a column header sorts the builds by that column; **Active** keeps `sort = false`, sorting by a star would mean nothing.
7. The minimap button opens and closes the window, and its tooltip shows the ashes without opening it.

!!! tip "🎮 Try it"
    Click the minimap button, then open **Builds** and click **Echoes** twice: the builds sort by their number of echoes, then in the other order. Change your active build in the game: the star moves at once.
