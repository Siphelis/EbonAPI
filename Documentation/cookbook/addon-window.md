# Addon window

A notebook with its own window and minimap button: the player adds notes, deletes them from a right-click menu, and sees how many there are on the button. No slash command: everything goes through the interface.

```lua title="RouteNotes.lua"
local api = EbonAPI:NewAddon("RouteNotes", 1, 0, { icon = "INV_Misc_Note_01" })

if not api then
  return
end

local L = api:Locale({
  enUS = {
    TITLE = "Route notes", ADD = "Add a note", NEW = "New note:", EMPTY = "No note yet.",
    DELETE = "Delete", ADDED = "Note added.", TIP = "Click: open your notes.",
  },
  frFR = {
    TITLE = "Notes de route", ADD = "Ajouter une note", NEW = "Nouvelle note :", EMPTY = "Aucune note.",
    DELETE = "Supprimer", ADDED = "Note ajoutée.", TIP = "Clic : ouvrir vos notes.",
  },
})

local db = api:DB({ account = { notes = {} } })
local win = api:Window("main", { key = "TITLE" })
local list, button

local function changed()
  list:Refresh()
  button:Refresh()
end

list = win:Add("list", {
  emptyKey = "EMPTY",
  items = function()
    local items = {}

    for index, note in ipairs(db.account.notes) do
      items[index] = {
        text = note,
        menu = {
          { key = "DELETE", onClick = function()
            table.remove(db.account.notes, index)
            changed()
          end },
        },
      }
    end

    return items
  end,
})

win:Add("button", {
  key = "ADD",
  onClick = function()
    api:Prompt(L.NEW, "", function(text)
      if text ~= "" then
        table.insert(db.account.notes, text)
        changed()
        api:Notify(L.ADDED)
      end
    end)
  end,
})

button = api:MinimapButton({
  tipKey = "TIP",
  badge = function()
    return #db.account.notes > 0 and #db.account.notes or nil
  end,
  onClick = function()
    win:Toggle()
  end,
})
```

## What happens

1. `NewAddon` gives the addon its icon: the minimap button, the notification and the card under **Connected addons** show it.
2. `api:Window("main", ...)` creates the window, hidden until opened. Its title comes from the translations and follows the language.
3. The list reads its items from a function, called again at each `list:Refresh()`. Each item carries its own menu: a right-click on a note offers **Delete**.
4. **Add a note** opens a prompt. On **OK**, the note is saved for the account, the list and the button are refreshed, and a notification appears at the top of the screen.
5. The minimap button shows the number of notes as its badge; a click opens or closes the window. The player can group it in EbonAPI's button or hide it from the card of RouteNotes.

!!! tip "🎮 Try it"
    Click the minimap button, add two notes, then right-click one of them. Choose French in **Language**, under **Esc → EbonAPI → General**: the title, the button and the menu change language at once.
