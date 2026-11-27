class_name ZoneData
extends Resource
## Una zona del mapa de la placa base = un tema del cuaderno. Puede tener varias salas (misiones).

@export var topic: int = 0
@export var title_key: String = ""
@export var component_key: String = ""  ## pieza de la placa donde está (CPU, RAM, BIOS…)
@export var missions: Array[MissionData] = []  ## vacío = todavía no está hecha
@export var board_position: Vector2 = Vector2(0.5, 0.5)  ## en la placa, de 0 a 1
