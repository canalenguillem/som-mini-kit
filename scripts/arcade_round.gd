class_name ArcadeRound
extends RefCounted
## Misión 4 en la sala recreativa: la CPU es una máquina, los procesos son jugadores con fichas
## (su ráfaga de CPU) y el alumno decide quién juega cuando el algoritmo tiene que elegir.
##
## Decisiones: los ciclos de Schedule.decision_cycles(). Si el alumno se equivoca, juega quien
## tocaba (el error no se arrastra) y cuenta como fallo. Al acabar, la cuadrícula ya está hecha y
## calcula el Servicio y la Espera de cada jugador y la espera media.
##
## Respuesta: {picks: {ciclo: proceso elegido la primera vez}, table: [{service, wait}], mean_wait: texto}

const PLAYER_NAMES: Array[String] = ["Ana", "Biel", "Carla", "Dani", "Eva"]
const TABLE_FIELDS: Array[String] = ["service", "wait"]
const MAX_MESSAGES: int = 4


## Fallos de una decisión, para enseñarlos en el momento. [] si es correcta.
static func decide(s: Schedule, cycle: int, pick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s.timeline[cycle - 1] == pick:
		return out
	var cell: Dictionary = GanttExercise._cell_mistake(s, cycle - 1, pick)
	out.append({"key": cell["key"], "args": cell["args"]})
	if cell.has("reason"):
		out.append({"key": cell["reason"], "args": cell["args"]})
	return out


## Respuesta perfecta (para el ejemplo y las pruebas).
static func solution_answer(exercise: Dictionary, decimal: String = ",") -> Dictionary:
	var s: Schedule = GanttExercise.solve(exercise)
	var picks: Dictionary = {}
	for c: int in s.decision_cycles():
		picks[c] = s.timeline[c - 1]
	var table: Array = []
	for i: int in s.names.size():
		table.append({"service": str(s.service(i)), "wait": str(s.wait(i))})
	return {"picks": picks, "table": table,
			"mean_wait": Scheduler.format_hundredths(Scheduler.mean_hundredths(s.waits()), decimal)}


static func evaluate(exercise: Dictionary, answer: Dictionary) -> ChallengeResult:
	var s: Schedule = GanttExercise.solve(exercise)
	var r := ChallengeResult.new()
	var processes: Array = exercise["processes"]
	# --- Decisiones ---
	var picks: Dictionary = answer.get("picks", {})
	var wrong: int = 0
	for c: int in s.decision_cycles():
		r.total += 1
		if picks.has(c) and int(picks[c]) == s.timeline[c - 1]:
			r.correct += 1
		else:
			wrong += 1
	var messages: Array[Dictionary] = []
	if wrong > 0:
		messages.append({"key": "ARCADE_WRONG_DECISIONS", "args": {"n": wrong, "total": s.decision_cycles().size()}})
	# --- Tabla corta: Servicio y Espera (la cuadrícula ya es la correcta) ---
	var table: Array = answer.get("table", [])
	var waits: Array = []
	var waits_ok: bool = true
	for i: int in processes.size():
		var row: Dictionary = table[i] if i < table.size() else {}
		var arrival: int = s.arrivals[i]
		var service_given: int = GanttExercise._parse_int(str(row.get("service", "")))
		var wait_given: int = GanttExercise._parse_int(str(row.get("wait", "")))
		var service_used: int = service_given if service_given >= 0 else s.service(i)
		var expected: Dictionary = {"service": s.service(i), "wait": service_used - s.cpu_totals[i] - s.io_totals[i]}
		var given: Dictionary = {"service": service_given, "wait": wait_given}
		for f: String in TABLE_FIELDS:
			r.total += 1
			if int(given[f]) == int(expected[f]):
				r.correct += 1
			elif messages.size() < MAX_MESSAGES:
				messages.append(GanttExercise._table_mistake(f, s.names[i], int(given[f]), expected, arrival,
						s.cpu_totals[i], s.io_totals[i], s.finishes[i]))
		if wait_given < 0:
			waits_ok = false
		waits.append(wait_given)
	# --- Espera media, con las esperas que haya escrito el alumno ---
	r.total += 1
	var expected_h: int = Scheduler.mean_hundredths(PackedInt32Array(waits)) if waits_ok \
			else Scheduler.mean_hundredths(s.waits())
	var given_h: int = Scheduler.parse_hundredths(str(answer.get("mean_wait", "")))
	if given_h == expected_h:
		r.correct += 1
	elif messages.size() < MAX_MESSAGES:
		var sum: int = 0
		for w: int in waits:
			sum += maxi(w, 0)
		var rounded: int = roundi(float(sum) * 100.0 / float(maxi(processes.size(), 1)))
		var key: String = "GANTT_MEAN_ROUNDED_WAIT" if waits_ok and given_h == rounded and rounded != expected_h \
				else "GANTT_MEAN_WRONG_WAIT"
		messages.append({"key": key, "args": {"n": processes.size()}})
	for m: Dictionary in messages:
		r.add_mistake(str(m["key"]), m["args"])
	# Las decisiones ya están tomadas: solo se puede mejorar si falla algo de la tabla
	r.can_improve = r.total - r.correct > wrong
	return r
