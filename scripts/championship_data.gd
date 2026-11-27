class_name ChampionshipData
extends Resource
## Definición de un campeonato: pistas en orden y multiplicador del premio final.

@export var id: String = ""
@export var display_name: String = ""
@export var tracks: Array[TrackData] = []
@export var reward_mult: float = 1.0
