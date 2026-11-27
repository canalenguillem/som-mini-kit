extends GutTest
## Efectos del coche y de la cámara: marcas de derrape, partículas, ruedas, zoom y sacudida.

const CAR_PATH: String = "res://scenes/car/car.tscn"
const DT: float = 1.0 / 60.0

var _car: Car
var _fx: CarFx
var _asphalt: SurfaceData
var _dirt: SurfaceData


func before_each() -> void:
	_car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	_car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(_car)
	_fx = _car.get_node("Fx") as CarFx
	_asphalt = load("res://data/surfaces/asphalt.tres") as SurfaceData
	_dirt = load("res://data/surfaces/dirt.tres") as SurfaceData


func test_derrapar_dibuja_marcas_y_rodar_recto_no() -> void:
	for i: int in 10:
		_fx.update_state(DT, 300.0, 0.0, 0.0, _asphalt, false)
	assert_false(_fx.skidding)
	assert_eq(_fx.skid_line_count(), 0)
	for i: int in 10:
		_car.global_position += Vector2(5, 0)
		_fx.update_state(DT, 300.0, 150.0, 0.5, _asphalt, false)
	assert_true(_fx.skidding)
	assert_eq(_fx.skid_line_count(), 2, "un trazo por rueda trasera")
	assert_eq((_fx.get_children().filter(func(n: Node) -> bool: return n is Line2D)[0] as Line2D).get_point_count(), 10)


func test_dejar_de_derrapar_corta_el_trazo() -> void:
	_fx.update_state(DT, 300.0, 150.0, 0.0, _asphalt, false)
	_fx.update_state(DT, 300.0, 0.0, 0.0, _asphalt, false)
	_fx.update_state(DT, 300.0, 150.0, 0.0, _asphalt, false)
	assert_eq(_fx.skid_line_count(), 4, "dos derrapes = dos trazos por rueda")


func test_reaparecer_corta_el_trazo() -> void:
	_fx.update_state(DT, 300.0, 150.0, 0.0, _asphalt, false)
	_fx.reset()
	_fx.update_state(DT, 300.0, 150.0, 0.0, _asphalt, false)
	assert_eq(_fx.skid_line_count(), 4)


func test_los_trazos_tienen_limite() -> void:
	for i: int in 200:
		_fx.update_state(DT, 300.0, 150.0, 0.0, _asphalt, false)
		_fx.reset()  # cada fotograma abre un trazo nuevo
	assert_lte(_fx.skid_line_count(), _fx.skid_max_lines)


func test_trazo_largo_se_parte_en_otro() -> void:
	for i: int in _fx.skid_max_points + 5:
		_fx.update_state(DT, 300.0, 150.0, 0.0, _asphalt, false)
	assert_eq(_fx.skid_line_count(), 4)


func test_polvo_segun_superficie() -> void:
	_fx.update_state(DT, 300.0, 0.0, 0.0, _asphalt, false)
	assert_false(_fx.dust_active, "asfalto rodando: sin polvo")
	_fx.update_state(DT, 300.0, 0.0, 0.0, _dirt, false)
	assert_true(_fx.dust_active, "tierra: polvo")
	assert_eq(_fx.get_node("Dust").color, _dirt.particles_color)
	_fx.update_state(DT, 10.0, 0.0, 0.0, _dirt, false)
	assert_false(_fx.dust_active, "casi parado: sin polvo")
	_fx.update_state(DT, 300.0, 150.0, 0.0, _asphalt, false)
	assert_true(_fx.dust_active, "derrape en asfalto: humo")


func test_nitro_enciende_la_llama() -> void:
	_fx.update_state(DT, 300.0, 0.0, 0.0, _asphalt, false)
	assert_false((_fx.get_node("Nitro") as CPUParticles2D).emitting)
	_fx.update_state(DT, 300.0, 0.0, 0.0, _asphalt, true)
	assert_true((_fx.get_node("Nitro") as CPUParticles2D).emitting)


func test_ruedas_delanteras_giran_con_el_volante() -> void:
	_fx.update_state(DT, 100.0, 0.0, 1.0, _asphalt, false)
	assert_almost_eq((_fx.get_node("WheelFL") as Node2D).rotation, _fx.max_wheel_angle, 0.0001)
	assert_almost_eq((_fx.get_node("WheelFR") as Node2D).rotation, _fx.max_wheel_angle, 0.0001)
	assert_eq((_fx.get_node("WheelRL") as Node2D).rotation, 0.0, "las traseras no giran")


func test_la_banda_de_la_rueda_avanza_con_la_velocidad() -> void:
	var stripe: Node2D = _fx.get_node("WheelRL/Stripe")
	_fx.update_state(DT, 0.0, 0.0, 0.0, _asphalt, false)
	var parado: float = stripe.position.x
	_fx.update_state(DT, 120.0, 0.0, 0.0, _asphalt, false)
	assert_ne(stripe.position.x, parado)


func test_el_coche_alimenta_los_efectos_en_marcha() -> void:
	_car.velocity = Vector2(0, 250)  # lateral puro: derrapa
	_car._physics_process(DT)
	assert_true(_fx.skidding)


# --- Cámara ---

func _camera() -> FollowCamera:
	var cam := FollowCamera.new()
	cam.target = _car
	add_child_autofree(cam)
	return cam


func test_choque_fuerte_sacude_y_leve_no() -> void:
	var cam: FollowCamera = _camera()
	_car.crashed.emit(100.0)
	assert_eq(cam.trauma, 0.0, "impacto leve")
	_car.crashed.emit(600.0)
	assert_gt(cam.trauma, 0.9)


func test_la_sacudida_se_apaga_sola() -> void:
	var cam: FollowCamera = _camera()
	cam.add_trauma(1.0)
	cam._process(DT)
	assert_gt(cam.offset.length(), 0.0)
	assert_lte(cam.offset.length(), cam.max_shake * 1.5)
	for i: int in 120:
		cam._process(DT)
	assert_eq(cam.trauma, 0.0)
	assert_eq(cam.offset, Vector2.ZERO)


func test_zoom_se_aleja_con_la_velocidad() -> void:
	var cam: FollowCamera = _camera()
	_car.velocity = Vector2.ZERO
	for i: int in 120:
		cam._process(DT)
	assert_almost_eq(cam.zoom.x, 1.0, 0.01)
	_car.velocity = Vector2(500, 0)
	for i: int in 300:
		cam._process(DT)
	assert_almost_eq(cam.zoom.x, cam.min_zoom, 0.01)


func test_cambiar_de_objetivo_desconecta_el_anterior() -> void:
	var cam: FollowCamera = _camera()
	cam.target = null
	_car.crashed.emit(600.0)
	assert_eq(cam.trauma, 0.0)
