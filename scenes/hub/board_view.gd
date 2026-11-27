class_name BoardView
extends Control
## La placa base de TORRE-7 vista desde arriba: pistas de los buses que salen de la CPU hacia cada
## zona, y un punto de luz (el alumno, convertido en programa) que viaja por ellas.

signal arrived(index: int)

@export var color_board: Color = Color(0.05, 0.32, 0.2)
@export var color_board_dark: Color = Color(0.03, 0.24, 0.15)
@export var color_trace: Color = Color(0.78, 0.62, 0.25, 0.55)
@export var color_trace_lit: Color = Color(0.98, 0.85, 0.35)
@export var color_dot: Color = Color(0.5, 0.95, 1.0)
@export var travel_time: float = 0.6

var points: Array[Vector2] = []  ## posiciones de las zonas (0..1)
var hub_index: int = 3  ## la CPU (zona 4) es el centro de los buses
var dot: Vector2 = Vector2(-1, -1)  ## en píxeles; (-1, -1) = en la CPU
var lit: int = -1  ## bus encendido
var _time: float = 0.0
var _tween: Tween


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func to_px(p: Vector2) -> Vector2:
	return Vector2(p.x * size.x, p.y * size.y)


## Recorrido del bus de la CPU a la zona `i`: horizontal y luego vertical, como una pista.
func path_to(i: int) -> PackedVector2Array:
	var a: Vector2 = to_px(points[hub_index])
	var b: Vector2 = to_px(points[i])
	return PackedVector2Array([a, Vector2(b.x, a.y), b])


func travel_to(i: int) -> void:
	lit = i
	if _tween != null:
		_tween.kill()
	var path: PackedVector2Array = path_to(i)
	dot = path[0]
	if not is_inside_tree() or travel_time <= 0.0:
		dot = path[2]
		arrived.emit(i)
		return
	_tween = create_tween()
	_tween.tween_property(self, "dot", path[1], travel_time * 0.5)
	_tween.tween_property(self, "dot", path[2], travel_time * 0.5)
	_tween.finished.connect(func() -> void: arrived.emit(i))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color_board)
	# Rejilla de la placa
	var step: float = 24.0
	var x: float = 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), color_board_dark, 1.0)
		x += step
	var y: float = 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), color_board_dark, 1.0)
		y += step
	# Agujeros de los tornillos
	for corner: Vector2 in [Vector2(14, 14), Vector2(size.x - 14, 14), Vector2(14, size.y - 14), size - Vector2(14, 14)]:
		draw_circle(corner, 7.0, Color(0.75, 0.75, 0.7))
		draw_circle(corner, 3.0, color_board_dark)
	if points.size() <= hub_index:
		return
	# Buses
	for i: int in points.size():
		if i == hub_index:
			continue
		var path: PackedVector2Array = path_to(i)
		var color: Color = color_trace_lit if i == lit else color_trace
		for k: int in 3:
			var off := Vector2(0, (k - 1) * 5.0)
			var shifted: PackedVector2Array = [path[0] + off, path[1] + Vector2((k - 1) * 5.0, 0) + off, path[2] + Vector2((k - 1) * 5.0, 0)]
			draw_polyline(shifted, color, 2.0)
	# El programa (el alumno)
	var p: Vector2 = dot if dot.x >= 0.0 else to_px(points[hub_index])
	var glow: float = 0.6 + 0.4 * sin(_time * 5.0)
	draw_circle(p, 14.0, Color(color_dot, 0.18 * glow))
	draw_circle(p, 8.0, Color(color_dot, 0.5))
	draw_circle(p, 4.0, Color.WHITE)
