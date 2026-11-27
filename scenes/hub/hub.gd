class_name Hub
extends Control
## Mapa de la placa base de TORRE-7: una zona por tema del cuaderno. Las zonas se abren en orden
## (Progress). Al tocar una abierta, el programa viaja por el bus y se abre el panel con sus salas.

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const MISSION_SHELL: String = "res://scenes/mission/mission_shell.tscn"
const ZONE_SIZE: Vector2 = Vector2(250, 84)

@export var zones: Array[ZoneData] = []

var _zone_buttons: Array[Button] = []
var _open_zone: int = -1

@onready var _back: Button = $Margin/Box/Top/Back
@onready var _student: Label = $Margin/Box/Top/Student
@onready var _board: BoardView = $Margin/Box/Board
@onready var _panel_layer: Control = $PanelLayer
@onready var _panel_title: Label = $PanelLayer/Panel/Box/Title
@onready var _panel_summary: Label = $PanelLayer/Panel/Box/Summary
@onready var _rooms: VBoxContainer = $PanelLayer/Panel/Box/Rooms
@onready var _panel_close: Button = $PanelLayer/Panel/Box/Close


func _ready() -> void:
	_back.pressed.connect(go_back)
	_panel_close.pressed.connect(close_zone)
	_panel_layer.visible = false
	_student.text = GameState.student_name
	var pts: Array[Vector2] = []
	for z: ZoneData in zones:
		pts.append(z.board_position)
	_board.points = pts
	_board.hub_index = maxi(zones.find(_zone_with_topic(4)), 0)
	_board.arrived.connect(_on_arrived)
	_board.resized.connect(_place_zones)
	for i: int in zones.size():
		var b := Button.new()
		b.custom_minimum_size = ZONE_SIZE
		b.size = ZONE_SIZE
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(select_zone.bind(i))
		_board.add_child(b)
		_zone_buttons.append(b)
	refresh()
	_place_zones()
	Events.locale_changed.connect(func(_l: String) -> void: refresh())
	var first_open: int = _first_open()
	(_zone_buttons[first_open] if first_open >= 0 else _back).grab_focus()


func _zone_with_topic(topic: int) -> ZoneData:
	for z: ZoneData in zones:
		if z.topic == topic:
			return z
	return null


func _first_open() -> int:
	for i: int in zones.size():
		if state_of(i) == Progress.State.OPEN:
			return i
	return -1


func state_of(i: int) -> Progress.State:
	return Progress.zone_state(zones, i, GameState.progress)


func refresh() -> void:
	for i: int in zones.size():
		var z: ZoneData = zones[i]
		var b: Button = _zone_buttons[i]
		var st: Progress.State = state_of(i)
		var status: String = ""
		match st:
			Progress.State.LOCKED:
				status = tr("ZONE_LOCKED")
			Progress.State.SOON:
				status = tr("ZONE_SOON")
			Progress.State.OPEN:
				status = tr("ZONE_ROOMS").format({"passed": Progress.rooms_passed(z, GameState.progress),
						"total": z.missions.size()})
			Progress.State.PASSED:
				status = tr("ZONE_PASSED").format({"grade": Grading.format_grade(
						Progress.zone_grade(z, GameState.progress), GameState.locale)})
		b.text = "%d · %s\n%s · %s" % [z.topic, tr(z.title_key), tr(z.component_key), status]
		b.disabled = st == Progress.State.LOCKED or st == Progress.State.SOON
		b.add_theme_color_override("font_disabled_color", Color(0.55, 0.6, 0.6))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.2, 0.1) if st == Progress.State.PASSED else Color(0.08, 0.08, 0.1)
		style.set_border_width_all(3)
		style.border_color = {Progress.State.OPEN: Color(0.98, 0.78, 0.2), Progress.State.PASSED: Color(0.4, 0.9, 0.4),
				Progress.State.LOCKED: Color(0.4, 0.4, 0.45), Progress.State.SOON: Color(0.3, 0.3, 0.35)}[st]
		style.set_corner_radius_all(4)
		for s: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(s, style)


func _place_zones() -> void:
	for i: int in _zone_buttons.size():
		var center: Vector2 = _board.to_px(zones[i].board_position)
		var pos: Vector2 = center - ZONE_SIZE / 2.0
		pos.x = clampf(pos.x, 4.0, maxf(_board.size.x - ZONE_SIZE.x - 4.0, 4.0))
		pos.y = clampf(pos.y, 4.0, maxf(_board.size.y - ZONE_SIZE.y - 4.0, 4.0))
		_zone_buttons[i].position = pos


func select_zone(i: int) -> void:
	var st: Progress.State = state_of(i)
	if st != Progress.State.OPEN and st != Progress.State.PASSED:
		return
	_board.travel_to(i)


func _on_arrived(i: int) -> void:
	open_zone(i)


func open_zone(i: int) -> void:
	_open_zone = i
	var z: ZoneData = zones[i]
	_panel_title.text = "%d · %s" % [z.topic, tr(z.title_key)]
	_panel_summary.text = tr("ZONE_SUMMARY").format({
		"passed": Progress.rooms_passed(z, GameState.progress), "total": z.missions.size(),
		"grade": Grading.format_grade(Progress.zone_grade(z, GameState.progress), GameState.locale)})
	for child: Node in _rooms.get_children():
		_rooms.remove_child(child)
		child.queue_free()
	for m: MissionData in z.missions:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name := Label.new()
		name.text = m.title_key
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_theme_font_size_override("font_size", 20)
		var info := Label.new()
		info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		info.add_theme_font_size_override("font_size", 18)
		var tries: int = Progress.attempts(GameState.progress, m.id)
		if tries == 0:
			info.text = tr("ROOM_NEW")
		else:
			info.text = tr("ROOM_BEST_ONE" if tries == 1 else "ROOM_BEST").format({"grade": Grading.format_grade(Progress.best(GameState.progress, m.id),
					GameState.locale), "attempts": tries})
			if Progress.mission_passed(GameState.progress, m.id):
				info.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
		var play := Button.new()
		play.text = "ROOM_PLAY"
		play.custom_minimum_size = Vector2(140, 44)
		play.add_theme_font_size_override("font_size", 20)
		play.pressed.connect(open_mission.bind(m))
		row.add_child(name)
		row.add_child(info)
		row.add_child(play)
		_rooms.add_child(row)
	_panel_layer.visible = true
	_panel_close.grab_focus()


func close_zone() -> void:
	_panel_layer.visible = false
	_board.lit = -1
	_board.dot = Vector2(-1, -1)
	if _open_zone >= 0:
		_zone_buttons[_open_zone].grab_focus()
	_open_zone = -1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _panel_layer.visible:
			close_zone()
		else:
			go_back()
		get_viewport().set_input_as_handled()


func open_mission(data: MissionData) -> void:
	GameState.current_mission = data
	get_tree().change_scene_to_file(MISSION_SHELL)


func go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
