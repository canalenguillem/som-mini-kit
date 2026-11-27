extends GutTest
## Marco de misión con la misión de prueba: fases, comprobación, pistas, nota e informe.

const DIR: String = "user://test_reports"
const SEED: int = 123456

var shell: MissionShell


func before_each() -> void:
	GameState.reset()
	GameState.student_name = "Anna Vidal"
	GameState.pending_seed = SEED
	shell = (load("res://scenes/mission/mission_shell.tscn") as PackedScene).instantiate() as MissionShell
	shell.mission = load("res://data/missions/sample.tres") as MissionData
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


func _content() -> BinarySwitches:
	return shell.content as BinarySwitches


func _go_to_solo() -> void:
	shell.next_phase()
	_content().set_bits(BinaryLock.bits_of(_content().target))
	shell.check()
	shell.next_phase()


func test_empieza_por_el_ejemplo_con_la_semilla_impuesta() -> void:
	assert_eq(shell.exercise_seed, SEED)
	assert_eq(GameState.pending_seed, 0, "la semilla impuesta se consume")
	assert_eq(shell.phase, MissionContent.Phase.EXAMPLE)
	assert_false(shell._check.visible)
	assert_true(shell._next.visible)
	assert_false(shell._next.disabled)
	assert_true(shell._hint_button.disabled, "en el ejemplo no hay pistas")
	assert_false(shell._result.visible)


func test_cada_fase_tiene_su_ejercicio_y_la_tercera_usa_la_semilla() -> void:
	assert_eq(_content().target, BinaryLock.generate(shell.seed_for(MissionContent.Phase.EXAMPLE)))
	shell.next_phase()
	assert_eq(_content().target, BinaryLock.generate(shell.seed_for(MissionContent.Phase.GUIDED)))
	_content().set_bits(BinaryLock.bits_of(_content().target))
	shell.check()
	shell.next_phase()
	assert_eq(_content().target, BinaryLock.generate(SEED))


func test_guiado_no_deja_seguir_hasta_que_esta_bien_y_no_puntua() -> void:
	shell.next_phase()
	assert_eq(shell.phase, MissionContent.Phase.GUIDED)
	assert_true(shell._next.disabled)
	var empty: Array[bool] = [false, false, false, false, false, false, false, false]
	_content().set_bits(empty)
	var target: int = _content().target
	if target & 0x0F == 0:
		pass  # los 4 bits libres ya están bien en blanco: nada que fallar
	else:
		shell.check()
		assert_true(shell._next.disabled)
		assert_string_contains(shell._feedback.text, "•")
	assert_eq(shell.failed_checks, 0)
	shell.show_hint()
	assert_eq(shell.hints_used, 0, "las pistas del guiado no cuentan")
	_content().set_bits(BinaryLock.bits_of(target))
	shell.check()
	assert_false(shell._next.disabled)


func test_en_solitario_fallos_y_pistas_cuentan_y_sale_la_nota() -> void:
	_go_to_solo()
	assert_eq(shell.phase, MissionContent.Phase.SOLO)
	assert_true(shell._hand_in.visible)
	assert_false(shell._next.visible)
	var target: int = _content().target
	_content().set_bits(BinaryLock.bits_of(target ^ 0xFF))
	shell.check()
	assert_eq(shell.failed_checks, 1)
	assert_false(shell._result.visible)
	shell.show_hint()
	assert_eq(shell.hints_used, 1)
	_content().set_bits(BinaryLock.bits_of(target))
	shell.check()
	assert_true(shell._result.visible)
	assert_almost_eq(shell.grade, 9.0, 0.001)  # 10·(0,7 + 0,2·0,75 + 0,1·0,5)
	assert_eq(shell._result_grade.text, "9,0")


func test_el_informe_se_guarda_firmado() -> void:
	_go_to_solo()
	_content().set_bits(BinaryLock.bits_of(_content().target))
	shell.check()
	assert_almost_eq(shell.grade, 10.0, 0.001)
	assert_ne(shell.report_path, "")
	var loaded: Dictionary = AttemptReport.load_file(shell.report_path)
	assert_true(AttemptReport.verify(loaded))
	assert_eq(str(loaded["student"]), "Anna Vidal")
	assert_eq(str(loaded["mission"]), "sample")
	assert_eq(int(loaded["seed"]), SEED)
	assert_true(bool(loaded["passed"]))
	assert_eq(Array(loaded["criteria"]), ["RA1 b)"])


func test_entregar_en_blanco_da_0_y_apunta_los_fallos() -> void:
	_go_to_solo()
	var empty: Array[bool] = [false, false, false, false, false, false, false, false]
	_content().set_bits(empty)
	shell.hand_in()
	assert_true(shell._result.visible)
	assert_true(shell.grade < 10.0)
	var loaded: Dictionary = AttemptReport.load_file(shell.report_path)
	assert_false((loaded["mistakes"] as Array).is_empty())
	assert_string_contains(str((loaded["mistakes"] as Array)[0]["text"]), "sumen 0")


func test_chuleta() -> void:
	assert_false(shell._cheatsheet.visible)
	shell.toggle_cheatsheet()
	assert_true(shell._cheatsheet.visible)
	assert_string_contains(shell._cheatsheet_body.text, "128")
	assert_false(shell._cheatsheet_body.text.contains("\\n"), "los saltos de línea no salen escapados")
	shell.toggle_cheatsheet()
	assert_false(shell._cheatsheet.visible)


func test_pistas_se_agotan() -> void:
	_go_to_solo()
	shell.show_hint()
	shell.show_hint()
	assert_true(shell._hint_button.disabled)
	shell.show_hint()
	assert_eq(shell.hints_used, 2)
