class_name GradingWeights
extends Resource
## Pesos de la nota de misión. Se ajustan en data/grading/*.tres sin tocar código.

@export_range(0.0, 1.0, 0.05) var accuracy: float = 0.7  ## aciertos de la fase en solitario
@export_range(0.0, 1.0, 0.05) var attempts: float = 0.2  ## comprobaciones fallidas
@export_range(0.0, 1.0, 0.05) var hints: float = 0.1  ## pistas no usadas
## Parte del componente de intentos que se pierde por cada comprobación fallida.
@export_range(0.0, 1.0, 0.05) var penalty_per_failed_check: float = 0.25
@export_range(0.0, 10.0, 0.5) var pass_grade: float = 5.0
