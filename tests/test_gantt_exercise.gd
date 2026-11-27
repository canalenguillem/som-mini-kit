extends GutTest
## Misión 4: generador y corrector de la cuadrícula y la tabla.

const A := Scheduler.Algorithm


func _ex(processes: Array, algorithm: Scheduler.Algorithm, quantum: int = 2) -> Dictionary:
	var s: Schedule = Scheduler.run(processes, algorithm, quantum)
	return {"algorithm": algorithm, "quantum": quantum, "processes": processes, "columns": s.cycles() + 2}


func _p(name: String, arrival: int, bursts: Array) -> Dictionary:
	return {"name": name, "arrival": arrival, "bursts": bursts}


## Ejemplo resuelto 5 del libro, con SRT.
func _ex5_srt() -> Dictionary:
	return _ex([_p("P1", 1, [7]), _p("P2", 3, [3])], A.SRT)


func _keys(r: ChallengeResult) -> Array:
	var out: Array = []
	for m: Dictionary in r.mistakes:
		out.append(m["key"])
	return out


func test_generador_determinista() -> void:
	var cfg: Dictionary = {"algorithm": A.RR}
	assert_eq(GanttExercise.generate(123456, cfg), GanttExercise.generate(123456, cfg))
	assert_ne(GanttExercise.generate(123456, cfg), GanttExercise.generate(654321, cfg))


func test_generador_respeta_las_reglas_del_libro() -> void:
	for algorithm: int in [A.FIFO, A.RR, A.SJF, A.SRT]:
		for seed: int in range(100000, 100030):
			var ex: Dictionary = GanttExercise.generate(seed, {"algorithm": algorithm})
			var s: Schedule = GanttExercise.solve(ex)
			assert_false(s.ambiguous, "sin empates que el libro no explica")
			assert_lte(s.cycles(), 16)
			var arrivals: Array = []
			for p: Dictionary in ex["processes"]:
				assert_false(arrivals.has(p["arrival"]), "sin llegadas a la vez")
				arrivals.append(p["arrival"])
			assert_eq(arrivals[0], 1)
			if algorithm == A.SRT:
				assert_true(s.reasons.has(Scheduler.Reason.PREEMPTS), "en SRT hay alguna expulsión")


func test_generador_con_es() -> void:
	for seed: int in range(100000, 100020):
		var ex: Dictionary = GanttExercise.generate(seed, {"algorithm": A.RR, "io": true})
		assert_eq((ex["processes"] as Array).size(), 3)
		assert_eq(((ex["processes"] as Array)[0]["bursts"] as Array).size(), 3)
		assert_lte(GanttExercise.solve(ex).cycles(), 16)


func test_la_solucion_saca_un_10() -> void:
	for algorithm: int in [A.FIFO, A.RR, A.SJF, A.SRT]:
		var ex: Dictionary = GanttExercise.generate(222222, {"algorithm": algorithm})
		var r: ChallengeResult = GanttExercise.evaluate(ex, GanttExercise.solution_answer(ex))
		assert_true(r.is_perfect(), "%s: %s" % [Scheduler.ALGORITHM_NAMES[algorithm], r.mistakes])
	var io: Dictionary = GanttExercise.generate(222222, {"algorithm": A.RR, "io": true})
	assert_true(GanttExercise.evaluate(io, GanttExercise.solution_answer(io)).is_perfect())


func test_solucion_del_ejemplo_5() -> void:
	var ans: Dictionary = GanttExercise.solution_answer(_ex5_srt())
	assert_eq(ans["grid"], [0, 0, 1, 1, 1, 0, 0, 0, 0, 0, -1, -1] as Array[int])
	assert_eq(ans["means"], {"response": "0", "service": "6,5", "wait": "1,5"})


func test_explica_la_expulsion_de_srt() -> void:
	var ex: Dictionary = _ex5_srt()
	var ans: Dictionary = GanttExercise.solution_answer(ex)
	ans["grid"] = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, -1, -1]  # lo de SJF: P1 no suelta la CPU
	var r: ChallengeResult = GanttExercise.evaluate(ex, ans)
	assert_eq(_keys(r).slice(0, 3), ["GANTT_WRONG_CELLS", "GANTT_CELL", "GANTT_REASON_PREEMPTS"])
	assert_eq(r.mistakes[1]["args"]["cycle"], 3)
	assert_eq(r.mistakes[1]["args"]["expected"], "P2")
	assert_eq(r.mistakes[2]["args"]["need"], 3)
	assert_eq(r.mistakes[2]["args"]["left"], 5)
	GameState.set_locale("es")
	assert_eq(r.messages()[1], "En el ciclo 3 le tocaba a P2, no a P1.")
	assert_eq(r.messages()[2], "P2 necesita 3 y a P1 le quedan 5: como 3 < 5, lo expulsa.")
	GameState.reset()


func test_cpu_parada() -> void:
	var data: Array = [_p("P1", 1, [2, 2, 1]), _p("P2", 3, [3, 2, 1]), _p("P3", 4, [3, 2, 1])]
	var ex: Dictionary = _ex(data, A.RR, 2)
	var ans: Dictionary = GanttExercise.solution_answer(ex)
	(ans["grid"] as Array)[9] = 1
	var r: ChallengeResult = GanttExercise.evaluate(ex, ans)
	assert_eq(r.mistakes[1]["key"], "GANTT_SHOULD_BE_IDLE")
	assert_eq(r.mistakes[1]["args"]["cycle"], 10)


func test_olvidar_el_mas_uno_del_servicio() -> void:
	var ex: Dictionary = _ex5_srt()
	var ans: Dictionary = GanttExercise.solution_answer(ex)
	ans["table"][0]["service"] = "9"  # 10 − 1 sin el +1
	var r: ChallengeResult = GanttExercise.evaluate(ex, ans)
	assert_true(_keys(r).has("GANTT_SERVICE_PLUS_ONE"))


func test_espera_sin_restar_la_es() -> void:
	var data: Array = [_p("A", 1, [3, 2, 1]), _p("B", 2, [2, 2, 2]), _p("C", 3, [2, 2, 2])]
	var ex: Dictionary = _ex(data, A.RR, 2)
	var ans: Dictionary = GanttExercise.solution_answer(ex)
	ans["table"][0]["wait"] = "8"  # 12 − 4, olvidando los 2 de E/S
	var r: ChallengeResult = GanttExercise.evaluate(ex, ans)
	assert_true(_keys(r).has("GANTT_WAIT_IO"))
	assert_eq(ans["means"]["service"], "9,66")


func test_redondear_la_media() -> void:
	var data: Array = [_p("A", 1, [3, 2, 1]), _p("B", 2, [2, 2, 2]), _p("C", 3, [2, 2, 2])]
	var ex: Dictionary = _ex(data, A.RR, 2)
	var ans: Dictionary = GanttExercise.solution_answer(ex)
	ans["means"]["service"] = "9,67"
	var r: ChallengeResult = GanttExercise.evaluate(ex, ans)
	assert_eq(_keys(r), ["GANTT_MEAN_ROUNDED_SERVICE"])
	assert_eq(r.correct, r.total - 1)


func test_error_arrastrado_de_la_cuadricula() -> void:
	# Cuadrícula de SJF en un ejercicio de SRT, con la tabla bien calculada a partir de ella.
	var ex: Dictionary = _ex5_srt()
	var sjf: Dictionary = GanttExercise.solution_answer(_ex([_p("P1", 1, [7]), _p("P2", 3, [3])], A.SJF))
	var r: ChallengeResult = GanttExercise.evaluate(ex, sjf)
	assert_false(r.is_perfect())
	for key: Variant in _keys(r):
		assert_false(str(key).begins_with("GANTT_RESPONSE") or str(key).begins_with("GANTT_SERVICE")
				or str(key).begins_with("GANTT_WAIT") or str(key).begins_with("GANTT_MEAN"),
				"la tabla coherente con su cuadrícula no se penaliza otra vez: %s" % key)
	assert_eq(r.mistakes[0]["key"], "GANTT_WRONG_CELLS")
	var wrong_cells: int = int(r.mistakes[0]["args"]["n"])
	assert_eq(r.correct, r.total - wrong_cells)


func test_respuesta_vacia_no_rompe() -> void:
	var r: ChallengeResult = GanttExercise.evaluate(_ex5_srt(), {})
	assert_false(r.is_perfect())
	assert_eq(r.total, 12 + 2 * 5 + 3)
	assert_lte(r.mistakes.size(), GanttExercise.MAX_MESSAGES + 1)
