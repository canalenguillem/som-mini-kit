extends GutTest
## Guardado: ida y vuelta, y un archivo corrupto no rompe el juego.

const GameStateScript: GDScript = preload("res://autoload/game_state.gd")
const SaveSystemScript: GDScript = preload("res://autoload/save_system.gd")
const PATH: String = "user://test_save_unit.json"

var _gs: Node
var _save: Node


func before_each() -> void:
	_gs = autofree(GameStateScript.new())
	_gs.load_catalog()
	_gs.reset()
	_save = autofree(SaveSystemScript.new())
	_remove()


func after_each() -> void:
	_remove()


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
	other.load_catalog()
	other.reset()
	return other


func test_ida_y_vuelta() -> void:
	_gs.money = 1234
	_gs.buy_car("buggy")  # sin dinero: no se compra
	_gs.money = 6000
	_gs.buy_car("buggy")
	_gs.select_car("buggy")
	_gs.buy_upgrade("buggy", "engine")
	_gs.buy_upgrade("buggy", "nitro")
	_gs.unlock_track("jungle_01")
	_gs.apply_race_result(_gs.tracks["west_01"], 1, 91.25)
	assert_eq(_save.save_to(_gs, PATH), OK)

	var other: Node = _fresh()
	assert_true(_save.load_from(other, PATH))
	assert_eq(other.money, _gs.money)
	assert_eq(other.owned_cars, _gs.owned_cars)
	assert_eq(other.selected_car, "buggy")
	assert_eq(other.upgrade_level("buggy", "engine"), 1)
	assert_eq(other.upgrade_level("buggy", "nitro"), 1)
	assert_true(other.is_track_unlocked("jungle_01"))
	assert_almost_eq(float(other.best_times["west_01"]), 91.25, 0.001)


func test_el_archivo_lleva_version() -> void:
	_save.save_to(_gs, PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_true(parsed is Dictionary)
	assert_eq(int((parsed as Dictionary)["version"]), SaveSystemScript.CURRENT_VERSION)
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "no deja temporales")


func test_sin_archivo_deja_la_partida_nueva() -> void:
	var other: Node = _fresh()
	assert_false(_save.load_from(other, PATH))
	assert_eq(other.money, 0)
	assert_eq(other.selected_car, "beetle")


func test_archivo_corrupto_no_rompe() -> void:
	for garbage: String in ["", "{no es json", "[1, 2, 3]", "null", "\"hola\"", "{\"money\": ", "\u0000\u0001\u0002"]:
		_write(garbage)
		var other: Node = _fresh()
		other.money = 77
		assert_false(_save.load_from(other, PATH), "basura: %s" % garbage.c_escape())
		assert_eq(other.selected_car, "beetle")
		assert_true(other.owned_cars.has("beetle"))


func test_datos_mal_tipados_se_ignoran() -> void:
	_write(JSON.stringify({
		"version": 1, "money": "mucho", "owned_cars": "beetle", "selected_car": 5,
		"upgrades": [1, 2], "unlocked_tracks": {"a": 1}, "best_times": "x",
	}))
	var other: Node = _fresh()
	assert_true(_save.load_from(other, PATH))
	assert_eq(other.money, 0)
	assert_eq(other.selected_car, "beetle")
	assert_eq(other.owned_cars, ["beetle"] as Array[String])
	assert_true(other.best_times.is_empty())


func test_valores_imposibles_se_corrigen() -> void:
	_write(JSON.stringify({
		"version": 1, "money": -500,
		"owned_cars": ["beetle", "fantasma", "buggy"], "selected_car": "sport",
		"upgrades": {"beetle": {"engine": 99, "turbo": -3, "magia": 4}, "sport": {"engine": 2}},
		"unlocked_tracks": ["west_02", "nope"], "best_times": {"west_01": -1.0, "west_02": 70.5, "nope": 3.0},
	}))
	var other: Node = _fresh()
	assert_true(_save.load_from(other, PATH))
	assert_eq(other.money, 0, "dinero negativo")
	assert_eq(other.owned_cars, ["beetle", "buggy"] as Array[String], "coches desconocidos fuera")
	assert_eq(other.selected_car, "beetle", "no se puede seleccionar un coche que no se tiene")
	assert_eq(other.upgrade_level("beetle", "engine"), 5, "nivel máximo")
	assert_eq(other.upgrade_level("beetle", "turbo"), 0)
	assert_eq(other.upgrade_level("sport", "engine"), 0, "mejoras de coche no comprado")
	assert_true(other.is_track_unlocked("west_02"))
	assert_false(other.is_track_unlocked("nope"))
	assert_false(other.best_times.has("west_01"))
	assert_almost_eq(float(other.best_times["west_02"]), 70.5, 0.001)


func test_pistas_gratuitas_siempre_desbloqueadas() -> void:
	_write(JSON.stringify({"version": 1, "unlocked_tracks": []}))
	var other: Node = _fresh()
	_save.load_from(other, PATH)
	assert_true(other.is_track_unlocked("west_01"))


func test_version_antigua_o_ausente_se_acepta() -> void:
	_write(JSON.stringify({"money": 321}))
	var other: Node = _fresh()
	assert_true(_save.load_from(other, PATH))
	assert_eq(other.money, 321)
