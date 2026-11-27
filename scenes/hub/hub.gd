class_name Hub
extends Control
## Mapa de la placa base de TORRE-7. Hasta M3 (mapa y progreso) es una lista de botones de misión.

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const MISSION_SHELL: String = "res://scenes/mission/mission_shell.tscn"

@export var missions: Array[MissionData] = []

@onready var _back: Button = $Margin/Box/Back
@onready var _list: VBoxContainer = $Margin/Box/Missions


func _ready() -> void:
	_back.pressed.connect(go_back)
	for data: MissionData in missions:
		var button := Button.new()
		button.text = data.title_key
		button.custom_minimum_size = Vector2(520, 52)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(open_mission.bind(data))
		_list.add_child(button)
	if _list.get_child_count() > 0:
		(_list.get_child(0) as Button).grab_focus()
	else:
		_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


func open_mission(data: MissionData) -> void:
	GameState.current_mission = data
	get_tree().change_scene_to_file(MISSION_SHELL)


func go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
