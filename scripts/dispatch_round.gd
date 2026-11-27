class_name DispatchRound
extends RefCounted
## El salón recreativo con arrastres: el alumno hace de sistema operativo y mueve a cada jugador.
## Cada movimiento es una transición del diagrama de estados:
##   puerta → cola (Nuevo → Preparado) · cola → máquina (Preparado → En ejecución)
##   máquina → cola (En ejecución → Preparado) · máquina → bocadillos (En ejecución → Bloqueado)
##   bocadillos → cola (Bloqueado → Preparado) · máquina → salida (En ejecución → Terminado)
##
## Al empezar cada ciclo hay unos movimientos pendientes, sacados de Scheduler (las reglas del libro):
##   1. sale de la máquina el del ciclo anterior si ha acabado (salida), pide E/S (bocadillos) o ha
##      agotado el quantum / lo expulsan en SRT (cola);
##   2. entran en la cola, en este orden: los que llegan, los que vuelven de E/S y el que sale de la
##      máquina;
##   3. si la máquina queda libre, entra quien diga el algoritmo.
## Cuando no queda nada pendiente, pasa el ciclo. Un movimiento que no toca se rechaza con su porqué.

const DOOR: String = "door"
const QUEUE: String = "queue"
const MACHINE: String = "machine"
const SNACK: String = "snack"
const EXIT: String = "exit"
const TRANSITIONS: Dictionary = {
	"door>queue": "NEW_READY", "queue>machine": "READY_RUNNING", "machine>queue": "RUNNING_READY",
	"machine>snack": "RUNNING_BLOCKED", "snack>queue": "BLOCKED_READY", "machine>exit": "RUNNING_TERMINATED",
}

var s: Schedule
var strict_order: bool = true  ## el orden de entrada en la cola cuenta (en el calentamiento, no)
var cycle: int = 1  ## ciclo que está a punto de jugarse; s.cycles() + 1 = solo quedan salidas
var zone: Array[String] = []
var queue: Array[int] = []
var machine: int = -1
var pending: Array[Dictionary] = []  ## {p, to}; las entradas en la cola van en su orden
var over: bool = false
var required: int = 0  ## movimientos que había que hacer en total
var errors: int = 0  ## movimientos rechazados que cuentan


func _init(schedule: Schedule, strict: bool = true) -> void:
	s = schedule
	strict_order = strict
	for i: int in s.names.size():
		zone.append(DOOR)
	_plan()


func arrived(p: int) -> bool:
	return s.arrivals[p] <= cycle


## Fichas (ciclos de CPU) que le quedan a `p` antes de jugar el ciclo actual.
func tokens_left(p: int) -> int:
	var used: int = 0
	for k: int in mini(cycle - 1, s.cycles()):
		if s.timeline[k] == p:
			used += 1
	return s.cpu_totals[p] - used


func waited(p: int) -> int:
	var w: int = 0
	for k: int in range(s.arrivals[p], mini(cycle, s.cycles() + 1)):
		if s.timeline[k - 1] != p and not s.io_cycles[p].has(k):
			w += 1
	return w


## Lo que pasa en este ciclo con `p` (para los avisos del salón): "arrive", "finish", "io", "quantum",
## "preempt", "io_done" o "".
func event_of(p: int) -> String:
	for m: Dictionary in pending:
		if int(m["p"]) != p:
			continue
		return str(m.get("why", ""))
	return ""


## Intenta mover a `p` a `to`. Devuelve {ok, transition, msgs: [{key, args}]}.
## Si `count` es false (guiado), el fallo no suma.
func try_move(p: int, to: String, count: bool = true) -> Dictionary:
	var from: String = zone[p]
	var msgs: Array[Dictionary] = _check(p, from, to)
	if not msgs.is_empty():
		if count:
			errors += 1
		return {"ok": false, "msgs": msgs, "transition": ""}
	_apply(p, from, to)
	return {"ok": true, "msgs": [] as Array[Dictionary], "transition": TRANSITIONS.get(from + ">" + to, "")}


## Hace el siguiente movimiento correcto (ejemplo, partes guiadas, elección automática).
func auto_move() -> Dictionary:
	if pending.is_empty():
		return {}
	var m: Dictionary = _next_allowed()
	var p: int = int(m["p"])
	var from: String = zone[p]
	_apply(p, from, str(m["to"]))
	return {"p": p, "from": from, "to": m["to"], "transition": TRANSITIONS.get(from + ">" + str(m["to"]), "")}


## Hay que esperar al alumno (o al automático) para seguir.
func waiting() -> bool:
	return not over and not pending.is_empty()


## Solo queda elegir quién juega.
func only_pick_left() -> bool:
	return pending.size() == 1 and str(pending[0]["to"]) == MACHINE


## Pasa al ciclo siguiente si no queda nada pendiente. Devuelve el ciclo jugado (o -1).
func advance() -> int:
	if over or not pending.is_empty():
		return -1
	var played: int = cycle
	cycle += 1
	_plan()
	return played


func _next_allowed() -> Dictionary:
	for m: Dictionary in pending:
		if _check(int(m["p"]), zone[int(m["p"])], str(m["to"])).is_empty():
			return m
	return pending[0]


# --- Plan de cada ciclo ---

func _plan() -> void:
	pending.clear()
	var c: int = cycle
	var n: int = s.cycles()
	var prev: int = s.timeline[c - 2] if c >= 2 and c - 2 < n else -1
	var now: int = s.timeline[c - 1] if c <= n else -1
	var requeue: int = -1
	if prev >= 0 and zone[prev] == MACHINE:
		if s.finishes[prev] == c - 1:
			pending.append({"p": prev, "to": EXIT, "why": "finish"})
		elif s.io_cycles[prev].has(c):
			pending.append({"p": prev, "to": SNACK, "why": "io"})
		elif c <= n and (now != prev or s.reasons[c - 1] == Scheduler.Reason.QUANTUM_ALONE):
			requeue = prev
	if c > n:
		if pending.is_empty():
			over = true
		required += pending.size()
		return
	for i: int in s.names.size():
		if s.arrivals[i] == c:
			pending.append({"p": i, "to": QUEUE, "why": "arrive"})
	var back: Array[int] = []
	for i: int in s.names.size():
		if zone[i] == SNACK and not s.io_cycles[i].has(c):
			back.append(i)
	back.sort_custom(func(a: int, b: int) -> bool: return s.io_cycles[a][0] < s.io_cycles[b][0])
	for i: int in back:
		pending.append({"p": i, "to": QUEUE, "why": "io_done"})
	if requeue >= 0:
		var why: String = "preempt" if s.algorithm == Scheduler.Algorithm.SRT else "quantum"
		pending.append({"p": requeue, "to": QUEUE, "why": why})
	if now >= 0 and (now != prev or requeue == prev):
		pending.append({"p": now, "to": MACHINE, "why": "pick"})
	required += pending.size()


# --- Validación ---

func _check(p: int, from: String, to: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var who: String = s.names[p]
	if from == to:
		return [{"key": "DISP_SAME_PLACE", "args": {"player": who}}]
	if from == EXIT:
		return [{"key": "DISP_ALREADY_GONE", "args": {"player": who}}]
	if from == DOOR and not arrived(p):
		return [{"key": "DISP_NOT_ARRIVED", "args": {"player": who, "cycle": s.arrivals[p]}}]
	if from == SNACK and to == MACHINE:
		return [{"key": "DISP_TRAP", "args": {"player": who}}]
	if from == DOOR and to != QUEUE:
		return [{"key": "DISP_DOOR_FIRST_QUEUE", "args": {"player": who}}]
	var mine: Dictionary = {}
	for m: Dictionary in pending:
		if int(m["p"]) == p:
			mine = m
			break
	if mine.is_empty():
		return _why_not(p, from, to)
	if str(mine["to"]) != to:
		return [_wrong_destination(p, mine)]
	if to == QUEUE and strict_order:
		var first_entrant: int = -1
		for m: Dictionary in pending:
			if str(m["to"]) == QUEUE:
				first_entrant = int(m["p"])
				break
		if first_entrant != p:
			return [{"key": "DISP_QUEUE_ORDER", "args": {"player": who, "expected": s.names[first_entrant]}}]
	if to == MACHINE:
		for m: Dictionary in pending:
			if str(m["to"]) != MACHINE:
				var key: String = "DISP_FIRST_CLEAR" if machine >= 0 else "DISP_FIRST_FILL_QUEUE"
				return [{"key": key, "args": {"player": s.names[int(m["p"])]}}]
	return out


## Por qué `p` no tiene que moverse en este ciclo.
func _why_not(p: int, from: String, to: String) -> Array[Dictionary]:
	var who: String = s.names[p]
	var c: int = cycle
	if to == MACHINE and from == QUEUE:
		var expected: int = s.timeline[c - 1] if c <= s.cycles() else -1
		if machine >= 0 or expected < 0:
			return [{"key": "DISP_MACHINE_BUSY", "args": {"player": s.names[machine] if machine >= 0 else who}}]
		# Elige a otro: se explica como en la cuadrícula («le tocaba a X» y por qué)
		var cell: Dictionary = GanttExercise._cell_mistake(s, c - 1, p)
		var out: Array[Dictionary] = [{"key": cell["key"], "args": cell["args"]}]
		if cell.has("reason"):
			out.append({"key": cell["reason"], "args": cell["args"]})
		return out
	if from == MACHINE:
		match s.algorithm:
			Scheduler.Algorithm.RR:
				return [{"key": "DISP_KEEPS_RR", "args": {"player": who}}]
			Scheduler.Algorithm.SRT:
				return [{"key": "DISP_KEEPS_SRT", "args": {"player": who, "left": tokens_left(p)}}]
		return [{"key": "DISP_KEEPS_NONPREEMPTIVE", "args": {"player": who}}]
	if from == SNACK:
		var io: PackedInt32Array = s.io_cycles[p]
		var last: int = io[io.size() - 1] if not io.is_empty() else c
		return [{"key": "DISP_STILL_EATING", "args": {"player": who, "cycle": last + 1}}]
	if from == QUEUE:
		return [{"key": "DISP_STAYS_IN_QUEUE", "args": {"player": who}}]
	return [{"key": "DISP_NOT_NOW", "args": {"player": who}}]


func _wrong_destination(p: int, mine: Dictionary) -> Dictionary:
	var who: String = s.names[p]
	match str(mine.get("why", "")):
		"finish":
			return {"key": "DISP_GOES_EXIT", "args": {"player": who}}
		"io":
			return {"key": "DISP_GOES_SNACK", "args": {"player": who}}
		"quantum", "preempt", "arrive", "io_done":
			return {"key": "DISP_GOES_QUEUE", "args": {"player": who}}
	return {"key": "DISP_NOT_NOW", "args": {"player": who}}


func _apply(p: int, from: String, to: String) -> void:
	if from == QUEUE:
		queue.erase(p)
	if from == MACHINE:
		machine = -1
	zone[p] = to
	if to == QUEUE:
		queue.append(p)
	if to == MACHINE:
		machine = p
	for k: int in pending.size():
		if int(pending[k]["p"]) == p:
			pending.remove_at(k)
			break
	if not strict_order and to == QUEUE:
		_fix_queue_order()


## En el calentamiento el orden de la cola lo pone el juego (el del libro).
func _fix_queue_order() -> void:
	var expected: Array = s.queues[cycle - 1] if cycle <= s.cycles() else []
	var order: Array[int] = []
	var now: int = s.timeline[cycle - 1] if cycle <= s.cycles() else -1
	if now >= 0 and zone[now] == QUEUE:
		order.append(now)
	for i: int in expected:
		if zone[i] == QUEUE and not order.has(i):
			order.append(i)
	for i: int in queue:
		if not order.has(i):
			order.append(i)
	queue = order


## Nota de los movimientos: cada fallo resta uno.
func result() -> ChallengeResult:
	var r := ChallengeResult.new()
	r.total = required
	r.correct = maxi(required - errors, 0)
	if errors > 0:
		r.add_mistake("DISP_WRONG_MOVES", {"n": errors})
	r.can_improve = false
	return r
