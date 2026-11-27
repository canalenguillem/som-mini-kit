class_name ArcadeHall
extends Control
## El salón recreativo dibujado: pared con letrero de neón, suelo de baldosas, puerta (llegan),
## cola delante de la máquina, la recreativa (la CPU), la barra de bocadillos (E/S) y la salida.
## ArcadeRoom le pasa el estado de cada ciclo con show_state(); los jugadores caminan solos.

signal player_pressed(index: int)

const CHARACTERS: Array[String] = ["femalePerson", "malePerson", "femaleAdventurer", "maleAdventurer", "robot"]
const QUEUE_SPACING: float = 74.0

@export var color_wall: Color = Color(0.13, 0.08, 0.2)
@export var color_floor_a: Color = Color(0.2, 0.16, 0.26)
@export var color_floor_b: Color = Color(0.17, 0.13, 0.22)
@export var color_neon: Color = Color(0.98, 0.35, 0.75)
@export var color_cabinet: Color = Color(0.28, 0.12, 0.45)
@export var color_screen_off: Color = Color(0.05, 0.08, 0.1)
@export var color_screen_on: Color = Color(0.1, 0.35, 0.45)
@export var color_counter: Color = Color(0.45, 0.28, 0.15)
@export var color_text: Color = Color(0.92, 0.94, 0.97)
@export var color_label: Color = Color(0.95, 0.75, 0.2)

var players: Array[ArcadePlayer] = []
var screen_lines: PackedStringArray = []  ## lo que sale en la pantalla de la máquina
var machine_busy: bool = false
var _time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 230)
	clip_contents = true


## Crea un jugador por nombre (Ana, Biel…).
func setup(labels: PackedStringArray) -> void:
	for p: ArcadePlayer in players:
		p.queue_free()
	players.clear()
	for i: int in labels.size():
		var p := ArcadePlayer.new()
		p.character = CHARACTERS[i % CHARACTERS.size()]
		p.label = labels[i]
		p.pressed.connect(func() -> void: player_pressed.emit(i))
		add_child(p)
		players.append(p)


## state[i] = {zone: "entrance"|"queue"|"machine"|"snack"|"done", slot: int, tokens, patience, tappable}
func show_state(state: Array, instant: bool = false) -> void:
	var slots: Dictionary = {}
	for i: int in mini(state.size(), players.size()):
		var s: Dictionary = state[i]
		var p: ArcadePlayer = players[i]
		var zone: String = str(s.get("zone", "entrance"))
		var slot: int = int(s.get("slot", 0))
		p.tokens = int(s.get("tokens", 0))
		p.patience = float(s.get("patience", 1.0))
		p.tappable = bool(s.get("tappable", false))
		p.show_patience = zone == "queue" or zone == "machine" or zone == "snack"
		p.dimmed = zone == "entrance"
		p.pose = _pose_for(zone, p.patience)
		p.walk_to(spot(zone, slot) - Vector2(p.size.x / 2.0, p.size.y), instant)
		slots[zone] = int(slots.get(zone, 0)) + 1
	queue_redraw()


func _pose_for(zone: String, patience: float) -> String:
	match zone:
		"machine":
			return "back"
		"snack":
			return "hold"
		"done":
			return "cheer0"
		"queue":
			return "think" if patience < 0.35 else "side"
	return "idle"


# --- Geometría del salón (todo relativo al tamaño) ---

func floor_y() -> float:
	return size.y * 0.62


func machine_rect() -> Rect2:
	var w: float = 120.0
	var h: float = floor_y() + 10.0 - 8.0  # del techo (con margen) al suelo
	return Rect2(size.x * 0.48, 8.0, w, h)


func counter_rect() -> Rect2:
	return Rect2(size.x * 0.64, floor_y() - 30.0, size.x * 0.15, 52.0)


## Punto de los pies del jugador en una zona.
func spot(zone: String, slot: int) -> Vector2:
	var feet_y: float = size.y - 6.0
	match zone:
		"entrance":
			return Vector2(34.0 + slot * 40.0, feet_y - 6.0)
		"queue":
			return Vector2(machine_rect().position.x - 40.0 - slot * QUEUE_SPACING, feet_y)
		"machine":
			return Vector2(machine_rect().get_center().x, feet_y)
		"snack":
			return Vector2(counter_rect().position.x + 40.0 + slot * 56.0, feet_y)
		"done":
			return Vector2(size.x - 40.0 - slot * 46.0, feet_y)
	return Vector2(size.x / 2.0, feet_y)


func _process(delta: float) -> void:
	_time += delta
	if machine_busy:
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var fy: float = floor_y()
	# Pared y suelo
	draw_rect(Rect2(0, 0, size.x, fy), color_wall)
	var tile: float = 32.0
	var row: int = 0
	var y: float = fy
	while y < size.y:
		var x: float = -tile * (row % 2) / 2.0
		var col: int = 0
		while x < size.x:
			draw_rect(Rect2(x, y, tile, tile), color_floor_a if (col + row) % 2 == 0 else color_floor_b)
			x += tile
			col += 1
		y += tile
		row += 1
	draw_line(Vector2(0, fy), Vector2(size.x, fy), Color(0.4, 0.25, 0.55), 3.0)
	# Letrero de neón
	_text(font, tr("ARCADE_SIGN"), Vector2(size.x * 0.25, 34.0), 24, color_neon)
	# Puerta (llegan)
	var door := Rect2(8.0, fy - 120.0, 86.0, 120.0)
	draw_rect(door, Color(0.08, 0.05, 0.12))
	draw_rect(door, Color(0.5, 0.35, 0.7), false, 3.0)
	_text(font, tr("ARCADE_ENTRANCE"), Vector2(door.get_center().x, door.position.y - 8.0), 15, color_text)
	# Cola: marcas en el suelo
	_text(font, tr("GRID_QUEUE"), Vector2(machine_rect().position.x - 150.0, fy + 18.0), 15, color_label)
	# Máquina recreativa
	_draw_machine(font)
	# Barra de bocadillos (E/S)
	var counter: Rect2 = counter_rect()
	draw_rect(Rect2(counter.position.x, fy - 74.0, counter.size.x, 22.0), Color(0.3, 0.6, 0.35))
	_text(font, tr("ARCADE_SNACK"), Vector2(counter.get_center().x, fy - 57.0), 15, color_text)
	draw_rect(counter, color_counter)
	draw_rect(Rect2(counter.position, Vector2(counter.size.x, 8.0)), color_counter.lightened(0.25))
	# Salida (han acabado)
	_text(font, tr("ARCADE_DONE"), Vector2(size.x - 80.0, fy - 96.0), 15, Color(0.5, 0.9, 0.5))
	draw_rect(Rect2(size.x - 150.0, fy - 88.0, 140.0, 4.0), Color(0.5, 0.9, 0.5, 0.6))


func _draw_machine(font: Font) -> void:
	var m: Rect2 = machine_rect()
	# Mueble con la parte de arriba inclinada
	var body: PackedVector2Array = [
		m.position + Vector2(10, 0), m.position + Vector2(m.size.x - 10, 0),
		m.position + Vector2(m.size.x, 26), m.end, Vector2(m.position.x, m.end.y), m.position + Vector2(0, 26)]
	draw_colored_polygon(body, color_cabinet)
	draw_polyline(body + PackedVector2Array([body[0]]), color_neon, 3.0)
	# Rótulo «CPU»
	var marquee := Rect2(m.position.x + 12, m.position.y + 6, m.size.x - 24, 24)
	draw_rect(marquee, Color(0.98, 0.78, 0.2))
	_text(font, "CPU", marquee.get_center() + Vector2(0, 7), 20, Color(0.2, 0.05, 0.3))
	# Pantalla
	var screen := Rect2(m.position.x + 14, m.position.y + 38, m.size.x - 28, m.size.y * 0.36)
	draw_rect(screen, color_screen_on if machine_busy else color_screen_off)
	if machine_busy:
		# Un «juego» de bloques que se mueven
		for k: int in 5:
			var bx: float = screen.position.x + fmod(_time * (30.0 + k * 11.0) + k * 17.0, screen.size.x - 8.0)
			var by: float = screen.position.y + 6.0 + k * (screen.size.y - 12.0) / 5.0
			draw_rect(Rect2(bx, by, 8, 6), Color.from_hsv(fmod(k * 0.21 + _time * 0.1, 1.0), 0.6, 1.0))
	for k: int in screen_lines.size():
		_text(font, screen_lines[k], Vector2(screen.get_center().x, screen.position.y + 18.0 + k * 18.0), 14, color_text)
	# Mandos
	var panel_y: float = screen.end.y + 10.0
	draw_rect(Rect2(m.position.x + 6, panel_y, m.size.x - 12, 18), color_cabinet.lightened(0.2))
	draw_circle(Vector2(m.position.x + 30, panel_y + 5), 6.0, Color(0.9, 0.2, 0.2))
	draw_circle(Vector2(m.position.x + 70, panel_y + 9), 5.0, Color(0.2, 0.8, 0.9))
	draw_circle(Vector2(m.position.x + 88, panel_y + 9), 5.0, Color(0.95, 0.8, 0.2))


func _text(font: Font, text: String, center: Vector2, fs: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(center.x - w / 2.0, center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
