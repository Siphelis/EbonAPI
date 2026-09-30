# 📊 Performance

Measure how much memory and CPU your addon uses, and which of its frames run code at every screen refresh, from the EbonAPI window or from your code.

## What it does

- In the EbonAPI window, **Diagnostics → Performance → Measure** shows the memory and running frames of every addon that uses EbonAPI, and of EbonAPI itself.
- With your addon chosen under **Addon**, it details yours: memory now and since a reset, the `OnUpdate` frames running at this moment, CPU per tracked frame and function.
- `api:Perf` prints its report in chat and returns its lines. The last 20 reports of each addon are kept in the saved data.

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

A report has these lines, in this order:

1. **Memory**: `memory 512 KB (whole UI: 20480 KB)`. The first figure is what the game counts for your addon, the second is the Lua memory of the whole interface. When the client cannot tell, the line reads `memory: not available on this client`.
2. **Since reset**: `+12 KB since reset, 340 s ago`. It appears only after **Reset counters** has been used.
3. **Running frames**: `OnUpdate running now: 2 -- Events, Bars`, or `OnUpdate running now: none`.
4. **CPU**: see below.

**Running frames** are the frames you registered with `api:Track` that are visible and have an `OnUpdate` script at this moment. Register every frame of yours that uses `OnUpdate`, under a name you will recognize in the report.

**CPU** needs the game's profiler. Without it the last line reads `CPU: profiler off -- /console scriptProfile 1, then /reload`. With it, the report shows the CPU your addon used since the last reset, in milliseconds, per second and as a share of all addons: `CPU 12.3 ms over 60 s = 0.205 ms/s, 4.5% of all addons`. Below it comes one line per registered frame and function that used some CPU, most expensive first, named as you registered it, with its milliseconds and number of calls.

**Reset counters** notes the current memory as the new baseline and starts the CPU counters again.

**Free memory** asks Lua to clean up the whole interface now, and shows the memory before and after: `MyAddon: memory 512 KB -> 498 KB after a full collection (14 KB was garbage)`. The difference is memory your addon no longer used but still held. With **All addons** there is one such line per addon, each starting with its name.

## In the window

| Control, under Diagnostics → Performance | Effect |
| --- | --- |
| **Addon**: All addons, then **Measure** | one line per addon: `MyAddon: 512 KB, 2 frame(s) running` |
| **Addon**: MyAddon, then **Measure** | the full report, saved without a label |
| **Reset counters** | new baseline for memory and CPU |
| **Free memory** | full collection, memory before and after, one line per addon starting with its name |

The text under **Result** is the reading taken when you pressed the button. Press **Measure** again for a fresh one.

To save a report under a label, call `api:Perf(label)` from your code.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:Track(name, frame)` | label, frame | `true`, or `false` if frame is not a table | |
| `api:TrackFunction(name, fn)` | label, function | `true`, or `false` if fn is not a function | |
| `api:Perf(label?)` | optional label | the lines of the report, after printing them | label is not a string or a number |

`api:Perf` prints a title line, `performance report` or `performance report "after import"` with your label, then the lines of the report.

## Events

Performance emits no event.

## Limits

| | Value |
| --- | --- |
| Reports kept per addon | 20, the oldest removed first |

!!! tip "🎮 Try it"
    Under **Diagnostics → Performance**, choose **All addons** and press **Measure** right after login, then again after ten minutes of play to compare the memory of each addon. Then choose your addon under **Addon** and press **Measure** to read its report.

## See also

- [Logging](logging.md) for the trace, the other diagnostic players can send you.
