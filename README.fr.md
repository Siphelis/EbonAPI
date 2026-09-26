# 🧩 EbonAPI

**Un seul socle sous tous les addons Ebonhold.**

EbonAPI est le socle commun des addons Ebonhold de Siphelis :
[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad) et EbonStat.
Il mutualise ce que chacun faisait de son côté, sans toucher à ce qui fait leur
identité : chaque addon garde son interface, son but et sa logique métier.
Depuis la 1.1, il porte aussi tout ce qui circule entre les joueurs : un seul
canal caché, une seule file d'envoi, et le profil d'échos que la matrice
d'EbonBuilds lit chez les autres.

EbonAPI ne remplace pas Ace3 et ne duplique pas ProjectEbonhold.

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

---

## Table des matières

- [Pourquoi cette extension](#-pourquoi-cette-extension)
- [Fonctionnalités](#-fonctionnalités)
- [Installation](#-installation)
- [Commandes slash](#-commandes-slash)
- [Pour les auteurs d'addons](#-pour-les-auteurs-daddons)
- [Anatomie du code](#-anatomie-du-code--comment-ça-fonctionne)
- [Limites connues et assumées](#-limites-connues-et-assumées)
- [Ce qu'EbonAPI ne fera pas](#-ce-quebonapi-ne-fera-pas)
- [Langues](#-langues)
- [Licence et crédits](#-licence-et-crédits)

---

## 🔥 Pourquoi cette extension

On n'installe pas EbonAPI pour lui-même : AutoCallboard, EbonBuilds,
SkillTreeAutoLoad et EbonStat refusent de se charger sans lui.

Chacun apportait son propre pont serveur, sa propre file d'envoi, son propre
stockage et son propre réglage de langue. Trois ponts lisaient chaque message
du serveur trois fois. Trois files restaient chacune sous la limite anti-flood,
et la dépassaient ensemble. EbonAPI en garde un seul exemplaire, pour tous.

## ✨ Fonctionnalités

- **Une seule file d'envoi pour tout le client** — les messages au serveur
  d'abord, puis les lignes du canal et les chuchotements, un envoi toutes les
  0,15 s. L'anti-flood compte le client entier, pas chaque addon : trois files
  indépendantes le dépassaient, une seule reste dessous.
- **Un seul pont serveur** — chaque message du serveur est lu une fois et remis
  aux addons qui l'ont demandé. Un message que personne n'écoute ne coûte rien.
- **Un seul canal caché** — `ebonapi`, retiré de vos fenêtres de discussion :
  ni message ni notice n'y apparaît jamais.
- **Un seul choix de langue** — choisie une fois, suivie par tous les addons.
  Un addon qui ne fournit pas cette langue repasse seul en anglais, sans
  imposer l'anglais aux autres.
- **Avis de mise à jour** — quand un autre joueur utilise une version plus
  récente de l'un de vos addons, vous êtes prévenu une fois par session, avec
  le lien de téléchargement donné par l'addon installé. Jamais un lien venu
  d'un autre joueur.
- **Vos builds d'échos, partagés une fois** — votre classe et les builds
  d'échos que le serveur garde pour votre personnage partent sur le canal pour
  la matrice EbonBuilds des autres joueurs, et ne repartent que s'ils changent.
- **Des erreurs qui restent visibles** — le bug d'un addon n'emporte jamais les
  autres, et ne disparaît jamais : il est transmis, avec sa pile, à BugSack,
  Swatter ou au cadre d'erreur de Blizzard.
- **Un diagnostic intégré** — `/eapi status` montre d'un coup d'œil le pont, le
  canal, la file et ProjectEbonhold ; `/eapi perf` mesure la mémoire et le CPU
  de chaque addon.

## 📦 Installation

1. [**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest) — téléchargez la dernière version.
2. Décompressez le dossier `EbonAPI` dans
   `Interface/AddOns/`.
3. Vérifiez dans l'écran de sélection des AddOns que **EbonAPI** est bien
   coché, avec les addons qui l'utilisent.

EbonAPI n'affiche rien par lui-même. Il ne rejoint son canal qu'une fois qu'un
addon s'est inscrit auprès de lui.

## 💬 Commandes slash

Alias : `/eapi` et `/ebonapi`.

| Commande | Effet |
| --- | --- |
| `/eapi` (ou `help`) | Liste les commandes. |
| `/eapi status` | État du socle : addons inscrits, pont serveur, canal, file d'envoi, profil, versions, services de ProjectEbonhold, messages rejetés. |
| `/eapi trace [n]` | Les `n` dernières entrées du diagnostic (20 par défaut). |
| `/eapi debug [addon\|*] on\|off` | Active ou coupe la sortie détaillée, pour un addon ou pour tous. |
| `/eapi lang [code]` | Affiche ou change la langue partagée (`enUS`, `frFR`, `deDE`, `esES`). |
| `/eapi db` | Résumé des données sauvegardées. |
| `/eapi opcodes` | Opcodes serveur connus. |
| `/eapi senders` | Expéditeurs observés sur le pont serveur. |
| `/eapi perf [addon] [libellé\|reset\|gc]` | Mémoire, cadres actifs et CPU, par addon. |

Le tampon de diagnostic retient les 128 derniers événements, même debug
éteint : ce qui intéresse est ce qui s'est passé *avant* qu'on pense à activer
la trace. Pour signaler un problème, `/eapi status` et `/eapi trace 30` sont
les deux sorties à copier.

## 🔌 Pour les auteurs d'addons

Tout ce qui suit est le contrat entre EbonAPI et les addons qui l'utilisent.

### Démarrage

EbonAPI est une dépendance dure. Dans le `.toc` de chaque consommateur :

```
## Dependencies: EbonAPI
```

```lua
local api = EbonAPI:NewAddon("MonAddon", 1, 1)   -- nom, majeur requis, mineur requis

if not api then
  return   -- version incompatible ; EbonAPI a déjà dit pourquoi dans le chat
end
```

Le majeur doit correspondre exactement, le mineur doit être au moins celui
demandé. Tout passe ensuite par cette poignée, ce qui permet à `api:OffAll()` de
tout reprendre d'un coup.

### Erreurs

Une erreur se corrige. EbonAPI ne décide donc rien à sa place : il la rend
visible à celui qui peut la corriger, et s'écarte.

**Un mauvais appel explose immédiatement.** Passer autre chose qu'une fonction à
`api:On`, un opcode en chaîne à `Bridge.on`, une table absente à `api:DB` : ce
sont des bugs dans le code appelant. Ils lèvent une erreur pointant sur **la
ligne de l'addon fautif** (`error(..., 2)`), pas sur une ligne d'EbonAPI où il
n'y aurait rien à corriger. Aucune de ces fonctions ne rend `false` en silence.

**Une erreur d'abonné est attrapée puis relâchée.** Le `pcall` sert uniquement à
ce qu'un bug d'AutoCallboard n'emporte pas EbonStat. Immédiatement après, elle
repart par `geterrorhandler()` : Swatter, BugSack ou le cadre d'erreur de
Blizzard la reçoivent avec sa pile, comme si elle n'avait jamais été attrapée.

Il n'y a ni déduplication, ni mise en sourdine, ni quarantaine automatique. Un
abonné qui échoue est écarté pour cette distribution-là seulement et rappelé à
l'événement suivant : chaque événement est une nouvelle tentative.

**Les données extérieures ne sont pas des erreurs.** Un message serveur illisible,
une sauvegarde corrompue, un service ProjectEbonhold absent : c'est la vie d'un
client. Ils sont validés, traités, et **comptés**. Le compte remonte dans
`/eapi status`, parce qu'un rejet que personne ne voit serait une erreur sans
solution derrière.

### Événements

```lua
api:On("READY", function(event, version) end)
api:Off("READY", fn)
api:OffAll()
```

Certains événements sont **collants** : ils rejouent leur dernier état au moment
de l'abonnement. Sans cela, un addon chargé après l'arrivée d'une donnée serveur
resterait aveugle jusqu'au message suivant, qui peut ne jamais venir.

| Événement | Collant | Charge |
|---|---|---|
| `READY` | oui | version |
| `LANGUAGE_CHANGED` | oui | code |
| `FEATURE_CHANGED` | non | nom, disponible |
| `SERVER_RUN_DATA` | oui | table de run |
| `SERVER_ASH` | oui | `{ spendable, committed, source }`, publié seulement quand le solde change |
| `SERVER_BUILDS` | oui | liste des builds |
| `SERVER_BUILD_ACTIVE` | oui | slot, liste |
| `SERVER_LOADOUT` | oui | loadout d'arbre |
| `SERVER_INTENSITY` | oui | table d'intensité |
| `SERVER_MULTIPLIER` | oui | nombre |
| `SERVER_MESSAGE` | non | opcode, corps, expéditeur |
| `STREAM_TIMEOUT` | non | opcode, id, reçus, total |
| `SEND_FAILED` | non | genre, puis la ligne (canal, serveur) ou le préfixe et la cible (chuchotement) |
| `CHANNEL_JOINED` | oui | index du canal commun |
| `CHANNEL_LOST` | non | — |
| `PEER_OFFLINE` | non | nom, envois retirés de la file |
| `UPDATE_AVAILABLE` | non | addon, version disponible, version installée, lien |
| `PROFILE_SLOTS` | non | expéditeur, classe, emplacements |
| `PROFILE_BUILD` | non | expéditeur, classe, emplacement, hash, échos |
| `PROFILE_BANS` | non | expéditeur, classe, hash, listes |

Un callback a le droit de s'abonner ou de se désabonner pendant qu'il tourne.

### Événements du client et timers

```lua
api:OnEvent("PLAYER_REGEN_DISABLED", fn)
api:OffEvent("PLAYER_REGEN_DISABLED", fn)

api:Tick("rafraichissement", 0.5, fn)   -- l'identifiant est préfixé par l'addon
api:Untick("rafraichissement")
```

Une seule frame porte tout. Le `OnUpdate` ne tourne que s'il reste au moins un
timer vivant.

Le bus tient deux registres par événement. Les abonnés consommateurs passent par
un appel protégé : un bug de l'un n'emporte pas les autres. Les abonnés du socle
(`Bus.onCore`, réservé à EbonAPI) sont appelés directement : les protéger contre
eux-mêmes ne protégerait personne et coûterait un appel protégé de plus à chaque
événement. Un événement sans abonné consommateur ne coûte donc **aucune**
protection.

### Pont serveur

```lua
api:OnServer(EbonAPI.SS.PLAYER_RUN_DATA, function(body, opcode, sender) end)
api:SendServer(EbonAPI.CS.BUILD_SELECT, "3")
api:RequestServer(EbonAPI.CS.REFRESH_BUILDS, "", 30)   -- coalescé sur 30 s
```

Les envois passent par la file unique de `Net/Queue` (voir
[Canal commun](#canal-commun)) : cinq demandes émises dans la même frame par
trois addons se perdraient ou couperaient la connexion. Les messages au serveur
y passent avant tout le reste. `RequestServer` coalesce entre addons : le
serveur ne reçoit la demande qu'une fois par intervalle. Deux demandes sont la
même si elles portent le même opcode et le même corps.

La grammaire de réception est l'union de ce que les trois implémentations
d'origine acceptaient : un message sans corps est livré (deux des trois le
jetaient), et les largeurs de fragment fixes comme variables sont acceptées.

Coût d'un message reçu, quel que soit le nombre d'abonnés : **un** appel protégé,
**un** motif évalué, **une** lecture de l'horloge, et **aucune** allocation hors
le corps lui-même. Un opcode que personne n'écoute ne coûte aucune protection.

### Canal commun

```lua
api:OnChannel("A", "H", function(sender, body, letter, op) end)
api:OffChannel("A", "H", fn)
api:Say("H", "digests")                 -- sous la lettre de l'addon, découpé si besoin
api:IsChannelJoined()
```

Un seul canal caché, `ebonapi`, pour tout ce qui s'adresse à tout le monde.
Chaque addon y parle sous sa lettre (`A` AutoCallboard, `B` EbonBuilds,
`S` SkillTreeAutoLoad, `G` EbonStat, `E` EbonAPI) et n'entend que ce qu'il
demande : une ligne d'une autre lettre ou d'une autre op s'arrête à une
recherche de table.

Une ligne a la forme `EA1:<lettre>:<op>:<n°>.<k>/<n>:<morceau>`, 255 caractères
au plus. Un message plus long part en paquets, seize au plus, réassemblés par
expéditeur et par numéro ; un message incomplet après 30 s est jeté. Un
caractère accentué n'est jamais coupé : la coupe recule d'un octet s'il le faut,
et `<n>` compte les paquets réellement produits. Le corps ne contient jamais
`|`, car le client refuse ce caractère, et `Say` explose si on lui en donne un.
Un marqueur injecté par le serveur devant la ligne (`[HCIV]`) est ignoré.

Le canal est rejoint dès qu'un addon s'inscrit par `NewAddon`, parce qu'EbonAPI
y envoie alors le profil d'échos ; EbonAPI seul ne le rejoint pas. Il est retiré
des fenêtres de chat, donc ni message ni notice n'apparaît. La jonction est relue
chaque seconde jusqu'à réussir, et redemandée toutes les dix.

**La file.** Tout ce qui sort du client passe par `Net/Queue` : les messages au
serveur d'abord, puis les lignes du canal et les chuchotements, un envoi toutes
les 0,15 s. L'anti-flood compte le client entier, pas chaque addon : trois
files indépendantes dépassaient la limite, une seule reste dessous. La file des
pairs est plafonnée à 500 envois ; un message qui n'y tient pas en entier est
refusé en entier, jamais coupé (`Say` et `WhisperAll` rendent `false`).

**Joueurs partis.** Quand le client répond « aucun joueur nommé X » à un
chuchotement, les chuchotements vers X sont retirés de la file, refusés pendant
60 s, et `PEER_OFFLINE` prévient l'addon. Le message système n'est écouté que
dans la minute qui suit un chuchotement : au repos, rien ne tourne.

### Chuchotements

```lua
api:Whisper("ACBR", "Bob", "G:abc")          -- un chuchotement d'addon, par la file
api:WhisperAll("ACBR", "Bob", parts, n)      -- plusieurs, tous ou aucun
api:OnWhisper("ACBR", function(sender, text, distribution, prefix) end)

api:WhisperStream("ACBR", "Bob", "C", hash, code)   -- un corps long, en morceaux
api:OnWhisperStream("ACBR", "C", function(sender, body, id, op) end, onPart)
```

Ce qu'un joueur demande à un autre (un build public d'EbonBuilds, une route
d'AutoCallboard) part en chuchotement, par la même file que le reste. Le
client limite un message d'addon à 255 octets **préfixe et tabulation
compris** : `Whisper` explose au-delà de `255 - #préfixe - 1`.

Un flux a la forme `EAS:<op>:<id>:<k>/<n>:<morceau>`. Il part en quatre cents
morceaux au plus, tous ou aucun ; `WhisperStream` rend `false` s'il ne tient
pas dans la file ou si le destinataire vient d'être signalé absent. À
l'arrivée, les morceaux sont réassemblés par expéditeur, préfixe, op et id ;
`onPart` est appelé à chaque morceau sauf le dernier, pour une barre
d'avancement ; un flux incomplet après 30 s est jeté. Comme sur le canal, un
caractère accentué n'est jamais coupé et `<n>` est le vrai nombre de morceaux.

### Profil d'échos

EbonAPI envoie lui-même, sous la lettre `E`, ce que la matrice d'EbonBuilds
lit chez les autres joueurs : la classe et les builds d'échos que le serveur
garde pour le personnage (opcode 540), plus les listes de ban qu'EbonBuilds
lui confie par `api:SetProfileBans(listes)`. Un seul EbonAPI par client, donc
plus rien à arbitrer entre addons, et le format n'est écrit qu'une fois.

| Op | Corps | Rôle |
|---|---|---|
| `P` | `<classe>:<emplacements>` (`8:1.2.5`) | les emplacements occupés |
| `D` | `<classe>:<emplacement>:<hash>:<échos>` | un build |
| `X` | `<classe>:<hash>:<liste>;<liste>...` | les listes de ban |

Un écho tient sur trois caractères de l'alphabet `0-9 A-Z a-z - _` : deux pour
l'écart entre son id et 200000, un pour ses piles. Les échos sont triés, donc
le même build donne toujours le même texte et le même hash
(`EbonAPI.Profile.Signature`, huit caractères). Les classes vont de `WARRIOR`
1 à `DRUID` 10, l'ordre de la matrice (`EbonAPI.Profile.ClassIndex`).

**Quand ça part.** Ce qui a déjà été envoyé est gardé dans `EbonAPIDB`, par
personnage : hash de chaque emplacement, emplacements annoncés, hash des bans.
Une ligne n'y est notée qu'une fois partie de la file, pas quand elle y entre :
un `/reload` qui vide la file avant qu'elle ait servi ne perd donc rien, la
ligne repart au chargement suivant. Hors de ce cas, un `/reload` ne renvoie
rien ; seul un build qui change repart, et `P` ne repart que si un emplacement
apparaît ou disparaît.

Une session nouvelle renvoie tout, pour les joueurs qui ne connaissaient pas
encore ce personnage, et demande la liste des builds au serveur dix secondes
après la connexion. Une session est nouvelle quand la connexion arrive plus de
dix minutes après la fin de la précédente. La fin, c'est la déconnexion ou le
`/reload` (`PLAYER_LOGOUT`) ; sans déconnexion propre (plantage, coupure), on
compte depuis la connexion précédente. Un `/reload` après deux heures de jeu
n'ouvre donc pas de session.

**À la réception**, EbonAPI vérifie les bornes (classe 1 à 10, emplacement 1 à
20, 150 échos par build, 20 listes de 150) et recalcule le hash ; un message
abîmé est compté et jeté. Le reste arrive décodé aux abonnés de
`PROFILE_SLOTS`, `PROFILE_BUILD` et `PROFILE_BANS`, échos et listes en texte
compact ; `EbonAPI.Profile.DecodeBuild` et `DecodeBans` les relisent quand un
addon en a besoin. EbonAPI ne garde rien des profils reçus.

Le profil part dès qu'un addon quelconque est inscrit : EbonStat seul suffit.

### Versions

```lua
api:Version("2.6.0", "https://...")   -- la version installée, et où la trouver
api:AvailableUpdate()                 -- "2.7.0", "2.6.0" si une plus récente circule
```

Une seule ligne `V` part sous la lettre `E` par session, pour tous les addons
à la fois : `A=2.6.0,E=1.1.0,S=1.8.0`. Seules les releases (`x.y.z`) y
figurent ; une build de travail (`x.y.z-n`) est gardée pour soi. Qui entend une
version plus récente que la sienne la garde dans `EbonAPIDB` pour tout le
compte, prévient le joueur une fois par session et émet `UPDATE_AVAILABLE` ; le
lien affiché est toujours celui que l'addon installé a donné, jamais celui d'un
autre joueur. Qui entend un joueur en retard lui répond après deux à huit
secondes, sauf si quelqu'un l'a déjà fait. Une version gardée est oubliée dès
que la version installée la rattrape.

### État serveur normalisé

```lua
local State = EbonAPI.State

State.GetRun()          -- 19 champs + valeurs dérivées (remainingRerolls, ...)
State.GetAsh()          -- solde unique, avec sa provenance
State.GetBuilds()       -- chaque emplacement porte `echoes`, la liste brute du serveur
State.activeBuild()
State.GetLoadout()
State.GetIntensity()
State.GetMultiplier()
State.snapshot("builds")   -- copie stable
```

Les getters rendent les tables vivantes : on les lit, on ne les modifie pas.
Pour une copie détachée, passer par `State.snapshot()`.

Le solde de cendres arrivait par deux chemins indépendants (opcode 15 côté
EbonStat, opcode 3 côté SkillTreeAutoLoad) sans réconciliation. Il est
désormais unique, et `ash.source` dit quel message l'a posé.

`SERVER_ASH` n'est publié que si le solde disponible ou engagé change. Le même
solde répété, par l'un ou l'autre opcode, met à jour `ash.source` et `ash.at`
sans rien publier : EbonStat enregistre des différences de solde et les garde à
vie, un solde republié à l'identique n'y serait que du bruit. Un abonné tardif
reçoit toujours le solde courant par le rejeu.

`State.GetIntensity()` rend toujours la même table quand il se replie sur
`EbonholdIntensityData` : la fenêtre d'EbonStat le lit quatre fois par seconde.

### Stockage

```lua
local db = api:DB({
  account   = { taille = 10 },
  character = { position = 1 },
})

db.account.taille
db.char.position        -- nil avant PLAYER_LOGIN, résolu ensuite
api:Shared().account    -- espace commun à tous les addons
```

Tout vit dans `EbonAPIDB` : la donnée survit indépendamment de quels
consommateurs sont installés. Un défaut ajouté dans une version suivante
n'écrase jamais un choix déjà fait par le joueur.

C'est ici que les addons rangent désormais ce qu'ils gardent : les profils
reçus d'EbonBuilds en premier, les routes et collections d'AutoCallboard, les
sauvegardes de SkillTreeAutoLoad et les builds d'EbonBuilds ensuite, un addon à
la fois. Chaque addon garde son format ; ce qui se partage entre addons passe
par un format déclaré, jamais par la lecture de la table d'un autre.

#### Migrations

```lua
db:MigrateOnce("depuis-MonAddonDB", MonAddonDB, function(store, legacy)
  -- lire legacy, écrire dans store
  return nombreDeReprises   -- nil = pas fait, sera rejoué
end)

db:MigrateOncePerCharacter("clef", legacy, function(store, legacy, nom, clef) end)
```

**Règle absolue, apprise à la dure sur SkillTreeAutoLoad** : le marqueur « déjà
migré » vit dans le même fichier que les données qu'il protège. Quand le marqueur
survit à ce qu'il garde, la reprise ne rejoue plus et les données sont perdues
pour de bon. Ici les deux sont dans `EbonAPIDB`. Corollaire : une base d'origine
n'est jamais modifiée, seulement lue.

Une migration qui rend `nil` ou qui échoue ne pose pas son marqueur : elle sera
retentée au chargement suivant.

### Langue

```lua
local L = api:Locale({
  enUS = { BONJOUR = "hello" },
  frFR = { BONJOUR = "bonjour" },
})

api:Localized(widget, "BONJOUR")   -- se retraduit tout seul au changement
```

La table rendue est vivante : elle est vidée et re-remplie sur place, donc un
`local L = api:Locale(...)` gardé en haut de fichier reste valide.

Le **choix** de la langue est partagé et persisté ; les tables de traduction
restent à chaque addon. Chaque registre retombe sur *sa* base `enUS`
indépendamment : si la langue partagée est `deDE` et qu'un addon ne la fournit
pas, cet addon-là parle anglais sans imposer l'anglais aux autres.

### Diagnostic

Écrire une entrée de diagnostic ne pose que cinq valeurs brutes. La mise en
forme n'a lieu qu'à la lecture, donc un message serveur n'alloue rien.

Un addon déclare ce qu'il veut voir mesuré : `api:Track("carte", frame)` pour
un cadre, `api:TrackFunction("OnUpdate", fn)` pour une fonction, puis
`api:Perf("apres combat")` ou `/eapi perf MonAddon apres combat` pour un
rapport, gardé dans `EbonAPIDB` (vingt par addon). Le CPU ne se lit que profileur
allumé (`/console scriptProfile 1`, puis `/reload`).

## 🧠 Anatomie du code — comment ça fonctionne

EbonAPI se charge dans l'ordre de son `.toc` : les primitives d'abord, puis les
langues, la file, le serveur, le réseau, et `Boot.lua` en dernier, qui démarre
le tout à la connexion. Tout est accroché à la table globale `EbonAPI`.

### `Core/` — le socle

| Fichier | Rôle exact |
| --- | --- |
| `Lib.lua` | Primitives sans dépendance : coercition, tables, chaînes, découpe UTF-8, `pcall` qui rapporte. |
| `Api.lua` | Espace de noms, garde de version, poignées consommateur, bus de callbacks. |
| `Listeners.lua` | Listes d'abonnés qu'on peut modifier pendant qu'elles tournent. |
| `Log.lua` | Journal préfixé et tampon circulaire de diagnostic. |
| `Bus.lua` | Une frame unique pour tous les événements du client et tous les timers. |
| `Assembler.lua` | Réassemblage des messages en morceaux, avec expiration. |
| `DB.lua` | `EbonAPIDB` : portées compte et personnage, défauts, migrations. |
| `Session.lua` | Dit si la connexion ouvre une session nouvelle. |
| `Format.lua` | Formateurs communs (nombres, monnaie, durées). |
| `Perf.lua` | Mémoire, cadres actifs et CPU par addon (`/eapi perf`). |

### `Language/` et `Locales/` — le système multilingue

| Fichier | Rôle exact |
| --- | --- |
| `Language/Locale.lua` | Le moteur de langue et le **choix de langue partagé**. |
| `Locales/enUS.lua`, `frFR.lua`, `deDE.lua`, `esES.lua` | Les messages d'EbonAPI lui-même, en quatre langues. |

### `Net/` — entre les joueurs

| Fichier | Rôle exact |
| --- | --- |
| `Queue.lua` | **Une seule** file d'envoi : serveur, canal, chuchotements. |
| `Channel.lua` | Le canal commun `ebonapi`, ses paquets, les chuchotements simples. |
| `Whisper.lua` | La réception des chuchotements par préfixe, et les flux en morceaux. |
| `Profile.lua` | Le profil d'échos du joueur, encodé, envoyé et relu à un seul endroit. |
| `Version.lua` | Les versions des addons, annoncées une fois par session. |

### `Server/` — le dialogue avec le serveur

| Fichier | Rôle exact |
| --- | --- |
| `Opcodes.lua` | Carte des opcodes AAM0x9 observés. |
| `Bridge.lua` | **Un seul** pont serveur : parseur, réassembleur, envoi par la file. |
| `Ebonhold.lua` | Façade ProjectEbonhold, avec détection et dégradation. |
| `State.lua` | État serveur normalisé, publié une fois pour tous. |

### À la racine

| Fichier | Rôle exact |
| --- | --- |
| `Boot.lua` | Le démarrage : rattache `EbonAPIDB` au chargement ; lance le pont, l'état, le canal, le profil et les versions à la connexion ; émet `READY` ; interprète les commandes `/eapi`. |
| `EbonAPI.toc` | Le manifeste WoW : métadonnées, variable sauvegardée (`EbonAPIDB`) et ordre de chargement des fichiers. |

## 🚧 Limites connues et assumées

- **L'envoi fragmenté vers le serveur n'est pas implémenté.** Aucun addon en
  production n'en émet, donc rien ne prouve que le serveur sache réassembler.
  La limite de 240 octets est donc réelle et définitive : la dépasser est un
  bug d'appel, et `Bridge.send` lève une erreur nommant la taille et la limite.
  Le canal commun, lui, découpe (seize paquets au plus).
- **Le filtre d'expéditeur est actif par défaut.** Seul un chuchotement du
  joueur à lui-même est lu comme venant du serveur : sans filtre, n'importe
  quel joueur du groupe, du raid ou de la guilde pouvait poster sur `AAM0x9`.
  Il a été vérifié en jeu (la liste des builds arrive, le profil part). Si le
  serveur répondait un jour sous un autre nom, le pont resterait muet :
  `/eapi senders` montre les noms reçus, et
  `EbonAPI.Bridge.setStrictSender(false)` coupe le filtre.
- **Une version annoncée sur le canal est crue.** Rien ne signe une ligne `V` :
  un joueur qui annonce `A=99.0.0` fait afficher « version 99.0.0 disponible »
  aux utilisateurs d'AutoCallboard qui l'entendent, et la valeur reste gardée
  tant que la version installée ne l'a pas rattrapée. Le lien affiché, lui, ne
  vient jamais du canal.
- **Le profil ne porte que les échos 200000 à 204095.** Un id hors de cet
  intervalle est retiré du build envoyé, sans message.
- **La carte des opcodes est tenue à la main.** `Server/Opcodes.lua` recopie
  ceux qu'on a observés (`EbonAPI.SS`, `EbonAPI.CS`) ; si ProjectEbonhold les
  change, elle ne suit pas toute seule. Ceux que ProjectEbonhold définit se
  lisent aussi à l'exécution par `EbonAPI.Ebonhold.OpcodeCS(nom)`, et
  `EbonAPI.Ebonhold.SendToServer(nom, corps)` envoie par ProjectEbonhold lui-même.
- **Un message serveur fragmenté incomplet peut survivre jusqu'à 22 s** (20 s
  d'expiration plus une période de balayage) avant d'être libéré.

## 🚫 Ce qu'EbonAPI ne fera pas

Configuration, timers de haut niveau, hooks génériques, sérialisation : Ace3 le
fait mieux. Le format colonne d'EbonStat, les données de voyage d'AutoCallboard,
la lecture de l'arbre de SkillTreeAutoLoad, les notes de la matrice
d'EbonBuilds : c'est du métier, ça reste chez eux. EbonAPI transporte et
stocke, il ne juge pas.

## 🌍 Langues

Anglais, français, allemand et espagnol sont complets pour les messages
d'EbonAPI lui-même. La langue choisie par `/eapi lang`, ou depuis le menu de
langue d'un addon, s'applique à tous les addons qui confient leurs traductions
à EbonAPI.

## 📜 Licence et crédits

Addon de **Siphelis**.
Construit sur ProjectEbonhold, l'interface client du serveur Ebonhold.

EbonAPI est publié sous la [PolyForm Strict License 1.0.0](LICENSE) : vous
pouvez l'utiliser à des fins non commerciales, mais vous ne pouvez **ni le
vendre, ni le modifier, ni le redistribuer**. Cela comprend sa publication sur
un site d'addons, son intégration dans un pack ou la diffusion d'une version
modifiée. Demandez l'autorisation avant tout usage de ce type.

---
