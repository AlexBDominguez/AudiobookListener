# Requisitos — Reproductor de audiolibros

Leyenda: **[MVP]** imprescindible · **[+]** deseable · **[?]** a decidir más adelante.

---

## Fase 0 — Preparación

- [MVP] Proyecto Flutter creado con plataformas `android` y `windows`.
- [MVP] Repositorio git inicializado y conectado a GitHub. `CLAUDE.md` (y `.claude/settings.local.json`) añadidos a `.gitignore` **antes** del primer commit.
- [MVP] Tema base en `lib/app/theme/` con la paleta oscura de `CLAUDE.md` y la tipografía empaquetada. Una pantalla de muestra con los componentes básicos (tarjeta, botón primario, barra de progreso) para validar el estilo antes de construir pantallas reales.
- [MVP] Dependencias base añadidas (ver `CLAUDE.md`) y app vacía que arranca en Android.
- [MVP] Configuración de Android para audio en segundo plano:
  - Permisos `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK` y `POST_NOTIFICATIONS`. **Ningún permiso de almacenamiento** (el acceso es por SAF).
  - Servicio y receiver que pide `audio_service` declarados en el `AndroidManifest.xml`.
  - `MainActivity` adaptada a lo que exige `audio_service`.
- [MVP] Fixtures de prueba en `test/fixtures/`: al menos un .m4b corto (1–2 min) con portada y 3 capítulos, y otro sin capítulos ni portada. Se pueden generar con ffmpeg a partir de audio silencioso y un archivo `ffmetadata` con capítulos; comprueba el resultado con `ffprobe -show_chapters`.

---

## Fase 1 — Parser de m4b (Dart puro, en `lib/m4b/`)

Entrada: un `ByteReader` abstracto (`length`, `read(offset, count)`). Salida: un objeto `M4bInfo`. El parser no sabe si los bytes vienen de SAF, de `dart:io` o de memoria.

- [MVP] Implementaciones de `ByteReader`: `MemoryByteReader` (tests), `FileByteReader` (`dart:io`, para Windows y tests con fixtures) y `BufferedByteReader` (envoltorio con caché de bloques de 64 KB).
- [MVP] Recorrer el archivo saltando de atom en atom **sin cargarlo entero en memoria**. Los audiolibros pueden pesar cientos de MB, y el atom `moov` puede estar al final del archivo.
- [MVP] Soportar atoms de tamaño de 64 bits (`size == 1`) y `co64`.
- [MVP] **Duración total:** desde `mvhd` (duración / timescale).
- [MVP] **Metadatos** desde `moov/udta/meta/ilst`:
  - Título `©nam`, autor `©ART` (o `aART`), narrador (normalmente `©wrt` o `©nrt`, configurable), año `©day`, descripción `desc` / `©cmt`, género `©gen`.
- [MVP] **Portada** desde `covr`: devolver los bytes y el tipo (JPEG/PNG).
- [MVP] **Capítulos, dos formatos:**
  1. Pista de capítulos al estilo QuickTime: un `trak` referenciado mediante `tref/chap` desde la pista de audio. Los títulos son las muestras de esa pista de texto (2 bytes de longitud + texto UTF-8), y sus tiempos salen de `stts`, `stsz` y `stco`/`co64` usando el timescale de esa pista.
  2. Atom Nero `chpl` dentro de `moov/udta`, con los inicios en unidades de 100 ns.
  - Si hay ambos, se prefiere el QuickTime.
  - Si no hay capítulos, se crea uno solo con el título del libro y toda la duración.
  - Cada capítulo tiene `title`, `start` y `end`; el `end` de uno es el `start` del siguiente.
- [MVP] Tests con los fixtures. Antes de escribir el parser, contrastar la estructura de los atoms con una implementación de referencia (por ejemplo mutagen en Python o la documentación de ffmpeg) y con la salida de `ffprobe`.
- [+] Tolerar archivos raros: atoms truncados, textos en otra codificación o capítulos desordenados (se ordenan por `start`).

---

## Fase 2 — Biblioteca

- [MVP] Canal SAF en Kotlin (`SafChannel.kt`) con la API descrita en `CLAUDE.md`, más `SafLibrarySource` en Dart. Tests manuales en un móvil real con Android 11 o superior.
- [MVP] Primera vez: pantalla de bienvenida con un botón "Elegir carpeta de audiolibros", que abre el selector del sistema. La URI del árbol se guarda con permiso persistente y se puede cambiar desde ajustes.
- [MVP] Al arrancar, comprobar con `hasPermission` que el acceso sigue vigente. Si no, mostrar un aviso con un botón para volver a elegir la carpeta.
- [MVP] Escanear la carpeta de forma recursiva buscando `.m4b`, en un isolate o en segundo plano, con indicador de progreso.
- [MVP] Guardar en la base de datos cada libro: URI `content://` (como clave), nombre de archivo, tamaño, fecha de modificación, metadatos, capítulos y la portada en un archivo de caché interno de la app (no como blob dentro de la base de datos).
- [MVP] Volver a escanear al abrir la app y con pull-to-refresh. Solo se re-parsea lo nuevo o lo modificado; los libros cuyo archivo ha desaparecido se marcan como no disponibles, sin perder su progreso.
- [MVP] Pantalla de biblioteca en cuadrícula de portadas, con título, autor y una barra fina de progreso.
- [MVP] Si un libro no tiene portada, buscar `cover.jpg`, `cover.png` o `folder.jpg` en su carpeta; si tampoco hay, mostrar un placeholder generado con las iniciales del título.
- [+] Orden: escuchado recientemente (por defecto), título, autor, añadido recientemente.
- [+] Filtro por estado: sin empezar / en curso / terminado.
- [+] Búsqueda por título o autor.

---

## Fase 3 — Reproductor

**Reproducción**
- [MVP] `AudioHandler` de `audio_service` envolviendo `just_audio`.
- [MVP] Reproducción en segundo plano, con controles en la notificación y en la pantalla de bloqueo. Muestran portada, título del libro y título del capítulo actual.
- [MVP] Botones de auriculares y Bluetooth: play/pausa, siguiente/anterior (capítulo).
- [MVP] Pausar al desconectar los auriculares y gestionar el audio focus (llamadas, otras apps) con `audio_session`.

**Pantalla de reproducción**
- [MVP] Portada grande, título y autor, título del capítulo actual ("Capítulo 4 de 23").
- [MVP] Barra de progreso **del capítulo actual** (arrastrable), con el tiempo transcurrido y el restante del capítulo.
- [MVP] Progreso **global**: porcentaje del libro y tiempo restante total, ajustado a la velocidad de reproducción.
- [MVP] Botones: play/pausa, retroceder 15 s, avanzar 30 s, capítulo anterior y siguiente. "Anterior" lleva al inicio del capítulo actual si han pasado más de 3 s.
- [MVP] Velocidad de 0.5x a 3.0x en pasos de 0.1, con atajos (1.0, 1.25, 1.5, 2.0). El tono se mantiene.
- [MVP] Lista de capítulos: título, duración y marca del actual. Al tocar uno, salta a él.

**Progreso**
- [MVP] Guardar posición y velocidad por libro según la regla de `CLAUDE.md`.
- [MVP] Al abrir un libro, reanudar donde se dejó, retrocediendo 3 s para recuperar el contexto.
- [MVP] Un libro se marca como terminado al llegar a menos de 30 s del final. Se puede reiniciar a mano.
- [MVP] Registrar sesiones de escucha en `listening_sessions`: una sesión empieza al dar a play y termina al pausar, al cerrar o tras 5 min sin reproducir. Las sesiones de menos de 10 s se descartan. Sin pantalla todavía: es solo recogida de datos para la Fase 4.
- [MVP] Guardar en cada libro `startedAt` (primer play), `finishedAt` y `lastPlayedAt`.
- [+] Mini-reproductor fijo en la parte inferior de la biblioteca.

---

## Fase 4 — Comodidad

- [+] **Temporizador de sueño:** 5/15/30/45/60 min o "al final del capítulo", con fundido de volumen los últimos 10 s. Agitar el móvil añade 5 min [?].
- [+] **Marcadores** con nota opcional, listados por libro y con salto directo.
- [+] **Historial de saltos:** deshacer un salto o un toque accidental en la barra ("volver a 1:23:45").
- [+] Ajustes: duración de los saltos (10/15/30/60 s), velocidad por defecto y si la velocidad se recuerda por libro o es global.
- [+] Ficha del libro: descripción, narrador, año, duración, ruta del archivo.
- [+] Opción para desactivar el degradado basado en la portada. [?] Tema claro.

### Seguimiento y estadísticas (no prioritario, pero previsto en el diseño de datos)
- [+] **Ficha de progreso por libro:** fecha de inicio y de fin, días que ha llevado, tiempo real escuchado frente a la duración del libro (efecto de la velocidad) y una línea temporal de sesiones.
- [+] **Pantalla de estadísticas:** tiempo escuchado por día, semana y mes (gráfico de barras), racha de días seguidos escuchando, libros terminados por mes y año, velocidad media y hora del día en que más se escucha.
- [+] **Resumen anual** al estilo "Wrapped": libros terminados, horas, autor más escuchado y libro más largo.
- [+] Valoración (estrellas) y nota personal al terminar un libro.
- [?] Objetivos: horas por semana o libros por año, con su progreso.
- [?] Exportar el historial a CSV o JSON.

---

## Fase 5 — Extras

- [+] Carpeta con varios MP3 tratada como un libro: cada archivo es un capítulo, ordenados por nombre o número de pista.
- [+] Build de Windows: atajos de teclado (espacio, flechas), ventana con la biblioteca y el reproductor lado a lado.
- [?] Sincronizar el progreso entre Android y PC (por ejemplo un JSON en una carpeta sincronizada). Solo si de verdad se usa la versión de PC.
- [?] Widget de pantalla de inicio de Android.
- [?] Varias carpetas raíz (por ejemplo memoria interna + tarjeta SD), cada una con su propio permiso persistente.

---

## Requisitos no funcionales

- **Offline total**: ninguna funcionalidad depende de red.
- **Rendimiento**: la biblioteca abre en menos de 1 s con 100 libros ya cacheados; el escaneo no bloquea la UI (usar un isolate para parsear).
- **Robustez**: un cierre forzado pierde como mucho 10 s de progreso; un archivo corrupto no rompe el escaneo.
- **Accesibilidad básica**: botones de al menos 48 dp, etiquetas semánticas en los controles del reproductor y textos que respetan el tamaño de fuente del sistema.

## Fuera de alcance

Tienda, descargas, DRM (Audible .aax), cuentas, nube, streaming y backend: la app no tiene servidor. También queda fuera cualquier permiso amplio de almacenamiento.
