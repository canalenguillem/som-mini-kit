class_name CarAudio
extends Node2D
## Sonido del coche: motor con el tono ligado a la velocidad, chirrido de derrape, choques y nitro.
## Solo suena; Car le pasa su estado cada frame de física.

@export_group("Motor")
@export var idle_pitch: float = 0.7
@export var max_pitch: float = 1.8
@export var pitch_smoothing: float = 8.0
@export var idle_volume_db: float = -22.0
@export var max_volume_db: float = -14.0
@export var volume_offset_db: float = 0.0  ## se suma al motor (los rivales suenan más bajo)
@export_group("Derrape")
@export var skid_lateral_speed: float = 80.0  ## px/s de velocidad lateral a partir de la cual chirría
@export var skid_min_db: float = -22.0
@export var skid_max_db: float = -8.0
@export_group("Choque")
@export var crash_min_impact: float = 60.0
@export var crash_max_impact: float = 500.0
@export var crash_cooldown: float = 0.2  ## s mínimos entre dos choques sonando

var skidding: bool = false

var _was_boosting: bool = false
var _crash_cooldown_left: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var _engine: AudioStreamPlayer2D = $Engine
@onready var _skid: AudioStreamPlayer2D = $Skid
@onready var _crash: AudioStreamPlayer2D = $Crash
@onready var _nitro: AudioStreamPlayer2D = $Nitro


func _ready() -> void:
	_rng.randomize()
	for looping: AudioStreamPlayer2D in [_engine, _skid]:
		if looping.stream is AudioStreamOggVorbis:
			(looping.stream as AudioStreamOggVorbis).loop = true
	_engine.pitch_scale = idle_pitch
	_engine.volume_db = idle_volume_db + volume_offset_db
	_engine.play()


## fwd/lat: velocidad longitudinal y lateral (px/s); max_speed: velocidad máxima del coche.
func update_state(delta: float, fwd: float, lat: float, boosting: bool, max_speed: float) -> void:
	var t: float = clampf(absf(fwd) / maxf(max_speed, 1.0), 0.0, 1.0)
	_engine.pitch_scale = lerpf(_engine.pitch_scale, lerpf(idle_pitch, max_pitch, t), 1.0 - exp(-pitch_smoothing * delta))
	_engine.volume_db = lerpf(idle_volume_db, max_volume_db, t) + volume_offset_db

	skidding = absf(lat) > skid_lateral_speed
	if skidding:
		_skid.volume_db = lerpf(skid_min_db, skid_max_db, clampf((absf(lat) - skid_lateral_speed) / 200.0, 0.0, 1.0))
		if not _skid.playing:
			_skid.play()
	elif _skid.playing:
		_skid.stop()

	if boosting and not _was_boosting:
		_nitro.play()
	_was_boosting = boosting
	_crash_cooldown_left = maxf(_crash_cooldown_left - delta, 0.0)


## Suena un choque proporcional al impacto (px/s). Los muy leves y los seguidos se ignoran.
func on_crash(impact: float) -> void:
	if impact < crash_min_impact or _crash_cooldown_left > 0.0:
		return
	_crash_cooldown_left = crash_cooldown
	_crash.volume_db = lerpf(-16.0, -2.0, inverse_lerp(crash_min_impact, crash_max_impact, impact))
	_crash.pitch_scale = _rng.randf_range(0.9, 1.1)
	_crash.play()
