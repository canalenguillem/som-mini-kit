class_name Hud
extends CanvasLayer
## HUD de carrera: vuelta, posición, tiempo, nitro y cuenta atrás. Solo muestra; no decide nada.

@onready var _lap: Label = $LapLabel
@onready var _position: Label = $PositionLabel
@onready var _time: Label = $TimeLabel
@onready var _nitro_label: Label = $NitroLabel
@onready var _nitro_bar: ProgressBar = $NitroBar
@onready var _countdown: Label = $CountdownLabel


func set_lap(lap: int, total: int) -> void:
	_lap.text = "Vuelta %d/%d" % [lap, total]


func set_position_text(pos: int, count: int) -> void:
	_position.text = "%dº/%d" % [pos, count]


func set_time(seconds: float) -> void:
	_time.text = RaceTime.format(seconds)


func set_nitro(charges: int, boosting: bool, fraction: float) -> void:
	_nitro_label.text = "NITRO x%d" % charges
	_nitro_bar.value = fraction if boosting else (1.0 if charges > 0 else 0.0)


## Texto grande central; cadena vacía lo oculta.
func set_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.visible = not text.is_empty()
