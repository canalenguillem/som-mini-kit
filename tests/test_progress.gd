extends GutTest
## Progreso: mejor nota, intentos, notas de zona y desbloqueo en el orden del cuaderno.

const GameStateScript: GDScript = preload("res://autoload/game_state.gd")
const SaveSystemScript: GDScript = preload("res://autoload/save_system.gd")
const S := Progress.State


func _zones() -> Array[ZoneData]:
	var out: Array[ZoneData] = []
	for i: int in range(1, 8):
		out.append(load("res://data/zones/zone_%d.tres" % i) as ZoneData)
	return out


func _mission(id: String) -> MissionData:
	var m := MissionData.new()
	m.id = id
	return m


func _zone(ids: Array) -> ZoneData:
	var z := ZoneData.new()
	for id: String in ids:
		z.missions.append(_mission(id))
	return z


func test_record_guarda_la_mejor_y_cuenta_intentos() -> void:
	var p: Dictionary = Progress.record({}, "m4_fifo", 4.5)
	p = Progress.record(p, "m4_fifo", 8.0)
	p = Progress.record(p, "m4_fifo", 6.0)
	assert_almost_eq(Progress.best(p, "m4_fifo"), 8.0, 0.001)
	assert_eq(Progress.attempts(p, "m4_fifo"), 3)
	assert_true(Progress.mission_passed(p, "m4_fifo"))
	assert_false(Progress.mission_passed(p, "m4_rr"))


func test_nota_y_estado_de_una_zona() -> void:
	var z: ZoneData = _zone(["a", "b"])
	var p: Dictionary = Progress.record({}, "a", 8.0)
	assert_almost_eq(Progress.zone_grade(z, p), 4.0, 0.001, "la sala sin hacer cuenta 0")
	assert_false(Progress.zone_passed(z, p))
	p = Progress.record(p, "b", 6.0)
	assert_almost_eq(Progress.zone_grade(z, p), 7.0, 0.001)
	assert_true(Progress.zone_passed(z, p))
	assert_eq(Progress.rooms_passed(z, p), 2)


func test_desbloqueo_en_orden() -> void:
	var zones: Array[ZoneData] = [_zone([]), _zone(["a"]), _zone(["b"]), _zone([])]
	var p: Dictionary = {}
	assert_eq(Progress.zone_state(zones, 0, p), S.SOON, "sin salas: próximamente")
	assert_eq(Progress.zone_state(zones, 1, p), S.OPEN, "la primera con salas está abierta")
	assert_eq(Progress.zone_state(zones, 2, p), S.LOCKED)
	p = Progress.record(p, "a", 4.0)
	assert_eq(Progress.zone_state(zones, 2, p), S.LOCKED, "con un 4 no se abre la siguiente")
	p = Progress.record(p, "a", 5.0)
	assert_eq(Progress.zone_state(zones, 1, p), S.PASSED)
	assert_eq(Progress.zone_state(zones, 2, p), S.OPEN)


func test_las_zonas_del_juego() -> void:
	var zones: Array[ZoneData] = _zones()
	for i: int in zones.size():
		assert_eq(zones[i].topic, i + 1)
	assert_eq(zones[3].missions.size(), 6, "la zona 4 tiene seis salas")
	assert_eq(Progress.zone_state(zones, 3, {}), S.OPEN, "hoy la zona 4 es la primera abierta")
	assert_eq(Progress.zone_state(zones, 0, {}), S.SOON)


func test_progreso_mal_guardado_se_limpia() -> void:
	var clean: Dictionary = Progress.sanitize({"m4_fifo": {"best": 12, "attempts": 2}, "x": "basura",
			"y": {"best": "alto", "attempts": 1}, "z": {"best": 5, "attempts": -1}, 7: {"best": 5, "attempts": 1}})
	assert_eq(clean, {"m4_fifo": {"best": 10.0, "attempts": 2}})
	assert_eq(Progress.sanitize("nada"), {})


func test_el_progreso_se_guarda() -> void:
	var gs: Node = autofree(GameStateScript.new())
	gs.record_attempt("m4_srt", 7.5)
	var save: Node = autofree(SaveSystemScript.new())
	var path: String = "user://test_save_progress.json"
	assert_eq(save.save_to(gs, path), OK)
	var other: Node = autofree(GameStateScript.new())
	assert_true(save.load_from(other, path))
	assert_almost_eq(Progress.best(other.progress, "m4_srt"), 7.5, 0.001)
	DirAccess.remove_absolute(path)
	GameState.reset()


func test_el_marco_apunta_el_intento() -> void:
	GameState.reset()
	GameState.pending_seed = 123456
	var shell: MissionShell = (load("res://scenes/mission/mission_shell.tscn") as PackedScene).instantiate() as MissionShell
	shell.mission = load("res://data/missions/m4_states.tres") as MissionData
	shell.reports_dir = "user://test_reports"
	add_child_autofree(shell)
	await wait_physics_frames(1)
	shell.next_phase()
	shell.next_phase()
	var room: ArcadeRoom = shell.content as ArcadeRoom
	room.play_all()
	shell.hand_in()
	assert_eq(Progress.attempts(GameState.progress, "m4_states"), 1)
	for f: String in DirAccess.get_files_at("user://test_reports"):
		DirAccess.remove_absolute("user://test_reports".path_join(f))
	GameState.reset()


func test_mapa() -> void:
	GameState.reset()
	GameState.progress = Progress.record({}, "m4_states", 9.0)
	var hub: Hub = add_child_autofree((load("res://scenes/hub/hub.tscn") as PackedScene).instantiate()) as Hub
	await wait_physics_frames(2)
	assert_eq(hub._zone_buttons.size(), 7)
	assert_true(hub._zone_buttons[0].disabled, "zona 1: próximamente")
	assert_false(hub._zone_buttons[3].disabled, "zona 4 abierta")
	assert_string_contains(hub._zone_buttons[3].text, "1/6")
	hub._board.travel_time = 0.0
	hub.select_zone(3)
	assert_true(hub._panel_layer.visible)
	assert_eq(hub._rooms.get_child_count(), 6)
	hub.close_zone()
	assert_false(hub._panel_layer.visible)
	GameState.reset()
