extends SceneTree
## Carga todos los .gd/.tscn/.tres del proyecto (excepto addons/) e instancia las escenas.
## Uso: godot --headless --path . -s res://tools/load_all.gd

const EXTENSIONS: Array[String] = [".gd", ".tscn", ".tres"]
const SKIP_DIRS: Array[String] = ["res://addons", "res://.godot"]


func _initialize() -> void:
	var failed: int = 0
	var paths: Array[String] = _collect("res://")
	for path: String in paths:
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			printerr("FAIL load: ", path)
			failed += 1
			continue
		if res is PackedScene:
			var inst: Node = (res as PackedScene).instantiate()
			if inst == null:
				printerr("FAIL instantiate: ", path)
				failed += 1
			else:
				inst.free()
	print("load_all: %d archivos, %d fallos" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for skip: String in SKIP_DIRS:
		if dir_path.begins_with(skip):
			return out
	for file: String in DirAccess.get_files_at(dir_path):
		for ext: String in EXTENSIONS:
			if file.ends_with(ext):
				out.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		if sub.begins_with("."):
			continue
		out.append_array(_collect(dir_path.path_join(sub)))
	return out
