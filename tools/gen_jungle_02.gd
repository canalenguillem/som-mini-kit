extends SceneTree
## Pista jungle_02 "Puente de Lianas": hierba y barro, un puente estrecho sobre el río y troncos.
## Uso: godot --headless --path . -s res://tools/gen_jungle_02.gd   (después ./tools/check.sh)


func _initialize() -> void:
	var points: Array[Vector2] = [
		Vector2(18, 40), Vector2(32, 40), Vector2(46, 40), Vector2(56, 36), Vector2(58, 26),
		Vector2(52, 18), Vector2(54, 9), Vector2(42, 5), Vector2(29, 8), Vector2(21, 15),
		Vector2(26, 23), Vector2(19, 30), Vector2(8, 28), Vector2(6, 36), Vector2(9, 40),
	]
	var def: Dictionary = {
		"id": "jungle_02", "display_name": "Puente de Lianas", "theme": "jungle",
		"music": "res://assets/audio/music/jungle.ogg", "laps": 3, "reward_mult": 1.6, "unlock_cost": 1200,
		"points": points, "half_width": 2.2, "shoulder": 1.1,
		"road_surface": "grass", "shoulder_surface": "mud",
		"segments": [
			# Puente estrecho: calzada más estrecha y agua a los lados (caer = perder velocidad)
			{"from": 0.40, "to": 0.50, "half_width": 1.5, "shoulder_surface": "water"},
			{"from": 0.12, "to": 0.18, "surface": "mud"},
		],
		"dodges": [
			{"p": 0.28, "amp": 0.9, "span": 0.05, "log": true},
			{"p": 0.65, "amp": -0.9, "span": 0.05, "log": true},
			{"p": 0.88, "amp": 0.9, "span": 0.05, "log": true},
		],
	}
	quit(0 if TrackBuilder.new().build(def) else 1)
