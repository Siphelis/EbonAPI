# 🧩 EbonAPI

**Gemeinsame Dienste für Ebonhold-Addons.**

[EbonAPI](https://github.com/Siphelis/EbonAPI) ist ein Addon, das gemeinsame Funktionen bereitstellt, die andere Addons direkt nutzen können.

Es bietet unter anderem Dienste, um mit dem Server zu kommunizieren, Daten zwischen Spielern auszutauschen, gespeicherte Daten zu verwalten, eine gemeinsame Sprache zu teilen, Updates zu erkennen und die Leistung zu überwachen.

Addons können nur die Dienste nutzen, die sie brauchen. Sie behalten ihre Funktionen und Daten und können ihre Oberfläche ganz oder teilweise dem Fenster von [EbonAPI](https://github.com/Siphelis/EbonAPI) überlassen.

[EbonAPI](https://github.com/Siphelis/EbonAPI) wird derzeit genutzt von:

[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad)

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

Entwickler: Die [Entwicklerdokumentation](https://siphelis.github.io/EbonAPI/), auf Englisch, erklärt, wie ein Addon an [EbonAPI](https://github.com/Siphelis/EbonAPI) angebunden wird.

---

## Inhaltsverzeichnis

- [Warum EbonAPI](#-warum-ebonapi)
- [Funktionen](#-funktionen)
- [Installation](#-installation)
- [Das EbonAPI-Fenster](#-das-ebonapi-fenster)
- [Code-Aufbau](#-code-aufbau--wie-es-funktioniert)
- [Sprachen](#-sprachen)
- [Lizenz & Danksagung](#-lizenz--danksagung)

---

## 🔥 Warum EbonAPI

Mehrere Addons können dieselben Funktionen brauchen: mit dem Ebonhold-Server kommunizieren, Daten an andere Spieler senden, eine gemeinsame Sprache verwalten, Daten speichern oder prüfen, ob eine neue Version verfügbar ist.

[EbonAPI](https://github.com/Siphelis/EbonAPI) bündelt diese Funktionen und stellt sie den Addons zur Verfügung, die sie nutzen möchten.

Ein Addon kann sich so mit den Diensten von [EbonAPI](https://github.com/Siphelis/EbonAPI) verbinden, statt diese Funktionen selbst neu umsetzen zu müssen.

[EbonAPI](https://github.com/Siphelis/EbonAPI) übernimmt dann ihren gemeinsamen Betrieb: Empfang von Servernachrichten, Verwaltung der Sendewarteschlangen, Austausch zwischen Spielern, gemeinsame Daten, Sprache, Diagnose und Update-Benachrichtigungen.

Jedes Addon bleibt in seiner Funktionsweise unabhängig und wählt selbst, welche Dienste von [EbonAPI](https://github.com/Siphelis/EbonAPI) es nutzen möchte.

Wird derselbe Dienst von mehreren Addons genutzt, kann [EbonAPI](https://github.com/Siphelis/EbonAPI) ihn außerdem zentral verwalten. Eine gemeinsame Servernachricht kann zum Beispiel einmal verarbeitet und dann an die betroffenen Addons weitergegeben werden.

## ✨ Funktionen

### Kommunikation mit dem Server

[EbonAPI](https://github.com/Siphelis/EbonAPI) bietet Addons eine gemeinsame Schnittstelle, um mit den Funktionen des Ebonhold-Servers und von ProjectEbonhold zu kommunizieren.

Die empfangenen Daten können von [EbonAPI](https://github.com/Siphelis/EbonAPI) verarbeitet und dann den Addons zur Verfügung gestellt werden, die sie brauchen.

Das betrifft unter anderem Daten zu Runs, Echo-Builds, Seelenasche und weiteren Funktionen des Servers.

### Kommunikation zwischen Spielern

Addons können [EbonAPI](https://github.com/Siphelis/EbonAPI) nutzen, um Daten mit anderen Spielern auszutauschen, die dieselben Funktionen verwenden.

[AutoCallboard](https://github.com/Siphelis/autocallboard) nutzt diesen Dienst insbesondere, um von Spielern gespeicherte Routen mit den anderen Nutzern des Addons zu teilen.

[EbonAPI](https://github.com/Siphelis/EbonAPI) übernimmt die Übertragung dieser Daten und ihre Zustellung an das betroffene Addon.

Der technische Austausch bleibt in den Chatfenstern des Spielers unsichtbar.

### Verwaltung der Sendungen

Die von Addons gesendeten Nachrichten laufen über eine gemeinsame Warteschlange, die [EbonAPI](https://github.com/Siphelis/EbonAPI) verwaltet.

Die Sendungen werden getaktet, um die Flood-Grenzen von World of Warcraft einzuhalten und zu verhindern, dass mehrere Addons gleichzeitig ihre eigenen Nachrichtenströme senden.

### Gemeinsame Daten

[EbonAPI](https://github.com/Siphelis/EbonAPI) kann bestimmte gemeinsame Daten aufbewahren und bereitstellen, damit mehrere Addons sie nutzen können, ohne dass jedes sie einzeln abrufen oder verarbeiten muss.

Jedes Addon behält dennoch seine eigenen Daten, wenn sie nur seine eigene Funktionsweise betreffen.

### Gemeinsame Sprache

Addons können das Sprachsystem von [EbonAPI](https://github.com/Siphelis/EbonAPI) nutzen.

Die gewählte Sprache wird dann zwischen allen Addons geteilt, die diesen Dienst nutzen.

Hat ein Addon keine Übersetzung für die gewählte Sprache, verwendet es automatisch Englisch, ohne die Sprache der anderen Addons zu ändern.

### Update-Benachrichtigungen

Ein Addon kann [EbonAPI](https://github.com/Siphelis/EbonAPI) seine Version und seinen Downloadlink mitteilen.

[EbonAPI](https://github.com/Siphelis/EbonAPI) kann dann erkennen, wenn unter den Spielern eine neuere Version im Umlauf ist, und eine Update-Benachrichtigung anzeigen.

Diese Benachrichtigung wird pro Sitzung nur einmal für jede neu erkannte Version angezeigt.

### Echo-Builds

[EbonAPI](https://github.com/Siphelis/EbonAPI) kann Addons die nötigen Funktionen bereitstellen, um Informationen zu Echo-Builds abzurufen und auszutauschen.

[EbonBuilds](https://github.com/Siphelis/EbonBuilds) nutzt diesen Dienst insbesondere, um die Klasse und die Builds eines Spielers mit anderen Nutzern zu teilen.

Die Informationen werden nur erneut gesendet, wenn eine Änderung erkannt wird.

### Gemeinsame Oberfläche

[EbonAPI](https://github.com/Siphelis/EbonAPI) hat ein eigenes Einstellungsfenster, das Sie über das Spielmenü öffnen.

Addons können dort ihre Einstellungen anzeigen, mit demselben Aussehen für alle, oder ihre eigene Oberfläche behalten und dem in [EbonAPI](https://github.com/Siphelis/EbonAPI) gewählten Erscheinungsbild folgen: Farben, Skalierung, Deckkraft, Schatten, Ecken und Seite der Reiter.

Ihre Wahl hat immer Vorrang vor den Werten, die ein Addon für sich selbst festlegt.

### Diagnose und Leistung

[EbonAPI](https://github.com/Siphelis/EbonAPI) enthält mehrere Werkzeuge, um seine eigene Funktion und die der Addons zu überprüfen, die seine Dienste nutzen.

Die Seite **Diagnose** im Fenster von [EbonAPI](https://github.com/Siphelis/EbonAPI) zeigt einen Überblick über die verbundenen Addons und den Zustand der verschiedenen Dienste sowie ihren Speicher- und CPU-Verbrauch und die aktiven Frames.

## 📦 Installation

1. Laden Sie die neueste Version von [**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest) herunter.
2. Entpacken Sie den Ordner `EbonAPI` nach:
   `Interface/AddOns/`
3. Prüfen Sie im AddOn-Auswahlbildschirm von World of Warcraft, dass **[EbonAPI](https://github.com/Siphelis/EbonAPI)** aktiviert ist.

[EbonAPI](https://github.com/Siphelis/EbonAPI) stellt seine Funktionen den installierten Addons zur Verfügung, die sie nutzen möchten. Seine Einstellungen befinden sich in einem eigenen Fenster: siehe [Das EbonAPI-Fenster](#-das-ebonapi-fenster).

Kompatible Addons erkennen [EbonAPI](https://github.com/Siphelis/EbonAPI) und können sich dann mit den Diensten verbinden, die sie unterstützen.

## 🪟 Das EbonAPI-Fenster

[EbonAPI](https://github.com/Siphelis/EbonAPI) hat keine Slash-Befehle: Alles läuft über sein Fenster.

Öffnen Sie es über das Spielmenü (**Esc → EbonAPI**) oder über die Interface-Optionen, Reiter AddOns.

| Seite                 | Inhalt                                                                                                                                                    |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Allgemein**         | Die gemeinsame Sprache, die alle kompatiblen Addons teilen.                                                                                               |
| **Erscheinungsbild**  | Farben, Skalierung, Deckkraft, Schatten unter Fenstern, Ecken, Reiter links oder rechts, Fensterpositionen sperren.                                       |
| **Verbundene Addons** | Die Addons, die [EbonAPI](https://github.com/Siphelis/EbonAPI) nutzen, und ihre Versionen.                                                                |
| **Diagnose**          | Der Zustand von [EbonAPI](https://github.com/Siphelis/EbonAPI) und seinen Diensten, das Protokoll, die gespeicherten Daten, Debug-Meldungen und Leistung. |

Addons, die ihre Einstellungen [EbonAPI](https://github.com/Siphelis/EbonAPI) überlassen, haben einen eigenen Reiter unter **Addons**. Das Suchfeld oben findet eine Einstellung in allen Reitern.

Um ein Problem zu melden, fügen Sie bitte einen Screenshot der Seite **Diagnose** bei, nachdem Sie auf **Status** und danach auf **Protokoll** geklickt haben.

Diese Angaben helfen dabei, den Zustand von [EbonAPI](https://github.com/Siphelis/EbonAPI), die genutzten Dienste und die mögliche Ursache des Problems leichter zu erkennen.

## 🧠 Code-Aufbau — wie es funktioniert

[EbonAPI](https://github.com/Siphelis/EbonAPI) ist in mehrere Module gegliedert, die den Diensten entsprechen, die es den Addons bereitstellt.

| Ordner / Datei          | Aufgabe                                                                                                                                                                                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Core/`                 | Gemeinsame Funktionen von [EbonAPI](https://github.com/Siphelis/EbonAPI): Ereignisse, Timer, gespeicherte Daten, internes Protokoll und Leistungsmessung.                                                                                   |
| `Server/`               | Dienste zur Kommunikation mit dem Ebonhold-Server und ProjectEbonhold sowie Verwaltung der Serverdaten, die den Addons bereitgestellt werden können: Runs, Builds, Seelenasche usw.                                                         |
| `Net/`                  | Dienste zur Kommunikation zwischen Spielern: Sendewarteschlange, Flüsternachrichten, Echo-Profile, zwischen Addons geteilte Daten und Update-Benachrichtigungen.                                                                            |
| `Language/`, `Locales/` | Verwaltung des gemeinsamen Sprachdienstes und der eigenen Übersetzungen von [EbonAPI](https://github.com/Siphelis/EbonAPI).                                                                                                                 |
| `UI/`                   | Das Fenster von [EbonAPI](https://github.com/Siphelis/EbonAPI): sein Aussehen, die gemeinsamen Einstellungen des Erscheinungsbilds, die Einstellungen der Addons und die eigenen Seiten von [EbonAPI](https://github.com/Siphelis/EbonAPI). |
| `Boot.lua`              | Initialisierung von [EbonAPI](https://github.com/Siphelis/EbonAPI) und Einrichtung seiner Dienste.                                                                                                                                          |
| `EbonAPI.toc`           | Manifest des Addons: Metadaten, gespeicherte Variable `EbonAPIDB` und Ladereihenfolge der Dateien.                                                                                                                                          |

Addons, die [EbonAPI](https://github.com/Siphelis/EbonAPI) nutzen, können sich so je nach Bedarf mit den verschiedenen Diensten verbinden, ohne sich um deren interne Funktionsweise kümmern zu müssen.

## 🌍 Sprachen

[EbonAPI](https://github.com/Siphelis/EbonAPI) ist vollständig verfügbar auf:

- Englisch
- Französisch
- Deutsch
- Spanisch

Es bietet außerdem einen Sprachdienst, den andere Addons nutzen können.

Die im Fenster von [EbonAPI](https://github.com/Siphelis/EbonAPI) (**Allgemein → Sprache**) oder im Sprachmenü eines Addons, das diesen Dienst nutzt, gewählte Sprache wird mit den anderen kompatiblen Addons geteilt.

Hat ein Addon keine Übersetzung für die gewählte Sprache, verwendet es automatisch seine englische Fassung.

## 📜 Lizenz & Danksagung

Addon entwickelt von **Siphelis**.

Entwickelt für ProjectEbonhold, die Client-Oberfläche des Ebonhold-Servers.

[EbonAPI](https://github.com/Siphelis/EbonAPI) wird unter der [PolyForm Strict License 1.0.0](LICENSE) veröffentlicht.

Sie dürfen es für nichtkommerzielle Zwecke nutzen, es aber **weder verkaufen noch verändern noch weiterverbreiten**.

Dazu gehören insbesondere:

- die Veröffentlichung auf einer Addon-Seite
- die Aufnahme in ein Addon-Paket
- die Weitergabe einer Kopie
- die Verbreitung einer veränderten Version

Jede solche Nutzung erfordert eine vorherige Erlaubnis.
