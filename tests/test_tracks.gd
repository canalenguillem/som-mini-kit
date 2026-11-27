extends GutTest
## Pistas del juego: geometría válida y que la IA puede completar una vuelta en cada una.

const TRACK_IDS: Array[String] = ["west_01", "west_02", "jungle_01", "jungle_02"]
const RACE_PATH: String = "res://scenes/race/race.tscn"
const DT: float = 1.0 / 60.0


func _data(id: String) -> TrackData:
	return load("res://data/tracks/%s.tres" % id) as TrackData


func _instance(id: String) -> Track:
	var td: TrackData = _data(id)
	assert_not_null(td, id)
	return add_child_autofree(td.scene.instantiate()) as Track


func test_trackdata_completos() -> void:
	for id: String in TRACK_IDS:
		var td: TrackData = _data(id)
		assert_eq(td.id, id)
		assert_false(td.display_name.is_empty(), id)
		assert_not_null(td.scene, id)
		assert_gt(td.laps, 0, id)
		assert_gt(td.reward_mult, 0.0, id)


func test_linea_de_carrera_cerrada() -> void:
	for id: String in TRACK_IDS:
		var track: Track = _instance(id)
		var curve: Curve2D = track.racing_line.curve
		var first: Vector2 = curve.get_point_position(0)
		var last: Vector2 = curve.get_point_position(curve.point_count - 1)
		assert_lt(first.distance_to(last), 5.0, "%s: línea cerrada" % id)
		assert_between(track.curve_length, 6000.0, 13000.0, "%s: longitud de vuelta" % id)


func test_checkpoints_y_parrilla() -> void:
	for id: String in TRACK_IDS:
		var track: Track = _instance(id)
		assert_gte(track.checkpoint_count, 8, "%s: checkpoints" % id)
		assert_eq(track.start_transforms().size(), 5, "%s: parrilla" % id)
		for xf: Transform2D in track.start_transforms():
			assert_not_null(track.get_surface_at(xf.origin), id)


func test_salida_y_checkpoints_estan_sobre_la_calzada() -> void:
	for id: String in TRACK_IDS:
		var track: Track = _instance(id)
		var walls: TileMapLayer = track.get_node("Walls") as TileMapLayer
		var ground: TileMapLayer = track.get_node("Ground") as TileMapLayer
		var spots: Array[Vector2] = []
		for xf: Transform2D in track.start_transforms():
			spots.append(xf.origin)
		for i: int in track.checkpoint_count:
			spots.append(track.get_respawn_transform(i).origin)
		for pos: Vector2 in spots:
			var cell: Vector2i = walls.local_to_map(walls.to_local(pos))
			assert_eq(walls.get_cell_source_id(cell), -1, "%s: %s sobre un muro" % [id, pos])
			assert_true(ground.get_cell_source_id(cell) != -1, "%s: %s fuera de la calzada" % [id, pos])


func test_muros_tienen_colision_y_el_mapa_esta_cerrado() -> void:
	for id: String in TRACK_IDS:
		var track: Track = _instance(id)
		var walls: TileMapLayer = track.get_node("Walls") as TileMapLayer
		assert_gt(walls.get_used_cells().size(), 100, id)
		assert_true(walls.tile_set.get_physics_layers_count() > 0, id)
		# Desde cualquier punto de la línea de carrera, en 4 direcciones se acaba chocando con un muro
		var curve: Curve2D = track.racing_line.curve
		var space: PhysicsDirectSpaceState2D = track.get_world_2d().direct_space_state
		await wait_physics_frames(2)
		for k: int in 8:
			var origin: Vector2 = track.racing_line.to_global(curve.sample_baked(curve.get_baked_length() * k / 8.0))
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var q := PhysicsRayQueryParameters2D.create(origin, origin + dir * 4000.0, 1)
				assert_false(space.intersect_ray(q).is_empty(), "%s: sin muro hacia %s desde %s" % [id, dir, origin])


func test_superficies_tematicas() -> void:
	var seen: Dictionary = {}
	for id: String in TRACK_IDS:
		var track: Track = _instance(id)
		var ground: TileMapLayer = track.get_node("Ground") as TileMapLayer
		var found: Dictionary = {}
		for cell: Vector2i in ground.get_used_cells():
			found[str(ground.get_cell_tile_data(cell).get_custom_data("surface"))] = true
		seen[id] = found
	assert_true(seen["west_01"].has("dirt") and seen["west_01"].has("sand"))
	assert_true(seen["jungle_01"].has("water") and seen["jungle_01"].has("mud") and seen["jungle_01"].has("grass"))
	assert_true(seen["jungle_02"].has("water"))


func test_obstaculos_tematicos() -> void:
	var w1: Node = _instance("west_01").get_node("Obstacles")
	assert_gt(_count(w1, RigidBody2D), 0, "west_01: barriles")
	var w2: Node = _instance("west_02").get_node("Obstacles")
	assert_eq(_count(w2, Train), 1, "west_02: tren")
	var j1: Node = _instance("jungle_01").get_node("Obstacles")
	assert_gt(j1.get_child_count(), 0, "jungle_01: troncos")
	assert_eq(_count(j1, RigidBody2D), 0)


func _count(root: Node, type: Variant) -> int:
	var n: int = 0
	for child: Node in root.get_children():
		if is_instance_of(child, type):
			n += 1
	return n


func test_tren_avisa_antes_de_cruzar() -> void:
	var train: Train = (load("res://scenes/obstacles/train.tscn") as PackedScene).instantiate() as Train
	train.period = 10.0
	train.warning_time = 2.0
	train.speed = 500.0
	train.half_span = 250.0  # cruza en 1 s
	add_child_autofree(train)
	var warned_before_crossing: bool = false
	for i: int in 700:  # 11,6 s
		train._physics_process(DT)
		if train._warning.visible and train.time_to_cross() > 0.0:
			warned_before_crossing = true
	assert_true(warned_before_crossing, "el aviso se enciende antes de que llegue")


## Con el tiempo acelerado, los 3 rivales completan una vuelta en cada pista.
func test_la_ia_completa_una_vuelta_en_cada_pista() -> void:
	for id: String in TRACK_IDS:
		Engine.time_scale = 10.0
		var race: RaceManager = (load(RACE_PATH) as PackedScene).instantiate() as RaceManager
		race.track_data = _data(id)
		race.countdown_seconds = 0.05
		add_child_autofree(race)
		race.player.car.collision_layer = 0  # el jugador parado no estorba
		var sim: float = 0.0
		while sim < 70.0 and not _rivals_lapped(race):
			await wait_physics_frames(30)
			sim += 30.0 * DT
			race.player.car.locked = true
		Engine.time_scale = 1.0
		for racer: RaceManager.Racer in race.racers:
			if not racer.is_player:
				assert_gte(racer.tracker.laps, 1, "%s: %s completa una vuelta (t=%.0f s)" % [id, racer.display_name, race.race_time])
				assert_lte(racer.respawn_count, 2, "%s: %s reapareció %d veces" % [id, racer.display_name, racer.respawn_count])
		race.queue_free()
		await wait_physics_frames(2)


func _rivals_lapped(race: RaceManager) -> bool:
	for racer: RaceManager.Racer in race.racers:
		if not racer.is_player and racer.tracker.laps < 1:
			return false
	return true


func after_each() -> void:
	Engine.time_scale = 1.0
