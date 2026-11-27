class_name RivalData
extends Resource
## Personalidad de un piloto IA.

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE  ## carrocería del placeholder (si no hay sprite)
@export var sprite: Texture2D
@export_range(-1.0, 1.0) var lane_offset: float = 0.0  ## -1 interior … 1 exterior
@export_range(0.5, 1.2) var skill: float = 1.0  ## multiplica la velocidad de paso por curva
@export_range(0.0, 1.0) var mistakes: float = 0.1  ## ruido en el volante
@export_range(0.0, 1.0) var nitro_eagerness: float = 0.5
