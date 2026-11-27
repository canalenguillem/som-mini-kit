extends GutTest
## Integración de RaceManager con la pista de pruebas (usa el motor de física real).

const RACE_PATH: String = "res://scenes/race/race.tscn"

var _race: RaceManager


func before_each() -> void:
	_race = (load(RACE_PATH) as PackedScene).instantiate() as RaceManager
	_race.countdown_seconds = 0.05


func _start() -> void:
	add_child_autofree(_race)
	await wait_physics_frames(6)


func test_cuenta_atras_bloquea_y_luego_arranca() -> void:
	_race.countdown_seconds = 0.5
	add_child_autofree(_race)
	await wait_physics_frames(2)
	assert_eq(_race.state, RaceManager.State.COUNTDOWN)
	assert_true(_race.player.car.locked)
	await wait_physics_frames(40)
	assert_eq(_race.state, RaceManager.State.RACING)
	assert_false(_race.player.car.locked)


func test_el_jugador_sale_detras_de_la_meta() -> void:
	await _start()
	var p: float = _race.track.get_progress(_race.player.car.global_position)
	assert_true(p > 0.9 or p < 0.02)
	assert_eq(_race.player.tracker.laps, 0)


func test_tres_vueltas_terminan_la_carrera() -> void:
	await _start()
	_race.stuck_seconds = 100.0
	watch_signals(Events)
	var n: int = _race.track.checkpoint_count
	for lap: int in 3:
		for i: int in range(1, n + 1):
			var idx: int = i % n
			_race.player.car.teleport(_race.track.get_respawn_transform(idx))
			await wait_physics_frames(2)
	assert_eq(_race.player.tracker.laps, 3)
	assert_eq(_race.state, RaceManager.State.FINISHED)
	assert_gt(_race.player.finish_time, 0.0)
	assert_signal_emit_count(Events, "lap_completed", 3)
	assert_signal_emit_count(Events, "race_finished", 1)


func test_fuera_del_mapa_reaparece() -> void:
	await _start()
	_race.stuck_seconds = 100.0
	_race.player.car.teleport(Transform2D(0.0, Vector2(99999, 99999)))
	await wait_physics_frames(3)
	assert_true(_race.track.map_bounds.has_point(_race.player.car.global_position))


func test_atasco_reaparece_en_el_ultimo_checkpoint() -> void:
	_race.stuck_seconds = 0.2
	await _start()
	await wait_physics_frames(30)
	var expected: Vector2 = _race.track.get_respawn_transform(0).origin
	assert_lt(_race.player.car.global_position.distance_to(expected), 1.0)


func test_tecla_r_reaparece() -> void:
	await _start()
	_race.stuck_seconds = 100.0
	var racer: RaceManager.Racer = _race.player
	racer.car.teleport(_race.track.get_respawn_transform(3))
	await wait_physics_frames(2)
	assert_eq(racer.tracker.last_checkpoint, 0, "saltarse checkpoints no cuenta")
	racer.car.global_position += Vector2(0, 5)
	racer.car.reset_requested.emit()
	assert_lt(racer.car.global_position.distance_to(_race.track.get_respawn_transform(0).origin), 1.0)
