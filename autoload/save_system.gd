extends Node
## Serializa GameState a user://save.json. Guarda al oír GameState.changed.

const SAVE_PATH: String = "user://save.json"
const TEST_SAVE_PATH: String = "user://test_save.json"  ## las pruebas nunca tocan la partida real
const CURRENT_VERSION: int = 1

var path: String = SAVE_PATH


func _ready() -> void:
	path = TEST_SAVE_PATH if _is_test_run() else SAVE_PATH
	load_from(GameState, path)
	GameState.changed.connect(func() -> void: save_to(GameState, path))


## Escribe el estado en `file_path` (a un temporal y luego renombra, para no dejar archivos a medias).
func save_to(state: Node, file_path: String) -> Error:
	var payload: Dictionary = state.to_dict()
	payload["version"] = CURRENT_VERSION
	var tmp: String = file_path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp, file_path)


## Carga `file_path` en el estado. Si no existe, está corrupto o es ilegible deja el estado por defecto
## y devuelve false (nunca rompe el juego).
func load_from(state: Node, file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	var text: String = FileAccess.get_file_as_string(file_path)
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:  # parse() no imprime errores del motor
		print("Guardado ilegible: se empieza de cero (%s)" % file_path)
		return false
	state.from_dict(_migrate(json.data as Dictionary))
	return true


## Lleva datos de versiones antiguas a la actual. Hoy solo existe la 1.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0)) if data.get("version") is int or data.get("version") is float else 0
	# if version < 2: … (futuras migraciones, una por versión)
	data["version"] = maxi(version, CURRENT_VERSION)
	return data


func _is_test_run() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg.contains("gut_cmdln"):
			return true
	return false
