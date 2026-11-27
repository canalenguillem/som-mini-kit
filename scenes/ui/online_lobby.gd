class_name OnlineLobby
extends Control
## Vestíbulo online: lista de salas, entrada rápida, crear sala y sala de espera.
## La carrera arranca sola con 5 jugadores; el propietario puede empezarla antes (se completa con bots).

const RACE_SCENE: String = "res://scenes/race/online_race.tscn"
const LOGIN_SCENE: String = "res://scenes/ui/online_login.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const FONT: int = 20

const ERRORS: Dictionary = {
	"already_in_room": "Ya estás en una sala.",
	"room_not_found": "Esa sala ya no existe.",
	"room_started": "Esa carrera ya ha empezado.",
	"room_full": "La sala está llena.",
	"not_in_room": "No estás en ninguna sala.",
	"not_owner": "Solo el propietario puede empezar la carrera.",
	"connect_failed": "No se pudo abrir la conexión.",
}

var online: OnlineClient  ## se inyecta en las pruebas
var navigate: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)  ## las pruebas lo sustituyen
var _rooms: Array = []

@onready var _who: Label = $Margin/Root/Header/Who
@onready var _status: Label = $Margin/Root/Header/Status
@onready var _reconnect: Button = $Margin/Root/Header/Reconnect
@onready var _logout: Button = $Margin/Root/Header/Logout
@onready var _back: Button = $Margin/Root/Header/Back
@onready var _lobby_view: Control = $Margin/Root/LobbyView
@onready var _room_list: VBoxContainer = $Margin/Root/LobbyView/RoomsPanel/Scroll/RoomList
@onready var _quick: Button = $Margin/Root/LobbyView/Actions/Quick
@onready var _room_name: LineEdit = $Margin/Root/LobbyView/Actions/RoomName
@onready var _create: Button = $Margin/Root/LobbyView/Actions/Create
@onready var _room_view: Control = $Margin/Root/RoomView
@onready var _room_title: Label = $Margin/Root/RoomView/RoomTitle
@onready var _players: VBoxContainer = $Margin/Root/RoomView/Players
@onready var _room_hint: Label = $Margin/Root/RoomView/Hint
@onready var _start: Button = $Margin/Root/RoomView/Buttons/Start
@onready var _leave: Button = $Margin/Root/RoomView/Buttons/Leave
@onready var _message: Label = $Margin/Root/Message


func _ready() -> void:
	if online == null:
		online = Online
	Music.play_menu()
	if not online.is_logged_in():
		_go.call_deferred(LOGIN_SCENE)
		return
	_who.text = "Conectado como %s" % online.user.get("username", "?")
	online.rooms_updated.connect(_on_rooms)
	online.room_updated.connect(func(_r: Dictionary) -> void: _refresh())
	online.left_room.connect(_refresh)
	online.room_closed.connect(func() -> void: _say("Un administrador cerró la sala."); _refresh())
	online.race_started.connect(_on_race_started)
	online.server_error.connect(func(reason: String) -> void: _say(ERRORS.get(reason, "Error: %s" % reason), true))
	online.connection_changed.connect(func(_c: bool) -> void: _refresh())
	online.kicked.connect(_on_kicked)
	_quick.pressed.connect(online.quick_join)
	_create.pressed.connect(func() -> void: online.create_room(_room_name.text))
	_room_name.text_submitted.connect(func(_t: String) -> void: online.create_room(_room_name.text))
	_start.pressed.connect(online.start_room)
	_leave.pressed.connect(online.leave_room)
	_reconnect.pressed.connect(online.connect_socket)
	_logout.pressed.connect(_on_logout)
	_back.pressed.connect(func() -> void: _go(MAIN_MENU_SCENE))
	if online.connected:
		online.request_rooms()
	_refresh()


func _say(text: String, is_error: bool = false) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if is_error else Color(0.8, 0.9, 1))


func _on_rooms(rooms: Array) -> void:
	_rooms = rooms
	_refresh()


func _refresh() -> void:
	var up: bool = online.connected
	_status.text = "● en línea" if up else "● sin conexión"
	_status.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5) if up else Color(1, 0.5, 0.4))
	_reconnect.visible = not up
	var inside: bool = online.in_room()
	_lobby_view.visible = not inside
	_room_view.visible = inside
	_quick.disabled = not up
	_create.disabled = not up
	if inside:
		_show_room()
	else:
		_show_rooms()


func _show_rooms() -> void:
	for child: Node in _room_list.get_children():
		_room_list.remove_child(child)
		child.queue_free()
	for r: Dictionary in _rooms:
		var waiting: bool = str(r["state"]) == "waiting" and int(r["players"]) < int(r["max"])
		var button := Button.new()
		button.add_theme_font_size_override("font_size", FONT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s   ·   %d/%d jugadores   ·   %s" % [r["name"], int(r["players"]), int(r["max"]), _state_name(str(r["state"]))]
		button.disabled = not waiting or not online.connected
		button.pressed.connect(online.join_room.bind(str(r["id"])))
		_room_list.add_child(button)
	if _rooms.is_empty():
		var empty := Label.new()
		empty.text = "No hay salas abiertas. Entra rápido o crea la tuya."
		empty.add_theme_font_size_override("font_size", FONT)
		_room_list.add_child(empty)


func _state_name(state: String) -> String:
	return {"waiting": "esperando", "countdown": "empezando", "racing": "en carrera"}.get(state, state)


func _show_room() -> void:
	var room: Dictionary = online.room
	_room_title.text = "Sala: %s" % room.get("name", "")
	for child: Node in _players.get_children():
		_players.remove_child(child)
		child.queue_free()
	var humans: int = 0
	for p: Dictionary in room.get("players", []):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 24)
		var tag: String = ""
		if int(p["user_id"] if p.get("user_id") != null else -1) == int(room.get("owner_id", -2)):
			tag = "  (propietario)"
		if bool(p["bot"]):
			tag = "  (bot)"
		else:
			humans += 1
		label.text = "%d. %s%s" % [int(p["slot"]) + 1, p["username"], tag]
		_players.add_child(label)
	var owner: bool = int(room.get("owner_id", -2)) == online.my_user_id() or bool(online.user.get("is_admin", false))
	_start.visible = owner
	_room_hint.text = "Esperando jugadores (%d/%d). Con 5 empieza sola.%s" % [humans, int(room.get("max", 5)), "  Puedes empezar ya: los puestos libres se llenan con bots." if owner else ""]


func _on_race_started(_info: Dictionary) -> void:
	_go(RACE_SCENE)


func _on_kicked(reason: String) -> void:
	_go(LOGIN_SCENE)


func _on_logout() -> void:
	await online.logout()
	_go(LOGIN_SCENE)


func _go(path: String) -> void:
	navigate.call(path)
