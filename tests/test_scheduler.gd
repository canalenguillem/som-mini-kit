extends GutTest
## Planificador contra los ejercicios resueltos del cuaderno (tema 4). Ver docs/temario/tema4.md §6.

const A := Scheduler.Algorithm


func _p(name: String, arrival: int, bursts: Array) -> Dictionary:
	return {"name": name, "arrival": arrival, "bursts": bursts}


## Datos A: los «cinco procesos de siempre».
func _data_a() -> Array:
	return [_p("A", 1, [3]), _p("B", 4, [2]), _p("C", 5, [3]), _p("D", 7, [4]), _p("E", 8, [2])]


func _data_48() -> Array:
	return [_p("P1", 1, [5]), _p("P2", 2, [2]), _p("P3", 3, [4]), _p("P4", 5, [1])]


func _data_repaso() -> Array:
	return [_p("A", 1, [6]), _p("B", 2, [3]), _p("C", 4, [1]), _p("D", 6, [4])]


## Comprueba tramos de CPU, columnas de la tabla y medias (en centésimas).
func _check(s: Schedule, segments: String, starts: Array, finishes: Array, means: Array) -> void:
	assert_eq(s.segments(), segments)
	assert_eq(Array(s.starts), starts, "inicios")
	assert_eq(Array(s.finishes), finishes, "fines")
	var got: Array = [Scheduler.mean_hundredths(s.responses()), Scheduler.mean_hundredths(s.services()),
			Scheduler.mean_hundredths(s.waits())]
	assert_eq(got, means, "medias de respuesta, servicio y espera")


func _queue_names(s: Schedule, cycle: int) -> Array:
	var out: Array = []
	for i: int in s.queues[cycle - 1]:
		out.append(s.names[i])
	return out


func test_ejemplo_1_fifo() -> void:
	var s: Schedule = Scheduler.run(_data_a(), A.FIFO)
	_check(s, "1-3 A, 4-5 B, 6-8 C, 9-12 D, 13-14 E", [1, 4, 6, 9, 13], [3, 5, 8, 12, 14], [160, 440, 160])
	assert_eq(Array(s.waits()), [0, 0, 1, 2, 5])
	assert_eq(_queue_names(s, 8), ["D", "E"])


func test_ejemplo_2_rr_q2() -> void:
	var s: Schedule = Scheduler.run(_data_a(), A.RR, 2)
	_check(s, "1-3 A, 4-5 B, 6-7 C, 8-9 D, 10-11 E, 12 C, 13-14 D", [1, 4, 6, 8, 10], [3, 5, 12, 14, 11], [80, 500, 220])
	assert_eq(_queue_names(s, 8), ["E", "C"], "ciclo 8: el nuevo E entra antes que C, que agotó el quantum")
	assert_eq(s.reasons[2], Scheduler.Reason.QUANTUM_ALONE, "ciclo 3: A agota el quantum con la cola vacía y sigue")


func test_practica_4_6_rr_q3() -> void:
	var s: Schedule = Scheduler.run(_data_a(), A.RR, 3)
	_check(s, "1-3 A, 4-5 B, 6-8 C, 9-11 D, 12-13 E, 14 D", [1, 4, 6, 9, 12], [3, 5, 8, 14, 13], [140, 460, 180])


func test_ejemplo_4_sjf() -> void:
	var s: Schedule = Scheduler.run(_data_a(), A.SJF)
	_check(s, "1-3 A, 4-5 B, 6-8 C, 9-10 E, 11-14 D", [1, 4, 6, 11, 9], [3, 5, 8, 14, 10], [120, 400, 120])
	assert_eq(_queue_names(s, 8), ["E", "D"])


func test_srt_con_datos_a_da_lo_mismo_que_sjf() -> void:
	var srt: Schedule = Scheduler.run(_data_a(), A.SRT)
	assert_eq(srt.segments(), Scheduler.run(_data_a(), A.SJF).segments())


func test_guiado_4_5_fifo() -> void:
	var data: Array = [_p("P1", 1, [4]), _p("P2", 2, [3]), _p("P3", 3, [2]), _p("P4", 6, [5])]
	var s: Schedule = Scheduler.run(data, A.FIFO)
	_check(s, "1-4 P1, 5-7 P2, 8-9 P3, 10-14 P4", [1, 5, 8, 10], [4, 7, 9, 14], [300, 650, 300])


func test_ejemplo_3_rr_con_es() -> void:
	var data: Array = [_p("A", 1, [3, 2, 1]), _p("B", 2, [2, 2, 2]), _p("C", 3, [2, 2, 2])]
	var s: Schedule = Scheduler.run(data, A.RR, 2)
	_check(s, "1-2 A, 3-4 B, 5-6 C, 7 A, 8-9 B, 10-11 C, 12 A", [1, 3, 5], [12, 9, 11], [100, 966, 366])
	assert_eq(Array(s.waits()), [6, 2, 3])
	assert_eq(_queue_names(s, 3), ["C", "A"], "ciclo 3: C, que es nuevo, antes que A")
	assert_eq(Array(s.io_cycles[1]), [5, 6])
	assert_eq(Array(s.io_cycles[2]), [7, 8])
	assert_eq(Array(s.io_cycles[0]), [8, 9])
	var row_a: String = ""
	for c: int in range(1, 13):
		row_a += s.mark(0, c) if s.mark(0, c) != "" else "."
	assert_eq(row_a, "XX....XWW..F")


func test_practica_4_7_rr_con_es_y_cpu_parada() -> void:
	var data: Array = [_p("P1", 1, [2, 2, 1]), _p("P2", 3, [3, 2, 1]), _p("P3", 4, [3, 2, 1])]
	var s: Schedule = Scheduler.run(data, A.RR, 2)
	_check(s, "1-2 P1, 3-4 P2, 5-6 P3, 7 P1, 8 P2, 9 P3, 10 -, 11 P2, 12 P3", [1, 3, 5], [7, 11, 12], [33, 833, 266])
	assert_eq(_queue_names(s, 5), ["P1", "P2"], "ciclo 5: vuelve P1 de E/S antes que P2, que agotó el quantum")
	assert_eq(s.timeline[9], -1)
	assert_eq(s.reasons[9], Scheduler.Reason.IDLE)


func test_ejemplo_5_sjf_frente_a_srt() -> void:
	var data: Array = [_p("P1", 1, [7]), _p("P2", 3, [3])]
	var sjf: Schedule = Scheduler.run(data, A.SJF)
	_check(sjf, "1-7 P1, 8-10 P2", [1, 8], [7, 10], [250, 750, 250])
	var srt: Schedule = Scheduler.run(data, A.SRT)
	_check(srt, "1-2 P1, 3-5 P2, 6-10 P1", [1, 3], [10, 5], [0, 650, 150])
	assert_eq(srt.reasons[2], Scheduler.Reason.PREEMPTS)


func test_practica_4_8_los_cuatro() -> void:
	_check(Scheduler.run(_data_48(), A.FIFO), "1-5 P1, 6-7 P2, 8-11 P3, 12 P4", [1, 6, 8, 12], [5, 7, 11, 12], [400, 700, 400])
	var rr: Schedule = Scheduler.run(_data_48(), A.RR, 2)
	_check(rr, "1-2 P1, 3-4 P2, 5-6 P3, 7-8 P1, 9 P4, 10-11 P3, 12 P1", [1, 3, 5, 9], [12, 4, 11, 9], [175, 725, 425])
	_check(Scheduler.run(_data_48(), A.SJF), "1-5 P1, 6 P4, 7-8 P2, 9-12 P3", [1, 7, 9, 6], [5, 8, 12, 6], [300, 600, 300])
	var srt: Schedule = Scheduler.run(_data_48(), A.SRT)
	_check(srt, "1 P1, 2-3 P2, 4 P1, 5 P4, 6-8 P1, 9-12 P3", [1, 2, 9, 5], [8, 3, 12, 5], [150, 525, 225])
	assert_eq(_queue_names(srt, 4), ["P3"], "ciclo 4: empate a 4 entre P1 y P3; entra P1, que estaba antes en la cola")


func test_repaso_problemas_1_2_3() -> void:
	_check(Scheduler.run(_data_repaso(), A.FIFO), "1-6 A, 7-9 B, 10 C, 11-14 D", [1, 7, 10, 11], [6, 9, 10, 14], [400, 750, 400])
	var rr: Schedule = Scheduler.run(_data_repaso(), A.RR, 2)
	_check(rr, "1-2 A, 3-4 B, 5-6 A, 7 C, 8 B, 9-10 D, 11-12 A, 13-14 D", [1, 3, 7, 9], [12, 8, 7, 14], [175, 800, 450])
	assert_eq(_queue_names(rr, 7), ["B", "D", "A"])
	_check(Scheduler.run(_data_repaso(), A.SJF), "1-6 A, 7 C, 8-10 B, 11-14 D", [1, 8, 7, 11], [6, 10, 7, 14], [350, 700, 350])


func test_medias_truncadas_como_el_libro() -> void:
	assert_eq(Scheduler.mean_hundredths(PackedInt32Array([12, 8, 9])), 966)
	assert_eq(Scheduler.format_hundredths(966), "9,66")
	assert_eq(Scheduler.format_hundredths(500), "5")
	assert_eq(Scheduler.format_hundredths(440), "4,4")
	assert_eq(Scheduler.format_hundredths(175), "1,75")
	assert_eq(Scheduler.format_hundredths(33), "0,33")
	assert_eq(Scheduler.format_hundredths(440, "."), "4.4")


func test_leer_lo_que_escribe_el_alumno() -> void:
	assert_eq(Scheduler.parse_hundredths("9,66"), 966)
	assert_eq(Scheduler.parse_hundredths(" 9.66 "), 966)
	assert_eq(Scheduler.parse_hundredths("4,4"), 440)
	assert_eq(Scheduler.parse_hundredths("5"), 500)
	assert_eq(Scheduler.parse_hundredths("0,333"), 33)
	assert_eq(Scheduler.parse_hundredths(""), -1)
	assert_eq(Scheduler.parse_hundredths("abc"), -1)
	assert_eq(Scheduler.parse_hundredths("-1"), -1)
	assert_eq(Scheduler.parse_hundredths("1,2,3"), -1)


func test_las_medias_se_pueden_escribir_como_fraccion() -> void:
	assert_eq(Scheduler.parse_hundredths("3/4"), 75)
	assert_eq(Scheduler.parse_hundredths("29/3"), 966, "truncada, como el libro")
	assert_eq(Scheduler.parse_hundredths(" 20 / 4 "), 500)
	assert_eq(Scheduler.parse_hundredths("3/0"), -1)
	assert_eq(Scheduler.parse_hundredths("3/4/2"), -1)
	assert_eq(Scheduler.parse_hundredths("a/4"), -1)
	assert_eq(Scheduler.parse_hundredths("-3/4"), -1)


func test_ciclos_de_decision() -> void:
	# Ejemplo 1 (FIFO): decide en el 9 (D o E) y en el 13 no (solo queda E).
	var fifo: Schedule = Scheduler.run(_data_a(), A.FIFO)
	assert_eq(fifo.decision_cycles(), [9] as Array[int])
	assert_eq(fifo.candidates(9), [3, 4] as Array[int])
	# Ejemplo 5 (SRT): en el 3 llega P2 y expulsa a P1.
	var srt: Schedule = Scheduler.run([_p("P1", 1, [7]), _p("P2", 3, [3])], A.SRT)
	assert_eq(srt.decision_cycles(), [3] as Array[int])
	assert_eq(srt.candidates(3), [1, 0] as Array[int])
	# SRT con los datos A: en el 7 y el 8 llega alguien y no expulsa; también se decide.
	var srt_a: Schedule = Scheduler.run(_data_a(), A.SRT)
	assert_true(srt_a.decision_cycles().has(7))
	assert_eq(srt_a.decided[6], 2)
