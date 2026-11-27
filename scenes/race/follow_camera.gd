class_name FollowCamera
extends Camera2D
## Sigue a un coche con suavizado, adelanto, zoom según la velocidad y sacudida en los choques.

@export var target: Car:
	set(value):
		if target != null and target.crashed.is_connected(_on_target_crashed):
			target.crashed.disconnect(_on_target_crashed)
		target = value
		if target != null:
			target.crashed.connect(_on_target_crashed)
@export var lookahead_time: float = 0.35  ## s de velocidad que se adelanta la cámara
@export var max_lookahead: float = 160.0  ## px
@export_group("Zoom")
@export var zoom_out_speed: float = 480.0  ## px/s a los que se llega al zoom mínimo
@export var min_zoom: float = 0.85  ## zoom a máxima velocidad (1 = sin alejarse)
@export var zoom_smoothing: float = 3.0
@export_group("Sacudida")
@export var shake_min_impact: float = 200.0  ## px/s de impacto por debajo de los cuales no tiembla
@export var shake_max_impact: float = 600.0  ## impacto que da la sacudida máxima
@export var max_shake: float = 14.0  ## px de desplazamiento máximo
@export var shake_decay: float = 2.5  ## trauma que se pierde por segundo

var trauma: float = 0.0  ## 0..1, la sacudida crece con su cuadrado

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	_rng.randomize()
	if target != null:
		global_position = target.global_position


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var ahead: Vector2 = (target.velocity * lookahead_time).limit_length(max_lookahead)
	global_position = target.global_position + ahead

	var speed_t: float = clampf(target.velocity.length() / zoom_out_speed, 0.0, 1.0)
	var wanted: float = lerpf(1.0, min_zoom, speed_t)
	zoom = zoom.lerp(Vector2(wanted, wanted), 1.0 - exp(-zoom_smoothing * delta))

	trauma = maxf(trauma - shake_decay * delta, 0.0)
	var amplitude: float = max_shake * trauma * trauma
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * amplitude


func _on_target_crashed(impact: float) -> void:
	if impact < shake_min_impact:
		return
	add_trauma(inverse_lerp(shake_min_impact, shake_max_impact, impact) * 0.7 + 0.3)
