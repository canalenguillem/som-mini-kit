extends GutTest
## Sala recreativa dentro del marco: partida con decisiones, tabla corta y nota.

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
	room().example_pause = 0.0


func after_each() -> void:
	get_tree().paused = false
	GameState.reset()
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func room() -> ArcadeRoom:
	return shell.content as ArcadeRoom


func _right(c: int) -> int:
	return room().solution.timeline[c - 1]


func _wrong(c: int) -> int:
	for i: int in room().solution.candidates(c):
		if i != _right(c):
			return i
	return _right(c)


func test_las_salas_usan_la_sala_recreativa() -> void:
	for id: String in ["m4_fifo", "m4_rr", "m4_rr_io", "m4_sjf", "m4_srt"]:
		await _open(id)
		assert_true(shell.content is ArcadeRoom, id)
		shell.queue_free()
		await wait_physics_frames(1)


func test_no_se_puede_comprobar_hasta_acabar_la_partida() -> void:
	await _open("m4_rr")
	shell.next_phase()
	assert_true(shell._check.disabled)
	room().play_all(_right)
	assert_true(room().round_over)
	assert_false(shell._check.disabled)
	assert_true(room()._table.visible)


func test_en_el_guiado_un_fallo_no_avanza() -> void:
	await _open("m4_sjf")
	shell.next_phase()
	room().step_interval = 0.0
	while not room().waiting_decision and not room().round_over:
		room()._step()
	assert_true(room().waiting_decision)
	var c: int = room().cycle
	room().pick(_wrong(c))
	assert_true(room().waiting_decision, "hay que elegir bien para seguir")
	assert_eq(room().cycle, c)
	assert_string_contains(shell._feedback.text, "•")
	room().pick(_right(c))
	assert_false(room().waiting_decision and room().cycle == c)


func test_en_solitario_el_fallo_cuenta_y_juega_el_que_tocaba() -> void:
	await _open("m4_srt")
	shell.next_phase()
	shell.next_phase()
	room().step_interval = 0.0
	var first: int = room().solution.decision_cycles()[0]
	room().play_all(func(c: int) -> int: return _wrong(c) if c == first else _right(c))
	assert_true(room().round_over)
	assert_eq(int(room().picks[first]), _wrong(first))
	var ans: Dictionary = ArcadeRound.solution_answer(room().exercise)
	room().set_table(ans)
	shell.check()
	assert_true(shell._result.visible)
	assert_lt(shell.grade, 10.0)
	assert_gt(shell.grade, 5.0)


func test_partida_perfecta_saca_un_10() -> void:
	await _open("m4_rr_io")
	shell.next_phase()
	shell.next_phase()
	room().step_interval = 0.0
	room().play_all(_right)
	room().set_table(ArcadeRound.solution_answer(room().exercise))
	shell.check()
	assert_almost_eq(shell.grade, 10.0, 0.001)
	var report: Dictionary = AttemptReport.load_file(shell.report_path)
	assert_eq(str(report["mission"]), "m4_rr_io")


func test_el_ejemplo_se_juega_solo() -> void:
	await _open("m4_fifo")
	room().play_all(_right)
	assert_true(room().round_over)
	assert_false((room()._inputs[0]["wait"] as LineEdit).editable)
	assert_ne((room()._inputs[0]["wait"] as LineEdit).text, "")


func test_la_cuadricula_se_dibuja_con_la_partida() -> void:
	await _open("m4_fifo")
	shell.next_phase()
	assert_true(room()._grid.revealed < room().solution.cycles())
	room().play_all(_right)
	assert_eq(room()._grid.revealed, -1)
