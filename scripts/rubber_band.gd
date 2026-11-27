class_name RubberBand
extends RefCounted
## Rubber banding suave para coches IA. Lógica pura.


## Multiplicador de velocidad máxima de una IA.
## lead: ventaja de la IA sobre el jugador, en checkpoints (positivo = la IA va por delante).
## Con `lead >= full_range` baja a 1 - max_delta; con `lead <= -full_range` sube a 1 + max_delta.
static func factor(lead: float, full_range: float, max_delta: float) -> float:
	if full_range <= 0.0:
		return 1.0
	return 1.0 - clampf(lead / full_range, -1.0, 1.0) * max_delta
