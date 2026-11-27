extends GutTest
## Cerrojo binario (misión de prueba): generador y corrector.


func test_200_es_11001000() -> void:
	var bits: Array[bool] = BinaryLock.bits_of(200)
	assert_eq(bits, [true, true, false, false, true, false, false, false] as Array[bool])
	assert_eq(BinaryLock.value_of(bits), 200)


func test_ida_y_vuelta_de_0_a_255() -> void:
	for v: int in 256:
		assert_eq(BinaryLock.value_of(BinaryLock.bits_of(v)), v)


func test_generador_determinista_y_en_rango() -> void:
	assert_eq(BinaryLock.generate(123456), BinaryLock.generate(123456))
	for s: int in range(100000, 100200):
		assert_between(BinaryLock.generate(s), 1, 255)


func test_pasos_del_metodo() -> void:
	var steps: Array[Dictionary] = BinaryLock.steps(200)
	assert_eq(steps.size(), 8)
	assert_eq(steps[0], {"weight": 128, "rest": 200, "on": true, "left": 72})
	assert_eq(steps[1], {"weight": 64, "rest": 72, "on": true, "left": 8})
	assert_eq(steps[2], {"weight": 32, "rest": 8, "on": false, "left": 8})
	assert_eq(steps[4], {"weight": 8, "rest": 8, "on": true, "left": 0})


func test_respuesta_correcta() -> void:
	var r: ChallengeResult = BinaryLock.evaluate(200, BinaryLock.bits_of(200))
	assert_true(r.is_perfect())
	assert_eq(r.correct, 8)
	assert_eq(r.mistakes.size(), 0)


func test_explica_el_primer_bit_que_falta() -> void:
	# 200 sin el 64: 10001000 = 136
	var r: ChallengeResult = BinaryLock.evaluate(200, BinaryLock.bits_of(136))
	assert_false(r.is_perfect())
	assert_eq(r.correct, 7)
	assert_eq(r.mistakes[0], {"key": "BIN_SUM_MISMATCH", "args": {"sum": 136, "target": 200}})
	assert_eq(r.mistakes[1], {"key": "BIN_BIT_SHOULD_BE_ON", "args": {"weight": 64, "rest": 72}})


func test_explica_el_primer_bit_que_sobra() -> void:
	# 72 con el 128 encendido: 11001000
	var r: ChallengeResult = BinaryLock.evaluate(72, BinaryLock.bits_of(200))
	assert_eq(r.mistakes[1], {"key": "BIN_BIT_SHOULD_BE_OFF", "args": {"weight": 128, "rest": 72}})


func test_mensajes_traducidos() -> void:
	GameState.set_locale("ca")
	var r: ChallengeResult = BinaryLock.evaluate(200, BinaryLock.bits_of(136))
	assert_eq(r.messages()[1], "El 64 cap en el que queda (72): encén-lo.")
	GameState.reset()
