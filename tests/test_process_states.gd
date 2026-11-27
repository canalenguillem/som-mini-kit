extends GutTest
## Calentamiento de la misión 4: diagrama de estados.


func test_seis_situaciones_una_por_flecha() -> void:
	var sits: Array[String] = ProcessStates.generate(123456)
	assert_eq(sits.size(), 6)
	var transitions: Array = []
	for s: String in sits:
		var t: int = ProcessStates.answer_of(s)
		assert_between(t, 0, 5)
		assert_false(transitions.has(t))
		transitions.append(t)
	assert_eq(ProcessStates.generate(123456), sits, "misma semilla, mismas situaciones")


func test_todo_bien() -> void:
	var sits: Array[String] = ProcessStates.generate(111111)
	var answers: Array = []
	for s: String in sits:
		answers.append(ProcessStates.answer_of(s))
	assert_true(ProcessStates.evaluate(sits, answers).is_perfect())


func test_la_trampa_de_bloqueado_a_ejecucion() -> void:
	var sits: Array[String] = ["ST_SIT_DISK_DONE", "ST_SIT_KEY_DONE"]
	var r: ChallengeResult = ProcessStates.evaluate(sits, [ProcessStates.TRAP, ProcessStates.TRAP])
	assert_eq(r.correct, 0)
	assert_eq(r.mistakes.size(), 1, "el aviso de la trampa sale una sola vez")
	assert_eq(r.mistakes[0]["key"], "ST_MISTAKE_TRAP")


func test_explica_la_flecha_correcta_y_lo_que_falta() -> void:
	var r: ChallengeResult = ProcessStates.evaluate(["ST_SIT_QUANTUM", "ST_SIT_LAST"] as Array[String], [3, -1])
	assert_eq(r.mistakes[0], {"key": "ST_MISTAKE_RUNNING_READY", "args": {"n": 1}})
	assert_eq(r.mistakes[1], {"key": "ST_MISTAKE_EMPTY", "args": {"n": 2}})


func test_todas_las_situaciones_tienen_texto() -> void:
	GameState.set_locale("ca")
	for s: String in ProcessStates.SITUATIONS:
		assert_ne(tr(s), s, s)
	for t: String in ProcessStates.TRANSITIONS:
		assert_ne(tr("ST_T_" + t), "ST_T_" + t)
		if t != "BLOCKED_RUNNING":
			assert_ne(tr("ST_MISTAKE_" + t), "ST_MISTAKE_" + t)
	GameState.reset()


func test_en_el_marco() -> void:
	GameState.reset()
	GameState.pending_seed = 123456
	var shell: MissionShell = (load("res://scenes/mission/mission_shell.tscn") as PackedScene).instantiate() as MissionShell
	shell.mission = load("res://data/missions/m4_states.tres") as MissionData
	shell.reports_dir = "user://test_reports"
	add_child_autofree(shell)
	await wait_physics_frames(1)
	var quiz: StatesQuiz = shell.content as StatesQuiz
	assert_true(quiz._selectors[0].disabled, "el ejemplo viene resuelto")
	shell.next_phase()
	assert_true(quiz._selectors[0].disabled)
	assert_false(quiz._selectors[5].disabled)
	shell.next_phase()
	var answers: Array = []
	for s: String in quiz.situations:
		answers.append(ProcessStates.answer_of(s))
	quiz.set_answers(answers)
	shell.check()
	assert_almost_eq(shell.grade, 10.0, 0.001)
	for f: String in DirAccess.get_files_at("user://test_reports"):
		DirAccess.remove_absolute("user://test_reports".path_join(f))
	GameState.reset()
