extends SceneTree
## Pista jungle_01 "Río Perdido": calzada de hierba, arcén de barro, troncos, barrizal y un vado.
## Uso: godot --headless --path . -s res://tools/gen_jungle_01.gd   (después ./tools/check.sh)


func _initialize() -> void:
	var points: Array[Vector2] = [
		Vector2(10, 32), Vector2(10, 20), Vector2(14, 10), Vector2(26, 6), Vector2(38, 10),
		Vector2(46, 18), Vector2(56, 20), Vector2(64, 27), Vector2(62, 37), Vector2(52, 41),
		Vector2(42, 37), Vector2(36, 29), Vector2(26, 27), Vector2(23, 36), Vector2(16, 43),
		Vector2(10, 43),
	]
	var def: Dictionary = {
		"id": "jungle_01", "display_name": "Río Perdido", "theme": "jungle",
		"music": "res://assets/audio/music/jungle.ogg", "laps": 3, "reward_mult": 1.4, "unlock_cost": 800,
		"points": points, "half_width": 2.2, "shoulder": 1.1,
		"road_surface": "grass", "shoulder_surface": "mud",
		"segments": [
			{"from": 0.20, "to": 0.28, "surface": "mud"},  # barrizal
			{"from": 0.56, "to": 0.62, "surface": "water"},  # vado del río
		],
		"dodges": [
			{"p": 0.10, "amp": 0.9, "span": 0.05, "log": true},
			{"p": 0.40, "amp": -0.9, "span": 0.05, "log": true},
			{"p": 0.78, "amp": 0.9, "span": 0.05, "log": true},
		],
	}
	quit(0 if TrackBuilder.new().build(def) else 1)
