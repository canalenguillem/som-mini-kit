class_name ArcadePlayer
extends Control
## Un jugador del salón: personaje de Kenney (Toon Characters, CC0), fichas sobre la cabeza,
## barra de paciencia y nombre. Camina entre zonas con tween; si se puede elegir, brilla y se toca.

signal pressed

const POSE_PATH: String = "res://assets/kenney_toon_characters/%s/%s.png"
const WALK_FRAMES: int = 8

@export var sprite_scale: float = 0.72
@export var walk_speed: float = 420.0  ## píxeles por segundo
@export var color_token: Color = Color(0.98, 0.78, 0.2)
@export var color_glow: Color = Color(0.98, 0.78, 0.2, 0.55)

var character: String = "femalePerson"
var label: String = ""
var tokens: int = 0
var patience: float = 1.0
var show_patience: bool = true
var tappable: bool = false:
	set(value):
		tappable = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
		queue_redraw()
var pose: String = "idle"
var dimmed: bool = false

var _walking: bool = false
var _walk_time: float = 0.0
var _tween: Tween
var _textures: Dictionary = {}


func _init() -> void:
	size = Vector2(84, 150)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _texture(name: String) -> Texture2D:
	var key: String = character + "/" + name
	if not _textures.has(key):
		var path: String = POSE_PATH % [character, name]
		_textures[key] = load(path) if ResourceLoader.exists(path) else null
	return _textures[key]


## Lleva al jugador a `target` (esquina superior izquierda). Sin animar si `instant`.
func walk_to(target: Vector2, instant: bool = false) -> void:
	if _tween != null:
		_tween.kill()
	if instant or not is_inside_tree() or position.distance_to(target) < 2.0:
		position = target
		_walking = false
		queue_redraw()
		return
	_walking = true
	var duration: float = clampf(position.distance_to(target) / walk_speed, 0.15, 0.9)
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE)
	_tween.finished.connect(func() -> void:
		_walking = false
		queue_redraw())


func _process(delta: float) -> void:
	if _walking or tappable:
		_walk_time += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if tappable and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit()
			accept_event()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var tex: Texture2D = _texture("walk%d" % (int(_walk_time * 12.0) % WALK_FRAMES) if _walking else pose)
	var feet := Vector2(size.x / 2.0, size.y - 16.0)
	if tappable:
		var pulse: float = 0.75 + 0.25 * sin(_walk_time * 6.0)
		_ellipse(feet, Vector2(36, 9) * pulse + Vector2(4, 1), color_glow)
	else:
		_ellipse(feet, Vector2(26, 6), Color(0, 0, 0, 0.3))
	if tex != null:
		var s: Vector2 = tex.get_size() * sprite_scale
		var bob: float = -3.0 * absf(sin(_walk_time * 6.0)) if tappable and not _walking else 0.0
		var rect := Rect2(feet.x - s.x / 2.0, feet.y - s.y + 4.0 + bob, s.x, s.y)
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, 0.45 if dimmed else 1.0))
	# Fichas encima de la cabeza
	var top: float = size.y - 16.0 - 128.0 * sprite_scale - 2.0
	var n: int = mini(tokens, 8)
	for k: int in n:
		var x: float = feet.x - (n - 1) * 5.0 + k * 10.0
		draw_circle(Vector2(x, top), 4.0, color_token)
		draw_circle(Vector2(x, top), 4.0, Color(0.5, 0.35, 0.05), false, 1.0)
	# Paciencia
	if show_patience:
		var bar := Rect2(feet.x - 22.0, top - 13.0, 44.0, 5.0)
		draw_rect(bar, Color(0, 0, 0, 0.5))
		var col := Color(1.0 - patience, 0.35 + 0.55 * patience, 0.3)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(patience, 0.0, 1.0), bar.size.y)), col)
	# Nombre
	var fs: int = 14
	var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(feet.x - w / 2.0, size.y - 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			color_token if tappable else Color(0.92, 0.94, 0.97, 0.5 if dimmed else 1.0))


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts: PackedVector2Array = []
	for k: int in 24:
		var a: float = TAU * k / 24.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)
