class_name BinarySwitches
extends MissionContent
## Misión de prueba: 8 interruptores para escribir un número en binario.

@export var reveal_interval: float = 0.6  ## segundos entre pasos del ejemplo animado

var target: int = 0
var _buttons: Array[Button] = []

@onready var _task: Label = $Box/Task
@onready var _row: HBoxContainer = $Box/Row
@onready var _sum: Label = $Box/Sum
@onready var _steps_left: Label = $Box/Steps/Left
@onready var _steps_right: Label = $Box/Steps/Right


func _build() -> void:
	target = BinaryLock.generate(exercise_seed)
	_task.text = tr("SAMPLE_TASK").format({"target": target})
	_make_switches()
	_steps_left.text = ""
	_steps_right.text = ""
	match phase:
		Phase.EXAMPLE:
			_lock_all()
			_play_example()
		Phase.GUIDED:
			var expected: Array[bool] = BinaryLock.bits_of(target)
			for i: int in 4:
				_buttons[i].button_pressed = expected[i]
				_buttons[i].disabled = true
	_update_sum()


func check() -> ChallengeResult:
	return BinaryLock.evaluate(target, get_bits())


func hint_count() -> int:
	return 2


func hint(index: int) -> String:
	if index == 0:
		return tr("SAMPLE_HINT_1")
	var first_on: int = 0
	for s: Dictionary in BinaryLock.steps(target):
		if s["on"]:
			first_on = int(s["weight"])
			break
	return tr("SAMPLE_HINT_2").format({"weight": first_on})


func get_bits() -> Array[bool]:
	var out: Array[bool] = []
	for b: Button in _buttons:
		out.append(b.button_pressed)
	return out


## Para pruebas y para el ejemplo: pone los interruptores que no estén bloqueados.
func set_bits(bits: Array[bool]) -> void:
	for i: int in _buttons.size():
		if not _buttons[i].disabled:
			_buttons[i].button_pressed = i < bits.size() and bits[i]
	_update_sum()


func _make_switches() -> void:
	for child: Node in _row.get_children():
		child.queue_free()
	_buttons.clear()
	for w: int in BinaryLock.WEIGHTS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var weight := Label.new()
		weight.text = str(w)
		weight.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weight.add_theme_font_size_override("font_size", 26)
		var button := Button.new()
		button.toggle_mode = true
		button.text = "0"
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(96, 96)
		button.add_theme_font_size_override("font_size", 44)
		button.toggled.connect(func(on: bool) -> void:
			button.text = "1" if on else "0"
			_update_sum())
		col.add_child(weight)
		col.add_child(button)
		_row.add_child(col)
		_buttons.append(button)


func _lock_all() -> void:
	for b: Button in _buttons:
		b.disabled = true


func _play_example() -> void:
	var lines: PackedStringArray = []
	var all_steps: Array[Dictionary] = BinaryLock.steps(target)
	for i: int in all_steps.size():
		var s: Dictionary = all_steps[i]
		_buttons[i].button_pressed = s["on"]
		lines.append(tr("BIN_STEP_ON" if s["on"] else "BIN_STEP_OFF").format(s))
		_steps_left.text = "\n".join(lines.slice(0, 4))
		_steps_right.text = "\n".join(lines.slice(4))
		if is_inside_tree() and reveal_interval > 0.0:
			await get_tree().create_timer(reveal_interval).timeout
			if phase != Phase.EXAMPLE or not is_inside_tree():
				return


func _update_sum() -> void:
	_sum.text = tr("SAMPLE_SUM").format({"sum": BinaryLock.value_of(get_bits())})
