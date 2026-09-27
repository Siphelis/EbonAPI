# 📊 Performance

Measure your addon's memory, CPU and running frames, from the same command players use to report a slow client.

## What it does

- `/eapi perf` shows the memory and running frames of every addon that uses EbonAPI.
- `/eapi perf MyAddon` details yours: memory now and since a reset, the `OnUpdate` frames running at this moment, CPU per tracked frame and function.
- Reports are printed, and the last 20 are kept in the saved data for reading later.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

local frame = CreateFrame("Frame")
api:Track("Events", frame)                 -- shows up when its OnUpdate runs

local function Refresh()
  -- ...
end

api:TrackFunction("Refresh", Refresh)      -- CPU per call, when profiling is on

api:Perf("after import")                   -- prints and saves a report
```

## How it works

**Memory** comes from the game's own per-addon accounting. `/eapi perf MyAddon reset` records a baseline; the next report shows the difference since then.

**Running frames** are the tracked frames whose `OnUpdate` script is set and that are visible right now. Track every frame that runs an `OnUpdate`, with a name you will recognize.

**CPU** needs the game's profiler: `/console scriptProfile 1`, then `/reload`. The report then shows the CPU of your addon over the window since the last reset, its share of all addons, and one line per tracked frame and function, most expensive first.

**Garbage** `/eapi perf MyAddon gc` forces a full collection and prints the memory before and after: the difference is what your addon had left for the collector.

## Commands

| Command | Effect |
| --- | --- |
| `/eapi perf` | one line per addon: memory, frames running |
| `/eapi perf MyAddon` | the full report |
| `/eapi perf MyAddon <label>` | the full report, saved under that label |
| `/eapi perf MyAddon reset` | new baseline for memory and CPU |
| `/eapi perf MyAddon gc` | full collection, memory before and after |

## API

| Method | Arguments | Returns |
| --- | --- | --- |
| `api:Track(name, frame)` | label, frame | `true`, or `false` if frame is not a table |
| `api:TrackFunction(name, fn)` | label, function | `true`, or `false` if fn is not a function |
| `api:Perf(label?)` | optional label | the lines of the report, after printing them |

## Limits

| | Value |
| --- | --- |
| Reports kept per addon | 20 |

!!! tip "🎮 Try it"
    `/eapi perf` right after login, then again after ten minutes of play: the memory of an addon that leaks keeps growing between the two.

## See also

- [Logging](logging.md) for the trace, the other diagnostic players can send you.
