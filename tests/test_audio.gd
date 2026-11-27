extends GutTest
## Audio: tono del motor ligado a la velocidad, chirrido, choques sin spam, nitro, cuenta atrás y música.

const CAR_PATH: String = "res://scenes/car/car.tscn"
const DT: float = 1.0 / 60.0

var _car: Car
var _audio: CarAudio


func before_each() -> void:
	_car = (load(CAR_PATH) as PackedScene).instantiate() as Car
	_car.data = load("res://data/cars/beetle.tres") as CarData
	add_child_autofree(_car)
	_audio = _car.get_node("Audio") as CarAudio


func _run(fwd: float, lat: float, boosting: bool = false, frames: int = 120) -> void:
	for i: int in frames:
		_audio.update_state(DT, fwd, lat, boosting, 420.0)


func test_el_motor_suena_nada_mas_nacer() -> void:
	assert_true((_audio.get_node("Engine") as AudioStreamPlayer2D).playing)


func test_el_tono_sube_con_la_velocidad() -> void:
	_run(0.0, 0.0)
	var idle: float = (_audio.get_node("Engine") as AudioStreamPlayer2D).pitch_scale
	_run(420.0, 0.0)
	var fast: float = (_audio.get_node("Engine") as AudioStreamPlayer2D).pitch_scale
	assert_almost_eq(idle, _audio.idle_pitch, 0.02)
	assert_almost_eq(fast, _audio.max_pitch, 0.02)
	assert_gt(fast, idle)


func test_marcha_atras_tambien_sube_el_tono() -> void:
	_run(-140.0, 0.0)
	assert_gt((_audio.get_node("Engine") as AudioStreamPlayer2D).pitch_scale, _audio.idle_pitch + 0.1)


func test_derrape_chirria_y_se_calla() -> void:
	var skid: AudioStreamPlayer2D = _audio.get_node("Skid")
	_run(300.0, 0.0, false, 3)
	assert_false(skid.playing)
	_run(300.0, 150.0, false, 3)
	assert_true(skid.playing)
	assert_true(_audio.skidding)
	var loud: float = skid.volume_db
	_run(300.0, 300.0, false, 3)
	assert_gt(skid.volume_db, loud, "más derrape, más fuerte")
	_run(300.0, 0.0, false, 3)
	assert_false(skid.playing)


func test_nitro_suena_una_vez_al_activarse() -> void:
	var nitro: AudioStreamPlayer2D = _audio.get_node("Nitro")
	_run(300.0, 0.0, false, 2)
	assert_false(nitro.playing)
	_run(300.0, 0.0, true, 1)
	assert_true(nitro.playing)
	nitro.stop()
	_run(300.0, 0.0, true, 5)
	assert_false(nitro.playing, "no se repite mientras dura")


func test_choque_leve_no_suena_y_fuerte_si() -> void:
	var crash: AudioStreamPlayer2D = _audio.get_node("Crash")
	_audio.on_crash(10.0)
	assert_false(crash.playing)
	_audio.on_crash(400.0)
	assert_true(crash.playing)


func test_choques_seguidos_no_se_acumulan() -> void:
	var crash: AudioStreamPlayer2D = _audio.get_node("Crash")
	_audio.on_crash(300.0)
	crash.stop()
	_audio.on_crash(300.0)
	assert_false(crash.playing, "enfriamiento")
	_run(300.0, 0.0, false, 20)  # 0,33 s
	_audio.on_crash(300.0)
	assert_true(crash.playing)


func test_choque_mas_fuerte_suena_mas_alto() -> void:
	var crash: AudioStreamPlayer2D = _audio.get_node("Crash")
	_audio.on_crash(100.0)
	var soft: float = crash.volume_db
	_run(300.0, 0.0, false, 30)
	_audio.on_crash(500.0)
	assert_gt(crash.volume_db, soft)


func test_el_coche_avisa_al_audio_al_chocar() -> void:
	var crash: AudioStreamPlayer2D = _audio.get_node("Crash")
	_car._audio.on_crash(300.0)
	assert_true(crash.playing)


func test_los_sonidos_van_al_bus_sfx() -> void:
	for node: String in ["Engine", "Skid", "Crash", "Nitro"]:
		assert_eq((_audio.get_node(node) as AudioStreamPlayer2D).bus, &"SFX", node)
	assert_gt(AudioServer.get_bus_index(&"SFX"), 0)
	assert_gt(AudioServer.get_bus_index(&"Music"), 0)


# --- Carrera ---

func test_sonidos_de_carrera() -> void:
	var sounds: RaceSounds = add_child_autofree((load("res://scenes/race/race_sounds.tscn") as PackedScene).instantiate()) as RaceSounds
	sounds.beep()
	assert_true((sounds.get_node("Beep") as AudioStreamPlayer).playing)
	sounds.go()
	assert_true((sounds.get_node("Go") as AudioStreamPlayer).playing)
	sounds.finish()
	assert_true((sounds.get_node("Finish") as AudioStreamPlayer).playing)


func test_cuenta_atras_pita_una_vez_por_numero() -> void:
	var race: RaceManager = (load("res://scenes/race/race.tscn") as PackedScene).instantiate() as RaceManager
	race.countdown_seconds = 1.0
	add_child_autofree(race)
	var beeps: Array = [0]
	var beep_player: AudioStreamPlayer = race.get_node("Sounds/Beep")
	var was_playing: bool = false
	for i: int in 90:
		await wait_physics_frames(1)
		if beep_player.playing and not was_playing:
			beeps[0] += 1
		was_playing = beep_player.playing
	assert_gte(beeps[0], 1)
	assert_lte(beeps[0], 2, "1 s de cuenta atrás = 1 pitido, no uno por frame")


# --- Música ---

func test_musica_no_reinicia_si_es_la_misma() -> void:
	var stream: AudioStream = load("res://assets/audio/sfx/finish.ogg") as AudioStream
	Music.play(null, 0.0)
	Music.play(stream, 0.05)
	assert_eq(Music.current, stream)
	var player: AudioStreamPlayer = Music._active
	assert_true(player.playing)
	await wait_seconds(0.2)
	var pos: float = player.get_playback_position()
	Music.play(stream, 0.05)
	assert_eq(Music._active, player, "mismo reproductor")
	assert_gte(player.get_playback_position(), pos, "sigue donde iba")
	Music.play(null, 0.05)
	await wait_seconds(0.3)
	assert_false(player.playing, "silencio tras el fundido")


func test_musica_cambia_con_fundido_cruzado() -> void:
	var a: AudioStream = load("res://assets/audio/sfx/engine.ogg") as AudioStream
	var b: AudioStream = load("res://assets/audio/sfx/skid.ogg") as AudioStream
	Music.play(a, 0.05)
	var first: AudioStreamPlayer = Music._active
	Music.play(b, 0.05)
	assert_ne(Music._active, first)
	assert_eq(Music._active.stream, b)
	await wait_seconds(0.3)
	assert_false(first.playing, "la anterior se apaga al terminar el fundido")
	assert_true(Music._active.playing)
	Music.play(null, 0.0)
	await wait_seconds(0.1)


func test_la_musica_va_al_bus_music() -> void:
	assert_eq(Music._active.bus, &"Music")


func test_cada_pista_tiene_su_musica() -> void:
	for id: String in ["west_01", "west_02", "jungle_01", "jungle_02"]:
		assert_not_null((load("res://data/tracks/%s.tres" % id) as TrackData).music, id)
	assert_eq((load("res://data/tracks/west_01.tres") as TrackData).music, (load("res://data/tracks/west_02.tres") as TrackData).music)
	assert_ne((load("res://data/tracks/west_01.tres") as TrackData).music, (load("res://data/tracks/jungle_01.tres") as TrackData).music)


func test_musica_del_menu_existe_y_dura_un_minuto() -> void:
	var menu: AudioStream = load(Music.MENU_MUSIC_PATH) as AudioStream
	assert_not_null(menu)
	assert_between(menu.get_length(), 50.0, 70.0)


func test_la_carrera_pone_la_musica_de_su_pista() -> void:
	var race: RaceManager = (load("res://scenes/race/race.tscn") as PackedScene).instantiate() as RaceManager
	race.track_data = load("res://data/tracks/jungle_01.tres") as TrackData
	add_child_autofree(race)
	assert_eq(Music.current, race.track_data.music)
	assert_true(Music._active.playing)
	Music.play(null, 0.0)
