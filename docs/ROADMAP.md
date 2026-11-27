# Roadmap — Mini SO

Hito actual: **M1 — Marco de misión** (código y pruebas hechos; falta la validación de Guillem).

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
- [ ] **Guillem:** hacer la misión de prueba entera (ver «Qué probar» abajo)

### Qué probar (M1)
1. Jugar → escribe tu nombre → Missió de prova.
2. Fase 1: ¿se entiende el ejemplo animado? ¿Va demasiado rápido o lento? (`reveal_interval` en `binary_switches.tscn`).
3. Fase 2: equivócate a propósito. ¿Los mensajes ayudan a arreglarlo?
4. Fase 3: usa una pista, abre la chuleta (F1), falla una vez y acaba. ¿La nota te parece justa? (pesos en `data/grading/default.tres`).
5. «Informes» abre la carpeta con el JSON. Cambia de idioma desde la pausa (Esc → Opcions) en mitad de la misión.

## M2 — Demo jugable: misión 4 (planificador)
- [ ] Leer el tema 4 del cuaderno (y `planisim`): vocabulario, ejemplos y criterio de desempate
- [ ] `scheduler.gd` con tests de FIFO, RR, SJF y SRT contra los ejercicios resueltos; desempates documentados en el GDD
- [ ] Calentamiento: diagrama de estados
- [ ] Editor de Gantt arrastrable (ratón y táctil); tiempos de espera y retorno y medias
- [ ] Mensajes de fallo precisos («RR: en t=6 le tocaba a P3»)
- [ ] Las tres fases, chuleta y resultado
- [ ] **Parar aquí: Guillem la prueba con alumnos** antes de seguir

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
