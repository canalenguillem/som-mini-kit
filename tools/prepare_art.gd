extends SceneTree
## Prepara el arte del pack Kenney Racing (CC0): reduce los sprites que usa el juego a ~2× su tamaño
## en pantalla, para que al escalar a 0,5 no se vean dientes de sierra.
## Uso: godot --headless --path . -s res://tools/prepare_art.gd   (después, godot --headless --path . --import)

const SRC: String = "res://assets/kenney_racing/PNG/"
const LONG_SIDE: int = 72  ## px del lado largo de los coches

## nombre de salida → sprite del pack
const CARS: Dictionary = {
	"beetle": "Cars/car_red_1.png",
	"buggy": "Cars/car_yellow_4.png",
	"sport": "Cars/car_red_2.png",
	"rayo": "Cars/car_blue_1.png",
	"bruto": "Cars/car_green_5.png",
	"despiste": "Cars/car_black_3.png",
}
const OBJECTS: Dictionary = {
	"barrel": ["Objects/barrel_red.png", 44],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/cars")
	DirAccess.make_dir_recursive_absolute("res://assets/objects")
	var failed: bool = false
	for car_name: String in CARS:
		failed = not _shrink(SRC + str(CARS[car_name]), "res://assets/cars/%s.png" % car_name, LONG_SIDE) or failed
	for obj_name: String in OBJECTS:
		var spec: Array = OBJECTS[obj_name]
		failed = not _shrink(SRC + str(spec[0]), "res://assets/objects/%s.png" % obj_name, int(spec[1])) or failed
	quit(1 if failed else 0)


func _shrink(from: String, to: String, long_side: int) -> bool:
	var tex: Texture2D = load(from) as Texture2D  # recurso importado (requiere --import previo)
	if tex == null:
		printerr("No se pudo leer ", from)
		return false
	var img: Image = tex.get_image()
	img.decompress()
	var k: float = float(long_side) / maxi(img.get_width(), img.get_height())
	img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var err: Error = img.save_png(to)
	print("%s → %s (%dx%d)" % [from.get_file(), to, img.get_width(), img.get_height()])
	return err == OK
