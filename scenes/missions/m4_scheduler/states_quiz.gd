class_name StatesQuiz
extends MissionContent
## Calentamiento de la misión 4: para cada situación, la transición del diagrama de estados.

var situations: Array[String] = []
var _selectors: Array[OptionButton] = []

@onready var _list: VBoxContainer = $Box/List


func _build() -> void:
	situations = ProcessStates.generate(exercise_seed)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_selectors.clear()
	for i: int in situations.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var label := Label.new()
		label.text = "%d. %s" % [i + 1, tr(situations[i])]
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 20)
		var select := OptionButton.new()
		select.custom_minimum_size = Vector2(420, 44)
		select.add_theme_font_size_override("font_size", 19)
		select.add_item("ST_CHOOSE")
		for t: String in ProcessStates.TRANSITIONS:
			select.add_item("ST_T_" + t)
		row.add_child(label)
		row.add_child(select)
		_list.add_child(row)
		_selectors.append(select)
	match phase:
		Phase.EXAMPLE:
			for i: int in situations.size():
				_selectors[i].select(ProcessStates.answer_of(situations[i]) + 1)
				_selectors[i].disabled = true
		Phase.GUIDED:
			for i: int in situations.size() / 2:
				_selectors[i].select(ProcessStates.answer_of(situations[i]) + 1)
				_selectors[i].disabled = true


func check() -> ChallengeResult:
	return ProcessStates.evaluate(situations, get_answers())


func get_answers() -> Array[int]:
	var out: Array[int] = []
	for s: OptionButton in _selectors:
		out.append(s.selected - 1)
	return out


## Para pruebas: elige respuestas en los desplegables que no estén bloqueados.
func set_answers(values: Array) -> void:
	for i: int in mini(values.size(), _selectors.size()):
		if not _selectors[i].disabled:
			_selectors[i].select(int(values[i]) + 1)


func hint_count() -> int:
	return 2


func hint(index: int) -> String:
	return tr("ST_HINT_1") if index == 0 else tr("ST_HINT_2")
