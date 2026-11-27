class_name UpgradeDef
extends Resource
## Definición de una mejora: "engine" | "turbo" | "tires" | "nitro".

@export var id: String = ""
@export var display_name: String = ""
@export var base_cost: int = 100
@export var cost_growth: float = 1.6
@export var per_level: float = 0.06  ## fracción por nivel (nitro: cargas por nivel)
@export var max_level: int = 5
