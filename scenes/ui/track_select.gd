class_name TrackSelect
extends Control
## Selección de pista para carrera rápida: muestra récords y pistas bloqueadas.

const RACE: String = "res://scenes/race/race.tscn"
const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

@onready var _list: VBoxContainer = $Margin/Root/List
@onready var _back: Button = $Margin/Root/Header/Back
@onready var _money: Label = $Margin/Root/Header/Money


func _ready() -> void:
	Music.play_menu()
	_back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	_money.text = "Monedas: %d" % GameState.money
	var first: Button = null
	for id: String in Catalog.sorted_ids(GameState.tracks, "unlock_cost"):
		var button: Button = _make_button(GameState.tracks[id])
		_list.add_child(button)
		if first == null and not button.disabled:
			first = button
	if first != null:
		first.grab_focus()


func _make_button(track: TrackData) -> Button:
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 24)
	button.custom_minimum_size = Vector2(0, 74)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var info: String = "%s · %d vueltas · premio ×%.1f" % [_theme_name(track.theme), track.laps, track.reward_mult]
	if GameState.is_track_unlocked(track.id):
		var record: String = "Récord: %s" % RaceTime.format(float(GameState.best_times[track.id])) \
				if GameState.best_times.has(track.id) else "Sin récord"
		button.text = "%s\n%s  ·  %s" % [track.display_name, info, record]
		button.pressed.connect(_on_track_pressed.bind(track))
	else:
		button.text = "%s  (bloqueada)\n%s  ·  Se desbloquea en el garaje por %d monedas" % [track.display_name, info, track.unlock_cost]
		button.disabled = true
	return button


func _theme_name(theme: String) -> String:
	return {"west": "Oeste", "jungle": "Jungla"}.get(theme, theme.capitalize())


func _on_track_pressed(track: TrackData) -> void:
	GameState.start_quick_race(track)
	get_tree().change_scene_to_packed(load(RACE))
