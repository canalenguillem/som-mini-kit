class_name GanttGrid
extends Control
## Cuadrícula del libro: una fila por proceso, una columna por ciclo (desde 1).
## Se toca una casilla (o se arrastra por la fila) para poner a ese proceso en la CPU en ese ciclo;
## en cada columna solo puede haber uno. La F (último ciclo) y las W (E/S) salen solas.

signal changed

@export var cell_size: Vector2 = Vector2(32, 30)
@export var label_width: float = 40.0
@export var header_height: float = 24.0
@export var queue_height: float = 50.0
@export var font_size: int = 16
@export var color_cell: Color = Color(0.17, 0.19, 0.25)
@export var color_locked: Color = Color(0.12, 0.13, 0.17)
@export var color_run: Color = Color(0.25, 0.55, 0.85)
@export var color_io: Color = Color(0.55, 0.45, 0.2)
@export var color_arrival: Color = Color(0.95, 0.75, 0.2)
@export var color_line: Color = Color(0.32, 0.35, 0.42)
@export var color_text: Color = Color(0.92, 0.94, 0.97)

var names: PackedStringArray = []
var arrivals: PackedInt32Array = []
var bursts: Array = []  ## ráfagas de cada proceso: CPU, E/S, CPU…
var columns: int = 0
var grid: Array[int] = []  ## proceso en la CPU en cada columna; -1 = nadie
var locked: Array[bool] = []  ## columnas que no se pueden tocar (guiado, ejemplo)
var editable: bool = true
var queues: Array = []  ## cola de cada ciclo (nombres); vacío = no se dibuja la fila de la cola
var revealed: int = -1  ## columnas visibles en el ejemplo animado; -1 = todas

var _painting: bool = false
var _paint_row: int = -1
var _paint_value: int = -1
var _last_col: int = -1


func setup(process_names: PackedStringArray, process_arrivals: PackedInt32Array, process_bursts: Array,
		column_count: int) -> void:
	names = process_names
	arrivals = process_arrivals
	bursts = process_bursts
	columns = column_count
	grid.clear()
	locked.clear()
	for c: int in columns:
		grid.append(-1)
		locked.append(false)
	queues = []
	revealed = -1
	_update_size()
	queue_redraw()


func set_grid(values: Array, lock: bool = false, upto: int = -1) -> void:
	var last: int = columns if upto < 0 else mini(upto, columns)
	for c: int in last:
		grid[c] = int(values[c]) if c < values.size() else -1
		if lock:
			locked[c] = true
	queue_redraw()
	changed.emit()


func clear_unlocked() -> void:
	for c: int in columns:
		if not locked[c]:
			grid[c] = -1
	queue_redraw()


func _update_size() -> void:
	var h: float = header_height + cell_size.y * names.size() + (queue_height if not queues.is_empty() else 0.0)
	custom_minimum_size = Vector2(label_width + cell_size.x * columns, h)


func show_queues(values: Array) -> void:
	queues = values
	_update_size()
	queue_redraw()


## Marca que verá el alumno en (proceso, columna): "X", "F", "W" o "".
func mark(row: int, c: int) -> String:
	return marks_for_row(row)[c]


## Marcas de una fila a partir de la cuadrícula actual: las W siguen a cada ráfaga de CPU completa.
func marks_for_row(row: int) -> PackedStringArray:
	var out: PackedStringArray = []
	out.resize(columns)
	var b: Array = bursts[row] if row < bursts.size() else []
	var burst: int = 0
	var done: int = 0
	var c: int = 0
	while c < columns:
		if grid[c] == row:
			out[c] = "X"
			done += 1
			if burst < b.size() and done >= int(b[burst]):
				if burst + 1 >= b.size():
					out[c] = "F"
					burst = b.size()  # lo que venga después ya no es F
				elif burst + 1 < b.size():
					var io: int = int(b[burst + 1])
					for k: int in io:
						if c + 1 + k < columns and grid[c + 1 + k] != row:
							out[c + 1 + k] = "W"
					burst += 2
					done = 0
		c += 1
	return out


func cell_at(pos: Vector2) -> Vector2i:
	var col: int = floori((pos.x - label_width) / cell_size.x)
	var row: int = floori((pos.y - header_height) / cell_size.y)
	if col < 0 or col >= columns or row < 0 or row >= names.size() or pos.x < label_width or pos.y < header_height:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var cell: Vector2i = cell_at(mb.position)
			if cell.x >= 0:
				_painting = true
				_paint_row = cell.y
				_paint_value = -1 if grid[cell.x] == cell.y else cell.y
				_last_col = cell.x
				_paint(cell.x)
				accept_event()
		else:
			_painting = false
	elif event is InputEventMouseMotion and _painting:
		var cell: Vector2i = cell_at((event as InputEventMouseMotion).position)
		if cell.x >= 0 and cell.y == _paint_row and cell.x != _last_col:
			# Un arrastre rápido puede saltarse columnas: se pintan también las de en medio
			var step: int = 1 if cell.x > _last_col else -1
			var c: int = _last_col + step
			while c != cell.x + step:
				_paint(c)
				c += step
			_last_col = cell.x
			accept_event()


## Pinta (o borra) la casilla de la fila que se está arrastrando.
func _paint(col: int) -> void:
	if locked[col]:
		return
	var value: int = _paint_value
	if value < 0 and grid[col] != _paint_row:
		return  # al borrar arrastrando, solo se borra lo de esta fila
	if grid[col] == value:
		return
	grid[col] = value
	queue_redraw()
	changed.emit()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var visible_cols: int = columns if revealed < 0 else mini(revealed, columns)
	for c: int in columns:
		var x: float = label_width + c * cell_size.x
		_text(font, str(c + 1), Rect2(x, 0, cell_size.x, header_height), color_text if c < visible_cols else color_line)
	var all_marks: Array[PackedStringArray] = []
	for row: int in names.size():
		all_marks.append(marks_for_row(row))
	for row: int in names.size():
		var y: float = header_height + row * cell_size.y
		_text(font, names[row], Rect2(0, y, label_width, cell_size.y), color_text)
		for c: int in columns:
			var rect := Rect2(label_width + c * cell_size.x, y, cell_size.x, cell_size.y).grow(-1)
			draw_rect(rect, color_locked if locked[c] else color_cell)
			if c + 1 == arrivals[row]:
				draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), color_arrival)
			if c < visible_cols:
				var m: String = all_marks[row][c]
				if m == "X" or m == "F":
					draw_rect(rect.grow(-3), color_run)
					_text(font, m, rect, color_text)
				elif m == "W":
					draw_rect(rect.grow(-3), color_io)
					_text(font, m, rect, color_text)
	if not queues.is_empty():
		var y: float = header_height + names.size() * cell_size.y
		_text(font, tr("GRID_QUEUE"), Rect2(0, y, label_width, cell_size.y), color_arrival)
		for c: int in mini(visible_cols, queues.size()):
			var q: Array = queues[c]
			for k: int in mini(q.size(), 3):
				_text(font, str(q[k]), Rect2(label_width + c * cell_size.x, y + k * 15, cell_size.x, 16),
						color_arrival, font_size - 4)


func _text(font: Font, text: String, rect: Rect2, color: Color, size: int = font_size) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(rect.position.x + (rect.size.x - w) / 2.0, rect.position.y + (rect.size.y + size * 0.7) / 2.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
