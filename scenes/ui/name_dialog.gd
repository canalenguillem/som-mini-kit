class_name NameDialog
extends PanelContainer
## Pide el nombre del alumno (sale en los informes). Se usa al pulsar Jugar la primera vez.

signal confirmed(student_name: String)
signal cancelled

@onready var _input: LineEdit = $Box/Input
@onready var _ok: Button = $Box/Buttons/Ok
@onready var _cancel: Button = $Box/Buttons/Cancel


func _ready() -> void:
	_input.max_length = GameState.MAX_NAME_LENGTH
	_input.text_changed.connect(func(_t: String) -> void: _update_ok())
	_input.text_submitted.connect(func(_t: String) -> void: accept())
	_ok.pressed.connect(accept)
	_cancel.pressed.connect(func() -> void: cancelled.emit())
	_update_ok()


func open() -> void:
	_input.text = GameState.student_name
	_update_ok()
	_input.grab_focus()


func accept() -> void:
	var clean: String = GameState.clean_name(_input.text)
	if clean.is_empty():
		return
	GameState.set_student_name(clean)
	confirmed.emit(clean)


func _update_ok() -> void:
	_ok.disabled = GameState.clean_name(_input.text).is_empty()
