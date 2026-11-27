extends GutTest
## Idiomas: catalán por defecto, castellano e inglés; el cambio se aplica al momento y se guarda.

const SaveSystemScript: GDScript = preload("res://autoload/save_system.gd")
const GameStateScript: GDScript = preload("res://autoload/game_state.gd")
const CSV_PATH: String = "res://data/texts/ui.csv"
## Escenas cuyos textos visibles deben ser claves de traducción.
## Las pantallas online del kit se traducen en M11.
const TRANSLATED_SCENES: Array[String] = [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/options_panel.tscn",
	"res://scenes/ui/pause_menu.tscn",
	"res://scenes/ui/language_selector.tscn",
	"res://scenes/hub/hub.tscn",
	"res://scenes/ui/name_dialog.tscn",
	"res://scenes/mission/mission_shell.tscn",
	"res://scenes/missions/sample/binary_switches.tscn",
	"res://scenes/missions/m4_scheduler/gantt_mission.tscn",
	"res://scenes/missions/m4_scheduler/arcade_room.tscn",
]


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	GameState.reset()


## Lee el CSV: clave → {locale → texto}.
func _rows() -> Dictionary:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	var out: Dictionary = {}
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < header.size() or line[0].is_empty():
			continue
		var row: Dictionary = {}
		for i: int in range(1, header.size()):
			row[header[i]] = line[i]
		out[line[0]] = row
	return out


func test_catalan_por_defecto() -> void:
	assert_eq(GameState.locale, "ca")
	assert_eq(TranslationServer.get_locale(), "ca")
	assert_eq(tr("MENU_PLAY"), "Jugar")
	assert_eq(tr("MENU_QUIT"), "Sortir")


func test_cambiar_idioma_traduce_al_momento() -> void:
	GameState.set_locale("es")
	assert_eq(tr("MENU_QUIT"), "Salir")
	GameState.set_locale("en")
	assert_eq(tr("MENU_QUIT"), "Quit")


func test_idioma_desconocido_vuelve_al_catalan() -> void:
	GameState.set_locale("fr")
	assert_eq(GameState.locale, "ca")
	assert_eq(TranslationServer.get_locale(), "ca")


func test_todas_las_claves_en_los_tres_idiomas() -> void:
	var rows: Dictionary = _rows()
	assert_gt(rows.size(), 10)
	for key: String in rows:
		for loc: String in GameState.LOCALES:
			assert_false(str((rows[key] as Dictionary).get(loc, "")).strip_edges().is_empty(),
					"falta %s en %s" % [key, loc])


func test_las_escenas_solo_usan_claves() -> void:
	var rows: Dictionary = _rows()
	var regex: RegEx = RegEx.create_from_string("\\ntext = \"([^\"]*)\"(?!\\nauto_translate_mode = 2)")
	for path: String in TRANSLATED_SCENES:
		var text: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in regex.search_all(text):
			assert_true(rows.has(m.get_string(1)), "%s: texto sin clave «%s»" % [path, m.get_string(1)])


func test_el_idioma_se_guarda_y_se_corrige() -> void:
	var gs: Node = autofree(GameStateScript.new())
	var save: Node = autofree(SaveSystemScript.new())
	var path: String = "user://test_save_locale.json"
	gs.set_locale("en")
	assert_eq(save.save_to(gs, path), OK)
	var other: Node = autofree(GameStateScript.new())
	assert_true(save.load_from(other, path))
	assert_eq(other.locale, "en")
	other.from_dict({"locale": 42})
	assert_eq(other.locale, "ca")
	other.from_dict({"locale": "xx"})
	assert_eq(other.locale, "ca")
	DirAccess.remove_absolute(path)
	GameState.reset()  # los GameState de prueba también tocan TranslationServer


func test_selector_cambia_el_idioma() -> void:
	var sel: LanguageSelector = add_child_autofree(
			(load("res://scenes/ui/language_selector.tscn") as PackedScene).instantiate()) as LanguageSelector
	await wait_physics_frames(1)
	assert_eq(sel.item_count, 3)
	assert_eq(sel.selected, 0)
	sel.select(1)
	sel.item_selected.emit(1)
	assert_eq(GameState.locale, "es")
	GameState.set_locale("en")
	assert_eq(sel.selected, 2, "el selector sigue al idioma aunque cambie desde otro sitio")
