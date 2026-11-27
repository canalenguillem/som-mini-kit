extends Node
## Bus de señales globales.

signal race_started
signal lap_completed(car: Car, lap: int)
## results: [{name, position, time, is_player}] ordenado por puesto.
signal race_finished(results: Array)
signal money_changed(amount: int)
