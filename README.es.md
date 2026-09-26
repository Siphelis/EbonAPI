# 🧩 EbonAPI

**Una sola base bajo todos los addons de Ebonhold.**

EbonAPI es la base común de los addons de Ebonhold de Siphelis:
[AutoCallboard](https://github.com/Siphelis/autocallboard),
[EbonBuilds](https://github.com/Siphelis/EbonBuilds),
[SkillTreeAutoLoad](https://github.com/Siphelis/SkillTreeAutoLoad) y EbonStat.
Reúne lo que cada uno hacía por su cuenta, sin tocar lo que los define: cada
addon conserva su interfaz, su propósito y su lógica. Desde la 1.1, también
lleva todo lo que circula entre jugadores: un único canal oculto, una única
cola de envío y el perfil de ecos que la matriz de EbonBuilds lee en los demás
jugadores.

EbonAPI no sustituye a Ace3 ni duplica ProjectEbonhold.

[English](README.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

---

## Tabla de contenidos

- [Por qué esta extensión](#-por-qué-esta-extensión)
- [Características](#-características)
- [Instalación](#-instalación)
- [Comandos slash](#-comandos-slash)
- [Para autores de addons](#-para-autores-de-addons)
- [Anatomía del código](#-anatomía-del-código--cómo-funciona)
- [Limitaciones conocidas](#-limitaciones-conocidas)
- [Lo que EbonAPI no hará](#-lo-que-ebonapi-no-hará)
- [Idiomas](#-idiomas)
- [Licencia y créditos](#-licencia-y-créditos)

---

## 🔥 Por qué esta extensión

No instalas EbonAPI por sí mismo: AutoCallboard, EbonBuilds, SkillTreeAutoLoad
y EbonStat se niegan a cargar sin él.

Cada uno traía su propio puente con el servidor, su propia cola de envío, su
propio almacenamiento y su propio ajuste de idioma. Tres puentes leían cada
mensaje del servidor tres veces. Tres colas se mantenían cada una por debajo
del límite anti-flood por separado, y lo superaban juntas. EbonAPI conserva uno
solo de cada, para todos.

## ✨ Características

- **Una sola cola de envío para todo el cliente** — primero los mensajes al
  servidor, luego las líneas del canal y los susurros, un envío cada 0,15 s. El
  límite anti-flood cuenta el cliente entero, no cada addon: tres colas
  independientes lo superaban, una sola se queda por debajo.
- **Un solo puente con el servidor** — cada mensaje del servidor se lee una vez
  y se entrega a los addons que lo pidieron. Un mensaje que nadie escucha no
  cuesta nada.
- **Un solo canal oculto** — `ebonapi`, retirado de tus ventanas de chat: nunca
  aparece en ellas ni un mensaje ni un aviso.
- **Una sola elección de idioma** — la eliges una vez y todos los addons la
  siguen. Un addon que no incluye ese idioma vuelve por su cuenta al inglés, sin
  imponer el inglés a los demás.
- **Avisos de actualización** — cuando otro jugador usa una versión más
  reciente de uno de tus addons, se te avisa una vez por sesión, con el enlace
  de descarga que da el addon que tienes instalado. Nunca un enlace venido de
  otro jugador.
- **Tus builds de ecos, compartidos una vez** — tu clase y los builds de ecos
  que el servidor guarda para tu personaje salen por el canal para la matriz de
  EbonBuilds de los demás jugadores, y solo vuelven a salir si cambian.
- **Errores que siguen visibles** — el fallo de un addon nunca arrastra a los
  demás y nunca desaparece: se transmite, con su pila, a BugSack, Swatter o al
  marco de errores de Blizzard.
- **Diagnóstico integrado** — `/eapi status` muestra de un vistazo el puente, el
  canal, la cola y ProjectEbonhold; `/eapi perf` mide la memoria y la CPU de
  cada addon.

## 📦 Instalación

1. [**EbonAPI**](https://github.com/Siphelis/EbonAPI/releases/latest) — descarga la última versión.
2. Descomprime la carpeta `EbonAPI` en
   `Interface/AddOns/`.
3. Comprueba en la pantalla de selección de AddOns que **EbonAPI** esté
   marcado, junto con los addons que lo usan.

EbonAPI no muestra nada por sí solo. Solo se une a su canal cuando un addon se
registra con él.

## 💬 Comandos slash

Alias: `/eapi` y `/ebonapi`.

| Comando | Efecto |
| --- | --- |
| `/eapi` (o `help`) | Lista los comandos. |
| `/eapi status` | Resumen: addons registrados, puente con el servidor, canal, cola de envío, perfil, versiones, servicios de ProjectEbonhold, mensajes rechazados. |
| `/eapi trace [n]` | Las últimas `n` entradas del diagnóstico (20 por defecto). |
| `/eapi debug [addon\|*] on\|off` | Activa o desactiva la salida detallada, para un addon o para todos. |
| `/eapi lang [code]` | Muestra o cambia el idioma compartido (`enUS`, `frFR`, `deDE`, `esES`). |
| `/eapi db` | Resumen de los datos guardados. |
| `/eapi opcodes` | Opcodes del servidor conocidos. |
| `/eapi senders` | Remitentes observados en el puente con el servidor. |
| `/eapi perf [addon] [etiqueta\|reset\|gc]` | Memoria, marcos activos y CPU, por addon. |

El búfer de diagnóstico conserva los últimos 128 eventos, incluso con el debug
desactivado: lo que interesa es lo que pasó *antes* de que alguien pensara en
activar la traza. Para informar de un problema, `/eapi status` y
`/eapi trace 30` son las dos salidas que vale la pena copiar.

## 🔌 Para autores de addons

Todo lo que sigue es el contrato entre EbonAPI y los addons que lo usan.

### Primeros pasos

EbonAPI es una dependencia obligatoria. En el `.toc` de cada consumidor:

```
## Dependencies: EbonAPI
```

```lua
local api = EbonAPI:NewAddon("MyAddon", 1, 1)   -- nombre, versión mayor requerida, menor requerida

if not api then
  return   -- versión incompatible; EbonAPI ya ha explicado el motivo en el chat
end
```

La versión mayor debe coincidir exactamente; la menor debe ser al menos la
pedida. Después todo pasa por este identificador, lo que permite que
`api:OffAll()` lo retire todo de una vez.

### Errores

Un error está para corregirse. Por eso EbonAPI no decide nada en su lugar: lo
hace visible para quien puede corregirlo, y se aparta.

**Una llamada incorrecta falla de inmediato.** Pasar algo que no sea una
función a `api:On`, un opcode en forma de cadena a `Bridge.on`, una tabla
ausente a `api:DB`: son fallos del código que llama. Lanzan un error que
apunta a **la línea del addon responsable** (`error(..., 2)`), no a una línea
de EbonAPI donde no habría nada que corregir. Ninguna de estas funciones
devuelve `false` en silencio.

**El error de un suscriptor se captura y luego se libera.** El `pcall` solo
sirve para que un fallo de AutoCallboard no arrastre a EbonStat. Justo después,
el error vuelve a salir por `geterrorhandler()`: Swatter, BugSack o el marco de
errores de Blizzard lo reciben con su pila, como si nunca se hubiera capturado.

No hay deduplicación, ni silenciamiento, ni cuarentena automática. Un
suscriptor que falla se omite solo en esa distribución y se vuelve a llamar en
el siguiente evento: cada evento es un nuevo intento.

**Los datos externos no son errores.** Un mensaje del servidor ilegible, un
guardado dañado, un servicio de ProjectEbonhold ausente: es el día a día de un
cliente. Se validan, se tratan y se **cuentan**. El recuento aparece en
`/eapi status`, porque un rechazo que nadie ve sería un error sin solución
detrás.

### Eventos

```lua
api:On("READY", function(event, version) end)
api:Off("READY", fn)
api:OffAll()
```

Algunos eventos son **persistentes**: reproducen su último estado en el momento
de la suscripción. Sin eso, un addon cargado después de la llegada de un dato
del servidor se quedaría ciego hasta el mensaje siguiente, que puede no llegar
nunca.

| Evento | Persistente | Contenido |
|---|---|---|
| `READY` | sí | versión |
| `LANGUAGE_CHANGED` | sí | código |
| `FEATURE_CHANGED` | no | nombre, disponible |
| `SERVER_RUN_DATA` | sí | tabla de la partida |
| `SERVER_ASH` | sí | `{ spendable, committed, source }`, publicado solo cuando el saldo cambia |
| `SERVER_BUILDS` | sí | lista de builds |
| `SERVER_BUILD_ACTIVE` | sí | ranura, lista |
| `SERVER_LOADOUT` | sí | loadout del árbol |
| `SERVER_INTENSITY` | sí | tabla de intensidad |
| `SERVER_MULTIPLIER` | sí | número |
| `SERVER_MESSAGE` | no | opcode, cuerpo, remitente |
| `STREAM_TIMEOUT` | no | opcode, id, recibidos, total |
| `SEND_FAILED` | no | tipo, luego la línea (canal, servidor) o el prefijo y el destinatario (susurro) |
| `CHANNEL_JOINED` | sí | índice del canal común |
| `CHANNEL_LOST` | no | — |
| `PEER_OFFLINE` | no | nombre, envíos retirados de la cola |
| `UPDATE_AVAILABLE` | no | addon, versión disponible, versión instalada, enlace |
| `PROFILE_SLOTS` | no | remitente, clase, ranuras |
| `PROFILE_BUILD` | no | remitente, clase, ranura, hash, ecos |
| `PROFILE_BANS` | no | remitente, clase, hash, listas |

Un callback puede suscribirse o cancelar su suscripción mientras se ejecuta.

### Eventos del cliente y temporizadores

```lua
api:OnEvent("PLAYER_REGEN_DISABLED", fn)
api:OffEvent("PLAYER_REGEN_DISABLED", fn)

api:Tick("refresh", 0.5, fn)   -- el identificador lleva como prefijo el nombre del addon
api:Untick("refresh")
```

Un único marco lo lleva todo. Su `OnUpdate` solo se ejecuta mientras quede al
menos un temporizador vivo.

El bus mantiene dos registros por evento. Los suscriptores consumidores pasan
por una llamada protegida, para que el fallo de uno no arrastre a los demás.
Los suscriptores del núcleo (`Bus.onCore`, reservado a EbonAPI) se llaman
directamente: protegerlos de sí mismos no protegería a nadie y costaría una
llamada protegida más en cada evento. Un evento sin suscriptor consumidor no
cuesta, por tanto, **ninguna** protección.

### Puente con el servidor

```lua
api:OnServer(EbonAPI.SS.PLAYER_RUN_DATA, function(body, opcode, sender) end)
api:SendServer(EbonAPI.CS.BUILD_SELECT, "3")
api:RequestServer(EbonAPI.CS.REFRESH_BUILDS, "", 30)   -- agrupado durante 30 s
```

Los envíos pasan por la cola única de `Net/Queue` (ver
[Canal común](#canal-común)): cinco peticiones emitidas en el mismo marco por
tres addons se perderían o cortarían la conexión. Los mensajes al servidor
pasan antes que todo lo demás. `RequestServer` agrupa entre addons: el servidor
solo recibe la petición una vez por intervalo. Dos peticiones son la misma si
llevan el mismo opcode y el mismo cuerpo.

La gramática de recepción es la unión de lo que aceptaban las tres
implementaciones originales: un mensaje sin cuerpo se entrega (dos de las tres
lo descartaban), y se aceptan anchos de fragmento tanto fijos como variables.

Coste de un mensaje recibido, sea cual sea el número de suscriptores: **una**
llamada protegida, **un** patrón evaluado, **una** lectura del reloj y
**ninguna** asignación aparte del propio cuerpo. Un opcode que nadie escucha no
cuesta ninguna protección.

### Canal común

```lua
api:OnChannel("A", "H", function(sender, body, letter, op) end)
api:OffChannel("A", "H", fn)
api:Say("H", "digests")                 -- bajo la letra del addon, dividido si hace falta
api:IsChannelJoined()
```

Un único canal oculto, `ebonapi`, para todo lo que se dirige a todos. Cada
addon habla en él bajo su letra (`A` AutoCallboard, `B` EbonBuilds,
`S` SkillTreeAutoLoad, `G` EbonStat, `E` EbonAPI) y solo oye lo que pide: una
línea con otra letra u otra op se detiene en una búsqueda en tabla.

Una línea tiene la forma `EA1:<letra>:<op>:<n.º>.<k>/<n>:<trozo>`, 255
caracteres como máximo. Un mensaje más largo sale en paquetes, dieciséis como
máximo, reensamblados por remitente y por número; un mensaje que sigue
incompleto tras 30 s se descarta. Un carácter acentuado nunca se corta: el
corte retrocede un byte si hace falta, y `<n>` cuenta los paquetes realmente
producidos. El cuerpo nunca contiene `|`, porque el cliente rechaza ese
carácter, y `Say` falla si se le da uno. Se ignora la marca que el servidor
inserta delante de la línea (`[HCIV]`).

Se entra en el canal en cuanto un addon se registra mediante `NewAddon`, porque
EbonAPI envía entonces el perfil de ecos por él; EbonAPI solo no entra. Se
retira de las ventanas de chat, así que no aparece ni mensaje ni aviso. La
entrada se comprueba cada segundo hasta que tiene éxito, y se vuelve a pedir
cada diez.

**La cola.** Todo lo que sale del cliente pasa por `Net/Queue`: primero los
mensajes al servidor, luego las líneas del canal y los susurros, un envío cada
0,15 s. El anti-flood cuenta el cliente entero, no cada addon: tres colas
independientes superaban el límite, una sola se queda por debajo. La cola hacia
otros jugadores está limitada a 500 envíos; un mensaje que no cabe entero se
rechaza entero, nunca se corta (`Say` y `WhisperAll` devuelven `false`).

**Jugadores que se han ido.** Cuando el cliente responde «no hay ningún jugador
llamado X» a un susurro, los susurros hacia X se retiran de la cola, se
rechazan durante 60 s, y `PEER_OFFLINE` avisa al addon. El mensaje del sistema
solo se escucha durante el minuto que sigue a un susurro: en reposo, no se
ejecuta nada.

### Susurros

```lua
api:Whisper("ACBR", "Bob", "G:abc")          -- un susurro de addon, por la cola
api:WhisperAll("ACBR", "Bob", parts, n)      -- varios, todos o ninguno
api:OnWhisper("ACBR", function(sender, text, distribution, prefix) end)

api:WhisperStream("ACBR", "Bob", "C", hash, code)   -- un cuerpo largo, en trozos
api:OnWhisperStream("ACBR", "C", function(sender, body, id, op) end, onPart)
```

Lo que un jugador pide a otro (un build público de EbonBuilds, una ruta de
AutoCallboard) sale como susurro, por la misma cola que todo lo demás. El
cliente limita un mensaje de addon a 255 bytes **prefijo y tabulación
incluidos**: `Whisper` falla por encima de `255 - #prefijo - 1`.

Un flujo tiene la forma `EAS:<op>:<id>:<k>/<n>:<trozo>`. Sale en cuatrocientos
trozos como máximo, todos o ninguno; `WhisperStream` devuelve `false` si no
cabe en la cola o si el destinatario acaba de ser señalado como ausente. A la
llegada, los trozos se reensamblan por remitente, prefijo, op e id; `onPart` se
llama con cada trozo salvo el último, para una barra de progreso; un flujo que
sigue incompleto tras 30 s se descarta. Como en el canal, un carácter acentuado
nunca se corta y `<n>` es el número real de trozos.

### Perfil de ecos

EbonAPI envía él mismo, bajo la letra `E`, lo que la matriz de EbonBuilds lee
en los demás jugadores: la clase y los builds de ecos que el servidor guarda
para el personaje (opcode 540), más las listas de baneo que EbonBuilds le
confía mediante `api:SetProfileBans(lists)`. Un solo EbonAPI por cliente, así
que ya no hay nada que arbitrar entre addons, y el formato se escribe una sola
vez.

| Op | Cuerpo | Función |
|---|---|---|
| `P` | `<clase>:<ranuras>` (`8:1.2.5`) | las ranuras ocupadas |
| `D` | `<clase>:<ranura>:<hash>:<ecos>` | un build |
| `X` | `<clase>:<hash>:<lista>;<lista>...` | las listas de baneo |

Un eco cabe en tres caracteres del alfabeto `0-9 A-Z a-z - _`: dos para la
diferencia entre su id y 200000, uno para sus acumulaciones. Los ecos se
ordenan, así que el mismo build da siempre el mismo texto y el mismo hash
(`EbonAPI.Profile.Signature`, ocho caracteres). Las clases van de `WARRIOR` 1
a `DRUID` 10, el orden de la matriz (`EbonAPI.Profile.ClassIndex`).

**Cuándo sale.** Lo que ya se ha enviado se guarda en `EbonAPIDB`, por
personaje: el hash de cada ranura, las ranuras anunciadas, el hash de los
baneos. Una línea solo se anota cuando ha salido de la cola, no cuando entra:
un `/reload` que vacía la cola antes de que se haya servido no pierde nada, y
la línea vuelve a salir en la carga siguiente. Fuera de ese caso, un `/reload`
no reenvía nada; solo vuelve a salir un build que cambia, y `P` solo vuelve a
salir si una ranura aparece o desaparece.

Una sesión nueva lo reenvía todo, para los jugadores que aún no conocían a este
personaje, y pide la lista de builds al servidor diez segundos después de
conectarse. Una sesión es nueva cuando la conexión llega más de diez minutos
después del final de la anterior. El final es la desconexión o el `/reload`
(`PLAYER_LOGOUT`); sin una desconexión limpia (cierre inesperado, corte), se
cuenta desde la conexión anterior. Un `/reload` tras dos horas de juego no abre,
por tanto, una sesión.

**Al recibir**, EbonAPI comprueba los límites (clase de 1 a 10, ranura de 1 a
20, 150 ecos por build, 20 listas de 150) y recalcula el hash; un mensaje dañado
se cuenta y se descarta. El resto llega decodificado a los suscriptores de
`PROFILE_SLOTS`, `PROFILE_BUILD` y `PROFILE_BANS`, con ecos y listas en texto
compacto; `EbonAPI.Profile.DecodeBuild` y `DecodeBans` los releen cuando un
addon los necesita. EbonAPI no guarda nada de los perfiles recibidos.

El perfil sale en cuanto hay un addon cualquiera registrado: basta con
EbonStat.

### Versiones

```lua
api:Version("2.6.0", "https://...")   -- la versión instalada y dónde encontrarla
api:AvailableUpdate()                 -- "2.7.0", "2.6.0" si circula una más reciente
```

Por sesión sale una única línea `V` bajo la letra `E`, para todos los addons a
la vez: `A=2.6.0,E=1.1.0,S=1.8.0`. Solo figuran en ella las versiones
publicadas (`x.y.z`); una versión de trabajo (`x.y.z-n`) se queda para uno
mismo. Quien oye una versión más reciente que la suya la guarda en `EbonAPIDB`
para toda la cuenta, avisa al jugador una vez por sesión y emite
`UPDATE_AVAILABLE`; el enlace mostrado es siempre el que dio el addon
instalado, nunca el de otro jugador. Quien oye a un jugador con una versión
anterior le responde tras dos a ocho segundos, salvo que alguien ya lo haya
hecho. Una versión guardada se olvida en cuanto la versión instalada la
alcanza.

### Estado del servidor normalizado

```lua
local State = EbonAPI.State

State.GetRun()          -- 19 campos + valores derivados (remainingRerolls, ...)
State.GetAsh()          -- un único saldo, con su procedencia
State.GetBuilds()       -- cada ranura lleva `echoes`, la lista en bruto del servidor
State.activeBuild()
State.GetLoadout()
State.GetIntensity()
State.GetMultiplier()
State.snapshot("builds")   -- copia estable
```

Los getters devuelven tablas vivas: se leen, no se modifican. Para una copia
independiente, hay que pasar por `State.snapshot()`.

El saldo de cenizas llegaba por dos caminos independientes (opcode 15 en
EbonStat, opcode 3 en SkillTreeAutoLoad) sin conciliación. Ahora es único, y
`ash.source` indica qué mensaje lo estableció.

`SERVER_ASH` solo se publica si cambia el saldo disponible o el comprometido. El
mismo saldo repetido, por uno u otro opcode, actualiza `ash.source` y `ash.at`
sin publicar nada: EbonStat registra las diferencias de saldo y las conserva
para siempre, y un saldo republicado idéntico solo sería ruido. Un suscriptor
tardío recibe siempre el saldo actual gracias a la reproducción.

`State.GetIntensity()` devuelve siempre la misma tabla cuando recurre a
`EbonholdIntensityData`: la ventana de EbonStat la lee cuatro veces por
segundo.

### Almacenamiento

```lua
local db = api:DB({
  account   = { size = 10 },
  character = { position = 1 },
})

db.account.size
db.char.position        -- nil antes de PLAYER_LOGIN, resuelto después
api:Shared().account    -- espacio común a todos los addons
```

Todo vive en `EbonAPIDB`: los datos sobreviven sin importar qué consumidores
estén instalados. Un valor por defecto añadido en una versión posterior nunca
sobrescribe una elección que el jugador ya ha hecho.

Aquí es donde los addons van trasladando lo que guardan: primero los perfiles
recibidos de EbonBuilds, después las rutas y colecciones de AutoCallboard, los
guardados de SkillTreeAutoLoad y los builds de EbonBuilds, un addon tras otro.
Cada addon conserva su formato; lo que se comparte entre addons pasa por un
formato declarado, nunca por la lectura de la tabla de otro.

#### Migraciones

```lua
db:MigrateOnce("from-MyAddonDB", MyAddonDB, function(store, legacy)
  -- leer legacy, escribir en store
  return migratedCount   -- nil = no hecho, se volverá a ejecutar
end)

db:MigrateOncePerCharacter("key", legacy, function(store, legacy, name, key) end)
```

**Regla absoluta, aprendida a las malas con SkillTreeAutoLoad**: la marca «ya
migrado» vive en el mismo archivo que los datos que protege. Cuando la marca
sobrevive a lo que protege, la migración ya no se vuelve a ejecutar y los datos
se pierden para siempre. Aquí ambos están en `EbonAPIDB`. Corolario: una base
de datos de origen nunca se modifica, solo se lee.

Una migración que devuelve `nil` o que falla no pone su marca: se volverá a
intentar en la carga siguiente.

### Localización

```lua
local L = api:Locale({
  enUS = { HELLO = "hello" },
  esES = { HELLO = "hola" },
})

api:Localized(widget, "HELLO")   -- se vuelve a traducir solo al cambiar de idioma
```

La tabla devuelta está viva: se vacía y se vuelve a llenar en su sitio, así que
un `local L = api:Locale(...)` guardado al principio de un archivo sigue siendo
válido.

La **elección** del idioma es compartida y se guarda; las tablas de traducción
se quedan en cada addon. Cada registro recurre de forma independiente a *su
propia* base `enUS`: si el idioma compartido es `deDE` y un addon no lo
incluye, ese addon habla inglés sin imponer el inglés a los demás.

### Diagnóstico

Escribir una entrada de diagnóstico solo guarda cinco valores en bruto. El
formato se aplica solo al leer, así que un mensaje del servidor no asigna nada.

Un addon declara lo que quiere medir: `api:Track("map", frame)` para un marco,
`api:TrackFunction("OnUpdate", fn)` para una función, y luego
`api:Perf("after combat")` o `/eapi perf MyAddon after combat` para un informe,
guardado en `EbonAPIDB` (veinte por addon). La CPU solo se lee con el
perfilador activado (`/console scriptProfile 1`, luego `/reload`).

## 🧠 Anatomía del código — cómo funciona

EbonAPI se carga en el orden de su `.toc`: primero las primitivas, luego los
idiomas, la cola, el servidor, la red y, por último, `Boot.lua`, que lo pone
todo en marcha al conectarse. Todo cuelga de la tabla global `EbonAPI`.

### `Core/` — la base

| Archivo | Función exacta |
| --- | --- |
| `Lib.lua` | Primitivas sin dependencias: conversión de tipos, tablas, cadenas, división UTF-8, un `pcall` que informa. |
| `Api.lua` | Espacio de nombres, control de versión, identificadores de consumidor, bus de callbacks. |
| `Listeners.lua` | Listas de suscriptores que se pueden modificar mientras se ejecutan. |
| `Log.lua` | Registro con prefijo y búfer circular de diagnóstico. |
| `Bus.lua` | Un único marco para todos los eventos del cliente y todos los temporizadores. |
| `Assembler.lua` | Reensamblado de mensajes en trozos, con caducidad. |
| `DB.lua` | `EbonAPIDB`: ámbitos de cuenta y de personaje, valores por defecto, migraciones. |
| `Session.lua` | Indica si la conexión abre una sesión nueva. |
| `Format.lua` | Formateadores comunes (números, dinero, duraciones). |
| `Perf.lua` | Memoria, marcos activos y CPU por addon (`/eapi perf`). |

### `Language/` y `Locales/` — el sistema multilingüe

| Archivo | Función exacta |
| --- | --- |
| `Language/Locale.lua` | El motor de idiomas y la **elección de idioma compartida**. |
| `Locales/enUS.lua`, `frFR.lua`, `deDE.lua`, `esES.lua` | Los mensajes propios de EbonAPI, en cuatro idiomas. |

### `Net/` — entre jugadores

| Archivo | Función exacta |
| --- | --- |
| `Queue.lua` | **La única** cola de envío: servidor, canal, susurros. |
| `Channel.lua` | El canal común `ebonapi`, sus paquetes, los susurros simples. |
| `Whisper.lua` | La recepción de susurros por prefijo y los flujos en trozos. |
| `Profile.lua` | El perfil de ecos del jugador, codificado, enviado y leído en un solo lugar. |
| `Version.lua` | Las versiones de los addons, anunciadas una vez por sesión. |

### `Server/` — el diálogo con el servidor

| Archivo | Función exacta |
| --- | --- |
| `Opcodes.lua` | Mapa de los opcodes AAM0x9 observados. |
| `Bridge.lua` | **El único** puente con el servidor: analizador, reensamblador, envío por la cola. |
| `Ebonhold.lua` | Fachada de ProjectEbonhold, con detección y funcionamiento degradado si algo falta. |
| `State.lua` | Estado del servidor normalizado, publicado una vez para todos. |

### En la raíz

| Archivo | Función exacta |
| --- | --- |
| `Boot.lua` | El arranque: vincula `EbonAPIDB` al cargar; pone en marcha el puente, el estado, el canal, el perfil y las versiones al conectarse; emite `READY`; interpreta los comandos `/eapi`. |
| `EbonAPI.toc` | El manifiesto de WoW: metadatos, variable guardada (`EbonAPIDB`) y orden de carga de los archivos. |

## 🚧 Limitaciones conocidas

- **El envío fragmentado al servidor no está implementado.** Ningún addon en
  uso lo emplea, así que nada demuestra que el servidor sepa reensamblarlo. El
  límite de 240 bytes es, por tanto, real y definitivo: superarlo es un fallo
  de llamada, y `Bridge.send` lanza un error que indica el tamaño y el límite.
  El canal común, en cambio, sí divide (dieciséis paquetes como máximo).
- **El filtro de remitente está activo por defecto.** Solo un susurro del
  jugador a sí mismo se considera procedente del servidor: sin el filtro,
  cualquier jugador del grupo, la banda o la hermandad podría publicar en
  `AAM0x9`. Se ha comprobado en el juego (la lista de builds llega, el perfil
  sale). Si algún día el servidor respondiera con otro nombre, el puente se
  quedaría mudo: `/eapi senders` muestra los nombres recibidos, y
  `EbonAPI.Bridge.setStrictSender(false)` desactiva el filtro.
- **Una versión anunciada en el canal se da por buena.** Nada firma una línea
  `V`: un jugador que anuncia `A=99.0.0` hace que los usuarios de
  AutoCallboard que lo oyen vean «versión 99.0.0 disponible», y el valor queda
  guardado hasta que la versión instalada lo alcanza. El enlace mostrado, en
  cambio, nunca viene del canal.
- **El perfil solo lleva los ecos 200000 a 204095.** Un id fuera de ese
  intervalo se retira del build enviado, sin mensaje.
- **El mapa de opcodes se mantiene a mano.** `Server/Opcodes.lua` copia los
  observados (`EbonAPI.SS`, `EbonAPI.CS`); si ProjectEbonhold los cambia, no se
  actualiza solo. Los que define ProjectEbonhold también se pueden leer en
  tiempo de ejecución mediante `EbonAPI.Ebonhold.OpcodeCS(name)`, y
  `EbonAPI.Ebonhold.SendToServer(name, body)` envía a través del propio
  ProjectEbonhold.
- **Un mensaje del servidor fragmentado e incompleto puede sobrevivir hasta
  22 s** (20 s de caducidad más un periodo de limpieza) antes de liberarse.

## 🚫 Lo que EbonAPI no hará

Configuración, temporizadores de alto nivel, hooks genéricos, serialización:
Ace3 lo hace mejor. El formato en columnas de EbonStat, los datos de viaje de
AutoCallboard, la lectura del árbol de SkillTreeAutoLoad, las notas de la
matriz de EbonBuilds: eso es lógica propia de cada addon y se queda en ellos.
EbonAPI transporta y almacena; no juzga.

## 🌍 Idiomas

Inglés, francés, alemán y español están completos para los mensajes propios de
EbonAPI. El idioma elegido con `/eapi lang`, o desde el menú de idioma de un
addon, se aplica a todos los addons que confían sus traducciones a EbonAPI.

## 📜 Licencia y créditos

Addon de **Siphelis**.
Creado sobre ProjectEbonhold, la interfaz del cliente del servidor Ebonhold.

EbonAPI se publica bajo la [PolyForm Strict License 1.0.0](LICENSE): puedes
usarlo con fines no comerciales, pero **no puedes venderlo, modificarlo ni
redistribuirlo**. Esto incluye publicarlo en un sitio de addons, incluirlo en
un pack o distribuir una versión modificada. Pide permiso antes de cualquier
uso de este tipo.

---
