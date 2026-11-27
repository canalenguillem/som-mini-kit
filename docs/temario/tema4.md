# Tema 4 · Gestión de procesos (extracto del cuaderno para la misión de planificación)

Material sacado del cuaderno del profesor *Sistemas Operativos Monopuesto. Cuaderno de trabajo*
(módulo 0222, CFGM SMR), tema 4, págs. 73–100 aprox., para implementar y probar la misión de
planificación de CPU.

## 0. Fuentes y qué se ha podido leer

| Fuente (Drive) | Uso | Qué se ha leído |
|---|---|---|
| `LLIBRE_Sistemas_Operativos_Monopuesto_SOLUCIONES.pdf` (19jlUbUp…) | principal | El lector de Drive **corta el texto a ~82.000 caracteres**: llega hasta el final del apartado 7 del tema 4 (pág. 80). Lo que hay en esas páginas coincide palabra por palabra con el `.md` de abajo. |
| `CAP04_gestion_de_procesos.md` (15yycWXd…), modificado el 05/10/2026 a las 14:31, cinco minutos antes que el PDF | texto fuente del tema 4 en castellano, con las soluciones entre `{{ }}` | Entero. **Los apartados 8 a 14, el repaso y todos los ejercicios resueltos salen de aquí.** |
| `LLIBRE_Sistemes_Operatius_Monolloc_SOLUCIONS.pdf` (1LcimnL4…) | vocabulario en catalán | El mismo corte: tema 4 hasta el apartado 7 (pág. 80). |
| `CAP04_gestio_de_processos.md` (1klY3i8u…, 12/11/2026) | vocabulario en catalán de los apartados 8 a 14 | Entero. Es una versión posterior: añade un ejemplo con `nano`/`ps` y un recuadro «Pila o monticle?». Los datos y las soluciones son los mismos. |
| PlaniSim (carpeta 1Vaxwiv…): `web/planificador.js`, `LLEGEIX-ME.txt` | reglas del simulador | Enteros. No se ha abierto `app.js` (interfaz), `narra.js` (texto de la narración) ni los `.json` de `exemples/` (solo traen los datos de entrada de las diapositivas). |

**Páginas:** solo las del índice del PDF. El texto de las págs. 81–100 no se ha podido leer, así que
la página de cada ejercicio es la del apartado donde aparece. Índice del tema 4: 1 Programa/proceso
74 · 2 Proceso e hilo 75 · 3 Memoria 75 · 4 PCB 77 · 5 Cambio de contexto 77 · 6 Estados 78 ·
7 Planificador 80 · 8 Cómo se mide 81 · 9 FIFO 81 · 10 Round Robin 83 · 11 SJF 88 · 12 SRT 90 ·
13 Los cuatro 91 · 14 Procesos de tu ordenador 94 · Repaso y Mis notas a continuación (antes de la
pág. 103, donde empieza el tema 5).

**Convención de tiempo del libro (muy importante para el código):** el tiempo va en **ciclos de
reloj y el primero es el 1**. Un proceso que llega en el ciclo *k* ya se puede ejecutar en el ciclo
*k*. «Fin» es el **último ciclo en el que se ejecuta** (incluido). Si la misión trabaja con
intervalos semiabiertos que empiezan en 0, el ciclo *k* es el intervalo `[k−1, k)`.

---

## 1. Vocabulario clave (castellano / catalán)

El libro **no dice nunca «tiempo de retorno»**: el tiempo de retorno (*turnaround*) se llama
**Servicio / Servei**. Tampoco usa «FCFS»: usa **FIFO**.

| Castellano (libro ES) | Català (llibre CA) | Inglés que da el libro / nota |
|---|---|---|
| Programa | Programa | — |
| Proceso | Procés | — |
| Hilo | Fil | *thread* |
| PID | PID | — |
| PCB, «la ficha de cada proceso» | PCB, «la fitxa de cada procés» | *Process Control Block* |
| Contador de programa | Comptador de programa | — |
| Registros de la CPU | Registres de la CPU | — |
| Información de planificación | Informació de planificació | — |
| Estadísticas | Estadístiques | — |
| Cambio de contexto | Canvi de context | *context switch* |
| Código / Datos / Pila / Montículo | Codi / Dades / Pila / Monticle | *stack*, *heap* (la FIG 4.1 en castellano pone «MONTÓN (heap)») |
| Estado | Estat | — |
| Nuevo | Nou | *new* |
| Preparado | Preparat | *ready* (en las FIG 4.3 y 4.4 en castellano pone «LISTO» y «COLA DE LISTOS») |
| En ejecución | En execució | *running* |
| Bloqueado | Bloquejat | *blocked* |
| Terminado | Acabat | *terminated* |
| Cola de preparados | Cua de preparats | *ready queue* |
| Planificador | Planificador | *scheduler* |
| Despachador | **Distribuïdor** | *dispatcher* |
| Algoritmo de planificación | Algorisme de planificació | — |
| Expulsivo / No expulsivo | Expulsiu / No expulsiu | *preemptive* / *non-preemptive* |
| Ciclo (de reloj) | Cicle (de rellotge) | — |
| Cuadrícula; gráfico de ejecución; diagrama de Gantt | Graella; gràfic d'execució; diagrama de Gantt | *Gantt chart* |
| Llegada | Arribada | columna de la tabla |
| CPU (ciclos de CPU que necesita) | CPU | columna; es la ráfaga de CPU |
| Inicio | Inici | columna |
| Fin | Fi | columna |
| Respuesta (tiempo de respuesta) | Resposta (temps de resposta) | columna |
| Servicio (tiempo de servicio) | Servei (temps de servei) | columna; es el tiempo de retorno |
| Espera (tiempo de espera) | Espera (temps d'espera) | columna |
| Media | Mitjana | fila final de la tabla |
| Ráfaga (de CPU, de E/S) | Ràfega | *burst* |
| Entrada/salida, E/S | Entrada/sortida, E/S | — |
| Quantum (q) | Quantum (q) (PlaniSim escribe «quàntum») | — |
| Agotar el quantum | Esgotar el quantum | — |
| Efecto convoy | Efecte comboi | *convoy effect* |
| Inanición | Inanició | *starvation* |
| Marcas de la cuadrícula: X, F, W, casilla vacía | X, F, W, casella buida | W viene de *wait* |
| FIFO — el primero que llega, el primero al que se atiende | FIFO — el primer que arriba, el primer que s'atén | *First In, First Out* |
| Round Robin — todos por turnos | Round Robin — tots per torns | — |
| SJF — primero el más corto | SJF — primer el més curt | *Shortest Job First* |
| SRT — el más corto, y además con expulsión | SRT — el més curt, i a més amb expulsió | *Shortest Remaining Time* |

Etiquetas de las flechas de la FIG 4.3: ES «lo admite», «lo elige el planificador», «fin del
quantum», «pide E/S», «la E/S termina», «termina», «¡nunca directo!». CA «l'admet», «el tria el
planificador», «fi del quantum», «demana E/S», «l'E/S acaba», «acaba», «mai directe!».

---

## 2. Diagrama de estados (apartado 6, pág. 78)

Cinco estados, con su significado (ES / CA):

| Estado | Estat | Qué significa (libro ES) |
|---|---|---|
| **Nuevo** *(new)* | **Nou** | Se acaba de crear. Todavía no está preparado. |
| **Preparado** *(ready)* | **Preparat** | Listo y esperando turno de CPU. |
| **En ejecución** *(running)* | **En execució** | Tiene la CPU. **Es el único estado en el que el proceso avanza.** |
| **Bloqueado** *(blocked)* | **Bloquejat** | Está esperando algo: el disco, el teclado, la red. No quiere CPU. |
| **Terminado** *(terminated)* | **Acabat** | Ha terminado. El sistema libera sus recursos. |

«Los cambios entre estados no son libres. Estos son los únicos que existen» (seis flechas):

| De | A | Por qué (ES) | Per què (CA) |
|---|---|---|---|
| Nuevo | Preparado | El sistema lo admite | El sistema l'admet |
| Preparado | En ejecución | El planificador lo elige | El planificador el tria |
| En ejecución | Preparado | Se le ha acabado el quantum | Se li ha acabat el quantum |
| En ejecución | Bloqueado | Pide una operación de entrada/salida | Demana una operació d'entrada/sortida |
| Bloqueado | Preparado | La operación ha terminado | L'operació ha acabat |
| En ejecución | Terminado | El proceso termina | El procés acaba |

> **Atención a lo que más se falla.** De **Bloqueado** no se pasa nunca directamente a **En
> ejecución**. Cuando termina lo que estaba esperando, el proceso vuelve a **Preparado** y hace cola
> otra vez, como todo el mundo. Esta flecha mal puesta es el error clásico del examen.

FIG 4.4 (pág. 80): los nuevos entran en la COLA DE LISTOS → PLANIFICADOR → CPU. Desde la CPU: «fin
del quantum» vuelve a la cola, «termina» sale y, si pide E/S, pasa a BLOQUEADOS; desde ahí «la E/S
termina» vuelve a la cola. Pie: «Como en la cola del súper. Pero quien elige es el planificador.»

---

## 3. Chuleta del tema (pág. 73), tal como sale en el libro

> **Tu chuleta para todo el tema**
>
> Estas siete columnas salen en todos los ejercicios del tema. Cópialas cada vez.
>
> | Columna | Qué es | Cómo se calcula |
> |:---:|---|---|
> | **Llegada** | Ciclo en el que llega el proceso | te la dan |
> | **CPU** | Ciclos de CPU que necesita | te los dan |
> | **Inicio** | Ciclo en el que se ejecuta por primera vez | la sacas de la cuadrícula |
> | **Fin** | Último ciclo en el que se ejecuta: cuando termina | la sacas de la cuadrícula |
> | **Respuesta** | Ciclos desde que llega hasta que entra por primera vez en la CPU | **Respuesta = Inicio − Llegada** |
> | **Servicio** | Ciclos desde que llega hasta que termina | **Servicio = Fin − Llegada + 1** |
> | **Espera** | Ciclos que pasa en la cola de preparados, sin CPU | **Espera = Servicio − CPU** |
>
> Fíjate en el orden: **primero rellenas la cuadrícula, de ahí sacas el Inicio y el Fin, y con eso
> ya salen la respuesta, el servicio y la espera.** Nunca al revés.
>
> **¿Por qué el +1 del servicio?** Porque cuentan el ciclo de llegada y el de fin. Si un proceso
> llega en el ciclo 4 y termina en el 5, ha estado en el sistema los ciclos 4 y 5: son **2**, y
> 5 − 4 + 1 = 2.
>
> Si hay entrada/salida, a la espera también le restas los ciclos de E/S: **Espera = Servicio − CPU −
> E/S**. Lo verás en el apartado 10.1.

### «Lo que tienes que saber sí o sí» (resumen del final del tema), literal

- **Programa** es el archivo en el disco. **Proceso** es el programa ejecutándose.
- Los **hilos** de un proceso comparten memoria; los **procesos** entre sí, no.
- El **PCB** es la ficha del proceso: PID, estado, contador de programa y registros.
- El **cambio de contexto** guarda un proceso y carga otro. Cuesta tiempo.
- Cinco estados: **Nuevo, Preparado, En ejecución, Bloqueado, Terminado**.
- De **Bloqueado** se pasa a **Preparado**, nunca directamente a En ejecución.
- **Respuesta = Inicio − Llegada** · **Servicio = Fin − Llegada + 1** · **Espera = Servicio − CPU**
- Primero la cuadrícula, después la tabla. Nunca al revés.
- **FIFO** por orden de llegada, no expulsivo, sufre efecto convoy.
- **Round Robin** por turnos de quantum, expulsivo, el más justo.
- Con **E/S**, el proceso deja la CPU en el acto, no hace cola mientras espera y, cuando termina,
  vuelve al **final** de la cola. **Espera = Servicio − CPU − E/S**.
- **Empates en la cola:** pasa primero el que lleva más tiempo sin ejecutarse.
- **SJF** el más corto primero, no expulsivo, mejores medias pero puede causar inanición.
- **SRT** como SJF pero expulsivo: expulsa si llega uno más corto que lo que queda.

### «Palabras nuevas» (glosario del tema), literal

| Palabra | Qué es |
|---|---|
| **Proceso** | Programa en ejecución, con su memoria y sus recursos. |
| **Hilo** | Línea de ejecución dentro de un proceso. Comparte su memoria. |
| **PID** | Número único que identifica un proceso. |
| **PCB** | Ficha donde el SO guarda todo lo del proceso. |
| **Cambio de contexto** | Guardar un proceso y cargar otro en la CPU. |
| **Planificador** *(scheduler)* | La parte del SO que decide quién entra en la CPU. |
| **Despachador** *(dispatcher)* | La parte del núcleo que da la CPU al proceso elegido. |
| **Ciclo** | Unidad de tiempo del reloj. En la cuadrícula, cada columna. |
| **Tiempo de respuesta** | Ciclos que pasan desde que llega un proceso hasta que entra por primera vez en la CPU. |
| **Quantum** | Número fijo de ciclos de CPU que recibe cada turno en Round Robin. |
| **Ráfaga** | Trozo seguido de tiempo de CPU, o de E/S, de un proceso. |
| **Expulsivo** | El sistema puede quitarle la CPU a un proceso sin que termine. |
| **Efecto convoy** | Procesos cortos atascados detrás de uno largo. |
| **Inanición** | Un proceso que no llega nunca a ejecutarse. |

---

## 4. Fórmulas exactas y cálculo de las medias

Con ciclos que empiezan en 1 e Inicio y Fin incluidos:

- **Respuesta = Inicio − Llegada**
- **Servicio = Fin − Llegada + 1**. Es el tiempo de retorno, contando el ciclo de llegada y el de fin.
- **Espera = Servicio − CPU** (sin E/S).
- **Espera = Servicio − CPU − E/S** (con E/S), «donde **CPU** es la suma de todas las ráfagas de CPU
  y **E/S** la suma de todas las de entrada/salida».
- Comprobaciones que propone el libro: (1) en la fila de cada proceso, las casillas vacías desde que
  llega hasta que termina tienen que dar su espera (las W no cuentan); (2) si el primero llega en el
  ciclo 1 y la CPU no se para nunca, el Fin del último es la suma de todas las CPU.

Equivalencia con tiempo continuo desde 0 (para el código de la misión): con `t_lleg = Llegada − 1`,
`t_ini = Inicio − 1` y `t_fin = Fin`, queda Respuesta = `t_ini − t_lleg`, Servicio =
`t_fin − t_lleg` y Espera = Servicio − CPU − E/S.

**Medias:** media aritmética de los procesos, escrita con **coma decimal**, **sin ceros de más**
(«5», «8», «1», «4,4», «7,5», «1,75») y **truncada a dos decimales, no redondeada**. Prueba:
29/3 sale como **9,66**, 11/3 como **3,66**, 25/3 como **8,33** y 8/3 como **2,66** (Ejemplo
resuelto 3 y Practica 4.7). Redondeando saldría 9,67 y 2,67. El libro no lo explica con palabras:
se deduce de esos ejemplos. PlaniSim lo hace así a propósito: `trunca()`, «com fa el llibre: dos
decimals tallats, sense zeros de sobra (6,66 · 4,4 · 1)».

---

## 5. Los algoritmos y sus reglas de desempate

Reglas generales (apartado 8): ciclos desde 1; un proceso que llega en el ciclo *k* ya puede
ejecutarse en *k*. En la cuadrícula: **X** = está en la CPU; **F** = último ciclo de CPU, el proceso
termina; **W** = ciclo de E/S; casilla vacía = en la cola o todavía no ha llegado. Debajo va la
**cola de preparados** de cada ciclo, con «arriba, el primero que entrará».

### 5.1 FIFO (apartado 9, pág. 81)
«FIFO (*First In, First Out*) es la cola del supermercado. Se atiende por orden de llegada, y **el
que entra no suelta la CPU hasta que termina**. Es **no expulsivo**.» Ventaja: «es simplísimo y no le
da trabajo al sistema». Inconveniente: el **efecto convoy**.

- **Llegadas en el mismo ciclo:** el libro **no dice nada** y ningún ejercicio lo plantea. PlaniSim
  mete a los que llegan a la vez en el orden de la lista de procesos (orden de entrada).
  *Propuesta: usar el orden de la tabla (P1 antes que P2).*

### 5.2 Round Robin (apartado 10, pág. 83, y 10.1)
«Round Robin reparte la CPU en turnos iguales. Cada proceso recibe un **quantum** (q): un número fijo
de ciclos. Cuando se le acaba, **aunque no haya terminado**, va al final de la cola y le toca al
siguiente. Es **expulsivo**.» Suelta la CPU por tres motivos: se le acaba el quantum, se bloquea por
E/S o termina antes de agotarlo.

Reglas que da el libro:
1. «**Si dos procesos tienen que entrar a la vez en la cola**, pasa primero **el que lleva más tiempo
   sin ejecutarse**. Uno que **llega nuevo** pasa delante del que **ha agotado el quantum**: el nuevo
   no se ha ejecutado nunca.» (Ejemplo 2, ciclo 8: llega E y C agota el quantum, así que entra
   primero E y después C. Ejemplo 3, ciclo 3: llega C y A agota el quantum, así que primero C y
   después A.)
2. Con E/S: «Cuando un proceso pide E/S, suelta la CPU en el acto, aunque no haya agotado el
   quantum». «Mientras hace E/S, no está en la cola.» La E/S no tiene cola: varios procesos pueden
   hacerla a la vez (Ejemplo 3, columna 8). «Cuando termina la E/S, vuelve al final de la cola de
   preparados. Nunca directamente a la CPU.»
3. Orden de los empates con E/S: «Si uno **llega nuevo**, pasa delante» · «Si uno **vuelve de E/S**
   y el otro **ha agotado el quantum**, primero el que vuelve de E/S» (Practica 4.7, ciclo 5) · «Si
   **vuelven dos de E/S**, primero el que lleva más tiempo allí.»
   → **Orden completo cuando entran varios a la vez: nuevos → los que vuelven de E/S (el que entró
   antes en E/S primero) → el que ha agotado el quantum.**
4. «Si en la cola no hay nadie, la CPU se queda parada: en esa columna de la cuadrícula no hay
   ninguna X.» (Practica 4.7, ciclo 10.)

Reglas que no están escritas y salen de los ejemplos:
- **El quantum se agota y la cola está vacía:** sigue el mismo proceso con un quantum nuevo
  (*inferido del Ejemplo resuelto 2*: A, con CPU 3 y q = 2, hace 1-2-3 sin interrupción porque B
  llega en el 4).
- **La ráfaga termina justo cuando se agota el quantum:** el proceso termina o se va a E/S, **no**
  vuelve a la cola (*inferido del Ejemplo resuelto 3*, ciclo 5: B, con CPU 2 y q = 2, se va a E/S).
- **Momento de la decisión:** la salida de la CPU (quantum agotado, fin, E/S) se resuelve al empezar
  el ciclo siguiente, a la vez que las llegadas de ese ciclo. Así salen los empates «llega nuevo /
  agota el quantum» del mismo ciclo. Coincide con PlaniSim.
- **Quien sale de la E/S en el ciclo *k*** puede ejecutarse en *k* si la cola está vacía (*inferido
  de la Practica 4.7*: P2 hace E/S en 9-10 y se ejecuta en 11).
- La E/S de *d* ciclos empieza en el ciclo siguiente al último ciclo de CPU (*inferido del Ejemplo
  3*: B acaba su ráfaga en el 4 y hace E/S en 5-6).

### 5.3 SJF (apartado 11, pág. 88)
«SJF (*Shortest Job First*) mira los procesos que ya han llegado y **elige el que menos ciclos de CPU
necesita**. Es **no expulsivo**: una vez elegido, lo deja terminar.» En la cola «ponemos arriba el
más corto, que es el que entrará». Problemas: inanición, y que «el sistema no sabe de antemano
cuánto tardará un proceso».

- **Empate en CPU:** no lo trata ningún ejercicio de SJF. La regla general del libro es «Empates en
  la cola: pasa primero el que lleva más tiempo sin ejecutarse». PlaniSim ordena de forma estable
  por lo que queda de la ráfaga, así que a igualdad gana **el que está antes en la cola** (el que
  entró antes). Ver la nota de SRT, donde esto se nota.
- **SJF con E/S:** el libro no lo trata. PlaniSim usa lo que queda de **la ráfaga actual**.

### 5.4 SRT (apartado 12, pág. 90)
«SRT (*Shortest Remaining Time*) es SJF pero **expulsivo**. Cada vez que llega un proceso nuevo, el
sistema compara: **¿Lo que necesita el recién llegado es menos que lo que le queda al que está en la
CPU?** Si la respuesta es sí, le quita la CPU al que estaba y se la da al nuevo.»

- **Si queda lo mismo, no hay expulsión:** la condición es «menos que», estricta (Ejemplo 5: «Como
  3 < 5, P2 expulsa a P1»). PlaniSim también usa `<` estricto.
- **El expulsado** vuelve a la cola y se ordena por lo que le queda (Practica 4.8 SRT: P1, al que le
  quedan 3, se pone delante de P3, que necesita 4).
- **Empate de lo que queda cuando la CPU se libera** (*inferido de la Practica 4.8 SRT, ciclo 4*):
  P1 (le quedan 4, expulsado en el ciclo 2) y P3 (necesita 4, llegó en el 3, no se ha ejecutado
  nunca). **Entra P1**, el que estaba antes en la cola. **Ojo:** si se aplicara al pie de la letra
  la regla de RR («el nuevo, que no se ha ejecutado nunca, pasa delante»), entraría P3. La solución
  del libro y PlaniSim deshacen el empate de SJF/SRT por **orden de la cola** (orden de entrada),
  no por la regla de «el nuevo primero». La regla «el nuevo primero» solo decide cómo se colocan los
  que entran en la cola en el mismo ciclo, que en SJF/SRT es el orden previo a la ordenación estable.
- **SRT con E/S:** el libro solo habla de «cuando llega un proceso nuevo». PlaniSim también deja
  expulsar a un proceso que **vuelve de E/S** y es más corto. El libro no tiene ningún ejemplo de
  esto.
- «Con los cinco procesos de siempre, SRT da lo mismo que SJF», porque nunca se cumple la condición
  de expulsar.

### 5.5 Resumen comparativo (apartado 13, pág. 91)

| Algoritmo | ¿Expulsivo? | ¿Justo? | Espera media | Riesgo de inanición | Se usa en |
|---|:---:|:---:|---|:---:|---|
| **FIFO** | No | Sí | Alta | No | Sistemas simples, colas de impresión |
| **Round Robin** | Sí | Sí | Media | No | Sistemas interactivos |
| **SJF** | No | No | Baja | **Sí** | Procesos por lotes con duración conocida |
| **SRT** | Sí | No | **Muy baja** | **Sí** | Sistemas de tiempo real |

> **La regla del quantum.** Si el quantum es **muy grande**, Round Robin se comporta igual que FIFO.
> Si es **muy pequeño**, se pierde muchísimo tiempo en cambios de contexto.

### 5.6 PlaniSim frente al libro

Cabecera de `planificador.js`: «Fa el mateix que el planificador del llibre
(03_PRODUCCIO/_eines/planificador.py), amb les mateixes regles». Lo que hace el código:
1. Ciclos desde 1. Inicio = primer ciclo en la CPU. Fi = ciclo de la F.
2. Al empezar cada ciclo, sale de la CPU el que ha acabado la ráfaga (si era la última, termina con
   Fi = ciclo − 1; si no, empieza la E/S en ese ciclo y dura *d* ciclos) o, en RR con el quantum a 0,
   el expulsado.
3. Entran en la cola, por este orden: **los que llegan** (en el orden de la lista de procesos), **los
   que vuelven de E/S** (ordenados por el ciclo en que empezaron la E/S) y **el expulsado por el
   quantum**.
4. SRT: de los que acaban de entrar, toma el más corto (a igualdad, el primero en ese orden). Si
   `necesita < le_queda_al_de_la_CPU`, el de la CPU va al final de la cola.
5. SJF/SRT: `cua.sort` **estable** por lo que queda de la ráfaga actual.
6. Si la CPU está libre, entra el primero de la cola con un quantum nuevo. Si la cola está vacía, la
   CPU se queda parada.
7. Medias truncadas a dos decimales, con coma y sin ceros de más.

**No hay ningún conflicto con las soluciones del libro:** he reproducido a mano con estas reglas
todos los ejercicios de abajo y sale exactamente lo impreso, cuadrículas y colas incluidas. Lo único
que no casa es la *letra* de la regla general «Empates en la cola: pasa primero el que lleva más
tiempo sin ejecutarse» aplicada a SJF/SRT (apartado 5.4): el libro, en la práctica, y PlaniSim
desempatan por orden de la cola.

---

## 6. Ejercicios resueltos (casos de prueba)

En cada ejercicio va: los datos; la **CPU por ciclo** (ciclos del libro, con el primero en 1 e
intervalos incluidos) y, entre corchetes, el **equivalente semiabierto desde 0**; la **cola por
ciclo** (de arriba abajo, el primero es el que entrará; solo los ciclos en que no está vacía); y la
tabla. Si la tabla del libro solo trae las medias, los valores por proceso van marcados como
*derivados* (calculados con las fórmulas del libro a partir de su cuadrícula).

### Datos A: los «cinco procesos de siempre» (apartado 8, pág. 81)

| Proceso | Llegada | CPU |
|:---:|:---:|:---:|
| A | 1 | 3 |
| B | 4 | 2 |
| C | 5 | 3 |
| D | 7 | 4 |
| E | 8 | 2 |

#### Ejemplo resuelto 1 — FIFO (pág. 81-82)
- CPU: `1-3 A, 4-5 B, 6-8 C, 9-12 D, 13-14 E` [`0-3 A, 3-5 B, 5-8 C, 8-12 D, 12-14 E`]
- Cola: c5 [C] · c7 [D] · c8 [D, E] · c9–c12 [E]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | 1 | 3 | 1 | 3 | 0 | 3 | 0 |
| B | 4 | 2 | 4 | 5 | 0 | 2 | 0 |
| C | 5 | 3 | 6 | 8 | 1 | 4 | 1 |
| D | 7 | 4 | 9 | 12 | 2 | 6 | 2 |
| E | 8 | 2 | 13 | 14 | 5 | 7 | 5 |
| | | | | **Media** | **1,6** | **4,4** | **1,6** |

#### Ejemplo resuelto 2 — Round Robin, q = 2 (pág. 83-84)
- CPU: `1-3 A, 4-5 B, 6-7 C, 8-9 D, 10-11 E, 12 C, 13-14 D` [`0-3 A, 3-5 B, 5-7 C, 7-9 D, 9-11 E, 11-12 C, 12-14 D`]
- Cola: c5 [C] · c7 [D] · c8 [E, C] · c9 [E, C] · c10 [C, D] · c11 [C, D] · c12 [D]
- Ciclo 8: llega E y C ha agotado el quantum, así que primero E y después C. En el ciclo 3, A agota
  el quantum con la cola vacía y sigue.

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | 1 | 3 | 1 | 3 | 0 | 3 | 0 |
| B | 4 | 2 | 4 | 5 | 0 | 2 | 0 |
| C | 5 | 3 | 6 | 12 | 1 | 8 | 5 |
| D | 7 | 4 | 8 | 14 | 1 | 8 | 4 |
| E | 8 | 2 | 10 | 11 | 2 | 4 | 2 |
| | | | | **Media** | **0,8** | **5** | **2,2** |

#### Practica 4.6 — Round Robin, q = 3 (pág. 84-85)
- CPU: `1-3 A, 4-5 B, 6-8 C, 9-11 D, 12-13 E, 14 D` [`0-3 A, 3-5 B, 5-8 C, 8-11 D, 11-13 E, 13-14 D`]
- Cola: c5 [C] · c7 [D] · c8 [D, E] · c9 [E] · c10 [E] · c11 [E] · c12 [D] · c13 [D]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | 1 | 3 | 1 | 3 | 0 | 3 | 0 |
| B | 4 | 2 | 4 | 5 | 0 | 2 | 0 |
| C | 5 | 3 | 6 | 8 | 1 | 4 | 1 |
| D | 7 | 4 | 9 | 14 | 2 | 8 | 4 |
| E | 8 | 2 | 12 | 13 | 4 | 6 | 4 |
| | | | | **Media** | **1,4** | **4,6** | **1,8** |

Pregunta: «¿Sale mejor o peor que con q = 2? ¿Por qué te lo esperabas?» Solución: «Mejor: el
servicio medio baja de 5 a 4,6 y la espera, de 2,2 a 1,8. Se esperaba porque casi todos necesitan 3
ciclos o menos y terminan dentro del primer turno. Hay menos expulsiones y se parece más a FIFO, que
con estos datos iba mejor.»

#### Ejemplo resuelto 4 — SJF (pág. 88-89)
- Narración: «Ciclo 1: solo está A. Se ejecuta de los ciclos 1 a 3. · Ciclo 4: solo está B. Ciclos
  4 y 5. · Ciclo 6: solo está C (D llega en el 7 y E, en el 8). Ciclos 6 a 8. · Ciclo 9: están D
  (necesita 4) y E (necesita 2). Gana E. Ciclos 9 y 10. · Ciclo 11: queda D. Ciclos 11 a 14.»
- CPU: `1-3 A, 4-5 B, 6-8 C, 9-10 E, 11-14 D` [`0-3 A, 3-5 B, 5-8 C, 8-10 E, 10-14 D`]
- Cola: c5 [C] · c7 [D] · c8 [E, D] · c9 [D] · c10 [D]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | 1 | 3 | 1 | 3 | 0 | 3 | 0 |
| B | 4 | 2 | 4 | 5 | 0 | 2 | 0 |
| C | 5 | 3 | 6 | 8 | 1 | 4 | 1 |
| D | 7 | 4 | 11 | 14 | 4 | 8 | 4 |
| E | 8 | 2 | 9 | 10 | 1 | 3 | 1 |
| | | | | **Media** | **1,2** | **4** | **1,2** |

#### SRT con los datos A (pág. 90): «da lo mismo que SJF»
Sale lo mismo que en el Ejemplo 4. En el ciclo 7, D necesita 4 y a C le quedan 2. En el ciclo 8, E
necesita 2 y a C le queda 1. Nunca hay expulsión.

#### Tabla comparativa con los datos A (pág. 91)

| | FIFO | RR (q=2) | SJF | SRT |
|---|:---:|:---:|:---:|:---:|
| Respuesta media | 1,6 | 0,8 | 1,2 | 1,2 |
| Servicio medio | 4,4 | 5 | 4 | 4 |
| Espera media | 1,6 | 2,2 | 1,2 | 1,2 |

### Guiado 4.5 — FIFO (pág. 82-83)
Datos: P1 (1, 4), P2 (2, 3), P3 (3, 2), P4 (6, 5). El P1 viene hecho.
- CPU: `1-4 P1, 5-7 P2, 8-9 P3, 10-14 P4` [`0-4 P1, 4-7 P2, 7-9 P3, 9-14 P4`]
- Cola: c2 [P2] · c3 [P2, P3] · c4 [P2, P3] · c5 [P3] · c6 [P3, P4] · c7 [P3, P4] · c8 [P4] · c9 [P4]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| P1 | 1 | 4 | 1 | 4 | 0 | 4 | 0 |
| P2 | 2 | 3 | 5 | 7 | 3 | 6 | 3 |
| P3 | 3 | 2 | 8 | 9 | 5 | 7 | 5 |
| P4 | 6 | 5 | 10 | 14 | 4 | 9 | 4 |
| | | | | **Media** | **3** | **6,5** | **3** |

### Ejemplo resuelto 3 — Round Robin con E/S, q = 2 (apartado 10.1, págs. 85-87)

| Proceso | Llegada | Ráfagas |
|:---:|:---:|---|
| A | 1 | CPU 3 · E/S 2 · CPU 1 |
| B | 2 | CPU 2 · E/S 2 · CPU 2 |
| C | 3 | CPU 2 · E/S 2 · CPU 2 |

Narración del libro, literal:
- **Ciclo 1.** Solo está A. Entra en la CPU.
- **Ciclo 2.** Llega B. Va a la cola.
- **Ciclo 3.** Llega C y A ha agotado el quantum, con 1 ciclo todavía por hacer: tienen que entrar a
  la vez en la cola. **Primero C, que es nuevo, después A.** Entra B. En la cola quedan C y A.
- **Ciclo 5.** B ha terminado la primera ráfaga y **se va a hacer E/S** los ciclos 5 y 6. Entra C.
  En la cola, A.
- **Ciclo 7.** C se va a hacer E/S los ciclos 7 y 8. B vuelve de la E/S y va a la cola, detrás de A.
  Entra A.
- **Ciclo 8.** A ha terminado la primera ráfaga y se va a hacer E/S los ciclos 8 y 9. Entra B.
- **Ciclo 9.** C vuelve de la E/S y va a la cola.
- **Ciclo 10.** B ha terminado. A vuelve de la E/S y va a la cola, detrás de C. Entra C.
- **Ciclo 12.** C ha terminado. Entra A, con la segunda ráfaga, y termina en este mismo ciclo.

Cuadrícula:

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **A** | X | X | | | | | X | W | W | | | F |
| **B** | | | X | X | W | W | | X | F | | | |
| **C** | | | | | X | X | W | W | | X | F | |
| **Cola** | | B | C | C | A | A | B | | C | A | A | |
| | | | A | A | | | | | | | | |

- CPU: `1-2 A, 3-4 B, 5-6 C, 7 A, 8-9 B, 10-11 C, 12 A` [`0-2 A, 2-4 B, 4-6 C, 6-7 A, 7-9 B, 9-11 C, 11-12 A`]
- E/S: B 5-6, C 7-8, A 8-9

| Proceso | Llegada | CPU y E/S | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | 1 | 3 · 2 · 1 | 1 | 12 | 0 | 12 | 6 |
| B | 2 | 2 · 2 · 2 | 3 | 9 | 1 | 8 | 2 |
| C | 3 | 2 · 2 · 2 | 5 | 11 | 2 | 9 | 3 |
| | | | | **Media** | **1** | **9,66** | **3,66** |

«Fíjate en la A: usa la CPU **4** ciclos, las dos ráfagas sumadas (3 + 1), y hace **2** ciclos de
E/S. Servicio 12 − 1 + 1 = 12. Espera 12 − 4 − 2 = **6**.»

### Practica 4.7 — Round Robin con E/S, q = 2 (págs. 86-87)

| Proceso | Llegada | Ráfagas |
|:---:|:---:|---|
| P1 | 1 | CPU 2 · E/S 2 · CPU 1 |
| P2 | 3 | CPU 3 · E/S 2 · CPU 1 |
| P3 | 4 | CPU 3 · E/S 2 · CPU 1 |

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **P1** | X | X | W | W | | | F | | | | | |
| **P2** | | | X | X | | | | X | W | W | F | |
| **P3** | | | | | X | X | | | X | W | W | F |
| **Cola** | | | | P3 | P1 | P1 | P2 | P3 | | | | |
| | | | | | P2 | P2 | P3 | | | | | |

- CPU: `1-2 P1, 3-4 P2, 5-6 P3, 7 P1, 8 P2, 9 P3, 10 (CPU parada), 11 P2, 12 P3` [`0-2 P1, 2-4 P2, 4-6 P3, 6-7 P1, 7-8 P2, 8-9 P3, 9-10 parada, 10-11 P2, 11-12 P3`]
- E/S: P1 3-4, P2 9-10, P3 10-11

| Proceso | Llegada | CPU y E/S | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| P1 | 1 | 2 · 2 · 1 | 1 | 7 | 0 | 7 | 2 |
| P2 | 3 | 3 · 2 · 1 | 3 | 11 | 0 | 9 | 3 |
| P3 | 4 | 3 · 2 · 1 | 5 | 12 | 1 | 9 | 3 |
| | | | | **Media** | **0,33** | **8,33** | **2,66** |

a) «En el ciclo 5 dos procesos tienen que entrar a la vez en la cola. ¿Cuáles son, y en qué orden
entran?» → «P1 vuelve de la E/S y P2 ha agotado el quantum. Primero P1, que lleva más tiempo sin
ejecutarse, después P2. La cola queda P3, P1, P2, y entra P3.»
b) «En la columna 10 no hay ninguna X. ¿Por qué?» → «Porque la cola está vacía: P1 ya ha terminado,
y P2 y P3 hacen E/S los dos a la vez. La CPU se queda parada.»

### Ejemplo resuelto 5 — SRT frente a SJF (pág. 90-91)
Datos: P1 (1, 7), P2 (3, 3).

**SJF** (no expulsivo): «P1 coge la CPU en el ciclo 1 y no la suelta.»
- CPU: `1-7 P1, 8-10 P2` [`0-7 P1, 7-10 P2`] · Cola: c3–c7 [P2]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| P1 | 1 | 7 | 1 | 7 | 0 | 7 | 0 |
| P2 | 3 | 3 | 8 | 10 | 5 | 8 | 5 |
| | | | | **Media** | **2,5** | **7,5** | **2,5** |

**SRT** (expulsivo): «en el ciclo 3 llega P2 y necesita 3. A P1 le quedan 5. Como 3 < 5, P2 expulsa
a P1. P2 va de los ciclos 3 a 5, y P1 recupera la CPU del 6 al 10.»
- CPU: `1-2 P1, 3-5 P2, 6-10 P1` [`0-2 P1, 2-5 P2, 5-10 P1`] · Cola: c3–c5 [P1]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| P1 | 1 | 7 | 1 | 10 | 0 | 10 | 3 |
| P2 | 3 | 3 | 3 | 5 | 0 | 3 | 0 |
| | | | | **Media** | **0** | **6,5** | **1,5** |

«SRT mejora la media. A cambio, P1 termina más tarde y ha habido un cambio de contexto de más.»

### Practica 4.8 — Los cuatro con los mismos datos, RR con q = 2 (págs. 92-93)
Datos: P1 (1, 5), P2 (2, 2), P3 (3, 4), P4 (5, 1). El libro da las cuatro cuadrículas y solo las
medias. Los valores por proceso son *derivados* y cuadran con las medias impresas.

**FIFO**
- CPU: `1-5 P1, 6-7 P2, 8-11 P3, 12 P4` [`0-5 P1, 5-7 P2, 7-11 P3, 11-12 P4`]
- Cola: c2 [P2] · c3 [P2, P3] · c4 [P2, P3] · c5 [P2, P3, P4] · c6 [P3, P4] · c7 [P3, P4] · c8–c11 [P4]
- *Derivado* (Respuesta/Servicio/Espera): P1 0/5/0 · P2 4/6/4 · P3 5/9/5 · P4 7/8/7

**Round Robin, q = 2**
- CPU: `1-2 P1, 3-4 P2, 5-6 P3, 7-8 P1, 9 P4, 10-11 P3, 12 P1` [`0-2 P1, 2-4 P2, 4-6 P3, 6-8 P1, 8-9 P4, 9-11 P3, 11-12 P1`]
- Cola: c2 [P2] · c3 [P3, P1] · c4 [P3, P1] · c5 [P1, P4] · c6 [P1, P4] · c7 [P4, P3] · c8 [P4, P3] · c9 [P3, P1] · c10 [P1] · c11 [P1]
- Ciclo 3: llega P3 y P1 agota el quantum, así que primero P3.
- *Derivado*: P1 0/12/7 · P2 1/3/1 · P3 2/9/5 · P4 4/5/4

**SJF**
- CPU: `1-5 P1, 6 P4, 7-8 P2, 9-12 P3` [`0-5 P1, 5-6 P4, 6-8 P2, 8-12 P3`]
- Cola: c2 [P2] · c3 [P2, P3] · c4 [P2, P3] · c5 [P4, P2, P3] · c6 [P2, P3] · c7 [P3] · c8 [P3]
- *Derivado*: P1 0/5/0 · P2 5/7/5 · P3 6/10/6 · P4 1/2/1

**SRT**
- CPU: `1 P1, 2-3 P2, 4 P1, 5 P4, 6-8 P1, 9-12 P3` [`0-1 P1, 1-3 P2, 3-4 P1, 4-5 P4, 5-8 P1, 8-12 P3`]
- Cola: c2 [P1] · c3 [P1, P3] · c4 [P3] · c5 [P1, P3] · c6–c8 [P3]
- Ciclo 2: P2 necesita 2 y a P1 le quedan 4, así que P2 expulsa. Ciclo 3: P3 necesita 4 y a P2 le
  queda 1, así que no expulsa. **Ciclo 4: empate a 4 entre P1 y P3 → entra P1** (ver 5.4). Ciclo 5:
  P4 necesita 1 y a P1 le quedan 3, así que P4 expulsa.
- *Derivado*: P1 0/8/3 · P2 0/2/0 · P3 6/10/6 · P4 0/1/0

| | FIFO | RR (q=2) | SJF | SRT |
|---|:---:|:---:|:---:|:---:|
| Respuesta media | 4 | 1,75 | 3 | 1,5 |
| Servicio medio | 7 | 7,25 | 6 | 5,25 |
| Espera media | 4 | 4,25 | 3 | 2,25 |

«¿Cuál da la mejor media de espera? ¿Cuál elegirías para un ordenador de sobremesa y por qué?» →
«La mejor espera es la de SRT, 2,25. Para un ordenador de sobremesa, Round Robin: tiene las medias
más malas, pero todos los programas reciben turno pronto y el ordenador responde mientras trabajas.
SJF y SRT pueden dejar sin turno a los procesos largos.»

### Repaso C — Problemas 1, 2 y 3 (repaso del tema, págs. 96-100 aprox.)
Datos de los tres: A (1, 6), B (2, 3), C (4, 1), D (6, 4).

**Problema 1 — FIFO**
- CPU: `1-6 A, 7-9 B, 10 C, 11-14 D` [`0-6 A, 6-9 B, 9-10 C, 10-14 D`]
- Cola: c2 [B] · c3 [B] · c4 [B, C] · c5 [B, C] · c6 [B, C, D] · c7 [C, D] · c8 [C, D] · c9 [C, D] · c10 [D]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | 1 | 6 | 1 | 6 | 0 | 6 | 0 |
| B | 2 | 3 | 7 | 9 | 5 | 8 | 5 |
| C | 4 | 1 | 10 | 10 | 6 | 7 | 6 |
| D | 6 | 4 | 11 | 14 | 5 | 9 | 5 |
| | | | | **Media** | **4** | **7,5** | **4** |

**Problema 2 — Round Robin, q = 2**
- CPU: `1-2 A, 3-4 B, 5-6 A, 7 C, 8 B, 9-10 D, 11-12 A, 13-14 D` [`0-2 A, 2-4 B, 4-6 A, 6-7 C, 7-8 B, 8-10 D, 10-12 A, 12-14 D`]
- Cola: c2 [B] · c3 [A] · c4 [A, C] · c5 [C, B] · c6 [C, B, D] · c7 [B, D, A] · c8 [D, A] · c9 [A] · c10 [A] · c11 [D] · c12 [D]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | 1 | 6 | 1 | 12 | 0 | 12 | 6 |
| B | 2 | 3 | 3 | 8 | 1 | 7 | 4 |
| C | 4 | 1 | 7 | 7 | 3 | 4 | 3 |
| D | 6 | 4 | 9 | 14 | 3 | 9 | 5 |
| | | | | **Media** | **1,75** | **8** | **4,5** |

**Problema 3 — SJF**
- CPU: `1-6 A, 7 C, 8-10 B, 11-14 D` [`0-6 A, 6-7 C, 7-10 B, 10-14 D`]
- Cola: c2 [B] · c3 [B] · c4 [C, B] · c5 [C, B] · c6 [C, B, D] · c7 [B, D] · c8 [D] · c9 [D] · c10 [D]

| Proceso | Llegada | CPU | Inicio | Fin | Respuesta | Servicio | Espera |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | 1 | 6 | 1 | 6 | 0 | 6 | 0 |
| B | 2 | 3 | 8 | 10 | 6 | 9 | 6 |
| C | 4 | 1 | 7 | 7 | 3 | 4 | 3 |
| D | 6 | 4 | 11 | 14 | 5 | 9 | 5 |
| | | | | **Media** | **3,5** | **7** | **3,5** |

«¿Cuál de los tres da la menor espera media?» → «La de SJF: 3,5, frente a 4 con FIFO y 4,5 con Round
Robin.»

### Comprobación de consistencia
He comprobado a mano los 16 casos de arriba: las cuadrículas y las colas con las reglas del apartado
5, cada fila con las fórmulas y cada media. **No hay ninguna solución incoherente.** Todo cuadra con
lo impreso y con la lógica de PlaniSim. Las únicas discrepancias están en el texto, no en los datos:
(1) las figuras en castellano dicen «LISTO / COLA DE LISTOS» y «MONTÓN», y el texto, «Preparado» y
«Montículo»; (2) la regla general de empates («el que lleva más tiempo sin ejecutarse / el nuevo
primero») no explica el empate de SRT de la Practica 4.8 (apartado 5.4).

---

## 7. Otros ejercicios del tema (con solución)

- **Practica 4.1** (pág. 74). a) Tres ventanas de Chrome: «Un solo programa, Chrome, y tres procesos,
  uno por ventana. De hecho, Chrome abre todavía más: uno para cada pestaña.» b) Programa frente a
  proceso: «El programa es el archivo guardado en el disco, quieto. El proceso es ese programa en
  marcha: cargado en la RAM y con la CPU ejecutando sus instrucciones. El programa es la receta; el
  proceso es cocinar.»
- **Practica 4.2** (pág. 76), zona de memoria: instrucciones → Código; variable creada dentro de una
  función → Pila; variable global → Datos; memoria reservada mientras se ejecuta → Montículo.
- **Proceso frente a hilo** (pág. 75, teoría): Memoria: propia y aislada / compartida con el proceso ·
  Crearlo: cuesta más / es rápido y ligero · Si falla: no afecta a los otros procesos / puede tumbar
  todo el proceso · Ejemplo: abrir el navegador / cada pestaña cargando a la vez. Los hilos comparten
  código, datos, montículo y archivos abiertos. Cada hilo tiene su pila y su contador de programa.
- **PCB** (pág. 77, teoría): PID · Estado · Contador de programa · Registros de la CPU · Información
  de planificación (prioridad y tiempo de CPU gastado) · Estadísticas. «El PCB es lo que hace posible
  que un proceso se pare y después siga **exactamente donde estaba**.»
- **Cambio de contexto** (pág. 77): 1. Guardar en el PCB del que sale los registros y el contador de
  programa. 2. Cargar desde el PCB del que entra. Cuesta tiempo (FIG 4.2: «La franja rayada es tiempo
  perdido»).
- **Guiado 4.3** (pág. 79), estado de cada situación: esperando que el usuario pulse una tecla →
  Bloqueado · usando la CPU → En ejecución · ha agotado el quantum y vuelve a la cola → Preparado · se
  acaba de crear y todavía no está en la cola → Nuevo · ha terminado su última instrucción →
  Terminado.
- **Practica 4.4** (pág. 79): dibujar de memoria el diagrama con las seis flechas y sus causas (FIG
  4.3m). No trae solución en texto: es la tabla del apartado 2 de este documento.
- **Practica 4.9** (pág. 94-95, en el ordenador). a) `ps -aux | grep firefox`: «Depende de cada
  ordenador: es el número de la segunda columna. Si Firefox no está abierto, solo sale la línea del
  propio grep.» b) `top`: «Depende del ordenador. Lo dice la línea Tasks de arriba: el total y
  cuántos salen como running. Normalmente en ejecución hay uno o dos.» c) 120 procesos y 1 en
  ejecución: «Casi todos bloqueados, esperando algo: una tecla, el disco, la red. En top salen como
  sleeping. Alguno puede estar preparado, esperando turno de CPU.» d) Proceso al 0 % de CPU en el
  Administrador de tareas: «Bloqueado: no usa CPU porque está esperando algo.»
- **Comandos (14.1):** `top`, `ps -aux`, `kill -9 PID`, `kill -STOP PID`, `kill -CONT PID`, `Ctrl+Z`,
  `bg` / `fg`. En Windows, el Administrador de tareas (Ctrl+Shift+Esc), pestaña *Detalles*.
- **Repaso A. Verdadero o falso:** Un programa y un proceso son lo mismo → **F** (el programa es el
  archivo; el proceso, el programa en marcha) · Un proceso bloqueado pasa directamente a ejecución →
  **F** (primero vuelve a preparado y hace cola) · Round Robin es expulsivo → **V** (quita la CPU
  cuando se acaba el quantum) · SJF puede provocar inanición → **V** (si no paran de llegar cortos,
  uno largo no entra nunca) · Los hilos de un proceso comparten la pila → **F** (cada hilo tiene su
  pila) · El cambio de contexto no cuesta tiempo → **F** (mientras se hace, la CPU no hace trabajo
  útil).
- **Repaso B. Preguntas cortas:** 1) Qué guarda el PCB antes de un cambio de contexto → «El contador
  de programa y los registros de la CPU del proceso que sale, para poder continuarlo exactamente
  donde estaba. También actualiza su estado.» 2) Por qué un quantum muy pequeño es mala idea →
  «Porque se hacen cambios de contexto todo el rato, y cada cambio es tiempo en el que la CPU no hace
  trabajo útil.» 3) Diferencia entre SJF y SRT → «SJF no es expulsivo: el elegido termina aunque
  llegue uno más corto. SRT sí: si el recién llegado necesita menos de lo que le queda al que se
  ejecuta, le quita la CPU.» 4) Efecto convoy → «Respuesta libre. Por ejemplo: en la caja del súper,
  alguien con el carro lleno llega primero, y tres personas que solo llevan una cosa esperan mucho
  para una compra de segundos.»
- **Repaso C. Problema 4** (estados): «El que espera al disco está bloqueado, y el que usa la CPU, en
  ejecución. Cuando el disco contesta llega una interrupción y el bloqueado pasa a preparado: hace
  cola y espera su turno. No entra directamente en la CPU.»

---

## 8. Tono y formato del libro

Frases cortas, en segunda persona («tú»), con analogías de la vida diaria, recuadros de aviso en
negrita («Atención a lo que más se falla», «Comprueba siempre», «Lo que importa», «Fíjate») y
ejercicios en tres niveles: **Ejemplo resuelto** → **Guiado** → **Practica**. Algunas frases
literales:

- «El programa es la receta. El proceso es cocinar.»
- «FIFO (*First In, First Out*) es la cola del supermercado.»
- «El planificador decide; el despachador ejecuta.»
- «Atención a lo que más se falla. De Bloqueado no se pasa nunca directamente a En ejecución. […]
  Esta flecha mal puesta es el error clásico del examen.»
- «Fíjate en el orden: primero rellenas la cuadrícula, de ahí sacas el Inicio y el Fin, y con eso ya
  salen la respuesta, el servicio y la espera. Nunca al revés.»
- «Comprueba siempre. En la fila de la A, cuenta las casillas vacías desde que llega hasta que
  termina: la 3, 4, 5, 6, 10 y 11. Son 6, como la espera. Si no coincide, es que no has restado la
  E/S.»
- «Paso 1. Seguimos la cola ciclo a ciclo. Este es el paso que no te puedes saltar.»
- «Fíjate en algo que no esperabas: con estos datos Round Robin sale peor que FIFO en servicio.»
- «Entonces, ¿por qué se usa? Mira la respuesta […]. En un ordenador con el que estás trabajando, eso
  es lo que hace que no se te quede congelado.»
- «La conclusión que hay que sacar. No existe el mejor algoritmo. Existe el que va mejor para lo que
  quieres.»
- Sobre la chuleta (introducción del libro): «Cópiala, hazle una foto, tenla abierta: usarla no es
  hacer trampa.»
- Sobre el cuaderno: «Esto no es un libro para leer: es un cuaderno para escribir en él.»
