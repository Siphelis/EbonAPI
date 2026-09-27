# Guides

One page per service. Each page follows the same plan: what the service does, a short example, how it works, the API table, the events it emits, its limits, and a `/eapi` command to see it live.

| Guide | Read it when you want to |
| --- | --- |
| [Events and tickers](events.md) | React to `READY`, to what EbonAPI learns, to the game client, or run code every few seconds |
| [Logging](logging.md) | Talk to the player in chat, keep debug output silent until needed, read the trace |
| [Storage](storage.md) | Save settings per account or per character, apply defaults, migrate old data |
| [Localization](localization.md) | Translate your addon and follow the language the player chose |
| [Server](server.md) | Receive run data, Soul Ashes, builds and loadouts; send requests by opcode |
| [ProjectEbonhold](ebonhold.md) | Detect the Ebonhold client and reach its services without crashing when they are absent |
| [Channel](channel.md) | Broadcast a line to every player who runs your addon |
| [Whispers](whispers.md) | Send a line, or a long stream, to one player |
| [Sharing](sharing.md) | Publish a dataset and let EbonAPI spread it between players |
| [Versions](versions.md) | Tell players when a newer version of your addon is out |
| [Echo profile](echo-profile.md) | Learn the class, build slots and ban lists of other players |
| [Performance](performance.md) | Measure your addon's memory, CPU and running frames |

Reading order for a first addon: events, logging, storage, localization. Then the server pages. Then the player-to-player pages.
