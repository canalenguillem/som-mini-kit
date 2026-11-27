extends GutTest
## Sala recreativa: decisiones y tabla corta.

const A := Scheduler.Algorithm


func _p(name: String, arrival: int, bursts: Array) -> Dictionary:
	return {"name": name, "arrival": arrival, "bursts": bursts}


func _ex(processes: Array, algorithm: Scheduler.Algorithm, quantum: int = 2) -> Dictionary:
	var s: Schedule = Scheduler.run(processes, algorithm, quantum)
	return {"algorithm": algorithm, "quantum": quantum, "processes": processes, "columns": s.cycles() + 2}


func _ex5_srt() -> Dictionary:
	return _ex([_p("P1", 1, [7]), _p("P2", 3, [3])], A.SRT)


func test_la_solucion_saca_un_10() -> void:
	for algorithm: int in [A.FIFO, A.RR, A.SJF, A.SRT]:
		var ex: Dictionary = GanttExercise.generate(333333, {"algorithm": algorithm})
		var r: ChallengeResult = ArcadeRound.evaluate(ex, ArcadeRound.solution_answer(ex))
		assert_true(r.is_perfect(), str(r.mistakes))
		assert_gt(GanttExercise.solve(ex).decision_cycles().size(), 0, "hay algo que decidir")


func test_decision_correcta_y_equivocada() -> void:
	var s: Schedule = GanttExercise.solve(_ex5_srt())
	assert_eq(ArcadeRound.decide(s, 3, 1), [] as Array[Dictionary])
	var msgs: Array[Dictionary] = ArcadeRound.decide(s, 3, 0)
	assert_eq(msgs[0]["key"], "GANTT_CELL")
	assert_eq(msgs[1]["key"], "GANTT_REASON_PREEMPTS")


func test_nota_de_las_decisiones() -> void:
	var ex: Dictionary = _ex5_srt()
	var ans: Dictionary = ArcadeRound.solution_answer(ex)
	ans["picks"] = {3: 0}
	var r: ChallengeResult = ArcadeRound.evaluate(ex, ans)
	assert_eq(r.total, 1 + 2 * 2 + 1)
	assert_eq(r.correct, r.total - 1)
	assert_eq(r.mistakes[0], {"key": "ARCADE_WRONG_DECISIONS", "args": {"n": 1, "total": 1}})
	assert_false(r.can_improve, "con la tabla bien, la decisión ya no tiene arreglo")
	ans["table"][0]["wait"] = "9"
	assert_true(ArcadeRound.evaluate(ex, ans).can_improve)


func test_tabla_corta_con_sus_avisos() -> void:
	var data: Array = [_p("A", 1, [3, 2, 1]), _p("B", 2, [2, 2, 2]), _p("C", 3, [2, 2, 2])]
	var ex: Dictionary = _ex(data, A.RR, 2)
	var ans: Dictionary = ArcadeRound.solution_answer(ex)
	assert_eq(ans["mean_wait"], "3,66")
	ans["table"][0]["service"] = "11"  # 12 − 1 sin el +1
	ans["table"][1]["wait"] = "4"  # 8 − 2 − 2 = 2; sin restar la E/S: 4
	ans["mean_wait"] = "3,67"
	var keys: Array = []
	for m: Dictionary in ArcadeRound.evaluate(ex, ans).mistakes:
		keys.append(m["key"])
	assert_true(keys.has("GANTT_SERVICE_PLUS_ONE"))
	assert_true(keys.has("GANTT_WAIT_IO"))


func test_espera_media_redondeada() -> void:
	var data: Array = [_p("A", 1, [3, 2, 1]), _p("B", 2, [2, 2, 2]), _p("C", 3, [2, 2, 2])]
	var ex: Dictionary = _ex(data, A.RR, 2)
	var ans: Dictionary = ArcadeRound.solution_answer(ex)
	ans["mean_wait"] = "3,67"
	var r: ChallengeResult = ArcadeRound.evaluate(ex, ans)
	assert_eq(r.mistakes[0]["key"], "GANTT_MEAN_ROUNDED_WAIT")


func test_vacio_no_rompe() -> void:
	var r: ChallengeResult = ArcadeRound.evaluate(_ex5_srt(), {})
	assert_eq(r.correct, 0)
