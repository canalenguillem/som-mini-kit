class_name RaceSounds
extends Node
## Sonidos de la carrera que no pertenecen a un coche: cuenta atrás, salida y meta.

@onready var _beep: AudioStreamPlayer = $Beep
@onready var _go: AudioStreamPlayer = $Go
@onready var _finish: AudioStreamPlayer = $Finish


func beep() -> void:
	_beep.play()


func go() -> void:
	_go.play()


func finish() -> void:
	_finish.play()
