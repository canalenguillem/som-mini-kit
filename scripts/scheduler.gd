class_name Scheduler
extends RefCounted
## Planificación de CPU con las reglas del cuaderno (tema 4) y de PlaniSim.
##
## Tiempo en ciclos que empiezan en 1. Un proceso que llega en el ciclo k ya puede ejecutarse en k.
## Fin = último ciclo en la CPU (incluido). Respuesta = Inicio − Llegada; Servicio = Fin − Llegada + 1;
## Espera = Servicio − CPU − E/S. Medias truncadas a dos decimales.
##
## Al empezar cada ciclo:
##  1. Sale de la CPU el que acabó su ráfaga en el ciclo anterior (termina o empieza su E/S en este
##     ciclo) o, en RR, el que ha agotado el quantum.
##  2. Entran en la cola, por este orden: los que llegan (orden de la tabla), los que vuelven de E/S
##     (el que empezó antes la E/S, primero) y el expulsado por el quantum.
##  3. SRT: si el más corto de los que acaban de entrar necesita estrictamente menos de lo que le queda
##     al de la CPU, lo expulsa (el expulsado va al final de la cola).
##  4. SJF y SRT: la cola se ordena de forma estable por lo que queda de la ráfaga actual
##     (a igualdad, el que estaba antes en la cola).
##  5. Si la CPU está libre, entra el primero de la cola con un quantum nuevo; si no hay nadie, se para.

enum Algorithm { FIFO, RR, SJF, SRT }
## Por qué está en la CPU quien está (para explicar los fallos).
enum Reason { IDLE, CONTINUES, QUEUE_HEAD, SHORTEST, PREEMPTS, QUANTUM_ALONE }

const ALGORITHM_NAMES: Array[String] = ["FIFO", "RR", "SJF", "SRT"]
const MAX_CYCLES: int = 500


## Simula. `processes`: [{name: String, arrival: int, bursts: Array[int]}], con bursts = CPU, E/S, CPU…
static func run(processes: Array, algorithm: Algorithm, quantum: int = 2) -> Schedule:
	var n: int = processes.size()
	var s := Schedule.new()
	s.algorithm = algorithm
	s.quantum = quantum
	var burst_idx: PackedInt32Array = []
	var remaining: PackedInt32Array = []
	var io_end: PackedInt32Array = []  ## último ciclo de la E/S en curso; 0 si no hace E/S
	var io_start: PackedInt32Array = []
	for i: int in n:
		var p: Dictionary = processes[i]
		var bursts: Array = p["bursts"]
		s.names.append(str(p["name"]))
		s.arrivals.append(int(p["arrival"]))
		var cpu: int = 0
		var io: int = 0
		for b: int in bursts.size():
			if b % 2 == 0:
				cpu += int(bursts[b])
			else:
				io += int(bursts[b])
		s.cpu_totals.append(cpu)
		s.io_totals.append(io)
		s.starts.append(0)
		s.finishes.append(0)
		burst_idx.append(0)
		remaining.append(int(bursts[0]))
		io_end.append(0)
		io_start.append(0)
		s.io_cycles.append(PackedInt32Array())

	var running: int = -1
	var quantum_left: int = 0
	var queue: Array[int] = []
	var done: int = 0
	var cycle: int = 0
	while done < n and cycle < MAX_CYCLES:
		cycle += 1
		var preempted: int = -1
		# 1. Salidas de la CPU
		if running >= 0:
			if remaining[running] == 0:
				var bursts: Array = processes[running]["bursts"]
				if burst_idx[running] + 1 < bursts.size():
					burst_idx[running] += 1
					var d: int = int(bursts[burst_idx[running]])
					io_start[running] = cycle
					io_end[running] = cycle + d - 1
				running = -1
			elif algorithm == Algorithm.RR and quantum_left <= 0:
				preempted = running
				running = -1
		# 2. Entradas en la cola
		var entering: Array[int] = []
		for i: int in n:
			if s.arrivals[i] == cycle:
				entering.append(i)
		var returning: Array[int] = []
		for i: int in n:
			if io_end[i] > 0 and io_end[i] == cycle - 1:
				returning.append(i)
				io_end[i] = 0
				burst_idx[i] += 1
				var bursts: Array = processes[i]["bursts"]
				remaining[i] = int(bursts[burst_idx[i]])
		returning.sort_custom(func(a: int, b: int) -> bool: return io_start[a] < io_start[b])
		entering.append_array(returning)
		queue.append_array(entering)
		if preempted >= 0:
			queue.append(preempted)
		# 3. Expulsión en SRT
		var reason: Reason = Reason.CONTINUES
		if algorithm == Algorithm.SRT and running >= 0 and not entering.is_empty():
			var shortest: int = entering[0]
			for i: int in entering:
				if remaining[i] < remaining[shortest]:
					shortest = i
			if remaining[shortest] < remaining[running]:
				queue.append(running)
				running = -1
				reason = Reason.PREEMPTS
		# 4. Orden por lo que queda
		if algorithm == Algorithm.SJF or algorithm == Algorithm.SRT:
			queue = _stable_sort_by(queue, remaining)
		# 5. Entra en la CPU
		if running < 0:
			if queue.is_empty():
				reason = Reason.IDLE
			else:
				running = queue.pop_front()
				quantum_left = quantum
				if reason != Reason.PREEMPTS:
					if preempted == running:
						reason = Reason.QUANTUM_ALONE
					elif algorithm == Algorithm.SJF or algorithm == Algorithm.SRT:
						reason = Reason.SHORTEST
					else:
						reason = Reason.QUEUE_HEAD
		# Ejecuta el ciclo
		s.timeline.append(running)
		s.reasons.append(reason)
		s.queues.append(queue.duplicate())
		for i: int in n:
			if io_end[i] > 0 and cycle >= io_start[i] and cycle <= io_end[i]:
				s.io_cycles[i].append(cycle)
		if running >= 0:
			if s.starts[running] == 0:
				s.starts[running] = cycle
			remaining[running] -= 1
			quantum_left -= 1
			if remaining[running] == 0 and burst_idx[running] + 1 >= (processes[running]["bursts"] as Array).size():
				s.finishes[running] = cycle
				done += 1
	return s


## Ordenación estable (inserción) de los índices por su valor en `key`.
static func _stable_sort_by(items: Array[int], key: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for item: int in items:
		var pos: int = out.size()
		while pos > 0 and key[out[pos - 1]] > key[item]:
			pos -= 1
		out.insert(pos, item)
	return out


## Media truncada a dos decimales, en centésimas (29/3 → 966). Solo valores ≥ 0.
static func mean_hundredths(values: PackedInt32Array) -> int:
	if values.is_empty():
		return 0
	var total: int = 0
	for v: int in values:
		total += v
	return (total * 100) / values.size()


## Centésimas como las escribe el libro: coma decimal y sin ceros de más (966 → «9,66», 500 → «5»,
## 440 → «4,4»). Con `decimal = "."` para inglés.
static func format_hundredths(h: int, decimal: String = ",") -> String:
	var whole: int = h / 100
	var frac: int = h % 100
	if frac == 0:
		return str(whole)
	if frac % 10 == 0:
		return "%d%s%d" % [whole, decimal, frac / 10]
	return "%d%s%02d" % [whole, decimal, frac]


## Lee lo que escribe el alumno («9,66», «9.66», «5», « 4,4 ») a centésimas, truncando.
## -1 si no es un número válido ≥ 0.
static func parse_hundredths(text: String) -> int:
	var t: String = text.strip_edges().replace(",", ".")
	if t.is_empty() or not t.is_valid_float() or t.begins_with("-"):
		return -1
	var parts: PackedStringArray = t.split(".")
	if parts.size() > 2 or not parts[0].is_valid_int() and not parts[0].is_empty():
		return -1
	var whole: int = int(parts[0]) if not parts[0].is_empty() else 0
	var frac: int = 0
	if parts.size() == 2:
		var digits: String = (parts[1] + "00").left(2)
		if not digits.is_valid_int():
			return -1
		frac = int(digits)
	return whole * 100 + frac
