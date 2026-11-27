extends GutTest
## Física del coche con un controlador falso (sin pista: asfalto por defecto).

const CAR_PATH: String = "res://scenes/car/car.tscn"
const DT: float = 1.0 / 60.0

var _car: Car
var _ctrl: FakeController


class FakeController extends CarController:
	var next: DriveInput = DriveInput.new()

	func get_input(_delta: float) -> DriveInput:
		var out: DriveInput = next
		next = DriveInput.new()  # nitro/reset son de un solo frame
		return out


func before_each() -> void:
	_car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	_car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(_car)
	_ctrl = autofree(FakeController.new()) as FakeController
	_car.controller = _ctrl
	_ctrl.owner_car = _car


func _run(seconds: float, throttle: float, steer: float = 0.0, brake: float = 0.0) -> void:
	for i: int in roundi(seconds / DT):
		var inp := DriveInput.new()
		inp.throttle = throttle
		inp.steer = steer
		inp.brake = brake
		_ctrl.next = inp
		_car._physics_process(DT)


func test_acelera_hasta_velocidad_maxima_sin_pasarse() -> void:
	_run(6.0, 1.0)
	var speed: float = _car.velocity.length()
	assert_lte(speed, _car.stats.max_speed + 0.5)
	assert_gt(speed, _car.stats.max_speed * 0.95)


func test_parado_no_gira() -> void:
	_run(1.0, 0.0, 1.0)
	assert_almost_eq(_car.rotation, 0.0, 0.0001)


func test_en_marcha_gira_hacia_el_lado_pedido() -> void:
	_run(2.0, 1.0)
	var before: float = _car.rotation
	_run(0.5, 1.0, 1.0)
	assert_gt(_car.rotation, before)


func test_frenar_detiene_y_luego_marcha_atras() -> void:
	_run(3.0, 1.0)
	_run(6.0, 0.0, 0.0, 1.0)
	var fwd: float = _car.velocity.dot(_car.transform.x)
	assert_lt(fwd, 0.0, "va hacia atrás")
	assert_gte(fwd, -_car.stats.max_reverse - 0.5)


func test_agarre_elimina_velocidad_lateral() -> void:
	_car.velocity = Vector2(0, 200)  # puro lateral
	_run(1.0, 0.0)
	assert_lt(absf(_car.velocity.dot(_car.transform.y)), 5.0)


func test_nitro_consume_carga_y_supera_el_maximo_normal() -> void:
	_run(6.0, 1.0)
	assert_eq(_car.nitro_charges, 1)
	var inp := DriveInput.new()
	inp.throttle = 1.0
	inp.nitro = true
	_ctrl.next = inp
	_car._physics_process(DT)
	assert_eq(_car.nitro_charges, 0)
	assert_true(_car.is_boosting())
	_run(1.2, 1.0)
	assert_gt(_car.velocity.length(), _car.stats.max_speed * 1.1)


func test_sin_cargas_el_nitro_no_se_activa() -> void:
	_car.nitro_charges = 0
	var inp := DriveInput.new()
	inp.nitro = true
	_ctrl.next = inp
	_car._physics_process(DT)
	assert_false(_car.is_boosting())
