# Modo online

Objetivo: que el alumnado juegue carreras entre sí en un servidor propio, con cuentas, y que el profesor administre y vea quién está conectado.

## Decisiones

- **Cliente:** el juego de escritorio (Godot) con un menú "Jugar solo" u "Online". No hay versión web del juego, para no cargar el servidor.
- **Netcode:** cada cliente simula **su** coche y envía su estado; el servidor lo retransmite y **valida** checkpoints y tiempos de meta. Los coches remotos se interpolan. Un alumno podría falsear su posición; en un aula se acepta, pero la meta y los tiempos las valida el servidor.
- **Sala:** una carrera arranca cuando hay 5 jugadores en espera.
- **Servidor:** repo aparte, `som-mini-server` (Python/FastAPI, React + TypeScript con Vite, MariaDB, MongoDB, Redis, todo en Docker). Se desarrolla en local y se despliega con rsync en `75enguiem:/home/guillem/code/som-mini-server`.
- **Publicación:** la gestiona el profesor (dominio `miniso.enguillem.es`, HTTPS). El servidor solo expone el puerto del frontend (nginx), que enruta `/api` y `/ws` al backend. Las bases de datos y el backend no publican puertos.
- **MongoDB 4.4:** la VM de `75enguiem` no expone AVX y MongoDB 5+ no arranca. Se usa `mongo:4.4` (fin de vida, sin puerto publicado y solo en la red privada de Docker). Si se activa el CPU "host" en el hipervisor, basta cambiar `MONGO_IMAGE` en el `.env` del servidor.
- **Correo:** Gmail por SMTP con contraseña de aplicación en `.env` (nunca en el repo).

## Qué guarda cada base de datos

| Servicio | Para qué |
|---|---|
| MariaDB | Cuentas, tokens de activación y recuperación, carreras, resultados y estadísticas |
| Redis | Sesiones revocables, presencia (quién está conectado), límites de intentos de login, colas y salas |
| MongoDB | Registro de auditoría de acciones de administración; telemetría y repeticiones de carreras (M9) |

## Reglas de seguridad

- Contraseñas con Argon2. Nunca se guardan ni se registran en claro.
- La cuenta no entra hasta activar el correo.
- Los tokens de activación y recuperación se guardan con hash y caducan.
- Límite de intentos en registro y login (por IP y por usuario).
- Sesiones en Redis: el administrador puede expulsar a un usuario revocando su sesión.
- Secretos solo en `.env` (permisos 600) fuera de git.

## Privacidad

Se guardan nombre de usuario, correo y resultados de alumnado, a veces menor de edad. Antes de abrirlo al grupo hay que revisarlo con el centro (consentimiento, plazo de conservación, derecho de borrado). Hay un endpoint para borrar la propia cuenta.

### Cookie de descargas

La página de descargas cuenta cuántas veces se descarga cada versión. Para no contar dos veces al mismo alumno (y, a la vez, contar a cada uno de una clase entera que comparte IP), el navegador recibe una cookie técnica aleatoria (`som_mini_cid`, solo para `/api/download`, `HttpOnly`, 90 días). No identifica a la persona ni se cruza con la cuenta; el servidor solo guarda un hash de ese valor junto a la versión y la fecha. Hay que mencionarla en la información de privacidad que se entregue al centro.

## Protocolo

Un único WebSocket `/api/ws?client=game` por usuario. Autenticación con la cabecera `Authorization: Bearer <token>` (el navegador usa `?token=`). Mensajes JSON de texto, de hasta 4096 caracteres; todos llevan `"t"` con el tipo. Un mensaje desconocido o con datos inválidos se descarta (a veces con `{"t":"error","reason":…}`).

Códigos de cierre: 4001 no autorizado · 4002 otra sesión abierta · 4003 expulsado o sesión caducada · 4004 mensaje demasiado grande.

### Latido

Cada 15 s el cliente envía `{"t":"ping"}` y recibe `{"t":"pong"}`. Sin ningún mensaje durante 45 s, el servidor da por perdida la conexión.

### Salas (cliente → servidor)

| Mensaje | Efecto |
|---|---|
| `{"t":"rooms"}` | pide la lista de salas |
| `{"t":"quick_join"}` | entra en la sala con más gente que aún espera, o crea una |
| `{"t":"room_create","name":"Clase 2B"}` | crea una sala y entra en ella |
| `{"t":"room_join","id":"…"}` | entra en una sala que espera |
| `{"t":"room_leave"}` | sale de la sala (en carrera cuenta como no terminar) |
| `{"t":"room_start"}` | el propietario (o un admin) la arranca ya, completando con bots hasta 5 |

Con 5 jugadores humanos la sala arranca sola, sin bots. Errores (`reason`): `already_in_room`, `room_not_found`, `room_started`, `room_full`, `not_in_room`, `not_owner`.

### Salas (servidor → cliente)

- `{"t":"rooms","rooms":[{id,name,state,players,max,owner}]}`: solo a quien está en el vestíbulo.
- `{"t":"room","id","name","state","owner_id","max","players":[{slot,user_id,username,bot}]}`: a los miembros cuando cambia la sala.
- `{"t":"left"}`: confirmación de `room_leave`.
- `{"t":"room_closed"}`: un admin cerró la sala.

### Carrera

1. `{"t":"start","room","track","laps","checkpoints","countdown_ms","host_id","players":[{slot,user_id,username,bot}]}`: empieza la cuenta atrás. La pista la elige el servidor por rotación (`west_01`, `west_02`, `jungle_01`, `jungle_02`). `slot` (0-4) es el puesto en la parrilla.
2. `{"t":"go"}`: salida. El reloj de la carrera es el del servidor.
3. Durante la carrera, cada cliente simula **su** coche y envía:
   - `{"t":"state","x","y","r","vx","vy"}` unas 15 veces por segundo (posición, ángulo en radianes y velocidad). Valores no numéricos o fuera de ±100 000 se descartan; más de 40 por segundo, también.
   - `{"t":"cp","i":N}` al pasar por el checkpoint N. El servidor lo valida igual que `LapTracker` (en orden, el 0 es la meta, sin saltarse ni repetir) y descarta los que llegan antes de lo que permite la velocidad máxima (`MAX_SPEED_PX_S`).
4. El **anfitrión** (`host_id`: el humano conectado con el puesto más bajo) simula también a los bots: envía `state` y `cp` con un campo extra `"slot": <puesto del bot>`. Nadie más puede controlar a un bot ni a otro humano. Si el anfitrión se desconecta, llega `{"t":"host","user_id":…}` con el nuevo.
5. El servidor reenvía `{"t":"states","ms","cars":[{s,x,y,r,vx,vy,l,c}]}` (`l` vueltas y `c` último checkpoint, ambos autoritativos) unas 15 veces por segundo. Cada cliente ignora su propio puesto.
6. `{"t":"finish","slot","username","bot","time_ms","position"}` cuando alguien completa las vueltas. **El tiempo lo calcula el servidor**, no el cliente.
7. `{"t":"results","track","results":[{position,slot,user_id,username,bot,finished,time_ms,suspicious}]}`: al terminar todos los humanos conectados, a los 90 s de llegar el primero, o a los 10 min. Quien no termina se ordena por progreso. En ese momento la sala se disuelve y todos pueden buscar otra.

Los resultados se guardan en MariaDB (`races`, `race_results`) y una telemetría de 4 muestras por segundo en MongoDB (`race_telemetry`). Al borrar una cuenta, sus resultados se conservan con el nombre `(cuenta borrada)`.

### Cliente de Godot

- `scripts/online_client.gd` (`OnlineClient`) habla con el servidor: cuenta por HTTP y salas/carreras por WebSocket, con señales para cada mensaje. El autoload `Online` es una instancia, para que la sesión y la conexión sobrevivan a los cambios de escena. Guarda solo el servidor y el último usuario en `user://online.json`; **nunca la contraseña**. El servidor por defecto es `https://miniso.enguillem.es`; se cambia en la pantalla de login o con `-- --server=URL`.
- Escenas: `online_login` (entrar/registrarse), `online_lobby` (salas y sala de espera) y `online_race` (`OnlineRace`, que hereda de `RaceManager`).
- En `OnlineRace` cada cliente simula su coche y los demás son fantasmas (`Car.make_ghost()`) que se interpolan y extrapolan con su velocidad. **No hay choques entre coches online** (cada cliente simularía una colisión distinta); sí con paredes y obstáculos. Barriles y troncos no se sincronizan (cada cliente ve los suyos); los trenes arrancan a la vez en la salida.
- Todos conducen el coche base sin mejoras para que sea justo en el aula (`OnlineRace.use_garage_car` lo cambia). No hay monedas ni premios online.
- Verificación sin pantalla: `tools/online_smoke.gd` corre una carrera completa de 1 a 5 jugadores contra un servidor real (crea las cuentas con el admin y las borra). `tools/online_demo.gd` graba capturas del flujo. Los tests de GUT usan un WebSocket y un HTTP falsos (`tests/fake_online.gd`).

### Notas para quien toque las pistas

- La parrilla de las pistas tiene hoy 4 puestos (`Track.GRID_SLOTS`); online hacen falta 5.
- `docs/online_tracks.json` (generado con `tools/export_online_tracks.gd`) tiene `checkpoints` y `length_px` de cada pista. El servidor lleva una copia en `backend/app/game/tracks.json`: **hay que copiarla cada vez que cambie una pista o su número de checkpoints**.
- Los bots usan el `AIController` ya existente, simulados solo en el cliente anfitrión.
