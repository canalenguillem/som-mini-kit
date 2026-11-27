class_name OptionsPanel
extends PanelContainer
## Opciones: volumen general. Se usa en el menú principal y en la pausa.

signal closed

@onready var _slider: HSlider = $Box/VolumeRow/Slider
@onready var _value: Label = $Box/VolumeRow/Value
@onready var _back: Button = $Box/Back


func _ready() -> void:
	_slider.value = GameState.master_volume
	_update_label()
	_slider.value_changed.connect(_on_volume_changed)
	_back.pressed.connect(func() -> void: closed.emit())


func focus_first() -> void:
	_slider.grab_focus()


func _on_volume_changed(value: float) -> void:
	GameState.master_volume = value
	GameState.changed.emit()  # SaveSystem guarda
	_update_label()


func _update_label() -> void:
	_value.text = "%d %%" % roundi(_slider.value * 100.0)
