---
name: ia-rival
description: Pilotos IA para carreras cenitales en Godot 4. Siguen la línea de carrera Path2D con anticipación según la velocidad, frenan en las curvas, tienen personalidad, se desatascan solos y llevan un rubber banding suave. Úsala al crear o ajustar AIController o la dificultad.
---

# IA rival

La IA es un `CarController` que devuelve un `DriveInput`, igual que el jugador. **Nunca toca la física del coche.**

## Algoritmo (cada frame de física)

1. **Dónde estoy en la línea**: `offset = curve.get_closest_offset(racing_line.to_local(car.global_position))`.
2. **Punto objetivo** por delante, a una distancia que crece con la velocidad:
   `lookahead = base_lookahead + speed * lookahead_per_speed`.
3. **Carril propio**: desplaza el objetivo en perpendicular a la línea según `lane_offset`. Así los 3 rivales no van en fila india.
4. **Volante**: el ángulo entre el morro y el objetivo, normalizado.
5. **Curvatura por delante**: compara la dirección de la línea en `offset + lookahead` con la de `offset + 2·lookahead`. Si el giro es grande, levanta el pie o frena.
6. **Nitro**: en rectas (curvatura baja), si quedan cargas.

## Referencia (`scenes/car/controllers/ai_controller.gd`)

```gdscript
class_name AIController
extends CarController

@export_group("Personalidad")
@export_range(-1.0, 1.0) var lane_offset: float = 0.0   ## -1 interior … 1 exterior, × lane_width
@export var lane_width: float = 40.0
@export_range(0.5, 1.2) var skill: float = 1.0          ## multiplica la velocidad de paso por curva
@export_range(0.0, 1.0) var mistakes: float = 0.1       ## ruido en el volante
@export_range(0.0, 1.0) var nitro_eagerness: float = 0.5

@export_group("Conducción")
@export var base_lookahead: float = 60.0
@export var lookahead_per_speed: float = 0.35
@export var max_steer_angle: float = 0.6                ## rad que equivalen a volante al 100 %
@export var brake_curvature: float = 0.9                ## rad de curva por delante a partir de la cual frena

var _input := DriveInput.new()
var _stuck_time: float = 0.0
var _reverse_time: float = 0.0
var _reverse_steer: float = 0.0
var _noise_t: float = 0.0


func get_input(delta: float) -> DriveInput:
	var car: Car = owner_car
	var line: Path2D = car.track.racing_line
	var curve: Curve2D = line.curve
	var length: float = curve.get_baked_length()
	var speed: float = car.velocity.dot(car.transform.x)

	# Recuperación de atasco: marcha atrás girando al lado contrario
	if _reverse_time > 0.0:
		_reverse_time -= delta
		_input.throttle = 0.0
		_input.brake = 1.0
		_input.steer = _reverse_steer
		_input.nitro = false
		return _input
	if absf(speed) < 25.0:
		_stuck_time += delta
		if _stuck_time > 1.2:
			_stuck_time = 0.0
			_reverse_time = 0.8
			_reverse_steer = -signf(_input.steer) if _input.steer != 0.0 else 1.0
	else:
		_stuck_time = 0.0

	var offset: float = curve.get_closest_offset(line.to_local(car.global_position))
	var look: float = base_lookahead + maxf(speed, 0.0) * lookahead_per_speed
	var t1: Transform2D = curve.sample_baked_with_rotation(fmod(offset + look, length))
	var t2: Transform2D = curve.sample_baked_with_rotation(fmod(offset + look * 2.0, length))

	var target_local: Vector2 = t1.origin + t1.y * lane_offset * lane_width
	var target: Vector2 = line.to_global(target_local)

	var to_target: float = car.transform.x.angle_to(target - car.global_position)
	_noise_t += delta
	var noise: float = sin(_noise_t * 1.7) * sin(_noise_t * 0.6) * mistakes * 0.3
	_input.steer = clampf(to_target / max_steer_angle + noise, -1.0, 1.0)

	var curvature: float = absf(t1.x.angle_to(t2.x))
	var corner_speed: float = car.stats.max_speed \
			* lerpf(1.0, 0.45, clampf(curvature / 1.5, 0.0, 1.0)) * skill
	_input.throttle = 1.0 if speed < corner_speed else 0.0
	_input.brake = 1.0 if curvature > brake_curvature and speed > corner_speed * 1.15 else 0.0
	_input.nitro = curvature < 0.15 and randf() < nitro_eagerness * delta
	return _input
```

## Rubber banding (suave)

- `RaceManager` lo calcula cada 0,5 s según la distancia de progreso al jugador y lo escribe en `car.rubber_band`, que multiplica la velocidad máxima en `car.gd`:
  - IA muy por delante → baja hasta 0.92.
  - IA muy por detrás → sube hasta 1.08.
- Nunca por encima de ±8 %. Si se nota, el jugador se siente engañado. El coche del jugador siempre tiene `rubber_band = 1.0`.

## Personalidades de los 3 rivales (v1)

| Rival | lane_offset | skill | mistakes | nitro_eagerness | Carácter |
|---|---|---|---|---|---|
| "Rayo" | -0.3 | 1.05 | 0.05 | 0.8 | Rápido y limpio |
| "Bruto" | 0.0 | 0.95 | 0.15 | 0.5 | Choca, empuja |
| "Despiste" | 0.4 | 0.9 | 0.35 | 0.3 | Se equivoca, se sale |

La dificultad global (fácil, normal, difícil) multiplica `skill` por 0.9, 1.0 o 1.08.

## Reaparición

Si un coche lleva más de 4 s atascado (o fuera de la pista), `RaceManager` lo coloca con `track.get_respawn_transform(last_checkpoint)` y le pone velocidad 0.

## Tests

- `test_ai_controller.gd`: en una pista recta de prueba, la IA acelera (`throttle == 1`) y el volante está cerca de 0. Ante una curva de 90° frena y gira hacia el lado correcto.
- Prueba headless de una vuelta: instancia `test_track` con 3 IA y simula unos 60 s con `await get_tree().physics_frame` en bucle. Comprueba que todas completan al menos 1 vuelta. Si alguna no lo hace, la pista o la IA tienen un problema.

## Para probar jugando

¿Adelantan y se dejan adelantar? ¿Hay algún punto donde se atasquen siempre? ¿Se nota el rubber banding? Ajustes principales: `skill`, `lookahead_per_speed` y `brake_curvature`.
