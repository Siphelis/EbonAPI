# 🧩 EbonAPI

**Ein Fundament unter allen Ebonhold-Addons.**

EbonAPI ist die gemeinsame Laufzeitbasis der Ebonhold-Addons von Siphelis:
[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad) und EbonStat.
Es bündelt, was jedes von ihnen früher für sich selbst erledigt hat, ohne das
anzutasten, was sie ausmacht: Jedes Addon behält seine Oberfläche, seinen Zweck
und seine Logik. Seit 1.1 trägt es außerdem alles, was zwischen Spielern
unterwegs ist: einen einzigen versteckten Kanal, eine einzige Sendewarteschlange
und das Echo-Profil, das die Matrix von EbonBuilds bei anderen Spielern liest.

EbonAPI ersetzt Ace3 nicht und dupliziert ProjectEbonhold nicht.

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

---

## Inhaltsverzeichnis

- [Warum dieses Addon](#-warum-dieses-addon)
- [Funktionen](#-funktionen)
- [Installation](#-installation)
- [Slash-Befehle](#-slash-befehle)
- [Für Addon-Autoren](#-für-addon-autoren)
- [Code-Aufbau](#-code-aufbau--wie-es-funktioniert)
- [Bekannte Grenzen](#-bekannte-grenzen)
- [Was EbonAPI nicht tun wird](#-was-ebonapi-nicht-tun-wird)
- [Sprachen](#-sprachen)
- [Lizenz & Danksagung](#-lizenz--danksagung)

---

## 🔥 Warum dieses Addon

EbonAPI installierst du nicht um seiner selbst willen: AutoCallboard,
EbonBuilds, SkillTreeAutoLoad und EbonStat weigern sich, ohne es zu laden.

Jedes von ihnen brachte früher seine eigene Server-Brücke mit, seine eigene
Sendewarteschlange, seinen eigenen Speicher und seine eigene
Spracheinstellung. Drei Brücken lasen jede Servernachricht dreimal. Drei
Warteschlangen blieben jede für sich unter dem Flood-Limit und überschritten es
gemeinsam. EbonAPI behält von allem genau eines, für alle.

## ✨ Funktionen

- **Eine Sendewarteschlange für den ganzen Client** — zuerst die Nachrichten an
  den Server, dann Kanalzeilen und Flüsternachrichten, ein Versand alle
  0,15 s. Das Flood-Limit zählt den Client, nicht jedes Addon: Drei
  unabhängige Warteschlangen überschritten es, eine einzige bleibt darunter.
- **Eine Server-Brücke** — jede Servernachricht wird einmal gelesen und an die
  Addons weitergereicht, die sie angefordert haben. Eine Nachricht, auf die
  niemand hört, kostet nichts.
- **Ein versteckter Kanal** — `ebonapi`, aus deinen Chatfenstern entfernt: Dort
  erscheint nie eine Nachricht oder ein Hinweis.
- **Eine Sprachwahl** — einmal gewählt, folgen alle Addons. Ein Addon, das diese
  Sprache nicht mitbringt, fällt für sich allein auf Englisch zurück, ohne den
  anderen Englisch aufzuzwingen.
- **Update-Hinweise** — wenn ein anderer Spieler eine neuere Version eines
  deiner Addons nutzt, erfährst du es einmal pro Sitzung, mit dem Downloadlink,
  den dein installiertes Addon angibt. Nie ein Link, der von einem anderen
  Spieler stammt.
- **Deine Echo-Builds, einmal geteilt** — deine Klasse und die Echo-Builds, die
  der Server für deinen Charakter speichert, gehen für die EbonBuilds-Matrix
  der anderen Spieler über den Kanal, und nur dann erneut, wenn sie sich ändern.
- **Fehler bleiben sichtbar** — ein Fehler in einem Addon reißt die anderen nie
  mit und verschwindet nie: Er wird mit seinem Stack an BugSack, Swatter oder
  Blizzards Fehlerfenster weitergegeben.
- **Eingebaute Diagnose** — `/eapi status` zeigt Brücke, Kanal, Warteschlange
  und ProjectEbonhold auf einen Blick; `/eapi perf` misst Speicher und CPU pro
  Addon.

## 📦 Installation

1. [**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest) — lade die neueste Version herunter.
2. Entpacke den Ordner `EbonAPI` nach
   `Interface/AddOns/`.
3. Prüfe im AddOn-Auswahlbildschirm, dass **EbonAPI** zusammen mit den Addons,
   die es nutzen, angehakt ist.

EbonAPI zeigt von sich aus nichts an. Es tritt seinem Kanal erst bei, sobald
sich ein Addon bei ihm registriert.

## 💬 Slash-Befehle

Aliase: `/eapi` und `/ebonapi`.

| Befehl | Wirkung |
| --- | --- |
| `/eapi` (oder `help`) | Listet die Befehle auf. |
| `/eapi status` | Überblick: registrierte Addons, Server-Brücke, Kanal, Sendewarteschlange, Profil, Versionen, ProjectEbonhold-Dienste, abgewiesene Nachrichten. |
| `/eapi trace [n]` | Die letzten `n` Diagnoseeinträge (standardmäßig 20). |
| `/eapi debug [addon\|*] on\|off` | Schaltet die ausführliche Ausgabe für ein Addon oder für alle ein oder aus. |
| `/eapi lang [code]` | Zeigt oder setzt die gemeinsame Sprache (`enUS`, `frFR`, `deDE`, `esES`). |
| `/eapi db` | Zusammenfassung der gespeicherten Daten. |
| `/eapi opcodes` | Bekannte Server-Opcodes. |
| `/eapi senders` | Auf der Server-Brücke beobachtete Absender. |
| `/eapi perf [addon] [label\|reset\|gc]` | Speicher, aktive Frames und CPU, pro Addon. |

Der Diagnosepuffer behält die letzten 128 Ereignisse, auch mit ausgeschaltetem
Debug: Interessant ist, was passiert ist, *bevor* jemand daran gedacht hat, die
Aufzeichnung einzuschalten. Wenn du ein Problem meldest, sind `/eapi status`
und `/eapi trace 30` die beiden Ausgaben, die sich zu kopieren lohnen.

## 🔌 Für Addon-Autoren

Alles Folgende ist der Vertrag zwischen EbonAPI und den Addons, die es nutzen.

### Erste Schritte

EbonAPI ist eine harte Abhängigkeit. In der `.toc` jedes Verbrauchers:

```
## Dependencies: EbonAPI
```

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 1)   -- Name, benötigte Major-, benötigte Minor-Version

if not api then
  return   -- inkompatible Version; EbonAPI hat den Grund bereits im Chat genannt
end
```

Die Major-Version muss exakt übereinstimmen, die Minor-Version mindestens der
angeforderten entsprechen. Danach läuft alles über dieses Handle, sodass
`api:OffAll()` alles auf einmal zurücknehmen kann.

### Fehler

Ein Fehler ist dazu da, behoben zu werden. EbonAPI entscheidet daher nichts an
seiner Stelle: Es macht ihn für denjenigen sichtbar, der ihn beheben kann, und
tritt zur Seite.

**Ein falscher Aufruf scheitert sofort.** Etwas anderes als eine Funktion an
`api:On` übergeben, einen Opcode als String an `Bridge.on`, eine fehlende
Tabelle an `api:DB`: Das sind Fehler im aufrufenden Code. Sie lösen einen
Fehler aus, der auf **die Zeile des verantwortlichen Addons** zeigt
(`error(..., 2)`), nicht auf eine Zeile von EbonAPI, an der es nichts zu
beheben gäbe. Keine dieser Funktionen gibt stillschweigend `false` zurück.

**Der Fehler eines Abonnenten wird abgefangen und wieder freigegeben.** Das
`pcall` dient nur dazu, dass ein Fehler in AutoCallboard nicht EbonStat
mitreißt. Unmittelbar danach geht er über `geterrorhandler()` weiter: Swatter,
BugSack oder Blizzards Fehlerfenster erhalten ihn mit seinem Stack, als wäre er
nie abgefangen worden.

Es gibt keine Deduplizierung, kein Stummschalten, keine automatische
Quarantäne. Ein fehlschlagender Abonnent wird nur für diese eine Verteilung
übersprungen und beim nächsten Ereignis wieder aufgerufen: Jedes Ereignis ist
ein neuer Versuch.

**Daten von außen sind keine Fehler.** Eine unlesbare Servernachricht, ein
beschädigter Spielstand, ein fehlender ProjectEbonhold-Dienst: Das ist der
Alltag eines Clients. Sie werden geprüft, behandelt und **gezählt**. Die Zahl
erscheint in `/eapi status`, denn eine Ablehnung, die niemand sieht, wäre ein
Fehler ohne Lösung dahinter.

### Ereignisse

```lua
api:On("READY", function(event, version) end)
api:Off("READY", fn)
api:OffAll()
```

Manche Ereignisse sind **haftend**: Sie spielen beim Abonnieren ihren letzten
Zustand erneut ab. Ohne das bliebe ein Addon, das nach dem Eintreffen einer
Serverangabe geladen wurde, blind bis zur nächsten Nachricht, die vielleicht
nie kommt.

| Ereignis | Haftend | Inhalt |
|---|---|---|
| `READY` | ja | Version |
| `LANGUAGE_CHANGED` | ja | Code |
| `FEATURE_CHANGED` | nein | Name, verfügbar |
| `SERVER_RUN_DATA` | ja | Run-Tabelle |
| `SERVER_ASH` | ja | `{ spendable, committed, source }`, nur veröffentlicht, wenn sich der Stand ändert |
| `SERVER_BUILDS` | ja | Build-Liste |
| `SERVER_BUILD_ACTIVE` | ja | Slot, Liste |
| `SERVER_LOADOUT` | ja | Baum-Loadout |
| `SERVER_INTENSITY` | ja | Intensitätstabelle |
| `SERVER_MULTIPLIER` | ja | Zahl |
| `SERVER_MESSAGE` | nein | Opcode, Inhalt, Absender |
| `STREAM_TIMEOUT` | nein | Opcode, ID, empfangen, gesamt |
| `SEND_FAILED` | nein | Art, dann die Zeile (Kanal, Server) oder Präfix und Ziel (Flüstern) |
| `CHANNEL_JOINED` | ja | Index des gemeinsamen Kanals |
| `CHANNEL_LOST` | nein | — |
| `PEER_OFFLINE` | nein | Name, aus der Warteschlange entfernte Sendungen |
| `UPDATE_AVAILABLE` | nein | Addon, verfügbare Version, installierte Version, Link |
| `PROFILE_SLOTS` | nein | Absender, Klasse, Slots |
| `PROFILE_BUILD` | nein | Absender, Klasse, Slot, Hash, Echos |
| `PROFILE_BANS` | nein | Absender, Klasse, Hash, Listen |

Ein Callback darf sich abonnieren oder abmelden, während er läuft.

### Client-Ereignisse und Timer

```lua
api:OnEvent("PLAYER_REGEN_DISABLED", fn)
api:OffEvent("PLAYER_REGEN_DISABLED", fn)

api:Tick("refresh", 0.5, fn)   -- die Kennung erhält den Namen des Addons als Präfix
api:Untick("refresh")
```

Ein einziger Frame trägt alles. Sein `OnUpdate` läuft nur, solange mindestens
ein Timer lebt.

Der Bus führt zwei Register pro Ereignis. Verbraucher-Abonnenten laufen über
einen geschützten Aufruf, damit ein Fehler des einen die anderen nicht
mitreißt. Kern-Abonnenten (`Bus.onCore`, EbonAPI vorbehalten) werden direkt
aufgerufen: Sie vor sich selbst zu schützen, würde niemanden schützen und bei
jedem Ereignis einen geschützten Aufruf mehr kosten. Ein Ereignis ohne
Verbraucher-Abonnenten kostet daher **keinen** Schutz.

### Server-Brücke

```lua
api:OnServer(EbonAPI.SS.PLAYER_RUN_DATA, function(body, opcode, sender) end)
api:SendServer(EbonAPI.CS.BUILD_SELECT, "3")
api:RequestServer(EbonAPI.CS.REFRESH_BUILDS, "", 30)   -- über 30 s zusammengefasst
```

Sendungen laufen über die einzige Warteschlange von `Net/Queue` (siehe
[Gemeinsamer Kanal](#gemeinsamer-kanal)): Fünf Anfragen, die drei Addons im
selben Frame abschicken, gingen verloren oder würden die Verbindung trennen.
Nachrichten an den Server haben Vorrang vor allem anderen. `RequestServer`
fasst Anfragen addonübergreifend zusammen: Der Server erhält die Anfrage nur
einmal pro Intervall. Zwei Anfragen gelten als gleich, wenn sie denselben
Opcode und denselben Inhalt tragen.

Die Empfangsgrammatik ist die Vereinigung dessen, was die drei ursprünglichen
Implementierungen akzeptierten: Eine Nachricht ohne Inhalt wird zugestellt
(zwei der drei verwarfen sie), und sowohl feste als auch variable
Fragmentbreiten werden akzeptiert.

Kosten einer empfangenen Nachricht, unabhängig von der Zahl der Abonnenten:
**ein** geschützter Aufruf, **ein** ausgewertetes Muster, **ein** Lesen der Uhr
und **keine** Allokation außer dem Inhalt selbst. Ein Opcode, auf den niemand
hört, kostet keinen Schutz.

### Gemeinsamer Kanal

```lua
api:OnChannel("A", "H", function(sender, body, letter, op) end)
api:OffChannel("A", "H", fn)
api:Say("H", "digests")                 -- unter dem Buchstaben des Addons, bei Bedarf aufgeteilt
api:IsChannelJoined()
```

Ein einziger versteckter Kanal, `ebonapi`, für alles, was sich an alle richtet.
Jedes Addon spricht dort unter seinem Buchstaben (`A` AutoCallboard,
`B` EbonBuilds, `S` SkillTreeAutoLoad, `G` EbonStat, `E` EbonAPI) und hört nur,
was es anfordert: Eine Zeile mit einem anderen Buchstaben oder einer anderen Op
endet bei einem Tabellennachschlag.

Eine Zeile hat die Form `EA1:<buchstabe>:<op>:<nr>.<k>/<n>:<stück>`, höchstens
255 Zeichen. Eine längere Nachricht geht in Paketen hinaus, höchstens sechzehn,
die pro Absender und pro Nummer wieder zusammengesetzt werden; eine Nachricht,
die nach 30 s noch unvollständig ist, wird verworfen. Ein Zeichen mit Akzent
wird nie zerteilt: Der Schnitt geht bei Bedarf ein Byte zurück, und `<n>` zählt
die tatsächlich erzeugten Pakete. Der Inhalt enthält nie `|`, da der Client
dieses Zeichen ablehnt, und `Say` scheitert, wenn man ihm eines gibt. Eine vom
Server vor die Zeile gesetzte Markierung (`[HCIV]`) wird ignoriert.

Dem Kanal wird beigetreten, sobald sich ein Addon über `NewAddon` registriert,
weil EbonAPI dann das Echo-Profil dort sendet; EbonAPI allein tritt ihm nicht
bei. Er wird aus den Chatfenstern entfernt, sodass weder Nachricht noch Hinweis
erscheint. Der Beitritt wird jede Sekunde geprüft, bis er gelingt, und alle
zehn Sekunden erneut angefordert.

**Die Warteschlange.** Alles, was den Client verlässt, läuft über `Net/Queue`:
zuerst die Nachrichten an den Server, dann Kanalzeilen und Flüsternachrichten,
ein Versand alle 0,15 s. Der Flood-Schutz zählt den ganzen Client, nicht jedes
Addon: Drei unabhängige Warteschlangen überschritten das Limit, eine einzige
bleibt darunter. Die Warteschlange für andere Spieler ist auf 500 Sendungen
begrenzt; eine Nachricht, die nicht vollständig hineinpasst, wird vollständig
abgelehnt, nie gekürzt (`Say` und `WhisperAll` geben `false` zurück).

**Spieler, die gegangen sind.** Wenn der Client auf eine Flüsternachricht mit
„Kein Spieler namens X“ antwortet, werden die Flüsternachrichten an X aus der
Warteschlange entfernt, 60 s lang abgelehnt, und `PEER_OFFLINE` benachrichtigt
das Addon. Die Systemmeldung wird nur in der Minute nach einer
Flüsternachricht abgehört: Im Ruhezustand läuft nichts.

### Flüstern

```lua
api:Whisper("ACBR", "Bob", "G:abc")          -- eine Addon-Flüsternachricht, über die Warteschlange
api:WhisperAll("ACBR", "Bob", parts, n)      -- mehrere, alle oder keine
api:OnWhisper("ACBR", function(sender, text, distribution, prefix) end)

api:WhisperStream("ACBR", "Bob", "C", hash, code)   -- ein langer Inhalt, in Stücken
api:OnWhisperStream("ACBR", "C", function(sender, body, id, op) end, onPart)
```

Was ein Spieler von einem anderen anfordert (ein öffentlicher EbonBuilds-Build,
eine AutoCallboard-Route), geht als Flüsternachricht hinaus, über dieselbe
Warteschlange wie alles andere. Der Client begrenzt eine Addon-Nachricht auf
255 Bytes **einschließlich Präfix und Tabulator**: `Whisper` scheitert
oberhalb von `255 - #präfix - 1`.

Ein Stream hat die Form `EAS:<op>:<id>:<k>/<n>:<stück>`. Er geht in höchstens
vierhundert Stücken hinaus, alle oder keines; `WhisperStream` gibt `false`
zurück, wenn er nicht in die Warteschlange passt oder der Empfänger gerade als
abwesend gemeldet wurde. Beim Eintreffen werden die Stücke pro Absender,
Präfix, Op und ID wieder zusammengesetzt; `onPart` wird bei jedem Stück außer
dem letzten aufgerufen, für einen Fortschrittsbalken; ein Stream, der nach 30 s
noch unvollständig ist, wird verworfen. Wie im Kanal wird ein Zeichen mit
Akzent nie zerteilt, und `<n>` ist die tatsächliche Zahl der Stücke.

### Echo-Profil

EbonAPI sendet selbst, unter dem Buchstaben `E`, was die Matrix von EbonBuilds
bei anderen Spielern liest: die Klasse und die Echo-Builds, die der Server für
den Charakter speichert (Opcode 540), dazu die Bannlisten, die EbonBuilds ihm
über `api:SetProfileBans(lists)` übergibt. Ein EbonAPI pro Client, also nichts
mehr zwischen Addons abzuwägen, und das Format wird nur einmal geschrieben.

| Op | Inhalt | Rolle |
|---|---|---|
| `P` | `<klasse>:<slots>` (`8:1.2.5`) | die belegten Slots |
| `D` | `<klasse>:<slot>:<hash>:<echos>` | ein Build |
| `X` | `<klasse>:<hash>:<liste>;<liste>...` | die Bannlisten |

Ein Echo passt in drei Zeichen des Alphabets `0-9 A-Z a-z - _`: zwei für den
Abstand zwischen seiner ID und 200000, eines für seine Stapel. Die Echos werden
sortiert, sodass derselbe Build immer denselben Text und denselben Hash ergibt
(`EbonAPI.Profile.Signature`, acht Zeichen). Die Klassen reichen von `WARRIOR`
1 bis `DRUID` 10, in der Reihenfolge der Matrix
(`EbonAPI.Profile.ClassIndex`).

**Wann gesendet wird.** Was bereits gesendet wurde, wird pro Charakter in
`EbonAPIDB` gespeichert: der Hash jedes Slots, die angekündigten Slots, der
Hash der Banns. Eine Zeile wird erst vermerkt, wenn sie die Warteschlange
verlassen hat, nicht wenn sie hineinkommt: Ein `/reload`, der die
Warteschlange leert, bevor sie abgearbeitet wurde, verliert also nichts, die
Zeile geht beim nächsten Laden erneut hinaus. Außer in diesem Fall sendet ein
`/reload` nichts erneut; nur ein geänderter Build geht erneut hinaus, und `P`
nur dann, wenn ein Slot hinzukommt oder wegfällt.

Eine neue Sitzung sendet alles erneut, für Spieler, die diesen Charakter noch
nicht kannten, und fordert zehn Sekunden nach dem Einloggen die Build-Liste
beim Server an. Eine Sitzung ist neu, wenn das Einloggen mehr als zehn Minuten
nach dem Ende der vorherigen erfolgt. Das Ende ist das Ausloggen oder der
`/reload` (`PLAYER_LOGOUT`); ohne sauberes Ausloggen (Absturz,
Verbindungsabbruch) zählt es ab dem vorherigen Einloggen. Ein `/reload` nach
zwei Stunden Spielzeit eröffnet also keine Sitzung.

**Beim Empfang** prüft EbonAPI die Grenzen (Klasse 1 bis 10, Slot 1 bis 20, 150
Echos pro Build, 20 Listen zu je 150) und berechnet den Hash neu; eine
beschädigte Nachricht wird gezählt und verworfen. Der Rest erreicht die
Abonnenten von `PROFILE_SLOTS`, `PROFILE_BUILD` und `PROFILE_BANS` dekodiert,
Echos und Listen als kompakter Text; `EbonAPI.Profile.DecodeBuild` und
`DecodeBans` lesen sie wieder ein, wenn ein Addon sie braucht. EbonAPI behält
nichts von den empfangenen Profilen.

Das Profil geht hinaus, sobald irgendein Addon registriert ist: EbonStat allein
genügt.

### Versionen

```lua
api:Version("2.6.0", "https://...")   -- die installierte Version und wo sie zu finden ist
api:AvailableUpdate()                 -- "2.7.0", "2.6.0", wenn eine neuere im Umlauf ist
```

Pro Sitzung geht eine einzige `V`-Zeile unter dem Buchstaben `E` hinaus, für
alle Addons zugleich: `A=2.6.0,E=1.1.0,S=1.8.0`. Nur Releases (`x.y.z`)
erscheinen darin; ein Arbeitsstand (`x.y.z-n`) bleibt für sich. Wer eine
neuere Version als die eigene hört, speichert sie für den ganzen Account in
`EbonAPIDB`, benachrichtigt den Spieler einmal pro Sitzung und löst
`UPDATE_AVAILABLE` aus; der angezeigte Link ist immer der, den das installierte
Addon angegeben hat, nie der eines anderen Spielers. Wer einen Spieler mit
älterem Stand hört, antwortet ihm nach zwei bis acht Sekunden, sofern das nicht
schon jemand getan hat. Eine gespeicherte Version wird vergessen, sobald die
installierte Version sie eingeholt hat.

### Normalisierter Serverzustand

```lua
local State = EbonAPI.State

State.GetRun()          -- 19 Felder + abgeleitete Werte (remainingRerolls, ...)
State.GetAsh()          -- ein einziger Stand, mit seiner Herkunft
State.GetBuilds()       -- jeder Slot trägt `echoes`, die Rohliste des Servers
State.activeBuild()
State.GetLoadout()
State.GetIntensity()
State.GetMultiplier()
State.snapshot("builds")   -- stabile Kopie
```

Die Getter liefern lebende Tabellen: Man liest sie, man verändert sie nicht.
Für eine losgelöste Kopie geht man über `State.snapshot()`.

Der Stand der Seelenasche kam früher über zwei unabhängige Wege (Opcode 15 bei
EbonStat, Opcode 3 bei SkillTreeAutoLoad), ohne Abgleich. Er ist jetzt
eindeutig, und `ash.source` sagt, welche Nachricht ihn gesetzt hat.

`SERVER_ASH` wird nur veröffentlicht, wenn sich der verfügbare oder gebundene
Stand ändert. Derselbe Stand, wiederholt über den einen oder anderen Opcode,
aktualisiert `ash.source` und `ash.at`, ohne etwas zu veröffentlichen: EbonStat
zeichnet Standänderungen auf und bewahrt sie dauerhaft; ein unverändert erneut
veröffentlichter Stand wäre dort nur Rauschen. Ein später Abonnent erhält über
die Wiedergabe immer den aktuellen Stand.

`State.GetIntensity()` liefert immer dieselbe Tabelle, wenn es auf
`EbonholdIntensityData` zurückfällt: Das Fenster von EbonStat liest sie viermal
pro Sekunde.

### Speicher

```lua
local db = api:DB({
  account   = { size = 10 },
  character = { position = 1 },
})

db.account.size
db.char.position        -- nil vor PLAYER_LOGIN, danach aufgelöst
api:Shared().account    -- von allen Addons geteilter Bereich
```

Alles liegt in `EbonAPIDB`: Die Daten überdauern, unabhängig davon, welche
Verbraucher installiert sind. Ein in einer späteren Version hinzugefügter
Standardwert überschreibt nie eine Wahl, die der Spieler bereits getroffen hat.

Hierhin ziehen die Addons nach und nach um, was sie aufbewahren: zuerst die
empfangenen Profile von EbonBuilds, danach die Routen und Sammlungen von
AutoCallboard, die Speicherstände von SkillTreeAutoLoad und die Builds von
EbonBuilds, ein Addon nach dem anderen. Jedes Addon behält sein Format; was
zwischen Addons geteilt wird, läuft über ein deklariertes Format, nie über das
Lesen der Tabelle eines anderen.

#### Migrationen

```lua
db:MigrateOnce("from-MyAddonDB", MyAddonDB, function(store, legacy)
  -- legacy lesen, in store schreiben
  return migratedCount   -- nil = nicht erledigt, wird erneut ausgeführt
end)

db:MigrateOncePerCharacter("key", legacy, function(store, legacy, name, key) end)
```

**Eiserne Regel, auf die harte Tour bei SkillTreeAutoLoad gelernt**: Die
Markierung „bereits migriert“ liegt in derselben Datei wie die Daten, die sie
schützt. Wenn die Markierung das überlebt, was sie bewacht, läuft die Übernahme
nicht mehr erneut, und die Daten sind endgültig verloren. Hier liegen beide in
`EbonAPIDB`. Folgerung: Eine ursprüngliche Datenbank wird nie verändert, nur
gelesen.

Eine Migration, die `nil` zurückgibt oder fehlschlägt, setzt ihre Markierung
nicht: Sie wird beim nächsten Laden erneut versucht.

### Lokalisierung

```lua
local L = api:Locale({
  enUS = { HELLO = "hello" },
  deDE = { HELLO = "hallo" },
})

api:Localized(widget, "HELLO")   -- übersetzt sich beim Sprachwechsel von selbst neu
```

Die zurückgegebene Tabelle ist lebendig: Sie wird an Ort und Stelle geleert und
neu befüllt, sodass ein oben in der Datei gehaltenes
`local L = api:Locale(...)` gültig bleibt.

Die **Wahl** der Sprache ist geteilt und wird gespeichert; die
Übersetzungstabellen bleiben bei jedem Addon. Jedes Register fällt unabhängig
auf *seine eigene* `enUS`-Basis zurück: Ist die gemeinsame Sprache `deDE` und
ein Addon liefert sie nicht, spricht dieses Addon Englisch, ohne den anderen
Englisch aufzuzwingen.

### Diagnose

Das Schreiben eines Diagnoseeintrags legt nur fünf Rohwerte ab. Formatiert wird
erst beim Lesen, sodass eine Servernachricht nichts alloziert.

Ein Addon gibt an, was gemessen werden soll: `api:Track("map", frame)` für
einen Frame, `api:TrackFunction("OnUpdate", fn)` für eine Funktion, dann
`api:Perf("after combat")` oder `/eapi perf MyAddon after combat` für einen
Bericht, gespeichert in `EbonAPIDB` (zwanzig pro Addon). Die CPU wird nur bei
eingeschaltetem Profiler gelesen (`/console scriptProfile 1`, dann `/reload`).

## 🧠 Code-Aufbau — wie es funktioniert

EbonAPI lädt in der Reihenfolge seiner `.toc`: zuerst die Grundbausteine, dann
die Sprachen, die Warteschlange, der Server, das Netzwerk und zuletzt
`Boot.lua`, das beim Einloggen alles startet. Alles hängt an der globalen
Tabelle `EbonAPI`.

### `Core/` — das Fundament

| Datei | Genaue Aufgabe |
| --- | --- |
| `Lib.lua` | Abhängigkeitsfreie Grundbausteine: Typumwandlung, Tabellen, Zeichenketten, UTF-8-Zerlegung, ein `pcall`, das berichtet. |
| `Api.lua` | Namensraum, Versionsprüfung, Verbraucher-Handles, Callback-Bus. |
| `Listeners.lua` | Abonnentenlisten, die sich ändern lassen, während sie laufen. |
| `Log.lua` | Protokoll mit Präfix und zirkulärer Diagnosepuffer. |
| `Bus.lua` | Ein einziger Frame für alle Client-Ereignisse und alle Timer. |
| `Assembler.lua` | Zusammensetzen stückweise eintreffender Nachrichten, mit Ablaufzeit. |
| `DB.lua` | `EbonAPIDB`: Account- und Charakterbereich, Standardwerte, Migrationen. |
| `Session.lua` | Sagt, ob das Einloggen eine neue Sitzung eröffnet. |
| `Format.lua` | Gemeinsame Formatierer (Zahlen, Geld, Dauern). |
| `Perf.lua` | Speicher, aktive Frames und CPU pro Addon (`/eapi perf`). |

### `Language/` und `Locales/` — das Mehrsprachensystem

| Datei | Genaue Aufgabe |
| --- | --- |
| `Language/Locale.lua` | Die Sprach-Engine und die **gemeinsame Sprachwahl**. |
| `Locales/enUS.lua`, `frFR.lua`, `deDE.lua`, `esES.lua` | Die eigenen Meldungen von EbonAPI, in vier Sprachen. |

### `Net/` — zwischen Spielern

| Datei | Genaue Aufgabe |
| --- | --- |
| `Queue.lua` | **Die einzige** Sendewarteschlange: Server, Kanal, Flüstern. |
| `Channel.lua` | Der gemeinsame Kanal `ebonapi`, seine Pakete, einfache Flüsternachrichten. |
| `Whisper.lua` | Empfang von Flüsternachrichten nach Präfix und stückweise Streams. |
| `Profile.lua` | Das Echo-Profil des Spielers, an einer einzigen Stelle kodiert, gesendet und gelesen. |
| `Version.lua` | Die Versionen der Addons, einmal pro Sitzung angekündigt. |

### `Server/` — der Austausch mit dem Server

| Datei | Genaue Aufgabe |
| --- | --- |
| `Opcodes.lua` | Karte der beobachteten AAM0x9-Opcodes. |
| `Bridge.lua` | **Die einzige** Server-Brücke: Parser, Zusammensetzer, Versand über die Warteschlange. |
| `Ebonhold.lua` | ProjectEbonhold-Fassade, mit Erkennung und geordnetem Rückzug, wenn etwas fehlt. |
| `State.lua` | Normalisierter Serverzustand, einmal für alle veröffentlicht. |

### Im Wurzelverzeichnis

| Datei | Genaue Aufgabe |
| --- | --- |
| `Boot.lua` | Der Start: bindet `EbonAPIDB` beim Laden an; startet beim Einloggen Brücke, Zustand, Kanal, Profil und Versionen; löst `READY` aus; wertet die `/eapi`-Befehle aus. |
| `EbonAPI.toc` | Das WoW-Manifest: Metadaten, gespeicherte Variable (`EbonAPIDB`) und Ladereihenfolge der Dateien. |

## 🚧 Bekannte Grenzen

- **Stückweises Senden an den Server ist nicht implementiert.** Kein Addon im
  Einsatz nutzt es, also beweist nichts, dass der Server es zusammensetzen
  kann. Die Grenze von 240 Bytes ist daher real und endgültig: Sie zu
  überschreiten ist ein Aufruffehler, und `Bridge.send` löst einen Fehler aus,
  der Größe und Grenze nennt. Der gemeinsame Kanal dagegen teilt auf (höchstens
  sechzehn Pakete).
- **Der Absenderfilter ist standardmäßig aktiv.** Nur eine Flüsternachricht des
  Spielers an sich selbst gilt als vom Server kommend: Ohne Filter könnte jeder
  Spieler der Gruppe, des Schlachtzugs oder der Gilde auf `AAM0x9` posten. Er
  wurde im Spiel überprüft (die Build-Liste kommt an, das Profil geht hinaus).
  Sollte der Server eines Tages unter einem anderen Namen antworten, bliebe die
  Brücke stumm: `/eapi senders` zeigt die empfangenen Namen, und
  `EbonAPI.Bridge.setStrictSender(false)` schaltet den Filter ab.
- **Eine im Kanal angekündigte Version wird geglaubt.** Nichts signiert eine
  `V`-Zeile: Ein Spieler, der `A=99.0.0` ankündigt, lässt die
  AutoCallboard-Nutzer, die ihn hören, „Version 99.0.0 verfügbar“ sehen, und
  der Wert bleibt gespeichert, bis die installierte Version ihn eingeholt hat.
  Der angezeigte Link hingegen kommt nie aus dem Kanal.
- **Das Profil trägt nur die Echos 200000 bis 204095.** Eine ID außerhalb
  dieses Bereichs wird ohne Meldung aus dem gesendeten Build entfernt.
- **Die Opcode-Karte wird von Hand gepflegt.** `Server/Opcodes.lua` übernimmt
  die beobachteten (`EbonAPI.SS`, `EbonAPI.CS`); ändert ProjectEbonhold sie,
  zieht sie nicht von selbst nach. Die von ProjectEbonhold definierten lassen
  sich zur Laufzeit auch über `EbonAPI.Ebonhold.OpcodeCS(name)` lesen, und
  `EbonAPI.Ebonhold.SendToServer(name, body)` sendet über ProjectEbonhold
  selbst.
- **Eine unvollständige, stückweise eintreffende Servernachricht kann bis zu
  22 s überleben** (20 s Ablaufzeit plus eine Bereinigungsperiode), bevor sie
  freigegeben wird.

## 🚫 Was EbonAPI nicht tun wird

Konfiguration, High-Level-Timer, generische Hooks, Serialisierung: Das macht
Ace3 besser. Das Spaltenformat von EbonStat, die Reisedaten von AutoCallboard,
das Auslesen des Baums bei SkillTreeAutoLoad, die Matrix-Notizen von
EbonBuilds: Das ist Fachlogik und bleibt bei ihnen. EbonAPI transportiert und
speichert, es urteilt nicht.

## 🌍 Sprachen

Englisch, Französisch, Deutsch und Spanisch sind für die eigenen Meldungen von
EbonAPI vollständig enthalten. Die mit `/eapi lang` oder im Sprachmenü eines
Addons gewählte Sprache gilt für alle Addons, die ihre Übersetzungen EbonAPI
anvertrauen.

## 📜 Lizenz & Danksagung

Addon von **Siphelis**.
Entwickelt auf Basis von ProjectEbonhold, der clientseitigen Oberfläche des
Ebonhold-Servers.

EbonAPI steht unter der [PolyForm Strict License 1.0.0](LICENSE): Du darfst es
für nichtkommerzielle Zwecke nutzen, es aber **weder verkaufen noch verändern
noch weiterverbreiten**. Dazu gehören die Veröffentlichung auf einer
Addon-Seite, die Aufnahme in ein Paket oder die Verbreitung einer veränderten
Version. Frag vor jeder solchen Nutzung um Erlaubnis.

---
