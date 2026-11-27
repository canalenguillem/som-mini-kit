class_name MainMenu
extends Control
## Menú principal: carrera rápida, campeonato, garaje, opciones y salir.

const TRACK_SELECT: String = "res://scenes/ui/track_select.tscn"
const GARAGE: String = "res://scenes/ui/garage.tscn"
const ONLINE_LOGIN: String = "res://scenes/ui/online_login.tscn"
const ONLINE_LOBBY: String = "res://scenes/ui/online_lobby.tscn"
const RACE: String = "res://scenes/race/race.tscn"

@onready var _menu: VBoxContainer = $Center/Menu
@onready var _quick: Button = $Center/Menu/Quick
@onready var _championship: Button = $Center/Menu/Championship
@onready var _online: Button = $Center/Menu/Online
@onready var _garage: Button = $Center/Menu/Garage
@onready var _options: Button = $Center/Menu/Options
@onready var _quit: Button = $Center/Menu/Quit
@onready var _options_panel: OptionsPanel = $OptionsLayer/OptionsPanel
@onready var _options_layer: Control = $OptionsLayer
@onready var _money: Label = $Money


func _ready() -> void:
	_quick.pressed.connect(func() -> void: get_tree().change_scene_to_file(TRACK_SELECT))
	_championship.pressed.connect(_on_championship_pressed)
	_online.pressed.connect(func() -> void: get_tree().change_scene_to_file(ONLINE_LOBBY if Online.is_logged_in() else ONLINE_LOGIN))
	_garage.pressed.connect(func() -> void: get_tree().change_scene_to_file(GARAGE))
	_options.pressed.connect(_on_options_pressed)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_options_panel.closed.connect(_on_options_closed)
	_options_layer.visible = false
	_championship.disabled = GameState.championships.is_empty()
	_money.text = "Monedas: %d" % GameState.money
	Music.play_menu()
	_quick.grab_focus()


func _on_championship_pressed() -> void:
	var ids: Array[String] = Catalog.sorted_ids(GameState.championships, "reward_mult")
	GameState.start_championship(GameState.championships[ids[0]])
	get_tree().change_scene_to_packed(load(RACE))


func _on_options_pressed() -> void:
	_menu.visible = false
	_options_layer.visible = true
	_options_panel.focus_first()


func _on_options_closed() -> void:
	_options_layer.visible = false
	_menu.visible = true
	_options.grab_focus()
