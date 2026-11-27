class_name Catalog
extends RefCounted
## Carga los recursos de data/ en diccionarios id → recurso.


static func cars() -> Dictionary:
	return _load_dir("res://data/cars", "id")


static func upgrades() -> Dictionary:
	return _load_dir("res://data/upgrades", "id")


static func championships() -> Dictionary:
	return _load_dir("res://data/championships", "id")


## Pistas jugables (sin las de tema "test").
static func tracks() -> Dictionary:
	var all: Dictionary = _load_dir("res://data/tracks", "id")
	var out: Dictionary = {}
	for id: String in all:
		if (all[id] as TrackData).theme != "test":
			out[id] = all[id]
	return out


## Ids ordenados por una clave numérica (y luego por id) para mostrarlos en un orden estable.
static func sorted_ids(dict: Dictionary, key: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in dict:
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka: float = float(dict[a].get(key))
		var kb: float = float(dict[b].get(key))
		return ka < kb if ka != kb else a < b)
	return ids


static func _load_dir(dir: String, id_prop: String) -> Dictionary:
	var out: Dictionary = {}
	for file: String in DirAccess.get_files_at(dir):
		var clean: String = file.trim_suffix(".remap")  # en exportaciones los .tres llevan .remap
		if not clean.ends_with(".tres"):
			continue
		var res: Resource = load(dir.path_join(clean))
		if res != null:
			out[str(res.get(id_prop))] = res
	return out
