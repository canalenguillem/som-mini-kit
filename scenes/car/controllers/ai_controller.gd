class_name AIController
extends CarController
## Piloto IA: sigue la línea de carrera con anticipación, frena en curvas y se desatasca.
## Produce un DriveInput como el jugador; nunca toca la física del coche.

@export_group("Personalidad")
@export_range(-1.0, 1.0) var lane_offset: float = 0.0  ## -1 interior … 1 exterior, × lane_width
@export var lane_width: float = 40.0
@export_range(0.5, 1.2) var skill: float = 1.0  ## multiplica la velocidad de paso por curva
@export_range(0.0, 1.0) var mistakes: float = 0.1  ## ruido en el volante
@export_range(0.0, 1.0) var nitro_eagerness: float = 0.5

@export_group("Conducción")
@export var base_lookahead: float = 60.0
@export var lookahead_per_speed: float = 0.35
@export var max_steer_angle: float = 0.6  ## rad que equivalen a volante al 100 %
@export var brake_curvature: float = 0.9  ## rad de curva por delante a partir de la cual frena
@export var corner_min_speed_frac: float = 0.45  ## fracción de la velocidad máxima en la curva más cerrada
@export var straight_curvature: float = 0.15  ## por debajo de esto es recta (permite nitro)

@export_group("Desatasco")
@export var stuck_speed: float = 25.0
@export var stuck_trigger_time: float = 1.2
@export var reverse_duration: float = 0.8

var _input := DriveInput.new()
var _stuck_time: float = 0.0
var _reverse_time: float = 0.0
var _reverse_steer: float = 0.0
var _noise_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_noise_t = _rng.randf() * 10.0  # que los rivales no se equivoquen todos a la vez


## Aplica la personalidad de un RivalData. skill_mult es la dificultad global.
func configure(rival: RivalData, skill_mult: float = 1.0) -> void:
	lane_offset = rival.lane_offset
	skill = rival.skill * skill_mult
	mistakes = rival.mistakes
	nitro_eagerness = rival.nitro_eagerness


func get_input(delta: float) -> DriveInput:
	var car: Car = owner_car
	var line: Path2D = car.track.racing_line
	var curve: Curve2D = line.curve
	var length: float = car.track.curve_length
	var speed: float = car.velocity.dot(car.transform.x)

	# Recuperación de atasco: marcha atrás girando al lado contrario
	if _reverse_time > 0.0:
		_reverse_time -= delta
		_input.throttle = 0.0
		_input.brake = 1.0
		_input.steer = _reverse_steer
		_input.nitro = false
		return _input
	if absf(speed) < stuck_speed:
		_stuck_time += delta
		if _stuck_time > stuck_trigger_time:
			_stuck_time = 0.0
			_reverse_time = reverse_duration
			_reverse_steer = -signf(_input.steer) if _input.steer != 0.0 else 1.0
	else:
		_stuck_time = 0.0

	var offset: float = curve.get_closest_offset(line.to_local(car.global_position))
	var look: float = base_lookahead + maxf(speed, 0.0) * lookahead_per_speed
	var t1: Transform2D = curve.sample_baked_with_rotation(fposmod(offset + look, length))
	var t2: Transform2D = curve.sample_baked_with_rotation(fposmod(offset + look * 2.0, length))

	var target: Vector2 = line.to_global(t1.origin + t1.y * lane_offset * lane_width)
	var to_target: float = car.transform.x.angle_to(target - car.global_position)
	_noise_t += delta
	var noise: float = sin(_noise_t * 1.7) * sin(_noise_t * 0.6) * mistakes * 0.3
	_input.steer = clampf(to_target / max_steer_angle + noise, -1.0, 1.0)

	var curvature: float = absf(t1.x.angle_to(t2.x))
	var corner_speed: float = car.stats.max_speed \
			* lerpf(1.0, corner_min_speed_frac, clampf(curvature / 1.5, 0.0, 1.0)) * skill
	_input.throttle = 1.0 if speed < corner_speed else 0.0
	_input.brake = 1.0 if curvature > brake_curvature and speed > corner_speed * 1.15 else 0.0
	_input.nitro = curvature < straight_curvature and _rng.randf() < nitro_eagerness * delta
	return _input
