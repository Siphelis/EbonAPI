# Glossary

The words these pages use. Each has one meaning.

**Addon name**
: The name given to `EbonAPI:NewAddon`. Your identity in every service: chat tag, saved data bucket, channel messages, datasets.

**Ash, Soul Ashes**
: The currency of a run. `spendable` is what can be spent, `committed` what was committed.

**Body**
: The text carried by a message: a server message, a channel line, a whisper.

**Bridge**
: The service that reads server messages and sends yours: `api:OnServer`, `api:SendServer`.

**Build**
: One slot of Echo builds on the server: a slot number, a name and its echoes.

**Channel**
: The hidden chat channel every EbonAPI addon shares. Lines are tagged with an addon name and an op.

**Consumer**
: An addon registered with `NewAddon`. `/eapi status` lists them.

**Contract error**
: A Lua error raised because a call broke the rules: wrong type, invalid name, body too long. A bug to fix.

**Dataset**
: What `api:Share` publishes: a name, a state and a text, spread between players by EbonAPI.

**Development build**
: A version text with a suffix, such as `1.2.0-3`. Compared like any other, never announced as the latest.

**Echo, echoes**
: The perks of a build, each with a spell id and a number of stacks.

**Feature**
: A flag telling whether a piece of ProjectEbonhold is present: `api:HasFeature`, `FEATURE_CHANGED`.

**Fingerprint**
: The hash of the keys a player holds, announced on the channel so that players can tell whether they differ.

**Handle**
: The object `EbonAPI:NewAddon` returns, `api` in every example. It carries every service.

**Key**
: The public part of a dataset: addon name, dataset name and state. Keys are what fingerprints are made of.

**Loadout**
: A skill tree layout from the server: an id, a name and the rank of each node.

**Migration**
: A function that runs once, per account or per character, to move saved data to a new layout.

**Op**
: The short alphanumeric word that names a kind of channel line or whisper stream within an addon.

**Opcode**
: The number that names a kind of server message. `EbonAPI.SS` and `EbonAPI.CS` give them names.

**Packet, part**
: One line of a body split for the channel (packets, 16 at most) or for a whisper stream (parts, 400 at most).

**Peer**
: Another player exchanging with this one over the channel or by whisper.

**Prefix**
: The label of an addon whisper. Each addon chooses its own.

**Queue**
: The single line of departure for everything sent, one line every 0.15 seconds, server first.

**Round**
: In sharing, the exchange started every 2 minutes with one peer whose fingerprint differs.

**Run**
: The current Ebonhold run, as the server describes it: ashes, resurrections, rerolls, freezes.

**Scope**
: Where a saved value lives: the account, or one character.

**Server state**
: What EbonAPI parsed from the server so far: run, intensity, ash, multiplier, builds, loadout. `api:State()`.

**Service**
: One group of handle methods: events, logging, storage, localization, server, channel, whispers, sharing, versions, echo profile, performance.

**Session**
: A period of play. A new session starts after 10 minutes away; some announcements happen once per session.

**State (of a dataset)**
: The whole number that says how new a dataset is. Higher wins.

**Sticky event**
: An event that keeps its last value and replays it to every later subscriber.

**Store**
: What `api:DB()` returns: `db.account`, `db.char` and the migration methods.

**Stream**
: A whisper body split into parts and reassembled on the other side, with an op and an id.

**Ticker**
: A function called every few seconds through `api:Tick`.

**Trace**
: The last 128 things that happened inside EbonAPI, shown by `/eapi trace`.

**Translation table, `L`**
: The live table `api:Locale` returns, English underneath and the active language on top.

**Whisper**
: An addon message to one player, invisible in chat.

**WoW event**
: An event of the game client, such as `PLAYER_ENTERING_WORLD`, listened to with `api:OnEvent`.
