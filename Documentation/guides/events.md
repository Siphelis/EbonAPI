# 🚀 Events and tickers

Know when EbonAPI is ready, react to what it learns, listen to the game client, and run code on a timer.

## What it does

The handle gives you three timing tools:

- **EbonAPI events**: what EbonAPI and the other addons announce. `READY`, `SERVER_RUN_DATA`, `SHARE_RECEIVED`, and your own.
- **WoW events**: the game client's events, registered on a frame EbonAPI manages for you.
- **Tickers**: a function called every few seconds, on one shared `OnUpdate`.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

api:On("READY", function(event, version)
  api:Print("EbonAPI " .. version .. " is ready")
end)

api:On("SERVER_ASH", function(event, ash)
  api:Print(ash.spendable .. " Soul Ashes to spend")
end)

api:OnEvent("PLAYER_ENTERING_WORLD", function()
  api:Debug("entering world")
end)

api:Tick("heartbeat", 30, function(every)
  api:Debug("still here after " .. every .. " seconds")
end)
```

## EbonAPI events

### Subscribing

```lua
api:On(event, fn)
```

The callback receives the event name, then up to five values: `fn(event, a, b, c, d, e)`. The arguments of every event are listed in the [Events catalog](../reference/events.md).

`api:On` returns `true`, or `false` when that exact function is already subscribed to that event. Subscribing the same function twice never fires it twice.

### Unsubscribing

```lua
api:Off(event, fn)   -- one function
api:Off(event)       -- every function of yours for this event
api:OffAll()         -- everything the handle registered, in every service
```

Each returns `true` when something was removed. Unsubscribing during a dispatch is safe: the dispatch in progress finishes with the list it started with.

### Sticky events

A sticky event keeps its last value. When you subscribe to one, your callback runs **immediately** with that value, inside the `api:On` call, and again at every later emission.

```lua
-- Somewhere after login. SERVER_RUN_DATA already fired: this prints right away.
api:On("SERVER_RUN_DATA", function(event, run)
  api:Print("Soul Ashes: " .. run.soulPoints)
end)

-- Read without subscribing.
local run = api:LastValue("SERVER_RUN_DATA")

if run then
  api:Print("Cost of the next reset: " .. run.costNextReset)
end
```

Sticky events: `READY`, `LANGUAGE_CHANGED`, `CHANNEL_JOINED`, `SERVER_RUN_DATA`, `SERVER_INTENSITY`, `SERVER_ASH`, `SERVER_MULTIPLIER`, `SERVER_BUILDS`, `SERVER_BUILD_ACTIVE`, `SERVER_LOADOUT`.

!!! warning
    Because the replay happens inside `api:On`, your callback may run before the line after `api:On` executes. Make sure everything the callback uses exists before you subscribe.

You can make one of your own events sticky, once, before the first emission:

```lua
EbonAPI:DeclareSticky("MYADDON_ROUTE")
```

`EbonAPI:ClearSticky("MYADDON_ROUTE")` forgets the held value; the next subscriber gets nothing until the next emission.

### Emitting your own events

```lua
api:Emit("MYADDON_ROUTE_SAVED", routeId, routeName)
```

`api:Emit` reaches **every** subscriber of that name, in every addon. It returns the number of callbacks served. Up to five values travel with the event.

Prefix your event names with your addon name in capitals. Two addons emitting `ROUTE_SAVED` would hear each other.

### Errors in callbacks

An error inside a callback is reported through the game's error handler and recorded in the trace. The other callbacks of the same event still run, and the emitter never sees the error. This protects every addon from a broken listener in another one.

### Features

`api:HasFeature(name)` tells you whether a ProjectEbonhold service was detected. `FEATURE_CHANGED(name, available)` fires when that changes. See [ProjectEbonhold](ebonhold.md).

## WoW events

```lua
api:OnEvent(event, fn)
api:OffEvent(event, fn)
```

These are the game client's events: `PLAYER_ENTERING_WORLD`, `BAG_UPDATE`, `CHAT_MSG_SYSTEM`, any name the client knows. EbonAPI registers the event on its own frame when the first listener appears and unregisters it when the last one leaves.

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

`api:OnEvent` returns `false` when the same function is already registered for that event. `api:OffEvent` returns `true` when it removed something.

## Tickers

```lua
api:Tick(id, every, fn)
api:Untick(id)
```

`fn(every)` runs every `every` seconds, on one `OnUpdate` frame shared by every addon. The frame only runs while at least one ticker exists.

- `id` is any string. It is yours: `"poll"` in MyAddon never clashes with `"poll"` in another addon.
- Calling `api:Tick` again with the same id replaces the interval and the function, without restarting the countdown.
- `every` must be greater than zero. Anything that is not a number counts as one second.
- An error inside `fn` is reported and the ticker keeps running.
- `api:Untick(id)` returns `true` when the ticker existed. Removing a ticker from inside its own callback is safe.

```lua
local seconds = 0

api:Tick("countdown", 1, function(every)
  seconds = seconds + every

  if seconds >= 10 then
    api:Untick("countdown")
    api:Print("ten seconds elapsed")
  end
end)
```

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:On(event, fn)` | event name, function | `true`, or `false` if already subscribed | event is not a string, fn is not a function |
| `api:Off(event, fn?)` | event name, optional function | `true` if something was removed | |
| `api:OffAll()` | | | |
| `api:Emit(event, a?, b?, c?, d?, e?)` | event name, up to five values | number of callbacks served | |
| `api:LastValue(event)` | event name | the held values, or `nil` | |
| `api:HasFeature(name)` | feature name | `true` or `false` | |
| `api:IsReady()` | | `true` after `READY` | |
| `api:OnEvent(event, fn)` | WoW event name, function | `true`, or `false` if already registered | event is not a string, fn is not a function |
| `api:OffEvent(event, fn)` | WoW event name, function | `true` if something was removed | |
| `api:Tick(id, every, fn)` | id, seconds, function | `true` | id is not a string, fn is not a function, interval is zero or negative |
| `api:Untick(id)` | id | `true` if the ticker existed | |
| `EbonAPI:DeclareSticky(event)` | event name | | |
| `EbonAPI:ClearSticky(event?)` | event name, or nothing for all | | |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `READY` | version | yes | once EbonAPI's services are enabled after `PLAYER_LOGIN` |
| `FEATURE_CHANGED` | name, available | no | a ProjectEbonhold service appeared or disappeared |

!!! tip "🎮 Try it"
    `/eapi debug MyAddon on` turns your `api:Debug` lines on. `/eapi trace 20 error` lists the last errors raised inside callbacks, yours included.

## See also

- [Concepts: events](../concepts.md#events) for the two event systems side by side.
- [Events catalog](../reference/events.md) for every event and its arguments.
