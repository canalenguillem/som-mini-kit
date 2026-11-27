class_name CarController
extends Node
## Base de los controladores. Produce un DriveInput por frame de física.

var owner_car: Car  ## lo asigna Car en _ready()


func get_input(_delta: float) -> DriveInput:
	return DriveInput.new()
