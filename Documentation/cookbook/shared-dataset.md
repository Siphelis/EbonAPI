# Shared dataset

A message board every player of the addon ends up reading: the newest message wins, and EbonAPI carries the text from player to player. A window shows the board, and a minimap button opens it.

```lua title="Notes.lua"
local api = EbonAPI:NewAddon("Notes", 1, 0, { icon = "INV_Misc_Note_02" })

if not api then
  return
end

local L = api:Locale({
  enUS = {
    TITLE = "Notes board", EMPTY = "The board is empty.", PUBLISHED_AT = "Published on %s",
    PUBLISH = "Publish a message", CLEAR = "Clear the board", SYNC = "Share now",
    PROMPT = "Message for the board:", DONE = "Board published.", CLEARED = "Board cleared for everyone.",
    UPDATED = "%s updated the board.", SYNCED = "Your board was announced.", TIP = "Click: open the board.",
  },
  frFR = {
    TITLE = "Tableau de notes", EMPTY = "Le tableau est vide.", PUBLISHED_AT = "Publié le %s",
    PUBLISH = "Publier un message", CLEAR = "Vider le tableau", SYNC = "Partager maintenant",
    PROMPT = "Message pour le tableau :", DONE = "Tableau publié.", CLEARED = "Tableau vidé pour tout le monde.",
    UPDATED = "%s a mis à jour le tableau.", SYNCED = "Votre tableau a été annoncé.", TIP = "Clic : ouvrir le tableau.",
  },
})

local win = api:Window("main", { key = "TITLE" })

win:Add("text", {
  width = 320,
  text = function()
    local text = api:GetShared("board")

    return text and text ~= "" and text or L.EMPTY
  end,
})

win:Add("status", {
  width = 320,
  text = function()
    local text, state = api:GetShared("board")

    return text and text ~= "" and string.format(L.PUBLISHED_AT, date("%Y-%m-%d %H:%M", tonumber(state))) or ""
  end,
})

local bar = win:Add("bar")

bar:Add("button", {
  key = "PUBLISH",
  onClick = function()
    api:Prompt(L.PROMPT, "", function(text)
      if text ~= "" then
        api:Share("board", time(), text)
        win:Refresh()
        api:Notify(L.DONE)
      end
    end)
  end,
})

bar:Add("button", {
  key = "CLEAR",
  onClick = function()
    api:Share("board", time(), "")
    win:Refresh()
    api:Notify(L.CLEARED)
  end,
})

bar:Add("button", {
  key = "SYNC",
  onClick = function()
    if api:SyncShares() then
      api:Notify(L.SYNCED)
    end
  end,
})

api:On("SHARE_RECEIVED", function(event, addon, name, state, sender)
  if addon == "Notes" and name == "board" then
    win:Refresh()
    api:Notify(string.format(L.UPDATED, sender))
  end
end)

-- Take a board only when it is newer than ours. This is the default rule,
-- written out so that you can change it.
api:ShareRule(function(name, theirState, myState)
  return myState == nil or tonumber(theirState) > tonumber(myState)
end)

api:MinimapButton({
  tipKey = "TIP",
  onClick = function()
    win:Toggle()
  end,
})
```

## What happens

1. **Publish a message** opens a prompt. On **OK**, `api:Share("board", time(), text)` stores the text under the name `board`, with the current time as its state. The [state](../reference/glossary.md) is a whole number that says how new the text is; here it is the time. Together, the name, the state and the text make a [dataset](../reference/glossary.md). EbonAPI then passes it on to the other players; this is not instant.
2. On the other players' side, `SHARE_RECEIVED` fires with the addon name, the dataset name, its state and the sender's name. The window is redrawn and a notification names the sender.
3. The state comes back as a string of digits, hence `tonumber` in the rule and in the date.
4. `ShareRule` is asked only when a player offers a state different from yours. `theirState` is the offered state and `myState` is yours, or `nil` if you have none. Return true to take the text, false to ignore it.
5. **Clear the board** publishes an empty text with a newer state: every player fetches the empty version. That is how a dataset is retired for everyone. `api:Unshare("board")` would only remove it from your own copy, and the next exchange would bring it back.
6. **Share now** calls `api:SyncShares()`, which announces your datasets at once instead of waiting. It returns false when you did so less than 30 seconds ago, or when EbonAPI cannot send yet, so the notification appears only when the announcement went out.
7. A player who has EbonAPI but not Notes still stores the board and passes it on to the others.

## Reading another addon's dataset

Datasets are readable across addons. An addon that wants the board of `Notes` reads it by name:

```lua
local text, state = api:GetShared("board", "Notes")
```

!!! tip "🎮 Try it"
    Two characters on two accounts: click the minimap button, choose **Publish a message** on one and type `hello`. Click **Share now**, then open the board on the other character after a few seconds. The shares line of **Esc → EbonAPI → Diagnostics → Reports → Status** counts what was received. **Trace**, with **Trace filter** on `share`, shows the exchange step by step.
