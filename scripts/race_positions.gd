class_name RacePositions
extends RefCounted
## Ordenación de coches en carrera. Lógica pura.


## Puntuación de avance: vueltas × checkpoints + último checkpoint + fracción hasta el siguiente.
## La fracción puede ser algo negativa (coche aún detrás de la meta en la parrilla).
static func score(laps: int, last_checkpoint: int, fraction: float, checkpoint_count: int) -> float:
	return float(laps * checkpoint_count + last_checkpoint) + clampf(fraction, -1.0, 1.0)


## Índices de los coches ordenados del primero al último. Empates: gana el índice menor.
static func order(scores: Array[float]) -> Array[int]:
	var idx: Array[int] = []
	for i: int in scores.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool:
		if scores[a] != scores[b]:
			return scores[a] > scores[b]
		return a < b)
	return idx
