class_name PlayerController
extends CarController
## Lee las acciones del InputMap y las traduce a DriveInput.


func get_input(_delta: float) -> DriveInput:
	var input := DriveInput.new()
	input.throttle = Input.get_action_strength("accelerate")
	input.brake = Input.get_action_strength("brake")
	input.steer = Input.get_axis("steer_left", "steer_right")
	input.nitro = Input.is_action_just_pressed("nitro")
	input.reset = Input.is_action_just_pressed("reset")
	return input
