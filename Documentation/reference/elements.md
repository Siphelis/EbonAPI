# Elements

The 27 kinds of the [Kit](../guides/kit.md), with the fields each one takes on top of the [fields every element takes](../guides/kit.md#fields-every-element-takes) (the click fields `onClick`, `menu`, `shortcut` and `link` are listed there apart, for `button`, `secure`, `icon`, `slot` and `handle`), its callbacks and its methods. Create them with `container:Add(kind, fields)` or `api:Create(kind, parent, fields)`.

Sizes marked "the skin's" come from the player's skin; the value given is the one of the default skin. A **unit** is the skin's `page.unit`, 170 pixels by default.

A callback field of an element is called with the element first; the callbacks and functions of an item or a row start with the item or the row, as their signatures show. An error it raises is reported to the game's error display without breaking the element. A field that accepts a function (such as `get`, `items` or `text`) calls it again at every refresh; see [Refreshing](../guides/kit.md#refreshing).

The examples on this page add their elements to `win`, a window created with `api:Window`. They show their texts through `key` and these translations:

```lua
api:Locale({
  enUS = {
    ROUTES = "Routes",
    BUILDS = "Builds",
    NO_ROUTE = "No route yet",
    ROUTE = "Route",
    ASHES = "Ashes",
    NEXT_RESET = "Next reset: %s",
    NO_ITEM = "Nothing to show",
    RESET_DONE = "Reset!",
    CLOSED = "Closed this week",
  },
  frFR = {
    ROUTES = "Routes",
    BUILDS = "Builds",
    NO_ROUTE = "Aucune route pour le moment",
    ROUTE = "Route",
    ASHES = "Cendres",
    NEXT_RESET = "Prochaine réinitialisation : %s",
    NO_ITEM = "Rien à afficher",
    RESET_DONE = "Réinitialisation terminée !",
    CLOSED = "Fermée cette semaine",
  },
})
```

| Family | Kinds |
| --- | --- |
| Actions | [button](#button), [secure](#secure), [icon](#icon), [shortcut](#shortcut) |
| Values | [toggle](#toggle), [range](#range), [select](#select), [color](#color), [input](#input) |
| Text | [heading](#heading), [text](#text), [status](#status), [timer](#timer) |
| Containers | [bar](#bar), [grid](#grid), [group](#group), [panel](#panel), [tabs](#tabs) |
| Collections | [list](#list), [tree](#tree), [table](#table) |
| Display | [progress](#progress), [chart](#chart), [arrow](#arrow), [model](#model) |
| Moving things | [slot](#slot), [handle](#handle) |

## Actions

### button

A button with a text. Its width follows the text unless you give `width`.

| Field | Effect |
| --- | --- |
| `minWidth` | the smallest width |

`onClick(element, mouseButton)` receives `"LeftButton"` or `"RightButton"`; with a `menu`, the right-click opens the menu instead.

### secure

A button that casts a spell, uses an item or runs a macro when the player clicks it with the left button. `onClick` is still called after a click; with a `menu`, the right-click opens the menu instead.

| Field | Effect |
| --- | --- |
| `spell`, `item` or `macro` | the action: a spell name, an item name, or the text of a macro |
| `name` | a global name for the button, so that a macro can `/click` it |
| `preClick` | `function(element, mouseButton)`, called just before the action |
| `disabled` | greys the button and blocks the action |
| `minWidth` | the smallest width |

| Method | Returns | Effect |
| --- | --- | --- |
| `element:SetDisabledState(disabled)` | nothing | greys the button and blocks the action, or restores it; during combat the change waits for the end of the fight |
| `element:SetAction({ spell = ... })` | `true` when applied, `false` when it waits for the end of the fight | another action, with `macro`, `spell` or `item`; if the table holds several, the macro wins, then the spell |

A secure element cannot be created during combat: the call raises `EbonAPI: MyAddon: a secure element cannot be created during combat`. See [Combat](../guides/kit.md#combat).

### icon

A square icon, with a count, a cooldown and a checked state. With `spell`, `item` or `macro`, it becomes a secure button like [secure](#secure), with the same `name` and `preClick` fields; it cannot be created during combat either.

| Field | Default | Effect |
| --- | --- | --- |
| `icon` | a question mark | a name from `Interface\Icons` or a texture path, or a function that returns it |
| `size` | the skin's, 32 | width and height |
| `count` | | a text or number in the lower right corner; `nil` clears it |
| `checked` | | `true` highlights the border, `false` removes the highlight |
| `cooldown` | | `{ start, duration }`, as `GetSpellCooldown` returns them; `{ 0, 0 }` hides it |

The border changes color when the mouse is over the icon and when it is checked.

| Method | Returns | Effect |
| --- | --- | --- |
| `element:SetCooldown(start, duration)` | the element | shows a cooldown; a `start` or a `duration` of 0 hides it |
| `element:SetCheckedState(state)` | the element | highlights the border or not |
| `element:SetDisabledState(disabled)` | nothing | greys the icon and makes it fainter |
| `element:SetAction(action)` | `true` when applied, `false` when it waits for the end of the fight | another action, for a secure icon; same rules as [secure](#secure) |

### shortcut

A button that lets the player choose the key of a [keyboard shortcut](../guides/kit.md#keyboard-shortcuts). Its text is the key, or `label: key` when you give `text` or `key`; it reads **None** while no key is chosen and **Press a key...** while it waits.

| Field | Effect |
| --- | --- |
| `target` | the id of the shortcut, the one given as `shortcut` to the element to click |
| `text`, `key` | a label before the key |
| `minWidth` | the smallest width |

A click waits for a key, a right-click removes the key, **Esc** cancels. The modifier keys **Shift**, **Ctrl** and **Alt** alone do not count: hold them while you press the key, and the shortcut is saved as, for example, `ALT-CTRL-K`. The tooltip reads "Click, then press the key to use. Right-click removes it."

## Values

Each value element reads its value from `get`, a function called at every refresh, or starts with `value`. It tells you about a change through `onChange`, only when the player changes it: changing the value from your code does not call `onChange`. `text` or `key` is its label.

### toggle

A check box with its label.

| Field | Effect |
| --- | --- |
| `get`, `value` | `true` or `false` |
| `onChange` | `function(element, value)` |

### range

A slider with a number field.

| Field | Default | Effect |
| --- | --- | --- |
| `min`, `max` | `0`, `1` | the bounds |
| `step` | `1` when `max - min` is 10 or more, else `0.01` | the increment |
| `percent` | | `true` shows the value as a percentage |
| `format` | | `function(value)` returning the text shown; if it raises, the error is reported and the number is shown |
| `get`, `value` | `min` | the value |
| `onChange` | | `function(element, value)`, when the player releases the slider or types a number and presses **Enter** |
| `width` | one unit | |

The value is rounded to `step` and kept between `min` and `max`. `onChange` is not called when the value did not change. A number typed in the field may use a comma, and a `%` sign is ignored; **Esc** puts the previous value back.

### select

A drop-down list.

| Field | Effect |
| --- | --- |
| `values` | a table `{ key = text }`, shown sorted by text, or a list `{ { value = ..., text = ... } }` shown in its order, where `textKey` can replace `text`; or a function that returns one of them |
| `get`, `value` | the key chosen |
| `onChange` | `function(element, key)` |
| `width` | one unit by default |

### color

A color swatch with its label. A click opens the game's color picker.

| Field | Effect |
| --- | --- |
| `get`, `value` | a list of four numbers from 0 to 1: red, green, blue and opacity, such as `{ 1, 0.5, 0, 1 }` |
| `alpha` | `true` lets the player choose the opacity too; without it, the picker has no opacity slider |
| `onChange` | `function(element, r, g, b, a)` |

### input

A text field with a title.

| Field | Effect |
| --- | --- |
| `lines` | a number of lines above 1: the field becomes multi-line and scrolls |
| `get`, `value` | the text |
| `onChange` | `function(element, text)` |
| `width` | one unit by default |

A one-line field calls `onChange` on **Enter**; **Esc** puts the previous text back. A multi-line field calls it when it loses the focus; **Enter** goes to the next line. `onChange` is not called when the text did not change.

## Text

### heading

A title line across the content, two units wide by default. It takes `text` or `key`.

### text

A paragraph.

| Field | Default | Effect |
| --- | --- | --- |
| `size` | `"small"` | `"small"`, `"medium"` or `"large"` |
| `color` | the text color | a palette name |
| `width` | two units | the text wraps at this width |

### status

A [text](#text) in the muted color, for a secondary line. Same fields.

### timer

A countdown. Its text shows the time left, rounded up to whole seconds, such as `1h 2m`, `3m 5s` or `45s`.

```lua
local reset = win:Add("timer", {
  key = "NEXT_RESET",
  onDone = function(element) api:Print(api:L().RESET_DONE) end,
})
reset:Start(90)
```

| Field | Default | Effect |
| --- | --- | --- |
| `text`, `key` | | a label: with `%s`, the time replaces it, otherwise it follows the label |
| `size` | `"medium"` | as for [text](#text) |
| `color` | | a palette name |
| `width` | one unit | |
| `onDone` | | `function(element)`, when the time is up |

| Method | Returns | Effect |
| --- | --- | --- |
| `element:Start(seconds, onDone?)` | the element | starts the countdown, or restarts it; the text updates at once; `onDone(element)` runs when it ends, before the `onDone` field |
| `element:Stop()` | the element | stops it |
| `element:Remaining()` | a number | the seconds left, `0` when stopped |

## Containers

A container has the methods `Add`, `Clear`, `Children`, `SetOrientation` and `Layout` of a window, and the fields `layout`, `spacing`, `columns` and `wrap`. See [Windows](../guides/kit.md#windows) and [Layouts](../guides/kit.md#layouts). The `tabs` element is not itself a container: add elements to the pages that `AddTab` returns.

### bar

Elements side by side. Its size fits its content unless you give `width` or `height`.

| Field | Effect |
| --- | --- |
| `frame` | a frame around it: `"LARGE"`, `"SMALL"` or `"FLAT"` |
| `padding` | the margin inside the frame, the skin's by default (8 with a frame, 0 without) |

### grid

A [bar](#bar) that places its elements in rows of `columns`, 4 by default.

### group

A titled box. Its title is `text` or `key`. It takes `scroll`, with `width` and `height` for the visible part.

### panel

A box that the player folds and unfolds by clicking its title, which is `text` or `key`.

| Field | Default | Effect |
| --- | --- | --- |
| `expanded` | `true` | unfolded at first |
| `onToggle` | | `function(element, expanded)`, when the player or `SetExpanded` folds or unfolds it |
| `scroll` | `"NONE"` | see [Scrolling](../guides/kit.md#scrolling) |

| Method | Returns | Effect |
| --- | --- | --- |
| `element:SetExpanded(state)` | the element | folds or unfolds it; during combat, if it holds a secure element, it waits for the end of the fight |

### tabs

A row of tabs, each with its own page. The element is as wide as its widest page and as high as the strip plus the page shown, unless you give `width` or `height`.

```lua
local tabs = win:Add("tabs", { onSelect = function(element, id) api:Debug("tab " .. id) end })
local routes = tabs:AddTab("routes", { key = "ROUTES" })

routes:Add("text", { key = "NO_ROUTE" })
tabs:AddTab("builds", { key = "BUILDS" })
```

| Method | Returns | Effect |
| --- | --- | --- |
| `element:AddTab(id, fields)` | the page, a container | adds a tab; `fields` takes `text` or `key` for its label (the id by default) and the fields of a container |
| `element:Select(id)` | the element | shows that tab; an unknown id does nothing; during combat, if the tabs hold a secure element, it waits for the end of the fight |
| `element:Selected()` | the id | the id of the tab shown, `nil` without tabs |

`onSelect(element, id)` is called every time a tab is chosen, by the player or by `Select`, even when it is already shown. The first tab added is shown first.

## Collections

### list

Rows that the player selects, checks, drags, or right-clicks. Two units wide and 200 pixels high by default; it scrolls.

```lua
win:Add("list", {
  emptyKey = "NO_ITEM",
  items = {
    { text = "Frostfire", checked = true },
    { text = "Ashfall", checked = false, tip = api:L().CLOSED },
  },
  onSelect = function(element, item) api:Print(item.text) end,
  onCheck = function(element, item, checked) api:Print(item.text, checked) end,
})
```

| Field | Effect |
| --- | --- |
| `items` | the list of items, or a function that returns it |
| `rowHeight` | the height of a row, the skin's by default (20) |
| `empty`, `emptyKey` | the text shown when there is no item; `emptyKey` is a key of your translations |
| `menu` | the menu of a right-click on an item: a list, or `function(item)` that returns one |
| `drag` | `function(item)` returning what the item carries when dragged; `nil` means it cannot be dragged |
| `onSelect` | `function(element, item, mouseButton)`, after a click on an item that is not disabled; not called when the right-click opened a menu |
| `onCheck` | `function(element, item, checked)` |
| `onDrop` | see [Drag and drop](../guides/kit.md#drag-and-drop) |
| `width`, `height` | two units by 200 pixels by default |

| Item field | Effect |
| --- | --- |
| `text`, `key` | the label |
| `color` | a palette name for the label; any other name raises `EbonAPI: MyAddon: list item color "x" is not a palette color (known: ...)` |
| `checked` | `true` or `false` shows a check box before the label; the list writes the new value back into the item |
| `disabled` | `true` greys the item and ignores its clicks |
| `tip` | the tooltip text of the row |
| `menu` | the menu of a right-click on this item, instead of the list's |
| `drag` | what this item carries when dragged, instead of the list's |
| `onClick` | `function(item, mouseButton)`, called before `onSelect` |
| `onCheck` | `function(item, checked)`, called before the list's `onCheck` |

The list keeps the selection while the same item table is still in the list.

| Method | Returns | Effect |
| --- | --- | --- |
| `element:SetItems(items)` | the element | new items; `nil` empties the list |
| `element:Selected()` | the item | the item selected, your own table, or `nil` |
| `element:Select(item)` | the element | selects an item (`nil` clears the selection); does not call `onSelect` |

### tree

A [list](#list) whose items hold other items. Same fields, same methods; its items also take:

| Item field | Effect |
| --- | --- |
| `children` | the list of items under this one |
| `expanded` | `true` shows them; the tree writes the new value back into the item |

A click on an item that has children opens or closes it, and selects it. With no menu, a right-click does the same as a left-click. `element:SetNodes(items)` gives new items, like `SetItems`.

### table

Rows under column headers. A click on a header sorts the rows; a second click reverses the order. Three units wide and 200 pixels high by default; it scrolls.

```lua
win:Add("table", {
  columns = {
    { id = "name", key = "ROUTE" },
    { id = "ashes", key = "ASHES", width = 60, align = "RIGHT" },
  },
  rows = {
    { name = "Frostfire", ashes = 1200 },
    { name = "Ashfall", ashes = 850 },
  },
  onSelect = function(element, row) api:Print(row.name) end,
})
```

| Field | Effect |
| --- | --- |
| `columns` | the list of columns, set when the table is created: `id`, `text` or `key` for the header (the id by default), `width`, `align` (`"LEFT"`, `"CENTER"`, `"RIGHT"`), `sort = false` to keep a column from sorting |
| `rows` | the list of rows, or a function that returns it; each row holds one value per column `id` |
| `menu` | the menu of a right-click on a row: a list, or a function that returns one |
| `onSelect` | `function(element, row, mouseButton)` |
| `width`, `height` | three units by 200 pixels by default |

A row may also hold `tip` (the tooltip text, titled with the first cell), `menu` (instead of the table's) and `onClick(row, mouseButton)`, called before `onSelect`. Columns without `width` share the room left, at least 20 pixels each. Two values that can be read as numbers sort as numbers, anything else as text, without regard to case. A right-click on a row that has a menu opens the menu and does not select the row.

| Method | Returns | Effect |
| --- | --- | --- |
| `element:SetRows(rows)` | the element | new rows; `nil` empties the table |
| `element:SortBy(id)` | the element | sorts by a column; the same id again reverses the order |
| `element:Sorted()` | a list | a copy of the rows in the order shown |
| `element:Selected()` | the row | the row selected, your own table, or `nil` |

## Display

### progress

A bar that fills from left to right, with its text in the middle. One unit wide and 14 pixels high by default.

| Field | Default | Effect |
| --- | --- | --- |
| `value`, `max` | `0`, `1` | the amount, or functions that return it |
| `color` | the skin's | a palette name for the fill |
| `text`, `key` | | the text in the middle |
| `width`, `height` | | the size |

| Method | Returns | Effect |
| --- | --- | --- |
| `element:SetValue(value, max?)` | the element | sets the amount; a `max` of 0 or less shows an empty bar |

The fill is the share `value / max`, kept between empty and full.

### chart

Bars from left to right, scaled to the largest value. Two units wide and 60 pixels high by default.

| Field | Effect |
| --- | --- |
| `values` | a list of numbers, or a function that returns it |
| `color` | a palette name for the bars |
| `width`, `height` | the size |

| Method | Returns | Effect |
| --- | --- | --- |
| `element:SetValues(values)` | the element | draws new values; `nil` draws none |

### arrow

An arrow that points to a place on the map, or in a fixed direction, with a text under it.

| Field | Default | Effect |
| --- | --- | --- |
| `size` | the skin's, 48 | width and height |
| `color` | `"heading"` | a palette name |
| `text`, `key` | | the text under the arrow |

| Method | Returns | Effect |
| --- | --- | --- |
| `element:SetTarget(x, y)` | the element | points to a position on the current map, from 0 to 1 as `GetPlayerMapPosition` gives it; follows the player as they move and turn |
| `element:SetAngle(radians)` | the element | points in a fixed direction; `0` is the arrow as drawn |
| `element:ClearTarget()` | the element | hides the arrow |

With `SetTarget`, the arrow hides while the player's position on the map is unknown.

### model

A 3D model that the player turns by dragging and zooms with the mouse wheel; the skin sets the turning speed and the zoom limits.

| Field | Default | Effect |
| --- | --- | --- |
| `unit` | | a unit, such as `"player"` or `"target"`, or a function that returns it |
| `creature` | | a creature id, or a function that returns it |
| `model` | | a model file, or a function that returns it |
| `dress` | | `true` gives a model that can wear items, like the dressing room |
| `width`, `height` | the skin's, 160 by 220 | |

## Moving things

### slot

A row with an optional icon that can be dragged and that receives what is dropped on it. One unit wide and 24 pixels high by default.

| Field | Effect |
| --- | --- |
| `text`, `key` | the label |
| `icon` | an icon before the text: a name from `Interface\Icons` or a texture path, or a function that returns it |
| `drag` | what the slot carries when dragged, or a function that returns it; `nil` means it cannot be dragged |
| `onDrop` | `function(element, payload, source, item)` when another element of your addon is dropped on it; `function(element, { kind, id, detail })` when the player drops a spell or an item carried on the cursor; see [Drag and drop](../guides/kit.md#drag-and-drop) |
| `width`, `height` | the size |

### handle

A round grip. Dragging it with the left button moves the window that holds it, whatever the window's `move` is. The player's **Lock positions** still applies, and a window that holds a secure element does not move during combat.

| Field | Default | Effect |
| --- | --- | --- |
| `size` | the skin's, 12 | width and height |
