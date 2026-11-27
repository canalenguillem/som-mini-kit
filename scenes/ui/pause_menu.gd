class_name PauseMenu
extends CanvasLayer
## Menú de pausa. Siempre procesa (process_mode ALWAYS) para poder reanudar con el juego parado.

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

var can_pause: bool = true  ## la misión lo desactiva al terminar
var pauses_game: bool = true  ## online no: los demás siguen corriendo
var quit_scene: String = MAIN_MENU
var on_quit: Callable = Callable()  ## se llama antes de abandonar (online: salir de la sala)

@onready var _menu: VBoxContainer = $Center/Menu
@onready var _resume: Button = $Center/Menu/Resume
@onready var _options: Button = $Center/Menu/Options
@onready var _quit: Button = $Center/Menu/Quit
@onready var _options_panel: OptionsPanel = $Center/OptionsPanel


func _ready() -> void:
	visible = false
	_options_panel.visible = false
	_resume.pressed.connect(close)
	_options.pressed.connect(_on_options_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_options_panel.closed.connect(_on_options_closed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	elif can_pause:
		open()


func open() -> void:
	visible = true
	_menu.visible = true
	_options_panel.visible = false
	if pauses_game:
		get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_options_pressed() -> void:
	_menu.visible = false
	_options_panel.visible = true
	_options_panel.focus_first()


func _on_options_closed() -> void:
	_options_panel.visible = false
	_menu.visible = true
	_options.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	if on_quit.is_valid():
		on_quit.call()
	get_tree().change_scene_to_file(quit_scene)
