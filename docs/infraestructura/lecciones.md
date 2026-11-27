# Lecciones aprendidas y cómo trabajar

## Cómo trabajar con el usuario

- **Hitos pequeños y validados.** Un `docs/ROADMAP.md` con hitos; el humano valida cada uno jugando. Solo se avanza al siguiente cuando lo dice. Lo que depende de la sensación (conducción, dificultad, fluidez en red) **no se da por bueno**: se deja una lista corta de "Para probar jugando" con los `@export` que ajustar.
- **Verificar siempre antes de decir "hecho":** `./tools/check.sh` (Godot), las pruebas del backend en Docker, `npm run build` (web), y si se puede, una capturas del resultado real (`--write-movie`, navegador).
- **Dar la respuesta primero**, explicar los límites de lo que no se pudo probar (por ejemplo: "probado bajo Wine, no en Windows real") y qué le toca a él.
- **Pedir confirmación antes de descargar archivos grandes** (plantillas de exportación 1,28 GB) o de tocar configuración persistente (cron, `.env`), diciendo qué se hará.
- **Documentar las decisiones que cambian el alcance** (GDD, ROADMAP, `docs/ONLINE.md`) y commitear en español con mensajes descriptivos.
- Mensajes y documentación en español; identificadores en inglés.

## Godot

- `-s script.gd`: los autoloads **no existen al compilar**. Usar `_initialize()` en lugar de `_init()` y, si el script nombra un autoload (o una clase que lo nombra), cargarlo en tiempo de ejecución sin tipar.
- `JSON.parse_string` **imprime errores del motor** con entradas inválidas y GUT los cuenta como fallos: usar `JSON.new().parse()`.
- `Image.load_from_file` avisa de que no funciona al exportar: cargar el recurso importado (`load(...).get_image()`).
- No inventar `uid="uid://…"` en `.tscn`/`.tres` escritos a mano. No tocar `.godot/` ni `.import`.
- Un `class_name` no puede coincidir con el nombre de un autoload.
- Los `@onready` de una clase hija se asignan antes de su `_ready`; al sobrescribir `_ready` en una subclase, el de la base **no** se ejecuta.
- Tests que cambian de escena: no llamar a `change_scene_to_*` dentro de GUT; inyectar un `Callable` de navegación.
- Un `Area2D` detecta cuerpos que aparecen sobre él solo tras un frame de física: en pruebas, `await wait_physics_frames(2)`.
- Los coches que no llegan a recibir ninguna posición de red deben quedarse donde están (un fantasma sin dato se iba al origen).
- Quitar una dependencia entre escenas con `Callable` inyectable (`navigate`, `http_backend`, `socket_factory`) hace probable todo sin red ni pantalla.
- Las pruebas bajo GUT usan `user://test_save.json`: detecta `gut_cmdln` en `OS.get_cmdline_args()` para no tocar la partida real. Las herramientas de demo deben poner `use_prefs = false` para no dejar `localhost` ni usuarios de prueba en las preferencias del usuario (ya ocurrió).
- El renderizador por defecto era Forward+ (Vulkan): para PCs de aula usar `gl_compatibility` en `project.godot` y comprobar con una captura que se ve igual.

- **Exportar a macOS desde Linux:** posible con la plantilla `macos.zip`. Hay que activar `import_etc2_astc`, usar `codesign/codesign=1` (ad hoc integrado) y comprobar que el binario universal lleva `LC_CODE_SIGNATURE` en las dos arquitecturas. Sin Apple Developer, el usuario ha de saltarse Gatekeeper a mano. Nunca digas que "funciona" sin que lo haya abierto alguien en un Mac.
- Mantener los permisos de un `.app` al reempaquetar un zip: copiar `ZipInfo.external_attr` (el ejecutable debe seguir en 755).

## Partidas online (lo que falló en clase)

- **Los checkpoints/áreas detectan por capa de colisión.** Si quitas la capa de un cuerpo para que no choque con otros, también deja de activar `Area2D`. Para "no chocar entre jugadores" quita la capa de coches de la **máscara**, no de la capa del cuerpo.
- **Una prueba que dispara la señal a mano no prueba el detector.** Para cualquier cosa basada en `Area2D`/física, incluye al menos una prueba que mueva el cuerpo sobre el área real y espere 2-3 fotogramas de física.
- **Los fantasmas no se suavizan arrastrando hacia el último paquete:** cada paquete llega ya viejo y el coche se frena o retrocede en cada uno. Se dibuja con retardo (~0,1 s) interpolando entre dos paquetes, **usando la hora del emisor** (no la de llegada, que lleva el jitter), a la cadencia de la pantalla (`_process`) y no de la física.
- Envía posiciones a 20 Hz y reenvía desde el servidor a 30 Hz; una prueba de jitter simulado (llegadas entre 20 y 90 ms) con "no retrocede nunca" y "ningún paso > 2× el esperado" es el mejor guardia contra esta regresión.
- **Probar con más de una persona cuanto antes**: los fallos de red y de percepción no salen con clientes simulados. Una vuelta con 2 instancias del juego en el mismo equipo ya habría encontrado los tres.
- **Controles:** el giro con teclado necesita rampa (sube y baja progresivamente), menos giro a velocidad alta y una sensibilidad ajustable por el jugador en Opciones. Los jugadores de teclado y los de mando perciben la dirección de forma muy distinta.
- **Señalización:** sin línea de meta y aviso de fin de vuelta, nadie sabe cuándo ha acabado una vuelta aunque el contador funcione.

## Sensación de juego

- **Comprueba que la mecánica existe antes de pulirla.** El modelo de conducción "con derrape" nunca deslizaba (la velocidad giraba con el morro) y nadie lo notó hasta escribir un test que medía la velocidad lateral. Un test por mecánica que mida su efecto físico (desliza, salta, acelera) lo habría cazado el primer día.
- **Mira capturas del juego real** (`--write-movie` con una demo guiada por la IA): así se vio que los coches ocupaban 16 px de 1280. El zoom de cámara es lo que más cambia la usabilidad.
- `sed` sobre un archivo de tests cambia también los nombres de métodos que se parecen (`_input(` → rompió `get_input(`): usar reemplazos exactos.
- Evita la tecla Shift para acciones repetidas: en Windows, pulsarla 5 veces abre "Teclas especiales".

## Servidor

- **nginx: `add_header` en una `location` anula las del `server`.** Repetir las de seguridad o no declarar ninguna en esa ubicación (`expires` no lo hace).
- **uvicorn registra la URL del WebSocket con el token**: `--log-level warning`. Comprobar que no hay `token=` en los registros.
- `TestClient` + anyio: la tarea cancelada interrumpe cualquier `await` del `finally`; proteger la limpieza con `anyio.CancelScope(shield=True)`.
- Pruebas asíncronas con estado compartido: reiniciar cancelando primero las partidas vivas, esperar a los guardados pendientes y solo entonces truncar. Varias ejecuciones simultáneas de las pruebas se pisan la base.
- Redis, MariaDB, Mongo y el backend tienen que ir en una red privada; solo el frontend publica puerto.
- `email-validator` rechaza dominios `.local`/`.test`: en pruebas usar `@example.com`.
- Un hash de una cookie o una IP basta para deduplicar: no guardes el valor en claro.
- Una cookie de sesión de otra pestaña/TestClient persiste entre peticiones: limpiar `client.cookies` para simular otro navegador.
- Un aula comparte IP: **ningún límite por IP debe bajar de unos cientos** salvo los de fuerza bruta por usuario.
- Si una migración cambia el significado de un dato (cuentas sin aceptar la política), avisar al usuario de cuántas filas afecta.

## Entorno

- La shell del usuario es **fish**: los bloques bash multilínea pegados fallan. Para cualquier cosa que deba ejecutar el usuario, dar **un script** (`ssh -t host ruta/script.sh`) o un comando de una línea.
- `/tmp` es tmpfs (RAM): para descargas grandes sirve, pero se pierde al reiniciar. Usa el scratchpad de la sesión para temporales.
- Si un comando dura más de 120 s, pasa a segundo plano; esperar con `Monitor` o volver a mirar el resultado, no con `sleep`.
- No imprimas ni repitas contraseñas, tokens ni `.env`. Si ocurre por accidente, dilo y rota el secreto.
- MongoDB 5+ exige AVX; la VM de producción no lo tiene (usar 4.4).
- El usuario tiene un estudio de IA local (`lamb`) para música, efectos e imágenes; las cuotas son de una sola GPU y la cola es secuencial.
