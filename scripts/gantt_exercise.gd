class_name GanttExercise
extends RefCounted
## Misión 4: generador y corrector de la cuadrícula y la tabla de tiempos.
##
## Ejercicio: {algorithm, quantum, processes: [{name, arrival, bursts}], columns}
## Respuesta: {grid: Array[int] (proceso en la CPU en cada columna, -1 = nadie),
##             table: [{start, finish, response, service, wait}] (texto tal como lo escribe el alumno),
##             means: {response, service, wait} (texto)}
##
## La cuadrícula se compara con la solución ciclo a ciclo. La tabla se corrige con «error arrastrado»:
## Inicio y Fin se esperan según la cuadrícula del alumno, y lo demás según sus propios Inicio y Fin.

const NAMES: Array[String] = ["A", "B", "C", "D", "E"]  ## como en el libro
const FIELDS: Array[String] = ["start", "finish", "response", "service", "wait"]
const MEAN_FIELDS: Array[String] = ["response", "service", "wait"]
const EXTRA_COLUMNS: int = 2  ## columnas de más, para no regalar cuándo acaba
const MAX_TRIES: int = 400
const MAX_MESSAGES: int = 4


## config: {algorithm: Scheduler.Algorithm, io: bool, processes: int, max_cycles: int}
static func generate(exercise_seed: int, config: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ExerciseSeed.rng(exercise_seed)
	var algorithm: Scheduler.Algorithm = config.get("algorithm", Scheduler.Algorithm.FIFO)
	var io: bool = bool(config.get("io", false))
	var count: int = int(config.get("processes", 3 if io else 4))
	var max_cycles: int = int(config.get("max_cycles", 16))
	var best: Dictionary = {}
	for attempt: int in MAX_TRIES:
		var quantum: int = rng.randi_range(2, 3) if algorithm == Scheduler.Algorithm.RR else 2
		var processes: Array = []
		var arrival: int = 1
		for i: int in count:
			if i > 0:
				arrival += rng.randi_range(1, 3)
			var bursts: Array = []
			if io:
				bursts = [rng.randi_range(1, 3), rng.randi_range(1, 3), rng.randi_range(1, 2)]
			else:
				bursts = [rng.randi_range(1, 6)]
			processes.append({"name": NAMES[i], "arrival": arrival, "bursts": bursts})
		var s: Schedule = Scheduler.run(processes, algorithm, quantum)
		var exercise: Dictionary = {"algorithm": algorithm, "quantum": quantum, "processes": processes,
				"columns": s.cycles() + EXTRA_COLUMNS}
		best = exercise
		if s.cycles() <= max_cycles and not s.ambiguous and _is_interesting(s, io):
			return exercise
	return best


## Que el ejercicio haga pensar: alguien espera y el algoritmo se nota.
static func _is_interesting(s: Schedule, io: bool) -> bool:
	if s.decision_cycles().size() < 2:
		return false  # en la sala recreativa tiene que haber algo que decidir
	var waited: bool = false
	for w: int in s.waits():
		if w > 0:
			waited = true
	if not waited:
		return false
	var has: Dictionary = {}
	for r: int in s.reasons:
		has[r] = true
	match s.algorithm:
		Scheduler.Algorithm.RR:
			var expired: bool = false
			for c: int in range(1, s.cycles()):
				var prev: int = s.timeline[c - 1]
				if prev >= 0 and s.timeline[c] != prev and s.timeline[c] >= 0 and s.finishes[prev] != c \
						and not s.io_cycles[prev].has(c + 1):
					expired = true
			if not expired:
				return false
			if io:
				var total_io: int = 0
				for t: int in s.io_totals:
					total_io += t
				return total_io > 0
			return true
		Scheduler.Algorithm.SJF:
			return _sjf_differs_from_fifo(s)
		Scheduler.Algorithm.SRT:
			return has.has(Scheduler.Reason.PREEMPTS)
	return true


static func _sjf_differs_from_fifo(s: Schedule) -> bool:
	var processes: Array = []
	for i: int in s.names.size():
		processes.append({"name": s.names[i], "arrival": s.arrivals[i], "bursts": [s.cpu_totals[i]]})
	return Scheduler.run(processes, Scheduler.Algorithm.FIFO).segments() != s.segments()


static func solve(exercise: Dictionary) -> Schedule:
	return Scheduler.run(exercise["processes"], exercise["algorithm"], int(exercise["quantum"]))


## Respuesta correcta completa (para el ejemplo y para rellenar el guiado).
static func solution_answer(exercise: Dictionary, decimal: String = ",") -> Dictionary:
	var s: Schedule = solve(exercise)
	var grid: Array[int] = []
	for c: int in int(exercise["columns"]):
		grid.append(s.timeline[c] if c < s.cycles() else -1)
	var table: Array = []
	for i: int in s.names.size():
		table.append({"start": str(s.starts[i]), "finish": str(s.finishes[i]), "response": str(s.response(i)),
				"service": str(s.service(i)), "wait": str(s.wait(i))})
	return {"grid": grid, "table": table, "means": {
		"response": Scheduler.format_hundredths(Scheduler.mean_hundredths(s.responses()), decimal),
		"service": Scheduler.format_hundredths(Scheduler.mean_hundredths(s.services()), decimal),
		"wait": Scheduler.format_hundredths(Scheduler.mean_hundredths(s.waits()), decimal)}}


static func evaluate(exercise: Dictionary, answer: Dictionary) -> ChallengeResult:
	var s: Schedule = solve(exercise)
	var r := ChallengeResult.new()
	var processes: Array = exercise["processes"]
	var n: int = processes.size()
	var columns: int = int(exercise["columns"])
	var grid: Array = answer.get("grid", [])
	# --- Cuadrícula ---
	var first_wrong: int = -1
	var wrong_cells: int = 0
	for c: int in columns:
		var expected: int = s.timeline[c] if c < s.cycles() else -1
		var given: int = int(grid[c]) if c < grid.size() else -1
		r.total += 1
		if given == expected:
			r.correct += 1
		else:
			wrong_cells += 1
			if first_wrong < 0:
				first_wrong = c
	var messages: Array[Dictionary] = []
	if first_wrong >= 0:
		messages.append({"key": "GANTT_WRONG_CELL_ONE" if wrong_cells == 1 else "GANTT_WRONG_CELLS", "args": {"n": wrong_cells}})
		var cell: Dictionary = _cell_mistake(s, first_wrong, int(grid[first_wrong]) if first_wrong < grid.size() else -1)
		messages.append(cell)
		if cell.has("reason"):
			messages.append({"key": cell["reason"], "args": cell["args"]})
	# --- Tabla (error arrastrado) ---
	var own: Dictionary = _own_times(exercise, grid)
	var table: Array = answer.get("table", [])
	var table_messages: Array[Dictionary] = []
	var values: Dictionary = {"response": [], "service": [], "wait": []}  ## Array (por referencia)
	var means_computable: bool = true
	for i: int in n:
		var row: Dictionary = table[i] if i < table.size() else {}
		var arrival: int = int(processes[i]["arrival"])
		var cpu: int = s.cpu_totals[i]
		var io: int = s.io_totals[i]
		var start_exp: int = int(own["starts"][i])
		var finish_exp: int = int(own["finishes"][i])
		var given: Dictionary = {}
		for f: String in FIELDS:
			given[f] = _parse_int(str(row.get(f, "")))
		# Las fórmulas se corrigen con los Inicio y Fin que haya escrito el alumno (si son números)
		var start_used: int = int(given["start"]) if int(given["start"]) >= 0 else start_exp
		var finish_used: int = int(given["finish"]) if int(given["finish"]) >= 0 else finish_exp
		var service_used: int = int(given["service"]) if int(given["service"]) >= 0 else finish_used - arrival + 1
		var expected: Dictionary = {
			"start": start_exp, "finish": finish_exp, "response": start_used - arrival,
			"service": finish_used - arrival + 1, "wait": service_used - cpu - io}
		var name: String = str(processes[i]["name"])
		for f: String in FIELDS:
			r.total += 1
			if int(given[f]) == int(expected[f]):
				r.correct += 1
			else:
				table_messages.append(_table_mistake(f, name, int(given[f]), expected, arrival, cpu, io, finish_used))
		for f: String in MEAN_FIELDS:
			if int(given[f]) < 0:
				means_computable = false
			(values[f] as Array).append(int(given[f]))
	# --- Medias, con los valores de la tabla del alumno ---
	var means: Dictionary = answer.get("means", {})
	for f: String in MEAN_FIELDS:
		r.total += 1
		var expected_h: int = Scheduler.mean_hundredths(PackedInt32Array(values[f])) if means_computable \
				else Scheduler.mean_hundredths(_solution_column(s, f))
		var given_h: int = Scheduler.parse_hundredths(str(means.get(f, "")))
		if given_h == expected_h:
			r.correct += 1
		else:
			var sum: int = 0
			for v: int in (values[f] as Array):
				sum += v
			var rounded: int = roundi(float(sum) * 100.0 / float(maxi(n, 1)))
			var key: String = "GANTT_MEAN_ROUNDED_" if means_computable and given_h == rounded and rounded != expected_h \
					else "GANTT_MEAN_WRONG_"
			table_messages.append({"key": key + f.to_upper(), "args": {"n": n}})
	for m: Dictionary in table_messages:
		if messages.size() >= MAX_MESSAGES:
			break
		messages.append(m)
	for m: Dictionary in messages:
		r.add_mistake(str(m["key"]), m["args"])
	return r


## Inicio y Fin según la cuadrícula del alumno (o los correctos si su fila está vacía).
static func _own_times(exercise: Dictionary, grid: Array) -> Dictionary:
	var s: Schedule = solve(exercise)
	var starts: Array = []
	var finishes: Array = []
	for i: int in (exercise["processes"] as Array).size():
		var first: int = 0
		var last: int = 0
		for c: int in grid.size():
			if int(grid[c]) == i:
				if first == 0:
					first = c + 1
				last = c + 1
		starts.append(first if first > 0 else s.starts[i])
		finishes.append(last if last > 0 else s.finishes[i])
	return {"starts": starts, "finishes": finishes}


static func _solution_column(s: Schedule, field: String) -> PackedInt32Array:
	match field:
		"response":
			return s.responses()
		"service":
			return s.services()
	return s.waits()


static func _parse_int(text: String) -> int:
	var t: String = text.strip_edges()
	return int(t) if t.is_valid_int() and int(t) >= 0 else -1


## Explica qué tenía que pasar en la columna `c` (0-based) de la cuadrícula.
static func _cell_mistake(s: Schedule, c: int, given: int) -> Dictionary:
	var cycle: int = c + 1
	if c >= s.cycles():
		return {"key": "GANTT_AFTER_END", "args": {"cycle": cycle}}
	var expected: int = s.timeline[c]
	if expected < 0:
		return {"key": "GANTT_SHOULD_BE_IDLE", "args": {"cycle": cycle}}
	var args: Dictionary = {"cycle": cycle, "expected": s.names[expected],
			"given": s.names[given] if given >= 0 else "", "q": s.quantum, "need": s.needs[c]}
	var reason: int = s.reasons[c]
	var key: String = "GANTT_REASON_"
	match reason:
		Scheduler.Reason.CONTINUES:
			key += "CONTINUES_" + Scheduler.ALGORITHM_NAMES[s.algorithm]
		Scheduler.Reason.QUEUE_HEAD:
			key += "HEAD_" + Scheduler.ALGORITHM_NAMES[s.algorithm]
		Scheduler.Reason.SHORTEST:
			key += "SHORTEST"
		Scheduler.Reason.PREEMPTS:
			key += "PREEMPTS"
			args["victim"] = s.names[s.victims[c]] if s.victims[c] >= 0 else ""
			args["left"] = s.victim_left[c]
		Scheduler.Reason.QUANTUM_ALONE:
			key += "QUANTUM_ALONE"
	return {"key": "GANTT_CELL_IDLE_GIVEN" if given < 0 else "GANTT_CELL", "args": args, "reason": key}


static func _table_mistake(field: String, name: String, given: int, expected: Dictionary, arrival: int,
		cpu: int, io: int, finish_used: int) -> Dictionary:
	var args: Dictionary = {"process": name}
	match field:
		"start":
			return {"key": "GANTT_START_WRONG", "args": args}
		"finish":
			return {"key": "GANTT_FINISH_WRONG", "args": args}
		"response":
			return {"key": "GANTT_RESPONSE_WRONG", "args": args}
		"service":
			if given == finish_used - arrival:
				return {"key": "GANTT_SERVICE_PLUS_ONE", "args": args}
			return {"key": "GANTT_SERVICE_WRONG", "args": args}
	if io > 0 and given == int(expected["wait"]) + io:
		return {"key": "GANTT_WAIT_IO", "args": args}
	return {"key": "GANTT_WAIT_WRONG", "args": args}
