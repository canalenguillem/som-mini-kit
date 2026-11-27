extends GutTest
## AIController: en recta acelera sin girar; ante una curva de 90° frena y gira bien.
## Más una carrera completa headless con los 3 rivales.

const CAR_PATH: String = "res://scenes/car/car.tscn"
const RACE_PATH: String = "res://scenes/race/race.tscn"
const DT: float = 1.0 / 60.0

var _track: Track
var _car: Car
var _ai: AIController


## Pista mínima con una RacingLine poligonal.
func _make_world(points: Array[Vector2]) -> void:
	var curve := Curve2D.new()
	for p: Vector2 in points:
		curve.add_point(p)
	var line := Path2D.new()
	line.name = "RacingLine"
	line.curve = curve
	_track = Track.new()
	_track.add_child(line)
	add_child_autofree(_track)
	_car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	var old: Node = _car.get_node("Controller")
	_car.remove_child(old)
	old.free()
	_ai = AIController.new()
	_ai.name = "Controller"
	_ai.mistakes = 0.0
	_ai.nitro_eagerness = 0.0
	_car.add_child(_ai)
	_car.data = load("res://data/cars/beetle.tres") as CarData
	_track.add_child(_car)
	_car.track = _track


func _place(pos: Vector2, speed: float) -> void:
	_car.global_position = pos
	_car.rotation = 0.0
	_car.velocity = Vector2(speed, 0.0)


func test_en_recta_acelera_y_no_gira() -> void:
	_make_world([Vector2(0, 0), Vector2(5000, 0)])
	_place(Vector2(100, 0), 150.0)
	var inp: DriveInput = _ai.get_input(DT)
	assert_eq(inp.throttle, 1.0)
	assert_eq(inp.brake, 0.0)
	assert_lt(absf(inp.steer), 0.05)


func test_ante_curva_cerrada_frena() -> void:
	_make_world([Vector2(0, 0), Vector2(300, 0), Vector2(300, 300)])
	_place(Vector2(100, 0), 300.0)
	var inp: DriveInput = _ai.get_input(DT)
	assert_eq(inp.brake, 1.0, "frena antes de la curva")
	assert_eq(inp.throttle, 0.0)


func test_en_la_curva_gira_hacia_el_lado_correcto() -> void:
	_make_world([Vector2(0, 0), Vector2(300, 0), Vector2(300, 300)])
	_place(Vector2(250, 0), 150.0)
	assert_gt(_ai.get_input(DT).steer, 0.3, "la curva va hacia +y: giro a la derecha")
	# y espejada: curva hacia -y
	_track.queue_free()
	await wait_physics_frames(1)
	_make_world([Vector2(0, 0), Vector2(300, 0), Vector2(300, -300)])
	_place(Vector2(250, 0), 150.0)
	assert_lt(_ai.get_input(DT).steer, -0.3)


func test_atasco_activa_marcha_atras() -> void:
	_make_world([Vector2(0, 0), Vector2(5000, 0)])
	_place(Vector2(100, 0), 0.0)
	for i: int in 90:  # 1.5 s parado
		_ai.get_input(DT)
	var inp: DriveInput = _ai.get_input(DT)
	assert_eq(inp.throttle, 0.0)
	assert_eq(inp.brake, 1.0)


func test_personalidades_de_los_rivales() -> void:
	var expected: Dictionary = {
		"rayo": [-0.3, 1.05, 0.05, 0.8],
		"bruto": [0.0, 0.95, 0.15, 0.5],
		"despiste": [0.4, 0.9, 0.35, 0.3],
	}
	for id: String in expected:
		var r: RivalData = load("res://data/rivals/%s.tres" % id) as RivalData
		assert_not_null(r, id)
		var v: Array = expected[id]
		assert_almost_eq(r.lane_offset, float(v[0]), 0.001, id)
		assert_almost_eq(r.skill, float(v[1]), 0.001, id)
		assert_almost_eq(r.mistakes, float(v[2]), 0.001, id)
		assert_almost_eq(r.nitro_eagerness, float(v[3]), 0.001, id)


func test_configure_aplica_la_dificultad() -> void:
	var r: RivalData = load("res://data/rivals/rayo.tres") as RivalData
	var ai := AIController.new()
	ai.configure(r, 0.9)
	assert_almost_eq(ai.skill, 1.05 * 0.9, 0.0001)
	ai.free()


## Los 3 rivales completan al menos una vuelta sin atascarse para siempre.
func test_los_tres_rivales_completan_una_vuelta() -> void:
	Engine.time_scale = 10.0
	var race: RaceManager = (load(RACE_PATH) as PackedScene).instantiate() as RaceManager
	race.countdown_seconds = 0.05
	add_child_autofree(race)
	race.player.car.collision_layer = 0  # el jugador parado no estorba
	race.player.car.locked = true
	var sim_time: float = 0.0
	while sim_time < 60.0 and not _all_rivals_lapped(race):
		await wait_physics_frames(30)
		sim_time += 30.0 * DT * 1.0  # tiempo de simulación aproximado
		race.player.car.locked = true
	Engine.time_scale = 1.0
	for racer: RaceManager.Racer in race.racers:
		if not racer.is_player:
			assert_gte(racer.tracker.laps, 1, "%s completó vuelta (t=%.0f s)" % [racer.display_name, race.race_time])
			assert_eq(racer.respawn_count, 0, "%s no debería necesitar reaparecer" % racer.display_name)


func _all_rivals_lapped(race: RaceManager) -> bool:
	for racer: RaceManager.Racer in race.racers:
		if not racer.is_player and racer.tracker.laps < 1:
			return false
	return true


func after_each() -> void:
	Engine.time_scale = 1.0
