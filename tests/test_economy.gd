extends GutTest
## Economía: coste de mejoras por nivel, compras con y sin dinero, premios, desbloqueos.

const GameStateScript: GDScript = preload("res://autoload/game_state.gd")

var _gs: Node


func before_each() -> void:
	_gs = autofree(GameStateScript.new())
	_gs.load_catalog()
	_gs.reset()


func test_coste_crece_un_1_6_por_nivel() -> void:
	var engine: UpgradeDef = _gs.upgrade_defs["engine"]  # base 200
	assert_eq(Economy.upgrade_cost(engine, 0), 200)
	assert_eq(Economy.upgrade_cost(engine, 1), 320)
	assert_eq(Economy.upgrade_cost(engine, 2), 512)
	assert_eq(Economy.upgrade_cost(engine, 3), 819)
	assert_eq(Economy.upgrade_cost(engine, 4), 1311)


func test_datos_de_mejoras_del_gdd() -> void:
	var expected: Dictionary = {"engine": [200, 0.06], "turbo": [150, 0.08], "tires": [150, 0.07], "nitro": [250, 1.0]}
	assert_eq(_gs.upgrade_defs.size(), 4)
	for id: String in expected:
		var d: UpgradeDef = _gs.upgrade_defs[id]
		assert_eq(d.base_cost, int(expected[id][0]), id)
		assert_almost_eq(d.per_level, float(expected[id][1]), 0.0001, id)
		assert_eq(d.max_level, 5, id)
		assert_almost_eq(d.cost_growth, 1.6, 0.0001, id)


func test_datos_de_coches_del_gdd() -> void:
	assert_eq(_gs.cars.size(), 3)
	assert_eq((_gs.cars["beetle"] as CarData).price, 0)
	assert_eq((_gs.cars["buggy"] as CarData).price, 1500)
	assert_eq((_gs.cars["sport"] as CarData).price, 4000)


func test_partida_nueva() -> void:
	assert_eq(_gs.money, 0)
	assert_eq(_gs.owned_cars, ["beetle"] as Array[String])
	assert_eq(_gs.selected_car, "beetle")
	assert_true(_gs.is_track_unlocked("west_01"), "la pista gratuita viene desbloqueada")
	assert_false(_gs.is_track_unlocked("jungle_02"))


func test_no_se_puede_comprar_mejora_sin_dinero() -> void:
	assert_false(_gs.buy_upgrade("beetle", "engine"))
	assert_eq(_gs.upgrade_level("beetle", "engine"), 0)
	assert_eq(_gs.money, 0)


func test_compra_mejora_descuenta_y_sube_nivel() -> void:
	_gs.money = 1000
	assert_true(_gs.buy_upgrade("beetle", "engine"))
	assert_eq(_gs.money, 800)
	assert_eq(_gs.upgrade_level("beetle", "engine"), 1)
	assert_eq(_gs.upgrade_cost("beetle", "engine"), 320)
	assert_true(_gs.buy_upgrade("beetle", "engine"))
	assert_eq(_gs.money, 480)
	assert_eq(_gs.upgrade_level("beetle", "engine"), 2)


func test_nivel_maximo_no_se_supera() -> void:
	_gs.money = 1000000
	for i: int in 5:
		assert_true(_gs.buy_upgrade("beetle", "turbo"))
	var money_before: int = _gs.money
	assert_false(_gs.buy_upgrade("beetle", "turbo"))
	assert_eq(_gs.upgrade_level("beetle", "turbo"), 5)
	assert_eq(_gs.upgrade_cost("beetle", "turbo"), -1)
	assert_eq(_gs.money, money_before)


func test_mejoras_son_por_coche() -> void:
	_gs.money = 100000
	_gs.buy_car("buggy")
	_gs.buy_upgrade("buggy", "tires")
	assert_eq(_gs.upgrade_level("buggy", "tires"), 1)
	assert_eq(_gs.upgrade_level("beetle", "tires"), 0)


func test_no_se_mejora_un_coche_que_no_se_tiene() -> void:
	_gs.money = 100000
	assert_false(_gs.buy_upgrade("sport", "engine"))
	assert_eq(_gs.money, 100000)


func test_comprar_coche() -> void:
	_gs.money = 1499
	assert_false(_gs.buy_car("buggy"), "falta 1 moneda")
	assert_false(_gs.owned_cars.has("buggy"))
	_gs.money = 1500
	assert_true(_gs.buy_car("buggy"))
	assert_eq(_gs.money, 0)
	assert_true(_gs.owned_cars.has("buggy"))
	assert_false(_gs.buy_car("buggy"), "no se compra dos veces")
	assert_false(_gs.buy_car("no_existe"))


func test_seleccionar_solo_coches_propios() -> void:
	assert_false(_gs.select_car("sport"))
	assert_eq(_gs.selected_car, "beetle")
	_gs.money = 5000
	_gs.buy_car("buggy")
	assert_true(_gs.select_car("buggy"))
	assert_eq(_gs.selected_car_data().id, "buggy")


func test_desbloquear_pista() -> void:
	var cost: int = (_gs.tracks["west_02"] as TrackData).unlock_cost
	assert_gt(cost, 0)
	assert_false(_gs.unlock_track("west_02"), "sin dinero")
	_gs.money = cost
	assert_true(_gs.unlock_track("west_02"))
	assert_true(_gs.is_track_unlocked("west_02"))
	assert_eq(_gs.money, 0)
	assert_false(_gs.unlock_track("west_02"), "ya desbloqueada")


func test_premios_del_gdd() -> void:
	assert_eq(Economy.prize(1, 1.0), 500)
	assert_eq(Economy.prize(2, 1.0), 300)
	assert_eq(Economy.prize(3, 1.0), 150)
	assert_eq(Economy.prize(4, 1.0), 50)
	assert_eq(Economy.prize(1, 1.4), 700)
	assert_eq(Economy.prize(5, 1.0), 0)
	assert_eq(Economy.prize(0, 1.0), 0)


func test_resultado_de_carrera_da_premio_y_record() -> void:
	var track: TrackData = _gs.tracks["west_01"]
	assert_eq(_gs.apply_race_result(track, 1, 95.5), 500)
	assert_eq(_gs.money, 500)
	assert_almost_eq(float(_gs.best_times["west_01"]), 95.5, 0.001)
	_gs.apply_race_result(track, 3, 101.0)
	assert_almost_eq(float(_gs.best_times["west_01"]), 95.5, 0.001, "un tiempo peor no pisa el récord")
	assert_eq(_gs.money, 650)
	_gs.apply_race_result(track, 2, 90.0)
	assert_almost_eq(float(_gs.best_times["west_01"]), 90.0, 0.001)


func test_premio_se_multiplica_por_la_pista() -> void:
	var track: TrackData = _gs.tracks["jungle_01"]
	assert_eq(_gs.apply_race_result(track, 2, 80.0), roundi(300 * track.reward_mult))


func test_carrera_terminada_por_evento_aplica_el_resultado_del_jugador() -> void:
	_gs.current_track = _gs.tracks["west_01"]
	var results: Array = [
		{"name": "Rayo", "position": 1, "time": 80.0, "is_player": false},
		{"name": "Jugador", "position": 2, "time": 85.0, "is_player": true},
	]
	_gs._on_race_finished(results)
	assert_eq(_gs.money, 300)
	assert_eq(_gs.last_prize, 300)


func test_las_mejoras_compradas_llegan_a_los_stats() -> void:
	_gs.money = 100000
	_gs.buy_upgrade("beetle", "engine")
	_gs.buy_upgrade("beetle", "engine")
	_gs.buy_upgrade("beetle", "nitro")
	var car: CarData = _gs.cars["beetle"]
	var s: CarStats = CarStats.build(car, _gs.car_levels("beetle"), _gs.upgrade_defs)
	assert_almost_eq(s.max_speed, car.base_max_speed * 1.12, 0.01)
	assert_eq(s.nitro_charges, 2)


func test_todo_terreno_reduce_la_penalizacion() -> void:
	var buggy: CarData = _gs.cars["buggy"]
	var beetle: CarData = _gs.cars["beetle"]
	assert_gt(CarStats.build(buggy).offroad, 0.0)
	assert_eq(CarStats.build(beetle).offroad, 0.0)
