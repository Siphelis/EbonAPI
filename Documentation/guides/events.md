# 🚀 Events and tickers

Know when EbonAPI is ready, react to what it learns, listen to the game, and run code on a timer.

## What it does

The handle gives you three ways to run code at the right moment:

- **EbonAPI events**: what EbonAPI and the other addons announce. `READY`, `SERVER_RUN_DATA`, `SHARE_RECEIVED`, and your own.
- **WoW events**: the game's own events, such as `BAG_UPDATE`, without creating a frame yourself.
- **Tickers**: a function called every few seconds.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

local L = api:Locale({
  enUS = {
    READY = "EbonAPI %s is ready",
    ASH = "%d Soul Ashes to spend",
  },
  frFR = {
    READY = "EbonAPI %s est prêt",
    ASH = "%d Cendres d'âme à dépenser",
  },
})

api:On("READY", function(event, version)
  api:Print(string.format(L.READY, version))
end)

api:On("SERVER_ASH", function(event, ash)
  api:Print(string.format(L.ASH, ash.spendable))
end)

api:OnEvent("PLAYER_ENTERING_WORLD", function()
  api:Debug("entering world")
end)

api:Tick("heartbeat", 30, function(every)
  api:Debug("still here after " .. every .. " seconds")
end)
```

## How it works

### EbonAPI events

#### Subscribing

```lua
api:On(event, fn)
```

The callback receives the event name, then up to six values: `fn(event, a, b, c, d, e, f)`. The arguments of every event are listed in the [Events catalog](../reference/events.md).

`api:On` returns `true` when the subscription is added, and `false` when your addon has already subscribed that same function to that event. Subscribing the same function twice never fires it twice.

#### Unsubscribing

```lua
api:Off(event, fn)   -- one function
api:Off(event)       -- every function of yours for this event
api:OffAll()         -- everything your handle registered
```

`api:Off` returns `true` when it removed at least one subscription. `api:OffAll()` returns nothing: it removes your EbonAPI events, your WoW events and your tickers, and everything your addon registered through the other services of the handle.

You can unsubscribe from inside a callback. The event being delivered still reaches every function that was subscribed when it started.

#### Sticky events

A sticky event keeps its last values. When you subscribe to one that has already fired, your callback runs **at once**, inside the `api:On` call, with those values. It then runs again every time the event fires.

```lua
local L = api:Locale({
  enUS = {
    ASHES = "Soul Ashes: %d",
    RESET_COST = "Cost of the next reset: %d",
  },
  frFR = {
    ASHES = "Cendres d'âme : %d",
    RESET_COST = "Coût de la prochaine réinitialisation : %d",
  },
})

-- Somewhere after login. SERVER_RUN_DATA already fired: this prints right away.
api:On("SERVER_RUN_DATA", function(event, run)
  api:Print(string.format(L.ASHES, run.soulPoints))
end)

-- Read without subscribing.
local run = api:LastValue("SERVER_RUN_DATA")

if run then
  api:Print(string.format(L.RESET_COST, run.costNextReset))
end
```

`api:LastValue(event)` returns the values of the last time the event fired, or `nil` when nothing is kept, including when the event is not sticky.

Sticky events: `READY`, `LANGUAGE_CHANGED`, `CHANNEL_JOINED`, `SERVER_RUN_DATA`, `SERVER_INTENSITY`, `SERVER_ASH`, `SERVER_MULTIPLIER`, `SERVER_BUILDS`, `SERVER_BUILD_ACTIVE`, `SERVER_LOADOUT`.

!!! warning
    Because the replay happens inside `api:On`, your callback may run before the line after `api:On` executes. Make sure everything the callback uses exists before you subscribe.

You can make one of your own events sticky. Do it once, before the event first fires:

```lua
EbonAPI:DeclareSticky("MYADDON_ROUTE")
```

`EbonAPI:ClearSticky("MYADDON_ROUTE")` forgets the kept values, so a new subscriber gets nothing until the event fires again. `EbonAPI:ClearSticky()` forgets them for every event.

#### Emitting your own events

```lua
api:Emit("MYADDON_ROUTE_SAVED", routeId, routeName)
```

`api:Emit` reaches **every** subscriber of that name, in every addon. It returns the number of callbacks that were subscribed when you emitted, or `0` when nobody listens. Up to six values travel with the event.

Prefix your event names with your addon name in capitals. Two addons emitting `ROUTE_SAVED` would hear each other.

A callback subscribed while the event is being delivered is not part of that delivery. If the event is sticky, it still runs once, at once, inside `api:On`, with the new values.

#### Errors in callbacks

An error in a callback is reported through the game's error display and recorded in the trace as an `error` under your addon name. The other callbacks still run, and the addon that emitted the event never sees the error. A broken addon cannot stop the others from hearing an event.

#### Features

`api:HasFeature(name)` returns `true` when a ProjectEbonhold service was detected, and `false` for any other name. `FEATURE_CHANGED(name, available)` fires when that changes. See [ProjectEbonhold](ebonhold.md).

### WoW events

```lua
api:OnEvent(event, fn)
api:OffEvent(event, fn)
```

These are the game's events: `PLAYER_ENTERING_WORLD`, `BAG_UPDATE`, `CHAT_MSG_SYSTEM`, any name the game knows. You do not need a frame of your own to hear them.

The callback receives the event's arguments **without** the event name:

```lua
api:OnEvent("CHAT_MSG_SYSTEM", function(message)
  api:Debug("system: " .. message)
end)

api:OnEvent("UNIT_HEALTH", function(unit)
  if unit == "player" then
    api:Debug("health changed")
  end
end)
```

`api:OnEvent` returns `true` when the function is added, and `false` when that function is already registered for that event. `api:OffEvent(event, fn)` needs both arguments and returns `true` when it removed something.

An event that already fired is not replayed. A callback you register after `PLAYER_LOGIN` never hears it: use the `READY` event instead.

### Tickers

```lua
api:Tick(id, every, fn)
api:Untick(id)
```

`fn(every)` runs about every `every` seconds. The first call comes after one full interval.

- `id` is a text that belongs to your addon: `"poll"` in MyAddon and `"poll"` in another addon are two different tickers.
- Calling `api:Tick` again with the same id replaces the interval and the function.
- `every` is a number of seconds, greater than zero.
- A ticker runs at most once per screen refresh.
- An error inside `fn` is reported through the game's error display, recorded in the trace as an `error` under your addon name, and the ticker keeps running.
- `api:Untick(id)` returns `true` when the ticker existed. Removing a ticker from inside its own callback is safe.

```lua
local L = api:Locale({
  enUS = { DONE = "ten seconds elapsed" },
  frFR = { DONE = "dix secondes se sont écoulées" },
})

local seconds = 0

api:Tick("countdown", 1, function(every)
  seconds = seconds + every

  if seconds >= 10 then
    api:Untick("countdown")
    api:Print(L.DONE)
  end
end)
```

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:On(event, fn)` | event name, function | `true`, or `false` if already subscribed | event is not a string, fn is not a function |
| `api:Off(event, fn?)` | event name, optional function | `true` if something was removed | |
| `api:OffAll()` | | | |
| `api:Emit(event, a?, b?, c?, d?, e?, f?)` | event name, up to six values | number of callbacks served | |
| `api:LastValue(event)` | event name | the kept values, or `nil` | |
| `api:HasFeature(name)` | feature name | `true` or `false` | |
| `api:IsReady()` | | `true` after `READY` | |
| `api:OnEvent(event, fn)` | WoW event name, function | `true`, or `false` if already registered | event is not a string, fn is not a function |
| `api:OffEvent(event, fn)` | WoW event name, function | `true` if something was removed | |
| `api:Tick(id, every, fn)` | id, seconds, function | `true` | `id` is not a string, fn is not a function, `every` is not a number above zero |
| `api:Untick(id)` | id | `true` if the ticker existed | |
| `EbonAPI:DeclareSticky(event)` | event name | | |
| `EbonAPI:ClearSticky(event?)` | event name, or nothing for all | | |

The messages raised, exactly:

| Method | Message |
| --- | --- |
| `api:On` | `EbonAPI: the event name must be a string, got <type>` |
| `api:On` | `EbonAPI: the callback for '<event>' must be a function, got <type>` |
| `api:OnEvent` | `EbonAPI.Bus.on expects an event name, got <type>` |
| `api:OnEvent` | `EbonAPI.Bus.on expects a function for '<event>', got <type>` |
| `api:Tick` | `EbonAPI:Tick expects a ticker id, got <type>` |
| `api:Tick` | `EbonAPI:Tick expects a function for '<id>', got <type>` |
| `api:Tick` | `EbonAPI:Tick: invalid interval for '<id>', expected a number above 0, got <value>` |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `READY` | version | yes | once EbonAPI's services are enabled after `PLAYER_LOGIN`; a later subscriber gets it at once |
| `ADDON_CONNECTED` | name | no | the first time an addon name is connected with `EbonAPI:NewAddon` |
| `FEATURE_CHANGED` | name, available | no | a ProjectEbonhold service is checked for the first time (`available` can already be `false`), or its availability changes |

## Limits

| | Value |
| --- | --- |
| Values carried by an event | 6, after the event name |
| Tickers: first call | after one full interval |
| Tickers: calls | at most one per screen refresh |

!!! tip "🎮 Try it"
    In the EbonAPI window, **Diagnostics → Debug messages** turns your `api:Debug` lines on: choose your addon under **Addon**, then switch on **For the chosen addon**, or switch on **All addons**. The lines from the examples above then show in chat.

## See also

- [Concepts: events](../concepts.md#events) for the two event systems side by side.
- [Events catalog](../reference/events.md) for every event and its arguments.
- [Logging](logging.md) for `api:Debug`.
