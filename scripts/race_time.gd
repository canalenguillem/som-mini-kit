class_name RaceTime
extends RefCounted
## Formato de tiempos de carrera.


## 83.42 → "1:23.42"
static func format(seconds: float) -> String:
	var s: float = maxf(seconds, 0.0)
	var minutes: int = int(s / 60.0)
	var rest: float = s - minutes * 60.0
	return "%d:%05.2f" % [minutes, rest]
