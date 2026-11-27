extends GutTest
## Salón con arrastres: cada movimiento es una transición; se valida con las reglas del libro.

const A := Scheduler.Algorithm
const Q := DispatchRound.QUEUE
const M := DispatchRound.MACHINE
const SN := DispatchRound.SNACK
const EX := DispatchRound.EXIT


func _p(name: String, arrival: int, bursts: Array) -> Dictionary:
	return {"name": name, "arrival": arrival, "bursts": bursts}


func _data_a() -> Array:
	return [_p("A", 1, [3]), _p("B", 4, [2]), _p("C", 5, [3]), _p("D", 7, [4]), _p("E", 8, [2])]


func _round(data: Array, algorithm: Scheduler.Algorithm, q: int = 2) -> DispatchRound:
	return DispatchRound.new(Scheduler.run(data, algorithm, q))


## Juega hasta el ciclo `c` (sin entrar en él) haciendo los movimientos correctos.
func _play_to(d: DispatchRound, c: int) -> void:
	while not d.over and not (d.cycle == c):
		if d.waiting():
			d.auto_move()
		else:
			d.advance()


func _keys(res: Dictionary) -> Array:
	var out: Array = []
	for m: Dictionary in res["msgs"]:
		out.append(m["key"])
	return out


func test_partida_completa_sin_fallos() -> void:
	for algorithm: int in [A.FIFO, A.RR, A.SJF, A.SRT]:
		var d: DispatchRound = _round(_data_a(), algorithm)
		var moves: int = 0
		while not d.over:
			if d.waiting():
				var m: Dictionary = d.auto_move()
				assert_ne(str(m["transition"]), "", "cada movimiento es una transición del diagrama")
				moves += 1
			else:
				d.advance()
			assert_lt(moves, 200)
		for z: String in d.zone:
			assert_eq(z, EX, "todos acaban en la salida")
		assert_eq(d.required, moves)
		assert_eq(d.errors, 0)
		assert_true(d.result().is_perfect())


func test_ciclo_1_entrar_en_la_cola_y_luego_jugar() -> void:
	var d: DispatchRound = _round(_data_a(), A.FIFO)
	assert_eq(d.pending.size(), 2)
	var r: Dictionary = d.try_move(0, M)
	assert_eq(_keys(r), ["DISP_DOOR_FIRST_QUEUE"], "primero Nuevo → Preparado")
	r = d.try_move(1, Q)
	assert_eq(_keys(r), ["DISP_NOT_ARRIVED"])
	r = d.try_move(0, Q)
	assert_true(r["ok"])
	assert_eq(r["transition"], "NEW_READY")
	r = d.try_move(0, M)
	assert_eq(r["transition"], "READY_RUNNING")
	assert_eq(d.errors, 2)


func test_rr_el_nuevo_antes_que_el_que_agota_el_quantum() -> void:
	# Ejemplo resuelto 3: en el ciclo 3 llega C y A agota el quantum; primero C, después A; entra B.
	var d: DispatchRound = _round([_p("A", 1, [3, 2, 1]), _p("B", 2, [2, 2, 2]), _p("C", 3, [2, 2, 2])], A.RR)
	_play_to(d, 3)
	assert_eq(d.event_of(0), "quantum")
	assert_eq(d.event_of(2), "arrive")
	assert_eq(_keys(d.try_move(1, M)), ["DISP_FIRST_CLEAR"], "la máquina sigue ocupada por A")
	assert_eq(_keys(d.try_move(0, Q)), ["DISP_QUEUE_ORDER"])
	assert_true(d.try_move(2, Q)["ok"])
	assert_eq(d.try_move(0, Q)["transition"], "RUNNING_READY")
	assert_true(d.try_move(1, M)["ok"])
	assert_eq(d.queue, [2, 0] as Array[int])


func test_bocadillos_y_la_trampa() -> void:
	var d: DispatchRound = _round([_p("A", 1, [3, 2, 1]), _p("B", 2, [2, 2, 2]), _p("C", 3, [2, 2, 2])], A.RR)
	_play_to(d, 5)
	assert_eq(d.event_of(1), "io")
	assert_eq(_keys(d.try_move(1, Q)), ["DISP_GOES_SNACK"])
	assert_eq(d.try_move(1, SN)["transition"], "RUNNING_BLOCKED")
	_play_to(d, 6)
	assert_eq(_keys(d.try_move(1, Q)), ["DISP_STILL_EATING"], "B come los ciclos 5 y 6")
	_play_to(d, 7)
	assert_eq(_keys(d.try_move(1, M)), ["DISP_TRAP"], "¡nunca directo a la CPU!")
	assert_eq(d.try_move(1, Q)["transition"], "BLOCKED_READY")


func test_srt_expulsar_o_no() -> void:
	# Ejemplo 5: en el 3 llega P2 (3) y a P1 le quedan 5: lo expulsa.
	var d: DispatchRound = _round([_p("P1", 1, [7]), _p("P2", 3, [3])], A.SRT)
	_play_to(d, 3)
	assert_true(d.try_move(1, Q)["ok"])
	assert_eq(d.try_move(0, Q)["transition"], "RUNNING_READY")
	assert_true(d.try_move(1, M)["ok"])
	# Datos A en SRT: en el 7 llega D (4) y a C le quedan 2: no lo expulsa.
	var e: DispatchRound = _round(_data_a(), A.SRT)
	_play_to(e, 7)
	assert_true(e.try_move(3, Q)["ok"])
	assert_eq(_keys(e.try_move(2, Q)), ["DISP_KEEPS_SRT"])
	assert_false(e.waiting(), "no queda nada: C sigue")


func test_sjf_elegir_mal_se_explica() -> void:
	var d: DispatchRound = _round(_data_a(), A.SJF)
	_play_to(d, 9)
	while d.pending.size() > 1:
		d.auto_move()
	var r: Dictionary = d.try_move(3, M)  # D en vez de E
	assert_eq(_keys(r), ["GANTT_CELL", "GANTT_REASON_SHORTEST"])
	assert_true(d.try_move(4, M)["ok"])


func test_no_expulsivo_no_se_saca_de_la_maquina() -> void:
	var d: DispatchRound = _round(_data_a(), A.FIFO)
	_play_to(d, 2)
	assert_eq(_keys(d.try_move(0, Q)), ["DISP_KEEPS_NONPREEMPTIVE"])
	_play_to(d, 4)
	assert_eq(_keys(d.try_move(0, Q)), ["DISP_GOES_EXIT"])
	assert_eq(d.try_move(0, EX)["transition"], "RUNNING_TERMINATED")


func test_calentamiento_sin_orden_estricto() -> void:
	var s: Schedule = Scheduler.run([_p("A", 1, [3, 2, 1]), _p("B", 2, [2, 2, 2]), _p("C", 3, [2, 2, 2])], A.RR)
	var d := DispatchRound.new(s, false)
	_play_to(d, 3)
	assert_true(d.try_move(0, Q)["ok"], "en el calentamiento el orden de la cola lo pone el juego")
	assert_true(d.try_move(2, Q)["ok"])
	assert_eq(d.queue, [1, 2, 0] as Array[int])


func test_los_fallos_cuentan_salvo_en_el_guiado() -> void:
	var d: DispatchRound = _round(_data_a(), A.FIFO)
	d.try_move(0, M, false)
	assert_eq(d.errors, 0)
	d.try_move(0, M)
	assert_eq(d.errors, 1)
	assert_eq(d.result().mistakes[0]["key"], "DISP_WRONG_MOVES")
