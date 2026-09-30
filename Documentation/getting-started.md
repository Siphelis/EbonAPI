# 🚀 Getting started

From an empty folder to an addon that talks to EbonAPI, in five steps.

## What you need

- World of Warcraft 3.3.5a with the Ebonhold client (ProjectEbonhold).
- EbonAPI 2.0.0 or newer in `Interface/AddOns/EbonAPI`, enabled in the addon list.
- A text editor. There is nothing to compile and no library to copy into your addon: the game loads EbonAPI before your files.

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

With `## Dependencies`, the game loads EbonAPI before your files, and disables your addon when EbonAPI is not installed. That is what you want when your addon cannot work without it.

!!! note
    There is no `## SavedVariables` line. EbonAPI saves your data for you, inside its own saved variable. See [Storage](guides/storage.md).

If your addon must also run without EbonAPI, declare `## OptionalDeps: EbonAPI` instead and guard every access with `if EbonAPI then`.

## 2. Get your handle

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
```

`NewAddon` takes your addon name and the oldest EbonAPI version your addon accepts, as `major, minor`: `1, 0` means "EbonAPI 1.0 or newer". It returns a **handle**: the object that carries every service, already labelled with your addon name. Keep it in a local variable and call everything through it. An optional fourth argument gives your icon, your project link and your update check; see [Connecting your addon](guides/connection.md).

- The name is 1 to 32 characters: letters, digits and `_` only. It becomes your identity everywhere: the chat tag `[MyAddon]`, your saved data, your messages to other players, your shared data.
- Calling `NewAddon` twice with the same name returns the same handle. Any file of your addon can call it.
- When the installed EbonAPI is older than what you ask for, `NewAddon` returns `nil` and the player sees a line in chat, in their language. In English it reads `EbonAPI 1.0.0 is too old for MyAddon, which needs 1.5.`. Guard for it:

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

if not api then
  return -- EbonAPI is too old for us; the player has been told
end
```

!!! warning
    A name that breaks the rules is a bug in your code, not a runtime condition: `NewAddon` raises an error instead of returning `nil`, for example `EbonAPI:NewAddon: addon name "My Addon" must be 1 to 32 letters, digits or "_"`. See [Errors](reference/errors.md).

## 3. Wait for READY

EbonAPI finishes its own start-up when the player logs in: it binds the character's saved data, detects ProjectEbonhold and turns on its server and player services. Then it emits `READY` with its version.

```lua
api:On("READY", function(event, version)
  api:Print("Connected to EbonAPI " .. version)
end)
```

`READY` is **sticky**: EbonAPI remembers it. If you subscribe after it fired, your function runs at once with the same version. Whatever the order in which the game loads your files, you never miss it.

You can do all of this before `READY`: subscribe to events, register translations, declare your version, open your saved data. Talking to other players is different: `api:Say` returns `false` until the channel is joined, and `CHANNEL_JOINED` tells you when. See [Channel](guides/channel.md).

## 4. React to the server

EbonAPI reads the server messages it knows and turns them into events. Run data, for example:

```lua
api:On("SERVER_RUN_DATA", function(event, run)
  api:Print("Soul Ashes: " .. run.soulPoints .. " / " .. run.soulPointsMax)
end)
```

`SERVER_RUN_DATA` is sticky too: once the server has sent the run data, a late subscriber gets the last run data right away. The full list of server events and their fields is in [Server](guides/server.md).

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
    Log in, press **Esc**, choose **EbonAPI**, open **Diagnostics → Reports → Status**. The `consumers:` line lists `MyAddon`: your handle is registered. **Trace** lists the last things EbonAPI recorded, the server messages it received included.

## Where next

- [Concepts](concepts.md): the handle, the start-up order, events, names, sending and errors.
- [Storage](guides/storage.md): `api:DB()` gives you account and character data with defaults.
- [Localization](guides/localization.md): `api:Locale()` gives your addon the language the player chose.
- [Kit](guides/kit.md): your own windows, built from EbonAPI's elements.
- [Cookbook: minimal addon](cookbook/minimal-addon.md): a complete small addon with saved data, translations, a version and a minimap button.
