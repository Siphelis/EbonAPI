# Errors

Every message EbonAPI can raise, what raised it, and how to fix the call.

A raised error means a **contract error**: the calling code passed something EbonAPI cannot accept. It is a bug to fix, not a condition to handle. Runtime conditions never raise; they come back as `false` or `nil`, and as events. See [Concepts: errors and messages](../concepts.md#errors-and-messages).

You see these errors where the game shows Lua errors: with `/console scriptErrors 1`, or with an error-display addon. Players with default settings never see them. Every message is in English.

Some problems are not raised. EbonAPI reports them to the same error display and carries on. Those are marked "not raised" below.

## Handle and events

| Message | Fix |
| --- | --- |
| `EbonAPI:NewAddon expects a non-empty addon name, got nil` | pass your addon name as a string |
| `EbonAPI:NewAddon: addon name "My Addon" must be 1 to 32 letters, digits or "_"` | remove spaces and punctuation, shorten the name |
| `EbonAPI:NewAddon: "MyAddon": the fourth argument must be a table (icon, updates, url, version), got string` | pass the connection options as a table, or leave the fourth argument out |
| `EbonAPI:NewAddon: "MyAddon": unknown connection option "link" (known: icon, updates, url, version)` | use one of the options listed |
| `EbonAPI:NewAddon: "MyAddon": connection option "url" expects a non-empty text, got number` | give `icon`, `url` and `version` as texts; an empty text is refused too, and the message then ends with `got an empty text` |
| `EbonAPI:NewAddon: "MyAddon": the required major version must be a number, got string` | pass the second and third arguments as numbers, or leave them out; the message says `minor` for the third |
| `EbonAPI:NewAddon: "MyAddon": connection option "updates" expects a boolean, got string` | pass `true` or `false` |
| `EbonAPI:NewAddon: "MyAddon": updates needs a version, from the version option or ## Version in the .toc, got nil` | add a `## Version: 1.0.0` line to the `.toc`, or pass `version`; the text must read `major.minor.patch`, such as `1.2.0` or `1.2.0-3` |
| `EbonAPI: the event name must be a string, got number` | pass the event name as a string |
| `EbonAPI: the callback for 'READY' must be a function, got nil` | pass a function; check that it is defined before you call `api:On` |

## WoW events and tickers

| Message | Fix |
| --- | --- |
| `EbonAPI.Bus.on expects an event name, got nil` | pass the WoW event name as a string |
| `EbonAPI.Bus.on expects a function for 'BAG_UPDATE', got table` | pass a function |
| `EbonAPI:Tick expects a ticker id, got nil` | pass the ticker id as a string |
| `EbonAPI:Tick expects a function for 'poll', got nil` | pass a function; the name in the message is the ticker id you gave |
| `EbonAPI:Tick: invalid interval for 'poll', expected a number above 0, got 0` | the interval must be a number greater than zero |

## Storage

| Message | Fix |
| --- | --- |
| `EbonAPI: the defaults of 'MyAddon' must be a table, got string` | pass `{ account = {...}, character = {...} }`; `false` is refused too, and the message then ends with `got boolean` |
| `EbonAPI: the account defaults of 'MyAddon' must be a table, got string` | give `account` a table; the message says `character` when that part is wrong |
| `EbonAPI: the migration key must be a string, got number` | name the migration with a string |
| `EbonAPI: migration 'import' expects a function, got nil` | pass the migration function as the third argument |

Not raised: when the migration function itself raises, the error display shows `[MyAddon] migration 'import' failed: ` followed by the error text. The migration is not marked as done, so it runs again the next time. A migration function that returns `nil` or `false` is not marked as done either.

## Localization

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: api:Locale expects a table of translations, got string` | pass a table keyed by language code |
| `EbonAPI: MyAddon: api:Localized expects a translation key, got nil` | pass the key as a string |
| `EbonAPI: MyAddon: api:Localized expects a widget with SetText for the key 'TITLE', got table` | pass a font string, button or edit box, not a frame; `nil` is refused too, and the message then ends with `got nil` |

## Links

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: api:OpenLink expects a URL text, got nil` | pass the link as a non-empty string |
| `EbonAPI:OpenLink expects a URL text, got nil` | the same, for the global function |
| `EbonAPI: MyAddon: api:OpenLink expects a URL text, got an empty string` | an empty text is refused too; `EbonAPI:OpenLink` says the same |

Not raised: when the game's own function that opens or copies the link fails, the error is reported to the error display and the call returns `nil`.

## Interface

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: unknown parameter "color" (known: background, accent, scale, opacity, shadow, corners, tabs, locked)` | use one of the names listed; the global `EbonAPI:GetParameter` raises the same message without the addon name |
| `EbonAPI: MyAddon: parameter "scale" expects a number from 0.2 to 1.4, got 2` | pass a value in range |
| `EbonAPI: MyAddon: parameter "corners" expects a whole number from 0 to 16, got 2.5` | pass a whole number |
| `EbonAPI: MyAddon: parameter "accent" expects a color 0xRRGGBB (0 to 16777215), got 16777216` | pass a color such as `0x3FA7F5` |
| `EbonAPI: MyAddon: parameter "tabs" expects one of LEFT, RIGHT, got TOP` | pass `"LEFT"` or `"RIGHT"` |
| `EbonAPI: MyAddon: parameter "locked" expects a boolean, got string` | pass `true` or `false` |
| `EbonAPI: MyAddon: the options table must be a group (type = "group")` | wrap your options in a root group with `args` |
| `EbonAPI: MyAddon: option "general" must be a table, got string` | every entry of `args` is a table |
| `EbonAPI: MyAddon: option "general" (group) needs an args table` | give every group an `args` table |
| `EbonAPI: MyAddon: option "general.volume" has an unknown type "slider" (known: color, description, execute, group, header, input, range, select, toggle)` | use one of the types listed |
| `EbonAPI: MyAddon: option "general.volume" needs a name (string or function), got nil` | give every option a `name` |
| `EbonAPI: MyAddon: option "sounds" (toggle) needs get and set, on itself or on a parent group` | add `get` and `set` to the option or to a group above it |
| `EbonAPI: MyAddon: option "general.volume" (range) needs numeric min and max, with min below max` | give `min` and `max` |
| `EbonAPI: MyAddon: option "mode" (select) needs values (table, function or method name)` | give `values` |
| `EbonAPI: MyAddon: option "mode" (select) sorting must be a table or a function, got string` | give `sorting` a list of keys, or a function that returns one |
| `EbonAPI: MyAddon: option "reset" (execute) needs a func, on itself or on a parent group` | give `func` |
| `EbonAPI: MyAddon: option "sounds" width must be "half", "normal", "double", "full" or a number, got huge` | use one of the widths listed |
| `EbonAPI: MyAddon: option "sounds" get must be a function or a method name, got number` | pass a function, or the name of a method of `handler`; the same message exists for `set`, `func`, `disabled`, `hidden` and `values` |
| `EbonAPI: MyAddon: option "sounds" desc must be a string or a function, got number` | give `desc` a text or a function |
| `EbonAPI: MyAddon: option "sounds" order must be a number or a function, got string` | give `order` a number or a function |
| `EbonAPI: MyAddon: option "sounds" handler must be a table, got string` | give `handler` a table holding your methods |
| `EbonAPI: MyAddon: option "general.volume" (range) step must be a positive number` | give `step` a number above zero, or leave it out |
| `EbonAPI: MyAddon: option "general.volume" (range) softMin must be a number` | `softMin`, `softMax` and `bigStep` are numbers |
| `EbonAPI: MyAddon: the options table has a key of type number in args, keys must be strings` | key `args` by name, not by index |
| `EbonAPI: MyAddon: option "general" contains itself` | a group cannot contain itself |
| `EbonAPI: MyAddon: OpenOptions needs options registered with api:Options first` | call `api:Options` before `api:OpenOptions`; `EbonAPI:OpenOptions("MyAddon")` raises the same message for an addon with no options, and for a name EbonAPI does not know |

Not raised: `EbonAPI: MyAddon: option "MyAddon.general.mode": method "GetMode" not found on its handler`. It appears when a field names a method that `handler` does not have, or when there is no `handler`. While the window draws the page, it is reported and the option is left out. The error of a `get`, `name`, `desc` or `values` function is reported the same way and only that option is left out. The error of a `set` or `func` function is reported when the player changes the value or clicks the button.

## Kit

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: api:Window expects an id of letters, digits or _, got main window` | name the window with letters, digits and `_` only, such as `main_window` |
| `EbonAPI: MyAddon: api:Window expects a table, got string` | pass the window's fields as a table, or nothing |
| `EbonAPI: MyAddon: scroll expects NONE, VERTICAL, HORIZONTAL or BOTH, got DOWN` | give `scroll` one of the four values, on `api:Window`, `group` or `panel` |
| `EbonAPI: MyAddon: element "text" does not scroll, it does not accept scroll` | only `group`, `panel` and windows take `scroll` |
| `EbonAPI: MyAddon: layout expects VERTICAL, HORIZONTAL, GRID, FLOW or NONE, got DIAGONAL` | give `layout` one of the five values; only `bar`, `grid`, `group`, `panel` and windows take it |
| `EbonAPI: MyAddon: SetOrientation expects VERTICAL, HORIZONTAL, GRID, FLOW or NONE, got DIAGONAL` | pass one of the five values to `container:SetOrientation` |
| `EbonAPI: MyAddon: frame expects flat, small or large, got thick` | give `frame` on a `bar` or a `grid` one of the three names, in any case |
| `EbonAPI: MyAddon: spacing expects a number, got x` | `spacing`, `wrap`, `padding`, `columns`, `min`, `max` and `step` are numbers |
| `EbonAPI: MyAddon: columns expects a whole number of at least 1, got 0` | give `columns` a whole number from 1 up |
| `EbonAPI: MyAddon: step expects a number above 0, got 0` | give a `range` a `step` above zero, or leave it out |
| `EbonAPI: MyAddon: range expects min lower than max, got min 5 and max 1` | give a `range` a `min` lower than its `max` |
| `EbonAPI: MyAddon: tip expects a string or a function, got 5` | `tip` and `link` are texts or functions |
| `EbonAPI: MyAddon: tipKey expects a string, got 5` | give `tipKey` the key of a text of your addon, as a string |
| `EbonAPI: MyAddon: color expects a palette color, got red (known: bg, bgSoft, ...)` | give `color` the name of a palette color; the message lists all 31 |
| `EbonAPI: MyAddon: onClick expects a function, got 5` | every field that starts with `on` and a capital letter, and `preClick`, is a function |
| `EbonAPI: MyAddon: element "heading" does not handle onClick` | `onClick`, `menu` and `shortcut` belong to `button`, `secure`, `icon`, `slot` and `handle`; `menu` also to `list`, `tree` and `table` |
| `EbonAPI: MyAddon: shortcut expects an id of letters, digits or _, got my key` | give `shortcut` letters, digits and `_` only, or `false` |
| `EbonAPI: MyAddon: shortcut expects a target, the shortcut name of the element it binds, got nil` | give a `shortcut` element the `target` it binds, as a non-empty string |
| `EbonAPI: MyAddon: name expects a frame name of letters, digits or _, got my name` | name a `secure` or `icon` element with letters, digits and `_` only |
| `EbonAPI: MyAddon: the frame name "MyButton" is already used` | pick a name no other frame or global variable uses |
| `EbonAPI: MyAddon: element "text" cannot be disabled` | only elements that can be greyed out take `disabled`; windows, `heading`, `text`, `status`, `bar`, `grid`, `group`, `panel` and `tabs` do not |
| `EbonAPI: MyAddon: SetAction expects a table with macro, spell or item, got nil` | pass a table such as `{ spell = "Heal" }` to `SetAction` |
| `EbonAPI: MyAddon: macro expects a string, got 5` | `macro`, `spell` and `item` are strings |
| `EbonAPI: MyAddon: element "icon" is not secure, give it macro, spell or item to accept SetAction` | create the `icon` with a `macro`, `spell` or `item` first |
| `EbonAPI: MyAddon: AddTab expects an id that is a string or a number, got nil` | give every tab a string or a number as id |
| `EbonAPI: MyAddon: AddTab id "one" is already used` | give each tab of the same `tabs` element its own id |
| `EbonAPI: lines:Add expects a palette color, got red (known: bg, bgSoft, ...)` | give `lines:Add` and `lines:Pair` the name of a palette color; raised from a tip function, it is reported, not raised |
| `EbonAPI: MyAddon: api:Dialog expects a table, got string` | pass the dialog's fields as a table; for a yes or no question, `api:Confirm(text, onYes, onNo)` takes plain arguments |
| `EbonAPI: MyAddon: api:Dialog choices expects tables with text and value, got x at 1` | make every choice a table with `text` and `value`; the message gives the position of the bad one |
| `EbonAPI: MyAddon: api:Notify expects a table, got string` | pass the options as a table, or leave the second argument out |
| `EbonAPI: MyAddon: unknown element "slider" (known: arrow, bar, button, chart, color, grid, group, handle, heading, icon, input, list, model, panel, progress, range, secure, select, shortcut, slot, status, table, tabs, text, timer, toggle, tree)` | use one of the elements listed; `api:Elements()` returns the same list |
| `EbonAPI: MyAddon: element "button" expects a table, got string` | pass the element's fields as a table, or nothing |
| `EbonAPI: MyAddon: a secure element cannot be created during combat` | create `secure` elements, and `icon` elements with a `spell`, `item` or `macro`, out of combat; `api:AfterCombat(fn)` runs `fn` once the fight is over |
| `EbonAPI: MyAddon: list item color "red" is not a palette color (known: bg, bgSoft, card, border, borderDim, button, buttonBorder, buttonHover, buttonDisabledBorder, buttonText, buttonDisabledText, checkbox, checkboxBorder, checked, thumb, selected, selectedText, text, muted, title, heading, menu, shadow, focus, buttonHoverFill, rowHover, headerBg, navBg, pageBg, footerBg, success)` | give `color` one of the names listed, or leave it out; the error comes when you pass the items, to the element or to `SetItems` or `SetNodes`, and nothing is stored |
| `EbonAPI: MyAddon: api:SetShortcut expects an id of letters, digits or _, got nil` | pass the same id as the `shortcut` field of the element, letters, digits and `_` only |
| `EbonAPI: MyAddon: api:AfterCombat expects a function, got nil` | pass a function |

## Minimap button

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: api:MinimapButton expects a table, got string` | pass the button's fields as a table, or nothing |
| `EbonAPI: MyAddon: api:MinimapButton display expects BUTTON, GROUP or HIDDEN, got SHOWN` | give `display` one of the three values |
| `EbonAPI: MyAddon: api:MinimapButton angle expects a number, got x` | give `angle` a number |
| `EbonAPI: MyAddon: api:MinimapButton does not take width, EbonAPI sets the size, place and state of the button` | leave out `width`, `height`, `point` and `disabled` |

## Skins

| Message | Fix |
| --- | --- |
| `EbonAPI: RegisterSkin expects a skin name, got nil` | pass the skin's name as a non-empty string |
| `EbonAPI: RegisterSkin: skin "Night" expects a table, got string` | pass the skin's values as a table |
| `EbonAPI: RegisterSkin: skin "Night" is already registered` | give the skin a name no other skin uses |
| `EbonAPI: Bricks.build: no built-in brick "glass" for slot "range"` | `B.build(slot, name, parent)` builds only the bricks that come with EbonAPI; use one of those names for that slot, such as `default` |

The problems below are not raised. EbonAPI reports every problem of the skin to the same error display, does not register the skin, and `EbonAPI:RegisterSkin` returns `false`. Fix them all and register the skin again. Each message starts with `EbonAPI: skin "Night": `.

| Message, after the skin name | Fix |
| --- | --- |
| `unknown parameter "header.colour"` | check the path of the parameter |
| `section "header" expects a table, got number` | a section such as `header` holds a table of parameters |
| `parameter "header.height" is given twice, flat and nested` | give each parameter once, either as `header = { height = 30 }` or as `["header.height"] = 30` |
| `parameter "kit.scroll.height" expects a whole number from 40 to 2000, got 10` | give a value in the range named in the message |
| `parameter "palette.text" expects a color 0xRRGGBB or { 0xRRGGBB, alpha from 0 to 1 }, got white` | give a number such as `0xFFFFFF`, or a pair such as `{ 0xFFFFFF, 0.8 }` |
| `parameter "page.addons" expects one of CARDS, LIST, got GRID` | give one of the values listed |
| `parameter "widgets.button.brick" expects a brick name, got 5` | give the name of a brick, as a non-empty text |
| `parameter "header.title.font" expects one of button, large, normal, small, got huge` | give one of the four text sizes listed |
| `parameter "header.title.color" expects a palette color name (bg, bgSoft, ...), got red` | give the name of a palette color; the message lists all 31 |
| `parameter "media.solid" expects a texture path, or "" for none, got number` | give a texture path as a text, or `""` for none; sound parameters say `a sound path` |
| `parameter "window.glass.enabled" expects a boolean, got string` | pass `true` or `false` |
| `parameter "fonts.normal.file" expects a font file or "game", got 5` | give the path of a font file, or `"game"` |
| `parameter "windows.detach.list" expects a list of texts, got number` | give a table of texts; a bad item adds `at` and its number |
| `parameter "header.close.glyph" expects a text, got number` | give a text |
| `keys must be texts, got 1 in "(root)"` | name every value; the message says in which section the numbered key is |
| `parent must be a skin name, got number` | give `parent` the name of another skin |
| `bricks must be a table of slots, got string` | write `bricks = { button = { glass = function(parent, B) ... end } }` |
| `unknown brick slot "slider" (known: button, close, color, execute, group, heading, input, minimap, range, row, scroll, section, select, tab, text, toggle)` | use one of the slots listed |
| `brick slot "button" expects a table of name = constructor, got function` | put each constructor under a name: `button = { glass = function(parent, B) ... end }` |
| `brick "button.glass" must be a function, got table` | give the brick a constructor function |

Two more are reported when EbonAPI applies the player's skin, at login and after a reload. The values that could not be inherited come from the default skin.

| Message, after the skin name | Fix |
| --- | --- |
| `unknown parent "Nigth"` | check the name given to `parent` |
| `parent loop at "Night"` | two skins name each other as parent, directly or through others; break the loop |

A brick that cannot be used is reported when EbonAPI builds it, and the default brick of the slot takes its place:

| Message | Fix |
| --- | --- |
| `EbonAPI: brick "glass" of slot "button" is not registered, the default one applies` | register the brick under `bricks`, or check the name given to the parameter that chooses it, such as `widgets.button.brick` |
| `EbonAPI: brick "glass" of slot "button" failed, the default one applies: the method "TextWidth" is missing` | give the widget the method or the field named in the message |
| `EbonAPI: brick "glass" of slot "button" failed, the default one applies: the constructor returned nil` | return the widget from the constructor |

A failing constructor reports its own error text after `the default one applies: `. Each brick is reported once per session. A `range` brick whose `SetFormat` function raises reports `EbonAPI: range formatter failed: ` followed by the error text, once for each formatter, and shows the value with the default display. Calling `SetFormat` again re-arms the report.

## Server

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: api:OnServer expects a numeric opcode, got string` | use `EbonAPI.SS.NAME`, a number |
| `EbonAPI: MyAddon: api:OnServer expects a function for opcode 13, got nil` | pass a function |
| `EbonAPI.Bridge.on expects a numeric opcode, got string` | the same, for `EbonAPI.Bridge.on` |
| `EbonAPI.Bridge.on expects a function for opcode 13, got nil` | pass a function |
| `EbonAPI.Bridge.send expects a numeric opcode, got string` | use `EbonAPI.CS.NAME`, a number |
| `EbonAPI.Bridge.send: payload of 260 bytes for opcode 341, the limit is 240` | shorten the body; the number in the message is the total you must stay under |

Not raised: when a ProjectEbonhold function called by EbonAPI raises, its own error text is reported, unchanged.

## Channel

| Message | Fix |
| --- | --- |
| `EbonAPI.Channel.on expects an alphanumeric op for MyAddon, got my-op` | letters and digits only; `EbonAPI.Channel.say` raises the same message under its own name |
| `EbonAPI.Channel.on expects a function for MyAddon:ROUTE, got nil` | pass a function |
| `EbonAPI.Channel.say expects a text body for MyAddon:ROUTE, got table` | encode the body as a string |
| `EbonAPI.Channel.say: the body of MyAddon:ROUTE contains '|'` | remove or encode the `|` character |
| `EbonAPI.Channel.say: op too long for MyAddon:ROUTE` | shorten the op |
| `EbonAPI.Channel.say: body of 4000 bytes for MyAddon:ROUTE, the limit is 3664 bytes` | split the content, or use a whisper stream; the limit in the message depends on the length of the op |

These errors are raised at the call, whether or not the channel is joined.

## Whispers

| Message | Fix |
| --- | --- |
| `EbonAPI.Channel.whisper expects a prefix, got nil` | pass your prefix as a non-empty string |
| `EbonAPI.Channel.whisper: text missing or beyond 246 bytes for prefix MyAddonW` | shorten the text, or use a stream |
| `EbonAPI.Whisper.on expects a prefix, got nil` | pass your prefix; `onStream` and `stream` raise the same message under their own names |
| `EbonAPI.Whisper.on expects a function for MyAddonW, got nil` | pass a function |
| `EbonAPI.Whisper.onStream expects an alphanumeric op, got my-op` | letters and digits only; `stream` raises the same message |
| `EbonAPI.Whisper.onStream expects a function for MyAddonW:ROUTE, got nil` | pass a function |
| `EbonAPI.Whisper.stream expects a text body for MyAddonW:ROUTE, got table` | encode the body as a string |
| `EbonAPI.Whisper.stream: invalid stream id for MyAddonW:ROUTE` | the id is a non-empty string without `:`, or `nil` |
| `EbonAPI.Whisper.stream: header too long for MyAddonW:ROUTE` | shorten the prefix, the op or the id |
| `EbonAPI.Whisper.stream: body of 100000 bytes for MyAddonW:ROUTE, the limit is 90400 bytes` | split the content; the limit in the message depends on the length of the prefix, the op and the id |
| `EbonAPI.Channel.whisperAll expects a prefix, got nil` | pass your prefix as a non-empty string |
| `EbonAPI.Channel.whisperAll: text missing or beyond 246 bytes for prefix MyAddonW` | every part must be a text within the limit; nothing is sent when one part is wrong |

## Sharing

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: share key name must be a string, got number` | pass the dataset name as a string |
| `EbonAPI: MyAddon: share key name is empty` | give it a name |
| `EbonAPI: MyAddon: share key "my notes" contains a space (allowed: letters, digits and "_")` | remove the character named in the message; it can also read `a control character (byte 9)` or `the character "é"` |
| `EbonAPI: MyAddon: share key "a_dataset_name_that_is_far_too_long" is 35 characters long (maximum 32)` | shorten the name |
| `EbonAPI: MyAddon: share key "notes": state must be a whole number, got table` | pass a number or a string of digits |
| `EbonAPI: MyAddon: share key "notes": state 1.5 is not a whole number (0 to 9007199254740991)` | pass a whole number in range |
| `EbonAPI: MyAddon: share "notes": text must be a string, got table` | encode the content as a string |
| `EbonAPI: MyAddon: share "notes": text is 40000 bytes long (maximum 32768)` | shorten or split the content |
| `EbonAPI: MyAddon: share "notes": text differs but the state is still 1 (raise the state to share a new text)` | raise the state when the text changes |
| `EbonAPI: MyAddon: ShareRule expects a function or nil, got string` | pass a function, or `nil` to remove the rule |

Not raised: when your rule function raises while a player offers a dataset, its error text is reported and that dataset is not fetched.

## Echo profile

| Message | Fix |
| --- | --- |
| `EbonAPI: MyAddon: SetProfileBans expects a table of lists, got string` | pass a list of lists of spell ids |
| `EbonAPI: MyAddon: SetProfileBans expects a table of lists of echo ids, list 1 is a string` | every item of the outer list is itself a list; the message gives the position of the bad one |

## Errors inside your own functions

Your functions run under protection: a handler of `api:On` or `api:OnEvent`, a ticker, a migration, a Kit callback such as `onClick`, `onAccept` or `onSelect`, a function of the options table. When one raises, EbonAPI reports the error text as is, to the error display, and carries on. It does not stop the other handlers or the load of your addon. When the game has no error display, the text appears in the chat as `[EbonAPI] ` followed by the text. The error is also recorded in the trace, under your addon name. Functions queued with `api:AfterCombat` are reported the same way, whether they run at once or after combat, and their error never reaches the caller.

`api:Error(text)` reports your own text the same way, prefixed with your addon name in brackets, such as `[MyAddon] text`.

## Messages to the player

These are not errors. They are printed in the player's language, through EbonAPI's own translations.

| Situation | English text |
| --- | --- |
| `NewAddon` asked for a newer EbonAPI | `EbonAPI 2.0.0 is too old for MyAddon, which needs 2.1.` |
| A newer release of an addon was seen | `version 1.3.0 is available (installed: 1.2.0).` followed by the link |
| The channel could not be joined after four requests | `channel ebonapi not joined after 4 requests: the client may have no channel slot left; still trying` |
