extends GutTest
## Informe firmado: se detecta cualquier cambio hecho a mano.

const DIR: String = "user://test_reports"


func _report() -> Dictionary:
	return {
		"format": AttemptReport.FORMAT, "student": "Anna Vidal", "mission": "m4", "topic": 4,
		"criteria": ["RA1 c)", "RA4 c)"], "seed": 123456, "grade": 7.5, "passed": true,
		"correct": 6, "total": 8, "failed_checks": 1, "hints_used": 0, "duration_s": 312,
		"finished_at": "2026-11-27T10:15:00",
		"mistakes": [{"key": "BIN_SUM_MISMATCH", "args": {"sum": 3, "target": 5}, "text": "x"}],
	}


func after_each() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func test_firma_y_verifica() -> void:
	var signed: Dictionary = AttemptReport.with_signature(_report())
	assert_true(signed.has("hmac"))
	assert_eq((signed["hmac"] as String).length(), 64)
	assert_true(AttemptReport.verify(signed))


func test_cambiar_la_nota_rompe_la_firma() -> void:
	var signed: Dictionary = AttemptReport.with_signature(_report())
	signed["grade"] = 10.0
	assert_false(AttemptReport.verify(signed))


func test_sin_firma_o_con_otra_clave_no_vale() -> void:
	assert_false(AttemptReport.verify(_report()))
	assert_false(AttemptReport.verify(AttemptReport.with_signature(_report(), "otra")))


func test_el_orden_de_las_claves_no_importa() -> void:
	var signed: Dictionary = AttemptReport.with_signature(_report())
	var reordered: Dictionary = {}
	var keys: Array = signed.keys()
	keys.reverse()
	for k: Variant in keys:
		reordered[k] = signed[k]
	assert_true(AttemptReport.verify(reordered))


func test_guardado_y_leido_sigue_valiendo() -> void:
	var path: String = AttemptReport.save(_report(), DIR)
	assert_ne(path, "")
	assert_true(FileAccess.file_exists(path))
	assert_string_contains(path, "m4_20261127-101500_123456.json")
	var loaded: Dictionary = AttemptReport.load_file(path)
	assert_eq(str(loaded["student"]), "Anna Vidal")
	assert_true(AttemptReport.verify(loaded), "los enteros vuelven como decimales al leer el JSON")


func test_archivo_editado_no_vale() -> void:
	var path: String = AttemptReport.save(_report(), DIR)
	var text: String = FileAccess.get_file_as_string(path).replace("\"grade\": 7.5", "\"grade\": 9.5")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	assert_false(AttemptReport.verify(AttemptReport.load_file(path)))


func test_archivo_inexistente_da_vacio() -> void:
	assert_eq(AttemptReport.load_file(DIR.path_join("no_existe.json")), {})
