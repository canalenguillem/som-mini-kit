class_name OnlineClient
extends Node
## Cliente del servidor online: cuenta (HTTP) y salas/carreras (WebSocket). Sin UI.
## El autoload `Online` es una instancia; las herramientas de prueba crean más.
## Para pruebas se inyectan `http_backend` y `socket_factory`.

signal logged_in
signal logged_out
signal connection_changed(connected: bool)
signal rooms_updated(rooms: Array)
signal room_updated(room: Dictionary)
signal left_room
signal room_closed
signal race_started(info: Dictionary)
signal race_go
signal race_states(msg: Dictionary)
signal race_finish(msg: Dictionary)
signal race_results(msg: Dictionary)
signal host_changed(user_id: int)
signal server_error(reason: String)
signal kicked(reason: String)  ## el servidor cerró la sesión (otra sesión, expulsión o caducidad)

const DEFAULT_SERVER: String = "https://miniso.enguillem.es"
const PREFS_PATH: String = "user://online.json"
const PING_INTERVAL: float = 15.0
const KICK_CODES: Array[int] = [4001, 4002, 4003, 4007]

var server_url: String = DEFAULT_SERVER
var username_hint: String = ""  ## último usuario que entró (se recuerda; la contraseña nunca)
var token: String = ""
var user: Dictionary = {}
var room: Dictionary = {}  ## sala actual (último mensaje "room"); vacío si no hay
var race_info: Dictionary = {}  ## último mensaje "start"
var race_running: bool = false  ## ya llegó "go" de la carrera actual
var connected: bool = false
var use_prefs: bool = true  ## las pruebas lo desactivan para no tocar el disco

var http_backend: Callable = _http_default
var socket_factory: Callable = func() -> Object: return WebSocketPeer.new()

var _socket: Object
var _ping_left: float = PING_INTERVAL


func _ready() -> void:
	if use_prefs:
		_load_prefs()
	for arg: String in OS.get_cmdline_user_args():  # godot … -- --server=http://localhost:8470
		if arg.begins_with("--server="):
			server_url = arg.trim_prefix("--server=")


func is_logged_in() -> bool:
	return not token.is_empty()


func in_room() -> bool:
	return not room.is_empty()


func my_user_id() -> int:
	return int(user.get("id", -1))


# --- Cuenta (HTTP) ---

## {ok, code, message}. En éxito deja la sesión iniciada y abre el WebSocket.
func login(login_name: String, password: String) -> Dictionary:
	var res: Dictionary = await _api(HTTPClient.METHOD_POST, "/auth/login", {"login": login_name.strip_edges(), "password": password})
	if not res["ok"]:
		return res
	var data: Dictionary = res["data"]
	token = str(data.get("access_token", ""))
	user = data.get("user", {})
	if not bool(user.get("privacy_accepted", true)):
		# La política se acepta en la web: aquí no se puede jugar online hasta entonces
		await logout()
		return {"ok": false, "status": 403, "code": "privacy_pending", "data": {},
				"message": "Primero tienes que aceptar la política de privacidad: entra en %s con tu usuario y acéptala. Luego vuelve aquí." % server_url}
	username_hint = str(user.get("username", login_name))
	_save_prefs()
	logged_in.emit()
	connect_socket()
	return res


func register(username: String, email: String, password: String, accept_privacy: bool) -> Dictionary:
	return await _api(HTTPClient.METHOD_POST, "/auth/register", {
		"username": username.strip_edges(), "email": email.strip_edges(), "password": password, "accept_privacy": accept_privacy})


func resend_activation(email: String) -> Dictionary:
	return await _api(HTTPClient.METHOD_POST, "/auth/resend-activation", {"email": email.strip_edges()})


func logout() -> void:
	if is_logged_in():
		await _api(HTTPClient.METHOD_POST, "/auth/logout", {})
	_drop_session()


func web_url(path: String = "") -> String:
	return server_url + path


func _api(method: HTTPClient.Method, path: String, body: Dictionary) -> Dictionary:
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var raw: Dictionary = await http_backend.call(method, server_url + "/api" + path, headers, JSON.stringify(body))
	return _interpret(int(raw.get("status", 0)), raw.get("data", {}))


## Respuesta HTTP → {ok, status, code, message, data}.
func _interpret(status: int, data: Variant) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	if status >= 200 and status < 300:
		return {"ok": true, "status": status, "code": "", "message": "", "data": d}
	var code: String = "error"
	var message: String = "Ha ocurrido un error."
	if status == 0:
		code = "network"
		message = "No se puede conectar con el servidor."
	else:
		var detail: Variant = d.get("detail")
		if detail is Dictionary:
			code = str((detail as Dictionary).get("code", code))
			message = str((detail as Dictionary).get("message", message))
		elif status == 422:
			code = "validation"
			message = "Revisa los datos: usuario de 3-20 letras, números o _; contraseña de 8 o más caracteres; correo válido."
	return {"ok": false, "status": status, "code": code, "message": message, "data": d}


func _http_default(method: HTTPClient.Method, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	if req.request(url, headers, method, body) != OK:
		req.queue_free()
		return {"status": 0, "data": {}}
	var res: Array = await req.request_completed  # [result, código, cabeceras, cuerpo]
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"status": 0, "data": {}}
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return {"status": int(res[1]), "data": parsed if parsed is Dictionary else {}}


# --- WebSocket ---

func connect_socket() -> void:
	close_socket()
	var ws_url: String = server_url.replace("https://", "wss://").replace("http://", "ws://") + "/api/ws?client=game"
	_socket = socket_factory.call()
	_socket.handshake_headers = PackedStringArray(["Authorization: Bearer " + token])
	if _socket.connect_to_url(ws_url) != OK:
		_socket = null
		server_error.emit("connect_failed")


func close_socket() -> void:
	if _socket != null:
		_socket.close()
		_socket = null
	_set_connected(false)


func _set_connected(value: bool) -> void:
	if connected != value:
		connected = value
		connection_changed.emit(value)


func _process(delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_set_connected(true)
			while _socket.get_available_packet_count() > 0:
				_handle_text((_socket.get_packet() as PackedByteArray).get_string_from_utf8())
			_ping_left -= delta
			if _ping_left <= 0.0:
				_ping_left = PING_INTERVAL
				send({"t": "ping"})
		WebSocketPeer.STATE_CLOSED:
			var code: int = _socket.get_close_code()
			_socket = null
			room = {}
			_set_connected(false)
			if code in KICK_CODES:
				_drop_session()
				kicked.emit({4001: "unauthorized", 4002: "another_session", 4003: "kicked", 4007: "privacy_pending"}.get(code, "kicked"))


func send(message: Dictionary) -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(message))


func _handle_text(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:  # parse() no imprime errores del motor
		_dispatch(json.data as Dictionary)


func _dispatch(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"rooms":
			rooms_updated.emit(msg.get("rooms", []))
		"room":
			room = msg
			room_updated.emit(msg)
		"left":
			room = {}
			left_room.emit()
		"room_closed":
			room = {}
			room_closed.emit()
		"start":
			race_info = msg
			race_running = false
			race_started.emit(msg)
		"go":
			race_running = true
			race_go.emit()
		"states":
			race_states.emit(msg)
		"finish":
			race_finish.emit(msg)
		"results":
			room = {}
			race_running = false
			race_results.emit(msg)
		"host":
			host_changed.emit(int(msg.get("user_id", -1)))
		"error":
			server_error.emit(str(msg.get("reason", "")))


func _drop_session() -> void:
	close_socket()
	token = ""
	user = {}
	room = {}
	logged_out.emit()


# --- Salas y carrera ---

func request_rooms() -> void:
	send({"t": "rooms"})


func quick_join() -> void:
	send({"t": "quick_join"})


func create_room(room_name: String) -> void:
	send({"t": "room_create", "name": room_name.strip_edges()})


func join_room(room_id: String) -> void:
	send({"t": "room_join", "id": room_id})


func leave_room() -> void:
	send({"t": "room_leave"})


func start_room() -> void:
	send({"t": "room_start"})


## Posición de un coche. slot < 0 = el propio; con slot, un bot (solo el anfitrión).
func send_state(pos: Vector2, rot: float, vel: Vector2, slot: int = -1) -> void:
	var msg: Dictionary = {"t": "state", "x": pos.x, "y": pos.y, "r": rot, "vx": vel.x, "vy": vel.y}
	if slot >= 0:
		msg["slot"] = slot
	send(msg)


func send_checkpoint(index: int, slot: int = -1) -> void:
	var msg: Dictionary = {"t": "cp", "i": index}
	if slot >= 0:
		msg["slot"] = slot
	send(msg)


# --- Preferencias (servidor y último usuario; nunca la contraseña) ---

func _load_prefs() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_PATH))
	if parsed is Dictionary:
		server_url = str((parsed as Dictionary).get("server_url", server_url))
		username_hint = str((parsed as Dictionary).get("username", ""))


func _save_prefs() -> void:
	if not use_prefs:
		return
	var file: FileAccess = FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"server_url": server_url, "username": username_hint}))
