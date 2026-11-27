class_name Garage
extends Control
## Garaje: elegir y comprar coches, comprar mejoras, desbloquear pistas y salir a correr.
## Solo presenta y llama a GameState; la lógica de economía vive allí.

const RACE_SCENE: String = "res://scenes/race/race.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const FONT_SIZE: int = 20
## Estadísticas que se muestran como barras: [título, propiedad de CarStats]
const STATS: Array = [["Velocidad", "max_speed"], ["Aceleración", "acceleration"], ["Agarre", "grip"], ["Nitro", "nitro_charges"]]

var _view_id: String = ""  ## coche que se está mirando (no tiene por qué ser el seleccionado)
var _track_id: String = ""
var _ref: Dictionary = {}  ## propiedad → valor de referencia (el máximo posible entre todos los coches)

@onready var _back: Button = $Margin/Root/Header/Back
@onready var _money: Label = $Margin/Root/Header/Money
@onready var _car_list: VBoxContainer = $Margin/Root/Body/CarsPanel/CarList
@onready var _preview: Control = $Margin/Root/Body/MidPanel/Preview
@onready var _car_body: Polygon2D = $Margin/Root/Body/MidPanel/Preview/CarBody
@onready var _car_nose: Polygon2D = $Margin/Root/Body/MidPanel/Preview/CarNose
@onready var _car_sprite: Sprite2D = $Margin/Root/Body/MidPanel/Preview/CarSprite
@onready var _car_name: Label = $Margin/Root/Body/MidPanel/CarName
@onready var _car_desc: Label = $Margin/Root/Body/MidPanel/CarDesc
@onready var _car_action: Button = $Margin/Root/Body/MidPanel/CarAction
@onready var _stats: VBoxContainer = $Margin/Root/Body/MidPanel/Stats
@onready var _upgrade_list: VBoxContainer = $Margin/Root/Body/UpgradesPanel/UpgradeList
@onready var _track_option: OptionButton = $Margin/Root/Footer/TrackOption
@onready var _best_time: Label = $Margin/Root/Footer/BestTime
@onready var _race_button: Button = $Margin/Root/Footer/RaceButton
@onready var _unlock_list: HBoxContainer = $Margin/Root/UnlockList


func _ready() -> void:
	Music.play_menu()
	_view_id = GameState.selected_car
	_track_id = GameState.current_track.id if GameState.current_track != null else ""
	_compute_reference()
	_preview.resized.connect(_center_preview)
	_back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	_car_action.pressed.connect(_on_car_action)
	_track_option.item_selected.connect(_on_track_selected)
	_race_button.pressed.connect(_on_race_pressed)
	GameState.changed.connect(_refresh)
	_refresh()
	_center_preview()


func _center_preview() -> void:
	for node: Node in _preview.get_children():
		(node as Node2D).position = _preview.size / 2.0


## Valor máximo de cada stat entre todos los coches con todas las mejoras: escala de las barras.
func _compute_reference() -> void:
	var all_max: Dictionary = {}
	for id: String in GameState.upgrade_defs:
		all_max[id] = (GameState.upgrade_defs[id] as UpgradeDef).max_level
	for entry: Array in STATS:
		var prop: String = entry[1]
		var best: float = 1.0
		for car_id: String in GameState.cars:
			var s: CarStats = CarStats.build(GameState.cars[car_id], all_max, GameState.upgrade_defs)
			best = maxf(best, float(s.get(prop)))
		_ref[prop] = best


func _refresh() -> void:
	_money.text = "Monedas: %d" % GameState.money
	_refresh_cars()
	_refresh_car_detail()
	_refresh_upgrades()
	_refresh_tracks()


func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _refresh_cars() -> void:
	_clear(_car_list)
	for id: String in Catalog.sorted_ids(GameState.cars, "price"):
		var car: CarData = GameState.cars[id]
		var status: String
		if id == GameState.selected_car:
			status = "SELECCIONADO"
		elif GameState.owned_cars.has(id):
			status = "En propiedad"
		else:
			status = "%d monedas" % car.price
		var button := Button.new()
		button.text = "%s%s\n%s" % ["▶ " if id == _view_id else "", car.display_name, status]
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.pressed.connect(_on_car_clicked.bind(id))
		_car_list.add_child(button)


func _refresh_car_detail() -> void:
	var car: CarData = GameState.cars[_view_id]
	_car_body.color = car.color
	_car_sprite.texture = car.sprite
	_car_sprite.visible = car.sprite != null
	_car_body.visible = car.sprite == null
	_car_nose.visible = car.sprite == null
	_car_name.text = car.display_name
	_car_desc.text = car.description
	if GameState.owned_cars.has(_view_id):
		_car_action.text = "Seleccionar" if _view_id != GameState.selected_car else "Seleccionado"
		_car_action.disabled = _view_id == GameState.selected_car
	else:
		_car_action.text = "Comprar (%d)" % car.price
		_car_action.disabled = car.price > GameState.money
	_clear(_stats)
	var stats: CarStats = CarStats.build(car, GameState.car_levels(_view_id), GameState.upgrade_defs)
	for entry: Array in STATS:
		var prop: String = entry[1]
		var value: float = float(stats.get(prop))
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = entry[0]
		name_label.custom_minimum_size = Vector2(130, 0)
		name_label.add_theme_font_size_override("font_size", FONT_SIZE)
		var bar := ProgressBar.new()
		bar.max_value = _ref[prop]
		bar.value = value
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 22)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := Label.new()
		value_label.text = str(roundi(value))
		value_label.custom_minimum_size = Vector2(60, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", FONT_SIZE)
		row.add_child(name_label)
		row.add_child(bar)
		row.add_child(value_label)
		_stats.add_child(row)


func _refresh_upgrades() -> void:
	_clear(_upgrade_list)
	var owned: bool = GameState.owned_cars.has(_view_id)
	for id: String in Catalog.sorted_ids(GameState.upgrade_defs, "base_cost"):
		var def: UpgradeDef = GameState.upgrade_defs[id]
		var level: int = GameState.upgrade_level(_view_id, id)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s  %s" % [def.display_name, _pips(level, def.max_level)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		var cost: int = GameState.upgrade_cost(_view_id, id)
		if cost < 0:
			button.text = "MÁX"
			button.disabled = true
		else:
			button.text = "Mejorar (%d)" % cost
			button.disabled = not owned or cost > GameState.money
		button.pressed.connect(_on_upgrade_pressed.bind(id))
		row.add_child(label)
		row.add_child(button)
		_upgrade_list.add_child(row)
	if not owned:
		var hint := Label.new()
		hint.text = "Compra el coche para mejorarlo."
		hint.add_theme_font_size_override("font_size", 16)
		_upgrade_list.add_child(hint)


func _pips(level: int, max_level: int) -> String:
	return "●".repeat(level) + "○".repeat(max_level - level)


func _refresh_tracks() -> void:
	_track_option.clear()
	_clear(_unlock_list)
	var unlocked: Array[String] = []
	for id: String in Catalog.sorted_ids(GameState.tracks, "unlock_cost"):
		var track: TrackData = GameState.tracks[id]
		if GameState.is_track_unlocked(id):
			unlocked.append(id)
			_track_option.add_item(track.display_name)
			_track_option.set_item_metadata(_track_option.item_count - 1, id)
		else:
			var button := Button.new()
			button.text = "Desbloquear %s (%d)" % [track.display_name, track.unlock_cost]
			button.disabled = track.unlock_cost > GameState.money
			button.add_theme_font_size_override("font_size", 18)
			button.pressed.connect(_on_unlock_pressed.bind(id))
			_unlock_list.add_child(button)
	if not unlocked.has(_track_id):
		_track_id = unlocked[0] if not unlocked.is_empty() else ""
	for i: int in _track_option.item_count:
		if _track_option.get_item_metadata(i) == _track_id:
			_track_option.select(i)
	_race_button.disabled = _track_id.is_empty()
	if GameState.best_times.has(_track_id):
		_best_time.text = "Récord: %s" % RaceTime.format(float(GameState.best_times[_track_id]))
	else:
		_best_time.text = ""


# --- Acciones ---

func _on_car_clicked(id: String) -> void:
	_view_id = id
	_refresh()


func _on_car_action() -> void:
	if GameState.owned_cars.has(_view_id):
		GameState.select_car(_view_id)
	elif GameState.buy_car(_view_id):
		GameState.select_car(_view_id)


func _on_upgrade_pressed(upgrade_id: String) -> void:
	GameState.buy_upgrade(_view_id, upgrade_id)


func _on_unlock_pressed(track_id: String) -> void:
	GameState.unlock_track(track_id)


func _on_track_selected(index: int) -> void:
	_track_id = str(_track_option.get_item_metadata(index))
	_refresh_tracks()


func _on_race_pressed() -> void:
	GameState.start_quick_race(GameState.tracks[_track_id])
	get_tree().change_scene_to_packed(load(RACE_SCENE))
