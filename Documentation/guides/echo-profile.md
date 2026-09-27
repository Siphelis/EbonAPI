# 🧬 Echo profile

Learn the class, the build slots, the echoes of each build and the ban lists of the other players, and let EbonAPI announce yours.

## What it does

- Announces your own Echo builds on the channel when the server's build list changes, and your ban lists when you set them.
- Delivers the profiles of the other players as three events: slots, one build, ban lists.
- Decodes the compact build and ban formats into spell ids and stacks.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
local Profile = EbonAPI.Profile

api:On("PROFILE_BUILD", function(event, sender, class, slot, hash, echoes)
  local ids, stacks, count = Profile.DecodeBuild(echoes)

  api:Print(sender .. " (" .. Profile.ClassToken(class) .. ") slot " .. slot .. ": " .. count .. " echoes")

  for i = 1, count do
    api:Debug(ids[i] .. " x" .. stacks[i])
  end
end)

api:On("PROFILE_SLOTS", function(event, sender, class, slots)
  api:Debug(sender .. " has " .. #slots .. " build slots")
end)
```

## How it works

**Your profile.** After the channel is joined, EbonAPI reads the build list the server sent, `SERVER_BUILDS`, and announces the layout of your slots, then each build that changed since the last announcement. At the first login of a session, it asks the server for the build list 10 seconds after `READY`, then announces everything once. A build is announced again only when its content changed.

**Ban lists.** `api:SetProfileBans(lists)` records your ban lists, a list of lists of echo spell ids, and announces them when they differ from the last announcement. It returns `true` when everything pending is queued, `false` when something must wait: the class is not known yet, or the channel is not joined.

**Other players.** Each announcement received becomes an event. The `hash` is a signature of the content: two builds with the same hash have the same echoes, which lets you skip a decode.

**Class.** The class travels as a number from 1 to 10, in this order: warrior, paladin, hunter, rogue, priest, death knight, shaman, mage, warlock, druid. `Profile.ClassToken(index)` gives the WoW token, `Profile.ClassIndex(token)` the number, `Profile.PlayerClass()` the player's own.

## Decoding

| Function | Arguments | Returns |
| --- | --- | --- |
| `Profile.DecodeBuild(echoes)` | the `echoes` text of `PROFILE_BUILD` | `ids, stacks, count`, or `nil` for a malformed text |
| `Profile.DecodeBans(lists)` | the `lists` text of `PROFILE_BANS` | a list of lists of spell ids, or `nil` |
| `Profile.ClassToken(index)` | 1 to 10 | `"WARRIOR"`, `"MAGE"`, ... |
| `Profile.ClassIndex(token)` | WoW class token | 1 to 10 |
| `Profile.PlayerClass()` | | the player's class index |

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:SetProfileBans(lists)` | list of lists of spell ids | `true` when everything pending is queued | lists is not a table |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `PROFILE_SLOTS` | sender, class, list of slot numbers | no | a player announced the layout of their builds |
| `PROFILE_BUILD` | sender, class, slot, hash, echoes | no | a player announced one build |
| `PROFILE_BANS` | sender, class, hash, lists | no | a player announced their ban lists |

## Limits

| | Value |
| --- | --- |
| Slots | 1 to 20 |
| Echoes per build | 150, stacks up to 63 |
| Ban lists | 20 lists of 150 echoes |
| Echo spell ids | 200000 to 204095 |

!!! tip "🎮 Try it"
    The profile line of `/eapi status` counts what was sent, received and rejected as malformed.

## See also

- [Server](server.md) for `SERVER_BUILDS`, the source of your own profile.
