class_name TrackData
extends Resource
## Datos de una pista.

@export var id: String = ""
@export var display_name: String = ""
@export var theme: String = ""
@export var scene: PackedScene
@export var laps: int = 3
@export var reward_mult: float = 1.0
@export var unlock_cost: int = 0
@export var thumbnail: Texture2D
@export var music: AudioStream  ## música de la carrera en esta pista
