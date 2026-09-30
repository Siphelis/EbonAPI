# 🧬 Echo profile

Learn the class, the build slots, the echoes of each build and the ban lists of the other players, and let EbonAPI announce yours.

## What it does

- Announces your own Echo builds to the other players when the server's build list changes, and your ban lists when you set them.
- Delivers the profiles of the other players as three events: slots, one build, ban lists.
- Turns the compact texts of those events into lists of spell ids and stacks.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)
local Profile = EbonAPI.Profile

local L = api:Locale({
  enUS = { BUILD_SEEN = "%s (%s), slot %d: %d echoes" },
  frFR = { BUILD_SEEN = "%s (%s), emplacement %d : %d échos" },
})

api:On("PROFILE_BUILD", function(event, sender, class, slot, hash, echoes, locked)
  local ids, stacks, count = Profile.DecodeBuild(echoes)

  api:Print(string.format(L.BUILD_SEEN, sender, Profile.ClassToken(class), slot, count))

  for i = 1, count do
    api:Debug(ids[i] .. " x" .. stacks[i])
  end

  if locked then
    local lockedIds, lockedCount = Profile.DecodeLocked(locked)

    api:Debug(lockedCount .. " locked echoes")
  end
end)

api:On("PROFILE_SLOTS", function(event, sender, class, slots)
  api:Debug(sender .. " has " .. #slots .. " build slots")
end)
```

## How it works

**Your own profile.** You do not send anything yourself. As soon as an addon uses EbonAPI, EbonAPI announces the layout of your build slots and each build, every time the server's build list changes (`SERVER_BUILDS`) and when the channel is joined. A build is announced again only when its content changed.

**Ban lists.** `api:SetProfileBans(lists)` records your ban lists, a list of lists of echo spell ids, and announces them when they differ from the last announcement. There is one set of ban lists per player, not one per addon: the last call replaces the previous one. EbonAPI does not keep the lists between sessions, so call it again at every login. It returns `true` when the lists were queued or were already announced. It returns `false` when nothing could be queued now: if the channel is not joined or your builds are not known yet, the lists are kept and go out on their own; if your class is unknown, they are not kept, so call again.

**Other players.** Each announcement received becomes an event. Your own announcements do not come back to you. `hash` is a fingerprint of the content: two builds with the same `hash` have the same echoes and the same locked echoes. Keep the last `hash` per player and slot, and you can skip the decoding when it did not change:

```lua
local seen = {}

api:On("PROFILE_BUILD", function(event, sender, class, slot, hash, echoes, locked)
  local key = sender .. ":" .. slot

  if seen[key] == hash then
    return                              -- same build as last time
  end

  seen[key] = hash
  local ids, stacks, count = Profile.DecodeBuild(echoes)
  -- use the new build
end)
```

**Locked echoes.** `locked` holds the echoes the player put in the locked slots of that build, and they are part of `echoes` too. It is `""` when no echo is locked, and `nil` when the sender runs an older EbonAPI that does not announce them: the build is delivered all the same.

**Class.** The class travels as a number from 1 to 10, in this order: warrior, paladin, hunter, rogue, priest, death knight, shaman, mage, warlock, druid. `Profile.ClassToken(index)` gives the WoW token, `Profile.ClassIndex(token)` the number, `Profile.PlayerClass()` the player's own.

**Invalid announcements.** An announcement with a class outside 1 to 10, a slot outside 1 to 20, a text that does not fit its limits or a `hash` that does not match its content is dropped: no event fires, and the rejected count of **Status** goes up.

## Decoding

| Function | Arguments | Returns |
| --- | --- | --- |
| `Profile.DecodeBuild(echoes)` | the `echoes` text of `PROFILE_BUILD` | `ids, stacks, count`, or `nil` for a malformed text |
| `Profile.DecodeLocked(locked)` | the `locked` text of `PROFILE_BUILD` | `ids, count`, or `nil` for a malformed or missing text |
| `Profile.DecodeBans(lists)` | the `lists` text of `PROFILE_BANS` | a list of lists of spell ids (empty for `""`), or `nil` for a malformed text |
| `Profile.ClassToken(index)` | 1 to 10 | `"WARRIOR"`, `"MAGE"`, ... ; `nil` for another number |
| `Profile.ClassIndex(token)` | WoW class token | 1 to 10, or `nil` for another token |
| `Profile.PlayerClass()` | | the player's class index, or `nil` when it is not known |
| `Profile.EncodeEchoes(raw)` | raw text of `<spellId>.<stacks>` pairs | `text, count` |
| `Profile.EncodeLocked(ids)` | list of spell ids | `text, count` |
| `Profile.EncodeBans(lists)` | list of lists of spell ids | `text, count` (empty lists dropped) |
| `Profile.Signature(text)` | text | the `hash` of the text |

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:SetProfileBans(lists)` | list of lists of spell ids | `true` when the lists were queued or were already announced; `false` when nothing could be queued now (channel not joined or builds not known yet: kept, sent on their own; class unknown: not kept, call again) | lists is not a table: `EbonAPI.Profile.SetBans expects a table of lists, got <type>` |

## Events

| Event | Arguments | Sticky | When |
| --- | --- | --- | --- |
| `PROFILE_SLOTS` | sender, class, list of slot numbers | no | a player announced the layout of their builds |
| `PROFILE_BUILD` | sender, class, slot, hash, echoes, locked | no | a player announced one build |
| `PROFILE_BANS` | sender, class, hash, lists | no | a player announced their ban lists |

## Limits

| | Value |
| --- | --- |
| Slots | 1 to 20 |
| Echoes per build | 150, stacks up to 63; extra echoes are ignored |
| Locked echoes per build | 150; extra ids are ignored |
| Ban lists | 20 lists of 150 echoes; extra lists and ids are ignored |
| Echo spell ids | 200000 to 204095; other ids are ignored |

!!! tip "🎮 Try it"
    The profile line of **Diagnostics → Reports → Status**, in the EbonAPI window, reads `profile: sent P=1 D=3 X=0, received 4, rejected 0`: **P** counts the layouts of your slots sent, **D** your builds, **X** your ban lists.

## See also

- [Server](server.md) for `SERVER_BUILDS`, the source of your own profile.
