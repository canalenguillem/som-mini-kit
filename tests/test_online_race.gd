extends GutTest
## Carrera online con un cliente de red falso: coches remotos, salida sincronizada, checkpoints, bots y resultados.

const RACE_PATH: String = "res://scenes/race/online_race.tscn"
const ME: int = 20  ## mi user_id

var _client: OnlineClient
var _socket: FakeOnline.Socket
var _race: OnlineRace


func _players(host_id: int) -> Dictionary:
	return {
		"t": "start", "room": "r1", "track": "west_01", "laps": 2, "checkpoints": 27, "countdown_ms": 3000, "host_id": host_id,
		"players": [
			{"slot": 0, "user_id": 10, "username": "ana", "bot": false},
			{"slot": 1, "user_id": 15, "username": "beto", "bot": false},
			{"slot": 2, "user_id": ME, "username": "yo", "bot": false},
			{"slot": 3, "user_id": null, "username": "Bot 4", "bot": true},
			{"slot": 4, "user_id": null, "username": "Bot 5", "bot": true},
		],
	}


## host_id 10 → soy un humano normal; host_id ME → soy el anfitrión (llevo a los bots).
func _start(host_id: int = 10, running: bool = false) -> void:
	_client = OnlineClient.new()
	_client.use_prefs = false
	_socket = FakeOnline.Socket.new()
	_client.socket_factory = func() -> Object: return _socket
	add_child_autofree(_client)
	_client.token = "tok"
	_client.user = {"id": ME, "username": "yo"}
	_client.connect_socket()
	_client.race_info = _players(host_id)
	_client.race_running = running
	GameState.reset()
	_race = (load(RACE_PATH) as PackedScene).instantiate() as OnlineRace
	_race.online = _client
	_race.leave_delay = 1000.0
	add_child_autofree(_race)
	await wait_physics_frames(3)


func _racer(slot: int) -> RaceManager.Racer:
	return _race._slot_racers[slot]


func test_los_cinco_coches_y_quien_los_lleva() -> void:
	await _start(10)
	assert_eq(_race.racers.size(), 5)
	assert_eq(_race.player, _racer(2))
	assert_false(_racer(2).car.ghost, "mi coche simula")
	assert_true(_racer(0).car.ghost and _racer(1).car.ghost, "los demás humanos son fantasmas")
	assert_true(_racer(3).car.ghost and _racer(4).car.ghost, "los bots, si no soy anfitrión, también")
	for slot: int in [0, 1, 3, 4]:
		assert_true(_racer(slot).remote, "slot %d" % slot)
		assert_eq(_racer(slot).car.collision_layer, 0)


func test_el_anfitrion_lleva_a_los_bots() -> void:
	await _start(ME)
	for slot: int in [3, 4]:
		var car: Car = _racer(slot).car
		assert_false(car.ghost, "bot %d simulado aquí" % slot)
		assert_true(car.get_node("Controller") is AIController)
		assert_false(_racer(slot).remote)
	assert_true(_racer(0).car.ghost)


func test_nadie_choca_con_otros_coches() -> void:
	await _start(ME)
	for r: RaceManager.Racer in _race.racers:
		assert_eq(r.car.collision_layer, 0, "capa de %s" % r.display_name)
		assert_eq(r.car.collision_mask & 2, 0, "ni mira a la capa de coches")


func test_parrilla_en_los_puestos_del_servidor() -> void:
	await _start()
	var grid: Array[Transform2D] = _race.track.start_transforms()
	for slot: int in 5:
		assert_lt(_racer(slot).car.global_position.distance_to(grid[slot].origin), 1.0, "slot %d" % slot)


func test_todos_usan_el_coche_base_y_el_sprite_del_puesto() -> void:
	await _start()
	for r: RaceManager.Racer in _race.racers:
		assert_eq(r.car.data.id, "beetle")
		assert_true(r.car.get_node("Sprite").visible)
	assert_ne(_racer(0).car.get_node("Sprite").texture, _racer(1).car.get_node("Sprite").texture)


func test_la_salida_la_manda_el_servidor() -> void:
	await _start()
	assert_eq(_race.state, RaceManager.State.COUNTDOWN)
	_race._countdown_left = -5.0  # la cuenta local ya acabó, pero no ha llegado "go"
	await wait_physics_frames(3)
	assert_eq(_race.state, RaceManager.State.COUNTDOWN, "sin go no se sale")
	assert_true(_race.player.car.locked)
	_client._dispatch({"t": "go"})
	assert_eq(_race.state, RaceManager.State.RACING)
	assert_false(_race.player.car.locked)


func test_si_go_llego_antes_de_cargar_la_escena() -> void:
	await _start(10, true)
	await wait_physics_frames(3)
	assert_eq(_race.state, RaceManager.State.RACING)


func test_los_trenes_se_sincronizan_en_la_salida() -> void:
	_client = null
	await _start()
	_race.track.queue_free()  # pista de pruebas distinta: west_02 tiene tren
	_race.queue_free()
	await wait_physics_frames(2)
	_client = OnlineClient.new()
	_client.use_prefs = false
	_socket = FakeOnline.Socket.new()
	_client.socket_factory = func() -> Object: return _socket
	add_child_autofree(_client)
	_client.token = "tok"
	_client.user = {"id": ME, "username": "yo"}
	var info: Dictionary = _players(10)
	info["track"] = "west_02"
	_client.race_info = info
	_race = (load(RACE_PATH) as PackedScene).instantiate() as OnlineRace
	_race.online = _client
	_race.leave_delay = 1000.0
	add_child_autofree(_race)
	await wait_physics_frames(2)
	var train: Train = null
	for n: Node in _race.track.get_node("Obstacles").get_children():
		if n is Train:
			train = n
	assert_not_null(train)
	await wait_physics_frames(30)  # el tren avanza su reloj durante la cuenta atrás
	train._time = 5.0
	_client._dispatch({"t": "go"})
	assert_almost_eq(train._time, train.phase, 0.001, "el reloj del tren vuelve al principio en la salida")


func test_las_posiciones_de_los_demas_mueven_sus_fantasmas() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	_client._dispatch({"t": "states", "ms": 500, "cars": [
		{"s": 0, "x": 5000.0, "y": 300.0, "r": 1.0, "vx": 0.0, "vy": 0.0, "l": 1, "c": 5},
		{"s": 3, "x": 6000.0, "y": 400.0, "r": 0.5, "vx": 0.0, "vy": 0.0, "l": 0, "c": 2},
	]})
	await wait_physics_frames(30)
	assert_lt(_racer(0).car.global_position.distance_to(Vector2(5000, 300)), 5.0)
	assert_almost_eq(_racer(0).car.rotation, 1.0, 0.05)
	assert_lt(_racer(3).car.global_position.distance_to(Vector2(6000, 400)), 5.0)
	assert_eq(_racer(0).tracker.laps, 1)
	assert_eq(_racer(0).tracker.last_checkpoint, 5, "vueltas y checkpoints ajenos son los del servidor")


func test_un_fantasma_se_mueve_suave_y_sigue_con_su_velocidad() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	_client._dispatch({"t": "states", "ms": 0, "cars": [{"s": 1, "x": 1000.0, "y": 1000.0, "r": 0.0, "vx": 300.0, "vy": 0.0, "l": 0, "c": 0}]})
	await wait_physics_frames(2)
	var start_x: float = _racer(1).car.global_position.x
	await wait_physics_frames(30)  # 0,5 s sin paquetes nuevos: extrapola con la velocidad
	assert_gt(_racer(1).car.global_position.x, start_x + 50.0)
	assert_lt(_racer(1).car.global_position.x, start_x + 200.0)


func test_mis_datos_no_se_pisan_con_los_del_servidor() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	var before: Vector2 = _race.player.car.global_position
	_client._dispatch({"t": "states", "ms": 0, "cars": [{"s": 2, "x": 99999.0, "y": 99999.0, "r": 0.0, "vx": 0.0, "vy": 0.0, "l": 9, "c": 9}]})
	await wait_physics_frames(3)
	assert_eq(_race.player.car.global_position, before)
	assert_eq(_race.player.tracker.laps, 0)


func test_solo_se_avisa_de_los_checkpoints_que_cuentan() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	_socket.sent.clear()
	_race.track.checkpoint_passed.emit(_race.player.car, 3)  # saltarse uno
	_race.track.checkpoint_passed.emit(_race.player.car, 1)
	_race.track.checkpoint_passed.emit(_race.player.car, 1)  # repetido
	_race.track.checkpoint_passed.emit(_race.player.car, 2)
	_race.track.checkpoint_passed.emit(_racer(0).car, 1)  # el de un fantasma no es cosa mía
	var cps: Array = _socket.sent_of("cp").map(func(m: Dictionary) -> int: return int(m["i"]))
	assert_eq(cps, [1, 2])
	assert_false(_socket.sent_of("cp")[0].has("slot"))


func test_los_checkpoints_no_cuentan_antes_de_la_salida() -> void:
	await _start()
	_socket.sent.clear()
	_race.track.checkpoint_passed.emit(_race.player.car, 1)
	assert_eq(_socket.sent_of("cp").size(), 0)


func test_el_anfitrion_envia_el_estado_y_los_checkpoints_de_los_bots() -> void:
	await _start(ME)
	_client._dispatch({"t": "go"})
	_socket.sent.clear()
	await wait_physics_frames(15)
	var states: Array[Dictionary] = _socket.sent_of("state")
	var slots: Array = states.map(func(m: Dictionary) -> int: return int(m.get("slot", -1)))
	assert_true(slots.has(-1), "envío el mío (sin slot)")
	assert_true(slots.has(3) and slots.has(4), "y el de los bots, con su puesto")
	assert_false(slots.has(0), "nunca el de otro humano")
	_socket.sent.clear()
	_race.track.checkpoint_passed.emit(_racer(3).car, 1)
	var cp: Dictionary = _socket.sent_of("cp")[0]
	assert_eq([int(cp["i"]), int(cp["slot"])], [1, 3])


func test_un_no_anfitrion_no_envia_nada_de_los_bots() -> void:
	await _start(10)
	_client._dispatch({"t": "go"})
	_socket.sent.clear()
	await wait_physics_frames(15)
	var slots: Array = _socket.sent_of("state").map(func(m: Dictionary) -> int: return int(m.get("slot", -1)))
	assert_true(slots.has(-1))
	assert_false(slots.has(3) or slots.has(4) or slots.has(0))


func test_el_estado_se_envia_a_unas_15_veces_por_segundo() -> void:
	await _start(10)
	_client._dispatch({"t": "go"})
	_socket.sent.clear()
	await wait_physics_frames(60)  # ~1 s
	var n: int = _socket.sent_of("state").size()
	assert_between(n, 10, 20)


func test_si_el_anfitrion_se_va_heredo_a_los_bots() -> void:
	await _start(10)
	_client._dispatch({"t": "go"})
	_client._dispatch({"t": "states", "ms": 0, "cars": [{"s": 3, "x": 800.0, "y": 600.0, "r": 0.0, "vx": 0.0, "vy": 0.0, "l": 1, "c": 4}]})
	await wait_physics_frames(3)
	assert_true(_racer(3).car.ghost)
	_client._dispatch({"t": "host", "user_id": ME})
	for slot: int in [3, 4]:
		assert_false(_racer(slot).car.ghost)
		assert_false(_racer(slot).remote)
		assert_true(_racer(slot).car.get_node("Controller") is AIController)
		assert_eq((_racer(slot).car.get_node("Controller") as CarController).owner_car, _racer(slot).car)
	assert_eq(_racer(3).tracker.last_checkpoint, 4, "sigue donde iba")
	_socket.sent.clear()
	await wait_physics_frames(15)
	var slots: Array = _socket.sent_of("state").map(func(m: Dictionary) -> int: return int(m.get("slot", -1)))
	assert_true(slots.has(3) and slots.has(4))


func test_otro_anfitrion_no_me_cambia_nada() -> void:
	await _start(10)
	_client._dispatch({"t": "host", "user_id": 15})
	assert_true(_racer(3).car.ghost)


func test_terminar_las_vueltas_bloquea_mi_coche_y_espera_resultados() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	var n: int = 27
	for lap: int in 2:
		for i: int in range(1, n):
			_race.track.checkpoint_passed.emit(_race.player.car, i)
		_race.track.checkpoint_passed.emit(_race.player.car, 0)
	assert_true(_race.player.tracker.finished)
	assert_true(_race.player.car.locked)
	assert_eq(_race.state, RaceManager.State.RACING, "sigue en carrera hasta que el servidor da los resultados")
	assert_false(_race._results.visible)
	assert_eq(_socket.sent_of("cp").size(), 27 * 2)


func test_el_tiempo_oficial_es_el_del_servidor() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	_client._dispatch({"t": "finish", "slot": 0, "username": "ana", "bot": false, "time_ms": 41230, "position": 1})
	assert_almost_eq(_racer(0).finish_time, 41.23, 0.001)


func test_pantalla_de_resultados_online() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	watch_signals(Events)
	var money_before: int = GameState.money
	_client._dispatch({"t": "results", "track": "west_01", "results": [
		{"position": 1, "slot": 0, "user_id": 10, "username": "ana", "bot": false, "finished": true, "time_ms": 41230, "suspicious": false},
		{"position": 2, "slot": 2, "user_id": ME, "username": "yo", "bot": false, "finished": true, "time_ms": 43000, "suspicious": false},
		{"position": 3, "slot": 1, "user_id": 15, "username": "beto", "bot": false, "finished": false, "time_ms": null, "suspicious": false},
		{"position": 4, "slot": 3, "user_id": null, "username": "Bot 4", "bot": true, "finished": false, "time_ms": null, "suspicious": false},
	]})
	assert_eq(_race.state, RaceManager.State.FINISHED)
	var results: Results = _race._results
	assert_true(results.visible)
	assert_true(results._lobby.visible, "botón de volver a las salas")
	assert_false(results._retry.visible)
	assert_false(results._garage.visible)
	assert_string_contains(results._list.text, "1º  ana  0:41.23")
	assert_string_contains(results._list.text, "3º  beto  —")
	assert_eq(results._prize.text, "Carrera online")
	assert_signal_not_emitted(Events, "race_finished")
	assert_eq(GameState.money, money_before, "las carreras online no dan monedas")
	assert_true(_race._pause_menu.can_pause == false)


func test_los_resultados_se_ignoran_si_ya_termino() -> void:
	await _start()
	var msg: Dictionary = {"t": "results", "track": "west_01", "results": [
		{"position": 1, "slot": 2, "user_id": ME, "username": "yo", "bot": false, "finished": true, "time_ms": 1000, "suspicious": false}]}
	_client._dispatch(msg)
	msg["results"][0]["username"] = "otro"
	_client._dispatch(msg)
	assert_string_contains(_race._results._list.text, "yo")


func test_la_pausa_no_para_la_carrera_y_abandonar_sale_de_la_sala() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	assert_false(_race._pause_menu.pauses_game)
	_race._pause_menu.open()
	assert_false(get_tree().paused, "los demás siguen corriendo")
	_race._pause_menu.close()
	assert_eq(_race._pause_menu.quit_scene, "res://scenes/ui/online_lobby.tscn")
	_socket.sent.clear()
	_race._pause_menu.on_quit.call()
	assert_eq(_socket.sent_of("room_leave").size(), 1)


func test_perder_la_conexion_avisa_y_vuelve_al_vestibulo() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	_socket.server_closes(1006)
	await wait_physics_frames(3)
	assert_true(_race._leaving)
	assert_string_contains(_race._hud._countdown.text, "conexión")


func test_sala_cerrada_por_un_admin_avisa() -> void:
	await _start()
	_client._dispatch({"t": "room_closed"})
	assert_true(_race._leaving)
	assert_string_contains(_race._hud._countdown.text, "cerrado")


func test_sin_rubber_banding_online() -> void:
	await _start(ME)
	_client._dispatch({"t": "go"})
	await wait_physics_frames(60)
	for slot: int in [3, 4]:
		assert_eq(_racer(slot).car.rubber_band, 1.0)


func test_la_posicion_del_hud_usa_vueltas_ajenas_del_servidor() -> void:
	await _start()
	_client._dispatch({"t": "go"})
	_client._dispatch({"t": "states", "ms": 0, "cars": [
		{"s": 0, "x": 0.0, "y": 0.0, "r": 0.0, "vx": 0.0, "vy": 0.0, "l": 1, "c": 10},
		{"s": 1, "x": 0.0, "y": 0.0, "r": 0.0, "vx": 0.0, "vy": 0.0, "l": 0, "c": 20},
	]})
	await wait_physics_frames(3)
	var order: Array[int] = _race._order()
	var by_slot: Array = order.map(func(i: int) -> int: return _race.racers[i].slot)
	assert_eq(by_slot.find(0), 0, "ana (1 vuelta) va primera")
	assert_lt(by_slot.find(0), by_slot.find(1))
	assert_lt(by_slot.find(1), by_slot.find(2), "yo, en la salida, voy detrás")
