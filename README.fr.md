# 🧩 EbonAPI

**Des services communs pour les addons Ebonhold.**

[EbonAPI](https://github.com/Siphelis/EbonAPI) est un addon conçu pour mettre à disposition des fonctionnalités communes que d'autres addons peuvent utiliser directement.

Il fournit notamment des services pour communiquer avec le serveur, échanger des données entre joueurs, gérer les données sauvegardées, partager une langue commune, détecter les mises à jour ou encore suivre les performances.

Les addons peuvent utiliser uniquement les services dont ils ont besoin. Ils conservent leurs fonctionnalités et leurs données, et peuvent confier tout ou partie de leur interface à la fenêtre d'[EbonAPI](https://github.com/Siphelis/EbonAPI).

[EbonAPI](https://github.com/Siphelis/EbonAPI) est actuellement utilisé par :

[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad)

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

Développeurs : la [documentation développeur](https://siphelis.github.io/EbonAPI/), en anglais, explique comment relier un addon à [EbonAPI](https://github.com/Siphelis/EbonAPI).

---

## Table des matières

- [Pourquoi EbonAPI](#-pourquoi-ebonapi)
- [Fonctionnalités](#-fonctionnalités)
- [Installation](#-installation)
- [La fenêtre EbonAPI](#-la-fenêtre-ebonapi)
- [Anatomie du code](#-anatomie-du-code--comment-ça-fonctionne)
- [Langues](#-langues)
- [Licence et crédits](#-licence-et-crédits)

---

## 🔥 Pourquoi EbonAPI

Plusieurs addons peuvent avoir besoin des mêmes fonctionnalités : communiquer avec le serveur Ebonhold, envoyer des données à d'autres joueurs, gérer une langue commune, enregistrer des données ou vérifier la disponibilité d'une nouvelle version.

[EbonAPI](https://github.com/Siphelis/EbonAPI) rassemble ces fonctionnalités et les met à disposition des addons qui souhaitent les utiliser.

Un addon peut ainsi se connecter aux services proposés par [EbonAPI](https://github.com/Siphelis/EbonAPI) au lieu d'avoir à recréer sa propre gestion de ces fonctionnalités.

[EbonAPI](https://github.com/Siphelis/EbonAPI) se charge alors de leur fonctionnement commun : réception des messages serveur, gestion des files d'envoi, échanges entre joueurs, données partagées, langue, diagnostics ou encore notifications de mise à jour.

Chaque addon reste indépendant dans son fonctionnement et choisit les services d'[EbonAPI](https://github.com/Siphelis/EbonAPI) qu'il souhaite utiliser.

Lorsqu'un même service est utilisé par plusieurs addons, [EbonAPI](https://github.com/Siphelis/EbonAPI) peut également le gérer de manière centralisée. Un message serveur commun, par exemple, peut être traité une seule fois puis transmis aux addons concernés.

## ✨ Fonctionnalités

### Communication avec le serveur

[EbonAPI](https://github.com/Siphelis/EbonAPI) fournit aux addons une interface commune pour communiquer avec les fonctionnalités mises à disposition par le serveur Ebonhold et ProjectEbonhold.

Les données reçues peuvent être traitées par [EbonAPI](https://github.com/Siphelis/EbonAPI) puis mises à disposition des addons qui en ont besoin.

Cela concerne notamment certaines données liées aux runs, aux builds d'échos, aux cendres et aux autres fonctionnalités proposées par le serveur.

### Communication entre joueurs

Les addons peuvent utiliser [EbonAPI](https://github.com/Siphelis/EbonAPI) pour échanger des données avec les autres joueurs utilisant les mêmes fonctionnalités.

[AutoCallboard](https://github.com/Siphelis/autocallboard) utilise notamment ce service pour partager les routes enregistrées par les joueurs avec les autres utilisateurs de l'addon.

[EbonAPI](https://github.com/Siphelis/EbonAPI) prend en charge la transmission de ces données et leur distribution vers l'addon concerné.

Les échanges techniques restent invisibles dans les fenêtres de discussion du joueur.

### Gestion des envois

Les messages envoyés par les addons passent par une file commune gérée par [EbonAPI](https://github.com/Siphelis/EbonAPI).

Les envois sont cadencés afin de respecter les limites anti-flood de World of Warcraft et d'éviter que plusieurs addons envoient simultanément leurs propres flux de messages.

### Données partagées

[EbonAPI](https://github.com/Siphelis/EbonAPI) peut conserver et mettre à disposition certaines données communes afin qu'elles puissent être utilisées par plusieurs addons sans devoir être récupérées ou traitées séparément par chacun d'eux.

Chaque addon conserve néanmoins ses propres données lorsqu'elles ne concernent que son fonctionnement.

### Langue commune

Les addons peuvent utiliser le système de langue fourni par [EbonAPI](https://github.com/Siphelis/EbonAPI).

La langue choisie est alors partagée entre tous les addons qui utilisent ce service.

Si un addon ne possède pas de traduction dans la langue sélectionnée, il utilise automatiquement l'anglais sans modifier la langue utilisée par les autres addons.

### Notifications de mise à jour

Un addon peut déclarer sa version et son lien de téléchargement auprès d'[EbonAPI](https://github.com/Siphelis/EbonAPI).

[EbonAPI](https://github.com/Siphelis/EbonAPI) peut alors détecter lorsqu'une version plus récente circule parmi les joueurs et afficher une notification de mise à jour.

Cette notification n'est affichée qu'une fois par session pour chaque nouvelle version détectée.

### Builds d'échos

[EbonAPI](https://github.com/Siphelis/EbonAPI) peut fournir aux addons les fonctionnalités nécessaires pour récupérer et échanger les informations liées aux builds d'échos.

[EbonBuilds](https://github.com/Siphelis/EbonBuilds) utilise notamment ce service pour partager la classe et les builds d'un joueur avec les autres utilisateurs.

Les informations ne sont renvoyées que lorsqu'une modification est détectée.

### Interface commune

[EbonAPI](https://github.com/Siphelis/EbonAPI) possède sa propre fenêtre de réglages, accessible depuis le menu du jeu.

Les addons peuvent y afficher leurs réglages, avec la même apparence pour tous, ou garder leur propre interface et suivre l'apparence choisie dans [EbonAPI](https://github.com/Siphelis/EbonAPI) : couleurs, échelle, opacité, ombre, angles et côté des onglets.

Vos choix l'emportent toujours sur les valeurs qu'un addon définit pour lui-même.

### Diagnostic et performances

[EbonAPI](https://github.com/Siphelis/EbonAPI) intègre plusieurs outils permettant de vérifier son fonctionnement et celui des addons qui utilisent ses services.

La page **Diagnostic** de la fenêtre d'[EbonAPI](https://github.com/Siphelis/EbonAPI) affiche une vue d'ensemble des addons connectés et de l'état des différents services, ainsi que leur utilisation de la mémoire, du CPU et des cadres actifs.

## 📦 Installation

1. Téléchargez la dernière version d'[**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest).
2. Décompressez le dossier `EbonAPI` dans :
   `Interface/AddOns/`
3. Depuis l'écran de sélection des AddOns de World of Warcraft, vérifiez que **[EbonAPI](https://github.com/Siphelis/EbonAPI)** est bien activé.

[EbonAPI](https://github.com/Siphelis/EbonAPI) met ses fonctionnalités à disposition des addons installés qui souhaitent les utiliser. Ses réglages se trouvent dans sa propre fenêtre : voir [La fenêtre EbonAPI](#-la-fenêtre-ebonapi).

Les addons compatibles détectent [EbonAPI](https://github.com/Siphelis/EbonAPI) et peuvent alors se connecter aux services qu'ils prennent en charge.

## 🪟 La fenêtre EbonAPI

[EbonAPI](https://github.com/Siphelis/EbonAPI) n'a aucune commande slash : tout passe par sa fenêtre.

Ouvrez-la depuis le menu du jeu (**Échap → EbonAPI**), ou depuis les options d'interface, onglet AddOns.

| Page                 | Contenu                                                                                                                                                         |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Général**          | La langue commune, partagée par tous les addons compatibles.                                                                                                    |
| **Apparence**        | Couleurs, échelle, opacité, ombre sous les fenêtres, angles, onglets à gauche ou à droite, verrouillage des fenêtres.                                           |
| **Addons connectés** | Les addons qui utilisent [EbonAPI](https://github.com/Siphelis/EbonAPI) et leurs versions.                                                                      |
| **Diagnostic**       | L'état d'[EbonAPI](https://github.com/Siphelis/EbonAPI) et de ses services, les traces, les données sauvegardées, les messages de débogage et les performances. |

Les addons qui confient leurs réglages à [EbonAPI](https://github.com/Siphelis/EbonAPI) ont leur propre onglet, sous **Addons**. La zone de recherche, en haut, trouve un réglage dans tous les onglets.

Pour signaler un problème, joignez de préférence une capture de la page **Diagnostic** après avoir cliqué sur **État**, puis sur **Traces**.

Ces informations permettent d'identifier plus facilement l'état d'[EbonAPI](https://github.com/Siphelis/EbonAPI), les services utilisés et l'origine éventuelle du problème.

## 🧠 Anatomie du code — comment ça fonctionne

[EbonAPI](https://github.com/Siphelis/EbonAPI) est organisé en plusieurs modules correspondant aux services qu'il met à disposition des addons.

| Dossier / fichier       | Rôle                                                                                                                                                                                                    |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Core/`                 | Fonctions communes d'[EbonAPI](https://github.com/Siphelis/EbonAPI) : événements, timers, données sauvegardées, journal interne et mesure des performances.                                             |
| `Server/`               | Services de communication avec le serveur Ebonhold et ProjectEbonhold, ainsi que gestion des données serveur pouvant être mises à disposition des addons : runs, builds, cendres, etc.                  |
| `Net/`                  | Services de communication entre joueurs : file d'envoi, chuchotements, profils d'échos, données partagées entre addons et notifications de mise à jour.                                                 |
| `Language/`, `Locales/` | Gestion du service de langue commune et des traductions propres à [EbonAPI](https://github.com/Siphelis/EbonAPI).                                                                                       |
| `UI/`                   | La fenêtre d'[EbonAPI](https://github.com/Siphelis/EbonAPI) : son habillage, les paramètres d'apparence communs, les réglages des addons et les pages d'[EbonAPI](https://github.com/Siphelis/EbonAPI). |
| `Boot.lua`              | Initialisation d'[EbonAPI](https://github.com/Siphelis/EbonAPI) et mise en place de ses services.                                                                                                       |
| `EbonAPI.toc`           | Manifeste de l'addon : métadonnées, variable sauvegardée `EbonAPIDB` et ordre de chargement des fichiers.                                                                                               |

Les addons utilisant [EbonAPI](https://github.com/Siphelis/EbonAPI) peuvent ainsi se connecter aux différents services selon leurs besoins, sans avoir à prendre en charge leur fonctionnement interne.

## 🌍 Langues

[EbonAPI](https://github.com/Siphelis/EbonAPI) est entièrement disponible en :

- anglais ;
- français ;
- allemand ;
- espagnol.

Il propose également un service de langue que les autres addons peuvent utiliser.

La langue sélectionnée dans la fenêtre d'[EbonAPI](https://github.com/Siphelis/EbonAPI) (**Général → Langue**) ou depuis le menu de langue d'un addon utilisant ce service est partagée avec les autres addons compatibles.

Si un addon ne possède pas de traduction dans la langue sélectionnée, il utilise automatiquement sa version anglaise.

## 📜 Licence et crédits

Addon développé par **Siphelis**.

Conçu pour ProjectEbonhold, l'interface client du serveur Ebonhold.

[EbonAPI](https://github.com/Siphelis/EbonAPI) est distribué sous la [PolyForm Strict License 1.0.0](LICENSE).

Vous pouvez l'utiliser dans un cadre non commercial, mais vous ne pouvez **ni le vendre, ni le modifier, ni le redistribuer**.

Cela inclut notamment :

- sa publication sur un site d'addons ;
- son intégration dans un pack d'addons ;
- la redistribution d'une copie ;
- la diffusion d'une version modifiée.

Toute utilisation de ce type nécessite une autorisation préalable.
