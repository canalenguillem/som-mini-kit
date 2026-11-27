# Servidor y web (repo `mini-bolidos-server`)

## Qué es genérico y qué es de carreras

Al crear un juego nuevo con `new-game.sh` se copia todo. Esta tabla dice qué conservar tal cual, qué adaptar y qué borrar.

### Backend (`backend/app/`)

| Archivo | Tipo | Nota |
|---|---|---|
| `config.py`, `db.py`, `resources.py`, `security.py`, `sessions.py`, `ratelimit.py`, `mail.py`, `audit.py`, `presence.py`, `deps.py`, `maintenance.py` | **Genérico** | No tocar. Los ajustes `race_*`, `state_hz`, `cp_min_interval_scale`, `finish_grace_s` en `config.py` son de carreras: se pueden renombrar o quitar |
| `routers/auth.py`, `routers/me.py`, `routers/downloads.py` | **Genérico** | `me.py` (exportar mis datos) consulta `Race`/`RaceResult`: adaptar a las partidas del juego nuevo |
| `routers/admin.py` | **Genérico** salvo `/rooms` | Usa `lobby`. Las rutas de usuarios, conectados, descargas y auditoría no cambian |
| `routers/ws.py` | **Casi genérico** | Autenticación, límites, latido y privacidad son comunes; el reparto de mensajes llama a `lobby.handle` |
| `main.py` | **Genérico** | Incluye el router `stats`: quitar o adaptar |
| `models.py` | **Genérico** (`User`, `EmailToken`, `DownloadEvent`) + **específico** (`Race`, `RaceResult`) | Sustituir las dos últimas por las tablas de partidas del juego nuevo |
| `schemas.py` | Mixto | `RoomOut`, `MyStatsOut`, `LeaderboardEntry` son de carreras |
| `routers/stats.py` | **Específico** | Estadísticas y clasificación por pista: reescribir o borrar |
| `game/` (`lobby.py`, `room.py`, `laps.py`, `tracks.py`, `tracks.json`) | **Específico** | Es el módulo de juego: ver más abajo |
| `migrations/versions/0001_users`, `0003_downloads`, `0004_download_client`, `0005_privacy` | **Genérico** | `0002_races` es de carreras: sustituir por las tablas del juego nuevo (conservando la cadena 0001→…) |

### Pruebas (`backend/tests/`)

Genéricas: `test_auth`, `test_me` (salvo exportación), `test_admin` (salvo salas), `test_presence`, `test_downloads`, `test_maintenance`, `test_privacy`, `conftest.py`. Específica: `test_rooms.py` (carreras con 5 clientes simulados): úsala como **modelo** para las del juego nuevo. `conftest.py` trunca tablas `races` y reinicia `lobby`: adaptar los nombres.

### Web (`frontend/src/`)

Genéricas: `auth.tsx`, `api.ts` (salvo tipos y llamadas de salas/clasificación), `App.tsx`, páginas `Login`, `Register`, `Activate`, `Forgot`, `Reset`, `Account`, `Privacy`, `Downloads`, `Home` (cambiar el texto). `Admin.tsx`: las pestañas Conectados, Usuarios, Descargas y Auditoría son genéricas; **Salas** usa el vestíbulo. `Ranking.tsx` y las estadísticas de `Account.tsx` son de carreras.

Los textos "Mini Bólidos", el emoji y las instrucciones de descarga se renombran con `new-game.sh`, pero conviene revisarlos.

### Operaciones

`deploy.sh`, `publish-download.sh`, `backup.sh`, `verify-backup.sh`, `restore.sh`, `install-backup-cron.sh`, `set-smtp.sh`, `setup.sh`, `docker-compose*.yml`, `db/init/`, `frontend/nginx.conf`: genéricos (ver `operaciones.md`).

## API (resumen)

| | |
|---|---|
| `POST /api/auth/register` (`accept_privacy` obligatorio) `activate` `resend-activation` `login` `logout` `forgot-password` `reset-password` | cuentas |
| `GET /api/me`, `POST /api/me/password`, `POST /api/me/accept-privacy`, `GET /api/me/export`, `DELETE /api/me` | perfil y derechos |
| `GET /api/info` | datos públicos para la web (versión de la política, contacto) |
| `GET /api/download/<linux|windows|macos>` | cuenta y entrega la descarga |
| `GET /api/admin/stats\|online\|users\|rooms\|downloads\|audit`; `POST /api/admin/users/{id}/ban\|unban\|activate\|kick`; `DELETE …/{id}`; `POST /api/admin/rooms/{id}/close` | administración |
| `GET /api/stats/me`, `leaderboard?track=`, `tracks` | **de carreras** |
| `WS /api/ws?client=game\|web` (cabecera `Authorization` o `?token=`) | presencia y partidas |

Códigos de cierre del WebSocket: 4001 no autorizado · 4002 otra sesión abierta · 4003 expulsado o sesión caducada · 4004 mensaje demasiado grande · 4005 servidor lleno · 4006 demasiados mensajes por segundo · 4007 falta aceptar la política de privacidad.

## El módulo de juego (`app/game/`): cómo se enchufa

El WebSocket es genérico; el juego decide qué hacer con los mensajes. El contrato:

- `ws.py` llama a `await lobby.handle(user, msg)` para todo mensaje que no sea `ping`, y a `lobby.on_disconnect(user_id)` al cerrarse la conexión.
- `lobby` (`game/lobby.py`) guarda las salas (`rooms`, `by_user`), gestiona entrar/salir/crear/arranque y envía la lista de salas a quien está en el vestíbulo. Envía mensajes con `presence.manager.send(user_id, dict)`.
- `room` (`game/room.py`) es una sala: huecos (`Slot`) de humanos y bots, estados `waiting → countdown → racing → finished`, bucle asíncrono de la partida, reenvío de estados a ~15 Hz, validación y resultados. Al terminar llama a `lobby._room_done`, que libera a los jugadores, envía resultados y guarda en MariaDB y MongoDB.
- El anfitrión (el humano conectado con el puesto más bajo) simula a los bots y envía sus mensajes con un campo `slot`.

**Para un juego nuevo:** conserva `Lobby` (salas, quick_join, crear, unirse, salir, arrancar, administración, `pending_saves`) y reescribe `Room` con las reglas del juego (por ejemplo equipos y marcador en vez de vueltas y checkpoints). Mantén el principio: **el servidor valida lo que importa** (en carreras, el orden de checkpoints y el tiempo de meta; en fútbol, goles y duración) y nunca se fía del tiempo del cliente.

### Autoridad en partidas con objetos compartidos (balón)

En carreras cada cliente simula solo su coche. Si hay un objeto que todos tocan (un balón), alguien tiene que ser la autoridad: lo más simple es que **el anfitrión simule el objeto** y los demás reciban su posición suavizada; el servidor valida los goles (por ejemplo, que el balón cruce la línea según el estado reenviado). Un servidor que simule todo es más justo pero mucho más trabajo.

## Cómo se prueba

```bash
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm --build backend   # pytest; usa bolidos_test, Redis db 1, MAIL_BACKEND=memory
cd frontend && npm install && npm run build                                              # comprueba tipos y compila
```

Patrones de las pruebas: `TestClient` (sincrónico) con `client.portal.call(...)` para consultar la base en el bucle de la app; fixture `client` que reinicia el estado (cancela salas, espera guardados pendientes, trunca tablas, limpia Redis y Mongo); `make_user` registra, activa y entra; clientes WebSocket simulados con `ExitStack`; `pytest-timeout` evita bloqueos. No lances dos ejecuciones de pruebas a la vez: comparten la base de pruebas.

## Migraciones (Alembic)

Se aplican solas al arrancar el contenedor (`alembic upgrade head`). Se escriben a mano (no hay autogeneración) con la cadena `0001 → 0002 → …`. Haz una copia de seguridad (`./backup.sh`) antes de desplegar una migración en producción.
