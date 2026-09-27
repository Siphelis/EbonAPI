# 🚀 Getting started

Ten minutes from an empty folder to an addon that talks to EbonAPI.

## What you need

- World of Warcraft 3.3.5a with the Ebonhold client (ProjectEbonhold).
- EbonAPI 1.0.0 or newer in `Interface/AddOns/EbonAPI`, enabled in the addon list.
- An editor. There is no build step and no library to copy: the game loads EbonAPI before your addon.

## 1. Declare the dependency

In your `.toc`, ask the game to load EbonAPI first:

```text title="MyAddon.toc"
## Interface: 30300
## Title: MyAddon
## Notes: My first Ebonhold addon
## Version: 1.0.0
## Dependencies: EbonAPI

MyAddon.lua
```

With `## Dependencies`, the game loads EbonAPI before your files and disables your addon when EbonAPI is missing. That is what you want for an Ebonhold addon.

!!! note
    There is no `## SavedVariables` line. EbonAPI saves your data for you, inside its own saved variable. See [Storage](guides/storage.md).

If your addon must also run without EbonAPI, declare `## OptionalDeps: EbonAPI` instead and guard every access with `if EbonAPI then`.

## 2. Get your handle

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
```

`NewAddon` takes your addon name and the lowest EbonAPI version you accept, as `major, minor`. It returns a **handle**: the object that carries every service. Keep it in a local or in your addon table, and use it everywhere.

- The name is 1 to 32 characters: letters, digits and `_` only. It becomes your identity everywhere: the chat tag `[MyAddon]`, your saved data bucket, your channel messages, your share keys.
- Calling `NewAddon` twice with the same name returns the same handle. Any file of your addon can call it.
- When the installed EbonAPI is older than what you ask for, the player sees a message in their language and `NewAddon` returns `nil`. Guard for it:

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

if not api then
  return -- EbonAPI is too old for us; the player has been told
end
```

!!! warning
    A name that breaks the rules is a bug in your code, not a runtime condition: `NewAddon` raises an error instead of returning `nil`. See [Errors](reference/errors.md).

## 3. Wait for READY

EbonAPI finishes its own start-up at `PLAYER_LOGIN`: it binds the character's saved data, detects ProjectEbonhold and enables its network services. Then it emits `READY` with its version.

```lua
api:On("READY", function(event, version)
  api:Print("Connected to EbonAPI " .. version)
end)
```

`READY` is a **sticky** event: if you subscribe after it fired, your callback runs immediately with the same value. You never miss it, whatever your load order.

Everything you register can be done before `READY`: subscribing to events, registering translations, declaring your version, opening your saved data. Sending is for after `READY`: the channel is joined once the services are up, and `api:Say` returns `false` until then.

## 4. React to the server

Every Ebonhold server message that EbonAPI understands becomes an event. Run data, for example:

```lua
api:On("SERVER_RUN_DATA", function(event, run)
  api:Print("Soul Ashes: " .. run.soulPoints .. " / " .. run.soulPointsMax)
end)
```

`SERVER_RUN_DATA` is sticky too: a late subscriber gets the last run data right away. The full list of server events and their fields is in [Server](guides/server.md).

## 5. The whole addon

`MyAddon.lua`, complete:

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

if not api then
  return
end

api:On("READY", function(event, version)
  api:Print("Connected to EbonAPI " .. version)
end)

api:On("SERVER_RUN_DATA", function(event, run)
  api:Print("Soul Ashes: " .. run.soulPoints .. " / " .. run.soulPointsMax)
end)
```

!!! tip "🎮 Try it"
    Log in, then type `/eapi status`. The consumers line lists `MyAddon`: your handle is registered. `/eapi trace 10` shows the last messages EbonAPI received from the server.

## Where next

- [Concepts](concepts.md): the handle, the lifecycle, events, names and errors, in twenty minutes.
- [Storage](guides/storage.md): `api:DB()` gives you account and character data with defaults.
- [Localization](guides/localization.md): `api:Locale()` gives your addon the language the player chose.
- [Cookbook: minimal addon](cookbook/minimal-addon.md): the same addon with storage, translations and a slash command.
