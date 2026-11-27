---
name: crear-pista
description: Crea un circuito nuevo de principio a fin en Godot 4: escena desde la plantilla, suelo y paredes con TileMapLayer, línea de carrera Path2D, checkpoints generados, parrilla de salida, obstáculos temáticos y su TrackData. Úsala cuando se pida una pista o tema nuevo (Oeste, Jungla, Ártico, billar…).
---

# Crear una pista

## Entradas que necesitas

- `id` (`west_03`), nombre visible, tema y número de vueltas.
- Una idea del trazado: un croquis en texto basta, por ejemplo: "óvalo con una chicane en el lado norte y un vado de río en la curva este".
- Si no te la dan, propón un trazado en texto **antes** de construirlo.

## Pasos

1. **Duplica la plantilla** `scenes/tracks/_template.tscn` como `scenes/tracks/<id>.tscn`. El script es siempre `track.gd`, no se duplica.
2. **Suelo (`Ground`)**: pintar tiles a mano en el `.tscn` no es viable. Escribe un generador:
   - `tools/gen_<id>.gd` (`extends SceneTree`) abre la escena, pinta con `set_cell(coords, source_id, atlas_coords)` siguiendo un **mapa ASCII** y la guarda con `PackedScene.pack()` + `ResourceSaver.save()`.
   - Deja el mapa ASCII dentro del generador, para poder retocarlo y regenerar la pista.
   - Leyenda sugerida: `#` pared, `.` asfalto, `t` tierra, `a` arena, `b` barro, `h` hierba, `w` agua, `S` línea de meta.
   - Cada tile del TileSet lleva el custom data `surface` con el id de su superficie.
3. **Paredes (`Walls`)**: un TileMapLayer con colisión (capa 1 walls). Los bordes exteriores siempre cerrados: ningún coche debe poder salir del mapa.
4. **Línea de carrera (`RacingLine`)**:
   - Un `Path2D` **cerrado**, en el sentido de la carrera, que **empieza en la línea de meta** y va por el centro ideal de la pista (abriéndose en las curvas).
   - Genera los puntos desde el mapa ASCII o a mano, con al menos 1 punto cada ~150 px en las curvas.
   - El último punto coincide con el primero.
5. **Checkpoints**: no se crean a mano. `track.gd` los genera en `_ready()`. Referencia:
   ```gdscript
   @export var checkpoint_spacing: float = 250.0
   @export var track_width: float = 220.0

   func _build_checkpoints() -> void:
   	var curve: Curve2D = racing_line.curve
   	var length: float = curve.get_baked_length()
   	var count: int = maxi(8, int(length / checkpoint_spacing))
   	for i: int in count:
   		var t: Transform2D = curve.sample_baked_with_rotation(length * i / count)
   		var area := Area2D.new()
   		area.collision_layer = 1 << 2      # capa 3: checkpoints
   		area.collision_mask = 1 << 1       # capa 2: cars
   		var shape := CollisionShape2D.new()
   		var rect := RectangleShape2D.new()
   		rect.size = Vector2(24.0, track_width)
   		shape.shape = rect
   		area.add_child(shape)
   		area.transform = racing_line.transform * t
   		area.body_entered.connect(_on_checkpoint_body_entered.bind(i))
   		checkpoints.add_child(area)
   ```
   El checkpoint 0 es la línea de meta.
6. **Parrilla (`StartGrid`)**: 4 `Marker2D` detrás de la meta, en 2 columnas, mirando en el sentido de la carrera. Se pueden generar desde `RacingLine` (offsets negativos desde la meta).
7. **Obstáculos del tema** (escenas en `scenes/obstacles/`):
   - Oeste: `barrel.tscn` (RigidBody2D, capa 4), `train.tscn` (AnimatableBody2D que cruza cada N s con aviso visual), `cactus.tscn` (StaticBody2D), rampas.
   - Jungla: `log.tscn` (StaticBody2D), un vado de agua (SurfaceZone `water`), un puente estrecho.
   - Billar: `pool_ball.tscn` (RigidBody2D redondo, rebote alto); las troneras son Area2D que provocan reaparición.
8. **TrackData**: crea `data/tracks/<id>.tres` con id, nombre, tema, escena, vueltas, `reward_mult` y `unlock_cost`.
9. **Test**: añade a `tests/test_tracks.gd` un caso que instancie la pista y compruebe:
   - que `RacingLine` está cerrada (el primer y el último punto distan menos de 5 px),
   - que hay al menos 8 checkpoints,
   - que hay 4 posiciones de salida,
   - que `get_surface_at()` en cada posición de salida devuelve una superficie no nula.
10. Ejecuta `./tools/check.sh`.

## Buen diseño de pista (comprobar antes de entregar)

- Vuelta de 25-40 s con el coche inicial sin mejoras.
- Una recta larga para el nitro y al menos una curva cerrada que pida frenar.
- La superficie lenta es un **atajo arriesgado** o una **penalización por salirse**, nunca obligatoria en todo el trazado.
- Los obstáculos móviles tienen un aviso (sonido o luz) al menos 1,5 s antes.
- El ancho mínimo de pista deja pasar 2 coches lado a lado (≥ 2,5 × el ancho del coche).

## Entrega

Termina con el mapa ASCII de la pista y una sección "Para probar jugando": tiempo de vuelta aproximado, zonas donde la IA podría atascarse y qué ajustar.
