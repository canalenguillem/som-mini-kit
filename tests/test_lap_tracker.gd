extends GutTest
## LapTracker: vueltas en orden, checkpoints saltados no cuentan, marcha atrás no suma.

const N: int = 6

var _t: LapTracker


func before_each() -> void:
	_t = LapTracker.new(N, 3)


func _lap(from: int = 1) -> void:
	for i: int in range(from, N):
		_t.passed(i)
	_t.passed(0)


func test_empieza_sin_vueltas_y_con_la_meta_pasada() -> void:
	assert_eq(_t.laps, 0)
	assert_eq(_t.last_checkpoint, 0)
	assert_false(_t.finished)


func test_vuelta_en_orden() -> void:
	for i: int in range(1, N):
		assert_true(_t.passed(i), "cp %d" % i)
	assert_eq(_t.laps, 0)
	assert_true(_t.passed(0))
	assert_eq(_t.laps, 1)


func test_saltarse_un_checkpoint_no_cuenta() -> void:
	_t.passed(1)
	assert_false(_t.passed(3))
	assert_eq(_t.last_checkpoint, 1)
	for i: int in range(3, N):
		_t.passed(i)
	_t.passed(0)
	assert_eq(_t.laps, 0, "sin el cp 2 no hay vuelta")


func test_repetir_el_mismo_no_cuenta() -> void:
	_t.passed(1)
	assert_false(_t.passed(1))
	assert_eq(_t.last_checkpoint, 1)


func test_cruzar_la_meta_al_salir_no_suma() -> void:
	assert_false(_t.passed(0))
	assert_eq(_t.laps, 0)


func test_marcha_atras_no_suma() -> void:
	_t.passed(1)
	_t.passed(2)
	# retrocede sobre 2 y 1, y vuelve a avanzar sobre 1 y 2
	for i: int in [2, 1, 1, 2]:
		assert_false(_t.passed(i))
	assert_eq(_t.last_checkpoint, 2)
	assert_true(_t.passed(3), "al seguir adelante se retoma")


func test_retroceder_sobre_la_meta_no_regala_vuelta() -> void:
	_lap()  # 1 vuelta
	assert_false(_t.passed(N - 1))
	assert_eq(_t.laps, 1)


func test_termina_al_completar_las_vueltas() -> void:
	_lap()
	_lap()
	assert_false(_t.finished)
	_lap()
	assert_eq(_t.laps, 3)
	assert_true(_t.finished)
	assert_false(_t.passed(1), "terminado: ya no cuenta")


func test_senal_de_vuelta() -> void:
	watch_signals(_t)
	_lap()
	assert_signal_emit_count(_t, "lap_completed", 1)
	assert_signal_emitted_with_parameters(_t, "lap_completed", [1])
