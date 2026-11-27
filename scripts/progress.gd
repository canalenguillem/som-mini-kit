class_name Progress
extends RefCounted
## Reglas del progreso, sin estado propio (el estado lo guarda GameState.progress).
##
## progress = {id_misión: {best: float, attempts: int}}
## - Una sala está superada si su mejor nota es ≥ 5.
## - La nota de una zona es la media de las mejores notas de sus salas (0 si no se ha hecho).
## - Una zona está superada si todas sus salas lo están.
## - Las zonas se abren en el orden del cuaderno: una zona está abierta cuando están superadas todas
##   las anteriores que ya tienen salas. Las que no tienen salas salen como «próximamente».

enum State { LOCKED, OPEN, PASSED, SOON }

const PASS_GRADE: float = 5.0


static func best(progress: Dictionary, mission_id: String) -> float:
	return float((progress.get(mission_id, {}) as Dictionary).get("best", 0.0))


static func attempts(progress: Dictionary, mission_id: String) -> int:
	return int((progress.get(mission_id, {}) as Dictionary).get("attempts", 0))


static func mission_passed(progress: Dictionary, mission_id: String) -> bool:
	return attempts(progress, mission_id) > 0 and best(progress, mission_id) >= PASS_GRADE


static func zone_grade(zone: ZoneData, progress: Dictionary) -> float:
	if zone.missions.is_empty():
		return 0.0
	var total: float = 0.0
	for m: MissionData in zone.missions:
		total += best(progress, m.id)
	return snappedf(total / zone.missions.size(), 0.1)


static func zone_passed(zone: ZoneData, progress: Dictionary) -> bool:
	if zone.missions.is_empty():
		return false
	for m: MissionData in zone.missions:
		if not mission_passed(progress, m.id):
			return false
	return true


static func rooms_passed(zone: ZoneData, progress: Dictionary) -> int:
	var n: int = 0
	for m: MissionData in zone.missions:
		if mission_passed(progress, m.id):
			n += 1
	return n


## Estado de la zona `index` dentro de `zones` (ordenadas por tema).
static func zone_state(zones: Array[ZoneData], index: int, progress: Dictionary) -> State:
	var zone: ZoneData = zones[index]
	if zone.missions.is_empty():
		return State.SOON
	for k: int in index:
		if not zones[k].missions.is_empty() and not zone_passed(zones[k], progress):
			return State.LOCKED
	return State.PASSED if zone_passed(zone, progress) else State.OPEN


## Apunta un intento y devuelve el progreso nuevo (no toca el original).
static func record(progress: Dictionary, mission_id: String, grade: float) -> Dictionary:
	var out: Dictionary = progress.duplicate(true)
	var entry: Dictionary = out.get(mission_id, {"best": 0.0, "attempts": 0})
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	entry["best"] = maxf(float(entry.get("best", 0.0)), clampf(grade, 0.0, 10.0))
	out[mission_id] = entry
	return out


## Limpia un progreso leído del disco: ignora lo mal tipado.
static func sanitize(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary:
		return out
	for id: Variant in raw:
		var e: Variant = raw[id]
		if not id is String or not e is Dictionary:
			continue
		var b: Variant = (e as Dictionary).get("best")
		var a: Variant = (e as Dictionary).get("attempts")
		if (b is float or b is int) and (a is float or a is int) and int(a) >= 0:
			out[id] = {"best": clampf(float(b), 0.0, 10.0), "attempts": int(a)}
	return out
