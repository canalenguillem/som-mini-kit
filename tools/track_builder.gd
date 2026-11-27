class_name TrackBuilder
extends RefCounted
## Genera una pista completa (escena + TrackData) desde una definición.
## La pista se describe con una línea central (puntos en "unidades" de 64 px, lazo cerrado, el
## primer punto es la línea de meta y debe estar en mitad de un tramo recto). El constructor:
##  - suaviza la línea (Catmull-Rom) y la remuestrea cada 8 px,
##  - pinta Ground (asfalto/arcén según distancia a la línea) y Walls (muro alrededor),
##  - crea RacingLine (con desvíos para esquivar troncos) y coloca los obstáculos,
##  - valida que ningún tramo se acerque demasiado a otro,
##  - guarda scenes/tracks/<id>.tscn y data/tracks/<id>.tres e imprime el mapa ASCII.
##
## Claves de la definición (ver tools/gen_west_01.gd):
##   id, display_name, theme, laps, reward_mult, unlock_cost, music (ruta opcional del .ogg)
##   points: Array[Vector2]            línea central, en unidades
##   half_width, shoulder: float       semiancho de calzada y ancho de arcén, en unidades
##   road_surface, shoulder_surface    superficies por defecto (id de SurfaceData)
##   segments: [{from, to, surface?, half_width?, shoulder_surface?}]   rangos de progreso 0..1
##   dodges:   [{p, amp, span, log}]   desvío lateral de la línea de carrera (+ tronco al otro lado)
##   barrels:  [{p, lateral, count}]   racimos de barriles
##   cacti:    [{p, lateral}]          cactus (muros sueltos)
##   trains:   [{p, period, warning, speed, phase}]  cruces de tren

const UNIT: float = 64.0
const CELL: int = 32
const WALL_CELLS: int = 2
const STEP: float = 8.0
const MARGIN_UNITS: float = 7.0
const PROFILE_RAMP: float = 0.012  ## suavizado (en progreso) al entrar/salir de un segmento
const SURFACE_ATLAS: Dictionary = {"asphalt": 0, "dirt": 1, "sand": 2, "mud": 3, "grass": 4, "water": 5}
const WALL_ATLAS: int = 6
const CHARS: Dictionary = {"asphalt": ".", "dirt": "t", "sand": "a", "mud": "b", "grass": "h", "water": "w"}
const TRAIN_HALF_LENGTH: float = 160.0

var def: Dictionary = {}
var count: int = 0
var length: float = 0.0
var pts: PackedVector2Array = []  ## línea central remuestreada (px)
var tangents: PackedVector2Array = []
var halfs: PackedFloat32Array = []  ## semiancho de calzada en cada muestra (unidades)
var shifts: PackedFloat32Array = []  ## desvío lateral de la línea de carrera (unidades)
var road_cells: Dictionary = {}  ## Vector2i → id de superficie
var wall_cells: Dictionary = {}  ## Vector2i → true
var min_separation: float = 0.0

var _root: Node2D


func build(p_def: Dictionary) -> bool:
	def = p_def
	_sample_centerline()
	_compute_profiles()
	if not _validate_separation():
		return false
	_classify_cells()
	_root = _make_scene()
	var scene_path: String = "res://scenes/tracks/%s.tscn" % def["id"]
	var packed := PackedScene.new()
	if packed.pack(_root) != OK or ResourceSaver.save(packed, scene_path) != OK:
		printerr("No se pudo guardar ", scene_path)
		return false
	_root.free()
	_save_track_data(scene_path)
	print("OK %s: %.0f px de vuelta, separación mínima %.1f u" % [def["id"], length, min_separation / UNIT])
	print(ascii_map())
	return true


# --- Línea central ---

func _sample_centerline() -> void:
	var ctrl: Array = def["points"]
	var n: int = ctrl.size()
	var raw := PackedVector2Array()
	for i: int in n:
		var p0: Vector2 = (ctrl[(i - 1 + n) % n] as Vector2) * UNIT
		var p1: Vector2 = (ctrl[i] as Vector2) * UNIT
		var p2: Vector2 = (ctrl[(i + 1) % n] as Vector2) * UNIT
		var p3: Vector2 = (ctrl[(i + 2) % n] as Vector2) * UNIT
		var segs: int = maxi(2, ceili(p1.distance_to(p2) / STEP))
		for k: int in segs:
			var t: float = float(k) / segs
			raw.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t \
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	raw.append(raw[0])
	# Remuestreo uniforme por longitud de arco
	var cum := PackedFloat32Array([0.0])
	for i: int in range(1, raw.size()):
		cum.append(cum[i - 1] + raw[i - 1].distance_to(raw[i]))
	length = cum[cum.size() - 1]
	count = roundi(length / STEP)
	var step: float = length / count
	pts.resize(count)
	var j: int = 0
	for i: int in count:
		var target: float = i * step
		while j < raw.size() - 2 and cum[j + 1] < target:
			j += 1
		var seg: float = cum[j + 1] - cum[j]
		pts[i] = raw[j].lerp(raw[j + 1], (target - cum[j]) / seg if seg > 0.0 else 0.0)
	# Traslada para que todo quede en coordenadas positivas con margen
	var min_v: Vector2 = pts[0]
	for p: Vector2 in pts:
		min_v = min_v.min(p)
	var offset: Vector2 = Vector2(MARGIN_UNITS, MARGIN_UNITS) * UNIT - min_v
	for i: int in count:
		pts[i] += offset
	tangents.resize(count)
	for i: int in count:
		tangents[i] = (pts[(i + 1) % count] - pts[(i - 1 + count) % count]).normalized()


func _normal(i: int) -> Vector2:
	return tangents[i].rotated(PI / 2.0)  ## hacia la derecha del avance (y hacia abajo)


func _compute_profiles() -> void:
	var base_half: float = def["half_width"]
	halfs.resize(count)
	shifts.resize(count)
	var segments: Array = def.get("segments", [])
	var dodges: Array = def.get("dodges", [])
	for i: int in count:
		var p: float = float(i) / count
		var h: float = base_half
		for seg: Dictionary in segments:
			if seg.has("half_width"):
				var w: float = clampf(minf(p - float(seg["from"]), float(seg["to"]) - p) / PROFILE_RAMP, 0.0, 1.0)
				h = lerpf(h, float(seg["half_width"]), w)
		halfs[i] = h
		var s: float = 0.0
		for d: Dictionary in dodges:
			var u: float = (p - (float(d["p"]) - float(d["span"]) / 2.0)) / float(d["span"])
			if u > 0.0 and u < 1.0:
				s += float(d["amp"]) * pow(sin(PI * u), 2.0)
		shifts[i] = s


func _surface_at(i: int, key: String, default_key: String) -> String:
	var p: float = float(i) / count
	var result: String = def[default_key]
	for seg: Dictionary in def.get("segments", []):
		if seg.has(key) and p >= float(seg["from"]) and p <= float(seg["to"]):
			result = str(seg[key])
	return result


func _validate_separation() -> bool:
	var stride: int = 4
	var n: int = count / stride
	var max_half: float = 0.0
	for h: float in halfs:
		max_half = maxf(max_half, h)
	var required: float = (2.0 * max_half + 2.0 * float(def["shoulder"])) * UNIT + WALL_CELLS * CELL
	var worst: float = INF
	var worst_pair: Vector2i = Vector2i.ZERO
	for a: int in n:
		for b: int in range(a + 1, n):
			var arc: float = minf(b - a, n - (b - a)) * stride * STEP
			if arc < 1.6 * required:  # tramos contiguos: se miden solo las curvas cerradas
				continue
			var d: float = pts[a * stride].distance_to(pts[b * stride])
			if d < worst:
				worst = d
				worst_pair = Vector2i(a * stride, b * stride)
	min_separation = worst
	if worst < required:
		printerr("%s: tramos demasiado cercanos (%.1f u < %.1f u) en p=%.3f %s y p=%.3f %s" % [
			def["id"], worst / UNIT, required / UNIT, float(worst_pair.x) / count, pts[worst_pair.x] / UNIT,
			float(worst_pair.y) / count, pts[worst_pair.y] / UNIT])
		return false
	return true


# --- Celdas ---

func _classify_cells() -> void:
	var shoulder_px: float = float(def["shoulder"]) * UNIT
	var wall_px: float = WALL_CELLS * CELL
	var best_d: Dictionary = {}
	var best_i: Dictionary = {}
	for i: int in count:
		var c: Vector2 = pts[i]
		var radius: float = halfs[i] * UNIT + shoulder_px + wall_px
		var x0: int = floori((c.x - radius) / CELL)
		var x1: int = floori((c.x + radius) / CELL)
		var y0: int = floori((c.y - radius) / CELL)
		var y1: int = floori((c.y + radius) / CELL)
		for cy: int in range(y0, y1 + 1):
			for cx: int in range(x0, x1 + 1):
				var cell := Vector2i(cx, cy)
				var d: float = c.distance_to((Vector2(cx, cy) + Vector2(0.5, 0.5)) * CELL)
				if d <= radius and d < float(best_d.get(cell, INF)):
					best_d[cell] = d
					best_i[cell] = i
	for cell: Vector2i in best_d:
		var i: int = best_i[cell]
		var d: float = best_d[cell]
		var half_px: float = halfs[i] * UNIT
		if d <= half_px:
			road_cells[cell] = _surface_at(i, "surface", "road_surface")
		elif d <= half_px + shoulder_px:
			road_cells[cell] = _surface_at(i, "shoulder_surface", "shoulder_surface")
		elif d <= half_px + shoulder_px + wall_px:
			wall_cells[cell] = true


# --- Escena ---

func _make_scene() -> Node2D:
	var root := Node2D.new()
	root.name = (def["id"] as String).to_pascal_case()
	root.set_script(load("res://scenes/tracks/track.gd"))

	var tileset: TileSet = load("res://assets/tilesets/%s.tres" % def["theme"]) as TileSet
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tileset
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tileset
	var min_c := Vector2i(1 << 30, 1 << 30)
	var max_c := Vector2i(-(1 << 30), -(1 << 30))
	for cell: Vector2i in road_cells:
		ground.set_cell(cell, 0, Vector2i(SURFACE_ATLAS[road_cells[cell]], 0))
	for cell: Vector2i in wall_cells:
		walls.set_cell(cell, 0, Vector2i(WALL_ATLAS, 0))
		min_c = min_c.min(cell)
		max_c = max_c.max(cell)

	var bg := Polygon2D.new()
	bg.name = "Background"
	bg.z_index = -10
	bg.color = Color(0.05, 0.05, 0.06)
	var lo: Vector2 = Vector2(min_c) * CELL - Vector2(UNIT, UNIT) * 6.0
	var hi: Vector2 = Vector2(max_c + Vector2i.ONE) * CELL + Vector2(UNIT, UNIT) * 6.0
	bg.polygon = PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])

	_add(root, root, bg)
	_add(root, root, ground)
	_add(root, root, walls)
	_add(root, root, _make_node("Decor"))
	var obstacles: Node2D = _make_node("Obstacles")
	_add(root, root, obstacles)
	_add(root, root, _make_node("SurfaceZones"))
	_add(root, root, _make_racing_line())
	_place_obstacles(root, obstacles)

	var width_px: float = (_max_half() + float(def["shoulder"]) + 0.8) * 2.0 * UNIT
	root.set("checkpoint_width", width_px)
	root.set("map_bounds", Rect2(lo, hi - lo))
	return root


func _max_half() -> float:
	var m: float = 0.0
	for h: float in halfs:
		m = maxf(m, h)
	return m


func _make_node(node_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	return n


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root


func _make_racing_line() -> Path2D:
	var line := Path2D.new()
	line.name = "RacingLine"
	var curve := Curve2D.new()
	curve.bake_interval = 8.0
	var every: int = roundi(UNIT / STEP)  # un punto cada 64 px
	for i: int in range(0, count, every):
		curve.add_point(pts[i] + _normal(i) * shifts[i] * UNIT)
	curve.add_point(curve.get_point_position(0))  # cierra el lazo
	line.curve = curve
	return line


func _at(p: float, lateral_units: float) -> Dictionary:
	var i: int = int(p * count) % count
	return {"pos": pts[i] + _normal(i) * lateral_units * UNIT, "angle": tangents[i].angle(), "i": i}


func _place_obstacles(root: Node, parent: Node) -> void:
	var barrel_scene: PackedScene = load("res://scenes/obstacles/barrel.tscn")
	var cactus_scene: PackedScene = load("res://scenes/obstacles/cactus.tscn")
	var log_scene: PackedScene = load("res://scenes/obstacles/log.tscn")
	var train_scene: PackedScene = load("res://scenes/obstacles/train.tscn")
	var n: int = 0

	for b: Dictionary in def.get("barrels", []):
		var at: Dictionary = _at(float(b["p"]), float(b["lateral"]))
		var cnt: int = int(b.get("count", 3))
		for k: int in cnt:
			var barrel: Node2D = barrel_scene.instantiate()
			var a: float = TAU * k / cnt
			barrel.name = "Barrel%d" % n
			n += 1
			_add(root, parent, barrel)
			barrel.position = (at["pos"] as Vector2) + Vector2.from_angle(a) * (0.0 if cnt == 1 else 17.0)
	for c: Dictionary in def.get("cacti", []):
		var cactus: Node2D = cactus_scene.instantiate()
		cactus.name = "Cactus%d" % n
		n += 1
		_add(root, parent, cactus)
		cactus.position = _at(float(c["p"]), float(c["lateral"]))["pos"]
	for d: Dictionary in def.get("dodges", []):
		if not bool(d.get("log", true)):
			continue
		var amp: float = float(d["amp"])
		var at: Dictionary = _at(float(d["p"]), -signf(amp) * 1.0)
		var log_node: Node2D = log_scene.instantiate()
		log_node.name = "Log%d" % n
		n += 1
		_add(root, parent, log_node)
		log_node.position = at["pos"]
		log_node.rotation = at["angle"]
	var span: float = (_max_half() + float(def["shoulder"]) + WALL_CELLS * CELL / UNIT + 1.0) * UNIT + TRAIN_HALF_LENGTH
	for t: Dictionary in def.get("trains", []):
		var at: Dictionary = _at(float(t["p"]), 0.0)
		var train: Node2D = train_scene.instantiate()
		train.name = "Train%d" % n
		n += 1
		_add(root, parent, train)
		train.position = at["pos"]
		train.rotation = float(at["angle"]) + PI / 2.0
		train.set("half_span", span)
		train.set("period", float(t.get("period", 10.0)))
		train.set("warning_time", float(t.get("warning", 2.0)))
		train.set("speed", float(t.get("speed", 650.0)))
		train.set("phase", float(t.get("phase", 0.0)))
		train.set("crossing_half_length", (_max_half() + float(def["shoulder"])) * UNIT)


func _save_track_data(scene_path: String) -> void:
	var td := TrackData.new()
	td.id = def["id"]
	td.display_name = def["display_name"]
	td.theme = def["theme"]
	td.laps = int(def.get("laps", 3))
	td.reward_mult = float(def.get("reward_mult", 1.0))
	td.unlock_cost = int(def.get("unlock_cost", 0))
	var music_path: String = str(def.get("music", ""))
	if not music_path.is_empty() and ResourceLoader.exists(music_path):
		td.music = load(music_path) as AudioStream
	td.scene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	ResourceSaver.save(td, "res://data/tracks/%s.tres" % def["id"])


# --- Mapa ASCII (1 carácter = 64 px) ---

func ascii_map() -> String:
	var min_c := Vector2i(1 << 30, 1 << 30)
	var max_c := Vector2i(-(1 << 30), -(1 << 30))
	for cell: Vector2i in wall_cells:
		min_c = min_c.min(cell)
		max_c = max_c.max(cell)
	var start_cell := Vector2i(floori(pts[0].x / UNIT), floori(pts[0].y / UNIT))
	var lines: PackedStringArray = []
	for uy: int in range(min_c.y / 2, max_c.y / 2 + 1):
		var row: String = ""
		for ux: int in range(min_c.x / 2, max_c.x / 2 + 1):
			var cell := Vector2i(ux * 2 + 1, uy * 2 + 1)
			if Vector2i(ux, uy) == start_cell:
				row += "S"
			elif road_cells.has(cell):
				row += CHARS[road_cells[cell]]
			elif wall_cells.has(cell):
				row += "#"
			else:
				row += " "
		lines.append(row.rstrip(" "))
	return "\n".join(lines)
