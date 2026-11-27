extends GutTest
## Pantallas online (login y vestíbulo) con un cliente falso.

const LOGIN: String = "res://scenes/ui/online_login.tscn"
const LOBBY: String = "res://scenes/ui/online_lobby.tscn"

var _client: OnlineClient
var _socket: FakeOnline.Socket
var _http: FakeOnline.Http
var _went: Array[String] = []


func before_each() -> void:
	_went.clear()
	_client = OnlineClient.new()
	_client.use_prefs = false
	_client.server_url = "https://ejemplo.test"
	_http = FakeOnline.Http.new()
	_socket = FakeOnline.Socket.new()
	_client.http_backend = _http.call_it
	_client.socket_factory = func() -> Object: return _socket
	add_child_autofree(_client)


func _login_screen() -> OnlineLogin:
	var s: OnlineLogin = (load(LOGIN) as PackedScene).instantiate() as OnlineLogin
	s.online = _client
	s.navigate = func(path: String) -> void: _went.append(path)
	add_child_autofree(s)
	return s


func _logged_in(admin: bool = false) -> void:
	_client.token = "tok"
	_client.user = {"id": 20, "username": "yo", "is_admin": admin}
	_client.connect_socket()


func _lobby_screen() -> OnlineLobby:
	_logged_in()
	return _lobby_screen_now()


func _lobby_screen_now() -> OnlineLobby:
	var s: OnlineLobby = (load(LOBBY) as PackedScene).instantiate() as OnlineLobby
	s.online = _client
	s.navigate = func(path: String) -> void: _went.append(path)
	add_child_autofree(s)
	return s


# --- Login ---

func test_login_recuerda_el_usuario_pero_no_la_contrasena() -> void:
	_client.username_hint = "ana"
	var s: OnlineLogin = _login_screen()
	await wait_physics_frames(1)
	assert_eq(s._user.text, "ana")
	assert_eq(s._password.text, "")
	assert_true(s._password.secret, "la contraseña no se ve al escribirla")
	assert_false(s._email.visible)


func test_entrar_correctamente_lleva_al_vestibulo() -> void:
	_http.responses["/auth/login"] = {"status": 200, "data": {"access_token": "t", "user": {"id": 1, "username": "ana"}}}
	var s: OnlineLogin = _login_screen()
	s._user.text = "ana"
	s._password.text = "Clave-1234"
	await s._on_submit()
	assert_eq(_went, [LOBBY])
	assert_true(_client.is_logged_in())


func test_el_servidor_escrito_se_usa() -> void:
	_http.responses["/auth/login"] = {"status": 200, "data": {"access_token": "t", "user": {"id": 1, "username": "ana"}}}
	var s: OnlineLogin = _login_screen()
	s._server.text = " http://localhost:8470/ "
	s._user.text = "ana"
	s._password.text = "x"
	await s._on_submit()
	assert_eq(_client.server_url, "http://localhost:8470")
	assert_eq(_http.calls[0]["url"], "http://localhost:8470/api/auth/login")


func test_contrasena_incorrecta_muestra_el_error() -> void:
	_http.responses["/auth/login"] = {"status": 401, "data": {"detail": {"code": "bad_credentials", "message": "Usuario o contraseña incorrectos."}}}
	var s: OnlineLogin = _login_screen()
	s._user.text = "ana"
	s._password.text = "mala"
	await s._on_submit()
	assert_eq(s._message.text, "Usuario o contraseña incorrectos.")
	assert_eq(_went.size(), 0)
	assert_false(s._resend.visible)
	assert_false(s._submit.disabled, "se puede reintentar")


func test_cuenta_sin_activar_ofrece_reenviar() -> void:
	_http.responses["/auth/login"] = {"status": 403, "data": {"detail": {"code": "not_activated", "message": "Debes activar tu cuenta."}}}
	_http.responses["/auth/resend-activation"] = {"status": 200, "data": {"ok": true}}
	var s: OnlineLogin = _login_screen()
	s._user.text = "ana@example.com"
	s._password.text = "x"
	await s._on_submit()
	assert_true(s._resend.visible)
	await s._on_resend()
	assert_eq(_http.calls[-1]["body"], {"email": "ana@example.com"})
	assert_string_contains(s._message.text, "enlace nuevo")


func test_reenviar_pide_un_correo_si_solo_hay_usuario() -> void:
	var s: OnlineLogin = _login_screen()
	s._user.text = "ana"
	await s._on_resend()
	assert_string_contains(s._message.text, "correo")
	assert_eq(_http.calls.size(), 0)


func test_registro() -> void:
	_http.responses["/auth/register"] = {"status": 201, "data": {"ok": true}}
	var s: OnlineLogin = _login_screen()
	s._switch.pressed.emit()
	assert_true(s._email.visible and s._password2.visible)
	assert_false(s._forgot.visible)
	s._user.text = "ana"
	s._email.text = "ana@example.com"
	s._password.text = "Clave-1234"
	s._password2.text = "Clave-1234"
	s._privacy.button_pressed = true
	await s._on_submit()
	assert_eq(_http.calls[0]["body"], {"username": "ana", "email": "ana@example.com", "password": "Clave-1234", "accept_privacy": true})
	assert_string_contains(s._message.text, "correo")
	assert_false(s._email.visible, "vuelve al modo entrar")
	assert_eq(_went.size(), 0, "registrarse no inicia sesión")


func test_registro_con_contrasenas_distintas() -> void:
	var s: OnlineLogin = _login_screen()
	s._switch.pressed.emit()
	s._privacy.button_pressed = true
	s._password.text = "Clave-1234"
	s._password2.text = "otra-clave-9"
	await s._on_submit()
	assert_string_contains(s._message.text, "no coinciden")
	assert_eq(_http.calls.size(), 0)


func test_registro_con_usuario_repetido() -> void:
	_http.responses["/auth/register"] = {"status": 409, "data": {"detail": {"code": "username_taken", "message": "Ese nombre de usuario ya está en uso."}}}
	var s: OnlineLogin = _login_screen()
	s._switch.pressed.emit()
	s._user.text = "ana"
	s._email.text = "a@example.com"
	s._password.text = "Clave-1234"
	s._password2.text = "Clave-1234"
	s._privacy.button_pressed = true
	await s._on_submit()
	assert_eq(s._message.text, "Ese nombre de usuario ya está en uso.")
	assert_true(s._email.visible, "sigue en el formulario de registro")


func test_ya_con_sesion_va_directo_al_vestibulo() -> void:
	_logged_in()
	_login_screen()
	await wait_physics_frames(2)
	assert_eq(_went, [LOBBY])


func test_sin_servidor_se_avisa() -> void:
	var s: OnlineLogin = _login_screen()
	s._user.text = "ana"
	s._password.text = "x"
	await s._on_submit()
	assert_string_contains(s._message.text, "No se puede conectar")


# --- Vestíbulo ---

func test_sin_sesion_el_vestibulo_manda_al_login() -> void:
	var s: OnlineLobby = _lobby_screen_now()
	await wait_physics_frames(2)
	assert_eq(_went, [LOGIN])
	assert_not_null(s)


func test_lista_de_salas() -> void:
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	assert_true(s._status.text.contains("en línea"))
	_client._dispatch({"t": "rooms", "rooms": [
		{"id": "a1", "name": "Clase 2B", "state": "waiting", "players": 2, "max": 5, "owner": "ana"},
		{"id": "b2", "name": "Llena", "state": "waiting", "players": 5, "max": 5, "owner": "x"},
		{"id": "c3", "name": "En juego", "state": "racing", "players": 3, "max": 5, "owner": "y"},
	]})
	var buttons: Array = s._room_list.get_children()
	assert_eq(buttons.size(), 3)
	assert_string_contains((buttons[0] as Button).text, "Clase 2B")
	assert_string_contains((buttons[0] as Button).text, "2/5")
	assert_false((buttons[0] as Button).disabled)
	assert_true((buttons[1] as Button).disabled, "llena")
	assert_true((buttons[2] as Button).disabled, "ya en carrera")
	_socket.sent.clear()
	(buttons[0] as Button).pressed.emit()
	assert_eq(_socket.sent_of("room_join")[0]["id"], "a1")


func test_sin_salas() -> void:
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	_client._dispatch({"t": "rooms", "rooms": []})
	assert_string_contains((s._room_list.get_child(0) as Label).text, "No hay salas")


func test_entrar_rapido_y_crear_sala() -> void:
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	_socket.sent.clear()
	s._quick.pressed.emit()
	s._room_name.text = "Mi sala"
	s._create.pressed.emit()
	assert_eq(_socket.sent_of("quick_join").size(), 1)
	assert_eq(_socket.sent_of("room_create")[0]["name"], "Mi sala")


func test_sala_de_espera() -> void:
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	_client._dispatch({"t": "room", "id": "a1", "name": "Clase 2B", "state": "waiting", "owner_id": 20, "max": 5, "players": [
		{"slot": 0, "user_id": 20, "username": "yo", "bot": false},
		{"slot": 1, "user_id": 31, "username": "beto", "bot": false},
	]})
	assert_true(s._room_view.visible)
	assert_false(s._lobby_view.visible)
	assert_string_contains(s._room_title.text, "Clase 2B")
	var names: Array = s._players.get_children().map(func(l: Label) -> String: return l.text)
	assert_eq(names, ["1. yo  (propietario)", "2. beto"])
	assert_true(s._start.visible, "soy el propietario")
	assert_string_contains(s._room_hint.text, "2/5")
	_socket.sent.clear()
	s._start.pressed.emit()
	s._leave.pressed.emit()
	assert_eq(_socket.sent_of("room_start").size(), 1)
	assert_eq(_socket.sent_of("room_leave").size(), 1)
	_client._dispatch({"t": "left"})
	assert_true(s._lobby_view.visible)


func test_solo_el_propietario_ve_empezar() -> void:
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	_client._dispatch({"t": "room", "id": "a1", "name": "S", "state": "waiting", "owner_id": 99, "max": 5, "players": [
		{"slot": 0, "user_id": 99, "username": "ana", "bot": false}, {"slot": 1, "user_id": 20, "username": "yo", "bot": false}]})
	assert_false(s._start.visible)


func test_el_admin_siempre_puede_empezar() -> void:
	_client.token = "tok"
	_client.user = {"id": 20, "username": "yo", "is_admin": true}
	_client.connect_socket()
	var s: OnlineLobby = _lobby_screen_now()
	await wait_physics_frames(3)
	_client._dispatch({"t": "room", "id": "a1", "name": "S", "state": "waiting", "owner_id": 99, "max": 5, "players": [
		{"slot": 0, "user_id": 99, "username": "ana", "bot": false}, {"slot": 1, "user_id": 20, "username": "yo", "bot": false}]})
	assert_true(s._start.visible)


func test_los_bots_se_marcan() -> void:
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	_client._dispatch({"t": "room", "id": "a1", "name": "S", "state": "countdown", "owner_id": 20, "max": 5, "players": [
		{"slot": 0, "user_id": 20, "username": "yo", "bot": false}, {"slot": 1, "user_id": null, "username": "Bot 2", "bot": true}]})
	var names: Array = s._players.get_children().map(func(l: Label) -> String: return l.text)
	assert_eq(names[1], "2. Bot 2  (bot)")
	assert_string_contains(s._room_hint.text, "1/5", "los bots no cuentan como jugadores")


func test_errores_en_castellano() -> void:
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	_client._dispatch({"t": "error", "reason": "room_full"})
	assert_eq(s._message.text, "La sala está llena.")
	_client._dispatch({"t": "error", "reason": "algo_raro"})
	assert_string_contains(s._message.text, "algo_raro")


func test_al_empezar_la_carrera_se_cambia_de_escena() -> void:
	_lobby_screen()
	await wait_physics_frames(3)
	_client._dispatch({"t": "start", "track": "west_01", "laps": 3, "checkpoints": 27, "countdown_ms": 3000, "host_id": 1, "players": []})
	assert_eq(_went, ["res://scenes/race/online_race.tscn"])


func test_sin_conexion_se_ofrece_reconectar() -> void:
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	_socket.server_closes(1006)
	await wait_physics_frames(3)
	assert_true(s._reconnect.visible)
	assert_true(s._quick.disabled and s._create.disabled)
	assert_true(s._status.text.contains("sin conexión"))
	_socket = FakeOnline.Socket.new()
	s._reconnect.pressed.emit()
	await wait_physics_frames(3)
	assert_false(s._reconnect.visible)
	assert_false(s._quick.disabled)


func test_sesion_cerrada_por_otro_sitio_vuelve_al_login() -> void:
	_lobby_screen()
	await wait_physics_frames(3)
	_socket.server_closes(4002)
	await wait_physics_frames(3)
	assert_eq(_went, [LOGIN])


func test_cerrar_sesion() -> void:
	_http.responses["/auth/logout"] = {"status": 200, "data": {"ok": true}}
	var s: OnlineLobby = _lobby_screen()
	await wait_physics_frames(3)
	await s._on_logout()
	assert_false(_client.is_logged_in())
	assert_eq(_went, [LOGIN])


func test_registrarse_exige_aceptar_la_politica() -> void:
	var s: OnlineLogin = _login_screen()
	s._switch.pressed.emit()
	assert_true(s._privacy.visible and s._privacy_link.visible)
	assert_false(s._privacy.button_pressed, "la casilla empieza sin marcar")
	s._user.text = "ana"
	s._email.text = "ana@example.com"
	s._password.text = "Clave-1234"
	s._password2.text = "Clave-1234"
	await s._on_submit()
	assert_string_contains(s._message.text, "política de privacidad")
	assert_eq(_http.calls.size(), 0, "sin marcarla no se envía nada")
	s._switch.pressed.emit()
	assert_false(s._privacy.visible, "en el modo entrar no se muestra")


func test_login_sin_aceptar_la_politica_explica_que_hacer() -> void:
	_http.responses["/auth/login"] = {"status": 200, "data": {"access_token": "t", "user": {"id": 1, "username": "ana", "privacy_accepted": false}}}
	_http.responses["/auth/logout"] = {"status": 200, "data": {"ok": true}}
	var s: OnlineLogin = _login_screen()
	s._user.text = "ana"
	s._password.text = "x"
	await s._on_submit()
	assert_string_contains(s._message.text, "política de privacidad")
	assert_eq(_went.size(), 0)
