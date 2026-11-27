extends GutTest
## Championship: puntos 10/6/3/1, clasificación, desempate, avance de pistas y premio final.

const GameStateScript: GDScript = preload("res://autoload/game_state.gd")

var _data: ChampionshipData
var _ch: Championship


func before_each() -> void:
	_data = load("res://data/championships/copa_salvaje.tres") as ChampionshipData
	_ch = Championship.new(_data)


## results de una carrera con el orden dado (el jugador es "Jugador").
func _race(order: Array[String]) -> Array:
	var out: Array = []
	for i: int in order.size():
		out.append({"name": order[i], "position": i + 1, "time": 80.0 + i, "is_player": order[i] == "Jugador"})
	return out


func test_datos_del_campeonato() -> void:
	assert_eq(_data.tracks.size(), 4)
	assert_eq(_ch.race_count(), 4)
	assert_eq(_ch.current_track().id, "west_01")
	assert_false(_ch.is_finished())


func test_puntos_por_puesto() -> void:
	_ch.record_race(_race(["Jugador", "Rayo", "Bruto", "Despiste"]))
	var s: Array[Dictionary] = _ch.standings()
	assert_eq(s[0]["name"], "Jugador")
	assert_eq(s[0]["points"], 10)
	assert_eq(s[1]["points"], 6)
	assert_eq(s[2]["points"], 3)
	assert_eq(s[3]["points"], 1)


func test_los_puntos_se_acumulan_y_reordenan() -> void:
	_ch.record_race(_race(["Jugador", "Rayo", "Bruto", "Despiste"]))
	_ch.record_race(_race(["Rayo", "Bruto", "Jugador", "Despiste"]))
	_ch.record_race(_race(["Rayo", "Bruto", "Despiste", "Jugador"]))
	var s: Array[Dictionary] = _ch.standings()
	assert_eq(s[0]["name"], "Rayo")  # 6+10+10 = 26
	assert_eq(s[0]["points"], 26)
	assert_eq(s[1]["name"], "Bruto")  # 3+6+6 = 15
	assert_eq(_ch.player_position(), 3)  # Jugador: 10+3+1 = 14; Despiste: 1+1+3 = 5
	assert_eq(s[2]["points"], 14)


func test_desempate_por_victorias() -> void:
	# A: 10+1+1 = 12 con 1 victoria. B: 6+3+3 = 12 sin victorias. B aparece primero.
	_ch.record_race([{"name": "B", "position": 2}, {"name": "A", "position": 1}])
	_ch.record_race([{"name": "B", "position": 3}, {"name": "A", "position": 4}])
	_ch.record_race([{"name": "B", "position": 3}, {"name": "A", "position": 4}])
	var s: Array[Dictionary] = _ch.standings()
	assert_eq(s[0]["points"], 12)
	assert_eq(s[1]["points"], 12)
	assert_eq(s[0]["name"], "A", "más victorias gana el empate")


func test_empate_total_respeta_el_orden_de_aparicion() -> void:
	_ch.record_race([
		{"name": "A", "position": 1}, {"name": "B", "position": 1},
	])  # ambos 10 puntos y 1 victoria
	var s: Array[Dictionary] = _ch.standings()
	assert_eq(s[0]["name"], "A")
	assert_eq(s[1]["name"], "B")


func test_avanza_de_pista_y_termina() -> void:
	var ids: Array[String] = []
	while not _ch.is_finished():
		ids.append(_ch.current_track().id)
		_ch.record_race(_race(["Jugador", "Rayo", "Bruto", "Despiste"]))
	assert_eq(ids, ["west_01", "west_02", "jungle_01", "jungle_02"] as Array[String])
	assert_null(_ch.current_track())
	assert_eq(_ch.race_index, 4)


func test_carreras_extra_no_cuentan() -> void:
	for i: int in 4:
		_ch.record_race(_race(["Jugador", "Rayo", "Bruto", "Despiste"]))
	_ch.record_race(_race(["Rayo", "Jugador", "Bruto", "Despiste"]))
	assert_eq(_ch.standings()[0]["points"], 40)
	assert_eq(_ch.race_index, 4)


func test_puesto_del_jugador_antes_de_correr() -> void:
	assert_eq(_ch.player_position(), 0)


func test_puestos_fuera_del_top4_no_puntuan() -> void:
	_ch.record_race([{"name": "X", "position": 5}])
	assert_eq(_ch.standings()[0]["points"], 0)


# --- Integración con GameState (instancia propia, sin tocar el real) ---

func _gs() -> Node:
	var gs: Node = autofree(GameStateScript.new())
	gs.load_catalog()
	gs.reset()
	return gs


func test_gamestate_campeonato_completo_paga_premio_final() -> void:
	var gs: Node = _gs()
	gs.start_championship(_data)
	assert_eq(gs.current_track.id, "west_01")
	var expected: int = 0
	for i: int in 4:
		var track: TrackData = gs.current_track
		gs._on_race_finished(_race(["Jugador", "Rayo", "Bruto", "Despiste"]))
		expected += roundi(500 * track.reward_mult)
		if i < 3:
			assert_eq(gs.last_championship_prize, 0)
			gs.current_track = gs.current_championship.current_track()
	assert_true(gs.current_championship.is_finished())
	assert_eq(gs.last_championship_prize, 2000)
	assert_eq(gs.money, expected + 2000)


func test_gamestate_carrera_rapida_no_toca_campeonato() -> void:
	var gs: Node = _gs()
	gs.start_championship(_data)
	gs.start_quick_race(gs.tracks["west_01"])
	assert_null(gs.current_championship)
	gs._on_race_finished(_race(["Jugador", "Rayo", "Bruto", "Despiste"]))
	assert_eq(gs.last_championship_prize, 0)
	assert_eq(gs.money, 500)


func test_gamestate_record_se_marca() -> void:
	var gs: Node = _gs()
	var track: TrackData = gs.tracks["west_01"]
	gs.apply_race_result(track, 1, 90.0)
	assert_true(gs.last_record, "primer tiempo es récord")
	gs.apply_race_result(track, 1, 95.0)
	assert_false(gs.last_record)
	gs.apply_race_result(track, 1, 85.0)
	assert_true(gs.last_record)


func test_premio_final_por_puesto() -> void:
	assert_eq(Economy.championship_prize(1, 1.0), 2000)
	assert_eq(Economy.championship_prize(2, 1.0), 1200)
	assert_eq(Economy.championship_prize(3, 1.0), 600)
	assert_eq(Economy.championship_prize(4, 1.0), 200)
	assert_eq(Economy.championship_prize(5, 1.0), 0)
	assert_eq(Economy.championship_prize(1, 1.5), 3000)
