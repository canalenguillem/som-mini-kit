extends Node
## Música de fondo persistente entre escenas, con fundido cruzado. Va en autoload para que
## no se reinicie al pasar de un menú a otro.

const MENU_MUSIC_PATH: String = "res://assets/audio/music/menu.ogg"
const BUS: StringName = &"Music"
const SILENT_DB: float = -60.0

var current: AudioStream  ## lo que suena (o debería sonar)

var _active: AudioStreamPlayer
var _idle: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue sonando con el juego en pausa
	_active = _make_player()
	_idle = _make_player()


func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = BUS
	player.volume_db = SILENT_DB
	add_child(player)
	return player


func play_menu() -> void:
	play(load(MENU_MUSIC_PATH) as AudioStream if ResourceLoader.exists(MENU_MUSIC_PATH) else null)


## Cambia a `stream` con un fundido. Si ya suena, no hace nada. null = silencio.
func play(stream: AudioStream, fade: float = 0.8) -> void:
	if stream == current:
		return
	current = stream
	if _tween != null:
		_tween.kill()
	_idle.stop()  # corta un fundido de salida anterior que siguiera en curso
	var outgoing: AudioStreamPlayer = _active
	_tween = create_tween().set_parallel()
	if outgoing.playing:
		_tween.tween_property(outgoing, "volume_db", SILENT_DB, fade)
	if stream != null:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		var incoming: AudioStreamPlayer = _idle
		_idle = outgoing
		_active = incoming
		incoming.stream = stream
		incoming.volume_db = SILENT_DB
		incoming.play()
		_tween.tween_property(incoming, "volume_db", 0.0, fade)
	_tween.finished.connect(_on_fade_finished.bind(outgoing))


func _on_fade_finished(outgoing: AudioStreamPlayer) -> void:
	if outgoing != _active:
		outgoing.stop()
	elif current == null:
		outgoing.stop()
