# Lista para un juego nuevo

## Preguntas al usuario (una vez, antes de crear nada)

1. **Nombre** y **slug** (`Mini Fútbol` → `mini-futbol`).
2. ¿**Proyecto aparte** o modo dentro de otro juego? (Recomendado: aparte.)
3. **Formato:** jugadores por partida y equipos (por ejemplo 2 contra 2 o 3 contra 3), duración, arcade o realista, ¿online desde el primer hito o primero en solitario contra IA?
4. **Dominio** (`*.enguillem.es`) y **puerto** del frontend libre en `75enguiem` (comprobar con `ss -tln`).
5. ¿Reutilizar la **misma cuenta de Gmail** para los correos? (Los usuarios del juego nuevo son otros: otra base de datos.)
6. ¿Se mantiene la política de privacidad tal cual o hay que adaptarla (datos distintos)?

## Pasos

1. `~/code/juego-online-kit/new-game.sh "<Nombre>" <slug> <dominio> <puerto>`.
2. **Limpiar lo de carreras** siguiendo `servidor.md` y `cliente-godot.md`: dejar la infraestructura compilando y las pruebas genéricas en verde mientras se retira lo específico. Hacerlo en commits pequeños.
3. Reescribir `CLAUDE.md`, `docs/GDD.md`, `docs/ARCHITECTURE.md` y `docs/ROADMAP.md` del juego nuevo (partir de los de Mini Bólidos: mismas convenciones y flujo de trabajo, hitos nuevos).
4. **Hitos sugeridos** (adaptar): M0 esqueleto con verificación y GUT; M1 un jugador con buenos controles; M2 reglas de partida y HUD; M3 IA; M4 contenido (mapas, temas); M5 progresión si procede; M6 menús; M7 pulido (arte CC0, audio, efectos); M8 servidor (ya hecho: solo renombrar y desplegar); M9 módulo de partida online en el servidor; M10 cliente online; M11 operación.
5. **Servidor desde el principio** (es barato): `./setup.sh`, pruebas, `./deploy.sh`, SMTP, dominio y descargas funcionando con el juego vacío. Así el despliegue no es una sorpresa al final.
6. **Subred, puerto y nombre de proyecto de compose únicos** (los pone `new-game.sh`; confirmar que no chocan).
7. Cuando el juego sea jugable: exportar (Windows, Linux y, si hay alumnado con Mac, macOS), `publish-download.sh`, probar en un Windows, un Ubuntu y un Mac reales y con más de un jugador.
8. Privacidad: revisar `docs/PRIVACIDAD.md` con el nuevo inventario de datos y volver a dar la información al centro.

## Qué NO hay que rehacer

Cuentas, correo, sesiones, administración, presencia, descargas y su contador, copias de seguridad, limpieza de datos, límites, política de privacidad, panel web, pantallas de login y lobby, guardado, música, pausa, exportación y los scripts de verificación.

## Qué sí es nuevo en cada juego

Reglas, física, controles, IA, mapas, arte y sonido, el módulo `game/` del servidor (`Room`) y el modo de partida online. Lo más delicado suele ser **quién es la autoridad** de lo que todos comparten (ver `servidor.md`).
