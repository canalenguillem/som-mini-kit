extends Node
## Estado persistente de la partida. Sin lógica de UI.
## Quien modifique algo emite `changed`; SaveSystem guarda al oírla.

signal changed

const LOCALES: Array[String] = ["ca", "es", "en"]  ## el primero es el idioma por defecto
const DEFAULT_LOCALE: String = "ca"
const MAX_NAME_LENGTH: int = 40

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

## Nombre del alumno tal como saldrá en los informes.
var student_name: String = ""
## Mejor nota e intentos de cada misión: {id: {best, attempts}}. Reglas en Progress.
var progress: Dictionary = {}

# --- No se guardan ---
var current_mission: MissionData  ## misión que abrirá MissionShell
var pending_seed: int = 0  ## semilla impuesta (la del profesor); 0 = una al azar


func _ready() -> void:
	reset()


## Partida nueva.
func reset() -> void:
	master_volume = 1.0
	locale = DEFAULT_LOCALE
	student_name = ""
	progress = {}
	current_mission = null
	pending_seed = 0


## Semilla para el próximo intento: la impuesta (y se consume) o una nueva.
func take_seed() -> int:
	var s: int = pending_seed if pending_seed > 0 else ExerciseSeed.new_seed()
	pending_seed = 0
	return s


static func clean_name(value: String) -> String:
	return value.strip_edges().left(MAX_NAME_LENGTH)


func set_student_name(value: String) -> void:
	student_name = clean_name(value)
	changed.emit()


## Cambia el idioma y lo guarda. No hace falta reiniciar: los nodos se retraducen solos.
func set_locale(value: String) -> void:
	locale = value
	changed.emit()


## Apunta un intento terminado (la nota de la fase en solitario) y guarda.
func record_attempt(mission_id: String, grade: float) -> void:
	progress = Progress.record(progress, mission_id, grade)
	changed.emit()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)


# --- Guardado ---

func to_dict() -> Dictionary:
	return {"master_volume": master_volume, "locale": locale, "student_name": student_name, "progress": progress}


## Carga datos guardados con tolerancia: ignora lo desconocido o mal tipado.
func from_dict(data: Dictionary) -> void:
	reset()
	var volume: Variant = data.get("master_volume")
	if volume is float or volume is int:
		master_volume = float(volume)
	var loc: Variant = data.get("locale")
	if loc is String:
		locale = loc
	var student: Variant = data.get("student_name")
	if student is String:
		student_name = clean_name(student)
	progress = Progress.sanitize(data.get("progress"))
