extends GutTest
## Misión 4 dentro del marco: fases, cuadrícula, tabla y nota.

const DIR: String = "user://test_reports"
const SEED: int = 123456

var shell: MissionShell


func _open(mission_path: String) -> void:
	GameState.reset()
	GameState.student_name = "Anna Vidal"
	GameState.pending_seed = SEED
	shell = (load("res://scenes/mission/mission_shell.tscn") as PackedScene).instantiate() as MissionShell
	shell.mission = load(mission_path) as MissionData
	shell.reports_dir = DIR
	add_child_autofree(shell)
	await wait_physics_frames(1)


func after_each() -> void:
	get_tree().paused = false
	GameState.reset()
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func _content() -> GanttMission:
	return shell.content as GanttMission


func test_cada_sala_configura_su_algoritmo() -> void:
	var cases: Dictionary = {"m4_fifo": [Scheduler.Algorithm.FIFO, false], "m4_rr": [Scheduler.Algorithm.RR, false],
			"m4_rr_io": [Scheduler.Algorithm.RR, true], "m4_sjf": [Scheduler.Algorithm.SJF, false],
			"m4_srt": [Scheduler.Algorithm.SRT, false]}
	for id: String in cases:
		await _open("res://data/missions/%s.tres" % id)
		assert_eq(_content().algorithm, cases[id][0], id)
		assert_eq(_content().with_io, cases[id][1], id)
		assert_eq(shell.mission.topic, 4)
		shell.queue_free()
		await wait_physics_frames(1)


func test_ejemplo_no_se_puede_tocar() -> void:
	await _open("res://data/missions/m4_srt.tres")
	assert_false(_content()._grid.editable)
	assert_false(_content()._grid.queues.is_empty(), "el ejemplo enseña la cola")


func test_guiado_trae_media_cuadricula_y_una_fila() -> void:
	await _open("res://data/missions/m4_rr.tres")
	shell.next_phase()
	var grid: GanttGrid = _content()._grid
	assert_true(grid.editable)
	var half: int = ceili(_content().solution.cycles() / 2.0)
	assert_true(grid.locked[0])
	assert_true(grid.locked[half - 1])
	assert_false(grid.locked[half])
	var row: Dictionary = _content()._inputs[0]
	assert_false((row["start"] as LineEdit).editable)
	assert_ne((row["start"] as LineEdit).text, "")


func test_en_solitario_la_solucion_saca_un_10() -> void:
	await _open("res://data/missions/m4_srt.tres")
	shell.next_phase()
	shell.next_phase()
	assert_eq(shell.phase, MissionContent.Phase.SOLO)
	var c: GanttMission = _content()
	assert_eq(c.exercise, GanttExercise.generate(SEED, {"algorithm": Scheduler.Algorithm.SRT, "io": false}))
	c.set_answer(GanttExercise.solution_answer(c.exercise))
	shell.check()
	assert_true(shell._result.visible)
	assert_almost_eq(shell.grade, 10.0, 0.001)
	var report: Dictionary = AttemptReport.load_file(shell.report_path)
	assert_eq(str(report["mission"]), "m4_srt")
	assert_eq(Array(report["criteria"]), ["RA1 c)", "RA4 c)"])


func test_fallo_en_la_cuadricula_explica_el_ciclo() -> void:
	await _open("res://data/missions/m4_fifo.tres")
	shell.next_phase()
	shell.next_phase()
	var c: GanttMission = _content()
	var ans: Dictionary = GanttExercise.solution_answer(c.exercise)
	var grid: Array = ans["grid"]
	var other: int = 1 if int(grid[0]) == 0 else 0
	grid[0] = other
	c.set_answer(ans)
	shell.check()
	assert_eq(shell.failed_checks, 1)
	assert_string_contains(shell._feedback.text, "1")


func test_pintar_la_cuadricula_con_el_raton() -> void:
	await _open("res://data/missions/m4_fifo.tres")
	shell.next_phase()
	shell.next_phase()
	var grid: GanttGrid = _content()._grid
	var y: float = grid.header_height + grid.cell_size.y * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(grid.label_width + 5, y)
	grid._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(grid.label_width + grid.cell_size.x * 2.5, y)
	grid._gui_input(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	grid._gui_input(release)
	assert_eq(grid.grid.slice(0, 4), [0, 0, 0, -1] as Array[int], "arrastrar por la fila pinta los ciclos 1 a 3")
	grid._gui_input(press)
	grid._gui_input(release)
	assert_eq(grid.grid[0], -1, "tocar otra vez borra")


func test_las_w_y_la_f_salen_solas() -> void:
	await _open("res://data/missions/m4_rr_io.tres")
	var grid: GanttGrid = _content()._grid
	grid.setup(PackedStringArray(["A"]), PackedInt32Array([1]), [[2, 2, 1]], 6)
	grid.grid = [0, 0, -1, -1, 0, -1] as Array[int]
	assert_eq(grid.marks_for_row(0), PackedStringArray(["X", "X", "W", "W", "F", ""]))
	grid.grid = [0, 0, -1, -1, 0, 0] as Array[int]
	assert_eq(grid.marks_for_row(0)[5], "X", "una X de más después de la F no es otra F")


func test_pistas() -> void:
	await _open("res://data/missions/m4_sjf.tres")
	shell.next_phase()
	shell.next_phase()
	for i: int in 3:
		assert_ne(_content().hint(i), "")
	assert_string_contains(_content().hint(1), "1", "la segunda pista habla del primer ciclo que falla")
