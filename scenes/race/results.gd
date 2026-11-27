class_name Results
extends CanvasLayer
## Pantalla de resultados al terminar la carrera (y clasificación si hay campeonato).

const RACE_SCENE: String = "res://scenes/race/race.tscn"
const GARAGE_SCENE: String = "res://scenes/ui/garage.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const LOBBY_SCENE: String = "res://scenes/ui/online_lobby.tscn"

var _championship: Championship

@onready var _title: Label = $Panel/Box/Title
@onready var _list: Label = $Panel/Box/List
@onready var _standings: Label = $Panel/Box/Standings
@onready var _prize: Label = $Panel/Box/Prize
@onready var _retry: Button = $Panel/Box/Buttons/Retry
@onready var _next: Button = $Panel/Box/Buttons/Next
@onready var _lobby: Button = $Panel/Box/Buttons/Lobby
@onready var _garage: Button = $Panel/Box/Buttons/Garage
@onready var _menu: Button = $Panel/Box/Buttons/Menu


func _ready() -> void:
	visible = false
	_retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
	_next.pressed.connect(_on_next_pressed)
	_lobby.pressed.connect(func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))
	_garage.pressed.connect(func() -> void: get_tree().change_scene_to_file(GARAGE_SCENE))
	_menu.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))


## results: [{name, position, time (-1 si no terminó), is_player}], ya ordenado.
## info: prize (int), record (bool), championship (Championship o null), championship_prize (int), online (bool).
func show_results(results: Array, info: Dictionary = {}) -> void:
	_championship = info.get("championship") as Championship
	var prize: int = int(info.get("prize", 0))
	var lines: PackedStringArray = []
	for r: Dictionary in results:
		var t: float = float(r["time"])
		var time_text: String = RaceTime.format(t) if t >= 0.0 else "—"
		lines.append("%dº  %s  %s" % [int(r["position"]), str(r["name"]), time_text])
	_list.text = "\n".join(lines)

	var prize_text: String = "Premio: +%d monedas" % prize if prize > 0 else "Sin premio"
	if bool(info.get("record", false)):
		prize_text += "  ·  ¡Nuevo récord!"
	_title.text = "¡Carrera terminada!"
	_standings.visible = _championship != null
	_retry.visible = _championship == null
	_next.visible = false
	if _championship != null:
		var lines2: PackedStringArray = []
		for entry: Dictionary in _championship.standings():
			lines2.append("%dº  %s  %d pts" % [entry["position"], entry["name"], entry["points"]])
		if _championship.is_finished():
			_title.text = "¡Campeonato terminado!"
			_standings.text = "Clasificación final\n" + "\n".join(lines2)
			var final_prize: int = int(info.get("championship_prize", 0))
			if final_prize > 0:
				prize_text += "\nPremio del campeonato: +%d monedas" % final_prize
		else:
			_standings.text = "Clasificación (%d/%d)\n%s" % [_championship.race_index, _championship.race_count(), "\n".join(lines2)]
			_next.visible = true
			_next.text = "Siguiente: %s" % _championship.current_track().display_name
	var online: bool = bool(info.get("online", false))
	if online:
		prize_text = "Carrera online"
		_retry.visible = false
		_next.visible = false
	_lobby.visible = online
	_garage.visible = not online
	_prize.text = prize_text
	visible = true
	(_lobby if _lobby.visible else (_next if _next.visible else _menu)).grab_focus()


func _on_next_pressed() -> void:
	GameState.current_track = _championship.current_track()
	get_tree().change_scene_to_packed(load(RACE_SCENE))
