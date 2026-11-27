class_name Grading
extends RefCounted
## Nota de misión (0–10).
##
## nota = 10 · aciertos · (p_aciertos + p_intentos · intentos + p_pistas · pistas) / suma_pesos
##   aciertos = correctos / total de la última comprobación
##   intentos = max(0, 1 − fallidas · penalización)
##   pistas   = 1 − usadas / disponibles   (1 si no hay pistas)
## Intentos y pistas se multiplican por los aciertos: entregar en blanco da 0, no 3.


static func grade(correct: int, total: int, failed_checks: int, hints_used: int,
		hints_available: int, weights: GradingWeights) -> float:
	if total <= 0:
		return 0.0
	var acc: float = clampf(float(correct) / float(total), 0.0, 1.0)
	var att: float = maxf(0.0, 1.0 - float(maxi(failed_checks, 0)) * weights.penalty_per_failed_check)
	var hint: float = 1.0
	if hints_available > 0:
		hint = 1.0 - clampf(float(hints_used) / float(hints_available), 0.0, 1.0)
	var sum: float = weights.accuracy + weights.attempts + weights.hints
	if sum <= 0.0:
		return 0.0
	var raw: float = 10.0 * acc * (weights.accuracy + weights.attempts * att + weights.hints * hint) / sum
	return snappedf(clampf(raw, 0.0, 10.0), 0.1)


static func passed(value: float, weights: GradingWeights) -> bool:
	return value >= weights.pass_grade


## «7,5» en catalán y castellano; «7.5» en inglés.
static func format_grade(value: float, locale: String) -> String:
	var text: String = "%.1f" % value
	return text if locale.begins_with("en") else text.replace(".", ",")
