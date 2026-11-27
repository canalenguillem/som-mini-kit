# GDD — Mini SO

## Qué es

Juego educativo para el alumnado de 1.º de CFGM SMR, módulo **0222 Sistemas Operativos Monopuesto**. **7 misiones, una por tema** del cuaderno del profesor. Cada misión se corrige sola, da una nota de 0 a 10 ligada a los criterios del RD 1691/2007 y el profesor puede ver los resultados.

No es un juego de acción con preguntas pegadas: cada misión es un puzle interactivo cuya mecánica **es** el contenido del tema (construir un Gantt, traducir direcciones, fijar permisos…). De Mini Bólidos y Mini Fútbol se reutilizan la infraestructura y el estilo de menús, no la jugabilidad.

## Concepto

El alumno es un técnico de taller que entra, convertido en un pequeño programa con privilegios de núcleo, dentro de un ordenador averiado, **TORRE-7**. Cada zona del ordenador es un tema; repararla es superar su misión.

- **Hub:** mapa cenital de la placa base, con los buses como pasillos y 7 zonas (bloqueada, abierta, superada). Se desbloquean en el orden del cuaderno.
- **Tres fases por misión**, como en el cuaderno: (1) ejemplo resuelto animado, (2) guiado con parte de la respuesta ya puesta, (3) práctica en solitario. **Solo la fase 3 puntúa.**
- **Chuleta siempre a mano** (F1 o botón): la página de referencia del tema. Consultarla no penaliza.
- **Pistas** (F2 o botón): sí restan (ver Evaluación).
- **Semilla:** los datos de cada ejercicio salen de un `RandomNumberGenerator` sembrado. Misma semilla, mismo ejercicio. Cada alumno recibe datos distintos y el profesor puede reproducir cualquier intento.
- **Idioma:** catalán por defecto; castellano e inglés. Selector en el menú principal y en opciones; se guarda y se aplica sin reiniciar. Vocabulario de las ediciones catalana y castellana del cuaderno; el inglés se traduce a partir de ellas.
- **Tono:** cercano y directo, de tú, como el cuaderno. Al fallar se explica **qué falla y cómo arreglarlo**, nunca solo «incorrecto».
- **Duración:** unos 15–20 minutos por misión (una parte de una sesión de clase).
- **Arte:** packs CC0 de Kenney.

## Temario

| Tema | Contenidos clave | Criterios |
|---|---|---|
| 1. Qué es un sistema informático | Hardware, software, firmware; componentes y buses (datos, direcciones, control); RAM frente a disco; BIOS, EPROM, CMOS; las seis tareas del SO | RA1 a) |
| 2. Cómo es por dentro un SO | Capas (hardware, núcleo, intérprete, interfaz, aplicaciones); modo privilegiado y modo usuario; llamadas al sistema; interrupciones; CLI y GUI; clasificación de SO | RA2 a), b), i) · RA3 a) |
| 3. Los números del ordenador | Binario (chuleta 128…1), hexadecimal, byte, suma binaria, ASCII, TB frente a TiB, tiempo de descarga | RA1 b) |
| 4. Gestión de procesos | Programa/proceso/hilo, PCB, cambio de contexto, estados, planificador y despachador, FIFO, Round Robin, SJF, SRT, tiempos de espera y retorno | RA1 c) · RA4 c) |
| 5. Gestión de la memoria | Jerarquía, direcciones virtuales y físicas, particiones contiguas y fragmentación, paginación, memoria virtual | RA2 a) · RA4 e) |
| 6. Sistemas de archivos | Rutas, FAT32/NTFS/ext4, journaling, atributos, permisos rwx y octal, RAID | RA1 d)–g) |
| 7. Máquinas virtuales | Hipervisor tipo 1 y 2, VirtualBox, crear VM, modos de red, integración, instantáneas, rendimiento | RA5 a)–g) |

## Las 7 misiones

Cada misión se compone de varios retos cortos.

### M1. El taller (tema 1)
- Montar la placa base arrastrando CPU, RAM, disco, fuente, etc. a su zócalo.
- Clasificar objetos como sistema informático o no (router, cajero, martillo, calculadora, libro…), y elementos como hardware, software o firmware.
- Conectar cada bus con lo que transporta (datos: qué; direcciones: dónde; control).
- Ordenar los pasos del arranque de la BIOS; decidir qué vive en EPROM y qué en CMOS; RAM frente a disco.
- **Corrección:** aciertos por elemento. Aprobado: placa completa y ≥ 80 % de clasificaciones.

### M2. La torre de capas (tema 2)
- Ordenar las capas de abajo arriba.
- Hacer de núcleo en tiempo real suave: llegan peticiones de aplicaciones; hay que encaminarlas por llamada al sistema, rechazar accesos directos al hardware en modo usuario y atender interrupciones antes de que caduquen.
- Clasificar sistemas operativos (monousuario/multiusuario, monotarea/multitarea, CLI/GUI…).
- **Corrección:** orden exacto, % de peticiones bien encaminadas, interrupciones perdidas.

### M3. La caja fuerte binaria (tema 3)
- Cerrojos encadenados: 8 interruptores con la chuleta 128-64-32-16-8-4-2-1 (leer y escribir binario), binario↔hexadecimal agrupando de 4 en 4 desde la derecha, suma binaria con acarreo, mensaje en ASCII.
- Remate: cuánto muestra el sistema de un disco de «1 TB» y cuánto tarda una descarga (ojo bits/bytes).
- **Corrección:** respuesta exacta por cerrojo; el juego hace la «comprobación de vuelta» a la vista. Cuentan intentos y pistas.
- **Idea de Guillem (2026-11-27):** los 8 interruptores como **plataformas**: un personaje salta sobre cada interruptor para subirlo o bajarlo, como los pilones de un aparcamiento. La lógica (`BinaryLock`) no cambia; solo la escena. Mantener también la opción de tocar el interruptor (táctil, accesibilidad) y que el salto no se coma el tiempo de la sesión.

### M4. La sala recreativa del planificador (tema 4) — primera en implementarse
Seis salas, cada una con sus tres fases y su nota (decisión de Guillem, 2026-11-27), en el orden del libro: **calentamiento (estados del proceso)**, **FIFO**, **Round Robin**, **Round Robin con E/S**, **SJF** y **SRT**. La nota de la zona es la media de las mejores notas de las salas.

Historia de las decisiones de Guillem (2026-11-27): primero una cuadrícula para rellenar («como una hoja de cálculo»); después una sala recreativa donde solo había que tocar al siguiente («ya se colocan por orden… solo hay que hacer clic»); y el test de estados era «un rollo». Resultado: **el alumno hace de sistema operativo y arrastra a cada jugador**.

- **El salón** (vista lateral): pared con letrero de neón, puerta (llegan), cola de pie delante de la recreativa (la CPU), barra de bocadillos (E/S) y salida. La CPU es la máquina; los procesos son **jugadores** (Ana, Biel, Carla, Dani y Eva = A–E del libro, personajes de Kenney) con **fichas** = ciclos de CPU encima de la cabeza y una **barra de paciencia** que baja mientras hacen cola (6 ciclos la vacían).
- **Cada arrastre es una transición del diagrama de estados** y se nombra al hacerla:
  puerta → cola (Nuevo → Preparado) · cola → máquina (Preparado → En ejecución) · máquina → cola (En ejecución → Preparado) · máquina → bocadillos (En ejecución → Bloqueado) · bocadillos → cola (Bloqueado → Preparado) · máquina → salida (En ejecución → Terminado).
- **Avisos:** bocadillos de texto («¡Ya estoy aquí!», «¡Tengo hambre!», «¡Turno acabado!», «¡Ya he comido!», «¡Sin fichas!») y la pantalla de la máquina (ciclo, «Partida 1 de q», «GAME OVER», «¿Quién juega?», en SRT «¡Alguien nuevo! ¿Lo echa?»).
- **El ciclo espera al alumno** (decisión de Guillem): avanza solo cuando no queda nada pendiente. Pendiente en cada ciclo (`DispatchRound`, a partir de `scheduler.gd`): sale de la máquina el del ciclo anterior (salida, bocadillos o cola); entran en la cola **en orden** (los nuevos, los que vuelven de E/S y el que sale de la máquina); y entra en la máquina quien diga el algoritmo, **cualquiera de la fila**, no necesariamente el primero (en SJF/SRT hay que mirar las fichas). En SRT, si llega alguien más corto, hay que sacar al que juega; si no, no se toca.
- **Cada arrastre se comprueba al momento.** Si no toca, el jugador vuelve a su sitio con el porqué: «¡Nunca directo! De Bloqueado se vuelve a Preparado», «Antes tiene que ponerse en la cola C…», «En el ciclo 9 le tocaba a E: de los que esperaban, era el que necesitaba menos CPU», «No lo echa: le quedan 2 y nadie necesita estrictamente menos»… En solitario el fallo cuenta; en el guiado, no.
- **Calentamiento (estados):** el mismo salón con Round Robin y E/S, pero el juego elige quién juega y ordena la cola; el alumno solo practica las transiciones. Sustituye al test.
- **La cuadrícula del libro se dibuja sola** debajo (X, F, W), ciclo a ciclo.
- **Tabla corta al final** (no en el calentamiento): el juego pone Inicio, Fin y Respuesta; el alumno calcula **Servicio y Espera** de cada jugador y la **espera media** (puede escribir la fracción, `3/4`). Avisos: +1 del servicio, restar la E/S, no redondear.
- **Nota:** movimientos (cada uno que había que hacer; cada fallo resta uno) + casillas de la tabla.
- **Fases:** ejemplo jugado solo con una frase en cada movimiento; guiado con la primera mitad de la partida hecha y la primera fila de la tabla puesta; en solitario, todo.
- **Ejercicios generados:** 4 jugadores (3 con E/S, ráfagas CPU · E/S · CPU), llegadas distintas desde el ciclo 1, como mucho 16 ciclos, quantum 2 o 3, al menos dos decisiones, sin los empates que el libro no explica.
- **Reglas de desempate** (las del libro y PlaniSim; detalle en `docs/temario/tema4.md` §5): en RR, cuando entran varios a la vez en la cola, primero el nuevo, después el que vuelve de E/S y por último el que agota el quantum; si la cola está vacía al agotar el quantum, vuelve a entrar el mismo; SRT expulsa solo si el nuevo necesita **estrictamente** menos.
- La **cuadrícula editable** del libro (`gantt_mission.tscn`, tabla completa con error arrastrado) se conserva con sus tests para el **modo examen** (M10).

### M5. El almacén de RAM (tema 5)
- Colocar procesos en particiones contiguas con primer, mejor y peor ajuste; identificar fragmentación interna y externa.
- Traducir direcciones virtuales a físicas con una tabla de páginas (número de página + desplazamiento).
- Memoria virtual: con la RAM llena, decidir qué página sale al disco y reconocer un fallo de página.
- **Corrección:** huecos y direcciones calculados por `memory.gd`; respuesta exacta.

### M6. El archivo (tema 6)
- Moverse por un árbol de directorios escribiendo rutas absolutas y relativas.
- Elegir sistema de archivos para cada caso (pendrive entre Windows y Linux, disco de sistema, archivo > 4 GB…).
- Fijar permisos `rwx` y su octal para cumplir un encargo («Ana puede leer y escribir, el grupo solo leer, el resto nada»).
- Elegir nivel RAID según se pida velocidad, redundancia o ambas, y calcular la capacidad útil.
- **Corrección:** usuarios simulados intentan leer, escribir y ejecutar; `permissions.gd` decide si pueden. Rutas y elecciones, por comparación directa.

### M7. El hipervisor (tema 7)
- Encargo de un cliente: elegir tipo de hipervisor, repartir RAM y disco sin ahogar al anfitrión, y elegir modo de red (NAT, puente, red interna, solo anfitrión) para que la VM vea o no al anfitrión, a otras VM y a Internet.
- Usar una instantánea para deshacer una avería provocada.
- **Corrección:** `vm_network.gd` calcula la conectividad de la configuración y pasa las pruebas del encargo (VM→Internet, VM↔VM, anfitrión↔VM).
- Es entrenamiento previo al taller; no sustituye la práctica real con VirtualBox.

## Evaluación

- **Nota de misión (0–10):** 70 % aciertos de la fase en solitario, 20 % intentos (cada fallo resta), 10 % pistas no usadas. Pesos en `data/grading/default.tres`, ajustables por misión.
  - Fórmula: `nota = 10 · aciertos · (0,7 + 0,2 · intentos + 0,1 · pistas)`, con `aciertos` = correctos/total al acabar, `intentos` = 1 − 0,25 por comprobación fallida (mínimo 0) y `pistas` = 1 − usadas/disponibles. Intentos y pistas se multiplican por los aciertos para que entregar en blanco dé 0 y no 3. Se redondea a una décima.
  - En la fase en solitario el alumno puede **comprobar** (si falla, cuenta un intento y ve qué falla) o **entregar** lo que tenga.
- **Aprobado:** ≥ 5. Se puede repetir con otra semilla; se guarda la mejor nota y el número de intentos.
- **De momento las notas son solo de práctica** (decisión de Guillem, 2026-11-27): el modo examen se queda en M10.
- **Modo examen:** sin ejemplo resuelto ni pistas, con tiempo límite y una semilla que da el profesor en clase.
- **Registro de cada intento:** alumno, misión, semilla, nota, duración, criterios RA y lista de fallos concretos. Se guarda al acabar en `user://reports/<misión>_<fecha>_<semilla>.json` con un código HMAC-SHA256 que delata cualquier edición a mano (la clave va en el juego: sirve para el aula, no resiste a quien desmonte el ejecutable).
- **Nombre del alumno:** se pide la primera vez que se pulsa Jugar y se cambia en Opciones.
- **Entrega al profesor:** (b) siempre, un informe local exportable (JSON con código de comprobación HMAC) por si no hay red; (a) envío al servidor propio (`miniso.enguillem.es`) mediante `Online`, visible en el panel de administración (M11).

## Qué valida el profesor jugando

Lo que solo se juzga jugando lo valida Guillem. Al acabar cada hito se deja una lista corta de qué probar:

- ¿Se entiende qué hay que hacer sin leer instrucciones largas?
- ¿El arrastre es cómodo con ratón y en pantalla táctil?
- ¿La dificultad y la duración encajan en una sesión de clase (15–20 min por misión)?
- ¿Los mensajes de error ayudan a un alumno de 1.º de grado medio?
