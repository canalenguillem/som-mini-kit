# Operaciones: despliegue, correo, descargas, copias, límites y privacidad

Todos los comandos se ejecutan en `<slug>-server`, salvo los marcados como "en el servidor".

## Primera puesta en marcha de un proyecto nuevo

1. `./setup.sh` crea `.env` con secretos aleatorios (permisos 600). Revisa `PUBLIC_URL`, `FRONTEND_PORT`, `BOLIDOS_SUBNET` (una subred distinta por proyecto), `MONGO_IMAGE` (4.4 en `75enguiem`) y `PRIVACY_CONTACT`.
2. Local: `docker compose up -d --build` (el `.env` local puede llevar `CREATE_TEST_DB=1` para poder lanzar las pruebas).
3. Servidor: `./deploy.sh` (rsync sin `.env`, `.git`, `node_modules`; después `./setup.sh` allí y `docker compose up -d --build`). Cambia `PUBLIC_URL` del `.env` del servidor a `https://<dominio>` (va en los enlaces de los correos).
4. El administrador se crea al arrancar con `ADMIN_EMAIL`/`ADMIN_PASSWORD` del `.env`. **La contraseña inicial está en el `.env` del servidor**; el usuario la cambia al entrar. No la leas ni la repitas en el chat.
5. Dominio y HTTPS: lo hace el usuario (alta en `dnstools.enguillem.es`, su proxy inverso). Solo hay que dejar abierto el puerto del frontend.

## Correo (Gmail con contraseña de aplicación)

`MAIL_BACKEND=log` escribe los correos (con enlaces) en el log: sirve para probar, nunca en producción. Para enviarlos de verdad el usuario ejecuta en su terminal (funciona en fish y bash, la contraseña no se ve ni pasa por el chat):

```
ssh -t 75enguiem /home/guillem/code/<slug>-server/set-smtp.sh
```

Pide la contraseña de aplicación de 16 letras (cuenta Google → Seguridad → Contraseñas de aplicaciones; requiere la verificación en dos pasos), activa `MAIL_BACKEND=smtp` y reinicia el backend. Si no llegan: mirar spam y `docker compose logs backend | grep -iE "smtp|mail"`.

## Despliegue de cambios

```bash
cd <slug>-server && ./deploy.sh            # backend y web
```
Antes de desplegar una migración: `ssh 75enguiem 'cd …/<slug>-server && ./backup.sh'`. Tras cambiar el backend se cortan los WebSockets abiertos (se reconectan).

## Descargas del juego

```bash
cd <slug>-kit && ./tools/export_linux.sh && ./tools/export_windows.sh && ./tools/export_macos.sh   # genera build/*.tar.gz y build/*.zip y su .json
cd <slug>-server && ./publish-download.sh && ./deploy.sh                  # copia a downloads/ y actualiza manifest.json
```

- Los archivos **no se sirven directos**: el botón de la web llama a `/api/download/<linux|windows|macos>`, que cuenta y responde con `X-Accel-Redirect`; nginx entrega el archivo desde `/downloads-files/` (interno). `/downloads/` devuelve 404 salvo `manifest.json`.
- El contador cuenta **una descarga por navegador y versión cada 10 minutos**, con una cookie técnica aleatoria (`<slug>_cid`, `HttpOnly`, solo para `/api/download`, 90 días); de ella solo se guarda un hash. Así un aula entera con la misma IP cuenta a cada alumno. Los clientes sin cookies (curl) dejan de contar tras 300 por hora y por IP. Las cifras se ven en Administración → Descargas.
- Tras probar en producción, borra tus propias descargas de la tabla `download_events` para que las estadísticas empiecen limpias.

## Copias de seguridad

- `./backup.sh`: volcado de MariaDB (`mariadb-dump --single-transaction`) y de MongoDB (`mongodump --archive`) a `~/backups/<carpeta>/daily/<fecha>/`, con `SHA256SUMS`, permisos 700/600, 14 diarias y 8 semanales (domingos). No copia Redis ni el `.env`.
- `./verify-backup.sh`: restaura la última en bases temporales, cuenta filas y las borra. Cron semanal.
- `./restore.sh <carpeta> --yes-borrar-todo`: **sustituye** los datos actuales.
- `./install-backup-cron.sh` (en el servidor) añade al cron del usuario copia diaria a las 03:30 y verificación el domingo a las 04:00, sin tocar otras líneas. En `75enguiem` ya hay copias de otros proyectos en el cron.
- Las copias están en el mismo equipo. Para copiarlas fuera (por ejemplo al Windows 192.168.1.46, como ya hace otro proyecto), añadir un rsync al cron; las copias contienen correos y hashes y deberían cifrarse si salen.

## Límites pensados para un aula

Un aula entera comparte IP pública, así que los topes por IP son amplios: registros 120/h, correos 60/h, fallos de acceso 80 cada 15 min por IP y **5 por usuario**, 400 WebSockets en total, 120 mensajes/s por conexión, nginx 30 peticiones/s por IP con ráfaga de 120. Todo se ajusta en `config.py` o por variable de entorno.

## Datos que se borran solos

Cuentas sin activar a los 14 días, tokens de correo caducados a los 7 y telemetría de partidas (MongoDB) a los 60 (índice TTL). El administrador puede borrar cuentas desde la web; al terminar el curso conviene borrarlas todas.

## Privacidad

`docs/PRIVACIDAD.md` (inventario, medidas, decisiones para el centro, modelo de nota para familias) y `/privacidad` en la web. Registro con casilla de aceptación (14 años o más, o permiso de la familia) y versión: subir `PRIVACY_VERSION` obliga a todos a aceptar de nuevo. Mientras no acepten, no pueden jugar online (WebSocket cierra con 4007). Menores de 14 años necesitan permiso de la familia: es una decisión del centro, no técnica.

## Puertos y red en `75enguiem`

- Puertos en uso por otros proyectos: 80, 3000, 3306, 6379, 5180, 5185, 8000, 8001, 8002, 8081, 8094, 8095, 8180, 8765… Comprueba antes con `ss -tln`. En 8420 está Mini Bólidos; elige otro para cada juego (8430, 8440…).
- Docker agotó los rangos automáticos: cada compose fija su subred (`10.213.<n>.0/24`).
- Hay un MongoDB de otro proyecto (`mongodb-correos`) publicado en `0.0.0.0:27017`: no es nuestro, pero conviene avisar al usuario.

## Comandos útiles

```bash
ssh 75enguiem 'cd …/<slug>-server && docker compose ps'
ssh 75enguiem 'cd …/<slug>-server && docker compose logs --no-color --tail 50 backend'
ssh 75enguiem 'cd …/<slug>-server && docker compose exec -T backend alembic current'
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm --build backend      # pruebas (local)
```
Para consultar la base sin mostrar secretos, ejecuta Python dentro del contenedor del backend (usa las variables de entorno del contenedor) y borra lo que crees solo para probar.
