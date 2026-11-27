extends GutTest
## Música: fundido cruzado, bus y pista del menú.


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
	var a: AudioStream = load("res://assets/audio/sfx/beep.ogg") as AudioStream
	var b: AudioStream = load("res://assets/audio/sfx/go.ogg") as AudioStream
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


func test_musica_del_menu_existe_y_dura_un_minuto() -> void:
	var menu: AudioStream = load(Music.MENU_MUSIC_PATH) as AudioStream
	assert_not_null(menu)
	assert_between(menu.get_length(), 50.0, 70.0)
