# 🧩 EbonAPI

**Shared services for Ebonhold addons.**

[EbonAPI](https://github.com/Siphelis/EbonAPI) is an addon designed to provide common features that other addons can use directly.

In particular, it provides services to communicate with the server, exchange data between players, manage saved data, share a common language, detect updates and track performance.

Addons can use only the services they need. They keep their own features and data, and can hand all or part of their interface to the [EbonAPI](https://github.com/Siphelis/EbonAPI) window.

[EbonAPI](https://github.com/Siphelis/EbonAPI) is currently used by:

[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad)

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

Developers: the [developer documentation](https://siphelis.github.io/EbonAPI/) explains how to connect an addon to [EbonAPI](https://github.com/Siphelis/EbonAPI).

---

## Table of Contents

- [Why EbonAPI](#-why-ebonapi)
- [Features](#-features)
- [Installation](#-installation)
- [The EbonAPI window](#-the-ebonapi-window)
- [Code anatomy](#-code-anatomy--how-it-works)
- [Languages](#-languages)
- [License & credits](#-license--credits)

---

## 🔥 Why EbonAPI

Several addons may need the same features: communicating with the Ebonhold server, sending data to other players, managing a common language, saving data or checking whether a new version is available.

[EbonAPI](https://github.com/Siphelis/EbonAPI) brings these features together and makes them available to the addons that want to use them.

An addon can then connect to the services [EbonAPI](https://github.com/Siphelis/EbonAPI) provides instead of having to build its own handling of these features.

[EbonAPI](https://github.com/Siphelis/EbonAPI) takes care of what they share: receiving server messages, managing send queues, exchanges between players, shared data, language, diagnostics and update notifications.

Each addon remains independent in how it works and chooses which [EbonAPI](https://github.com/Siphelis/EbonAPI) services it wants to use.

When the same service is used by several addons, [EbonAPI](https://github.com/Siphelis/EbonAPI) can also handle it centrally. A common server message, for example, can be processed once and then passed on to the addons concerned.

## ✨ Features

### Communicating with the server

[EbonAPI](https://github.com/Siphelis/EbonAPI) gives addons a common interface to communicate with the features provided by the Ebonhold server and ProjectEbonhold.

The data received can be processed by [EbonAPI](https://github.com/Siphelis/EbonAPI) and then made available to the addons that need it.

This includes data related to runs, Echo builds, Soul Ashes and the other features offered by the server.

### Communicating between players

Addons can use [EbonAPI](https://github.com/Siphelis/EbonAPI) to exchange data with other players using the same features.

[AutoCallboard](https://github.com/Siphelis/autocallboard) uses this service in particular to share routes saved by players with the addon's other users.

[EbonAPI](https://github.com/Siphelis/EbonAPI) handles the transmission of this data and its delivery to the addon concerned.

These technical exchanges stay invisible in the player's chat windows.

### Send management

Messages sent by addons go through a common queue managed by [EbonAPI](https://github.com/Siphelis/EbonAPI).

Sending is paced to respect World of Warcraft's anti-flood limits and to prevent several addons from sending their own message streams at the same time.

### Shared data

[EbonAPI](https://github.com/Siphelis/EbonAPI) can keep and provide some common data so that several addons can use it without each of them having to fetch or process it separately.

Each addon still keeps its own data when it only concerns how that addon works.

### Common language

Addons can use the language system provided by [EbonAPI](https://github.com/Siphelis/EbonAPI).

The chosen language is then shared between all the addons that use this service.

If an addon has no translation for the selected language, it automatically uses English without changing the language used by the other addons.

### Update notifications

An addon can declare its version and download link to [EbonAPI](https://github.com/Siphelis/EbonAPI).

[EbonAPI](https://github.com/Siphelis/EbonAPI) can then detect when a newer version is circulating among players and display an update notification.

This notification is only shown once per session for each new version detected.

### Echo builds

[EbonAPI](https://github.com/Siphelis/EbonAPI) can provide addons with the features needed to retrieve and exchange information about Echo builds.

[EbonBuilds](https://github.com/Siphelis/EbonBuilds) uses this service in particular to share a player's class and builds with other users.

The information is only sent again when a change is detected.

### Common interface

[EbonAPI](https://github.com/Siphelis/EbonAPI) has its own settings window, opened from the game menu.

Addons can show their settings there, with the same look for all, or keep their own interface and follow the appearance chosen in [EbonAPI](https://github.com/Siphelis/EbonAPI): colors, scale, opacity, shadow, corners and the side of the tabs.

Your choices always win over the values an addon sets for itself.

### Diagnostics and performance

[EbonAPI](https://github.com/Siphelis/EbonAPI) includes several tools to check how it is working, along with the addons that use its services.

The **Diagnostics** page of the [EbonAPI](https://github.com/Siphelis/EbonAPI) window shows an overview of the connected addons and the state of the various services, along with their memory use, CPU use and active frames.

## 📦 Installation

1. Download the latest version of [**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest).
2. Unzip the `EbonAPI` folder into:
   `Interface/AddOns/`
3. From the World of Warcraft AddOns selection screen, make sure **[EbonAPI](https://github.com/Siphelis/EbonAPI)** is enabled.

[EbonAPI](https://github.com/Siphelis/EbonAPI) makes its features available to the installed addons that want to use them. Its settings are in its own window: see [The EbonAPI window](#-the-ebonapi-window).

Compatible addons detect [EbonAPI](https://github.com/Siphelis/EbonAPI) and can then connect to the services they support.

## 🪟 The EbonAPI window

[EbonAPI](https://github.com/Siphelis/EbonAPI) has no slash command: everything goes through its window.

Open it from the game menu (**Esc → EbonAPI**), or from the interface options, in the AddOns tab.

| Page                 | Contents                                                                                                                                    |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **General**          | The common language, shared by every compatible addon.                                                                                      |
| **Appearance**       | Colors, scale, opacity, shadow under windows, corners, tabs on the left or on the right, window lock.                                       |
| **Connected addons** | The addons using [EbonAPI](https://github.com/Siphelis/EbonAPI) and their versions.                                                         |
| **Diagnostics**      | The state of [EbonAPI](https://github.com/Siphelis/EbonAPI) and of its services, the trace, the saved data, debug messages and performance. |

Addons that hand their settings to [EbonAPI](https://github.com/Siphelis/EbonAPI) have their own tab, under **Addons**. The search box at the top finds a setting in every tab.

To report a problem, please include a screenshot of the **Diagnostics** page after clicking **Status**, then after clicking **Trace**.

This information makes it easier to identify the state of [EbonAPI](https://github.com/Siphelis/EbonAPI), the services in use and where the problem may come from.

## 🧠 Code anatomy — how it works

[EbonAPI](https://github.com/Siphelis/EbonAPI) is organized into several modules matching the services it makes available to addons.

| Folder / file           | Role                                                                                                                                                                                            |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Core/`                 | [EbonAPI](https://github.com/Siphelis/EbonAPI)'s common functions: events, timers, saved data, internal log and performance measurement.                                                        |
| `Server/`               | Services for communicating with the Ebonhold server and ProjectEbonhold, and handling of the server data that can be made available to addons: runs, builds, Soul Ashes, etc.                   |
| `Net/`                  | Services for communicating between players: send queue, whispers, Echo profiles, data shared between addons and update notifications.                                                           |
| `Language/`, `Locales/` | Handling of the common language service and of [EbonAPI](https://github.com/Siphelis/EbonAPI)'s own translations.                                                                               |
| `UI/`                   | The [EbonAPI](https://github.com/Siphelis/EbonAPI) window: its look, the common appearance settings, the settings of the addons and [EbonAPI](https://github.com/Siphelis/EbonAPI)'s own pages. |
| `Boot.lua`              | [EbonAPI](https://github.com/Siphelis/EbonAPI)'s initialization and setup of its services.                                                                                                      |
| `EbonAPI.toc`           | The addon manifest: metadata, saved variable `EbonAPIDB` and file load order.                                                                                                                   |

Addons using [EbonAPI](https://github.com/Siphelis/EbonAPI) can thus connect to the various services as they need, without having to handle how they work internally.

## 🌍 Languages

[EbonAPI](https://github.com/Siphelis/EbonAPI) is fully available in:

- English
- French
- German
- Spanish

It also offers a language service that other addons can use.

The language selected in the [EbonAPI](https://github.com/Siphelis/EbonAPI) window (**General → Language**), or from the language menu of an addon using this service, is shared with the other compatible addons.

If an addon has no translation for the selected language, it automatically uses its English version.

## 📜 License & credits

Addon developed by **Siphelis**.

Designed for ProjectEbonhold, the client interface of the Ebonhold server.

[EbonAPI](https://github.com/Siphelis/EbonAPI) is distributed under the [PolyForm Strict License 1.0.0](LICENSE).

You may use it for noncommercial purposes, but you may **not sell, modify, or redistribute it**.

This includes, in particular:

- publishing it on an addon site
- bundling it in an addon pack
- redistributing a copy
- distributing a modified version

Any such use requires prior permission.
