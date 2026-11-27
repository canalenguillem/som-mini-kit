# Cliente Godot (repo `mini-bolidos-kit`)

Godot 4.7.x, GDScript con tipado estático, GUT 9.x, vista 2D, renderizador de compatibilidad (OpenGL 3.3, funciona en PCs de aula sin Vulkan), resolución 1280×720 con `stretch/mode = canvas_items`.

## Qué es genérico y qué es de carreras

| Parte | Tipo |
|---|---|
| `scripts/online_client.gd` (`OnlineClient`), `autoload/online.gd` | **Genérico**: cuenta por HTTP y salas por WebSocket |
| `autoload/events.gd`, `music.gd`, `save_system.gd`, `game_state.gd` | Genéricos con matices: `GameState` guarda dinero, coches, mejoras y pistas (de carreras); `SaveSystem` es genérico (versión, escritura atómica, tolerante a corrupción) |
| `scenes/ui/online_login`, `online_lobby`, `options_panel`, `main_menu` | **Genéricos**; `online_lobby` arranca `online_race.tscn` (cambiar a la escena de partida del juego) y `main_menu` enlaza el garaje y la selección de pista |
| `scenes/race/pause_menu`, `race_sounds`, `hud`, `results`, `follow_camera` | Reutilizables con cambios menores |
| `tools/check.sh`, `load_all.gd`, `export_linux.sh`, `export_windows.sh`, `export_presets.cfg`, `online_smoke.gd`, `online_demo.gd` | **Genéricos** (ver abajo) |
| `tests/fake_online.gd`, `test_online_client.gd`, `test_online_ui.gd`, `test_menus.gd`, `test_save_system.gd`, `test_audio.gd` | Genéricos |
| `scenes/car/*`, `scenes/tracks/*`, `scenes/obstacles/*`, `scenes/race/race.gd`, `online_race.gd`, `scripts/` de coches (stats, IA, vueltas, economía…), `tools/gen_*`, `track_builder.gd` | **Específicos de carreras** |
| `default_bus_layout.tres` (buses `Music` y `SFX`), `project.godot` (autoloads, entrada, compatibilidad) | Genéricos |

## OnlineClient

Una sola clase con todo el protocolo, **sin UI**, con señales para cada mensaje: `logged_in`, `logged_out`, `connection_changed`, `rooms_updated`, `room_updated`, `left_room`, `room_closed`, `race_started`, `race_go`, `race_states`, `race_finish`, `race_results`, `host_changed`, `server_error`, `kicked`. Métodos: `login`, `register(usuario, correo, contraseña, acepta_privacidad)`, `resend_activation`, `logout`, `quick_join`, `create_room`, `join_room`, `leave_room`, `start_room`, `send_state`, `send_checkpoint`, `connect_socket`.

- El autoload `Online` es una instancia, para que sesión y conexión sobrevivan a los cambios de escena. Las herramientas y pruebas crean más instancias.
- Solo guarda en `user://online.json` el servidor y el último usuario; **nunca la contraseña**. El servidor por defecto está en `DEFAULT_SERVER`; se cambia en el login o con `-- --server=URL`.
- Si el usuario no ha aceptado la política de privacidad, `login` devuelve `privacy_pending` y cierra la sesión (se acepta en la web).
- **Pruebas con dobles:** `http_backend` (Callable) y `socket_factory` (Callable) se inyectan; `tests/fake_online.gd` trae un `Socket` y un `Http` falsos. Así se prueba todo sin red.

Los nombres de los mensajes de carrera (`start`, `go`, `states`, `finish`, `results`, `cp`) son los del módulo de carreras del servidor. Para un juego nuevo, define los tuyos en `Room` (servidor) y en `_dispatch` de `OnlineClient`.

## Partida online: el patrón que funciona

Ver `OnlineRace` (hereda de `RaceManager`):

- Cada cliente **simula solo lo suyo** y envía su estado ~15 veces por segundo.
- Los demás jugadores son **fantasmas** (`Car.make_ghost()`): sin física ni colisiones, se mueven interpolando hacia la última posición recibida y extrapolando con su velocidad entre paquetes. No simules colisiones entre jugadores online: cada cliente calcularía una distinta.
- El **anfitrión** simula a los bots con la IA del juego; si se desconecta, el servidor envía `host` y el siguiente humano hereda los bots (conversión de fantasma a simulado).
- La **salida la manda el servidor** (`go`); el cliente solo cuenta atrás para mostrarla.
- Lo que el servidor valida (checkpoints, tiempos) se envía solo si el cliente lo da por bueno (`tracker.passed(...)`), pero **el tiempo oficial lo calcula el servidor**.
- Obstáculos dinámicos no se sincronizan (cada cliente ve los suyos); los que dependen del tiempo (trenes) se reinician en la salida para que coincidan.
- Todos usan el mismo coche base online para que sea justo (`use_garage_car` lo cambia).

## Verificación sin pantalla (obligatoria antes de dar algo por hecho)

- `./tools/check.sh`: importa, carga e instancia todos los `.gd`/`.tscn`/`.tres` y ejecuta GUT. Hay un aviso inocuo al salir (`resources still in use at exit`).
- `tools/online_smoke.gd`: cliente de consola que corre una partida completa de 1 a 5 jugadores contra un servidor real (crea las cuentas con el administrador y las borra). Requiere `BOLIDOS_ADMIN_EMAIL` y `BOLIDOS_ADMIN_PASSWORD` en el entorno (el usuario los pone; no los pidas por el chat).
- `tools/online_demo.gd`: demo para grabar capturas con `--write-movie` y revisar el aspecto sin jugar. Las capturas se miran con la herramienta de lectura de imágenes.
- Los scripts `-s` no pueden nombrar autoloads al compilar: usar `_initialize()` y `root.get_node("Online")`.

## Exportación

`export_presets.cfg` (Linux x86_64, Windows x86_64 y macOS universal; PCK embebido salvo en macOS; excluye `tools/`, `tests/`, `docs/`, `addons/gut/`). Hacen falta las **plantillas de exportación de la misma versión de Godot** (1,28 GB de descarga; basta extraer `linux_release.x86_64`, `windows_release_x86_64.exe`, `macos.zip` y `version.txt` a `~/.local/share/godot/export_templates/<versión>/`, y borrar el paquete).

- `./tools/export_linux.sh` → `build/mini-bolidos-linux.tar.gz` + `.json` con versión y SHA-256.
- `./tools/export_windows.sh` → `build/mini-bolidos-windows.zip` + `.json`. Sin firma digital: SmartScreen avisará (la web lo explica).
- `./tools/export_macos.sh` → `build/mini-bolidos-macos.zip` + `.json`. App **universal (x86_64 + arm64) con firma ad hoc** (`codesign/codesign=1`): la hace el propio Godot desde Linux, **no hace falta `rcodesign`**; sin esa firma, los Mac con chip Apple no ejecutan el binario. El script comprueba las dos arquitecturas y la firma leyendo las cabeceras Mach-O y conserva los permisos del ejecutable. Exige activar `rendering/textures/vram_compression/import_etc2_astc` en `project.godot`. **Sin firma de desarrollador ni notarización** (99 $/año): Gatekeeper bloquea la app y el usuario debe dar permiso la primera vez (macOS 15: Ajustes → Privacidad y seguridad → Abrir igualmente; antes: clic derecho → Abrir; o `xattr -dr com.apple.quarantine`). Godot nombra la app como el proyecto (`Mini Bólidos.app`, con tilde y espacio): las instrucciones deben usar comillas. **Desde Linux no se puede probar**: lo debe abrir alguien en un Mac.
- Un `.exe` se puede probar bajo Wine con un `WINEPREFIX` temporal.

## Audio y arte

- Godot **no importa FLAC**: convertir a OGG Vorbis (`ffmpeg -c:a vorbis -strict -2`). Los bucles necesitan empalme (crossfade) para que no suenen a salto.
- Música y efectos generados con el estudio de IA `lamb` (Stable Audio 3 y ACE-Step); los prompts van en inglés. Un efecto de motor generado era un zumbido agudo (centroide de 3,8 kHz): **mide el espectro** antes de fiarte.
- Arte CC0 de Kenney (`kenney.nl/assets`): reducir los sprites al doble de su tamaño en pantalla para evitar dientes de sierra (`tools/prepare_art.gd`).
