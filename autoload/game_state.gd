extends Node
## Estado persistente de la partida. Sin lógica de UI.
## Quien modifique algo emite `changed`; SaveSystem guarda al oírla.

signal changed

const LOCALES: Array[String] = ["ca", "es", "en"]  ## el primero es el idioma por defecto
const DEFAULT_LOCALE: String = "ca"

var master_volume: float = 1.0:  ## 0..1; se aplica al bus Master
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volume()

## Idioma de la interfaz. Un valor desconocido vuelve al catalán.
var locale: String = DEFAULT_LOCALE:
	set(value):
		locale = value if LOCALES.has(value) else DEFAULT_LOCALE
		TranslationServer.set_locale(locale)
		Events.locale_changed.emit(locale)


func _ready() -> void:
	reset()


## Partida nueva.
func reset() -> void:
	master_volume = 1.0
	locale = DEFAULT_LOCALE


## Cambia el idioma y lo guarda. No hace falta reiniciar: los nodos se retraducen solos.
func set_locale(value: String) -> void:
	locale = value
	changed.emit()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)


# --- Guardado ---

func to_dict() -> Dictionary:
	return {"master_volume": master_volume, "locale": locale}


## Carga datos guardados con tolerancia: ignora lo desconocido o mal tipado.
func from_dict(data: Dictionary) -> void:
	reset()
	var volume: Variant = data.get("master_volume")
	if volume is float or volume is int:
		master_volume = float(volume)
	var loc: Variant = data.get("locale")
	if loc is String:
		locale = loc
