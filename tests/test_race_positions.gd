extends GutTest
## RacePositions: la ordenación por progreso es correcta.

const N: int = 12


func test_mas_vueltas_gana() -> void:
	var a: float = RacePositions.score(2, 0, 0.0, N)
	var b: float = RacePositions.score(1, 11, 0.9, N)
	assert_gt(a, b)


func test_mismo_checkpoint_gana_la_fraccion() -> void:
	assert_gt(RacePositions.score(0, 3, 0.6, N), RacePositions.score(0, 3, 0.2, N))


func test_mayor_checkpoint_gana() -> void:
	assert_gt(RacePositions.score(1, 5, 0.0, N), RacePositions.score(1, 4, 0.99, N))


func test_parrilla_detras_de_la_meta() -> void:
	# antes de cruzar la meta la fracción es negativa: el de delante puntúa más
	assert_gt(RacePositions.score(0, 0, -0.1, N), RacePositions.score(0, 0, -0.3, N))


func test_fraccion_se_limita() -> void:
	assert_eq(RacePositions.score(0, 2, 5.0, N), RacePositions.score(0, 2, 1.0, N))


func test_orden() -> void:
	var scores: Array[float] = [3.2, 10.5, 7.0, 0.1]
	assert_eq(RacePositions.order(scores), [1, 2, 0, 3] as Array[int])


func test_empate_gana_el_indice_menor() -> void:
	var scores: Array[float] = [5.0, 5.0, 9.0]
	assert_eq(RacePositions.order(scores), [2, 0, 1] as Array[int])


func test_orden_vacio() -> void:
	var scores: Array[float] = []
	assert_eq(RacePositions.order(scores).size(), 0)
