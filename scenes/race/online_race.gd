class_name OnlineRace
extends RaceManager
## Carrera online: cada cliente simula su coche y recibe del servidor las posiciones de los demás
## (coches "fantasma" interpolados). El servidor pone la salida, valida los checkpoints y da el resultado.
## El anfitrión (el humano conectado con el puesto más bajo) simula además a los bots.
## Hereda del RaceManager local: HUD, posiciones, reaparición y pantalla de resultados.

const LOBBY_SCENE: String = "res://scenes/ui/online_lobby.tscn"
const SEND_INTERVAL: float = 1.0 / 15.0
const SLOT_SPRITES: Array[String] = ["beetle", "buggy", "rayo", "bruto", "despiste"]
const BOT_RIVALS: Array[String] = ["rayo", "bruto", "despiste"]

## Todos conducen el coche base sin mejoras (justo para el aula). Con true, cada uno usa el de su garaje.
@export var use_garage_car: bool = false
@export var leave_delay: float = 3.0  ## s que se muestra el aviso antes de volver al vestíbulo

var online: OnlineClient  ## se inyecta en las pruebas; por defecto, el autoload Online
var _info: Dictionary = {}
var _slot_racers: Dictionary = {}  ## puesto → Racer
var _send_left: float = 0.0
var _host_id: int = -1
var _go_received: bool = false


func _ready() -> void:
	if online == null:
		online = Online
	_info = online.race_info
	_host_id = int(_info.get("host_id", -1))
	track_data = GameState.tracks[str(_info["track"])]
	track = track_data.scene.instantiate() as Track
	add_child(track)
	move_child(track, 0)
	track.checkpoint_passed.connect(_on_checkpoint_passed)
	if int(_info.get("checkpoints", track.checkpoint_count)) != track.checkpoint_count:
		push_warning("El servidor cuenta %d checkpoints y la pista tiene %d: reexporta docs/online_tracks.json" % [int(_info["checkpoints"]), track.checkpoint_count])
	_spawn_cars()
	Music.play(track_data.music)
	_camera.target = player.car
	_countdown_left = float(_info.get("countdown_ms", 3000)) / 1000.0
	_set_locked(true)
	_pause_menu.pauses_game = false
	_pause_menu.quit_scene = LOBBY_SCENE
	_pause_menu.on_quit = online.leave_room
	online.race_go.connect(_on_net_go)
	online.race_states.connect(_on_net_states)
	online.race_finish.connect(_on_net_finish)
	online.race_results.connect(_on_net_results)
	online.host_changed.connect(_on_net_host)
	online.room_closed.connect(_on_net_lost.bind("La sala se ha cerrado."))
	online.kicked.connect(func(_reason: String) -> void: _on_net_lost("Se ha cerrado tu sesión."))
	online.connection_changed.connect(func(c: bool) -> void: _on_connection_changed(c))
	if online.race_running:  # "go" llegó mientras cargaba la escena
		_go_received = true
	_update_hud()


# --- Preparación ---

func _spawn_cars() -> void:
	var grid: Array[Transform2D] = track.start_transforms()
	for p: Dictionary in _info.get("players", []):
		var slot: int = int(p["slot"])
		var racer := Racer.new()
		racer.slot = slot
		racer.user_id = int(p["user_id"]) if p.get("user_id") != null else -1
		racer.bot = bool(p["bot"])
		racer.display_name = str(p["username"])
		racer.is_player = racer.user_id == online.my_user_id() and not racer.bot
		racer.remote = not racer.is_player and not (racer.bot and _am_host())
		racer.car = CAR_SCENE.instantiate() as Car
		if racer.bot and not racer.remote:
			_use_ai_controller(racer.car, slot)
		# Vueltas y checkpoints son los que dice el servidor (los que valida); si no coinciden con la pista, hay que reexportar online_tracks.json
		racer.tracker = LapTracker.new(int(_info.get("checkpoints", track.checkpoint_count)), int(_info.get("laps", track_data.laps)))
		racer.tracker.lap_completed.connect(_on_lap_completed.bind(racer))
		_cars_root.add_child(racer.car)
		_setup_car(racer)
		racer.car.track = track
		racer.car.teleport(grid[mini(slot, grid.size() - 1)])
		if racer.remote:
			racer.car.make_ghost()
			racer.car.set_name_tag(racer.display_name)
			(racer.car.get_node("Audio") as CarAudio).volume_offset_db = rival_engine_db
		else:
			racer.car.make_online_local()
			racer.car.reset_requested.connect(_respawn.bind(racer))
			if racer.bot:
				racer.car.set_name_tag(racer.display_name)
				(racer.car.get_node("Audio") as CarAudio).volume_offset_db = rival_engine_db
		racers.append(racer)
		_slot_racers[slot] = racer
		if racer.is_player:
			player = racer


func _setup_car(racer: Racer) -> void:
	var data: CarData = car_data
	var levels: Dictionary = {}
	if racer.is_player and use_garage_car and GameState.selected_car_data() != null:
		data = GameState.selected_car_data()
		levels = GameState.car_levels(data.id)
	racer.car.setup(data, levels, GameState.upgrade_defs)
	var sprite_name: String = SLOT_SPRITES[racer.slot % SLOT_SPRITES.size()]
	racer.car.set_sprite(load("res://assets/cars/%s.png" % sprite_name) as Texture2D)


func _use_ai_controller(car: Car, slot: int) -> void:
	var old: Node = car.get_node("Controller")
	car.remove_child(old)
	old.free()
	var ai := AIController.new()
	ai.name = "Controller"
	ai.configure(load("res://data/rivals/%s.tres" % BOT_RIVALS[slot % BOT_RIVALS.size()]) as RivalData, DIFFICULTY_SKILL[difficulty])
	car.add_child(ai)


func _am_host() -> bool:
	return _host_id == online.my_user_id()


# --- Reloj ---

func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown_left -= delta
			var count: int = maxi(ceili(_countdown_left), 1)
			if count != _last_count:
				_last_count = count
				_sounds.beep()
			_hud.set_countdown(str(count))
			if _go_received:
				_begin_race()
		State.RACING:
			race_time += delta
			if _go_text_left > 0.0:
				_go_text_left -= delta
				if _go_text_left <= 0.0:
					_hud.set_countdown("")
			for racer: Racer in racers:
				if not racer.remote and racer.finish_time < 0.0:
					_check_stuck(racer, delta)
					_check_bounds(racer)
			_send_left -= delta
			if _send_left <= 0.0:
				_send_left = SEND_INTERVAL
				_send_states()
	_update_hud()


func _begin_race() -> void:
	super._begin_race()
	for node: Node in track.get_node("Obstacles").get_children():
		if node is Train:
			(node as Train).reset_time()  # los trenes arrancan a la vez en todos los clientes


func _send_states() -> void:
	for racer: Racer in racers:
		if racer.remote or racer.finish_time >= 0.0:
			continue
		online.send_state(racer.car.global_position, racer.car.rotation, racer.car.velocity, racer.slot if racer.bot else -1)


# --- Mensajes del servidor ---

func _on_net_go() -> void:
	_go_received = true
	if state == State.COUNTDOWN:
		_begin_race()


func _on_net_states(msg: Dictionary) -> void:
	for c: Dictionary in msg.get("cars", []):
		var racer: Racer = _slot_racers.get(int(c["s"]))
		if racer == null or not racer.remote:
			continue
		racer.car.net_update(Vector2(float(c["x"]), float(c["y"])), float(c["r"]), Vector2(float(c["vx"]), float(c["vy"])))
		racer.tracker.laps = int(c["l"])
		racer.tracker.last_checkpoint = int(c["c"])


func _on_net_finish(msg: Dictionary) -> void:
	var racer: Racer = _slot_racers.get(int(msg["slot"]))
	if racer != null:
		racer.finish_time = float(msg["time_ms"]) / 1000.0  # el tiempo oficial es el del servidor


func _on_net_results(msg: Dictionary) -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	_set_locked(true)
	_hud.set_countdown("")
	_pause_menu.can_pause = false
	_sounds.finish()
	var results: Array = []
	for r: Dictionary in msg["results"]:
		var time_s: float = float(r["time_ms"]) / 1000.0 if r.get("time_ms") != null else -1.0
		results.append({
			"name": str(r["username"]), "position": int(r["position"]), "time": time_s,
			"is_player": r.get("user_id") != null and int(r["user_id"]) == online.my_user_id() and not bool(r["bot"]),
		})
	_results.show_results(results, {"online": true})
	state_changed.emit(state)


## Si el anfitrión se va, los bots que eran fantasmas pasan a simularse aquí.
func _on_net_host(user_id: int) -> void:
	_host_id = user_id
	if not _am_host():
		return
	for racer: Racer in racers:
		if racer.bot and racer.remote:
			racer.remote = false
			racer.car.ghost = false
			racer.car.make_online_local()
			_use_ai_controller(racer.car, racer.slot)
			racer.car.controller = racer.car.get_node("Controller") as CarController
			racer.car.controller.owner_car = racer.car
			racer.car.locked = racer.finish_time >= 0.0
			racer.car.reset_requested.connect(_respawn.bind(racer))


func _on_connection_changed(is_connected: bool) -> void:
	if not is_connected and state != State.FINISHED:
		_on_net_lost("Se ha perdido la conexión con el servidor.")


var _leaving: bool = false


func _on_net_lost(message: String) -> void:
	if _leaving or state == State.FINISHED:
		return
	_leaving = true
	_hud.set_countdown(message)
	await get_tree().create_timer(leave_delay).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)


# --- Reglas locales ---

func _on_checkpoint_passed(car: Car, index: int) -> void:
	if state != State.RACING:
		return
	for racer: Racer in racers:
		if racer.car == car and not racer.remote:
			if racer.tracker.passed(index):  # solo se avisa al servidor de los que cuentan
				online.send_checkpoint(index, racer.slot if racer.bot else -1)
			return


func _on_lap_completed(lap: int, racer: Racer) -> void:
	Events.lap_completed.emit(racer.car, lap)
	if racer.tracker.finished and racer.finish_time < 0.0:
		racer.finish_time = race_time
		if racer.is_player:
			racer.car.locked = true
			_hud.set_countdown("¡Meta! Esperando al resto…")


func _update_rubber_band() -> void:
	pass  # online no hay rubber banding
