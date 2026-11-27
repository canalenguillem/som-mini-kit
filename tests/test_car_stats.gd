extends GutTest
## CarStats: las mejoras aplican sus porcentajes y respetan el nivel máximo.

var _car: CarData
var _upgrades: Dictionary


func before_each() -> void:
	_car = load("res://data/cars/beetle.tres") as CarData
	_upgrades = {
		"engine": _def("engine", 0.06),
		"turbo": _def("turbo", 0.08),
		"tires": _def("tires", 0.07),
		"nitro": _def("nitro", 1.0),
	}


func _def(id: String, per_level: float) -> UpgradeDef:
	var d := UpgradeDef.new()
	d.id = id
	d.per_level = per_level
	d.max_level = 5
	return d


func test_sin_mejoras_son_los_base() -> void:
	var s: CarStats = CarStats.build(_car, {}, _upgrades)
	assert_almost_eq(s.max_speed, _car.base_max_speed, 0.001)
	assert_almost_eq(s.acceleration, _car.base_acceleration, 0.001)
	assert_almost_eq(s.grip, _car.base_grip, 0.001)
	assert_eq(s.nitro_charges, 1)


func test_porcentajes_por_nivel() -> void:
	var levels: Dictionary = {"engine": 2, "turbo": 3, "tires": 1, "nitro": 2}
	var s: CarStats = CarStats.build(_car, levels, _upgrades)
	assert_almost_eq(s.max_speed, _car.base_max_speed * 1.12, 0.001)
	assert_almost_eq(s.acceleration, _car.base_acceleration * 1.24, 0.001)
	assert_almost_eq(s.grip, _car.base_grip * 1.07, 0.001)
	assert_eq(s.nitro_charges, 3)


func test_nivel_maximo_se_respeta() -> void:
	var s: CarStats = CarStats.build(_car, {"engine": 99, "nitro": 99}, _upgrades)
	assert_almost_eq(s.max_speed, _car.base_max_speed * 1.30, 0.001)
	assert_eq(s.nitro_charges, 6)


func test_nivel_negativo_se_trata_como_cero() -> void:
	var s: CarStats = CarStats.build(_car, {"engine": -3}, _upgrades)
	assert_almost_eq(s.max_speed, _car.base_max_speed, 0.001)


func test_mejora_sin_definicion_no_hace_nada() -> void:
	var s: CarStats = CarStats.build(_car, {"engine": 5}, {})
	assert_almost_eq(s.max_speed, _car.base_max_speed, 0.001)


func test_los_stats_fijos_pasan_tal_cual() -> void:
	var s: CarStats = CarStats.build(_car, {}, _upgrades)
	assert_almost_eq(s.braking, _car.braking, 0.001)
	assert_almost_eq(s.nitro_boost, _car.nitro_boost, 0.001)
	assert_almost_eq(s.nitro_duration, _car.nitro_duration, 0.001)
