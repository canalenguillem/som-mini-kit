# Arquitectura — Mini SO

## Principios

- **Generador y corrector separados de la interfaz.** La lógica de cada misión vive en `scripts/` como clases sin nodos: `generate(seed) -> Exercise` y `evaluate(exercise, answer) -> Result`. Se prueban con GUT contra los ejercicios resueltos del cuaderno. Las escenas solo muestran y recogen respuestas.
- **`mission_shell`** gestiona lo común (las tres fases, chuleta, pistas, pantalla de resultado); cada misión solo aporta sus retos.
- **Señales hacia arriba, llamadas hacia abajo.** Lo global pasa por `Events`.
- **Datos fuera del código**: `MissionData` y chuletas en `.tres`; pesos de la nota ajustables.
- **Textos fuera del código**: siempre claves de traducción.

## Autoloads (`project.godot`)

| Nombre | Archivo | Para qué |
|---|---|---|
| `Events` | `autoload/events.gd` | Bus de señales globales (`locale_changed`) |
| `GameState` | `autoload/game_state.gd` | Estado persistente: volumen, idioma y nombre del alumno; además (sin guardar) la misión y la semilla del próximo intento. Emite `changed` al modificarse. El progreso de misiones irá aquí o en `progress.gd` (M3) |
| `SaveSystem` | `autoload/save_system.gd` | Guarda `GameState` en `user://save.json` al oír `changed` (escritura atómica, versión, tolerante a corrupción). En pruebas usa `user://test_save.json` |
| `Music` | `autoload/music.gd` | Música persistente con fundido cruzado |
| `Online` | `autoload/online.gd` | Instancia de `OnlineClient` (cuentas por HTTP, salas por WebSocket). Del kit; se adapta en M11 |

## Escenas

```
scenes/
  ui/main_menu.tscn         # Jugar (→ hub), En línia, Opcions, Sortir; selector de idioma en la esquina
  ui/options_panel.tscn     # volumen e idioma; se usa en el menú y en la pausa
  ui/language_selector.tscn # OptionButton (LanguageSelector) reutilizable
  ui/pause_menu.tscn        # pausa (acción `pause`)
  ui/online_login.tscn, online_lobby.tscn   # del kit (textos aún sin traducir: M11)
  ui/name_dialog.tscn       # pide el nombre del alumno
  hub/hub.tscn, board_view.gd  # placa base de TORRE-7: 7 zonas (ZoneData) y panel de salas
  mission/mission_shell.tscn, mission_content.gd   # marco común y base de los retos
  missions/sample/          # misión de prueba: cerrojo binario
  missions/m4_scheduler/    # gantt_grid (cuadrícula pintable), gantt_mission, states_quiz
  missions/m1_workshop/ … m7_hypervisor/  # una carpeta por misión
```

## Marco de misión

- `MissionData` (`data/missions/*.tres`): id, tema, título (clave), criterios RA, escena de contenido, `Cheatsheet`, `GradingWeights` y `params` (lo lee el contenido en `configure()`; p. ej. `{"algorithm": "RR", "io": true}`). Una misión del cuaderno puede tener varias salas: varios `MissionData` con la misma escena y distintos `params`.
- `ZoneData` (`data/zones/zone_N.tres`): tema, título, pieza de la placa, posición (0–1) y sus salas (`Array[MissionData]`). El hub tiene `@export var zones`.
- `Progress` (lógica pura): mejor nota e intentos por misión en `GameState.progress` (se guarda), nota y estado de cada zona y desbloqueo en orden. `MissionShell.finish()` llama a `GameState.record_attempt()`.
- El hub pone `GameState.current_mission` y abre `scenes/mission/mission_shell.tscn`. La semilla sale de `GameState.take_seed()` (la impuesta en `pending_seed`, o una al azar).
- `MissionShell` crea la escena de contenido, que hereda de `MissionContent` y implementa `_build()` (con `phase` y `exercise_seed`), `check() -> ChallengeResult`, `hint_count()` y `hint(i)`.
- Semillas por fase: ejemplo y guiado usan `ExerciseSeed.derive(semilla, "example"/"guided")`; la fase en solitario usa la semilla del intento, que es la que va al informe. Así el profesor reproduce exactamente lo que se puntuó.
- `ChallengeResult`: `correct`, `total` y `mistakes` = `[{key, args}]`; el texto se traduce al mostrarlo (`ChallengeResult.message_of`). Cada clave de fallo dice qué falla y cómo arreglarlo.
- Al acabar: `Grading.grade()` → `AttemptReport.save()` → panel de resultado (repetir con otra semilla, abrir la carpeta de informes, volver al mapa).

## Lógica pura (`scripts/`, con tests)

| Archivo | Hito | Qué hace |
|---|---|---|
| `exercise_seed.gd` | M1 | RNG sembrado; misma semilla → mismo ejercicio |
| `challenge_result.gd`, `mission_data.gd`, `cheatsheet.gd`, `grading_weights.gd` | M1 | Tipos del marco de misión |
| `binary_lock.gd` | M1 | Cerrojo binario de la misión de prueba (se reutilizará en la misión 3) |
| `grading.gd` | M1 | Nota 0–10 a partir de aciertos, intentos y pistas |
| `attempt_report.gd` | M1 | Registro de intentos e informe JSON firmado con HMAC |
| `scheduler.gd`, `schedule.gd` | M2 | FIFO, RR (con E/S), SJF, SRT en ciclos desde 1 → cuadrícula, colas, motivo de cada ciclo, tiempos y medias truncadas |
| `gantt_exercise.gd` | M2 | Genera ejercicios de planificación y corrige cuadrícula y tabla (error arrastrado) |
| `process_states.gd` | M2 | Calentamiento: situaciones y transiciones del diagrama de estados |
| `number_systems.gd` | M6 | Binario, hexadecimal, suma, ASCII, TB/TiB, descargas |
| `memory.gd` | M7 | Ajustes de particiones, fragmentación, paginación |
| `permissions.gd`, `raid.gd`, `paths.gd` | M8 | rwx/octal, RAID, rutas |
| `vm_network.gd` | M9 | Conectividad según el modo de red |
| `online_client.gd` | kit | Protocolo del servidor |

## Material del cuaderno

`docs/temario/temaN.md`: extracto de cada tema (vocabulario ca/es, chuleta, reglas, ejercicios resueltos con solución) sacado de los PDF y los `.md` fuente de Google Drive. Es la referencia de los tests de cada misión.

## Datos

```
data/
  missions/*.tres    # MissionData: tema, título (clave), criterios RA, pesos
  cheatsheets/       # chuleta de cada tema
  texts/ui.csv       # claves de traducción: columnas keys, ca, es, en
```

## Traducciones

- Sistema de Godot (`TranslationServer`) con un CSV: `data/texts/ui.csv`. Al importar se generan `ui.ca.translation`, `ui.es.translation` y `ui.en.translation` (ignoradas por git), registradas en `project.godot` (`internationalization/locale/translations`, `fallback = ca`).
- `GameState.locale` (por defecto `ca`; valores en `GameState.LOCALES`) aplica `TranslationServer.set_locale` y emite `Events.locale_changed`. `GameState.set_locale()` además guarda. Un idioma desconocido vuelve a `ca`.
- Labels y botones con `text = "CLAVE"` se retraducen solos al cambiar de idioma. Textos generados en código: `tr("CLAVE")` y, si deben actualizarse en caliente, escuchar `NOTIFICATION_TRANSLATION_CHANGED` o `Events.locale_changed`.
- Texto que no se traduce (cifras, nombres propios): `auto_translate_mode = 2`.
- Cuando crezca, se puede partir `ui.csv` por misión (`m4.csv`…) y añadir cada uno a `project.godot`.
- `tests/test_i18n.gd` comprueba: catalán por defecto, cambio en caliente, que toda clave tenga los tres idiomas y que las escenas traducidas solo usen claves.

## Entrada

Acciones del InputMap: `pause` (Esc), `cheatsheet` (F1), `hint` (F2) y las `ui_*` de Godot. El resto es ratón/táctil sobre controles.

## Online e informes

- Informe local (M1): JSON con código HMAC, exportable sin red.
- Servidor (M11): `../som-mini-server`, `miniso.enguillem.es`, puerto 8470, subred `10.213.148.0/24`. Lo genérico (cuentas, correo, administración, privacidad) viene del kit; lo de carreras se sustituye por el envío de notas.

## Capturas sin jugar

Los scripts lanzados con `-s` no compilan si usan tipos que dependen de autoloads (`MissionShell`, `GameState`…): usar `Object`, `get()` y `call()`.

## Verificación

`./tools/check.sh` importa, carga e instancia todo `.gd/.tscn/.tres` (`tools/load_all.gd`) y ejecuta GUT. El aviso «Unexpected NUL character» viene de la prueba de guardado corrupto y es esperado; también el de `resources still in use at exit`.
