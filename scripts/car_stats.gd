class_name CarStats
extends RefCounted
## Stats finales de un coche: CarData + niveles de mejora. Función pura.

var max_speed: float = 0.0
var acceleration: float = 0.0
var grip: float = 0.0
var steering: float = 0.0
var braking: float = 0.0
var drag: float = 0.0
var max_reverse: float = 0.0
var nitro_boost: float = 1.0
var nitro_duration: float = 0.0
var nitro_charges: int = 0
var offroad: float = 0.0  ## 0..1: cuánto se anula la penalización de tierra, barro, etc.


## levels: id de mejora → nivel. upgrades: id de mejora → UpgradeDef.
## Sin definición para una mejora, esa mejora no tiene efecto.
static func build(car_data: CarData, levels: Dictionary = {}, upgrades: Dictionary = {}) -> CarStats:
	var s := CarStats.new()
	s.max_speed = car_data.base_max_speed * (1.0 + _bonus("engine", levels, upgrades))
	s.acceleration = car_data.base_acceleration * (1.0 + _bonus("turbo", levels, upgrades))
	s.grip = car_data.base_grip * (1.0 + _bonus("tires", levels, upgrades))
	s.nitro_charges = car_data.base_nitro_charges + roundi(_bonus("nitro", levels, upgrades))
	s.steering = car_data.base_steering
	s.offroad = car_data.base_offroad
	s.braking = car_data.braking
	s.drag = car_data.drag
	s.max_reverse = car_data.max_reverse
	s.nitro_boost = car_data.nitro_boost
	s.nitro_duration = car_data.nitro_duration
	return s


## Bonus total de una mejora: per_level × nivel (nivel limitado a 0..max_level).
static func _bonus(id: String, levels: Dictionary, upgrades: Dictionary) -> float:
	var def: UpgradeDef = upgrades.get(id) as UpgradeDef
	if def == null:
		return 0.0
	var level: int = clampi(int(levels.get(id, 0)), 0, def.max_level)
	return def.per_level * level
