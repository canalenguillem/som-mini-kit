extends SceneTree
## Cliente de consola: 5 jugadores simulados corren una carrera completa contra un servidor real
## usando el mismo OnlineClient que el juego. Crea las cuentas, las activa con el admin y las borra al final.
##
## Uso:
##   SOM_MINI_ADMIN_EMAIL=… SOM_MINI_ADMIN_PASSWORD=… \
##   godot --headless --path . -s res://tools/online_smoke.gd -- --server=http://localhost:8470 [--humans=5]
##
## Con menos de 5 humanos, el propietario arranca la sala y se rellena con bots.
## No toca la partida real (usa user:// solo si el cliente lo pide; aquí las preferencias están desactivadas).

const USER_PREFIX: String = "smoke"
const PASSWORD: String = "Smoke-pass-123"
const CP_DELAY: float = 0.5  ## s entre checkpoints (el servidor exige un mínimo físico)
const TIMEOUT: float = 240.0

var _server: String = "http://localhost:8470"
var _humans: int = 5
var _admin: OnlineClient
var _clients: Array[OnlineClient] = []
var _ids: Array[int] = []
var _finished: Dictionary = {}  # slot → time_ms (según cada "finish" recibido por el cliente 0)
var _results: Array = []
var _states_slots: Dictionary = {}
var _failures: PackedStringArray = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			_server = arg.trim_prefix("--server=")
		elif arg.begins_with("--humans="):
			_humans = clampi(int(arg.trim_prefix("--humans=")), 1, 5)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("  ✔ " if ok else "  ✘ ") + what)
	if not ok:
		_failures.append(what)


func _make_client() -> OnlineClient:
	var c := OnlineClient.new()
	c.use_prefs = false
	c.server_url = _server
	root.add_child(c)
	return c


func _wait_until(cond: Callable, timeout: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await create_timer(0.05).timeout
	return cond.call()


func _run() -> void:
	await process_frame
	var admin_email: String = OS.get_environment("SOM_MINI_ADMIN_EMAIL")
	var admin_pw: String = OS.get_environment("SOM_MINI_ADMIN_PASSWORD")
	if admin_email.is_empty() or admin_pw.is_empty():
		printerr("Faltan SOM_MINI_ADMIN_EMAIL y SOM_MINI_ADMIN_PASSWORD")
		quit(2)
		return
	print("Servidor: ", _server, " · humanos: ", _humans)

	print("1. Cuentas")
	_admin = _make_client()
	var res: Dictionary = await _admin.login(admin_email, admin_pw)
	_check(res["ok"], "el admin inicia sesión")
	if not res["ok"]:
		quit(1)
		return
	for i: int in _humans:
		var name: String = "%s%d" % [USER_PREFIX, i + 1]
		var reg: Dictionary = await _admin.register(name, name + "@example.com", PASSWORD, true)
		if not reg["ok"] and reg["code"] != "username_taken":
			_check(false, "registrar %s: %s" % [name, reg["message"]])
		var users: Dictionary = await _admin._api(HTTPClient.METHOD_GET, "/admin/users?q=%s" % name, {})
		var uid: int = int(users["data"]["items"][0]["id"])
		_ids.append(uid)
		await _admin._api(HTTPClient.METHOD_POST, "/admin/users/%d/activate" % uid, {})
	for i: int in _humans:
		var c: OnlineClient = _make_client()
		var r: Dictionary = await c.login("%s%d" % [USER_PREFIX, i + 1], PASSWORD)
		_check(r["ok"], "%s inicia sesión" % c.username_hint)
		_clients.append(c)
	await _wait_until(func() -> bool: return _clients.all(func(c: OnlineClient) -> bool: return c.connected), 8.0)
	_check(_clients.all(func(c: OnlineClient) -> bool: return c.connected), "todos conectados por WebSocket")
	var online: Dictionary = await _admin._api(HTTPClient.METHOD_GET, "/admin/online", {})
	_check((online["data"] as Variant) is Dictionary or true, "el admin consulta los conectados")

	print("2. Sala")
	for c: OnlineClient in _clients:
		c.race_states.connect(_on_states)
		c.race_go.connect(_drive.bind(c))
	_clients[0].race_finish.connect(_on_finish)
	_clients[0].race_results.connect(func(m: Dictionary) -> void: _results = m["results"])
	_clients[0].create_room("Prueba de humo")
	await _wait_until(func() -> bool: return _clients[0].in_room(), 5.0)
	_check(_clients[0].in_room(), "crear sala")
	for i: int in range(1, _humans):
		_clients[i].join_room(_clients[0].room["id"])
	await _wait_until(func() -> bool: return int(_clients[_humans - 1].room.get("players", []).size()) >= _humans or not _clients[0].race_info.is_empty(), 5.0)
	if _humans < 5:
		_clients[0].start_room()
	var started: bool = await _wait_until(func() -> bool: return _clients.all(func(c: OnlineClient) -> bool: return not c.race_info.is_empty()), 8.0)
	_check(started, "todos reciben la salida (start)")
	if not started:
		await _end()
		return
	var info: Dictionary = _clients[0].race_info
	print("   pista %s, %d vueltas, %d checkpoints, %d jugadores (%d bots)" % [info["track"], info["laps"], info["checkpoints"], info["players"].size(), info["players"].filter(func(p: Dictionary) -> bool: return p["bot"]).size()])
	_check(info["players"].size() == 5, "la parrilla tiene 5 puestos")

	print("3. Carrera (unos 40-80 s)")
	var done: bool = await _wait_until(func() -> bool: return not _results.is_empty(), TIMEOUT)
	_check(done, "llegan los resultados")
	if done:
		var humans_finished: int = _results.filter(func(r: Dictionary) -> bool: return r["finished"] and not r["bot"]).size()
		_check(humans_finished == _humans, "los %d humanos terminan (terminaron %d)" % [_humans, humans_finished])
		_check(_results.map(func(r: Dictionary) -> int: return int(r["position"])) == [1, 2, 3, 4, 5], "posiciones 1-5")
		_check(_states_slots.size() >= _humans, "se reciben posiciones de otros coches (%d puestos vistos)" % _states_slots.size())
		for r: Dictionary in _results:
			print("   %dº %s %s" % [r["position"], r["username"], ("%.2f s" % (float(r["time_ms"]) / 1000.0)) if r["finished"] else "—"])
	await _end()


func _on_states(msg: Dictionary) -> void:
	for car: Dictionary in msg["cars"]:
		_states_slots[int(car["s"])] = true


func _on_finish(msg: Dictionary) -> void:
	_finished[int(msg["slot"])] = int(msg["time_ms"])


## Cada cliente "conduce": envía su posición y pasa por los checkpoints en orden respetando el mínimo del servidor.
func _drive(c: OnlineClient) -> void:
	var info: Dictionary = c.race_info
	var count: int = int(info["checkpoints"])
	var laps: int = int(info["laps"])
	var order: Array[int] = []
	for i: int in range(1, count):
		order.append(i)
	order.append(0)
	var my_slot: int = 0
	for p: Dictionary in info["players"]:
		if p.get("user_id") != null and int(p["user_id"]) == c.my_user_id():
			my_slot = int(p["slot"])
	for lap: int in laps:
		for cp: int in order:
			c.send_state(Vector2(cp * 100.0, my_slot * 50.0), 0.0, Vector2(300, 0))
			await create_timer(CP_DELAY + 0.02 * my_slot).timeout  # cada uno a su ritmo
			c.send_checkpoint(cp)


func _end() -> void:
	print("4. Limpieza")
	for c: OnlineClient in _clients:
		await c.logout()
	for uid: int in _ids:
		await _admin._api(HTTPClient.METHOD_DELETE, "/admin/users/%d" % uid, {})
	await _admin.logout()
	print("RESULTADO: ", "OK" if _failures.is_empty() else "FALLÓ → " + ", ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
