class_name MissionContent
extends Control
## Base de los retos de una misión. MissionShell crea la escena, llama a setup() en cada fase
## y a check() al comprobar. La lógica (generar y corregir) va en scripts/, no aquí.

enum Phase { EXAMPLE, GUIDED, SOLO }

## Texto para el panel de mensajes del marco (BBCode, ya traducido).
signal feedback(text: String)
## El contenido avisa de si ya se puede comprobar o entregar (p. ej. cuando acaba una partida).
signal check_enabled(enabled: bool)

var phase: Phase = Phase.EXAMPLE
var exercise_seed: int = 0


## Virtual: recibe MissionData.params antes de la primera fase.
func configure(_params: Dictionary) -> void:
	pass


## Prepara el reto para una fase. EXAMPLE: resuelto y explicado; GUIDED: parte ya puesta; SOLO: en blanco.
func setup(new_phase: Phase, new_seed: int) -> void:
	phase = new_phase
	exercise_seed = new_seed
	_build()


## Virtual: construye el reto con `phase` y `exercise_seed`.
func _build() -> void:
	pass


## Virtual: corrige la respuesta actual.
func check() -> ChallengeResult:
	return ChallengeResult.new()


## Virtual: cuántas pistas hay.
func hint_count() -> int:
	return 0


## Virtual: texto de la pista `index` ya traducido.
func hint(_index: int) -> String:
	return ""
