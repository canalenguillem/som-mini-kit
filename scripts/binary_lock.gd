class_name BinaryLock
extends RefCounted
## Cerrojo binario: escribir un número de 0 a 255 con 8 interruptores (chuleta 128…1).
## Generador y corrector de la misión de prueba; se reutilizará en la misión 3.

const WEIGHTS: Array[int] = [128, 64, 32, 16, 8, 4, 2, 1]


static func generate(exercise_seed: int) -> int:
	return ExerciseSeed.rng(exercise_seed).randi_range(1, 255)


static func bits_of(value: int) -> Array[bool]:
	var out: Array[bool] = []
	for w: int in WEIGHTS:
		out.append(value & w != 0)
	return out


static func value_of(bits: Array[bool]) -> int:
	var total: int = 0
	for i: int in mini(bits.size(), WEIGHTS.size()):
		if bits[i]:
			total += WEIGHTS[i]
	return total


## Pasos del método de la chuleta: de izquierda a derecha, si el peso cabe en lo que queda, 1 y resta.
## [{weight, rest, on, left}]
static func steps(target: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rest: int = target
	for w: int in WEIGHTS:
		var on: bool = w <= rest
		var left: int = rest - w if on else rest
		out.append({"weight": w, "rest": rest, "on": on, "left": left})
		rest = left
	return out


## Corrige: un acierto por interruptor. Explica el primer interruptor mal puesto.
static func evaluate(target: int, bits: Array[bool]) -> ChallengeResult:
	var r := ChallengeResult.new()
	r.total = WEIGHTS.size()
	var expected: Array[bool] = bits_of(target)
	var first_wrong: int = -1
	for i: int in WEIGHTS.size():
		var given: bool = i < bits.size() and bits[i]
		if given == expected[i]:
			r.correct += 1
		elif first_wrong < 0:
			first_wrong = i
	if first_wrong >= 0:
		var sum: int = value_of(bits)
		r.add_mistake("BIN_SUM_MISMATCH", {"sum": sum, "target": target})
		var step: Dictionary = steps(target)[first_wrong]
		var key: String = "BIN_BIT_SHOULD_BE_ON" if step["on"] else "BIN_BIT_SHOULD_BE_OFF"
		r.add_mistake(key, {"weight": step["weight"], "rest": step["rest"]})
	return r
