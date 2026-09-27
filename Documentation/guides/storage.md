# 💾 Storage

Account and character data, with defaults applied on load and migrations that run once.

## What it does

EbonAPI owns one saved variable, `EbonAPIDB`, and gives every addon its own bucket inside it. `api:DB(defaults)` returns a **store** with two scopes:

- `db.account`: shared by every character of the account.
- `db.char`: the current character. It exists from `READY` on.

Defaults fill the missing keys on every load, including inside nested tables. A value the player already has is never overwritten.

## Quick example

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 0)

local db = api:DB({
  account = { minimapButton = true, routes = {} },
  character = { logins = 0 },
})

api:On("READY", function()
  db.char.logins = db.char.logins + 1
  api:Print("Logins on this character: " .. db.char.logins)
end)
```

No `## SavedVariables` line in your `.toc`: EbonAPI's own saved variable carries your data.

## Scopes

| Scope | Field | Available | Shared by |
| --- | --- | --- | --- |
| Account | `db.account` | as soon as `api:DB` returns | every character of the account |
| Character | `db.char` | from `READY` on; `nil` before | this character only, keyed `Name-Realm` |

Always go through `db.char`; do not copy it into a local before `READY`, it is `nil` then.

Other characters of the account can be read:

```lua
for _, key in ipairs(db:CharacterKeys()) do      -- "Alice-Ebonhold", "Bob-Ebonhold"
  local entry = db:CharacterAt(key)
  api:Print(key .. " logged in " .. (entry.logins or 0) .. " times")
end
```

`db:ResetCharacter()` wipes the current character's data and applies the defaults again. It returns `false` before `READY`.

## Defaults

```lua
api:DB({
  account = { ... },
  character = { ... },
})
```

- A default is used only when the key is missing. A saved `false` stays `false`.
- Table defaults are applied recursively, so a new key inside `account.options` reaches existing players.
- Both parts are optional. `api:DB()` with no argument returns the store with the defaults given so far.
- Several files can call `api:DB(defaults)`; the defaults merge and the same store comes back.

Saved values must be strings, numbers, booleans or tables of those. Functions, frames and other userdata cannot be saved by the game.

## Migrations

When your layout changes, or when you move from your own saved variable, run a migration once:

```lua
db:MigrateOnce("import-legacy", MyAddonLegacyDB, function(store, legacy)
  if type(legacy) ~= "table" then
    return true                          -- nothing to import: done anyway
  end

  for id, route in pairs(legacy.routes or {}) do
    store.account.routes[id] = route
  end

  return true                            -- any value except nil marks it done
end)
```

- The key names the migration. It runs at most once per account, whatever the character.
- `fn(store, legacy, characterName, characterKey)` receives your store, the value you passed as `legacy`, and the current character.
- Return `nil` to say "not now": the migration stays pending and runs again next time. Return anything else to mark it done.
- An error inside `fn` is reported with `api:Error`, and the migration stays pending.
- `MigrateOnce` returns `true, result` when it ran and completed, `false` otherwise.

`db:MigrateOncePerCharacter(key, legacy, fn)` does the same once per character. It returns `false` before `READY`.

`db:IsMigrated(key)` and `db:IsMigrated(key, true)` tell you whether a marker exists.

!!! note
    To import an old saved variable, keep its `## SavedVariables` line in your `.toc` for a release or two, so the game still loads it for the migration to read. Remove the line once every player has migrated.

## Layout of EbonAPIDB

```text
EbonAPIDB
├─ version                       schema of this layout
├─ shared
│  └─ account                    EbonAPI's own settings, such as the language
├─ addons
│  └─ MyAddon
│     ├─ account                 db.account
│     └─ characters
│        └─ Alice-Ebonhold       db.char for that character
└─ migrations                    "MyAddon/import-legacy" = true
```

Read and write through the store. Reading `EbonAPIDB` directly ties your addon to this layout, which may change.

A value found where a table was expected is replaced by an empty table at load and counted as a repair. `/eapi db` shows the count.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:DB(defaults?)` | `{ account = {...}, character = {...} }` | the store | defaults is not a table |
| `db.account` | | table | |
| `db.char` | | table, or `nil` before `READY` | |
| `db:CharacterKeys()` | | sorted list of `Name-Realm` keys | |
| `db:CharacterAt(key)` | key | that character's table, or `nil` | |
| `db:ResetCharacter()` | | `true`, or `false` before `READY` | |
| `db:MigrateOnce(key, legacy, fn)` | key, any value, function | `true, result` or `false` | key is not a string, fn is not a function |
| `db:MigrateOncePerCharacter(key, legacy, fn)` | key, any value, function | `true, result` or `false` | key is not a string, fn is not a function |
| `db:IsMigrated(key, perCharacter?)` | key, boolean | `true` or `false` | |

!!! tip "🎮 Try it"
    `/eapi db` prints one line per addon with the number of account keys and characters, the migrations applied and the entries repaired at load.

## See also

- [Cookbook: minimal addon](../cookbook/minimal-addon.md) uses a store with both scopes.
- [Sharing](sharing.md) for data that must reach other players.
