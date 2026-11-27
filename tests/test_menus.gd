extends GutTest
## Menús: se construyen, reflejan el estado y la pausa funciona. El volumen se guarda.

const SaveSystemScript: GDScript = preload("res://autoload/save_system.gd")
const GameStateScript: GDScript = preload("res://autoload/game_state.gd")


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	get_tree().paused = false
	GameState.reset()


func _scene(path: String) -> Node:
	return add_child_autofree((load(path) as PackedScene).instantiate())


func test_menu_principal() -> void:
	var menu: MainMenu = _scene("res://scenes/ui/main_menu.tscn") as MainMenu
	await wait_physics_frames(2)
	assert_false(menu._championship.disabled)
	assert_false(menu._options_layer.visible)
	menu._on_options_pressed()
	assert_true(menu._options_layer.visible)
	assert_false(menu._menu.visible)
	menu._on_options_closed()
	assert_true(menu._menu.visible)


func test_seleccion_de_pista_muestra_bloqueos_y_records() -> void:
	GameState.best_times["west_01"] = 83.42
	var sel: TrackSelect = _scene("res://scenes/ui/track_select.tscn") as TrackSelect
	await wait_physics_frames(2)
	assert_eq(sel._list.get_child_count(), 4)
	var enabled: int = 0
	for b: Button in sel._list.get_children():
		if not b.disabled:
			enabled += 1
	assert_eq(enabled, 1, "solo la pista gratuita")
	var first: Button = sel._list.get_child(0)
	assert_string_contains(first.text, "Cañón del Coyote")
	assert_string_contains(first.text, "1:23.42")
	assert_string_contains((sel._list.get_child(1) as Button).text, "bloqueada")


func test_pista_desbloqueada_se_puede_elegir() -> void:
	GameState.money = 400
	GameState.unlock_track("west_02")
	var sel: TrackSelect = _scene("res://scenes/ui/track_select.tscn") as TrackSelect
	await wait_physics_frames(2)
	var enabled: int = 0
	for b: Button in sel._list.get_children():
		if not b.disabled:
			enabled += 1
	assert_eq(enabled, 2)


func test_pausa_para_y_reanuda_el_juego() -> void:
	var pause: PauseMenu = _scene("res://scenes/race/pause_menu.tscn") as PauseMenu
	await wait_physics_frames(1)
	assert_false(pause.visible)
	pause.toggle()
	assert_true(pause.visible)
	assert_true(get_tree().paused)
	pause.toggle()
	assert_false(pause.visible)
	assert_false(get_tree().paused)


func test_no_se_puede_pausar_tras_terminar() -> void:
	var pause: PauseMenu = _scene("res://scenes/race/pause_menu.tscn") as PauseMenu
	await wait_physics_frames(1)
	pause.can_pause = false
	pause.toggle()
	assert_false(pause.visible)
	assert_false(get_tree().paused)


func test_la_pausa_responde_a_la_accion() -> void:
	var pause: PauseMenu = _scene("res://scenes/race/pause_menu.tscn") as PauseMenu
	await wait_physics_frames(1)
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	pause._unhandled_input(ev)
	assert_true(pause.visible)
	pause.close()


func test_opciones_cambian_el_volumen() -> void:
	var panel: OptionsPanel = _scene("res://scenes/ui/options_panel.tscn") as OptionsPanel
	await wait_physics_frames(1)
	panel._slider.value = 0.5
	assert_almost_eq(GameState.master_volume, 0.5, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 0.01)
	assert_eq(panel._value.text, "50 %")
	panel._slider.value = 0.0
	assert_true(AudioServer.is_bus_mute(0))


func test_el_volumen_se_guarda_y_se_corrige() -> void:
	var gs: Node = autofree(GameStateScript.new())
	gs.load_catalog()
	gs.reset()
	var save: Node = autofree(SaveSystemScript.new())
	var path: String = "user://test_save_volume.json"
	gs.master_volume = 0.3
	assert_eq(save.save_to(gs, path), OK)
	var other: Node = autofree(GameStateScript.new())
	other.load_catalog()
	other.reset()
	assert_true(save.load_from(other, path))
	assert_almost_eq(other.master_volume, 0.3, 0.001)
	other.from_dict({"master_volume": 7.5})
	assert_eq(other.master_volume, 1.0, "se limita a 0..1")
	other.from_dict({"master_volume": "alto"})
	assert_eq(other.master_volume, 1.0, "mal tipado: se ignora")
	DirAccess.remove_absolute(path)
	GameState.master_volume = 1.0
