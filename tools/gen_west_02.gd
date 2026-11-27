extends SceneTree
## Pista west_02 "Paso del Ferrocarril": tierra y arena, barriles y un tren que cruza la recta.
## Uso: godot --headless --path . -s res://tools/gen_west_02.gd   (después ./tools/check.sh)


func _initialize() -> void:
	var points: Array[Vector2] = [
		Vector2(16, 36), Vector2(30, 36), Vector2(46, 36), Vector2(56, 32), Vector2(58, 22),
		Vector2(51, 13), Vector2(40, 10), Vector2(29, 15), Vector2(31, 24), Vector2(22, 27),
		Vector2(12, 22), Vector2(6, 27), Vector2(8, 34),
	]
	var def: Dictionary = {
		"id": "west_02", "display_name": "Paso del Ferrocarril", "theme": "west",
		"music": "res://assets/audio/music/west.ogg", "laps": 3, "reward_mult": 1.2, "unlock_cost": 400,
		"points": points, "half_width": 2.2, "shoulder": 1.1,
		"road_surface": "dirt", "shoulder_surface": "sand",
		"segments": [
			{"from": 0.55, "to": 0.63, "surface": "sand"},
		],
		"barrels": [
			{"p": 0.30, "lateral": -1.2, "count": 3},
			{"p": 0.50, "lateral": 1.3, "count": 3},
			{"p": 0.78, "lateral": -1.2, "count": 2},
		],
		"cacti": [
			{"p": 0.08, "lateral": -3.0}, {"p": 0.40, "lateral": 3.0}, {"p": 0.90, "lateral": 3.0},
		],
		"trains": [
			{"p": 0.18, "period": 12.0, "warning": 2.0, "speed": 650.0, "phase": 0.0},
		],
	}
	quit(0 if TrackBuilder.new().build(def) else 1)
