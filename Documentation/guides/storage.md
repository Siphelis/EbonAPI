# 💾 Storage

Account and character data, with defaults applied on load and migrations that run once.

## What it does

EbonAPI owns one saved variable, `EbonAPIDB`, and gives every addon its own bucket inside it. `api:DB(defaults)` returns a **store** with two scopes:

- `db.account`: shared by every character of the account.
- `db.char`: the current character. It exists from `READY` on.

Defaults fill the missing keys on every load, including inside nested tables. A value the player already has is kept. The one exception: where your default is a table and the saved value is not a table, it is replaced by a table with your defaults.

The store is yours alone: other addons have their own. `api:DB()` returns the same store every time you call it.

## Quick example

```lua title="MyAddon.lua"
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

## How it works

### Scopes

| Scope | Field | Available | Shared by |
| --- | --- | --- | --- |
| Account | `db.account` | as soon as `api:DB` returns | every character of the account |
| Character | `db.char` | from `READY` on; `nil` before | this character only, keyed `Name-Realm` |

Read `db.account` and `db.char` each time you need them. Do not keep them in a local variable: `db.char` is `nil` before the character is known, and `db.char` is replaced by a new table after `db:ResetCharacter()`.

Other characters of the account can be read:

```lua
for _, key in ipairs(db:CharacterKeys()) do      -- "Alice-Ebonhold", "Bob-Ebonhold"
  local entry = db:CharacterAt(key)
  api:Print(key .. " logged in " .. (entry.logins or 0) .. " times")
end
```

`db:CharacterAt(key)` gives the table as it was saved. The defaults are applied only to the current character, so another character's table can lack a key that is new in your defaults. Read it with a fallback, as above.

`db:ResetCharacter()` wipes the current character's data and applies the defaults again. It returns `true`, or `false` when the character is not known yet. The account data and the migrations already done are kept: a per-character migration that ran is not run again.

### Defaults

```lua
api:DB({
  account = { ... },
  character = { ... },
})
```

- A default is used only when the key is missing. A saved `false` stays `false`. The one exception: where your default is a table and the saved value is not a table, the saved value is replaced by a table with your defaults.
- Table defaults are applied recursively, so a new key inside `account.options` reaches existing players.
- Both parts are optional. `api:DB()` with no argument returns the store with the defaults given so far.
- Several files can call `api:DB(defaults)`. The defaults add up and the same store comes back. When two calls give a default for the same key, the first one stays.
- Removing a default later never removes what the player has already saved.
- Give `account` and `character` as tables. `api:DB(defaults)` raises `EbonAPI: the defaults of 'MyAddon' must be a table, got <type>` when `defaults` itself is not a table.

### Migrations

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
- An error inside `fn` is reported as `[MyAddon] migration 'import-legacy' failed: <error text>`, and the migration stays pending.
- `MigrateOnce` returns `true, result` when it ran and completed, where `result` is the value `fn` returned. It returns `false` when the migration was already done, when `fn` returned `nil`, or when `fn` raised an error.
- `key` must be a string and `fn` a function. Otherwise it raises `EbonAPI: the migration key must be a string, got <type>` or `EbonAPI: migration '<key>' expects a function, got <type>`.

`db:MigrateOncePerCharacter(key, legacy, fn)` does the same once per character. It returns `false`, without running `fn`, while the character is not known yet.

`db:IsMigrated(key)` tells you whether the account migration `key` is done. `db:IsMigrated(key, true)` tells you the same for the current character's migration.

!!! note
    To import an old saved variable, keep its `## SavedVariables` line in your `.toc` for a release or two, so the game still loads it for the migration to read. Remove the line once every player has migrated.

## EbonAPIDB layout

This is what you find in the `EbonAPI.lua` file of the `SavedVariables` folder, to help you read it when something looks wrong. It is not meant to be read by code: go through `api:DB()`, since this layout may change in any version.

```text
EbonAPIDB
├─ version                         layout version
├─ shared
│  ├─ account                      the language shared by every addon (language)
│  └─ characters
├─ addons
│  ├─ EbonAPI                      EbonAPI's own data
│  │  ├─ account                   skin, parameters, windows, kit, keys, shared,
│  │  │                            versions, perfReports
│  │  └─ characters                session, profile
│  └─ MyAddon
│     ├─ account                   db.account
│     └─ characters
│        └─ Alice-Ebonhold         db.char for that character
└─ migrations
   ├─ MyAddon/import-legacy        true once that account migration is done
   └─ MyAddon/fix@Alice-Ebonhold   the same, for a per-character migration
```

The character key is the character name, a dash and the realm name.

When EbonAPI finds something other than a table where a table belongs, for example after a hand edit of the file, it replaces it with an empty table and counts a repair. **Diagnostics → Reports → Saved data** shows that count.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:DB(defaults?)` | `{ account = {...}, character = {...} }` | the store | `defaults` is given and is not a table |
| `db.account` | | table | |
| `db.char` | | table, or `nil` before `READY` | |
| `db:CharacterKeys()` | | sorted list of `Name-Realm` keys | |
| `db:CharacterAt(key)` | key | that character's table, or `nil` | |
| `db:ResetCharacter()` | | `true`, or `false` when the character is not known yet | |
| `db:MigrateOnce(key, legacy, fn)` | key, any value, function | `true, result` or `false` | `key` is not a string, `fn` is not a function |
| `db:MigrateOncePerCharacter(key, legacy, fn)` | key, any value, function | `true, result` or `false` (also while the character is not known) | `key` is not a string, `fn` is not a function |
| `db:IsMigrated(key, perCharacter?)` | key, boolean | `true` or `false` | |

## Limits

Saved values are limited to strings, numbers, booleans and tables of those.

- `db.char` is `nil` until the character is known. It is set by the time `READY` fires.
- A migration returning `false` counts as done: only `nil` leaves it pending.

!!! tip "🎮 Try it"
    **Diagnostics → Reports → Saved data**, in the EbonAPI window, shows one line per addon with its number of account keys and characters, then the total of migrations applied and of entries repaired at load.

## See also

- [Cookbook: minimal addon](../cookbook/minimal-addon.md) uses a store with both scopes.
- [Sharing](sharing.md) for data that must reach other players.
