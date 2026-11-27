extends SceneTree
## Demo visual del modo online contra un servidor real: inicia sesión, crea una sala, arranca con bots
## y deja correr la carrera unos segundos. Pensada para grabar capturas con --write-movie.
##
##   SOM_MINI_ADMIN_EMAIL=… SOM_MINI_ADMIN_PASSWORD=… godot --path . --write-movie out.png --fixed-fps 30 \
##     --quit-after 540 -s res://tools/online_demo.gd -- --server=http://localhost:8470

const USERNAME: String = "demo1"
const PASSWORD: String = "Demo-pass-123"

var _admin: OnlineClient
var _online: OnlineClient  ## el autoload Online (en un script -s no se puede nombrar al compilar)
var _uid: int = -1


func _initialize() -> void:
	_run()


func _show(path: String) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	root.add_child(node)
	return node


func _run() -> void:
	await process_frame
	_online = root.get_node("Online") as OnlineClient
	_online.use_prefs = false  # que la demo no deje el servidor local ni el usuario "demo1" en las preferencias reales
	var server: String = "http://localhost:8470"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			server = arg.trim_prefix("--server=")
	_online.server_url = server
	_admin = OnlineClient.new()
	_admin.use_prefs = false
	_admin.server_url = server
	root.add_child(_admin)
	await _admin.login(OS.get_environment("SOM_MINI_ADMIN_EMAIL"), OS.get_environment("SOM_MINI_ADMIN_PASSWORD"))
	await _admin.register(USERNAME, USERNAME + "@example.com", PASSWORD, true)
	var users: Dictionary = await _admin._api(HTTPClient.METHOD_GET, "/admin/users?q=" + USERNAME, {})
	_uid = int(users["data"]["items"][0]["id"])
	await _admin._api(HTTPClient.METHOD_POST, "/admin/users/%d/activate" % _uid, {})

	var login: Node = _show("res://scenes/ui/online_login.tscn")
	await create_timer(1.0).timeout
	login.queue_free()
	await _online.login(USERNAME, PASSWORD)
	var lobby: Node = _show("res://scenes/ui/online_lobby.tscn")  # sin tipo: un script -s no puede depender del autoload al compilar
	lobby.set("navigate", func(path: String) -> void:
		lobby.queue_free()
		_show(path))
	await create_timer(1.5).timeout
	_online.create_room("Clase 2B")
	await create_timer(1.5).timeout
	_online.start_room()
	await create_timer(11.0).timeout
	await _end()


func _end() -> void:
	await _online.logout()
	await _admin._api(HTTPClient.METHOD_DELETE, "/admin/users/%d" % _uid, {})
	await _admin.logout()
	quit(0)
