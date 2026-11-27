# Infraestructura: visión general

## Los dos repositorios

| Repo | Qué es | Tecnología |
|---|---|---|
| `mini-bolidos-kit` | El juego (cliente de escritorio) | Godot 4.7, GDScript tipado, GUT 9, renderizador de compatibilidad (OpenGL 3.3) |
| `mini-bolidos-server` | Servidor online + web | FastAPI (Python 3.12), React + TypeScript (Vite), MariaDB, MongoDB, Redis, nginx, Docker Compose |

Ambos están etiquetados `infra-v1` (versión congelada para crear proyectos nuevos). El juego nuevo vive en dos repos hermanos (`<slug>-kit` y `<slug>-server`).

## Dónde corre

- **Servidor:** la máquina `75enguiem` (Debian, VM de Proxmox, 8 CPU, ~11 GB de RAM, comparte host con unos 70 contenedores de otros proyectos). Se accede por `ssh 75enguiem`. Carpeta del proyecto: `/home/guillem/code/<slug>-server`.
- **Desarrollo:** el equipo del usuario (CachyOS). Se desarrolla y se prueba en local con Docker y se despliega con `./deploy.sh` (rsync + `docker compose up -d --build`).
- **Publicación:** la gestiona el usuario (dominio `*.enguillem.es`, HTTPS, proxy inverso propio). El servidor solo expone **un puerto** (el del frontend, por ejemplo 8420). El usuario da de alta el dominio con `dnstools.enguillem.es`; el proxy debe enviar `X-Forwarded-For`.
- **Cliente:** ejecutables para Windows (zip) y Linux (tar.gz) que se descargan desde la propia web. El cliente apunta por defecto a `https://<dominio>`.

## Servicios (docker compose, red privada, solo el frontend publica puerto)

```
nginx (frontend + web React, puerto publicado) ──/api, /ws──▶ backend FastAPI (1 proceso)
                                                               ├─ MariaDB 11.4  cuentas, tokens, partidas, resultados, contador de descargas
                                                               ├─ Redis 7       sesiones, presencia, límites de intentos
                                                               └─ MongoDB 4.4   auditoría, telemetría de partidas (con TTL)
```

- Un solo proceso del backend: salas y WebSockets viven en memoria. Si algún día hay que escalar, habrá que mover el estado de salas a Redis.
- MongoDB **4.4** porque la VM no tiene AVX (MongoDB 5+ no arranca). Se cambia con `MONGO_IMAGE` en el `.env`.
- Subred fija por proyecto (`BOLIDOS_SUBNET`, por defecto `10.213.77.0/24`) porque Docker en ese host agotó los rangos automáticos. Cada proyecto nuevo necesita **una subred distinta**.
- Límites de memoria por contenedor (MariaDB 384 MB, Mongo 512 MB, backend 256 MB, Redis 96 MB, nginx 64 MB).

## Funciones ya resueltas

- **Cuentas:** registro con usuario, correo y contraseña (Argon2), correo de activación (Gmail SMTP con contraseña de aplicación), login por usuario o correo, recuperación de contraseña, cambio de contraseña, borrado de la propia cuenta, exportación de los propios datos.
- **Sesiones** revocables en Redis (JWT + sesión); límites de intentos por usuario y por IP; el administrador puede bloquear, expulsar, activar y borrar.
- **Administrador:** cuenta creada o promovida al arrancar desde el `.env`; panel web con conectados ahora, salas, usuarios, descargas y auditoría.
- **Presencia:** WebSocket único por usuario (`/api/ws`), latido cada 15 s; una conexión nueva expulsa a la anterior.
- **Salas y partidas:** vestíbulo, salas, arranque automático al llenarse, anfitrión que simula a los bots, resultados guardados, clasificación (ver `servidor.md`; es lo más específico del juego).
- **Descargas:** página pública con pestañas Windows y Linux, instrucciones, huella SHA-256 y contador por navegador (cookie técnica).
- **Copias de seguridad:** diaria (cron) con rotación y verificación semanal restaurando en bases temporales.
- **Privacidad:** política en la web, aceptación registrada y versionada, bloqueo hasta aceptarla, limpieza periódica de datos, `docs/PRIVACIDAD.md` para el centro.
- **Cliente Godot:** `OnlineClient` + pantallas de login/registro y vestíbulo, música y sonido, menús, pausa, guardado, exportación a Windows y Linux, verificación sin pantalla.

## Seguridad en resumen

- Contraseñas con Argon2; tokens de correo con hash y caducidad; los registros no contienen tokens (`--log-level warning` en uvicorn).
- nginx con CSP, `nosniff`, sin marcos y tope de peticiones por IP; backend y bases de datos sin puertos publicados.
- Los archivos descargables no se sirven directos: pasan por `/api/download/<sistema>` (cuenta y entrega con `X-Accel-Redirect`).
- Las pruebas se niegan a ejecutarse contra una base que no termine en `_test`.
