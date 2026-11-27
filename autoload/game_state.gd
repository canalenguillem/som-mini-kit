extends Node
## Estado de la partida: dinero, coches, mejoras, pistas. Sin lógica de UI.
## Quien modifique algo emite `changed`; SaveSystem guarda al oírla.

signal changed

const STARTING_CAR: String = "beetle"

var money: int = 0
var owned_cars: Array[String] = []
var selected_car: String = ""
var upgrades: Dictionary = {}  ## car_id → {upgrade_id → nivel}
var unlocked_tracks: Array[String] = []
var best_times: Dictionary = {}  ## track_id → segundos
var current_track: TrackData  ## pista elegida para la próxima carrera
var last_prize: int = 0  ## premio de la última carrera (para la pantalla de resultados)
var last_record: bool = false  ## la última carrera batió el mejor tiempo de la pista
var last_championship_prize: int = 0  ## premio final si la última carrera cerró un campeonato
var current_championship: Championship  ## campeonato en curso (null en carrera rápida; no se guarda)
var master_volume: float = 1.0:  ## 0..1; se aplica al bus Master
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volume()

var cars: Dictionary = {}  ## id → CarData
var upgrade_defs: Dictionary = {}  ## id → UpgradeDef
var tracks: Dictionary = {}  ## id → TrackData
var championships: Dictionary = {}  ## id → ChampionshipData


func _ready() -> void:
	load_catalog()
	reset()
	Events.race_finished.connect(_on_race_finished)


func load_catalog() -> void:
	cars = Catalog.cars()
	upgrade_defs = Catalog.upgrades()
	tracks = Catalog.tracks()
	championships = Catalog.championships()


## Partida nueva: sin dinero, con el coche inicial y las pistas gratuitas.
func reset() -> void:
	money = 0
	owned_cars = [STARTING_CAR]
	selected_car = STARTING_CAR
	upgrades = {}
	best_times = {}
	last_prize = 0
	last_record = false
	last_championship_prize = 0
	current_championship = null
	master_volume = 1.0
	unlocked_tracks = []
	for id: String in tracks:
		if (tracks[id] as TrackData).unlock_cost <= 0:
			unlocked_tracks.append(id)


# --- Dinero ---

func add_money(amount: int) -> void:
	money += amount
	Events.money_changed.emit(money)


## Gasta si hay saldo suficiente. Devuelve si se pudo.
func spend(amount: int) -> bool:
	if amount < 0 or amount > money:
		return false
	money -= amount
	Events.money_changed.emit(money)
	return true


# --- Coches ---

func selected_car_data() -> CarData:
	return cars.get(selected_car) as CarData


func buy_car(id: String) -> bool:
	if not cars.has(id) or owned_cars.has(id):
		return false
	if not spend((cars[id] as CarData).price):
		return false
	owned_cars.append(id)
	changed.emit()
	return true


func select_car(id: String) -> bool:
	if not owned_cars.has(id):
		return false
	selected_car = id
	changed.emit()
	return true


# --- Mejoras ---

func upgrade_level(car_id: String, upgrade_id: String) -> int:
	return int((upgrades.get(car_id, {}) as Dictionary).get(upgrade_id, 0))


func car_levels(car_id: String) -> Dictionary:
	return (upgrades.get(car_id, {}) as Dictionary).duplicate()


## Coste del siguiente nivel; -1 si ya está al máximo o no existe.
func upgrade_cost(car_id: String, upgrade_id: String) -> int:
	var def: UpgradeDef = upgrade_defs.get(upgrade_id) as UpgradeDef
	if def == null:
		return -1
	var level: int = upgrade_level(car_id, upgrade_id)
	return -1 if level >= def.max_level else Economy.upgrade_cost(def, level)


func buy_upgrade(car_id: String, upgrade_id: String) -> bool:
	if not owned_cars.has(car_id):
		return false
	var cost: int = upgrade_cost(car_id, upgrade_id)
	if cost < 0 or not spend(cost):
		return false
	var levels: Dictionary = upgrades.get(car_id, {})
	levels[upgrade_id] = upgrade_level(car_id, upgrade_id) + 1
	upgrades[car_id] = levels
	changed.emit()
	return true


# --- Pistas ---

func is_track_unlocked(id: String) -> bool:
	return unlocked_tracks.has(id)


func unlock_track(id: String) -> bool:
	if not tracks.has(id) or unlocked_tracks.has(id):
		return false
	if not spend((tracks[id] as TrackData).unlock_cost):
		return false
	unlocked_tracks.append(id)
	changed.emit()
	return true


# --- Opciones ---

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)


# --- Campeonato ---

## Empieza un campeonato nuevo y deja lista su primera pista.
func start_championship(data: ChampionshipData) -> void:
	current_championship = Championship.new(data)
	current_track = current_championship.current_track()


## Carrera rápida: sin campeonato en curso.
func start_quick_race(track: TrackData) -> void:
	current_championship = null
	current_track = track


# --- Carreras ---

## Aplica el resultado del jugador: premio en monedas y mejor tiempo. Devuelve el premio.
func apply_race_result(track: TrackData, position: int, time: float) -> int:
	var prize: int = Economy.prize(position, track.reward_mult) if track != null else 0
	last_prize = prize
	last_record = false
	if prize > 0:
		add_money(prize)
	if track != null and time > 0.0 and (not best_times.has(track.id) or time < float(best_times[track.id])):
		best_times[track.id] = time
		last_record = true
	changed.emit()
	return prize


func _on_race_finished(results: Array) -> void:
	for r: Dictionary in results:
		if bool(r.get("is_player", false)):
			apply_race_result(current_track, int(r["position"]), float(r["time"]))
			_update_championship(results)
			return


func _update_championship(results: Array) -> void:
	last_championship_prize = 0
	if current_championship == null:
		return
	current_championship.record_race(results)
	if current_championship.is_finished():
		last_championship_prize = Economy.championship_prize(
				current_championship.player_position(), current_championship.data.reward_mult)
		if last_championship_prize > 0:
			add_money(last_championship_prize)
		changed.emit()


# --- Guardado ---

func to_dict() -> Dictionary:
	return {
		"money": money,
		"owned_cars": owned_cars,
		"selected_car": selected_car,
		"upgrades": upgrades,
		"unlocked_tracks": unlocked_tracks,
		"best_times": best_times,
		"master_volume": master_volume,
	}


## Carga datos guardados con tolerancia: ignora lo desconocido o mal tipado y deja los valores por defecto.
func from_dict(data: Dictionary) -> void:
	reset()
	money = maxi(_as_int(data.get("money"), 0), 0)

	var owned: Array[String] = [STARTING_CAR]
	var raw_owned: Variant = data.get("owned_cars")
	if raw_owned is Array:
		for id: Variant in raw_owned:
			if id is String and cars.has(id) and not owned.has(id):
				owned.append(id)
	owned_cars = owned
	var sel: Variant = data.get("selected_car")
	selected_car = sel if sel is String and owned_cars.has(sel) else STARTING_CAR

	var raw_up: Variant = data.get("upgrades")
	if raw_up is Dictionary:
		for car_id: Variant in raw_up:
			if not (car_id is String and owned_cars.has(car_id) and raw_up[car_id] is Dictionary):
				continue
			var levels: Dictionary = {}
			for up_id: Variant in raw_up[car_id]:
				var def: UpgradeDef = upgrade_defs.get(up_id) as UpgradeDef
				if def != null:
					levels[up_id] = clampi(_as_int(raw_up[car_id][up_id], 0), 0, def.max_level)
			upgrades[car_id] = levels

	var raw_tracks: Variant = data.get("unlocked_tracks")
	if raw_tracks is Array:
		for id: Variant in raw_tracks:
			if id is String and tracks.has(id) and not unlocked_tracks.has(id):
				unlocked_tracks.append(id)

	var volume: Variant = data.get("master_volume")
	if volume is float or volume is int:
		master_volume = float(volume)

	var raw_times: Variant = data.get("best_times")
	if raw_times is Dictionary:
		for id: Variant in raw_times:
			var t: Variant = raw_times[id]
			if id is String and tracks.has(id) and (t is float or t is int) and float(t) > 0.0:
				best_times[id] = float(t)


static func _as_int(value: Variant, default: int) -> int:
	return int(value) if value is int or value is float else default
