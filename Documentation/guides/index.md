# Guides

One page per service. Each page starts with what the service does and a short example, then lists its methods, and ends with where to watch it in game and related pages; it adds how it works, events and limits when the service has them.

| Guide | Read it when you want to |
| --- | --- |
| [Events and tickers](events.md) | React to `READY`, to what EbonAPI learns, to the game client, or run code every few seconds |
| [Logging](logging.md) | Talk to the player in chat, keep debug output silent until needed, read the trace |
| [Storage](storage.md) | Save settings per account or per character, apply defaults, migrate old data |
| [Localization](localization.md) | Translate your addon and follow the language the player chose |
| [Connecting your addon](connection.md) | Give your icon and project link, and open links in the player's browser |
| [Interface](interface.md) | Put your settings in the EbonAPI window, or follow the player's appearance in your own |
| [Kit](kit.md) | Build your own windows from EbonAPI's elements |
| [Minimap button](minimap.md) | Put a button around the minimap |
| [Skins](skins.md) | Write a skin that changes the whole look of the interface |
| [Server](server.md) | Receive run data, Soul Ashes, builds and loadouts; send requests by opcode |
| [ProjectEbonhold](ebonhold.md) | Detect the Ebonhold client and reach its services without crashing when they are absent |
| [Channel](channel.md) | Broadcast a line to every player who runs your addon |
| [Whispers](whispers.md) | Send a line, or a long stream, to one player |
| [Sharing](sharing.md) | Publish a dataset and let EbonAPI spread it between players |
| [Versions](versions.md) | Tell players when a newer version of your addon is out |
| [Echo profile](echo-profile.md) | Learn the class, build slots and ban lists of other players |
| [Performance](performance.md) | Measure your addon's memory, CPU and running frames |

For a first addon, read Events, Logging, Storage and Localization. Add the others as you need them: each one works on its own.
