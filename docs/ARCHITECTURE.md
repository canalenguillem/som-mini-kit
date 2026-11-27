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
| `GameState` | `autoload/game_state.gd` | Estado persistente: volumen e idioma. Emite `changed` al modificarse. El progreso de misiones irá aquí o en `progress.gd` (M3) |
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
  hub/hub.tscn              # placa base de TORRE-7 (vacía en M0; zonas en M3)
  mission/mission_shell.tscn              # M1
  missions/m1_workshop/ … m7_hypervisor/  # una carpeta por misión
```

## Lógica pura (`scripts/`, con tests)

| Archivo | Hito | Qué hace |
|---|---|---|
| `exercise_seed.gd` | M1 | RNG sembrado; misma semilla → mismo ejercicio |
| `grading.gd` | M1 | Nota 0–10 a partir de aciertos, intentos y pistas |
| `attempt_report.gd` | M1 | Registro de intentos e informe JSON firmado con HMAC |
| `scheduler.gd` | M2 | FIFO, RR, SJF, SRT → Gantt y tiempos de espera/retorno |
| `number_systems.gd` | M6 | Binario, hexadecimal, suma, ASCII, TB/TiB, descargas |
| `memory.gd` | M7 | Ajustes de particiones, fragmentación, paginación |
| `permissions.gd`, `raid.gd`, `paths.gd` | M8 | rwx/octal, RAID, rutas |
| `vm_network.gd` | M9 | Conectividad según el modo de red |
| `online_client.gd` | kit | Protocolo del servidor |

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

## Verificación

`./tools/check.sh` importa, carga e instancia todo `.gd/.tscn/.tres` (`tools/load_all.gd`) y ejecuta GUT. El aviso «Unexpected NUL character» viene de la prueba de guardado corrupto y es esperado; también el de `resources still in use at exit`.
