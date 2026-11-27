# GDD — Mini SO

## Concepto

Carreras arcade de coches en miniatura con vista cenital. Partidas cortas (2-3 min por carrera), control inmediato y circuitos temáticos con personalidad. Ganas dinero en las carreras y lo gastas en el garaje para mejorar el coche, lo que te permite ganar en circuitos más difíciles.

Referencias: *Micro Machines V3* (escenarios, cámara, caos) y *Mini Motor Racing* (garaje, mejoras, progresión por campeonatos).

## Pilares

1. **Se controla bien en 10 segundos.** Acelerar, girar y derrapar se sienten bien desde el primer momento.
2. **Cada tema se juega distinto.** El Oeste no es la Jungla con otra textura: cambian las superficies, los obstáculos y el trazado.
3. **Progresión visible.** Cada mejora comprada se nota en la siguiente carrera.

## Bucle principal

```
Elegir carrera → Correr (3 vueltas, 4 coches) → Premio en monedas → Garaje: mejorar → Siguiente carrera
```

## Modos

| Modo | Hito | Descripción |
|---|---|---|
| Carrera rápida | M3 | Cualquier pista desbloqueada, sin premio |
| Campeonato | M6 | 4 pistas seguidas (v1: la "Copa Salvaje" con las 2 del Oeste y las 2 de la Jungla, porque hay 2 pistas por tema), puntos 10/6/3/1, premio final 2000/1200/600/200 por puesto. Sus pistas se juegan aunque no estén desbloqueadas |
| Contrarreloj | Opcional | Solo, con fantasma de la mejor vuelta |
| Multijugador local | Opcional | 2 jugadores en pantalla compartida (teclado + mando) |
| Online | M8-M10 | Carreras de 5 jugadores reales en un servidor propio, con cuentas. Ver `docs/ONLINE.md` |

## Reglas de carrera

- 4 coches: jugador + 3 IA.
- 3 vueltas por defecto (configurable en `TrackData`).
- Cuenta atrás de 3 s; arrancar antes de tiempo no penaliza (versión 1).
- Las vueltas se validan con checkpoints en orden: no hay atajos que salten checkpoints.
- Si un coche se queda atascado o se sale del mapa, reaparece en el último checkpoint tras 3 s (o al pulsar `reset`).
- Premios: 1º 500, 2º 300, 3º 150, 4º 50 monedas, multiplicados por `TrackData.reward_mult`.

## Coches

Versión 1 con 3 coches. Se compran en el garaje.

| Coche | Precio | Vel. máx | Aceleración | Agarre | Carácter |
|---|---|---|---|---|---|
| Escarabajo | 0 (inicial) | media | media | alto | Fácil y perdona |
| Buggy | 1500 | baja | alta | medio | Muy bueno en tierra y barro (`base_offroad` 0.6: anula el 60 % de la penalización de superficie) |
| Deportivo | 4000 | alta | media | bajo | Rápido pero derrapa |

## Mejoras

Cada coche tiene sus propios niveles de mejora, del 0 al 5. El coste crece: `coste_base × 1.6^nivel`.

| Mejora | Afecta a | +por nivel | Coste base |
|---|---|---|---|
| Motor | velocidad máxima | +6 % | 200 |
| Turbo | aceleración | +8 % | 150 |
| Neumáticos | agarre | +7 % | 150 |
| Nitro | capacidad de nitro | +1 carga (base 1) | 250 |

## Superficies

Se definen en `data/surfaces/*.tres`. Los multiplicadores se aplican a los stats del coche.

| Superficie | Agarre | Vel. máx | Fricción | Dónde aparece |
|---|---|---|---|---|
| asfalto | 1.0 | 1.0 | 1.0 | Ciudad |
| tierra | 0.75 | 0.95 | 1.1 | Oeste |
| arena | 0.6 | 0.8 | 1.6 | Oeste, Playa |
| barro | 0.5 | 0.7 | 2.0 | Jungla |
| hierba | 0.7 | 0.85 | 1.4 | Jungla, bordes |
| hielo | 0.25 | 1.0 | 0.8 | Ártico |
| agua poco profunda | 0.6 | 0.6 | 2.5 | Jungla (vados) |

## Temas y circuitos

| Tema | Superficies | Obstáculos / elementos | Pistas v1 |
|---|---|---|---|
| **Oeste** | tierra, arena | barriles que se mueven, vías de tren con un tren que cruza cada X s, cactus (pared), saltos en rampa | 2 |
| **Jungla** | barro, hierba, agua | troncos caídos, vados de río, puente estrecho, lianas (decoración) | 2 |
| Ártico | hielo, nieve | bloques de hielo, curvas cerradas sobre hielo | Opcional |
| Mesa de billar (homenaje) | tapete = asfalto con agarre alto | bolas físicas que empujan, troneras = caída y reaparición | Opcional |

## Cámara

- Sigue al jugador con suavizado (`position_smoothing`) y un pequeño adelanto en la dirección de la velocidad.
- Zoom dinámico: se aleja un poco a alta velocidad.
- Sin rotación: el mundo no gira, el coche sí.

## Controles

| Acción | Teclado | Mando | Táctil (M7) |
|---|---|---|---|
| Acelerar | ↑ / W | RT / A | botón derecho |
| Frenar / marcha atrás | ↓ / S | LT / B | botón derecho inferior |
| Girar | ← → / A D | stick izq. | flechas a la izquierda |
| Nitro | Espacio | X | botón |
| Reaparecer | R | Y | — |
| Pausa | Esc | Start | botón ⏸ |

## Fuera de alcance (v1)

Editor de pistas, armas o power-ups de combate, físicas 3D.

## Arte y audio

- Prototipo: formas simples (`Polygon2D`) y colores planos.
- Después: packs CC0 (por ejemplo, Kenney *Racing Pack*), descargados por el humano a `assets/`.
- Audio: motor con el pitch ligado a la velocidad, derrape, choque, nitro, cuenta atrás y una música por tema.
