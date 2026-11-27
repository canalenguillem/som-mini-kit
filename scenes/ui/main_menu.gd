class_name MainMenu
extends Control
## Menú principal: jugar (hub; pide el nombre la primera vez), online, opciones, idioma y salir.

const HUB: String = "res://scenes/hub/hub.tscn"
const ONLINE_LOGIN: String = "res://scenes/ui/online_login.tscn"
const ONLINE_LOBBY: String = "res://scenes/ui/online_lobby.tscn"

@onready var _menu: VBoxContainer = $Center/Menu
@onready var _play: Button = $Center/Menu/Play
@onready var _online: Button = $Center/Menu/Online
@onready var _options: Button = $Center/Menu/Options
@onready var _quit: Button = $Center/Menu/Quit
@onready var _options_panel: OptionsPanel = $OptionsLayer/OptionsPanel
@onready var _options_layer: Control = $OptionsLayer
@onready var _name_layer: Control = $NameLayer
@onready var _name_dialog: NameDialog = $NameLayer/NameDialog


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	_online.pressed.connect(func() -> void: get_tree().change_scene_to_file(ONLINE_LOBBY if Online.is_logged_in() else ONLINE_LOGIN))
	_options.pressed.connect(_on_options_pressed)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_options_panel.closed.connect(_on_options_closed)
	_options_layer.visible = false
	_name_layer.visible = false
	_name_dialog.confirmed.connect(func(_n: String) -> void: _go_to_hub())
	_name_dialog.cancelled.connect(_on_name_cancelled)
	Music.play_menu()
	_play.grab_focus()


## La primera vez pide el nombre: sale en los informes que se entregan al profesor.
func _on_play_pressed() -> void:
	if GameState.student_name.is_empty():
		_menu.visible = false
		_name_layer.visible = true
		_name_dialog.open()
	else:
		_go_to_hub()


func _go_to_hub() -> void:
	get_tree().change_scene_to_file(HUB)


func _on_name_cancelled() -> void:
	_name_layer.visible = false
	_menu.visible = true
	_play.grab_focus()


func _on_options_pressed() -> void:
	_menu.visible = false
	_options_layer.visible = true
	_options_panel.focus_first()


func _on_options_closed() -> void:
	_options_layer.visible = false
	_menu.visible = true
	_options.grab_focus()
