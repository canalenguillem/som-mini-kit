class_name ArcadeRoom
extends MissionContent
## Misión 4: el salón recreativo. El alumno hace de sistema operativo y arrastra a cada jugador entre
## la puerta, la cola, la máquina (la CPU), la barra de bocadillos (E/S) y la salida. Cada arrastre es
## una transición del diagrama de estados; DispatchRound lo valida con las reglas del libro. El ciclo
## avanza solo cuando no queda nada pendiente. La cuadrícula del libro se dibuja debajo y, al acabar,
## se calculan el Servicio y la Espera (no en el calentamiento).
##
## params: {algorithm: "FIFO"|"RR"|"SJF"|"SRT", io: bool, warmup: bool}
## En el calentamiento el juego elige quién juega y ordena la cola: solo se practican las transiciones.

const PATIENCE_CYCLES: float = 6.0

@export var step_interval: float = 0.55  ## pausa entre ciclos que pasan solos
@export var example_interval: float = 1.4  ## pausa entre movimientos del ejemplo

var algorithm: Scheduler.Algorithm = Scheduler.Algorithm.FIFO
var with_io: bool = false
var warmup: bool = false
var exercise: Dictionary = {}
var solution: Schedule
var round_state: DispatchRound
var round_over: bool = false

var _run_id: int = 0
var _inputs: Array[Dictionary] = []
var _mean_wait: LineEdit
var _first_draw: bool = true
var _ticking: bool = false

@onready var _task: Label = $Box/Task
@onready var _hall: ArcadeHall = $Box/Hall
@onready var _grid: GanttGrid = $Box/Grid
@onready var _table: GridContainer = $Box/Table


func configure(params: Dictionary) -> void:
	algorithm = maxi(Scheduler.ALGORITHM_NAMES.find(str(params.get("algorithm", "FIFO"))), 0) as Scheduler.Algorithm
	with_io = bool(params.get("io", false))
	warmup = bool(params.get("warmup", false))


func _build() -> void:
	_run_id += 1
	exercise = GanttExercise.generate(exercise_seed, {"algorithm": algorithm, "io": with_io})
	solution = GanttExercise.solve(exercise)
	round_state = DispatchRound.new(solution, not warmup)
	round_over = false
	_task.text = _task_text()
	var labels: PackedStringArray = []
	for i: int in solution.names.size():
		labels.append(_label_of(i))
	_hall.setup(labels)
	if not _hall.player_dropped.is_connected(_on_dropped):
		_hall.player_dropped.connect(_on_dropped)
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
	_hall.visible = true
	_table.visible = false
	_first_draw = true
	_build_table()
	check_enabled.emit(phase == Phase.EXAMPLE)
	if phase == Phase.GUIDED:
		# La primera mitad de la partida viene jugada
		var half: int = ceili(solution.cycles() / 2.0)
		while round_state.cycle <= half and not round_state.over:
			if round_state.waiting():
				round_state.auto_move()
			else:
				_reveal(round_state.advance())
	_draw_state()
	if phase == Phase.EXAMPLE:
		_play_example(_run_id)
	else:
		feedback.emit(tr("DISP_INTRO_WARMUP" if warmup else "DISP_INTRO"))
		_tick(_run_id)


func _task_text() -> String:
	if warmup:
		return tr("DISP_TASK_WARMUP")
	var key: String = "GANTT_TASK_" + Scheduler.ALGORITHM_NAMES[algorithm] + ("_IO" if with_io else "")
	return tr(key).format({"q": exercise["quantum"]})


func check() -> ChallengeResult:
	var r: ChallengeResult = round_state.result()
	if warmup:
		return r
	var t: ChallengeResult = ArcadeRound.evaluate_table(exercise, get_answer())
	r.total += t.total
	r.correct += t.correct
	for m: Dictionary in t.mistakes:
		r.mistakes.append(m)
	r.can_improve = t.total - t.correct > 0
	return r


func get_answer() -> Dictionary:
	var table: Array = []
	for row: Dictionary in _inputs:
		table.append({"service": (row["service"] as LineEdit).text, "wait": (row["wait"] as LineEdit).text})
	return {"table": table, "mean_wait": _mean_wait.text if _mean_wait != null else ""}


func hint_count() -> int:
	return 3


func hint(index: int) -> String:
	if index == 0 and not warmup:
		return tr("GANTT_HINT_RULE_" + Scheduler.ALGORITHM_NAMES[algorithm]).format({"q": exercise["quantum"]})
	if index <= 1 and not round_over:
		# Qué falta en este ciclo (sin decir quién elige el algoritmo)
		var parts: PackedStringArray = []
		for m: Dictionary in round_state.pending:
			var key: String = "DISP_PENDING_" + str(m.get("why", "")).to_upper()
			if str(m.get("why", "")) == "pick" or str(m.get("why", "")) == "preempt":
				key = "DISP_PENDING_PICK" if str(m.get("why", "")) == "pick" else "DISP_PENDING_PREEMPT"
				parts.append(tr(key))
			else:
				parts.append(tr(key).format({"player": _label_of(int(m["p"]))}))
		return tr("DISP_HINT_PENDING").format({"list": " · ".join(parts)}) if not parts.is_empty() else tr("DISP_HINT_NOTHING")
	return tr("ST_HINT_1") if warmup else tr("GANTT_HINT_FORMULAS")


## Movimiento del alumno (desde el salón o desde las pruebas).
func move(p: int, to: String) -> bool:
	if round_over or phase == Phase.EXAMPLE or round_state.over:
		return false
	var res: Dictionary = round_state.try_move(p, to, phase == Phase.SOLO)
	if res["ok"]:
		feedback.emit("[color=#7fe07f]✓ %s[/color]  %s" % [tr("ST_T_" + str(res["transition"])), _label_of(p)])
		_draw_state()
		_tick(_run_id)
		return true
	var text: String = "[color=#f0a050]%s[/color]" % tr("ARCADE_WRONG")
	for m: Dictionary in res["msgs"]:
		text += "\n• " + ChallengeResult.message_of(m)
	if phase == Phase.SOLO:
		text += "\n" + tr("DISP_COUNTS")
	feedback.emit(text)
	_draw_state()  # el jugador vuelve a su sitio
	return false


func _on_dropped(p: int, to: String) -> void:
	move(p, to)


## Para pruebas: juega toda la partida con los movimientos correctos (más `extra_wrong` fallos al principio).
func play_all() -> void:
	step_interval = 0.0
	while not round_over:
		if round_state.waiting():
			var m: Dictionary = round_state._next_allowed()
			move(int(m["p"]), str(m["to"]))
		else:
			_tick(_run_id)


func set_table(values: Dictionary) -> void:
	var table: Array = values.get("table", [])
	for i: int in mini(table.size(), _inputs.size()):
		for f: String in ["service", "wait"]:
			var edit: LineEdit = _inputs[i][f]
			if edit.editable:
				edit.text = str(table[i][f])
	if _mean_wait != null and _mean_wait.editable:
		_mean_wait.text = str(values.get("mean_wait", ""))


# --- Partida ---

## Pasa los ciclos que no necesitan a nadie; se para cuando hay algo pendiente.
func _tick(run: int) -> void:
	if _ticking:
		return
	_ticking = true
	while run == _run_id and not round_over:
		if round_state.waiting():
			if warmup and round_state.only_pick_left():
				# En el calentamiento, el juego elige quién juega
				if step_interval > 0.0 and is_inside_tree():
					await get_tree().create_timer(step_interval).timeout
					if run != _run_id:
						break
				var m: Dictionary = round_state.auto_move()
				feedback.emit(tr("DISP_AUTO_PICK").format({"player": _label_of(int(m["p"]))}))
				_draw_state()
				continue
			break
		if round_state.over:
			_finish_round()
			break
		_reveal(round_state.advance())
		_draw_state()
		if step_interval > 0.0 and is_inside_tree():
			await get_tree().create_timer(step_interval).timeout
	_ticking = false
	if run == _run_id and round_state.over and not round_over:
		_finish_round()


func _reveal(played: int) -> void:
	if played > 0:
		_grid.revealed = mini(played, solution.cycles())
		_grid.queue_redraw()


func _play_example(run: int) -> void:
	while run == _run_id and not round_state.over:
		if round_state.waiting():
			var m: Dictionary = round_state.auto_move()
			feedback.emit(_narrate(m))
		else:
			_reveal(round_state.advance())
		_draw_state()
		if is_inside_tree() and example_interval > 0.0:
			await get_tree().create_timer(example_interval).timeout
		elif not is_inside_tree():
			break
	if run == _run_id:
		_finish_round()


func _narrate(m: Dictionary) -> String:
	var p: int = int(m["p"])
	var text: String = tr("GANTT_NARR_CYCLE").format({"cycle": round_state.cycle})
	text += "%s: %s. " % [_label_of(p), tr("ST_T_" + str(m["transition"]))]
	if str(m["to"]) == DispatchRound.MACHINE and not warmup:
		var mistake: Dictionary = GanttExercise._cell_mistake(solution, round_state.cycle - 1, -1)
		if mistake.has("reason"):
			text += tr(str(mistake["reason"])).format(mistake["args"])
	return text


func _finish_round() -> void:
	if round_over:
		return
	round_over = true
	_grid.revealed = -1
	_grid.queue_redraw()
	_hall.machine_busy = false
	if warmup:
		feedback.emit(tr("DISP_WARMUP_DONE"))
		if phase != Phase.EXAMPLE:
			check_enabled.emit(true)
		return
	_hall.visible = false
	_table.visible = true
	if phase == Phase.EXAMPLE:
		var ans: Dictionary = ArcadeRound.solution_answer(exercise, _decimal())
		for i: int in _inputs.size():
			for f: String in ["service", "wait"]:
				(_inputs[i][f] as LineEdit).text = str(ans["table"][i][f])
		_mean_wait.text = str(ans["mean_wait"])
		feedback.emit(tr("ARCADE_EXAMPLE_DONE"))
	else:
		feedback.emit(tr("ARCADE_ROUND_DONE"))
		check_enabled.emit(true)


# --- Dibujo ---

const BUBBLES: Dictionary = {"arrive": "EVT_ARRIVE", "finish": "EVT_FINISH", "io": "EVT_IO",
		"quantum": "EVT_QUANTUM", "io_done": "EVT_IO_DONE"}


func _draw_state() -> void:
	var d: DispatchRound = round_state
	var state: Array = []
	var counters: Dictionary = {"door": 0, "snack": 0, "exit": 0}
	var student_turn: bool = phase != Phase.EXAMPLE and not round_over
	for i: int in solution.names.size():
		var z: String = d.zone[i]
		var slot: int = 0
		if z == DispatchRound.QUEUE:
			slot = d.queue.find(i)
		elif counters.has(z):
			slot = int(counters[z])
			counters[z] = slot + 1
		var bubble_key: String = BUBBLES.get(d.event_of(i), "")
		state.append({"zone": z, "slot": maxi(slot, 0), "tokens": maxi(d.tokens_left(i), 0),
				"patience": clampf(1.0 - d.waited(i) / PATIENCE_CYCLES, 0.0, 1.0),
				"dimmed": z == DispatchRound.DOOR and not d.arrived(i),
				"draggable": student_turn and z != DispatchRound.EXIT and (z != DispatchRound.DOOR or d.arrived(i)),
				"bubble": tr(bubble_key) if bubble_key != "" else ""})
	var lines: PackedStringArray = [tr("ARCADE_CYCLE").format({"cycle": mini(d.cycle, solution.cycles())})]
	var pick_pending: bool = false
	var quantum_over: bool = false
	for m: Dictionary in d.pending:
		pick_pending = pick_pending or str(m["to"]) == DispatchRound.MACHINE
		quantum_over = quantum_over or str(m.get("why", "")) == "quantum"
	if quantum_over:
		lines.append("GAME OVER")
	elif d.machine < 0 and pick_pending:
		lines.append(tr("ARCADE_WHO"))
	elif d.machine < 0:
		lines.append(tr("ARCADE_FREE"))
	elif algorithm == Scheduler.Algorithm.SRT and not d.pending.is_empty():
		lines.append(tr("DISP_SCREEN_SRT"))
	elif algorithm == Scheduler.Algorithm.RR and d.cycle <= solution.cycles():
		lines.append(tr("ARCADE_QUANTUM").format({"used": _turn_used(d.cycle), "q": solution.quantum}))
	_hall.screen_lines = lines
	_hall.machine_busy = d.machine >= 0 and not quantum_over
	_hall.show_state(state, _first_draw)
	_first_draw = false


func _turn_used(c: int) -> int:
	var start: int = c
	while start > 1 and solution.decided[start - 1] != 1:
		start -= 1
	return c - start + 1


func _label_of(i: int) -> String:
	return "%s (%s)" % [ArcadeRound.PLAYER_NAMES[i], solution.names[i]]


# --- Tabla del final ---

func _build_table() -> void:
	for child: Node in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	_inputs.clear()
	_mean_wait = null
	if warmup:
		return
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
		for f: String in ["service", "wait"]:
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
		for f: String in ["service", "wait"]:
			var e: LineEdit = _inputs[0][f]
			e.text = str(ans["table"][0][f])
			e.editable = false
	if phase == Phase.EXAMPLE:
		for row: Dictionary in _inputs:
			for f: String in ["service", "wait"]:
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
