class_name GanttMission
extends MissionContent
## Misión 4 (sala del planificador): cuadrícula y tabla de tiempos para un algoritmo.

const PROCESS_FIELDS: Array[String] = ["start", "finish", "response", "service", "wait"]

@export var reveal_interval: float = 0.8  ## segundos por ciclo en el ejemplo animado

var algorithm: Scheduler.Algorithm = Scheduler.Algorithm.FIFO
var with_io: bool = false
var exercise: Dictionary = {}
var solution: Schedule

var _inputs: Array[Dictionary] = []  ## por proceso: campo → LineEdit
var _mean_inputs: Dictionary = {}  ## campo → LineEdit

@onready var _task: Label = $Box/Task
@onready var _narration: Label = $Box/Narration
@onready var _grid: GanttGrid = $Box/Work/GridScroll/Grid
@onready var _table: GridContainer = $Box/Work/Table


func configure(params: Dictionary) -> void:
	var name: String = str(params.get("algorithm", "FIFO"))
	algorithm = maxi(Scheduler.ALGORITHM_NAMES.find(name), 0) as Scheduler.Algorithm
	with_io = bool(params.get("io", false))


func _build() -> void:
	exercise = GanttExercise.generate(exercise_seed, {"algorithm": algorithm, "io": with_io})
	solution = GanttExercise.solve(exercise)
	var key: String = "GANTT_TASK_" + Scheduler.ALGORITHM_NAMES[algorithm] + ("_IO" if with_io else "")
	_task.text = tr(key).format({"q": exercise["quantum"]})
	_narration.text = tr("GANTT_INSTRUCTIONS") if phase != Phase.EXAMPLE else ""
	var names: PackedStringArray = []
	var arrivals: PackedInt32Array = []
	var bursts: Array = []
	for p: Dictionary in exercise["processes"]:
		names.append(str(p["name"]))
		arrivals.append(int(p["arrival"]))
		bursts.append(p["bursts"])
	_grid.setup(names, arrivals, bursts, int(exercise["columns"]))
	_build_table()
	var answer: Dictionary = GanttExercise.solution_answer(exercise, _decimal())
	match phase:
		Phase.EXAMPLE:
			_grid.editable = false
			_grid.set_grid(answer["grid"], true)
			_set_table_editable(false)
			_play_example(answer)
		Phase.GUIDED:
			_grid.editable = true
			_grid.set_grid(answer["grid"], true, ceili(solution.cycles() / 2.0))
			_fill_row(0, answer["table"][0], true)
		Phase.SOLO:
			_grid.editable = true


func check() -> ChallengeResult:
	return GanttExercise.evaluate(exercise, get_answer())


func hint_count() -> int:
	return 3


func hint(index: int) -> String:
	match index:
		0:
			return tr("GANTT_HINT_RULE_" + Scheduler.ALGORITHM_NAMES[algorithm]).format({"q": exercise["quantum"]})
		1:
			var c: int = _first_wrong_column()
			if c < 0:
				return tr("GANTT_HINT_GRID_OK")
			if c >= solution.cycles():
				return tr("GANTT_AFTER_END").format({"cycle": c + 1})
			var queue: Array = solution.queues[c]
			if queue.is_empty() and solution.timeline[c] < 0:
				return tr("GANTT_HINT_QUEUE_EMPTY").format({"cycle": c + 1})
			# Quién quería la CPU en ese ciclo, por orden de la tabla (no por orden de la cola: eso lo decide el alumno)
			var present: Array[int] = queue.duplicate()
			if solution.timeline[c] >= 0:
				present.append(solution.timeline[c])
			present.sort()
			var waiting: PackedStringArray = []
			for i: int in present:
				waiting.append(solution.names[i])
			return tr("GANTT_HINT_QUEUE").format({"cycle": c + 1, "queue": ", ".join(waiting)})
	return tr("GANTT_HINT_FORMULAS")


## Respuesta tal como está en pantalla.
func get_answer() -> Dictionary:
	var table: Array = []
	for row: Dictionary in _inputs:
		var values: Dictionary = {}
		for f: String in PROCESS_FIELDS:
			values[f] = (row[f] as LineEdit).text
		table.append(values)
	var means: Dictionary = {}
	for f: String in _mean_inputs:
		means[f] = (_mean_inputs[f] as LineEdit).text
	return {"grid": _grid.grid.duplicate(), "table": table, "means": means}


## Para pruebas: escribe una respuesta completa en pantalla (sin tocar lo bloqueado).
func set_answer(answer: Dictionary) -> void:
	var grid: Array = answer.get("grid", [])
	for c: int in _grid.columns:
		if not _grid.locked[c]:
			_grid.grid[c] = int(grid[c]) if c < grid.size() else -1
	_grid.queue_redraw()
	var table: Array = answer.get("table", [])
	for i: int in mini(table.size(), _inputs.size()):
		_fill_row(i, table[i], false)
	var means: Dictionary = answer.get("means", {})
	for f: String in _mean_inputs:
		var edit: LineEdit = _mean_inputs[f]
		if edit.editable:
			edit.text = str(means.get(f, ""))


func _first_wrong_column() -> int:
	for c: int in _grid.columns:
		var expected: int = solution.timeline[c] if c < solution.cycles() else -1
		if _grid.grid[c] != expected:
			return c
	return -1


func _decimal() -> String:
	return "." if TranslationServer.get_locale().begins_with("en") else ","


func _build_table() -> void:
	for child: Node in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	_inputs.clear()
	_mean_inputs.clear()
	var headers: Array[String] = ["COL_PROCESS", "COL_ARRIVAL", "COL_BURSTS" if with_io else "COL_CPU",
			"COL_START", "COL_FINISH", "COL_RESPONSE", "COL_SERVICE", "COL_WAIT"]
	_table.columns = headers.size()
	for h: String in headers:
		_table.add_child(_label(h, true))
	for p: Dictionary in exercise["processes"]:
		_table.add_child(_label(str(p["name"]), false, false))
		_table.add_child(_label(str(p["arrival"]), false, false))
		var bursts: PackedStringArray = []
		for b: Variant in (p["bursts"] as Array):
			bursts.append(str(b))
		_table.add_child(_label(" · ".join(bursts), false, false))
		var row: Dictionary = {}
		for f: String in PROCESS_FIELDS:
			var edit: LineEdit = _edit()
			row[f] = edit
			_table.add_child(edit)
		_inputs.append(row)
	_table.add_child(_label("COL_MEAN", true))
	for i: int in 4:
		_table.add_child(Control.new())
	for f: String in ["response", "service", "wait"]:
		var edit: LineEdit = _edit()
		_mean_inputs[f] = edit
		_table.add_child(edit)


func _label(text: String, translate: bool, bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15 if bold else 17)
	if bold:
		l.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	return l


func _edit() -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size = Vector2(56, 30)
	e.max_length = 6
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_size_override("font_size", 17)
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	return e


func _fill_row(i: int, values: Dictionary, lock: bool, force: bool = false) -> void:
	for f: String in PROCESS_FIELDS:
		var edit: LineEdit = _inputs[i][f]
		if not edit.editable and not force:
			continue
		edit.text = str(values.get(f, ""))
		if lock:
			edit.editable = false


func _set_table_editable(value: bool) -> void:
	for row: Dictionary in _inputs:
		for f: String in PROCESS_FIELDS:
			(row[f] as LineEdit).editable = value
	for f: String in _mean_inputs:
		(_mean_inputs[f] as LineEdit).editable = value


## Ejemplo resuelto: la cuadrícula se rellena ciclo a ciclo con la cola y una frase que explica cada paso;
## al final sale la tabla.
func _play_example(answer: Dictionary) -> void:
	var queue_names: Array = []
	for c: int in solution.cycles():
		var q: Array = []
		for i: int in solution.queues[c]:
			q.append(solution.names[i])
		queue_names.append(q)
	_grid.show_queues(queue_names)
	var interval: float = reveal_interval if is_inside_tree() else 0.0
	for c: int in solution.cycles():
		_grid.revealed = c + 1
		_grid.queue_redraw()
		_narration.text = _narrate(c)
		if interval > 0.0:
			await get_tree().create_timer(interval).timeout
			if phase != Phase.EXAMPLE or not is_inside_tree():
				return
	_grid.revealed = -1
	_grid.queue_redraw()
	for i: int in _inputs.size():
		_fill_row(i, answer["table"][i], false, true)
	for f: String in _mean_inputs:
		(_mean_inputs[f] as LineEdit).text = str(answer["means"][f])
	_narration.text = tr("GANTT_NARR_DONE")


func _narrate(c: int) -> String:
	var text: String = tr("GANTT_NARR_CYCLE").format({"cycle": c + 1})
	var arrived: PackedStringArray = []
	for i: int in solution.arrived[c]:
		arrived.append(solution.names[i])
	if not arrived.is_empty():
		text += tr("GANTT_NARR_ARRIVES").format({"names": ", ".join(arrived)})
	var who: int = solution.timeline[c]
	if who < 0:
		return text + tr("GANTT_NARR_IDLE")
	var mistake: Dictionary = GanttExercise._cell_mistake(solution, c, -1)
	return text + tr(str(mistake.get("reason", ""))).format(mistake["args"])
