class_name CarFx
extends Node2D
## Efectos visuales del coche: ruedas que giran, marcas de derrape y partículas (polvo, humo, nitro).
## Solo presenta: Car le pasa su estado cada frame de física.

@export_group("Ruedas")
@export var max_wheel_angle: float = 0.45  ## rad de giro de las ruedas delanteras a volante completo
@export var wheel_stripe_period: float = 8.0  ## px de avance por vuelta visual de la banda de la rueda
@export_group("Derrape")
@export var skid_lateral_speed: float = 80.0  ## velocidad lateral a partir de la cual se marca
@export var skid_max_points: int = 60  ## puntos por trazo
@export var skid_max_lines: int = 24  ## trazos que se conservan por coche
@export_group("Partículas")
@export var dust_min_speed: float = 60.0  ## px/s a partir de los cuales levanta polvo
@export var smoke_surface_id: String = "asphalt"  ## en esta superficie solo hay humo al derrapar

var skidding: bool = false
var dust_active: bool = false

var _spin: float = 0.0
var _lines: Array[Line2D] = []
var _current: Array[Line2D] = [null, null]  ## trazo en curso de cada rueda trasera

@onready var _wheel_fl: Node2D = $WheelFL
@onready var _wheel_fr: Node2D = $WheelFR
@onready var _rears: Array[Node2D] = [$WheelRL, $WheelRR]
@onready var _stripes: Array[Node2D] = [$WheelFL/Stripe, $WheelFR/Stripe, $WheelRL/Stripe, $WheelRR/Stripe]
@onready var _dust: CPUParticles2D = $Dust
@onready var _nitro: CPUParticles2D = $Nitro


## fwd/lat: velocidad longitudinal y lateral (px/s); steer: -1..1.
func update_state(delta: float, fwd: float, lat: float, steer: float, surface: SurfaceData, boosting: bool) -> void:
	_wheel_fl.rotation = steer * max_wheel_angle
	_wheel_fr.rotation = steer * max_wheel_angle
	_spin = fposmod(_spin + fwd * delta, wheel_stripe_period)
	var stripe_x: float = _spin / wheel_stripe_period * 6.0 - 3.0
	for stripe: Node2D in _stripes:
		stripe.position.x = stripe_x

	skidding = absf(lat) > skid_lateral_speed
	_update_skid_marks()

	var speed: float = Vector2(fwd, lat).length()
	var on_asphalt: bool = surface.id == smoke_surface_id
	dust_active = (speed > dust_min_speed and not on_asphalt) or (skidding and on_asphalt)
	_dust.emitting = dust_active
	_dust.color = surface.particles_color
	_nitro.emitting = boosting


## Corta los trazos en curso (al reaparecer, para no dibujar una línea que cruce el mapa).
func reset() -> void:
	_current = [null, null]


func skid_line_count() -> int:
	return _lines.size()


func _update_skid_marks() -> void:
	for i: int in _rears.size():
		if not skidding:
			_current[i] = null
			continue
		var line: Line2D = _current[i]
		if line == null or line.get_point_count() >= skid_max_points:
			line = _new_line()
			_current[i] = line
		line.add_point(_rears[i].global_position)


func _new_line() -> Line2D:
	var line := Line2D.new()
	line.top_level = true  # los puntos están en coordenadas del mundo
	line.width = 3.0
	line.default_color = Color(0.05, 0.05, 0.05, 0.45)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)
	_lines.append(line)
	while _lines.size() > skid_max_lines:
		var old: Line2D = _lines.pop_front()
		if _current.has(old):
			_current[_current.find(old)] = null
		old.queue_free()
	return line
