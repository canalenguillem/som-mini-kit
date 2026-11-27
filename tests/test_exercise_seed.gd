extends GutTest
## Semillas: misma semilla, mismo ejercicio.


func test_misma_semilla_misma_secuencia() -> void:
	var a: RandomNumberGenerator = ExerciseSeed.rng(123456)
	var b: RandomNumberGenerator = ExerciseSeed.rng(123456)
	for i: int in 20:
		assert_eq(a.randi(), b.randi())


func test_semillas_distintas_dan_ejercicios_distintos() -> void:
	assert_ne(ExerciseSeed.rng(123456).randi(), ExerciseSeed.rng(123457).randi())


func test_semilla_nueva_tiene_seis_cifras() -> void:
	for i: int in 50:
		var s: int = ExerciseSeed.new_seed()
		assert_between(s, ExerciseSeed.MIN_SEED, ExerciseSeed.MAX_SEED)


func test_derivada_estable_y_distinta() -> void:
	assert_eq(ExerciseSeed.derive(123456, "guided"), ExerciseSeed.derive(123456, "guided"))
	assert_ne(ExerciseSeed.derive(123456, "guided"), ExerciseSeed.derive(123456, "example"))
	assert_ne(ExerciseSeed.derive(123456, "guided"), 123456)
	assert_true(ExerciseSeed.derive(999999, "x") >= 0)
