# 🧩 EbonAPI

**Servicios comunes para los addons de Ebonhold.**

[EbonAPI](https://github.com/Siphelis/EbonAPI) es un addon diseñado para ofrecer funciones comunes que otros addons pueden usar directamente.

Proporciona, entre otros, servicios para comunicarse con el servidor, intercambiar datos entre jugadores, gestionar los datos guardados, compartir un idioma común, detectar actualizaciones o supervisar el rendimiento.

Los addons pueden usar solo los servicios que necesitan, conservando su propia interfaz, sus datos y sus funciones.

[EbonAPI](https://github.com/Siphelis/EbonAPI) lo usan actualmente:

[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad)

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

Desarrolladores: la [documentación para desarrolladores](https://siphelis.github.io/EbonAPI/), en inglés, explica cómo conectar un addon a [EbonAPI](https://github.com/Siphelis/EbonAPI).

---

## Tabla de contenidos

- [Por qué EbonAPI](#-por-qué-ebonapi)
- [Características](#-características)
- [Instalación](#-instalación)
- [Comandos slash](#-comandos-slash)
- [Anatomía del código](#-anatomía-del-código--cómo-funciona)
- [Idiomas](#-idiomas)
- [Licencia y créditos](#-licencia-y-créditos)

---

## 🔥 Por qué EbonAPI

Varios addons pueden necesitar las mismas funciones: comunicarse con el servidor de Ebonhold, enviar datos a otros jugadores, gestionar un idioma común, guardar datos o comprobar si hay una nueva versión disponible.

[EbonAPI](https://github.com/Siphelis/EbonAPI) reúne estas funciones y las pone a disposición de los addons que quieran usarlas.

Así, un addon puede conectarse a los servicios que ofrece [EbonAPI](https://github.com/Siphelis/EbonAPI) en lugar de tener que crear su propia gestión de estas funciones.

[EbonAPI](https://github.com/Siphelis/EbonAPI) se encarga entonces de su funcionamiento común: recepción de los mensajes del servidor, gestión de las colas de envío, intercambios entre jugadores, datos compartidos, idioma, diagnóstico y avisos de actualización.

Cada addon sigue siendo independiente en su funcionamiento y elige qué servicios de [EbonAPI](https://github.com/Siphelis/EbonAPI) quiere usar.

Cuando varios addons usan el mismo servicio, [EbonAPI](https://github.com/Siphelis/EbonAPI) también puede gestionarlo de forma centralizada. Un mensaje común del servidor, por ejemplo, puede procesarse una sola vez y transmitirse después a los addons afectados.

## ✨ Características

### Comunicación con el servidor

[EbonAPI](https://github.com/Siphelis/EbonAPI) ofrece a los addons una interfaz común para comunicarse con las funciones que ponen a su disposición el servidor de Ebonhold y ProjectEbonhold.

[EbonAPI](https://github.com/Siphelis/EbonAPI) puede procesar los datos recibidos y ponerlos a disposición de los addons que los necesitan.

Esto incluye, entre otros, datos relacionados con las runs, los builds de ecos, las cenizas y las demás funciones que ofrece el servidor.

### Comunicación entre jugadores

Los addons pueden usar [EbonAPI](https://github.com/Siphelis/EbonAPI) para intercambiar datos con otros jugadores que usan las mismas funciones.

[AutoCallboard](https://github.com/Siphelis/autocallboard) usa especialmente este servicio para compartir las rutas guardadas por los jugadores con los demás usuarios del addon.

[EbonAPI](https://github.com/Siphelis/EbonAPI) se encarga de transmitir esos datos y de entregarlos al addon correspondiente.

Los intercambios técnicos siguen siendo invisibles en las ventanas de chat del jugador.

### Gestión de los envíos

Los mensajes que envían los addons pasan por una cola común gestionada por [EbonAPI](https://github.com/Siphelis/EbonAPI).

Los envíos se acompasan para respetar los límites anti-flood de World of Warcraft y evitar que varios addons envíen a la vez sus propios flujos de mensajes.

### Datos compartidos

[EbonAPI](https://github.com/Siphelis/EbonAPI) puede conservar y poner a disposición ciertos datos comunes para que varios addons puedan usarlos sin que cada uno tenga que obtenerlos o procesarlos por separado.

Aun así, cada addon conserva sus propios datos cuando solo afectan a su funcionamiento.

### Idioma común

Los addons pueden usar el sistema de idioma que ofrece [EbonAPI](https://github.com/Siphelis/EbonAPI).

El idioma elegido se comparte entonces entre todos los addons que usan este servicio.

Si un addon no tiene traducción al idioma seleccionado, usa automáticamente el inglés sin cambiar el idioma que usan los demás addons.

### Avisos de actualización

Un addon puede declarar a [EbonAPI](https://github.com/Siphelis/EbonAPI) su versión y su enlace de descarga.

[EbonAPI](https://github.com/Siphelis/EbonAPI) puede entonces detectar cuándo circula entre los jugadores una versión más reciente y mostrar un aviso de actualización.

Este aviso solo se muestra una vez por sesión para cada nueva versión detectada.

### Builds de ecos

[EbonAPI](https://github.com/Siphelis/EbonAPI) puede ofrecer a los addons las funciones necesarias para obtener e intercambiar la información relacionada con los builds de ecos.

[EbonBuilds](https://github.com/Siphelis/EbonBuilds) usa este servicio, en particular, para compartir la clase y los builds de un jugador con los demás usuarios.

La información solo se vuelve a enviar cuando se detecta un cambio.

### Diagnóstico y rendimiento

[EbonAPI](https://github.com/Siphelis/EbonAPI) incluye varias herramientas para comprobar su funcionamiento y el de los addons que usan sus servicios.

`/eapi status` muestra una vista general de los addons conectados a [EbonAPI](https://github.com/Siphelis/EbonAPI) y del estado de sus distintos servicios.

`/eapi perf` permite consultar su uso de memoria, de CPU y los marcos activos.

## 📦 Instalación

1. Descargue la última versión de [**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest).
2. Descomprima la carpeta `EbonAPI` en:
   `Interface/AddOns/`
3. En la pantalla de selección de AddOns de World of Warcraft, compruebe que **[EbonAPI](https://github.com/Siphelis/EbonAPI)** esté activado.

[EbonAPI](https://github.com/Siphelis/EbonAPI) no tiene una interfaz principal destinada al jugador.

Pone sus funciones a disposición de los addons instalados que quieran usarlas.

Los addons compatibles detectan [EbonAPI](https://github.com/Siphelis/EbonAPI) y pueden conectarse entonces a los servicios que admiten.

## 💬 Comandos slash

Los comandos `/eapi` y `/ebonapi` son equivalentes.

| Comando                       | Efecto                                                                                                              |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `/eapi` o `/eapi help`        | Muestra la lista de comandos disponibles.                                                                           |
| `/eapi status`                | Muestra el estado de [EbonAPI](https://github.com/Siphelis/EbonAPI), de sus servicios y de los addons que los usan. |
| `/eapi lang [code]`           | Muestra o cambia el idioma común (`enUS`, `frFR`, `deDE`, `esES`).                                                  |
| `/eapi perf [addon]`          | Muestra el uso de memoria, de CPU y los marcos activos de cada addon.                                               |
| `/eapi trace [n]`             | Muestra las últimas `n` entradas del diagnóstico.                                                                   |
| `/eapi debug [addon] on\|off` | Activa o desactiva la información de depuración detallada de un addon.                                              |
| `/eapi db`                    | Muestra un resumen de los datos guardados por [EbonAPI](https://github.com/Siphelis/EbonAPI).                       |

Para informar de un problema, adjunte preferiblemente el resultado de los comandos:

`/eapi status`

y

`/eapi trace 30`

Esta información permite identificar más fácilmente el estado de [EbonAPI](https://github.com/Siphelis/EbonAPI), los servicios en uso y el posible origen del problema.

## 🧠 Anatomía del código — cómo funciona

[EbonAPI](https://github.com/Siphelis/EbonAPI) está organizado en varios módulos que corresponden a los servicios que pone a disposición de los addons.

| Carpeta / archivo       | Función                                                                                                                                                                                  |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Core/`                 | Funciones comunes de [EbonAPI](https://github.com/Siphelis/EbonAPI): eventos, temporizadores, datos guardados, registro interno y medición del rendimiento.                              |
| `Server/`               | Servicios de comunicación con el servidor de Ebonhold y ProjectEbonhold, y gestión de los datos del servidor que pueden ponerse a disposición de los addons: runs, builds, cenizas, etc. |
| `Net/`                  | Servicios de comunicación entre jugadores: cola de envío, susurros, perfiles de ecos, datos compartidos entre addons y avisos de actualización.                                          |
| `Language/`, `Locales/` | Gestión del servicio de idioma común y de las traducciones propias de [EbonAPI](https://github.com/Siphelis/EbonAPI).                                                                    |
| `Boot.lua`              | Inicialización de [EbonAPI](https://github.com/Siphelis/EbonAPI), puesta en marcha de sus servicios y gestión de los comandos `/eapi`.                                                   |
| `EbonAPI.toc`           | Manifiesto del addon: metadatos, variable guardada `EbonAPIDB` y orden de carga de los archivos.                                                                                         |

Así, los addons que usan [EbonAPI](https://github.com/Siphelis/EbonAPI) pueden conectarse a los distintos servicios según sus necesidades, sin tener que ocuparse de su funcionamiento interno.

## 🌍 Idiomas

[EbonAPI](https://github.com/Siphelis/EbonAPI) está disponible por completo en:

- inglés
- francés
- alemán
- español

También ofrece un servicio de idioma que pueden usar otros addons.

El idioma seleccionado con `/eapi lang`, o desde el menú de idioma de un addon que use este servicio, se comparte con los demás addons compatibles.

Si un addon no tiene traducción al idioma seleccionado, usa automáticamente su versión en inglés.

## 📜 Licencia y créditos

Addon desarrollado por **Siphelis**.

Diseñado para ProjectEbonhold, la interfaz del cliente del servidor Ebonhold.

[EbonAPI](https://github.com/Siphelis/EbonAPI) se distribuye bajo la [PolyForm Strict License 1.0.0](LICENSE).

Puede usarlo con fines no comerciales, pero **no puede venderlo, modificarlo ni redistribuirlo**.

Esto incluye, en particular:

- publicarlo en un sitio de addons
- incluirlo en un pack de addons
- redistribuir una copia
- difundir una versión modificada

Cualquier uso de este tipo requiere un permiso previo.
