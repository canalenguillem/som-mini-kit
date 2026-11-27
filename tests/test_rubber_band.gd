extends GutTest
## RubberBand: suave y nunca por encima de ±8 %.


func test_sin_ventaja_no_cambia() -> void:
	assert_almost_eq(RubberBand.factor(0.0, 2.0, 0.08), 1.0, 0.0001)


func test_ia_muy_por_delante_baja_al_minimo() -> void:
	assert_almost_eq(RubberBand.factor(2.0, 2.0, 0.08), 0.92, 0.0001)
	assert_almost_eq(RubberBand.factor(50.0, 2.0, 0.08), 0.92, 0.0001, "no baja de 0.92")


func test_ia_muy_por_detras_sube_al_maximo() -> void:
	assert_almost_eq(RubberBand.factor(-2.0, 2.0, 0.08), 1.08, 0.0001)
	assert_almost_eq(RubberBand.factor(-50.0, 2.0, 0.08), 1.08, 0.0001, "no sube de 1.08")


func test_es_proporcional() -> void:
	assert_almost_eq(RubberBand.factor(1.0, 2.0, 0.08), 0.96, 0.0001)


func test_rango_invalido_no_hace_nada() -> void:
	assert_eq(RubberBand.factor(5.0, 0.0, 0.08), 1.0)
