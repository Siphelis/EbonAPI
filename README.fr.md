# 🧩 EbonAPI

**Des services communs pour les addons Ebonhold.**

EbonAPI est un addon conçu pour mettre à disposition des fonctionnalités communes que d'autres addons peuvent utiliser directement.

Il fournit notamment des services pour communiquer avec le serveur, échanger des données entre joueurs, gérer les données sauvegardées, partager une langue commune, détecter les mises à jour ou encore suivre les performances.

Les addons peuvent utiliser uniquement les services dont ils ont besoin, tout en conservant leur propre interface, leurs données et leurs fonctionnalités.

EbonAPI est actuellement utilisé par :

[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad)

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

Développeurs : la [documentation développeur](https://siphelis.github.io/EbonAPI/), en anglais, explique comment relier un addon à EbonAPI.

---

## Table des matières

- [Pourquoi EbonAPI](#-pourquoi-ebonapi)
- [Fonctionnalités](#-fonctionnalités)
- [Installation](#-installation)
- [Commandes slash](#-commandes-slash)
- [Anatomie du code](#-anatomie-du-code--comment-ça-fonctionne)
- [Langues](#-langues)
- [Licence et crédits](#-licence-et-crédits)

---

## 🔥 Pourquoi EbonAPI

Plusieurs addons peuvent avoir besoin des mêmes fonctionnalités : communiquer avec le serveur Ebonhold, envoyer des données à d'autres joueurs, gérer une langue commune, enregistrer des données ou vérifier la disponibilité d'une nouvelle version.

EbonAPI rassemble ces fonctionnalités et les met à disposition des addons qui souhaitent les utiliser.

Un addon peut ainsi se connecter aux services proposés par EbonAPI au lieu d'avoir à recréer sa propre gestion de ces fonctionnalités.

EbonAPI se charge alors de leur fonctionnement commun : réception des messages serveur, gestion des files d'envoi, échanges entre joueurs, données partagées, langue, diagnostics ou encore notifications de mise à jour.

Chaque addon reste indépendant dans son fonctionnement et choisit les services d'EbonAPI qu'il souhaite utiliser.

Lorsqu'un même service est utilisé par plusieurs addons, EbonAPI peut également le gérer de manière centralisée. Un message serveur commun, par exemple, peut être traité une seule fois puis transmis aux addons concernés.

## ✨ Fonctionnalités

### Communication avec le serveur

EbonAPI fournit aux addons une interface commune pour communiquer avec les fonctionnalités mises à disposition par le serveur Ebonhold et ProjectEbonhold.

Les données reçues peuvent être traitées par EbonAPI puis mises à disposition des addons qui en ont besoin.

Cela concerne notamment certaines données liées aux runs, aux builds d'échos, aux cendres et aux autres fonctionnalités proposées par le serveur.

### Communication entre joueurs

Les addons peuvent utiliser EbonAPI pour échanger des données avec les autres joueurs utilisant les mêmes fonctionnalités.

AutoCallboard utilise notamment ce service pour partager les routes enregistrées par les joueurs avec les autres utilisateurs de l'addon.

EbonAPI prend en charge la transmission de ces données et leur distribution vers l'addon concerné.

Les échanges techniques restent invisibles dans les fenêtres de discussion du joueur.

### Gestion des envois

Les messages envoyés par les addons passent par une file commune gérée par EbonAPI.

Les envois sont cadencés afin de respecter les limites anti-flood de World of Warcraft et d'éviter que plusieurs addons envoient simultanément leurs propres flux de messages.

### Données partagées

EbonAPI peut conserver et mettre à disposition certaines données communes afin qu'elles puissent être utilisées par plusieurs addons sans devoir être récupérées ou traitées séparément par chacun d'eux.

Chaque addon conserve néanmoins ses propres données lorsqu'elles ne concernent que son fonctionnement.

### Langue commune

Les addons peuvent utiliser le système de langue fourni par EbonAPI.

La langue choisie est alors partagée entre tous les addons qui utilisent ce service.

Si un addon ne possède pas de traduction dans la langue sélectionnée, il utilise automatiquement l'anglais sans modifier la langue utilisée par les autres addons.

### Notifications de mise à jour

Un addon peut déclarer sa version et son lien de téléchargement auprès d'EbonAPI.

EbonAPI peut alors détecter lorsqu'une version plus récente circule parmi les joueurs et afficher une notification de mise à jour.

Cette notification n'est affichée qu'une fois par session pour chaque nouvelle version détectée.

### Builds d'échos

EbonAPI peut fournir aux addons les fonctionnalités nécessaires pour récupérer et échanger les informations liées aux builds d'échos.

EbonBuilds utilise notamment ce service pour partager la classe et les builds d'un joueur avec les autres utilisateurs.

Les informations ne sont renvoyées que lorsqu'une modification est détectée.

### Diagnostic et performances

EbonAPI intègre plusieurs outils permettant de vérifier son fonctionnement et celui des addons qui utilisent ses services.

`/eapi status` affiche une vue d'ensemble des addons connectés à EbonAPI et de l'état des différents services.

`/eapi perf` permet de consulter leur utilisation de la mémoire, du CPU et des cadres actifs.

## 📦 Installation

1. Téléchargez la dernière version d'[**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest).
2. Décompressez le dossier `EbonAPI` dans :
   `Interface/AddOns/`
3. Depuis l'écran de sélection des AddOns de World of Warcraft, vérifiez que **EbonAPI** est bien activé.

EbonAPI ne possède pas d'interface principale destinée au joueur.

Il met ses fonctionnalités à disposition des addons installés qui souhaitent les utiliser.

Les addons compatibles détectent EbonAPI et peuvent alors se connecter aux services qu'ils prennent en charge.

## 💬 Commandes slash

Les commandes `/eapi` et `/ebonapi` sont équivalentes.

| Commande                      | Effet                                                                               |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| `/eapi` ou `/eapi help`       | Affiche la liste des commandes disponibles.                                         |
| `/eapi status`                | Affiche l'état d'EbonAPI, de ses services et des addons qui les utilisent.          |
| `/eapi lang [code]`           | Affiche ou modifie la langue commune (`enUS`, `frFR`, `deDE`, `esES`).              |
| `/eapi perf [addon]`          | Affiche l'utilisation de la mémoire, du CPU et les cadres actifs pour chaque addon. |
| `/eapi trace [n]`             | Affiche les `n` dernières entrées du diagnostic.                                    |
| `/eapi debug [addon] on\|off` | Active ou désactive les informations de débogage détaillées pour un addon.          |
| `/eapi db`                    | Affiche un résumé des données sauvegardées par EbonAPI.                             |

Pour signaler un problème, joignez de préférence les résultats des commandes :

`/eapi status`

et

`/eapi trace 30`

Ces informations permettent d'identifier plus facilement l'état d'EbonAPI, les services utilisés et l'origine éventuelle du problème.

## 🧠 Anatomie du code — comment ça fonctionne

EbonAPI est organisé en plusieurs modules correspondant aux services qu'il met à disposition des addons.

| Dossier / fichier       | Rôle                                                                                                                                                                                   |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Core/`                 | Fonctions communes d'EbonAPI : événements, timers, données sauvegardées, journal interne et mesure des performances.                                                                   |
| `Server/`               | Services de communication avec le serveur Ebonhold et ProjectEbonhold, ainsi que gestion des données serveur pouvant être mises à disposition des addons : runs, builds, cendres, etc. |
| `Net/`                  | Services de communication entre joueurs : file d'envoi, chuchotements, profils d'échos, données partagées entre addons et notifications de mise à jour.                                |
| `Language/`, `Locales/` | Gestion du service de langue commune et des traductions propres à EbonAPI.                                                                                                             |
| `Boot.lua`              | Initialisation d'EbonAPI, mise en place de ses services et gestion des commandes `/eapi`.                                                                                              |
| `EbonAPI.toc`           | Manifeste de l'addon : métadonnées, variable sauvegardée `EbonAPIDB` et ordre de chargement des fichiers.                                                                              |

Les addons utilisant EbonAPI peuvent ainsi se connecter aux différents services selon leurs besoins, sans avoir à prendre en charge leur fonctionnement interne.

## 🌍 Langues

EbonAPI est entièrement disponible en :

- anglais ;
- français ;
- allemand ;
- espagnol.

Il propose également un service de langue que les autres addons peuvent utiliser.

La langue sélectionnée avec `/eapi lang` ou depuis le menu de langue d'un addon utilisant ce service est partagée avec les autres addons compatibles.

Si un addon ne possède pas de traduction dans la langue sélectionnée, il utilise automatiquement sa version anglaise.

## 📜 Licence et crédits

Addon développé par **Siphelis**.

Conçu pour ProjectEbonhold, l'interface client du serveur Ebonhold.

EbonAPI est distribué sous la [PolyForm Strict License 1.0.0](LICENSE).

Vous pouvez l'utiliser dans un cadre non commercial, mais vous ne pouvez **ni le vendre, ni le modifier, ni le redistribuer**.

Cela inclut notamment :

- sa publication sur un site d'addons ;
- son intégration dans un pack d'addons ;
- la redistribution d'une copie ;
- la diffusion d'une version modifiée.

Toute utilisation de ce type nécessite une autorisation préalable.
