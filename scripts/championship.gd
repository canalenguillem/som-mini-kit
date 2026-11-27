class_name Championship
extends RefCounted
## Estado de un campeonato en curso: puntos por carrera y clasificación. Lógica pura.

const POINTS: Array[int] = [10, 6, 3, 1]  ## por puesto 1º..4º

var data: ChampionshipData
var race_index: int = 0  ## carreras ya disputadas
var player_name: String = ""

var _points: Dictionary = {}  ## nombre → puntos
var _wins: Dictionary = {}  ## nombre → victorias
var _order: Array[String] = []  ## orden de aparición (desempate final)


func _init(championship_data: ChampionshipData) -> void:
	data = championship_data


func race_count() -> int:
	return data.tracks.size()


func is_finished() -> bool:
	return race_index >= race_count()


## Pista de la próxima carrera; null si el campeonato ha terminado.
func current_track() -> TrackData:
	return null if is_finished() else data.tracks[race_index]


## Suma los puntos de una carrera. results: [{name, position, is_player?}] (como Events.race_finished).
func record_race(results: Array) -> void:
	if is_finished():
		return
	for r: Dictionary in results:
		var racer: String = str(r["name"])
		var position: int = int(r["position"])
		if not _points.has(racer):
			_points[racer] = 0
			_wins[racer] = 0
			_order.append(racer)
		if position >= 1 and position <= POINTS.size():
			_points[racer] += POINTS[position - 1]
		if position == 1:
			_wins[racer] += 1
		if bool(r.get("is_player", false)):
			player_name = racer
	race_index += 1


## [{name, points, wins, position}] del primero al último. Desempate: más victorias, luego orden de aparición.
func standings() -> Array[Dictionary]:
	var names: Array[String] = _order.duplicate()
	names.sort_custom(func(a: String, b: String) -> bool:
		if _points[a] != _points[b]:
			return _points[a] > _points[b]
		if _wins[a] != _wins[b]:
			return _wins[a] > _wins[b]
		return _order.find(a) < _order.find(b))
	var out: Array[Dictionary] = []
	for i: int in names.size():
		out.append({"name": names[i], "points": _points[names[i]], "wins": _wins[names[i]], "position": i + 1})
	return out


## Puesto final del jugador (0 si aún no ha corrido).
func player_position() -> int:
	for entry: Dictionary in standings():
		if entry["name"] == player_name:
			return int(entry["position"])
	return 0
