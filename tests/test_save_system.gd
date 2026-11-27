extends GutTest
## Guardado: ida y vuelta, y un archivo corrupto no rompe el juego.

const GameStateScript: GDScript = preload("res://autoload/game_state.gd")
const SaveSystemScript: GDScript = preload("res://autoload/save_system.gd")
const PATH: String = "user://test_save_unit.json"

var _gs: Node
var _save: Node


func before_each() -> void:
	_gs = autofree(GameStateScript.new())
	_gs.reset()
	_save = autofree(SaveSystemScript.new())
	_remove()


func after_each() -> void:
	_remove()
	GameState.master_volume = 1.0


func _remove() -> void:
	for p: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _write(text: String) -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _fresh() -> Node:
	var other: Node = autofree(GameStateScript.new())
	other.reset()
	return other


func test_ida_y_vuelta() -> void:
	_gs.master_volume = 0.3
	assert_eq(_save.save_to(_gs, PATH), OK)
	var other: Node = _fresh()
	assert_true(_save.load_from(other, PATH))
	assert_almost_eq(other.master_volume, 0.3, 0.001)


func test_el_archivo_lleva_version() -> void:
	_save.save_to(_gs, PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_true(parsed is Dictionary)
	assert_eq(int((parsed as Dictionary)["version"]), SaveSystemScript.CURRENT_VERSION)
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "no deja temporales")


func test_sin_archivo_deja_la_partida_nueva() -> void:
	var other: Node = _fresh()
	assert_false(_save.load_from(other, PATH))
	assert_eq(other.master_volume, 1.0)


func test_archivo_corrupto_no_rompe() -> void:
	for garbage: String in ["", "{no es json", "[1, 2, 3]", "null", "\"hola\"", "{\"master_volume\": ", "\u0000\u0001\u0002"]:
		_write(garbage)
		var other: Node = _fresh()
		assert_false(_save.load_from(other, PATH), "basura: %s" % garbage.c_escape())
		assert_eq(other.master_volume, 1.0)


func test_datos_mal_tipados_se_ignoran() -> void:
	_write(JSON.stringify({"version": 1, "master_volume": "alto"}))
	var other: Node = _fresh()
	assert_true(_save.load_from(other, PATH))
	assert_eq(other.master_volume, 1.0)


func test_volumen_imposible_se_corrige() -> void:
	_write(JSON.stringify({"version": 1, "master_volume": 7.5}))
	var other: Node = _fresh()
	_save.load_from(other, PATH)
	assert_eq(other.master_volume, 1.0, "se limita a 0..1")


func test_version_ausente_se_acepta() -> void:
	_write(JSON.stringify({"master_volume": 0.5}))
	var other: Node = _fresh()
	assert_true(_save.load_from(other, PATH))
	assert_almost_eq(other.master_volume, 0.5, 0.001)
