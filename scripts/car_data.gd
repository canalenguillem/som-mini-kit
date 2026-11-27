class_name CarData
extends Resource
## Datos base de un coche (sin mejoras). Ver CarStats para los valores finales.

@export var id: String = ""
@export var display_name: String = ""
@export var price: int = 0
@export_multiline var description: String = ""
@export var sprite: Texture2D
@export var color: Color = Color(0.85, 0.2, 0.15)  ## carrocería del placeholder
@export_group("Base")
@export var base_max_speed: float = 420.0  ## px/s
@export var base_acceleration: float = 520.0  ## px/s²
@export var base_grip: float = 8.0  ## 1/s
@export var base_steering: float = 3.2  ## rad/s a velocidad completa
@export var base_nitro_charges: int = 1
@export_range(0.0, 1.0) var base_offroad: float = 0.0  ## fracción de la penalización de superficie que se anula
@export_group("Fijos")
@export var braking: float = 900.0  ## px/s²
@export var drag: float = 0.6  ## 1/s
@export var max_reverse: float = 140.0  ## px/s
@export var nitro_boost: float = 1.35  ## multiplicador de velocidad máxima
@export var nitro_duration: float = 1.5  ## s
