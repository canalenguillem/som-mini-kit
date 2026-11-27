# Plan: «Mini SO», juego educativo de Sistemas Operativos Monopuesto

> Documento de arranque para Claude Code. Léelo entero antes de tocar nada.
> Autor del encargo: Guillem (profesor de FP). Fecha del plan: 2026-11-27.

## 1. Qué hay que construir

Un juego en **Godot 4.7** para el alumnado de 1.º de CFGM SMR, módulo **0222 Sistemas Operativos Monopuesto**. El alumno completa **7 misiones, una por tema** del cuaderno del profesor. Cada misión se corrige sola, da una nota de 0 a 10 ligada a los criterios del RD 1691/2007 y el profesor puede ver los resultados.

No es un juego de acción con preguntas pegadas: cada misión es un puzle interactivo cuya mecánica **es** el contenido del tema (construir un Gantt, traducir direcciones, fijar permisos…).

## 2. Fuente del temario

Cuaderno «Sistemas Operativos Monopuesto. Cuaderno de trabajo» (Guillem Mateu Mascaró, 2026). En Google Drive:

`libros_kdp/Sistemas_Operativos_Cuaderno/03_PRODUCCIO/LLIBRE_KDP/`

- `LLIBRE_Sistemas_Operativos_Monopuesto.pdf` (castellano)
- `LLIBRE_Sistemes_Operatius_Monolloc.pdf` (catalán)
- `..._SOLUCIONES.pdf` / `..._SOLUCIONS.pdf` (edición con soluciones)

Si esa carpeta está disponible en este ordenador, **lee el tema correspondiente antes de implementar cada misión** y usa su vocabulario, sus chuletas y sus ejemplos. Los ejercicios resueltos de la edición con soluciones son los casos de prueba de los evaluadores. Si no la encuentras, pídele la ruta a Guillem.

En `Sistemas_Operativos_Cuaderno/06_SIMULADOR/` están `planisim` y `ossim`, simuladores del propio profesor: úsalos como referencia de la lógica de planificación (misión 4).

| Tema | Contenidos clave | Criterios |
|---|---|---|
| 1. Qué es un sistema informático | Hardware, software, firmware; componentes y buses (datos, direcciones, control); RAM frente a disco; BIOS, EPROM, CMOS; las seis tareas del SO | RA1 a) |
| 2. Cómo es por dentro un SO | Capas (hardware, núcleo, intérprete, interfaz, aplicaciones); modo privilegiado y modo usuario; llamadas al sistema; interrupciones; CLI y GUI; clasificación de SO | RA2 a), b), i) · RA3 a) |
| 3. Los números del ordenador | Binario (chuleta 128…1), hexadecimal, byte, suma binaria, ASCII, TB frente a TiB, tiempo de descarga | RA1 b) |
| 4. Gestión de procesos | Programa/proceso/hilo, PCB, cambio de contexto, estados, planificador y despachador, FIFO, Round Robin, SJF, SRT, tiempos de espera y retorno | RA1 c) · RA4 c) |
| 5. Gestión de la memoria | Jerarquía, direcciones virtuales y físicas, particiones contiguas y fragmentación, paginación, memoria virtual | RA2 a) · RA4 e) |
| 6. Sistemas de archivos | Rutas, FAT32/NTFS/ext4, journaling, atributos, permisos rwx y octal, RAID | RA1 d)–g) |
| 7. Máquinas virtuales | Hipervisor tipo 1 y 2, VirtualBox, crear VM, modos de red, integración, instantáneas, rendimiento | RA5 a)–g) |

## 3. Base técnica

Crea el proyecto con **`new-game.sh` de `~/code/juego-online-kit`** (etiqueta `infra-v1`, skill `juego-online`), igual que Mini Bólidos y Mini Fútbol. Sigue lo que diga el kit; este plan no lo sustituye.

Convenciones heredadas de esos juegos (son obligatorias):

- Godot 4.7.x, GDScript con **tipado estático** en todo. Nada de APIs de Godot 3.
- 2D, base 1280×720, `stretch/mode = canvas_items`, `stretch/aspect = expand`.
- Autoloads `Events`, `GameState`, `SaveSystem`, `Music`, `Online`. Señales hacia arriba, llamadas hacia abajo.
- **Los datos no van en el código**: Resources `.tres` y `@export`.
- Input por acciones del InputMap. Aquí casi todo es ratón/táctil: arrastrar, pulsar, escribir.
- Tests con GUT; `./tools/check.sh` después de cada cambio de escena o recurso.
- En `.tscn`/`.tres` editados como texto, no inventar `uid`.
- Comentarios y commits en español, identificadores en inglés.
- Crea `CLAUDE.md`, `docs/GDD.md`, `docs/ARCHITECTURE.md` y `docs/ROADMAP.md` como en los otros juegos, volcando en ellos este plan.

**Repositorio:** `https://github.com/canalenguillem/som-mini-kit` (ya creado y vacío). Tras crear el proyecto con el kit, conéctalo como `origin` (`git branch -M main`, `git remote add origin …`, `git push -u origin main`) y haz commits pequeños a partir de ahí.

De los otros juegos se reutiliza la **infraestructura y el estilo de menús**, no la jugabilidad.

## 4. Concepto

**Título: «Mini SO»** (igual en los tres idiomas; sigue la saga Mini Bólidos y Mini Fútbol). El alumno es un técnico de taller que entra, convertido en un pequeño programa con privilegios de núcleo, dentro de un ordenador averiado, TORRE-7. Cada zona del ordenador es un tema; repararla es superar su misión.

- **Hub:** mapa cenital de la placa base, con los buses como pasillos y 7 zonas (bloqueada, abierta, superada). Se desbloquean en el orden del cuaderno.
- **Tres fases por misión**, como en el cuaderno: (1) ejemplo resuelto animado, (2) guiado con parte de la respuesta ya puesta, (3) práctica en solitario. Solo la fase 3 puntúa.
- **Chuleta siempre a mano** (una tecla/botón): la página de referencia del tema. Consultarla no penaliza.
- **Semilla:** todos los datos de un ejercicio se generan con un `RandomNumberGenerator` sembrado. Misma semilla, mismo ejercicio. Cada alumno recibe datos distintos y el profesor puede reproducir cualquier intento.
- **Idioma:** selector de idioma en el menú y en opciones. **Catalán por defecto**; castellano e inglés también disponibles. Toda la interfaz, enunciados, chuletas y mensajes de error existen en los tres idiomas. Como fuente del vocabulario se usan las ediciones catalana (`LLIBRE_Sistemes_Operatius_Monolloc.pdf`) y castellana (`LLIBRE_Sistemas_Operativos_Monopuesto.pdf`) del cuaderno; el inglés se traduce a partir de ellas.
- **Tono:** cercano y directo, de tú, como el cuaderno. Al fallar se explica qué falla y cómo arreglarlo, nunca solo «incorrecto».

## 5. Las 7 misiones

Cada misión se compone de varios retos cortos. Para cada una: qué hace el alumno y cómo se corrige.

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

### M4. La sala del planificador (tema 4) — primera en implementarse
- Calentamiento: mover un proceso por el diagrama de estados eligiendo la transición correcta para cada situación.
- Núcleo de la misión: tabla de procesos (llegada, ráfaga) generada por semilla. El alumno construye el **diagrama de Gantt** arrastrando bloques a una línea de tiempo para FIFO, Round Robin (quantum dado), SJF y SRT, y rellena tiempo de espera y de retorno de cada proceso y las medias.
- **Corrección:** `scheduler.gd` simula el algoritmo y compara casilla a casilla; el fallo se señala con precisión («RR: en t=6 le tocaba a P3»). Definir y documentar los desempates con el criterio del cuaderno (léelo en el tema 4) y cubrirlos con tests.

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

## 6. Evaluación

- **Nota de misión (0–10):** 70 % aciertos de la fase en solitario, 20 % intentos (cada fallo resta), 10 % pistas no usadas. Pesos en un `.tres`, ajustables.
- **Aprobado:** ≥ 5. Se puede repetir con otra semilla; se guarda la mejor nota y el número de intentos.
- **Modo examen:** sin ejemplo resuelto ni pistas, con tiempo límite y una semilla que da el profesor en clase.
- **Registro de cada intento:** alumno, misión, semilla, nota, duración, criterios RA y lista de fallos concretos.
- **Entrega al profesor:** (a) envío al servidor del kit mediante `Online`, visible en el panel de administración; (b) siempre, además, un informe local exportable (JSON con código de comprobación HMAC) por si no hay red. Empieza por (b); (a) cuando esté el servidor.

## 7. Arquitectura

```
autoload/            # los del kit + progress.gd (estado de misiones) si no cabe en GameState
scenes/
  hub/               # hub.tscn: placa base y 7 zonas
  mission/           # mission_shell.tscn: marco común (fases, chuleta, pistas, resultado)
  missions/m1_workshop/ … m7_hypervisor/   # una carpeta por misión
  ui/                # menú, opciones, chuleta, informe, modo examen
scripts/             # lógica pura, sin nodos, con tests GUT:
  exercise_seed.gd   # RNG sembrado
  grading.gd         # nota a partir de aciertos, intentos, pistas
  attempt_report.gd  # registro e informe firmado
  number_systems.gd  # M3
  scheduler.gd       # M4: FIFO, RR, SJF, SRT → Gantt y tiempos
  memory.gd          # M5: ajustes, paginación
  permissions.gd     # M6: rwx/octal; raid.gd; paths.gd
  vm_network.gd      # M7
data/
  missions/*.tres    # MissionData: tema, título, criterios RA, pesos
  cheatsheets/       # chuleta de cada tema
  texts/             # enunciados y mensajes, en catalán (por defecto), castellano e inglés
tests/               # test_*.gd
```

Reglas:

- **Generador y corrector separados de la interfaz.** Cada misión tiene `generate(seed) -> Exercise` y `evaluate(exercise, answer) -> Result` en `scripts/`, probados con GUT contra los ejercicios resueltos del cuaderno.
- `mission_shell` gestiona las tres fases, la chuleta, las pistas y la pantalla de resultado; cada misión solo aporta sus retos.
- Textos fuera del código con el sistema de traducción de Godot (`TranslationServer`, CSV o PO). Locales `ca` (por defecto), `es` y `en`. El idioma elegido se guarda con `SaveSystem` y se puede cambiar en cualquier momento sin reiniciar. Ningún texto visible escrito a mano en escenas o scripts: siempre claves de traducción.
- Exportación con los scripts del kit (Linux, Windows, macOS).

## 8. Hitos

Trabaja solo en el hito actual y marca las casillas en `docs/ROADMAP.md`.

- **M0 — Esqueleto.** Proyecto creado con el kit, `check.sh` en verde, docs y `CLAUDE.md` escritos, menú que abre un hub vacío, selector de idioma (ca por defecto, es, en) funcionando.
- **M1 — Marco de misión.** `mission_shell`, semilla, `grading.gd`, registro de intentos e informe local, con tests.
- **M2 — Demo jugable: misión 4 (planificador).** `scheduler.gd` con tests de los cuatro algoritmos, editor de Gantt arrastrable, las tres fases, chuleta, resultado. **Parar aquí y dejar que Guillem la pruebe con alumnos** antes de seguir.
- **M3 — Hub y progreso.** Mapa de la placa, desbloqueo, guardado.
- **M4 a M9 — Resto de misiones**, en el orden del cuaderno: tema 1, 2, 3, 5, 6 y 7. Una por hito, cada una con su lógica probada.
- **M10 — Modo examen** e informe para el profesor.
- **M11 — Online:** envío de notas al servidor y vista en el panel de administración.
- **M12 — Revisión de las traducciones, pulido, sonido y exportaciones.** (Cada hito anterior entrega ya sus textos en catalán, castellano e inglés.)

## 9. Qué no puedes dar por bueno tú

Lo que solo se juzga jugando lo valida el profesor. Al acabar cada hito, deja una lista corta de qué probar:

- ¿Se entiende qué hay que hacer sin leer instrucciones largas?
- ¿El arrastre del Gantt es cómodo con ratón y en pantalla táctil?
- ¿La dificultad y la duración encajan en una sesión de clase (unos 15–20 min por misión)?
- ¿Los mensajes de error ayudan a un alumno de 1.º de grado medio?

## 10. Dudas abiertas para Guillem

Pregúntalas al empezar si no están resueltas; no bloquean el hito M0.

1. ~~Idioma inicial~~ **Resuelto:** selector de idioma, catalán por defecto, castellano e inglés también.
2. ~~Nombre definitivo~~ **Resuelto:** «Mini SO» (repositorio `som-mini-kit`).
3. ¿Las notas cuentan para la evaluación real (y por tanto hace falta el modo examen pronto) o es solo práctica?
4. ¿Servidor propio para este juego, como en los otros, o compartido?
5. Arte: ¿assets de Kenney como en los otros juegos?
