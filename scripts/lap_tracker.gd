class_name LapTracker
extends RefCounted
## Cuenta vueltas de un coche. Los checkpoints deben pasarse en orden; el 0 es la meta.
## Los coches salen detrás de la meta: empiezan con el 0 "ya pasado".

signal lap_completed(lap: int)

var checkpoint_count: int
var total_laps: int
var laps: int = 0
var last_checkpoint: int = 0
var finished: bool:
	get:
		return laps >= total_laps


func _init(count: int, laps_total: int) -> void:
	checkpoint_count = count
	total_laps = laps_total


## Registra el paso por un checkpoint. Devuelve true si cuenta (era el siguiente en orden).
## Repetir el mismo, saltarse uno o pasar marcha atrás no cuenta.
func passed(index: int) -> bool:
	if finished:
		return false
	if index != (last_checkpoint + 1) % checkpoint_count:
		return false
	last_checkpoint = index
	if index == 0:
		laps += 1
		lap_completed.emit(laps)
	return true
