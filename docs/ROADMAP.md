# Roadmap — Mini SO

Hito actual: **M2 — Demo jugable: misión 4 (planificador)** (hecho; **parado para que Guillem lo pruebe con alumnos**).

Regla: trabajar solo en el hito actual; no empezar el siguiente hasta que `./tools/check.sh` esté en verde y Guillem haya validado lo que hay que probar jugando. Cada hito entrega ya sus textos en catalán, castellano e inglés.

## M0 — Esqueleto
- [x] Proyecto y servidor creados con `new-game.sh` (infra-v2): `~/code/som-mini-kit` y `~/code/som-mini-server` (`miniso.enguillem.es`, puerto 8470, subred 10.213.148.0/24)
- [x] Quitar lo específico de carreras (coche, pistas, garaje, IA, campeonato y tests)
- [x] InputMap: `pause`, `cheatsheet` (F1), `hint` (F2)
- [x] Traducciones ca (por defecto), es, en con `data/texts/ui.csv`; selector de idioma en el menú y en opciones; se guarda y se aplica sin reiniciar
- [x] Menú principal que abre un hub vacío
- [x] `CLAUDE.md`, `docs/GDD.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`
- [x] `./tools/check.sh` en verde
- [x] Repositorio conectado a `origin` y subido (`git push -u origin main`)
- [x] **Guillem:** abrir el juego, cambiar de idioma en el menú y en opciones, cerrar y volver a abrir (debe recordar el idioma), entrar al hub y volver

## M1 — Marco de misión
- [x] `exercise_seed.gd`: RNG sembrado, semillas de seis cifras y derivadas por fase (tests)
- [x] `grading.gd` y pesos en `data/grading/default.tres` (70 % aciertos, 20 % intentos, 10 % pistas) (tests)
- [x] `attempt_report.gd`: informe JSON con HMAC-SHA256 en `user://reports/`, verificable (tests)
- [x] `MissionData`, `Cheatsheet`, `ChallengeResult` y la base `MissionContent`
- [x] `mission_shell`: tres fases (ejemplo, guiado, en solitario), chuleta (F1), pistas (F2), comprobar/entregar, resultado (tests)
- [x] Nombre del alumno: se pide al pulsar Jugar la primera vez y se cambia en Opciones; sale en el informe
- [x] Misión de prueba (cerrojo binario, `scenes/missions/sample/`) accesible desde el hub para probar el marco
- [x] Textos en ca/es/en
- [x] **Guillem:** hacer la misión de prueba entera (ver «Qué probar» abajo)

### Qué probar (M1)
1. Jugar → escribe tu nombre → Missió de prova.
2. Fase 1: ¿se entiende el ejemplo animado? ¿Va demasiado rápido o lento? (`reveal_interval` en `binary_switches.tscn`).
3. Fase 2: equivócate a propósito. ¿Los mensajes ayudan a arreglarlo?
4. Fase 3: usa una pista, abre la chuleta (F1), falla una vez y acaba. ¿La nota te parece justa? (pesos en `data/grading/default.tres`).
5. «Informes» abre la carpeta con el JSON. Cambia de idioma desde la pausa (Esc → Opcions) en mitad de la misión.

## M2 — Demo jugable: misión 4 (planificador)
- [x] Leer el tema 4 del cuaderno y `planisim`: extracto en `docs/temario/tema4.md` (vocabulario ca/es, chuleta, desempates, 16 ejercicios resueltos)
- [x] `scheduler.gd` con FIFO, RR (con E/S), SJF y SRT en ciclos desde 1, como el libro; los 16 casos resueltos del libro son tests
- [x] Calentamiento: sala de estados del proceso (6 situaciones, la trampa «Bloqueado → En ejecución»)
- [x] Cuadrícula del libro (tocar o arrastrar por la fila; F y W automáticas) y tabla Inicio/Fin/Respuesta/Servicio/Espera con medias truncadas
- [x] Mensajes de fallo precisos («En el ciclo 3 le tocaba a P2, no a P1» + por qué), tabla con error arrastrado
- [x] Seis salas con su nota: estados, FIFO, Round Robin, Round Robin con E/S, SJF, SRT; tres fases, chuleta y resultado
- [ ] **Parar aquí: Guillem la prueba con alumnos** antes de seguir

### Qué probar (M2)
1. ¿Se entiende la cuadrícula sin explicación? ¿Es cómodo marcar con ratón y en pantalla táctil (tocar y arrastrar)?
2. Ejemplo animado: ¿la velocidad va bien? (`reveal_interval` en `gantt_mission.tscn`, 0,8 s por ciclo).
3. ¿Los mensajes de fallo ayudan? (ciclo y motivo; +1 del servicio; E/S en la espera; medias truncadas).
4. ¿Cuánto tarda cada sala? Objetivo: 5–8 min por sala.
5. Tamaño de los ejercicios: 4 procesos (3 con E/S), como mucho 16 ciclos. ¿Muy fácil o muy difícil?
6. «Inicio» y «Fin» se piden en la tabla aunque salen de la cuadrícula, como en el libro. ¿Se mantienen?

## M3 — Hub y progreso
- [ ] Mapa de la placa base con buses y 7 zonas (bloqueada, abierta, superada); arte Kenney CC0
- [ ] Desbloqueo en el orden del cuaderno; mejor nota e intentos guardados

## M4 a M9 — Resto de misiones (orden del cuaderno)
- [ ] M4: misión 1, el taller (tema 1)
- [ ] M5: misión 2, la torre de capas (tema 2)
- [ ] M6: misión 3, la caja fuerte binaria (tema 3) — `number_systems.gd`
- [ ] M7: misión 5, el almacén de RAM (tema 5) — `memory.gd`
- [ ] M8: misión 6, el archivo (tema 6) — `permissions.gd`, `raid.gd`, `paths.gd`
- [ ] M9: misión 7, el hipervisor (tema 7) — `vm_network.gd`

## M10 — Modo examen e informe para el profesor
- [ ] Sin ejemplo ni pistas, tiempo límite, semilla dada por el profesor
- [ ] Informe para el profesor

## M11 — Online
- [ ] Servidor: quitar lo de carreras (`app/game/`, `stats`, `Ranking`, migración `0002`), `./setup.sh`, pruebas, `./deploy.sh`, SMTP
- [ ] Envío de notas al servidor y vista en el panel de administración
- [ ] Traducir las pantallas online del kit (`online_login`, `online_lobby`) y reescribir `docs/ONLINE.md`
- [ ] Revisar `docs/PRIVACIDAD.md` con el nuevo inventario de datos (notas del alumnado)

## M12 — Pulido
- [ ] Revisión de las traducciones, sonido, exportaciones (Linux, Windows, macOS) y prueba en equipos reales

## Decisiones tomadas
- 2026-11-27: título «Mini SO»; idioma con selector, catalán por defecto; dominio `miniso.enguillem.es`, puerto 8470; notas **solo de práctica** por ahora; arte Kenney CC0.
