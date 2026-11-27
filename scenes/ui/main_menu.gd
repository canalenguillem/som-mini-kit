class_name MainMenu
extends Control
## Menú principal: jugar (hub), online, opciones, idioma y salir.

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


func _ready() -> void:
	_play.pressed.connect(func() -> void: get_tree().change_scene_to_file(HUB))
	_online.pressed.connect(func() -> void: get_tree().change_scene_to_file(ONLINE_LOBBY if Online.is_logged_in() else ONLINE_LOGIN))
	_options.pressed.connect(_on_options_pressed)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_options_panel.closed.connect(_on_options_closed)
	_options_layer.visible = false
	Music.play_menu()
	_play.grab_focus()


func _on_options_pressed() -> void:
	_menu.visible = false
	_options_layer.visible = true
	_options_panel.focus_first()


func _on_options_closed() -> void:
	_options_layer.visible = false
	_menu.visible = true
	_options.grab_focus()
