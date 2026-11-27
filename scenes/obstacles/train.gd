class_name Train
extends AnimatableBody2D
## Tren que cruza la pista cada `period` s, con aviso luminoso `warning_time` s antes.
## El eje local x es la dirección de cruce. Se coloca centrado en el cruce y se desplaza ±half_span.

@export var half_span: float = 500.0  ## px desde el cruce hasta donde espera, fuera de la pista
@export var speed: float = 650.0  ## px/s
@export var period: float = 10.0  ## s entre trenes
@export var warning_time: float = 2.0  ## s de aviso antes de que aparezca
@export var phase: float = 0.0  ## s de adelanto del ciclo (para desfasar varios trenes)
@export var crossing_half_length: float = 240.0  ## semilargo de la zona de aviso (cubre la pista)

var _origin: Vector2
var _time: float = 0.0

@onready var _warning: Polygon2D = $Warning
@onready var _rail: Polygon2D = $Rail


func _ready() -> void:
	_origin = global_position
	_time = phase
	for zone: Polygon2D in [_warning, _rail]:
		zone.top_level = true
		zone.global_transform = Transform2D(global_rotation, _origin)
	var half: float = crossing_half_length
	_warning.polygon = PackedVector2Array([Vector2(-half, -34), Vector2(half, -34), Vector2(half, 34), Vector2(-half, 34)])
	_rail.polygon = PackedVector2Array([Vector2(-half, -20), Vector2(half, -20), Vector2(half, 20), Vector2(-half, 20)])
	_warning.visible = false


func _physics_process(delta: float) -> void:
	_time = fposmod(_time + delta, period)
	var cross_time: float = 2.0 * half_span / speed
	var cross_start: float = period - cross_time
	var along: float = -half_span
	if _time >= cross_start:
		along += (_time - cross_start) * speed
	global_position = _origin + Vector2.from_angle(global_rotation) * along
	var warning_on: bool = _time >= cross_start - warning_time and _time < cross_start + cross_time * 0.5
	_warning.visible = warning_on and int(_time * 6.0) % 2 == 0  # parpadea


## Reinicia el ciclo: online se llama en la salida para que todos los clientes vean los trenes a la vez.
func reset_time() -> void:
	_time = phase


## Segundos hasta el próximo cruce (0 si está cruzando). Para tests e IA.
func time_to_cross() -> float:
	var cross_start: float = period - 2.0 * half_span / speed
	return maxf(cross_start - _time, 0.0)
