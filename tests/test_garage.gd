extends GutTest
## El garaje se construye y las acciones llegan a GameState (se usa el GameState real, con guardado de pruebas).

const GARAGE_PATH: String = "res://scenes/ui/garage.tscn"

var _garage: Garage


func before_each() -> void:
	GameState.reset()
	GameState.current_track = null
	_garage = (load(GARAGE_PATH) as PackedScene).instantiate() as Garage
	add_child_autofree(_garage)
	await wait_physics_frames(2)


func after_each() -> void:
	GameState.reset()


func test_lista_los_tres_coches_y_cuatro_mejoras() -> void:
	assert_eq(_garage._car_list.get_child_count(), 3)
	assert_eq(_garage._upgrade_list.get_child_count(), 4)
	assert_eq(_garage._stats.get_child_count(), 4, "4 barras")


func test_mejorar_desde_el_garaje() -> void:
	GameState.add_money(500)
	_garage._refresh()
	_garage._on_upgrade_pressed("engine")
	assert_eq(GameState.upgrade_level("beetle", "engine"), 1)
	assert_eq(GameState.money, 300)
	assert_eq(_garage._money.text, "Monedas: 300")


func test_comprar_y_seleccionar_coche() -> void:
	GameState.add_money(1500)
	_garage._on_car_clicked("buggy")
	assert_eq(_garage._car_action.text, "Comprar (1500)")
	assert_false(_garage._car_action.disabled)
	_garage._on_car_action()
	assert_true(GameState.owned_cars.has("buggy"))
	assert_eq(GameState.selected_car, "buggy")


func test_no_deja_comprar_sin_dinero() -> void:
	_garage._on_car_clicked("sport")
	assert_true(_garage._car_action.disabled)
	_garage._on_car_action()
	assert_false(GameState.owned_cars.has("sport"))


func test_pistas_bloqueadas_ofrecen_desbloqueo() -> void:
	assert_eq(_garage._track_option.item_count, 1, "solo west_01 al empezar")
	assert_eq(_garage._unlock_list.get_child_count(), 3)
	GameState.add_money(400)
	_garage._on_unlock_pressed("west_02")
	assert_eq(_garage._track_option.item_count, 2)
	assert_eq(_garage._unlock_list.get_child_count(), 2)
