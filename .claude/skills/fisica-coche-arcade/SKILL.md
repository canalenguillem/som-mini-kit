---
name: fisica-coche-arcade
description: Modelo de conducción arcade cenital para Godot 4 (CharacterBody2D) con aceleración, giro dependiente de la velocidad, agarre lateral y derrape, nitro, superficies y choques. Úsala al crear o modificar car.gd, al ajustar la sensación de conducción o al añadir superficies.
---

# Física de coche arcade (vista cenital)

Buscamos **diversión, no simulación**. El coche es un `CharacterBody2D` con física propia; nada de `RigidBody2D` para los coches.

Los bloques de código de esta skill son **referencia**: adáptalos al proyecto y no los copies a ciegas.

## Modelo

Cada frame, la velocidad se descompone en dos partes:
- **longitudinal** (`fwd`): hacia donde apunta el morro, `transform.x`.
- **lateral** (`lat`): hacia el costado, `transform.y`.

El agarre **reduce la velocidad lateral hacia 0**. Con mucho agarre el coche va "sobre raíles"; con poco, derrapa. Eso es todo el truco.

## Controlador base (`scenes/car/controllers/car_controller.gd`)

```gdscript
class_name CarController
extends Node

var owner_car: Car   ## lo asigna Car en _ready()

func get_input(_delta: float) -> DriveInput:
	return DriveInput.new()
```

## Referencia (`scenes/car/car.gd`)

```gdscript
class_name Car
extends CharacterBody2D

signal crashed(impact: float)

@export var data: CarData
@export_group("Tuning")
@export var turn_speed_ref: float = 220.0     ## velocidad a la que el giro llega al 100 %
@export var drift_grip_factor: float = 0.35   ## agarre durante el derrape (frenar girando a alta velocidad)
@export var wall_speed_keep: float = 0.55     ## fracción de velocidad que conservas al chocar con una pared
@export var car_bump_impulse: float = 140.0

var stats: CarStats
var track: Track                               ## lo asigna RaceManager
var rubber_band: float = 1.0                   ## lo ajusta RaceManager solo en coches IA (0.92…1.08)
var nitro_charges: int = 0
var _nitro_time_left: float = 0.0
var _default_surface: SurfaceData = preload("res://data/surfaces/asphalt.tres")

@onready var controller: CarController = $Controller


func _ready() -> void:
	controller.owner_car = self


func setup(car_data: CarData, levels: Dictionary) -> void:
	data = car_data
	stats = CarStats.build(car_data, levels)
	nitro_charges = stats.nitro_charges


func _physics_process(delta: float) -> void:
	var input: DriveInput = controller.get_input(delta)
	var surface: SurfaceData = track.get_surface_at(global_position) if track else _default_surface

	var fwd: float = velocity.dot(transform.x)
	var lat: float = velocity.dot(transform.y)

	# --- Nitro ---
	if input.nitro and nitro_charges > 0 and _nitro_time_left <= 0.0:
		nitro_charges -= 1
		_nitro_time_left = stats.nitro_duration
	var boosting: bool = _nitro_time_left > 0.0
	_nitro_time_left = maxf(_nitro_time_left - delta, 0.0)

	# --- Longitudinal ---
	var max_speed: float = stats.max_speed * surface.speed_mult * rubber_band \
			* (stats.nitro_boost if boosting else 1.0)
	var accel: float = stats.acceleration * input.throttle * (1.5 if boosting else 1.0)
	if input.brake > 0.0:
		# Si va hacia delante frena; si está casi parado, marcha atrás
		accel -= (stats.braking if fwd > 10.0 else stats.acceleration * 0.5) * input.brake
	fwd += accel * delta
	fwd -= fwd * stats.drag * surface.drag_mult * delta
	fwd = clampf(fwd, -stats.max_reverse, max_speed)

	# --- Giro (no se gira parado; la marcha atrás invierte el volante) ---
	var speed_factor: float = clampf(absf(fwd) / turn_speed_ref, 0.0, 1.0)
	rotation += input.steer * stats.steering * speed_factor * signf(fwd) * delta

	# --- Agarre lateral / derrape ---
	var drifting: bool = input.brake > 0.0 and absf(input.steer) > 0.5 and fwd > turn_speed_ref
	var grip: float = stats.grip * surface.grip_mult * (drift_grip_factor if drifting else 1.0)
	lat = lerpf(lat, 0.0, clampf(grip * delta, 0.0, 1.0))

	# Recompone con la NUEVA orientación (el morro ya ha girado)
	var basis := Transform2D(rotation, Vector2.ZERO)
	velocity = basis.x * fwd + basis.y * lat
	var pre_speed: float = velocity.length()
	move_and_slide()
	_handle_collisions(pre_speed)


func _handle_collisions(pre_speed: float) -> void:
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		var other: Object = col.get_collider()
		if other is Car:
			var push: Vector2 = -col.get_normal() * car_bump_impulse
			(other as Car).velocity += push
			velocity -= push * 0.5
		else:
			velocity *= wall_speed_keep
		crashed.emit(pre_speed)
```

## Valores de partida (escala: 1 coche ≈ 32×16 px)

| Stat | Escarabajo | Unidades |
|---|---|---|
| max_speed | 420 | px/s |
| acceleration | 520 | px/s² |
| braking | 900 | px/s² |
| drag | 0.6 | 1/s |
| max_reverse | 140 | px/s |
| steering | 3.2 | rad/s a velocidad completa |
| grip | 8.0 | 1/s (≥ 10 sobre raíles, ≤ 3 hielo) |
| nitro_boost | 1.35 | multiplicador de la velocidad máxima |
| nitro_duration | 1.5 | s |

## Superficies

- `Track.get_surface_at()` mira primero las `SurfaceZones` (Area2D con `get_meta("surface")`) y después el tile de `Ground`:
  ```gdscript
  var cell: Vector2i = ground.local_to_map(ground.to_local(global_pos))
  var td: TileData = ground.get_cell_tile_data(cell)
  var id: String = td.get_custom_data("surface") if td else "asphalt"
  return SURFACES.get(id, SURFACES["asphalt"])
  ```
- Para añadir una superficie: crea un `.tres` en `data/surfaces/`, regístralo en el diccionario `SURFACES` de `track.gd`, añade la fila a la tabla de `docs/GDD.md` y crea un test que compruebe que se carga.

## Feedback (sin esto la física "se siente" mal aunque esté bien)

- Marcas de derrape cuando `absf(lat) > 80`: un `Line2D` por rueda trasera con un máximo de puntos.
- Partículas del color de la superficie (`surface.particles_color`) proporcionales a la velocidad.
- `EngineAudio.pitch_scale = lerpf(0.8, 1.8, fwd / stats.max_speed)`.
- Sacudida de cámara en `crashed` si `impact > 200`.

## Reglas

- No uses `RigidBody2D` para los coches; sí para los barriles y las bolas de billar.
- Todo el tuning es `@export` o va en `CarData`/`SurfaceData`; nada de números mágicos sueltos.
- La IA usa **exactamente** la misma física. Para hacerla más difícil se toca su controlador y `rubber_band`, nunca la física.
- Al cambiar la física, termina con "Para probar jugando" y los 2-3 `@export` que más afectan.
