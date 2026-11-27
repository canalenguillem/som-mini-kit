extends GutTest
## Salón recreativo con arrastres dentro del marco.

const DIR: String = "user://test_reports"
const SEED: int = 123456

var shell: MissionShell


func _open(id: String) -> void:
	GameState.reset()
	GameState.student_name = "Anna Vidal"
	GameState.pending_seed = SEED
	shell = (load("res://scenes/mission/mission_shell.tscn") as PackedScene).instantiate() as MissionShell
	shell.mission = load("res://data/missions/%s.tres" % id) as MissionData
	shell.reports_dir = DIR
	add_child_autofree(shell)
	await wait_physics_frames(1)
	room().step_interval = 0.0
	room().example_interval = 0.0


func after_each() -> void:
	get_tree().paused = false
	GameState.reset()
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func room() -> ArcadeRoom:
	return shell.content as ArcadeRoom


func _to_solo() -> void:
	shell.next_phase()
	shell.next_phase()
	room().step_interval = 0.0


func test_todas_las_salas_usan_el_salon() -> void:
	for id: String in ["m4_states", "m4_fifo", "m4_rr", "m4_rr_io", "m4_sjf", "m4_srt"]:
		await _open(id)
		assert_true(shell.content is ArcadeRoom, id)
		shell.queue_free()
		await wait_physics_frames(1)


func test_partida_perfecta_y_tabla_saca_un_10() -> void:
	await _open("m4_rr_io")
	_to_solo()
	assert_true(shell._check.disabled, "hasta que acaba la partida no se comprueba")
	room().play_all()
	assert_true(room().round_over)
	assert_false(shell._check.disabled)
	room().set_table(ArcadeRound.solution_answer(room().exercise))
	shell.check()
	assert_almost_eq(shell.grade, 10.0, 0.001)


func test_un_arrastre_equivocado_cuenta_y_no_mueve() -> void:
	await _open("m4_fifo")
	_to_solo()
	var d: DispatchRound = room().round_state
	assert_false(room().move(0, DispatchRound.MACHINE), "de la puerta a la máquina no")
	assert_eq(d.zone[0], DispatchRound.DOOR)
	assert_eq(d.errors, 1)
	assert_string_contains(shell._feedback.text, "•")
	assert_true(room().move(0, DispatchRound.QUEUE))
	assert_string_contains(shell._feedback.text, "✓")
	room().play_all()
	room().set_table(ArcadeRound.solution_answer(room().exercise))
	shell.check()
	assert_true(shell._result.visible)
	assert_lt(shell.grade, 10.0)


func test_en_el_guiado_los_fallos_no_cuentan_y_media_partida_viene_hecha() -> void:
	await _open("m4_sjf")
	shell.next_phase()
	room().step_interval = 0.0
	assert_gt(room().round_state.cycle, 1, "la primera mitad viene jugada")
	room().move(0, DispatchRound.SNACK)
	assert_eq(room().round_state.errors, 0)


func test_calentamiento_sin_tabla() -> void:
	await _open("m4_states")
	assert_true(room().warmup)
	_to_solo()
	room().play_all()
	assert_true(room().round_over)
	assert_false(room()._table.visible)
	shell.check()
	assert_almost_eq(shell.grade, 10.0, 0.001)


func test_el_ejemplo_se_juega_solo() -> void:
	await _open("m4_fifo")
	shell.start_phase(MissionContent.Phase.EXAMPLE)  # otra vez, ya sin pausas entre movimientos
	assert_true(room().round_over)
	assert_ne((room()._inputs[0]["wait"] as LineEdit).text, "")


func test_soltar_en_el_salon_elige_la_zona() -> void:
	await _open("m4_fifo")
	var hall: ArcadeHall = room()._hall
	hall.size = Vector2(1200, 260)
	assert_eq(hall.zone_at(Vector2(40, 200)), "door")
	assert_eq(hall.zone_at(Vector2(hall.machine_rect().position.x - 60, 200)), "queue")
	assert_eq(hall.zone_at(Vector2(hall.machine_rect().get_center().x, 200)), "machine")
	assert_eq(hall.zone_at(Vector2(hall.counter_rect().get_center().x, 200)), "snack")
	assert_eq(hall.zone_at(Vector2(1180, 200)), "exit")
