class_name Economy
extends RefCounted
## Reglas económicas puras: coste de mejoras y premios de carrera.

const PRIZES: Array[int] = [500, 300, 150, 50]  ## por puesto 1º..4º, antes de reward_mult
const CHAMPIONSHIP_PRIZES: Array[int] = [2000, 1200, 600, 200]  ## premio final del campeonato por puesto


## Coste de comprar el siguiente nivel, estando en `level`: base × crecimiento^nivel.
static func upgrade_cost(def: UpgradeDef, level: int) -> int:
	return roundi(def.base_cost * pow(def.cost_growth, level))


## Premio por puesto (1 = primero) multiplicado por la pista. Fuera de los 4 primeros: 0.
static func prize(position: int, reward_mult: float) -> int:
	if position < 1 or position > PRIZES.size():
		return 0
	return roundi(PRIZES[position - 1] * reward_mult)


## Premio final de un campeonato por puesto en la clasificación. Fuera de los 4 primeros: 0.
static func championship_prize(position: int, reward_mult: float) -> int:
	if position < 1 or position > CHAMPIONSHIP_PRIZES.size():
		return 0
	return roundi(CHAMPIONSHIP_PRIZES[position - 1] * reward_mult)
