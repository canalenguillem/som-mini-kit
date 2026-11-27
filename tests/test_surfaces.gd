extends GutTest
## Superficies: los .tres cargan con los valores del GDD y la pista las resuelve.

const TRACK_PATH: String = "res://scenes/tracks/test_track.tscn"


func test_superficies_cargan_con_valores_del_gdd() -> void:
	var expected: Dictionary = {
		"asphalt": [1.0, 1.0, 1.0],
		"dirt": [0.75, 0.95, 1.1],
		"mud": [0.5, 0.7, 2.0],
		"sand": [0.6, 0.8, 1.6],
		"grass": [0.7, 0.85, 1.4],
		"water": [0.6, 0.6, 2.5],
	}
	for id: String in expected:
		var s: SurfaceData = load("res://data/surfaces/%s.tres" % id) as SurfaceData
		assert_not_null(s, id)
		assert_eq(s.id, id)
		var v: Array = expected[id]
		assert_almost_eq(s.grip_mult, float(v[0]), 0.001, id)
		assert_almost_eq(s.speed_mult, float(v[1]), 0.001, id)
		assert_almost_eq(s.drag_mult, float(v[2]), 0.001, id)


func test_track_resuelve_zonas() -> void:
	var track: Track = add_child_autofree((load(TRACK_PATH) as PackedScene).instantiate()) as Track
	assert_eq(track.get_surface_at(Vector2(0, 520)).id, "asphalt", "arranque")
	assert_eq(track.get_surface_at(Vector2(970, 0)).id, "dirt", "extremo derecho")
	assert_eq(track.get_surface_at(Vector2(-970, 0)).id, "mud", "extremo izquierdo")
	assert_eq(track.get_surface_at(Vector2(5000, 5000)).id, "asphalt", "fuera: por defecto")


func test_track_genera_checkpoints_y_parrilla() -> void:
	var track: Track = add_child_autofree((load(TRACK_PATH) as PackedScene).instantiate()) as Track
	assert_gte(track.checkpoint_count, 3)
	assert_eq(track.get_node("Checkpoints").get_child_count(), track.checkpoint_count)
	assert_eq(track.start_transforms().size(), 5)
	# la parrilla está detrás de la meta: progreso justo por debajo de 1 (o 0), nunca en mitad de la vuelta
	for xf: Transform2D in track.start_transforms():
		var p: float = track.get_progress(xf.origin)
		assert_true(p > 0.9 or p < 0.02, "progreso parrilla %f" % p)
	assert_almost_eq(track.curve_length, track.segment_length(0) * track.checkpoint_count, track.curve_length * 0.02)


func test_progreso_crece_en_el_sentido_de_carrera() -> void:
	var track: Track = add_child_autofree((load(TRACK_PATH) as PackedScene).instantiate()) as Track
	var right: float = track.get_progress(Vector2(970, 0))
	var top: float = track.get_progress(Vector2(0, -520))
	var left: float = track.get_progress(Vector2(-970, 0))
	assert_between(right, 0.15, 0.35)
	assert_gt(top, right)
	assert_gt(left, top)
