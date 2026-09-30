# 🧭 Minimap button

Give your addon a button around the minimap. The player places it, groups it with others or hides it, and finds it where they left it.

## What it does

- `api:MinimapButton` puts your addon's button around the minimap, with your icon, a tooltip and a mark for news.
- The player can reposition, lock and reset it.
- The player chooses where it appears. **Grouped** buttons gather in EbonAPI's own button, which opens them in a small pop-up.
- Your button is also offered to LibDataBroker displays, when one is installed.

## Quick example

```lua title="MyAddon.lua"
local api = EbonAPI:NewAddon("MyAddon", 1, 0, { icon = "INV_Misc_Map_01" })

local L = api:Locale({
  enUS = { TIP = "Click: open the window.", CLOSE = "Close the window" },
  frFR = { TIP = "Clic : ouvrir la fenêtre.", CLOSE = "Fermer la fenêtre" },
})

local win = api:Window("main", { text = "MyAddon" })

api:MinimapButton({
  tipKey = "TIP",
  onClick = function(button, mouseButton)
    win:Toggle()
  end,
  menu = {
    { key = "CLOSE", onClick = function() win:Close() end },
  },
})
```

A left-click opens the window, a right-click opens the menu. The tooltip shows the name of your addon and its version, then the text of `tipKey`.

## How it works

Your button sits on the minimap edge. The player drags it, locks it, puts it in EbonAPI's button or hides it, and EbonAPI remembers the choice for the account.

### The button

`api:MinimapButton(fields?)` creates your addon's button and returns it. Each addon has one: calling it again replaces the fields of the same button and returns it.

| Field | Default | Effect |
| --- | --- | --- |
| `icon` | your addon's icon | a name from `Interface\Icons` or a texture path, or a function that returns it |
| `text`, `key` | your addon name and version | the first line of the tooltip: a text, a function that returns it, or a translation key |
| `tip`, `tipKey` | | the rest of the tooltip: a text, a translation key, or `function(lines, button)` as for [Kit elements](kit.md#fields-every-element-takes) |
| `onClick` | | `function(button, mouseButton)` |
| `menu` | | the menu of a right-click, see [Menus](kit.md#menus) |
| `badge` | | a mark on the corner: a text, a number, `true` for a dot |
| `display` | `"BUTTON"` | where it appears: `"BUTTON"`, `"GROUP"` or `"HIDDEN"` |
| `hidden` | | `true`, or a function that returns it, is the same as `display = "HIDDEN"` |
| `angle` | the skin's, 225 | its first place around the minimap, in degrees |

The default first line is the name of your addon followed by the `## Version` of its `.toc` file. Functions given as `icon`, `text`, `hidden` or `badge` receive the button.

A left-click calls `onClick`. A right-click opens `menu` when you gave one; otherwise it calls `onClick` with `"RightButton"` as `mouseButton`.

When a newer version of your addon was seen, the tooltip shows `Version 1.3.0 available.` under the first line, and the button shows a dot, unless you gave your own `badge`.

| Method | Effect |
| --- | --- |
| `button:Refresh()` | reads the functions again, for an icon or a badge that changes; returns the button |
| `button:SetAngle(angle)` | moves the button to `angle`, in degrees, and saves it as the player's place; returns the button |

`angle` counts counter-clockwise from the right of the minimap: 0 is to the right, 90 is at the top.

### Where it appears

| `display` | The button |
| --- | --- |
| `"BUTTON"` | stands around the minimap |
| `"GROUP"` | goes into EbonAPI's button |
| `"HIDDEN"` | does not show |

`display` is only where the button starts. The player can choose another place on your card under **Connected addons**, and the player's choice wins. Choosing your `display` again there hands the decision back to your code.

**EbonAPI's button** shows as soon as one addon is grouped, or always when the player ticks **Always show the EbonAPI button** on the **General** page. A left-click opens the pop-up of the grouped buttons, a right-click opens the EbonAPI window. With no grouped button, a click opens the window. Clicking a grouped button closes the pop-up. The pop-up sorts the buttons by addon name, four to a row in the default skin. When EbonAPI or a grouped addon has news, EbonAPI's button shows the dot.

**Position.** The player drags a button around the minimap with the left mouse button, square minimaps included. The position is saved for the account. A button inside the pop-up cannot be dragged. The player can lock one button, or all of them with **Lock positions** under **Appearance → Layout**, and put one back at its first place.

**On your card.** Under **Esc → EbonAPI → Connected addons**, your card has three controls: **Minimap button** (**On the minimap**, **In the EbonAPI button** or **Hidden**), **Lock its position** and **Reset its position**. The last two work while the button is on the minimap. EbonAPI's own button has its controls on the **General** page, under **Minimap button**: **Always show the EbonAPI button**, **Lock its position** and **Reset its position**.

**LibDataBroker.** When a LibDataBroker display is installed, such as a data bar, your addon appears there too, under its name, with the same icon, click and tooltip. EbonAPI appears there as well under the name `EbonAPI`, and a click opens its window.

The tooltip of EbonAPI's button says `Left-click: grouped addons` and `Right-click: EbonAPI window`; with no grouped button it says `Click: EbonAPI window`.

## Events

The minimap button emits no event.

## API

| Method | Arguments | Returns | Raises when |
| --- | --- | --- | --- |
| `api:MinimapButton(fields?)` | fields | the button | fields not a table; `display` not `BUTTON`, `GROUP` or `HIDDEN` |
| `button:Refresh()` | | the button | |
| `button:SetAngle(angle)` | angle in degrees | the button | |

The messages, with your addon's name in place of `MyAddon`:

- `EbonAPI: MyAddon: api:MinimapButton expects a table, got <type>`
- `EbonAPI: MyAddon: api:MinimapButton display expects BUTTON, GROUP or HIDDEN, got <value>`

Both are listed in [Errors](../reference/errors.md#minimap-button). An error inside one of your functions is reported in the game's error display.

## Limits

| | Value |
| --- | --- |
| Buttons | one per addon |
| `display` | `BUTTON`, `GROUP`, `HIDDEN`; capitals only |
| Size of a button | the skin's, 31 pixels in the default skin |

!!! tip "🎮 Try it"
    On your card under **Esc → EbonAPI → Connected addons**, set **Minimap button** to **In the EbonAPI button**: your button leaves the minimap and appears in the pop-up of EbonAPI's button.

## See also

- [Connecting your addon](connection.md) for the icon.
- [Kit](kit.md) for windows, menus and tooltips.
- [Skin parameters](../reference/skin-parameters.md#kit) for the size and the look of the buttons.
