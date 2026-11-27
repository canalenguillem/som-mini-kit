extends GutTest
## OnlineClient con WebSocket y HTTP falsos: cuenta, mensajes de salas y carrera, desconexiones.

var _client: OnlineClient
var _socket: FakeOnline.Socket
var _http: FakeOnline.Http


func before_each() -> void:
	_client = OnlineClient.new()
	_client.use_prefs = false
	_client.server_url = "https://ejemplo.test"
	_http = FakeOnline.Http.new()
	_socket = FakeOnline.Socket.new()
	_client.http_backend = _http.call_it
	_client.socket_factory = func() -> Object: return _socket
	add_child_autofree(_client)
	_http.responses["/auth/login"] = {"status": 200, "data": {"access_token": "tok123", "user": {"id": 7, "username": "ana"}}}


func _login() -> void:
	var res: Dictionary = await _client.login("ana", "Clave-1234")
	assert_true(res["ok"])
	await wait_physics_frames(2)  # el WebSocket falso se abre al hacer poll


func test_login_guarda_sesion_y_abre_el_websocket() -> void:
	watch_signals(_client)
	await _login()
	assert_true(_client.is_logged_in())
	assert_eq(_client.my_user_id(), 7)
	assert_eq(_client.username_hint, "ana")
	assert_signal_emitted(_client, "logged_in")
	assert_eq(_socket.url, "wss://ejemplo.test/api/ws?client=game")
	assert_eq(_socket.handshake_headers, PackedStringArray(["Authorization: Bearer tok123"]))
	assert_true(_client.connected)
	assert_signal_emitted(_client, "connection_changed")
	var call: Dictionary = _http.calls[0]
	assert_eq(call["url"], "https://ejemplo.test/api/auth/login")
	assert_eq(call["body"], {"login": "ana", "password": "Clave-1234"})


func test_http_en_claro_usa_ws() -> void:
	_client.server_url = "http://localhost:8470"
	await _login()
	assert_eq(_socket.url, "ws://localhost:8470/api/ws?client=game")


func test_login_incorrecto() -> void:
	_http.responses["/auth/login"] = {"status": 401, "data": {"detail": {"code": "bad_credentials", "message": "Usuario o contraseña incorrectos."}}}
	var res: Dictionary = await _client.login("ana", "mala")
	assert_false(res["ok"])
	assert_eq(res["code"], "bad_credentials")
	assert_eq(res["message"], "Usuario o contraseña incorrectos.")
	assert_false(_client.is_logged_in())
	assert_null(_client._socket, "no se abre el WebSocket")


func test_cuenta_sin_activar() -> void:
	_http.responses["/auth/login"] = {"status": 403, "data": {"detail": {"code": "not_activated", "message": "Debes activar tu cuenta."}}}
	assert_eq((await _client.login("ana", "x"))["code"], "not_activated")


func test_errores_de_red_y_de_validacion() -> void:
	_http.responses.clear()
	var net: Dictionary = await _client.login("ana", "x")
	assert_eq(net["code"], "network")
	assert_string_contains(net["message"], "No se puede conectar")
	_http.responses["/auth/register"] = {"status": 422, "data": {"detail": [{"msg": "x"}]}}
	var val: Dictionary = await _client.register("a", "no", "corta", true)
	assert_eq(val["code"], "validation")


func test_registro() -> void:
	_http.responses["/auth/register"] = {"status": 201, "data": {"ok": true}}
	var res: Dictionary = await _client.register(" ana ", "ana@example.com", "Clave-1234", true)
	assert_true(res["ok"])
	assert_eq(_http.calls[0]["body"], {"username": "ana", "email": "ana@example.com", "password": "Clave-1234", "accept_privacy": true})
	assert_false(_client.is_logged_in(), "registrarse no inicia sesión: falta activar")


func test_usuario_duplicado() -> void:
	_http.responses["/auth/register"] = {"status": 409, "data": {"detail": {"code": "username_taken", "message": "Ese nombre de usuario ya está en uso."}}}
	var res: Dictionary = await _client.register("ana", "ana@example.com", "Clave-1234", true)
	assert_eq(res["code"], "username_taken")


func test_logout_cierra_todo() -> void:
	_http.responses["/auth/logout"] = {"status": 200, "data": {"ok": true}}
	await _login()
	watch_signals(_client)
	await _client.logout()
	assert_false(_client.is_logged_in())
	assert_false(_client.connected)
	assert_signal_emitted(_client, "logged_out")
	assert_eq(_http.calls[-1]["headers"].has("Authorization: Bearer tok123"), true, "el logout lleva el token")


func test_mensajes_de_sala() -> void:
	await _login()
	watch_signals(_client)
	_socket.receive({"t": "rooms", "rooms": [{"id": "ab", "name": "Clase", "players": 2}]})
	_socket.receive({"t": "room", "id": "ab", "name": "Clase", "players": [{"slot": 0, "user_id": 7, "username": "ana", "bot": false}]})
	await wait_physics_frames(2)
	assert_signal_emitted(_client, "rooms_updated")
	assert_signal_emitted(_client, "room_updated")
	assert_true(_client.in_room())
	assert_eq(_client.room["id"], "ab")
	_socket.receive({"t": "left"})
	await wait_physics_frames(2)
	assert_false(_client.in_room())
	assert_signal_emitted(_client, "left_room")


func test_mensajes_de_carrera() -> void:
	await _login()
	watch_signals(_client)
	_socket.receive({"t": "start", "track": "west_01", "laps": 3, "checkpoints": 27, "countdown_ms": 3000, "host_id": 7, "players": []})
	_socket.receive({"t": "go"})
	_socket.receive({"t": "states", "ms": 100, "cars": [{"s": 1, "x": 1.0, "y": 2.0}]})
	_socket.receive({"t": "finish", "slot": 1, "time_ms": 50000})
	_socket.receive({"t": "host", "user_id": 9})
	_socket.receive({"t": "results", "track": "west_01", "results": []})
	await wait_physics_frames(2)
	for s: String in ["race_started", "race_go", "race_states", "race_finish", "host_changed", "race_results"]:
		assert_signal_emitted(_client, s)
	assert_signal_emitted_with_parameters(_client, "host_changed", [9])
	assert_eq(_client.race_info["track"], "west_01")
	assert_false(_client.in_room(), "los resultados disuelven la sala")


func test_errores_del_servidor() -> void:
	await _login()
	watch_signals(_client)
	_socket.receive({"t": "error", "reason": "room_full"})
	await wait_physics_frames(2)
	assert_signal_emitted_with_parameters(_client, "server_error", ["room_full"])


func test_mensajes_basura_no_rompen_nada() -> void:
	await _login()
	_socket.inbox.append("no es json")
	_socket.inbox.append("[1,2,3]")
	_socket.inbox.append('{"t":"inventado"}')
	_socket.inbox.append('{"sin_tipo":1}')
	await wait_physics_frames(2)
	assert_true(_client.connected)


func test_los_mensajes_salientes() -> void:
	await _login()
	_client.quick_join()
	_client.create_room("  Clase 2B ")
	_client.join_room("ab12")
	_client.leave_room()
	_client.start_room()
	_client.request_rooms()
	_client.send_state(Vector2(10.5, 20), 1.5, Vector2(100, -5))
	_client.send_state(Vector2(1, 2), 0.0, Vector2.ZERO, 3)
	_client.send_checkpoint(4)
	_client.send_checkpoint(5, 2)
	var kinds: Array = _socket.sent.map(func(m: Dictionary) -> Variant: return m["t"])
	assert_eq(kinds, ["quick_join", "room_create", "room_join", "room_leave", "room_start", "rooms", "state", "state", "cp", "cp"])
	assert_eq(_socket.sent_of("room_create")[0]["name"], "Clase 2B")
	assert_eq(_socket.sent_of("room_join")[0]["id"], "ab12")
	var own: Dictionary = _socket.sent_of("state")[0]
	assert_eq([own["x"], own["y"], own["r"], own["vx"], own["vy"]], [10.5, 20.0, 1.5, 100.0, -5.0])
	assert_false(own.has("slot"))
	assert_eq(_socket.sent_of("state")[1]["slot"], 3)
	assert_false(_socket.sent_of("cp")[0].has("slot"))
	assert_eq(_socket.sent_of("cp")[1]["slot"], 2)


func test_no_se_envia_sin_conexion() -> void:
	_client.quick_join()  # sin sesión ni socket: no pasa nada
	assert_eq(_socket.sent.size(), 0)


func test_latido_cada_15_segundos() -> void:
	await _login()
	_client._ping_left = 0.01
	await wait_physics_frames(3)
	assert_eq(_socket.sent_of("ping").size(), 1)


func test_ser_expulsado_cierra_la_sesion() -> void:
	await _login()
	watch_signals(_client)
	_socket.server_closes(4002)
	await wait_physics_frames(2)
	assert_false(_client.is_logged_in())
	assert_false(_client.connected)
	assert_signal_emitted_with_parameters(_client, "kicked", ["another_session"])
	assert_signal_emitted(_client, "logged_out")


func test_caida_de_red_no_cierra_la_sesion() -> void:
	await _login()
	watch_signals(_client)
	_socket.server_closes(1006)
	await wait_physics_frames(2)
	assert_true(_client.is_logged_in(), "la sesión sigue: se puede reconectar")
	assert_false(_client.connected)
	assert_signal_not_emitted(_client, "kicked")


func test_reconectar_tras_una_caida() -> void:
	await _login()
	_socket.server_closes(1006)
	await wait_physics_frames(2)
	_socket = FakeOnline.Socket.new()
	_client.connect_socket()
	await wait_physics_frames(2)
	assert_true(_client.connected)


func test_sin_aceptar_la_politica_no_se_entra_al_online() -> void:
	_http.responses["/auth/login"] = {"status": 200, "data": {"access_token": "tok123", "user": {"id": 7, "username": "ana", "privacy_accepted": false}}}
	_http.responses["/auth/logout"] = {"status": 200, "data": {"ok": true}}
	var res: Dictionary = await _client.login("ana", "Clave-1234")
	assert_false(res["ok"])
	assert_eq(res["code"], "privacy_pending")
	assert_string_contains(res["message"], "política de privacidad")
	assert_false(_client.is_logged_in())
	assert_null(_client._socket, "no se abre el WebSocket")
	assert_eq(_http.calls[-1]["url"], "https://ejemplo.test/api/auth/logout", "se revoca la sesión en el servidor")


func test_la_politica_aceptada_deja_entrar() -> void:
	_http.responses["/auth/login"] = {"status": 200, "data": {"access_token": "tok123", "user": {"id": 7, "username": "ana", "privacy_accepted": true}}}
	assert_true((await _client.login("ana", "x"))["ok"])


func test_el_servidor_corta_si_falta_aceptar_la_politica() -> void:
	await _login()
	watch_signals(_client)
	_socket.server_closes(4007)
	await wait_physics_frames(2)
	assert_signal_emitted_with_parameters(_client, "kicked", ["privacy_pending"])
	assert_false(_client.is_logged_in())
