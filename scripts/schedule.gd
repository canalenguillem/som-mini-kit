class_name Schedule
extends RefCounted
## Resultado de Scheduler.run(): cuadrícula, colas y la tabla de tiempos.
## Los arrays por ciclo empiezan en el ciclo 1 (índice 0 = ciclo 1).

var algorithm: Scheduler.Algorithm = Scheduler.Algorithm.FIFO
var quantum: int = 2
var names: PackedStringArray = []
var arrivals: PackedInt32Array = []
var cpu_totals: PackedInt32Array = []
var io_totals: PackedInt32Array = []
var starts: PackedInt32Array = []
var finishes: PackedInt32Array = []
var timeline: Array[int] = []  ## proceso en la CPU en cada ciclo; -1 = CPU parada
var reasons: Array[int] = []  ## Scheduler.Reason de cada ciclo
var queues: Array[Array] = []  ## cola de preparados de cada ciclo, el primero es el que entrará
var io_cycles: Array[PackedInt32Array] = []  ## ciclos de E/S de cada proceso


func cycles() -> int:
	return timeline.size()


func response(i: int) -> int:
	return starts[i] - arrivals[i]


func service(i: int) -> int:
	return finishes[i] - arrivals[i] + 1


func wait(i: int) -> int:
	return service(i) - cpu_totals[i] - io_totals[i]


func responses() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i: int in names.size():
		out.append(response(i))
	return out


func services() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i: int in names.size():
		out.append(service(i))
	return out


func waits() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i: int in names.size():
		out.append(wait(i))
	return out


## Marca de la cuadrícula del libro: X (en la CPU), F (último ciclo), W (E/S) o "" (cola o fuera).
func mark(process: int, cycle: int) -> String:
	if cycle < 1 or cycle > timeline.size():
		return ""
	if timeline[cycle - 1] == process:
		return "F" if cycle == finishes[process] else "X"
	if io_cycles[process].has(cycle):
		return "W"
	return ""


## La CPU por tramos, como en el libro: «1-3 A, 4-5 B, 10 (parada)». Las paradas se escriben «-».
func segments() -> String:
	var parts: PackedStringArray = []
	var c: int = 0
	while c < timeline.size():
		var who: int = timeline[c]
		var end: int = c
		while end + 1 < timeline.size() and timeline[end + 1] == who:
			end += 1
		var label: String = names[who] if who >= 0 else "-"
		parts.append(("%d %s" % [c + 1, label]) if end == c else ("%d-%d %s" % [c + 1, end + 1, label]))
		c = end + 1
	return ", ".join(parts)
