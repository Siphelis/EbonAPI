# Shared dataset

A message board every player of the addon ends up reading: whoever publishes last wins, and EbonAPI carries the text from player to player.

```lua title="Notes.lua"
local api = EbonAPI:NewAddon("Notes", 1, 0)

if not api then
  return
end

local function show()
  local text, state = api:GetShared("board")

  if text and text ~= "" then
    api:Print("Board (revision " .. state .. "): " .. text)
  else
    api:Print("Board is empty")
  end
end

api:On("SHARE_RECEIVED", function(event, addon, name, state, sender)
  if addon == "Notes" and name == "board" then
    api:Print("Board updated by " .. sender)
    show()
  end
end)

-- Take a board only when it is newer than ours. This is the default rule,
-- written out so that you can change it.
api:ShareRule(function(name, theirState, myState)
  return myState == nil or tonumber(theirState) > tonumber(myState)
end)

SLASH_NOTES1 = "/notes"

SlashCmdList["NOTES"] = function(input)
  local command, rest = string.match(input or "", "^%s*(%S*)%s*(.-)%s*$")

  if command == "set" and rest ~= "" then
    api:Share("board", time(), rest)
    api:Success("Board published")
  elseif command == "clear" then
    api:Share("board", time(), "")
    api:Success("Board cleared for everyone")
  else
    show()
  end
end
```

## What happens

1. `/notes set Raid at nine` publishes the dataset `board` with the current time as its state. Fifteen seconds later EbonAPI announces the change; players whose copy is older fetch the text within the next exchange.
2. On their side, `SHARE_RECEIVED` fires with the sender's name, and `show()` prints the new board.
3. The state comes back as a string of digits, hence `tonumber` in the rule.
4. `/notes clear` publishes an empty text with a newer state: every player fetches the empty version. That is how a dataset is retired for everyone, since removing it locally would only make it come back.
5. Players who do not run the addon still carry the board for the others: EbonAPI stores every dataset it receives.

## Reading another addon's dataset

Datasets are readable across addons. An addon that wants the board of `Notes` reads it by name:

```lua
local text, state = api:GetShared("board", "Notes")
```

!!! tip "🎮 Try it"
    Two characters on two accounts: `/notes set hello` on one, wait for the next exchange, `/notes` on the other. The shares line of `/eapi status` counts what was received. `/eapi trace 20 share` shows the exchange step by step.
