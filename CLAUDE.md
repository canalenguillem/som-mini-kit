# Mini SO

Juego educativo en **Godot 4.7** para 1.º de CFGM SMR, módulo **0222 Sistemas Operativos Monopuesto**. El alumno, convertido en un programa con privilegios de núcleo, repara por dentro un ordenador averiado (TORRE-7) superando **7 misiones, una por tema** del cuaderno del profesor. Cada misión es un puzle cuya mecánica **es** el contenido del tema, se corrige sola y da una nota de 0 a 10 ligada a los criterios del RD 1691/2007.

Encargo original: `docs/PLAN_ORIGINAL.md`. Autor del encargo y validador de todo lo jugable: Guillem (profesor).

## Stack

- **Godot 4.7.x stable**. Prohibidas las APIs de Godot 3 (`KinematicBody2D`, `yield`, `export var`, `onready var`, `TileMap` clásico).
- **GDScript con tipado estático** en todo: variables, parámetros y retornos.
- **2D**, base 1280×720, `stretch/mode = canvas_items`, `stretch/aspect = expand`. Renderizador de compatibilidad (PCs de aula sin Vulkan).
- Casi todo se juega con **ratón o pantalla táctil** (arrastrar, pulsar, escribir).
- Tests con **GUT 9.x** en `addons/gut`.

## Documentación (léela antes de cualquier tarea grande)

- `docs/GDD.md`: qué es el juego (concepto, misiones, evaluación).
- `docs/ARCHITECTURE.md`: cómo está construido (escenas, autoloads, datos, traducciones, lógica pura).
- `docs/ROADMAP.md`: hitos. **Trabaja solo en el hito actual** y marca las casillas al terminarlas.
- `docs/infraestructura/`: el kit común (servidor, cliente online, operaciones, lecciones). Skill `juego-online`.
- `docs/ONLINE.md`, `docs/PRIVACIDAD.md` (si existe): cuentas y datos. El alumnado puede ser menor.

## Fuente del temario

Cuaderno «Sistemas Operativos Monopuesto. Cuaderno de trabajo» (Guillem Mateu Mascaró, 2026), en Google Drive: `libros_kdp/Sistemas_Operativos_Cuaderno/03_PRODUCCIO/LLIBRE_KDP/` (ediciones ca/es y con soluciones). **Lee el tema antes de implementar cada misión** y usa su vocabulario, chuletas y ejemplos; los ejercicios resueltos son los casos de prueba de los evaluadores. Simuladores de referencia (`planisim`, `ossim`) en `Sistemas_Operativos_Cuaderno/06_SIMULADOR/`. Si no encuentras algo, pregunta a Guillem.

## Comandos

```bash
./tools/check.sh                                   # verificación completa (importa, carga todo, tests)
godot --headless --path . --import                 # reimportar (también regenera las .translation)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --path .                                     # jugar (necesita pantalla)
./tools/export_linux.sh | export_windows.sh | export_macos.sh   # exportación (plantillas de la misma versión)
```

## Estructura

```
autoload/          # events, game_state (volumen, idioma), save_system, music, online
scenes/
  hub/             # hub.tscn: placa base con las 7 zonas
  mission/         # mission_shell.tscn: fases, chuleta, pistas, resultado (M1)
  missions/        # m1_workshop/ … m7_hypervisor/, una carpeta por misión
  ui/              # main_menu, options_panel, language_selector, pause_menu, online_login, online_lobby
scripts/           # lógica pura sin nodos (generadores y correctores), con tests; online_client.gd
data/
  missions/        # MissionData .tres (tema, título, criterios RA, pesos)
  cheatsheets/     # chuleta de cada tema
  texts/           # ui.csv: claves de traducción → ca, es, en
tests/             # test_*.gd (GUT)
tools/             # check.sh, load_all.gd, exportación, online_smoke.gd, online_demo.gd
docs/
```

## Convenciones

- Archivos, funciones y variables en `snake_case`; `class_name` y nodos en `PascalCase`. Un script por escena, con su mismo nombre.
- **Señales hacia arriba, llamadas hacia abajo.** Los eventos globales pasan por `Events`.
- **Los datos no van en el código**: Resources `.tres` y `@export`.
- **Ningún texto visible escrito a mano**: siempre claves de `data/texts/ui.csv` con sus tres columnas `ca`, `es`, `en`. En escenas, `text = "CLAVE"` (Godot traduce solo); en código, `tr("CLAVE")`. Los textos que no se traducen (números, nombres propios) llevan `auto_translate_mode = 2`. `tests/test_i18n.gd` comprueba que no falte ninguna clave ni idioma.
- Catalán por defecto. El tono es el del cuaderno: de tú, cercano y directo; al fallar se dice **qué falla y cómo arreglarlo**, nunca solo «incorrecto».
- Input por acciones del InputMap (`pause`, `cheatsheet` F1, `hint` F2, y las `ui_*`), nunca teclas directas.
- **Generador y corrector separados de la interfaz**: cada misión tiene `generate(seed) -> Exercise` y `evaluate(exercise, answer) -> Result` en `scripts/`, probados con GUT.
- Comentarios y mensajes de commit en español; identificadores en inglés.

## Reglas al editar `.tscn` / `.tres` como texto

- **No inventes `uid="uid://…"`**: en los `ext_resource` usa solo `path`. Godot los regenerará.
- No toques `.godot/` ni los `.import`. Las `.translation` se generan al importar (están en `.gitignore`).
- Después de crear o editar cualquier escena o recurso, ejecuta `./tools/check.sh`.

## Flujo de trabajo

1. Lee el hito actual en `docs/ROADMAP.md`.
2. Pasos pequeños; `./tools/check.sh` tras cada uno; commits pequeños.
3. Toda la lógica pura (generadores, correctores, nota, informe) lleva tests GUT.
4. Lo que solo se juzga jugando (si se entiende, comodidad del arrastre, dificultad, duración, utilidad de los mensajes) **no lo des por bueno tú**: al acabar cada hito deja a Guillem una lista corta de qué probar.

## Skills del proyecto

- `godot-verificar`: verificar el proyecto sin pantalla; obligatorio antes de dar algo por terminado.
