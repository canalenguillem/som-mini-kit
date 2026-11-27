class_name Track
extends Node2D
## Script común de las pistas. Genera checkpoints y parrilla a partir de RacingLine.

signal checkpoint_passed(car: Car, index: int)

const SURFACES: Dictionary = {
	"asphalt": preload("res://data/surfaces/asphalt.tres"),
	"dirt": preload("res://data/surfaces/dirt.tres"),
	"mud": preload("res://data/surfaces/mud.tres"),
	"sand": preload("res://data/surfaces/sand.tres"),
	"grass": preload("res://data/surfaces/grass.tres"),
	"water": preload("res://data/surfaces/water.tres"),
}
const DEFAULT_SURFACE: String = "asphalt"
const GRID_SLOTS: int = 5  ## 4 en carrera contra IA; 5 en carreras online
const CHECKPOINT_THICKNESS: float = 24.0
const LAYER_CHECKPOINTS: int = 4  ## capa 3
const MASK_CARS: int = 2  ## capa 2

@export var checkpoint_spacing: float = 400.0  ## distancia aproximada entre checkpoints (px)
@export var checkpoint_width: float = 600.0  ## largo de la línea de checkpoint (cubre la pista)
@export var grid_first_gap: float = 36.0  ## px entre la meta y la primera fila
@export var grid_row_gap: float = 56.0
@export var grid_lateral: float = 26.0
@export var map_bounds: Rect2 = Rect2(-2000, -1500, 4000, 3000)  ## fuera de aquí se reaparece

var checkpoint_count: int = 0
var curve_length: float = 0.0

var _curve: Curve2D
var racing_line: Path2D  ## línea de carrera (la usan la IA y el progreso)
var _cp_offsets: Array[float] = []
var _start_transforms: Array[Transform2D] = []

@onready var _ground: TileMapLayer = get_node_or_null("Ground") as TileMapLayer
@onready var _zones: Node2D = get_node_or_null("SurfaceZones") as Node2D


func _ready() -> void:
	racing_line = get_node_or_null("RacingLine") as Path2D
	if racing_line == null or racing_line.curve == null:
		return
	_curve = racing_line.curve
	curve_length = _curve.get_baked_length()
	_generate_checkpoints()
	_generate_grid()


# --- Superficies ---

## Superficie bajo un punto: primero las SurfaceZones, luego el tile de Ground.
func get_surface_at(global_pos: Vector2) -> SurfaceData:
	var id: String = _zone_surface_id(global_pos)
	if id.is_empty() and _ground != null and _ground.tile_set != null:
		var cell: Vector2i = _ground.local_to_map(_ground.to_local(global_pos))
		var tile: TileData = _ground.get_cell_tile_data(cell)
		if tile != null:
			id = str(tile.get_custom_data("surface"))
	return SURFACES.get(id, SURFACES[DEFAULT_SURFACE]) as SurfaceData


func _zone_surface_id(global_pos: Vector2) -> String:
	if _zones == null:
		return ""
	for zone: Node in _zones.get_children():
		for child: Node in zone.get_children():
			var poly := child as CollisionPolygon2D
			if poly == null:
				continue
			if Geometry2D.is_point_in_polygon(poly.to_local(global_pos), poly.polygon):
				return str(zone.get_meta("surface", ""))
	return ""


# --- Progreso sobre la línea de carrera ---

## Distancia (px) recorrida sobre RacingLine hasta el punto más cercano a global_pos.
func get_offset(global_pos: Vector2) -> float:
	return _curve.get_closest_offset(racing_line.to_local(global_pos))


## Offset normalizado 0..1.
func get_progress(global_pos: Vector2) -> float:
	return get_offset(global_pos) / curve_length


func checkpoint_offset(index: int) -> float:
	return _cp_offsets[index]


## Longitud del tramo entre el checkpoint `index` y el siguiente.
func segment_length(index: int) -> float:
	var next: int = (index + 1) % checkpoint_count
	return fposmod(_cp_offsets[next] - _cp_offsets[index], curve_length) if checkpoint_count > 1 else curve_length


func get_respawn_transform(checkpoint_index: int) -> Transform2D:
	return _transform_at(_cp_offsets[checkpoint_index], 0.0)


func start_transforms() -> Array[Transform2D]:
	return _start_transforms


# --- Generación ---

## Transform global sobre la línea a `offset`, desplazado `lateral` px hacia la derecha del avance.
func _transform_at(offset: float, lateral: float) -> Transform2D:
	var o: float = fposmod(offset, curve_length)
	var ahead: Vector2 = _curve.sample_baked(fposmod(o + 5.0, curve_length))
	var behind: Vector2 = _curve.sample_baked(fposmod(o - 5.0, curve_length))
	var tangent: Vector2 = (ahead - behind).normalized()
	var pos: Vector2 = _curve.sample_baked(o) + tangent.rotated(PI / 2.0) * lateral
	return racing_line.global_transform * Transform2D(tangent.angle(), pos)


func _generate_checkpoints() -> void:
	checkpoint_count = maxi(3, roundi(curve_length / checkpoint_spacing))
	var root: Node2D = get_node_or_null("Checkpoints") as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "Checkpoints"
		add_child(root)
	for child: Node in root.get_children():
		child.queue_free()
	_cp_offsets.clear()
	for i: int in checkpoint_count:
		var offset: float = curve_length * i / checkpoint_count
		_cp_offsets.append(offset)
		var area := Area2D.new()
		area.name = "Checkpoint%d" % i
		area.collision_layer = LAYER_CHECKPOINTS
		area.collision_mask = MASK_CARS
		area.monitorable = false
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(CHECKPOINT_THICKNESS, checkpoint_width)
		shape.shape = rect
		area.add_child(shape)
		root.add_child(area)
		area.global_transform = _transform_at(offset, 0.0)
		area.body_entered.connect(_on_checkpoint_body_entered.bind(i))


func _generate_grid() -> void:
	var root: Node2D = get_node_or_null("StartGrid") as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "StartGrid"
		add_child(root)
	for child: Node in root.get_children():
		child.queue_free()
	_start_transforms.clear()
	for i: int in GRID_SLOTS:
		var row: int = i / 2
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var xf: Transform2D = _transform_at(-(grid_first_gap + row * grid_row_gap), side * grid_lateral)
		var marker := Marker2D.new()
		marker.name = "Slot%d" % i
		root.add_child(marker)
		marker.global_transform = xf
		_start_transforms.append(xf)


func _on_checkpoint_body_entered(body: Node2D, index: int) -> void:
	if body is Car:
		checkpoint_passed.emit(body as Car, index)
