class_name Hub
extends Control
## Mapa de la placa base de TORRE-7. Las zonas llegan en M3; de momento abre la misión de prueba.

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const MISSION_SHELL: String = "res://scenes/mission/mission_shell.tscn"
const SAMPLE_MISSION: String = "res://data/missions/sample.tres"  ## temporal hasta M2/M3

@onready var _back: Button = $Margin/Box/Back
@onready var _sample: Button = $Margin/Box/Sample


func _ready() -> void:
	_back.pressed.connect(go_back)
	_sample.pressed.connect(func() -> void: open_mission(load(SAMPLE_MISSION) as MissionData))
	_sample.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


func open_mission(data: MissionData) -> void:
	GameState.current_mission = data
	get_tree().change_scene_to_file(MISSION_SHELL)


func go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
