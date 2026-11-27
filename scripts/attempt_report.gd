class_name AttemptReport
extends RefCounted
## Informe de un intento: JSON con código de comprobación HMAC-SHA256.
##
## El código detecta que alguien haya editado el archivo a mano (cambiar la nota, por ejemplo).
## La clave va dentro del juego, así que no resiste a quien lo desmonte: es para el aula, no un examen oficial.

const FORMAT: int = 1
const DEFAULT_DIR: String = "user://reports"
const SECRET: String = "miniso-torre7-informe-v1"
const SIGNATURE_KEY: String = "hmac"


## Texto canónico: se pasa por JSON y vuelta (así enteros y decimales quedan igual que al
## leer el archivo) y se ordenan las claves.
static func canonical(report: Dictionary) -> String:
	var copy: Dictionary = report.duplicate(true)
	copy.erase(SIGNATURE_KEY)
	var normalized: Variant = JSON.parse_string(JSON.stringify(copy))
	return JSON.stringify(normalized, "", true)


static func signature(report: Dictionary, secret: String = SECRET) -> String:
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	ctx.update(canonical(report).to_utf8_buffer())
	return ctx.finish().hex_encode()


## Devuelve una copia con el código añadido.
static func with_signature(report: Dictionary, secret: String = SECRET) -> Dictionary:
	var out: Dictionary = report.duplicate(true)
	out[SIGNATURE_KEY] = signature(report, secret)
	return out


static func verify(report: Dictionary, secret: String = SECRET) -> bool:
	var given: Variant = report.get(SIGNATURE_KEY)
	return given is String and given == signature(report, secret)


## Nombre de archivo: misión_fecha_semilla.json
static func file_name(report: Dictionary) -> String:
	var stamp: String = str(report.get("finished_at", "")).replace(":", "").replace("-", "").replace("T", "-")
	return "%s_%s_%s.json" % [str(report.get("mission", "mission")), stamp, str(report.get("seed", 0))]


## Firma y guarda el informe. Devuelve la ruta o "" si no se pudo escribir.
static func save(report: Dictionary, dir: String = DEFAULT_DIR) -> String:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	var path: String = dir.path_join(file_name(report))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(with_signature(report), "\t", true))
	file.close()
	return path


## Lee un informe guardado. {} si no existe o no es JSON.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
