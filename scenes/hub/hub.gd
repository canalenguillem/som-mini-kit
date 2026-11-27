class_name Hub
extends Control
## Mapa de la placa base de TORRE-7. En M0 está vacío; las zonas llegan en M3.

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

@onready var _back: Button = $Margin/Box/Back


func _ready() -> void:
	_back.pressed.connect(go_back)
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


func go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
