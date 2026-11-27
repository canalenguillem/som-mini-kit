class_name ExerciseSeed
extends RefCounted
## Semillas de ejercicio. Misma semilla → mismo ejercicio en cualquier equipo
## (RandomNumberGenerator es PCG32, determinista entre plataformas).

const MIN_SEED: int = 100000  ## seis cifras: fácil de dictar en clase
const MAX_SEED: int = 999999


## Generador listo para usar con esa semilla.
static func rng(exercise_seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = exercise_seed
	return r


## Semilla nueva al azar, de seis cifras.
static func new_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi_range(MIN_SEED, MAX_SEED)


## Semilla derivada y estable para una parte del ejercicio (fase, reto…).
static func derive(exercise_seed: int, salt: String) -> int:
	return ("%d:%s" % [exercise_seed, salt]).hash() & 0x7fffffff
