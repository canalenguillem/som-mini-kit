extends SceneTree
## Pista west_01 "Cañón del Coyote": calzada de tierra, arcén de arena, barriles y cactus.
## Uso: godot --headless --path . -s res://tools/gen_west_01.gd   (después ./tools/check.sh)


func _initialize() -> void:
	var points: Array[Vector2] = [
		Vector2(24, 38), Vector2(38, 38), Vector2(54, 38), Vector2(63, 34), Vector2(66, 24),
		Vector2(58, 16), Vector2(46, 18), Vector2(38, 26), Vector2(28, 24), Vector2(23, 14),
		Vector2(15, 9), Vector2(8, 13), Vector2(5, 22), Vector2(6, 32), Vector2(14, 38),
	]
	var def: Dictionary = {
		"id": "west_01", "display_name": "Cañón del Coyote", "theme": "west",
		"music": "res://assets/audio/music/west.ogg", "laps": 3, "reward_mult": 1.0, "unlock_cost": 0,
		"points": points, "half_width": 2.2, "shoulder": 1.1,
		"road_surface": "dirt", "shoulder_surface": "sand",
		"segments": [
			{"from": 0.30, "to": 0.38, "surface": "sand"},  # duna que cruza la calzada
		],
		"barrels": [
			{"p": 0.07, "lateral": 1.2, "count": 3},
			{"p": 0.60, "lateral": -1.3, "count": 3},
			{"p": 0.85, "lateral": 1.2, "count": 2},
		],
		"cacti": [
			{"p": 0.12, "lateral": 3.0}, {"p": 0.45, "lateral": -3.0}, {"p": 0.72, "lateral": 3.0},
		],
	}
	quit(0 if TrackBuilder.new().build(def) else 1)
