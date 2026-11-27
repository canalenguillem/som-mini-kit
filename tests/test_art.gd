extends GutTest
## Arte: cada coche y rival tiene sprite, el coche lo muestra y el barril lo usa.

const CAR_PATH: String = "res://scenes/car/car.tscn"


func test_todos_los_coches_y_rivales_tienen_sprite() -> void:
	for id: String in Catalog.cars():
		assert_not_null((Catalog.cars()[id] as CarData).sprite, "coche %s" % id)
	for r: String in ["rayo", "bruto", "despiste"]:
		assert_not_null((load("res://data/rivals/%s.tres" % r) as RivalData).sprite, "rival %s" % r)


func test_el_coche_muestra_el_sprite_y_oculta_el_placeholder() -> void:
	var car: Car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	car.data = load("res://data/cars/buggy.tres") as CarData
	add_child_autofree(car)
	assert_true((car.get_node("Sprite") as Sprite2D).visible)
	assert_eq((car.get_node("Sprite") as Sprite2D).texture, car.data.sprite)
	assert_false((car.get_node("Body") as Polygon2D).visible)
	assert_false((car.get_node("Nose") as Polygon2D).visible)


func test_sin_sprite_se_usa_el_placeholder() -> void:
	var car: Car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	add_child_autofree(car)
	car.set_sprite(null)
	assert_false((car.get_node("Sprite") as Sprite2D).visible)
	assert_true((car.get_node("Body") as Polygon2D).visible)


func test_el_sprite_encaja_con_la_colision() -> void:
	var car: Car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(car)
	var sprite: Sprite2D = car.get_node("Sprite")
	# Rotado 90°: el lado largo de la textura queda a lo largo del eje x del coche (adelante)
	var length: float = sprite.texture.get_height() * sprite.scale.y
	var width: float = sprite.texture.get_width() * sprite.scale.x
	assert_between(length, 30.0, 42.0, "largo en px")
	assert_between(width, 14.0, 24.0, "ancho en px")


func test_barril_usa_sprite() -> void:
	var barrel: Node = add_child_autofree((load("res://scenes/obstacles/barrel.tscn") as PackedScene).instantiate())
	assert_not_null((barrel.get_node("Sprite") as Sprite2D).texture)


func test_licencia_del_pack_incluida() -> void:
	assert_true(FileAccess.file_exists("res://assets/kenney_racing/License.txt"))
