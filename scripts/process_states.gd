class_name ProcessStates
extends RefCounted
## Calentamiento de la misión 4: el diagrama de estados del proceso (cuaderno, tema 4, apartado 6).
## Cada situación tiene una sola transición correcta. La opción «Bloqueado → En ejecución» no existe en
## el diagrama: está para detectar el error clásico del examen.

## Transiciones que se ofrecen, en el orden del libro. La última es la trampa.
const TRANSITIONS: Array[String] = [
	"NEW_READY", "READY_RUNNING", "RUNNING_READY", "RUNNING_BLOCKED", "BLOCKED_READY", "RUNNING_TERMINATED",
	"BLOCKED_RUNNING",
]
const TRAP: int = 6
## Situaciones: clave de texto → índice de la transición correcta.
const SITUATIONS: Dictionary = {
	"ST_SIT_CREATED": 0, "ST_SIT_LAUNCHED": 0,
	"ST_SIT_CHOSEN": 1, "ST_SIT_DISPATCHED": 1,
	"ST_SIT_QUANTUM": 2, "ST_SIT_QUANTUM_AGAIN": 2,
	"ST_SIT_DISK": 3, "ST_SIT_KEY": 3, "ST_SIT_NETWORK": 3,
	"ST_SIT_DISK_DONE": 4, "ST_SIT_KEY_DONE": 4,
	"ST_SIT_LAST": 5, "ST_SIT_EXIT": 5,
}
const COUNT: int = 6


## Elige COUNT situaciones distintas, sin repetir transición mientras se pueda.
static func generate(exercise_seed: int) -> Array[String]:
	var rng: RandomNumberGenerator = ExerciseSeed.rng(exercise_seed)
	var keys: Array = SITUATIONS.keys()
	keys.sort()
	var by_transition: Dictionary = {}
	for k: String in keys:
		var t: int = SITUATIONS[k]
		if not by_transition.has(t):
			by_transition[t] = []
		(by_transition[t] as Array).append(k)
	var chosen: Array[String] = []
	for t: int in range(6):
		var options: Array = by_transition[t]
		chosen.append(options[rng.randi_range(0, options.size() - 1)])
	# Orden al azar (Fisher-Yates con el mismo generador)
	for i: int in range(chosen.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = chosen[i]
		chosen[i] = chosen[j]
		chosen[j] = tmp
	return chosen.slice(0, COUNT)


static func answer_of(situation: String) -> int:
	return int(SITUATIONS.get(situation, -1))


## answers[i] = índice de transición elegido para la situación i (-1 = sin contestar).
static func evaluate(situations: Array[String], answers: Array) -> ChallengeResult:
	var r := ChallengeResult.new()
	r.total = situations.size()
	var trap_reported: bool = false
	for i: int in situations.size():
		var given: int = int(answers[i]) if i < answers.size() else -1
		var expected: int = answer_of(situations[i])
		if given == expected:
			r.correct += 1
		elif given == TRAP:
			if not trap_reported:
				r.add_mistake("ST_MISTAKE_TRAP", {"n": i + 1})
				trap_reported = true
		elif given < 0:
			r.add_mistake("ST_MISTAKE_EMPTY", {"n": i + 1})
		else:
			r.add_mistake("ST_MISTAKE_" + TRANSITIONS[expected], {"n": i + 1})
	return r
