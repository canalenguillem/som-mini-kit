# Arquitectura — Mini SO

## Autoloads

| Nombre | Archivo | Responsabilidad |
|---|---|---|
| `Events` | `autoload/events.gd` | Bus de señales globales: `race_started`, `lap_completed(car, lap)`, `race_finished(results)`, `money_changed(amount)` |
| `GameState` | `autoload/game_state.gd` | Dinero, coches comprados, niveles de mejora por coche, pistas desbloqueadas y coche seleccionado. Sin lógica de UI |
| `SaveSystem` | `autoload/save_system.gd` | Serializa `GameState` a `user://save.json` con un campo `version` para poder migrar. Guarda al oír `GameState.changed`, escribe a un temporal y renombra, y un archivo corrupto deja la partida por defecto. En las pruebas GUT usa `user://test_save.json` para no tocar la partida real |

Lógica pura de apoyo: `Economy` (coste de mejoras, premios) y `Catalog` (carga de `data/`) en `scripts/`. El garaje (`scenes/ui/garage.gd`) solo presenta y llama a `GameState`. `GameState` aplica el premio al oír `Events.race_finished`.

El autoload `Music` (`autoload/music.gd`) reproduce la música con fundido cruzado y no se reinicia al cambiar de escena; por eso es un autoload. Los efectos van en los buses `SFX` y la música en `Music` (`default_bus_layout.tres`).

Nada más va en autoload. `RaceManager` es un nodo de la escena de carrera, no un singleton.

## Recursos de datos (`class_name … extends Resource`)

```
CarData        id, display_name, price, sprite: Texture2D,
               base_max_speed, base_acceleration, base_grip, base_steering, base_nitro_charges,
               base_offroad (0..1: fracción de la penalización de superficie que se anula),
               description, color,
               braking, drag, max_reverse, nitro_boost, nitro_duration
UpgradeDef     id ("engine" | "turbo" | "tires" | "nitro"), display_name,
               base_cost, cost_growth (1.6), per_level (0.06…), max_level (5)
TrackData      id, display_name, theme, scene: PackedScene, laps, reward_mult,
               unlock_cost, thumbnail
SurfaceData    id, grip_mult, speed_mult, drag_mult, particles_color, sound
RivalData      id, display_name, color, lane_offset, skill, mistakes, nitro_eagerness
```

`CarStats` (en `scripts/car_stats.gd`, extiende `RefCounted`) es el **resultado calculado** de combinar `CarData` con los niveles de mejora: `CarStats.build(car_data, levels: Dictionary) -> CarStats`. Es función pura y está cubierta por tests.

## El coche

```
Car (CharacterBody2D)            scenes/car/car.gd
├── Sprite2D
├── CollisionShape2D (Rectangle)
├── Controller (Node)            PlayerController | AIController (extienden CarController)
├── SkidMarks / GPUParticles2D
└── EngineAudio (AudioStreamPlayer2D)
```

- El coche mira hacia **+X** en coordenadas locales (`transform.x` es "adelante").
- Cada frame de física: `var input: DriveInput = $Controller.get_input(delta)`.
- `DriveInput` (`RefCounted`) tiene `throttle: float` (0..1), `brake: float` (0..1), `steer: float` (-1..1), `nitro: bool` y `reset: bool`.
- El coche no sabe si lo conduce una persona o la IA. Para cambiar de piloto basta con cambiar el nodo `Controller`.
- La superficie bajo el coche la consulta `Car` a la pista (`Track.get_surface_at(global_position) -> SurfaceData`).
- Física detallada: skill `fisica-coche-arcade`.

## La pista

```
Track (Node2D)                   scenes/tracks/track.gd (script común a todas)
├── Ground (TileMapLayer)        TileSet con custom data "surface": String
├── Walls (TileMapLayer)         con física (capa walls) — o StaticBody2D + CollisionPolygon2D
├── Decor (TileMapLayer / Node2D)
├── Obstacles (Node2D)           barriles, tren, troncos… (escenas propias)
├── SurfaceZones (Node2D)        Area2D opcionales con meta "surface" (charcos, manchas)
├── RacingLine (Path2D)          bucle cerrado en el sentido de la carrera; empieza en la línea de meta
├── Checkpoints (Node2D)         GENERADO por script a partir de RacingLine
└── StartGrid (Node2D)           Marker2D × 4 detrás de la línea de meta
```

`track.gd` expone:

- `get_surface_at(global_pos: Vector2) -> SurfaceData`: primero mira las `SurfaceZones` y si no, el tile de `Ground`.
- `get_progress(global_pos: Vector2) -> float`: offset sobre `RacingLine` en 0..1.
- `get_respawn_transform(checkpoint_index: int) -> Transform2D`
- `start_transforms() -> Array[Transform2D]`

### Cómo se generan las pistas

Las pistas de tema (`west_01`, `west_02`, `jungle_01`, `jungle_02`) no se editan a mano: `tools/gen_<id>.gd` describe la línea central y los obstáculos, y `tools/track_builder.gd` genera `scenes/tracks/<id>.tscn` y `data/tracks/<id>.tres`. Para retocar una pista: edita su `gen_<id>.gd`, ejecuta `godot --headless --path . -s res://tools/gen_<id>.gd` y después `./tools/check.sh`. Los TileSets (`assets/tilesets/*.tres`) salen de `tools/gen_tilesets.gd` (colores planos; se sustituirán por arte en M7).

## La carrera

```
Race (Node)                      scenes/race/race.gd = RaceManager
├── Track (instancia de TrackData.scene)
├── Cars (Node2D)                coches instanciados en StartGrid
├── Camera2D                     sigue al jugador
└── HUD (CanvasLayer)            posición, vuelta, tiempo, nitro, cuenta atrás
```

- `LapTracker` (`scripts/lap_tracker.gd`, `RefCounted`, uno por coche) recibe `checkpoint_passed(index)`. Valida el orden y cuenta las vueltas. **Lógica pura con tests.**
- La posición en carrera se ordena por `vueltas × N_checkpoints + último_checkpoint + progreso_hasta_el_siguiente`.
- Estados de `RaceManager`: `COUNTDOWN → RACING → FINISHED`. Al terminar emite `Events.race_finished(results)` y `GameState` aplica el premio.

## Capas de física

| Capa | Nombre | Quién está | Colisiona con (mask) |
|---|---|---|---|
| 1 | walls | paredes y obstáculos estáticos | — |
| 2 | cars | coches | walls, cars, obstacles |
| 3 | checkpoints | Area2D de checkpoints | (monitoriza cars) |
| 4 | obstacles | obstáculos dinámicos (RigidBody2D) | walls, cars, obstacles |
| 5 | surfaces | SurfaceZones (Area2D) | (monitoriza cars) |

## Flujo de escenas

`main_menu → track_select | garage | campeonato → race → results → (garage | track_select | siguiente carrera | main_menu)`

- Pausa: `PauseMenu` (hijo de `Race`, `process_mode = ALWAYS`) con la acción `pause`; desde ahí se abren las opciones (volumen) o se abandona la carrera.
- Campeonato: `Championship` (`scripts/championship.gd`, lógica pura) lleva puntos 10/6/3/1 y clasificación; `ChampionshipData` (`data/championships/*.tres`) lista sus pistas. `GameState.current_championship` no se guarda en disco: abandonar o cerrar el juego lo pierde. Los premios por carrera se cobran como siempre y al final se suma el premio del campeonato (`Economy.CHAMPIONSHIP_PRIZES`).
- El volumen (`GameState.master_volume`) se guarda en `save.json` y se aplica al bus Master.

Para cambiar de escena se usa `get_tree().change_scene_to_packed()`. La pista elegida se pasa por `GameState.current_track: TrackData`.

## Guardado (`user://save.json`)

```json
{
  "version": 1,
  "money": 1200,
  "owned_cars": ["beetle", "buggy"],
  "selected_car": "buggy",
  "upgrades": { "beetle": { "engine": 2, "turbo": 1, "tires": 0, "nitro": 0 } },
  "unlocked_tracks": ["west_01", "west_02", "jungle_01"],
  "best_times": { "west_01": 83.42 }
}
```

## Tests mínimos obligatorios

- `test_car_stats.gd`: las mejoras aplican bien los porcentajes y respetan el nivel máximo.
- `test_economy.gd`: coste de mejora por nivel; no se puede comprar sin dinero.
- `test_lap_tracker.gd`: vueltas en orden, checkpoints saltados no cuentan, marcha atrás no suma.
- `test_race_positions.gd`: la ordenación por progreso es correcta.
- `test_save_system.gd`: ida y vuelta de guardado; un archivo corrupto no rompe el juego.
