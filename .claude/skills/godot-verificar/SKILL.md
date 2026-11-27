---
name: godot-verificar
description: Verifica el proyecto Godot sin pantalla (importa, carga e instancia todas las escenas y recursos, y ejecuta los tests GUT). Úsala después de crear o editar cualquier .gd, .tscn o .tres, y siempre antes de dar una tarea por terminada.
---

# Verificar el proyecto Godot

No puedes ver el juego, así que **tu única prueba de que algo funciona es la verificación headless**. Nunca digas "hecho" sin haberla pasado.

## Instalación (una vez, en el hito M0)

1. Comprueba que Godot está disponible: `which godot || echo $GODOT`. Si no, pide al humano la ruta y usa `GODOT=/ruta/al/binario`.
2. Copia los scripts de esta skill al proyecto:
   ```bash
   mkdir -p tools
   cp .claude/skills/godot-verificar/check.sh tools/check.sh
   cp .claude/skills/godot-verificar/load_all.gd tools/load_all.gd
   chmod +x tools/check.sh
   ```
3. Instala GUT 9.x (rama para Godot 4) en `addons/gut`. Si no tienes acceso a la red, pide al humano que lo instale desde la AssetLib del editor. Activa el plugin en `project.godot`:
   ```ini
   [editor_plugins]
   enabled=PackedStringArray("res://addons/gut/plugin.cfg")
   ```

## Uso

```bash
./tools/check.sh
```

Pasos que ejecuta:
1. `--import`, para que los assets nuevos tengan sus `.import`.
2. `load_all.gd`, que carga todo `.gd`, `.tscn` y `.tres` fuera de `addons/` e instancia cada escena.
3. Busca en la salida `Parse Error`, `SCRIPT ERROR`, `ERROR:` y `Failed to load`.
4. Ejecuta los tests GUT de `res://tests`.

## Si falla

- **Parse Error**: suele ser sintaxis de Godot 3 (`export var`, `onready var`, `yield`), falta de tipo en un `:=` ambiguo, o indentación mezclada (usa tabs, el estilo por defecto de Godot).
- **Failed to load / ext_resource**: una ruta mal escrita en el `.tscn` o un `uid` inventado. Quita el `uid=` del `ext_resource` y deja solo `path`.
- **Error al instanciar**: un `@onready` que apunta a un nodo inexistente (`$Ruta/Mal`). Revisa los nombres de los nodos en el `.tscn`.
- **Test rojo**: arregla el código, no el test, salvo que el test contradiga `docs/GDD.md`.

## Lo que esta verificación NO comprueba

La sensación de juego, la dificultad, la legibilidad visual y el rendimiento. Para eso, termina tu respuesta con una sección **"Para probar jugando"**: 3-5 puntos concretos y los `@export` que el humano puede ajustar.
