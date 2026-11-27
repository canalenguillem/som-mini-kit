class_name ChallengeResult
extends RefCounted
## Resultado de corregir una respuesta: aciertos y fallos concretos.
## Cada fallo es {key, args}: una clave de traducción y sus valores, para decir
## qué falla y cómo arreglarlo en el idioma del alumno.

var correct: int = 0
var total: int = 0
var mistakes: Array[Dictionary] = []


func add_mistake(key: String, args: Dictionary = {}) -> void:
	mistakes.append({"key": key, "args": args})


func is_perfect() -> bool:
	return total > 0 and correct == total


func accuracy() -> float:
	return 0.0 if total <= 0 else float(correct) / float(total)


## Fallos traducidos al idioma actual.
func messages() -> PackedStringArray:
	var out: PackedStringArray = []
	for m: Dictionary in mistakes:
		out.append(ChallengeResult.message_of(m))
	return out


static func message_of(mistake: Dictionary) -> String:
	return TranslationServer.translate(str(mistake.get("key", ""))).format(mistake.get("args", {}) as Dictionary)
