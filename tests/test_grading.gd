extends GutTest
## Nota de misión: 70 % aciertos, 20 % intentos, 10 % pistas.

var w: GradingWeights


func before_each() -> void:
	w = load("res://data/grading/default.tres") as GradingWeights


func test_pesos_por_defecto() -> void:
	assert_almost_eq(w.accuracy, 0.7, 0.001)
	assert_almost_eq(w.attempts, 0.2, 0.001)
	assert_almost_eq(w.hints, 0.1, 0.001)
	assert_almost_eq(w.pass_grade, 5.0, 0.001)


func test_perfecto_a_la_primera_sin_pistas_es_10() -> void:
	assert_almost_eq(Grading.grade(8, 8, 0, 0, 2, w), 10.0, 0.001)


func test_en_blanco_es_0() -> void:
	assert_almost_eq(Grading.grade(0, 8, 0, 0, 2, w), 0.0, 0.001)


func test_cada_comprobacion_fallida_resta() -> void:
	assert_almost_eq(Grading.grade(8, 8, 1, 0, 2, w), 9.5, 0.001)  # 0,7 + 0,2·0,75 + 0,1
	assert_almost_eq(Grading.grade(8, 8, 4, 0, 2, w), 8.0, 0.001)  # intentos agotados
	assert_almost_eq(Grading.grade(8, 8, 10, 0, 2, w), 8.0, 0.001)  # no baja de ahí


func test_pistas_restan_en_proporcion() -> void:
	assert_almost_eq(Grading.grade(8, 8, 0, 1, 2, w), 9.5, 0.001)
	assert_almost_eq(Grading.grade(8, 8, 0, 2, 2, w), 9.0, 0.001)
	assert_almost_eq(Grading.grade(8, 8, 0, 0, 0, w), 10.0, 0.001, "sin pistas disponibles no resta")


func test_aciertos_parciales_escalan_todo() -> void:
	assert_almost_eq(Grading.grade(4, 8, 0, 0, 2, w), 5.0, 0.001)
	assert_almost_eq(Grading.grade(6, 8, 2, 1, 2, w), 6.4, 0.001)  # 0,75·(0,7 + 0,2·0,5 + 0,1·0,5)·10 = 6,375


func test_aprobado() -> void:
	assert_true(Grading.passed(5.0, w))
	assert_false(Grading.passed(4.9, w))


func test_total_cero_no_rompe() -> void:
	assert_eq(Grading.grade(0, 0, 0, 0, 0, w), 0.0)


func test_formato_de_la_nota() -> void:
	assert_eq(Grading.format_grade(7.5, "ca"), "7,5")
	assert_eq(Grading.format_grade(7.5, "es"), "7,5")
	assert_eq(Grading.format_grade(7.5, "en"), "7.5")
	assert_eq(Grading.format_grade(10.0, "ca"), "10,0")
