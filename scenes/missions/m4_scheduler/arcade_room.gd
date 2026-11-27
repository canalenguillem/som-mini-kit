class_name ArcadeRoom
extends MissionContent
## Misión 4 como sala recreativa. La CPU es la máquina; los procesos, jugadores con fichas (ciclos de
## CPU). Cuando el algoritmo tiene que elegir, la partida se para y el alumno toca al jugador que
## entra. Los demás ciclos pasan solos. La cuadrícula del libro se dibuja abajo. Al acabar, se
## calculan el Servicio y la Espera de cada jugador y la espera media.

const PATIENCE_CYCLES: float = 6.0  ## ciclos de cola que vacían la barra de paciencia
const TABLE_FIELDS: Array[String] = ["service", "wait"]

@export var step_interval: float = 0.45  ## segundos por ciclo cuando no hay nada que decidir
@export var example_pause: float = 1.6  ## en el ejemplo, pausa en cada decisión para leerla

var algorithm: Scheduler.Algorithm = Scheduler.Algorithm.FIFO
var with_io: bool = false
var exercise: Dictionary = {}
var solution: Schedule
var cycle: int = 1  ## ciclo que se está jugando (1..n); n + 1 = partida acabada
var waiting_decision: bool = false
var picks: Dictionary = {}  ## ciclo → primer jugador elegido
var round_over: bool = false

var _decisions: Array[int] = []
var _resolved: Dictionary = {}  ## ciclos de decisión ya resueltos (se puede seguir jugando)
var _run_id: int = 0  ## invalida los temporizadores de una fase anterior
var _inputs: Array[Dictionary] = []
var _mean_wait: LineEdit

@onready var _task: Label = $Box/Task
@onready var _stage: HBoxContainer = $Box/Stage
@onready var _entrance: VBoxContainer = $Box/Stage/Entrance/List
@onready var _queue: VBoxContainer = $Box/Stage/Queue/List
@onready var _machine_slot: VBoxContainer = $Box/Stage/Machine/Box/Slot
@onready var _clock: Label = $Box/Stage/Machine/Box/Clock
@onready var _quantum: Label = $Box/Stage/Machine/Box/Quantum
@onready var _snack_col: VBoxContainer = $Box/Stage/Snack
@onready var _snack: VBoxContainer = $Box/Stage/Snack/List
@onready var _done: VBoxContainer = $Box/Stage/Done/List
@onready var _grid: GanttGrid = $Box/Grid
@onready var _table: GridContainer = $Box/Table


func configure(params: Dictionary) -> void:
	algorithm = maxi(Scheduler.ALGORITHM_NAMES.find(str(params.get("algorithm", "FIFO"))), 0) as Scheduler.Algorithm
	with_io = bool(params.get("io", false))


func _build() -> void:
	_run_id += 1
	exercise = GanttExercise.generate(exercise_seed, {"algorithm": algorithm, "io": with_io})
	solution = GanttExercise.solve(exercise)
	_decisions = solution.decision_cycles()
	picks.clear()
	_resolved.clear()
	cycle = 1
	round_over = false
	waiting_decision = false
	var key: String = "GANTT_TASK_" + Scheduler.ALGORITHM_NAMES[algorithm] + ("_IO" if with_io else "")
	_task.text = tr(key).format({"q": exercise["quantum"]})
	_snack_col.visible = with_io
	_quantum.visible = algorithm == Scheduler.Algorithm.RR
	var bursts: Array = []
	var arrivals: PackedInt32Array = []
	for p: Dictionary in exercise["processes"]:
		bursts.append(p["bursts"])
		arrivals.append(int(p["arrival"]))
	_grid.cell_size = Vector2(28, 22)
	_grid.label_width = 30.0
	_grid.header_height = 20.0
	_grid.font_size = 14
	_grid.setup(solution.names, arrivals, bursts, solution.cycles())
	_grid.editable = false
	_grid.set_grid(solution.timeline, true)
	_grid.revealed = 0
	_stage.visible = true
	_table.visible = false
	_build_table()
	check_enabled.emit(phase == Phase.EXAMPLE)
	_advance(_run_id)


func check() -> ChallengeResult:
	return ArcadeRound.evaluate(exercise, get_answer())


func get_answer() -> Dictionary:
	var table: Array = []
	for row: Dictionary in _inputs:
		table.append({"service": (row["service"] as LineEdit).text, "wait": (row["wait"] as LineEdit).text})
	return {"picks": picks.duplicate(), "table": table, "mean_wait": _mean_wait.text if _mean_wait != null else ""}


func hint_count() -> int:
	return 3


func hint(index: int) -> String:
	match index:
		0:
			return tr("GANTT_HINT_RULE_" + Scheduler.ALGORITHM_NAMES[algorithm]).format({"q": exercise["quantum"]})
		1:
			if not round_over:
				return tr("ARCADE_HINT_" + Scheduler.ALGORITHM_NAMES[algorithm])
	return tr("GANTT_HINT_FORMULAS")


## El alumno toca a un jugador.
func pick(player: int) -> void:
	if not waiting_decision:
		return
	if not picks.has(cycle):
		picks[cycle] = player
	var msgs: Array[Dictionary] = ArcadeRound.decide(solution, cycle, player)
	if msgs.is_empty():
		feedback.emit(tr("ARCADE_OK").format({"player": _label_of(player)}))
		_resume()
		return
	var text: String = "[color=#f0a050]%s[/color]" % tr("ARCADE_WRONG")
	for m: Dictionary in msgs:
		text += "\n• " + ChallengeResult.message_of(m)
	if phase == Phase.SOLO:
		text += "\n" + tr("ARCADE_PLAYS_ANYWAY").format({"player": _label_of(solution.timeline[cycle - 1])})
		feedback.emit(text)
		_resume()
	else:
		feedback.emit(text + "\n" + tr("ARCADE_TRY_AGAIN"))


## Para pruebas: juega toda la partida eligiendo `chooser.call(ciclo)` en cada decisión.
func play_all(chooser: Callable) -> void:
	step_interval = 0.0
	example_pause = 0.0
	while not round_over:
		if waiting_decision:
			pick(int(chooser.call(cycle)))
		else:
			_step()


func set_table(values: Dictionary) -> void:
	var table: Array = values.get("table", [])
	for i: int in mini(table.size(), _inputs.size()):
		for f: String in TABLE_FIELDS:
			var edit: LineEdit = _inputs[i][f]
			if edit.editable:
				edit.text = str(table[i][f])
	if _mean_wait.editable:
		_mean_wait.text = str(values.get("mean_wait", ""))


# --- Partida ---

func _advance(run: int) -> void:
	while run == _run_id and not round_over and not waiting_decision:
		_step()
		if waiting_decision or round_over or step_interval <= 0.0 or not is_inside_tree():
			break
		await get_tree().create_timer(step_interval).timeout


## Juega el ciclo actual (o se para si hay que decidir).
func _step() -> void:
	if cycle > solution.cycles():
		_finish_round()
		return
	if _decisions.has(cycle) and not waiting_decision and not _resolved.has(cycle):
		waiting_decision = true
		_draw_state(true)
		if phase == Phase.EXAMPLE:
			_example_decision(_run_id)
		else:
			feedback.emit(tr("ARCADE_DECIDE"))
		return
	_draw_state(false)
	_grid.revealed = cycle
	_grid.queue_redraw()
	cycle += 1


func _resume() -> void:
	_resolved[cycle] = true
	waiting_decision = false
	_step()
	_advance(_run_id)


func _example_decision(run: int) -> void:
	var who: int = solution.timeline[cycle - 1]
	var mistake: Dictionary = GanttExercise._cell_mistake(solution, cycle - 1, -1)
	feedback.emit(tr("GANTT_NARR_CYCLE").format({"cycle": cycle}) + tr(str(mistake.get("reason", ""))).format(mistake["args"]))
	if example_pause > 0.0 and is_inside_tree():
		await get_tree().create_timer(example_pause).timeout
	if run != _run_id:
		return
	picks[cycle] = who
	_resolved[cycle] = true
	waiting_decision = false
	_step()
	_advance(run)


func _finish_round() -> void:
	round_over = true
	waiting_decision = false
	_grid.revealed = -1
	_grid.queue_redraw()
	_stage.visible = false
	_table.visible = true
	if phase == Phase.EXAMPLE:
		var ans: Dictionary = ArcadeRound.solution_answer(exercise, _decimal())
		for i: int in _inputs.size():
			for f: String in TABLE_FIELDS:
				(_inputs[i][f] as LineEdit).text = str(ans["table"][i][f])
		_mean_wait.text = str(ans["mean_wait"])
		feedback.emit(tr("ARCADE_EXAMPLE_DONE"))
	else:
		feedback.emit(tr("ARCADE_ROUND_DONE"))
		check_enabled.emit(true)


# --- Dibujo del estado ---

## Estado de la sala al empezar el ciclo `cycle`. Si `deciding`, la máquina se ve libre (o con el que
## juega, en SRT) y los candidatos se pueden tocar.
func _draw_state(deciding: bool) -> void:
	_clock.text = tr("ARCADE_CYCLE").format({"cycle": cycle})
	for box: VBoxContainer in [_entrance, _queue, _machine_slot, _snack, _done]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var c: int = cycle
	var runner: int = solution.timeline[c - 1] if c <= solution.cycles() else -1
	var candidates: Array[int] = []
	if deciding:
		candidates = solution.candidates(c)
	var keep_runner: bool = deciding and solution.decided[c - 1] == 2
	var queue_order: Array[int] = []
	var victim: int = solution.victims[c - 1] if deciding else -1
	if deciding and not keep_runner:
		# Mientras se decide, el que entrará sigue en la cola, en su sitio (orden de llegada a la cola)
		queue_order = _queue_before_choice(c)
		if victim >= 0:
			# SRT: el que jugaba sigue en la máquina mientras se decide si lo expulsa el recién llegado
			queue_order.erase(victim)
	else:
		for i: int in solution.queues[c - 1]:
			queue_order.append(i)
	for i: int in solution.names.size():
		var card: Button = _card(i, c, candidates.has(i))
		if solution.arrivals[i] > c:
			_entrance.add_child(card)
		elif solution.finishes[i] > 0 and solution.finishes[i] < c:
			_done.add_child(card)
		elif solution.io_cycles[i].has(c):
			_snack.add_child(card)
		elif (i == runner and (not deciding or keep_runner)) or i == victim:
			_machine_slot.add_child(card)
	for i: int in queue_order:
		_queue.add_child(_card(i, c, candidates.has(i)))
	if algorithm == Scheduler.Algorithm.RR and runner >= 0 and not deciding:
		_quantum.text = tr("ARCADE_QUANTUM").format({"used": _turn_used(c), "q": solution.quantum})
	else:
		_quantum.text = ""


## Cola tal como estaba antes de elegir: el elegido estaba en ella. Se respeta el orden del libro
## (en SJF/SRT la cola ya va ordenada por fichas; el alumno tiene que elegir igualmente).
func _queue_before_choice(c: int) -> Array[int]:
	var out: Array[int] = []
	var chosen: int = solution.timeline[c - 1]
	var rest: Array = solution.queues[c - 1]
	if algorithm == Scheduler.Algorithm.FIFO or algorithm == Scheduler.Algorithm.RR:
		out.append(chosen)
		for i: int in rest:
			out.append(i)
	else:
		# En SJF/SRT no se regala el orden: se enseñan por orden de llegada a la sala
		var all: Array[int] = [chosen]
		for i: int in rest:
			all.append(i)
		all.sort()
		out = all
	return out


## Partidas que lleva el jugador en su turno actual (cada turno empieza cuando sale de la cola).
func _turn_used(c: int) -> int:
	var start: int = c
	while start > 1 and solution.decided[start - 1] != 1:
		start -= 1
	return c - start + 1


## Fichas que le quedan al jugador `i` al empezar el ciclo `c` (de todas sus ráfagas de CPU).
func _tokens_left(i: int, c: int) -> int:
	var used: int = 0
	for k: int in c - 1:
		if solution.timeline[k] == i:
			used += 1
	return solution.cpu_totals[i] - used


func _waited(i: int, c: int) -> int:
	var w: int = 0
	for k: int in range(solution.arrivals[i], c):
		if solution.timeline[k - 1] != i and not solution.io_cycles[i].has(k):
			w += 1
	return w


func _label_of(i: int) -> String:
	return "%s (%s)" % [ArcadeRound.PLAYER_NAMES[i], solution.names[i]]


func _card(i: int, c: int, tappable: bool) -> Button:
	var b := Button.new()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(150, 54)
	b.add_theme_font_size_override("font_size", 16)
	var tokens: int = maxi(_tokens_left(i, c), 0)
	var line2: String = "●".repeat(tokens) if tokens > 0 else "✓"
	if solution.arrivals[i] > c:
		line2 = tr("ARCADE_ARRIVES").format({"cycle": solution.arrivals[i]})
	b.text = "%s\n%s" % [_label_of(i), line2]
	b.disabled = not tappable
	b.add_theme_color_override("font_disabled_color", Color(0.92, 0.94, 0.97))
	if tappable:
		b.pressed.connect(pick.bind(i))
		b.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0.25, 0.22, 0.12)
		glow.set_border_width_all(2)
		glow.border_color = Color(0.95, 0.75, 0.2)
		glow.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", glow)
	var patience := ProgressBar.new()
	patience.show_percentage = false
	patience.custom_minimum_size = Vector2(0, 5)
	patience.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	patience.offset_top = -6
	patience.max_value = 1.0
	patience.value = clampf(1.0 - _waited(i, c) / PATIENCE_CYCLES, 0.0, 1.0)
	patience.modulate = Color(1.0 - patience.value, 0.4 + 0.5 * patience.value, 0.3)
	patience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patience.visible = solution.arrivals[i] <= c and (solution.finishes[i] == 0 or solution.finishes[i] >= c)
	b.add_child(patience)
	return b


# --- Tabla del final ---

func _build_table() -> void:
	for child: Node in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	_inputs.clear()
	var headers: Array[String] = ["ARCADE_COL_PLAYER", "COL_ARRIVAL", "COL_BURSTS" if with_io else "COL_CPU",
			"COL_START", "COL_FINISH", "COL_RESPONSE", "COL_SERVICE", "COL_WAIT"]
	_table.columns = headers.size()
	for h: String in headers:
		_table.add_child(_label(h, true))
	for i: int in solution.names.size():
		var bursts: PackedStringArray = []
		for b: Variant in (exercise["processes"][i]["bursts"] as Array):
			bursts.append(str(b))
		for text: String in [_label_of(i), str(solution.arrivals[i]), " · ".join(bursts), str(solution.starts[i]),
				str(solution.finishes[i]), str(solution.response(i))]:
			_table.add_child(_label(text, false))
		var row: Dictionary = {}
		for f: String in TABLE_FIELDS:
			var e: LineEdit = _edit()
			row[f] = e
			_table.add_child(e)
		_inputs.append(row)
	for k: int in 6:
		_table.add_child(_label("COL_MEAN" if k == 0 else "", k == 0))
	_table.add_child(Control.new())
	_mean_wait = _edit()
	_mean_wait.max_length = 9
	_mean_wait.tooltip_text = "GANTT_MEAN_TOOLTIP"
	_mean_wait.focus_exited.connect(_fraction_to_decimal.bind(_mean_wait))
	_mean_wait.text_submitted.connect(func(_t: String) -> void: _fraction_to_decimal(_mean_wait))
	_table.add_child(_mean_wait)
	if phase == Phase.GUIDED:
		var ans: Dictionary = ArcadeRound.solution_answer(exercise, _decimal())
		for f: String in TABLE_FIELDS:
			var e: LineEdit = _inputs[0][f]
			e.text = str(ans["table"][0][f])
			e.editable = false
	if phase == Phase.EXAMPLE:
		for row: Dictionary in _inputs:
			for f: String in TABLE_FIELDS:
				(row[f] as LineEdit).editable = false
		_mean_wait.editable = false


func _fraction_to_decimal(edit: LineEdit) -> void:
	if not edit.text.contains("/"):
		return
	var h: int = Scheduler.parse_hundredths(edit.text)
	if h >= 0:
		edit.text = Scheduler.format_hundredths(h, _decimal())


func _decimal() -> String:
	return "." if TranslationServer.get_locale().begins_with("en") else ","


func _label(text: String, translate: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15 if translate else 17)
	if translate:
		l.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	return l


func _edit() -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size = Vector2(70, 32)
	e.max_length = 6
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_size_override("font_size", 18)
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	return e
