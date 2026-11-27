extends SceneTree
## Exporta los datos de las pistas que necesita el servidor online (docs/online_tracks.json):
## laps, número de checkpoints y longitud de la línea de carrera. Hay que copiarlo al servidor
## (backend/app/game/tracks.json) cada vez que cambie una pista.
## Uso: godot --headless --path . -s res://tools/export_online_tracks.gd

const OUT: String = "res://docs/online_tracks.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # el árbol y los autoloads ya están listos
	var data: Dictionary = {}
	var ids: Array[String] = Catalog.sorted_ids(Catalog.tracks(), "unlock_cost")
	for id: String in ids:
		var td: TrackData = Catalog.tracks()[id]
		var track: Track = td.scene.instantiate() as Track
		root.add_child(track)  # _ready genera los checkpoints
		await process_frame
		data[id] = {
			"display_name": td.display_name,
			"laps": td.laps,
			"checkpoints": track.checkpoint_count,
			"length_px": snappedf(track.curve_length, 0.1),
		}
		track.free()
	var file: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"order": ids, "tracks": data}, "\t") + "\n")
	file.close()
	print("exportado ", OUT, ": ", ids)
	quit(0)
