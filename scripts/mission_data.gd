class_name MissionData
extends Resource
## Datos de una misión. La lógica va en scripts/, la interfaz en scenes/missions/<id>/.

@export var id: String = ""  ## «m4», «sample»…
@export var topic: int = 0  ## tema del cuaderno (0 = misión de prueba)
@export var title_key: String = ""
@export var criteria: PackedStringArray = []  ## criterios RA del RD 1691/2007, p. ej. «RA4 c)»
@export_file("*.tscn") var content_scene: String = ""  ## escena que hereda de MissionContent
@export var cheatsheet: Cheatsheet
@export var weights: GradingWeights
## Ajustes que lee la escena de contenido (p. ej. {"algorithm": "RR", "io": true}).
@export var params: Dictionary = {}
