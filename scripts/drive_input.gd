class_name DriveInput
extends RefCounted
## Órdenes de conducción de un frame. Las produce un controlador (humano o IA).

var throttle: float = 0.0  ## 0..1
var brake: float = 0.0  ## 0..1
var steer: float = 0.0  ## -1 (izquierda) .. 1 (derecha)
var nitro: bool = false
var reset: bool = false
