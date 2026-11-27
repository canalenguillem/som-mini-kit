# Mini SO (nombre provisional)

Juego de carreras arcade con **vista cenital**, inspirado en *Micro Machines V3* (PS1) y *Mini Motor Racing* (Android): coches pequeños, circuitos temáticos (Oeste, Jungla…), rivales con IA y un garaje donde mejorar el coche con el dinero ganado.

## Stack

- **Godot 4.7.x stable**. Prohibidas las APIs de Godot 3 (`KinematicBody2D`, `yield`, `export var`, `onready var`, `TileMap` clásico → usar `TileMapLayer`).
- **GDScript con tipado estático** en todo: variables, parámetros y retornos (`var speed: float`, `func f(x: int) -> void`).
- **2D**, vista cenital. Resolución base 1280×720, `stretch/mode = canvas_items`, `stretch/aspect = expand`.
- Tests con **GUT 9.x** en `addons/gut`.
- Plataforma: escritorio Linux primero; Android (controles táctiles) en un hito posterior.

## Documentación (léela antes de cualquier tarea grande)

- `docs/GDD.md`: qué es el juego (diseño, reglas, números).
- `docs/ARCHITECTURE.md`: cómo está construido (escenas, autoloads, datos, capas).
- `docs/ROADMAP.md`: hitos. **Trabaja solo en el hito actual** y marca las casillas al terminarlas.

## Comandos

```bash
./tools/check.sh                                   # verificación completa (importa, carga todo, tests)
godot --headless --path . --import                 # reimportar assets
godot --headless --path . -s res://tools/load_all.gd   # cargar/instanciar todos los recursos
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --path . res://scenes/race/race.tscn # ejecutar una escena (necesita pantalla)
./tools/export_linux.sh                            # ejecutable de Linux + build/som-mini-linux.tar.gz (necesita las plantillas de exportación)
./tools/export_windows.sh                          # ejecutable de Windows + build/som-mini-windows.zip
./tools/export_macos.sh                            # .app universal firmado ad hoc + build/som-mini-macos.zip (sin firma de Apple: solo se puede probar en un Mac)
```

## Estructura

```
project.godot
autoload/          # events.gd, game_state.gd, save_system.gd, music.gd, online.gd
scenes/
  car/             # car.tscn, car.gd, controllers/ (player_controller.gd, ai_controller.gd)
  race/            # race.tscn (RaceManager), hud.tscn, results.tscn
  tracks/          # track.gd, _template.tscn, test_track.tscn, west_01.tscn, jungle_01.tscn…
  obstacles/       # barrel.tscn, cactus.tscn, log.tscn, train.tscn
  ui/              # main_menu.tscn, garage.tscn, track_select.tscn, online_login.tscn, online_lobby.tscn
scripts/           # clases sin escena: drive_input.gd, car_stats.gd, lap_tracker.gd…
data/
  cars/            # *.tres (CarData)
  upgrades/        # *.tres (UpgradeDef)
  tracks/          # *.tres (TrackData)
  surfaces/        # *.tres (SurfaceData)
  rivals/          # *.tres (RivalData: personalidad de cada piloto IA)
assets/            # sprites, tilesets, audio, fuentes
tests/             # test_*.gd (GUT)
tools/             # check.sh, load_all.gd, track_builder.gd, gen_tilesets.gd, gen_<pista>.gd
```

## Convenciones

- Archivos, funciones y variables en `snake_case`; `class_name` y nodos en `PascalCase`.
- Un script por escena, con el mismo nombre que la escena.
- **Señales hacia arriba, llamadas hacia abajo.** Los eventos globales pasan por el autoload `Events`.
- **Los datos no van en el código.** Coches, mejoras, pistas y superficies son Resources `.tres`. Los valores de ajuste son `@export`, para poder tocarlos desde el editor.
- El input va siempre por acciones del InputMap (`accelerate`, `brake`, `steer_left`, `steer_right`, `nitro`, `pause`), nunca por teclas directas.
- El coche no lee el input directamente: recibe un `DriveInput` de su controlador (humano o IA). Ver ARCHITECTURE.
- Las capas de física están definidas en ARCHITECTURE; no inventes otras.
- Comentarios y mensajes de commit en español; identificadores en inglés.

## Reglas al editar `.tscn` / `.tres` como texto

- Godot 4.4+ usa UIDs. **No inventes `uid="uid://…"`**: en los `ext_resource` omite el atributo `uid` y usa solo `path`. Godot lo regenerará.
- No toques `.godot/` ni los archivos `.import`.
- Los nodos repetitivos (checkpoints, posiciones de salida) se generan por script, no a mano en el `.tscn`.
- Después de crear o editar cualquier escena o recurso, ejecuta `./tools/check.sh`.

## Flujo de trabajo

1. Lee el hito actual en `docs/ROADMAP.md`.
2. Avanza en pasos pequeños y ejecuta `./tools/check.sh` tras cada uno.
3. Toda la lógica pura (economía, mejoras, vueltas, posiciones) lleva tests GUT.
4. Lo que solo se puede juzgar jugando (sensación de conducción, dificultad) **no lo des por bueno tú**. Deja al humano una lista corta de qué probar y qué `@export` ajustar.
5. Haz commits pequeños con mensajes descriptivos.

## Para empezar otro juego

La infraestructura común (cuentas, correo, administración, descargas, copias, privacidad, cliente online, exportación) está documentada y empaquetada en `~/code/juego-online-kit` (skill `juego-online`): `new-game.sh` crea un proyecto nuevo desde la etiqueta `infra-v1`. Si mejoras algo común aquí, fija una versión nueva con `update-reference.sh`.

## Skills del proyecto

- `godot-verificar`: verificar el proyecto sin pantalla; obligatorio antes de dar algo por terminado.
- `fisica-coche-arcade`: modelo de conducción, derrape, nitro, superficies y choques.
- `crear-pista`: añadir un circuito nuevo, de principio a fin.
- `ia-rival`: pilotos IA que siguen la línea de carrera, con dificultad y rubber banding.
