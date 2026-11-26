# v0.7 — Árbol de reliquias y logros: simulación

Estado al 2026-11-26 (segunda vuelta). **Nada de esto está en el juego**: es la simulación y espera aprobación. Rama `v07-arbol`.
Especificación de partida: [arbol-reliquias.md](arbol-reliquias.md) (todavía sin actualizar con estos cambios).

## Cómo retomar
- Archivos: `tools/simulate_tree.gd` (simulador), `tools/tree_sim/economy_tree.gd` (el Economy real con los efectos del árbol encima), `tools/tree_sim/arbol_v2.json` (propuesta: todos los números), `logros.json`.
- Correr con el Godot de consola (ruta en `tools/run_tests.ps1`); cada campaña tarda ~2 min y se pueden lanzar en paralelo:
  - `godot --headless --path . --script res://tools/simulate_tree.gd -- campaign res://tools/tree_sim/arbol_v2.json 3 1` (golpes/s y semilla; con `oraculo` al final anota hasta dónde se llega en 10 min al empezar cada bajada)
  - `... -- descents res://tools/tree_sim/arbol_v2.json 7` (primeras 8 bajadas contra las reglas de hoy)
  - `... -- stars res://tools/tree_sim/arbol_v2.json 5 <parte> <partes>` (qué cambia cada estrella)
- Jugador simulado: golpea sin pausas, compra casi óptimo, usa la dinamita, entra una vez por día 60 min (23 h fuera), vuelve a la superficie cuando las reliquias por minuto dejan de mejorar y compra siempre la estrella más barata. Es optimista.

## Tus seis pedidos
| Pedido | Qué quedó | Resultado simulado |
|---|---|---|
| 1. Primer reset: Corazón y 1–2 estrellas | Estrellas del anillo 1 desde 2 reliquias y **20 fragmentos = 1 reliquia** (eran 10) | 5–6 reliquias: Corazón + 1 o 2 estrellas. **Cumple** |
| 2. Ninguna bajada de menos de ~10 min a 3 golpes/s | La meta baja según las reliquias ganadas (tabla) y **más hondo paga más** | 95% de las bajadas sobre 10:15; mediana 12:11–12:48; en tres partidas, 4 de ~200 bajo 10 min (mínima 8:44). **Cumple** |
| 3. Capataz y Mina sola; activo mejor; AFK alto | Capataz +5% por nivel; Mina sola pasa a **A la par**; AFK base de 25% a **5%** | 8 h fuera pasan de ~65 min de juego activo a ~14 (sin árbol). **Cumple** |
| 4. Que Fortuna se note | Números más altos; el peso extra de las rarezas sale de los Comunes | Anillo 1: +9 a +17% (antes 0 a +5%). **Cumple**, salvo Corona y Reliquia escondida, que dan reliquias y no velocidad |
| 5. Cuenta regresiva | Sin cambios | Aprobada |
| 6. Repetir a 1,5, 3 y 5 golpes/s | Hecho, 3 semillas cada uno | Ver Resultados |

## Decisiones ya tomadas
1. Las reliquias **dejan de dar +25% de oro**: son solo la moneda del árbol.
2. Bonus pasivo chico por **reliquias ganadas en toda la historia**, para que gastar nunca debilite.
3. Testers: conservan sus reliquias para gastarlas, cuentan para el bonus histórico y un cartel se los avisa la primera vez.
4. La meta de volver se corre y se ve en el juego: **"Próximo regreso a X m"**.
5. "Planos viejos" pasa a ser **"Bolsa inicial"**.
6. **Cuenta regresiva ★** en lugar de "Reloj de arena" (aprobada).
7. Ninguna bajada menos de ~10 min a 3 golpes/s. Esto **reemplaza** la condición anterior ("las siguientes al menos tan cortas como hoy").
8. El jugador activo tiene que ser el más beneficiado.

## La propuesta (falta tu OK)
### Meta de volver a la superficie
Depende de las reliquias **sacadas de bajadas** (las de cofres y logros no la corren). Se fija al empezar cada bajada y comprar estrellas no la mueve. Es una tabla en `data/`, lineal entre puntos:

| Reliquias de bajadas | 0–5 | 9 | 12 | 20 | 40 | 65 | 100 | 180 | 300 | 500 | 700 | 1000 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Meta (m) | 300 | 314 | 325 | 346 | 394 | 430 | 449 | 480 | 497 | 522 | 552 | 583 |

- **Más hondo paga más:** la fórmula de reliquias de hoy, medida desde la meta, más 1 reliquia por cada 30 m que se corrió. Se ganan ~3 por bajada al principio y más de 10 al final.
- Por qué una tabla y no una fórmula: probé metros fijos por reliquia (se queda corta enseguida) y un logaritmo (las bajadas 2.ª–8.ª quedaban o en 14–18 min o en 8 min). El jugador se hace fuerte de golpe, después de a poco, y se estanca juntando para las piedras angulares.
- La partida completa termina cerca de 560–580 m. Más allá de 400 m todo es Abismo: **los mapas nuevos quedan para más adelante**.

### AFK
| | Hoy | Propuesta |
|---|---|---|
| Eficiencia base | 25% | 5% |
| Vigilia (3 niveles) | — | 7 / 9 / 12% |
| Tope (Turno noche, 2 niveles) | 8 h | 8 h; con la estrella 10 / 12 h |
| Turnos rotativos (puente) | — | +50% |

Los primeros 2 min siguen pagando completo. Solo con el árbol entero se vuelve cerca de lo que hoy paga una noche. En toda una campaña a 3 golpes/s el AFK es el 7–9% del oro.

### Cambios de estrellas
- **A la par ★** (reemplaza a Mina sola): la cuadrilla rinde ×1,3 mientras golpeás y ×0,7 si no (también AFK). Acorta ~25% jugando a cualquier ritmo; quien deja el juego solo, pierde.
- **Capataz:** +5% por nivel (era +20% y acortaba 45%; ahora 19%).
- **Fortuna:** Olfato +20%, Botín generoso +25%, Gemólogo +50% de Raros, Corazón de dragón +80% de Épicos, Doble cofre +12%, Corona +100% de Legendarios, Mineros con suerte +100%. Los Raros, Épicos y Legendarios extra salen de los Comunes (antes, subir los Raros bajaba los Legendarios y con ellos las reliquias).
- **Pólvora:** +20% por nivel (era +25%).

### Costos y anillos
- Anillo 1: 2, 2, 3, 3, 3. Anillos 2 y 3: crecimiento ×1,4. Piedras angulares: 40. Puentes: 50. **Árbol completo = 918 reliquias** (anillo 1: 151 · anillo 2: 216 · anillo 3: 350 · puentes: 200).
- Requisitos sin cambios: anillo 2 = 350 m y 8 resets; anillo 3 = 400 m y 25 resets.
- Bonus histórico (+6% por reliquia hasta 60, después +0,5%) y Corazón (+50%) sin cambios.

★ = piedra angular (máximo 2 activas).

| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total |
|---|---|---|---|---|---|
| core | Corazón del pozo | +50% de oro | 0 | 1 | 1 |
| f_brazo | Brazo fuerte | cada golpe suma +1,2% del oro/s | 1 | 2, 2, 3, 3, 3 | 13 |
| f_templado | Pico templado | +30% de golpe | 1 | 2, 2, 3, 3, 3 | 13 |
| f_ojo | Ojo certero | +3% de crítico | 1 | 2, 2, 3, 3, 3 | 13 |
| f_brutal | Golpe brutal | +0,6× de daño crítico | 2 | 4, 6, 8, 11, 15 | 44 |
| f_eco | Eco | +12% de golpe doble | 2 | 6, 8, 12 | 26 |
| f_combo | Combo | en frenesí, +30% de golpe | 3 | 10, 14, 20 | 44 |
| f_umbral | Mano rápida | frenesí con 1 golpe/s menos | 3 | 20 | 20 |
| f_furia | Furia ciega ★ | críticos ×4, mitad de chance | 3 | 40 | 40 |
| o_olfato | Olfato | +20% de chance de cofre | 1 | 2, 2, 3, 3, 3 | 13 |
| o_botin | Botín generoso | +25% de oro por cofre | 1 | 2, 2, 3, 3, 3 | 13 |
| o_gemologo | Gemólogo | +50% de Raros (salen de los Comunes) | 1 | 2, 2, 3 | 7 |
| o_dragon | Corazón de dragón | +80% de Épicos (salen de los Comunes) | 2 | 6, 8, 12 | 26 |
| o_doble | Doble cofre | +12% de cofre doble | 2 | 6, 8, 12 | 26 |
| o_corona | Corona | +100% de Legendarios | 3 | 15, 21 | 36 |
| o_reliquia | Reliquia escondida | el Legendario da +1 reliquia | 3 | 30 | 30 |
| o_apostador | Apostador ★ | sin Comunes; el resto sale ×2 | 3 | 40 | 40 |
| c_reclutas | Reclutas | empezás con +5 mineros | 1 | 2, 2, 3, 3, 3 | 13 |
| c_capataz | Capataz | +5% de cuadrilla (antes +20%) | 1 | 2, 2, 3, 3, 3 | 13 |
| c_contrato | Contrato barato | −4% de costo de generadores | 1 | 2, 2, 3, 3, 3 | 13 |
| c_bolsa | Bolsa inicial | empezás con 500 / 5.000 / 50.000 de oro | 1 | 2, 2, 3 | 7 |
| c_ventaja | Ventaja inicial | empezás con 1 Taladro / Topo / Gólem | 2 | 8, 11, 16 | 35 |
| c_hitos | Hitos dorados | hitos ×2,5 | 2 | 25 | 25 |
| c_memoria | Memoria | conservás el Pico | 3 | 30 | 30 |
| c_mina | A la par ★ | cuadrilla ×1,3 mientras golpeás, ×0,7 si no | 3 | 40 | 40 |
| t_mecha | Mecha corta | −8% de recarga de dinamita | 1 | 2, 2, 3, 3, 3 | 13 |
| t_polvora | Pólvora | +20% de dinamita | 1 | 2, 2, 3, 3, 3 | 13 |
| t_vigilia | Vigilia | AFK 7 / 9 / 12% (base 5%) | 1 | 2, 2, 3 | 7 |
| t_noche | Turno noche | tope AFK 10 / 12 h (base 8) | 2 | 8, 11 | 19 |
| t_descenso | Descenso rápido | hasta 200 m, oro ×3 | 2 | 15 | 15 |
| t_memoria_din | Mecha guardada | conservás la Dinamita | 3 | 30 | 30 |
| t_cuenta | Cuenta regresiva ★ | dinamita recarga en la mitad, paga 25% menos | 3 | 40 | 40 |
| p_suerte | Golpe de suerte | 3% de cofre por crítico | 4 | 50 | 50 |
| p_mineros | Mineros con suerte | +100% de cofres de la cuadrilla | 4 | 50 | 50 |
| p_turnos | Turnos rotativos | +50% de producción AFK | 4 | 50 | 50 |
| p_critica | Dinamita crítica | la dinamita puede hacer crítico | 4 | 50 | 50 |

## Resultados
### Las primeras 8 bajadas, una atrás de otra
Volviendo apenas se puede, sin ausencias (mediana de 7).

| Golpes/s | Reglas | 1.ª | 2.ª | 3.ª | 4.ª | 5.ª | 6.ª | 7.ª | 8.ª |
|---|---|---|---|---|---|---|---|---|---|
| 3 | hoy | 28:15 | 18:06 | 12:36 | 10:34 | 8:53 | 7:10 | 6:41 | 6:13 |
| 3 | árbol | 28:15 | 16:12 | 14:41 | 13:22 | 11:54 | 12:33 | 12:33 | 12:05 |
| 3 | árbol y logros | 27:13 | 14:21 | 13:06 | 11:04 | 11:18 | 10:03 | 11:02 | 10:21 |
| 1,5 | hoy | 30:52 | 20:08 | 15:05 | 12:38 | 9:44 | 8:19 | 7:54 | 6:49 |
| 1,5 | árbol | 30:52 | 17:31 | 16:14 | 15:51 | 14:24 | 14:35 | 13:26 | 14:54 |
| 1,5 | árbol y logros | 30:02 | 15:58 | 14:56 | 14:10 | 13:30 | 13:27 | 13:53 | 12:08 |
| 5 | hoy | 24:59 | 15:49 | 11:51 | 9:13 | 8:07 | 7:01 | 5:37 | 5:12 |
| 5 | árbol | 24:59 | 14:15 | 13:11 | 10:52 | 10:24 | 10:21 | 10:41 | 11:00 |
| 5 | árbol y logros | 23:48 | 13:05 | 10:14 | 9:20 | 9:13 | 9:07 | 9:16 | 8:56 |

### Partidas completas
1 h por día hasta completar el árbol; rangos de 3 semillas. "Se puede volver" es el momento en que se llega a la meta (lo que tardaría quien vuelve apenas puede); el jugador simulado se queda un rato más. Se excluyen las bajadas con una ausencia en el medio, que el AFK adelanta.

| | 1,5 golpes/s | 3 golpes/s | 5 golpes/s |
|---|---|---|---|
| Primer reset | 49–52 min | 44–49 min | 37–43 min |
| Se puede volver: mínimo | 10:27–11:47 | 8:44–10:10 | 6:31–7:26 |
| Se puede volver: 5% más rápido | 11:52–12:13 | 10:16–10:19 | 7:18–7:46 |
| Se puede volver: mediana | 16:18–16:56 | 12:11–12:48 | 9:04–9:40 |
| Bajada completa: mediana | 23:26–23:44 | 17:28–18:22 | 13:14–14:02 |
| Bajadas bajo 10 min | 0% | 0–4% | 60–77% |
| Anillo 1 completo | día 9 | día 8 | día 6–7 |
| Anillo 2 completo | día 22–23 | día 18–19 | día 14–15 |
| Primera piedra angular | día 27–28 | día 22–23 | día 17–18 |
| Primer puente | día 32–34 | día 26 | día 19–21 |
| **Árbol completo** | **día 35–37** | **día 28–29** | **día 21–23** |
| Oro: golpes / cofres / dinamita / AFK | 11–12 / 43–48 / 23–24 / 7–14% | 27–29 / 41–43 / 16–17 / 7–9% | 37 / 41 / 12 / 4–5% |

El resto del oro es la cuadrilla mientras jugás (5–9%).

### Día por día (3 golpes/s, semilla 1)
```
día | reliquias ganadas (gastadas) | estrellas | niveles | resets | se puede volver a los (mín/mediana) | bajada completa (mediana) | récord | meta | logros (frag.)
  primer reset a los 46:02: 6 reliquias (con fragmentos) → encendió core, f_brazo, sobran 1
  1 |     6 (5) |  2 |   3 |   1 | 27:58 / 27:58 |  46:02 | 341 m | 300 m | 20 (55)
  2 |    17 (17) |  5 |   9 |   4 | 10:10 / 11:24 |  20:04 | 360 m | 328 m | 25 (77)
  3 |    32 (31) |  9 |  16 |   7 | 10:37 / 11:02 |  20:16 | 386 m | 358 m | 31 (106)
  4 |    54 (53) | 14 |  27 |  11 | 10:16 / 11:26 |  16:12 | 417 m | 403 m | 35 (133)
  5 |    82 (80) | 14 |  36 |  15 | 10:58 / 12:46 |  18:02 | 451 m | 434 m | 39 (160)
  6 |   103 (101) | 14 |  43 |  18 | 11:27 / 12:35 |  17:46 | 463 m | 445 m | 40 (185)
  7 |   133 (131) | 14 |  53 |  22 | 11:29 / 13:08 |  18:30 | 483 m | 458 m | 41 (195)
  8 |   166 (162) | 15 |  62 |  26 | 10:49 / 11:46 |  16:42 | 483 m | 470 m | 44 (215)
  9 |   188 (188) | 18 |  66 |  29 | 11:30 / 12:39 |  17:52 | 491 m | 478 m | 45 (225)
 10 |   227 (220) | 19 |  70 |  33 | 13:21 / 13:28 |  18:56 | 507 m | 484 m | 49 (280)
 11 |   252 (249) | 21 |  73 |  36 | 13:48 / 14:22 |  20:12 | 507 m | 488 m | 49 (280)
 12 |   277 (271) | 21 |  75 |  39 | 12:12 / 14:05 |  19:48 | 507 m | 491 m | 49 (280)
 13 |   304 (295) | 21 |  77 |  42 | 14:21 / 14:55 |  20:56 | 521 m | 495 m | 51 (295)
 14 |   330 (321) | 21 |  79 |  45 | 14:07 / 15:04 |  21:06 | 523 m | 498 m | 51 (295)
 15 |   356 (351) | 22 |  81 |  48 | 13:29 / 14:56 |  20:56 | 525 m | 501 m | 53 (310)
 16 |   387 (382) | 23 |  83 |  51 | 15:14 / 15:38 |  21:52 | 526 m | 505 m | 54 (320)
 17 |   414 (402) | 23 |  84 |  54 | 16:00 / 16:09 |  22:36 | 527 m | 508 m | 54 (320)
 18 |   449 (443) | 24 |  86 |  58 | 12:23 / 13:29 |  19:00 | 527 m | 512 m | 54 (320)
 19 |   478 (468) | 25 |  87 |  61 | 12:26 / 13:18 |  18:44 | 527 m | 515 m | 55 (330)
 20 |   519 (498) | 26 |  88 |  65 | 10:44 / 12:46 |  18:00 | 532 m | 520 m | 56 (355)
 21 |   550 (528) | 27 |  89 |  68 | 13:22 / 14:13 |  19:58 | 533 m | 524 m | 56 (355)
 22 |   581 (558) | 28 |  90 |  71 | 13:54 / 14:00 |  19:40 | 537 m | 528 m | 56 (355)
 23 |   647 (638) | 30 |  92 |  75 | 10:14 / 12:24 |  17:30 | 550 m | 533 m | 60 (410)
 24 |   701 (678) | 31 |  93 |  79 | 11:15 / 12:06 |  17:06 | 552 m | 539 m | 60 (410)
 25 |   760 (718) | 32 |  94 |  83 | 10:43 / 10:58 |  15:34 | 556 m | 544 m | 62 (445)
 26 |   806 (768) | 33 |  95 |  86 | 10:13 / 12:05 |  17:06 | 561 m | 549 m | 64 (480)
 27 |   866 (818) | 34 |  96 |  90 | 10:50 / 10:52 |  15:26 | 568 m | 554 m | 64 (480)
 28 |   926 (918) | 36 |  98 |  94 | 10:40 / 11:20 |  16:04 | 572 m | 558 m | 65 (505)
```

### Estrella por estrella
Cuánto acorta una bajada pasar la estrella de 0 al máximo, con las demás de su anillo y anteriores al máximo (sin piedras angulares). La meta de cada fila es adonde se llega en 12 min sin la estrella; promedio de 5 semillas. La última columna son valores promedio, sin azar, medidos a los 10 min de bajada (3 golpes/s): lo que la prueba de tiempo no ve (cofres, reliquias, AFK en minutos de juego activo, segunda bajada).

| Estrella | Anillo | Costo | 3 g/s | 1,5 g/s | 5 g/s | Qué más cambia |
|---|---|---|---|---|---|---|
| Corazón del pozo | 0 | 1 | +31% | +35% | +35% | 2 h fuera = 4:12 → 6:18 min de juego · 8 h fuera = 13:47 → 20:40 min de juego · 23 h fuera = 13:47 → 20:40 min de juego |
| Brazo fuerte | 1 | 13 | +11% | +6% | +15% | cofres 28.6% → 26.1% del ingreso |
| Pico templado | 1 | 13 | +12% | +8% | +17% | cofres 29.2% → 26.1% del ingreso |
| Ojo certero | 1 | 13 | +4% | +3% | +4% | cofres 26.6% → 26.1% del ingreso |
| Golpe brutal | 2 | 44 | +13% | +8% | +14% | cofres 37.4% → 33.8% del ingreso |
| Eco | 2 | 26 | +9% | +12% | +4% | cofres 36.4% → 33.8% del ingreso |
| Combo | 3 | 44 | +22% | +0% | +24% | cofres 35.9% → 29.2% del ingreso |
| Mano rápida | 3 | 20 | +22% | +0% | +0% | cofres 35.9% → 29.2% del ingreso |
| Furia ciega ★ | 3 | 40 | +23% | +13% | +26% | cofres 29.2% → 23.2% del ingreso |
| Olfato | 1 | 13 | +15% | +15% | +14% | cofres 15.0% → 26.1% del ingreso · 14.4 → 28.8 cofres cada 10 min · reliquias de cofres/h 0.4 → 0.9 |
| Botín generoso | 1 | 13 | +17% | +15% | +16% | cofres 13.5% → 26.1% del ingreso |
| Gemólogo | 1 | 7 | +9% | +6% | +9% | cofres 20.7% → 26.1% del ingreso |
| Corazón de dragón | 2 | 26 | +10% | +9% | +5% | cofres 26.8% → 33.8% del ingreso |
| Doble cofre | 2 | 26 | +9% | +9% | +3% | cofres 27.3% → 33.8% del ingreso · reliquias de cofres/h 0.9 → 1.2 |
| Corona | 3 | 36 | +4% | +2% | +2% | cofres 27.4% → 29.2% del ingreso · reliquias de cofres/h 2.4 → 7.1 |
| Reliquia escondida | 3 | 30 | +0% | +0% | +0% | reliquias de cofres/h 3.5 → 7.1 |
| Apostador ★ | 3 | 40 | +21% | +27% | +25% | cofres 29.2% → 42.9% del ingreso · 28.8 → 34.2 cofres cada 10 min · reliquias de cofres/h 7.1 → 14.1 |
| Reclutas | 1 | 13 | -0% | -2% | -1% |  |
| Capataz | 1 | 13 | +19% | +17% | +19% | 8 h fuera = 9:56 → 12:26 min de juego · 23 h fuera = 9:56 → 12:26 min de juego |
| Contrato barato | 1 | 13 | +10% | +9% | +9% |  |
| Bolsa inicial | 1 | 7 | +1% | +1% | +1% |  |
| Ventaja inicial | 2 | 35 | +1% | +1% | +0% |  |
| Hitos dorados | 2 | 25 | +21% | +18% | +18% | 2 h fuera = 1:48 → 2:19 min de juego · 8 h fuera = 6:35 → 8:29 min de juego · 23 h fuera = 9:47 → 12:36 min de juego |
| Memoria | 3 | 30 | +0% | +0% | +0% | 2.ª bajada seguida 11:28 → 11:23 (+1%) |
| A la par ★ | 3 | 40 | +25% | +26% | +25% | 2 h fuera = 1:25 → 0:59 min de juego · 8 h fuera = 5:12 → 3:38 min de juego · 23 h fuera = 7:43 → 5:24 min de juego |
| Mecha corta | 1 | 13 | +11% | +12% | +7% | cofres 30.2% → 26.1% del ingreso |
| Pólvora | 1 | 13 | +15% | +17% | +11% | cofres 33.1% → 26.8% del ingreso |
| Vigilia | 1 | 7 | +0% | +0% | +0% | 2 h fuera = 1:17 → 2:38 min de juego · 8 h fuera = 4:13 → 9:40 min de juego · 23 h fuera = 4:13 → 9:40 min de juego |
| Turno noche | 2 | 19 | +0% | +0% | +0% | 23 h fuera = 6:35 → 9:47 min de juego |
| Descenso rápido | 2 | 15 | +1% | +1% | +0% |  |
| Mecha guardada | 3 | 30 | +0% | +0% | +0% | 2.ª bajada seguida 11:43 → 11:23 (+3%) |
| Cuenta regresiva ★ | 3 | 40 | +5% | +8% | +3% | cofres 29.2% → 27.8% del ingreso |
| Golpe de suerte | 4 | 50 | +9% | +12% | +18% | cofres 29.2% → 37.1% del ingreso · 28.8 → 41.2 cofres cada 10 min · reliquias de cofres/h 7.1 → 10.1 |
| Mineros con suerte | 4 | 50 | +25% | +27% | +11% | cofres 29.2% → 40.2% del ingreso · 28.8 → 46.8 cofres cada 10 min · reliquias de cofres/h 7.1 → 11.5 |
| Turnos rotativos | 4 | 50 | +0% | +0% | +0% | 2 h fuera = 1:25 → 2:07 min de juego · 8 h fuera = 5:12 → 7:48 min de juego · 23 h fuera = 7:43 → 11:35 min de juego |
| Dinamita crítica | 4 | 50 | +19% | +22% | +15% |  |

Lectura:
- Los porcentajes tienen unos ±3 puntos de ruido.
- **Combo** y **Mano rápida** no hacen nada por debajo del ritmo de frenesí (y Mano rápida tampoco por encima): es lo esperado de estrellas de frenesí, pero quien golpea a 1,5/s no las nota.
- **Corona** y **Reliquia escondida** casi no aceleran; triplican y duplican las reliquias de cofres por hora.
- **Cuenta regresiva** es la piedra angular más floja (3–8% contra 13–27% de las otras). Quedó como la aprobaste.

## Para decidir antes de programar
1. **Estrellas que no se notan** (incumple "ninguna estrella inútil"): Reclutas, Bolsa inicial, Ventaja inicial, Descenso rápido, Memoria y Mecha guardada acortan 0–3%. Con metas tan hondas, lo que pasa al arrancar ya no pesa. Propuesta, sin simular: que escalen con la bajada (por ejemplo "Descenso rápido: oro ×3 hasta 100 m antes de la meta", "Ventaja inicial: empezás con una parte de la cuadrilla anterior").
2. **Los cofres pasan a ser la fuente principal de oro** (41–43% a 3 golpes/s; hoy ~13%). Es la consecuencia de que Fortuna se note. Si es demasiado, bajo Fortuna y vuelvo a calibrar la meta.
3. **A 5 golpes/s el piso no se cumple** (mediana 9:04–9:40, mínima 6:31). Lo dejé así porque el activo tiene que salir ganando; correr la meta ~10 m más lo arreglaría, y a 1,5 golpes/s las bajadas pasarían de ~16 a ~19 min.
4. **La 3.ª y la 4.ª bajada** son más largas que hoy: sin contar logros, 14:41 y 13:22 contra 12:36 y 10:34; con logros, medio minuto más.
5. **A mitad de campaña** (días 13–17) la bajada sube a 14–16 min mientras se junta para el anillo 3.
6. **Logros:** con 20 fragmentos por reliquia dan 31 reliquias (antes 63). "Mil escaleras" (150 resets) y "Museo ambulante" (20 reliquias en una bajada) no salen antes de completar el árbol: habría que bajarlos (por ejemplo a 90 resets y 14 reliquias).
7. **El AFK al 5% cambia el balance base** (`data/balance.json`): también lo sienten quienes todavía no compraron nada.

## Logros propuestos
70 logros, 630 fragmentos = **31 reliquias** en total (20 fragmentos = 1 reliquia). Fácil 2, medio 5, difícil 10, épico 25.

| Categoría | Logro | Cómo | Dificultad | Frag. |
|---|---|---|---|---|
| Golpes | Primeras astillas | 100 golpes | fácil | 2 |
| Golpes | Muñeca firme | 1.000 golpes | fácil | 2 |
| Golpes | Rompepiedras | 10.000 golpes | medio | 5 |
| Golpes | Brazo de hierro | 100.000 golpes | difícil | 10 |
| Golpes | La roca te teme | 300.000 golpes | épico | 25 |
| Golpes | Buen ojo | 100 críticos | fácil | 2 |
| Golpes | Donde duele | 1.000 críticos | medio | 5 |
| Golpes | Cirujano de piedra | 10.000 críticos | difícil | 10 |
| Profundidad | Bajo la tierra | Llegá a Roca | fácil | 2 |
| Profundidad | Brillo propio | Llegá a Cristal | fácil | 2 |
| Profundidad | Hace calor | Llegá a Magma | medio | 5 |
| Profundidad | Mirar al Abismo | Llegá al Abismo | difícil | 10 |
| Profundidad | Sin fondo | 450 m | difícil | 10 |
| Profundidad | Medio kilómetro | 500 m | difícil | 10 |
| Profundidad | Donde no llega el eco | 550 m | épico | 25 |
| Profundidad | El corazón del mundo | 600 m | épico | 25 |
| Cofres | ¿Qué habrá adentro? | Primer cofre | fácil | 2 |
| Cofres | Algo azul | Primer cofre Raro | fácil | 2 |
| Cofres | Esto promete | Primer cofre Épico | fácil | 2 |
| Cofres | ¡Legendario! | Primer cofre Legendario | medio | 5 |
| Cofres | Coleccionista | 100 cofres | medio | 5 |
| Cofres | Buscatesoros | 1.000 cofres | difícil | 10 |
| Cofres | Rey del botín | 5.000 cofres | épico | 25 |
| Cofres | Racha dorada | 5 Legendarios | medio | 5 |
| Cofres | Cueva del dragón | 25 Legendarios | difícil | 10 |
| Cofres | Leyenda viva | 100 Legendarios | épico | 25 |
| Cuadrilla | Primer turno | 25 Mineros | fácil | 2 |
| Cuadrilla | Sindicato | 50 Mineros | medio | 5 |
| Cuadrilla | Pueblo minero | 100 Mineros | difícil | 10 |
| Cuadrilla | A toda presión | 25 Taladros | fácil | 2 |
| Cuadrilla | Nube de vapor | 50 Taladros | medio | 5 |
| Cuadrilla | Revolución industrial | 100 Taladros | difícil | 10 |
| Cuadrilla | Madriguera | 25 Topos | fácil | 2 |
| Cuadrilla | Colonia | 50 Topos | medio | 5 |
| Cuadrilla | Queso suizo | 100 Topos | épico | 25 |
| Cuadrilla | Guardia de piedra | 25 Gólems | medio | 5 |
| Cuadrilla | Ejército de roca | 50 Gólems | difícil | 10 |
| Cuadrilla | Runas encendidas | 25 Excavadoras | difícil | 10 |
| Cuadrilla | Círculo mayor | 50 Excavadoras | épico | 25 |
| Cuadrilla | Despertaste algo | Primer Gusano | difícil | 10 |
| Cuadrilla | Nido del Abismo | 25 Gusanos | épico | 25 |
| Resets | Aire fresco | Volvé a la superficie | fácil | 2 |
| Resets | Ida y vuelta | 5 veces | medio | 5 |
| Resets | Rutina | 15 veces | medio | 5 |
| Resets | Ascensor propio | 50 veces | difícil | 10 |
| Resets | Mil escaleras | 150 veces | épico | 25 |
| Resets | Mochila llena | 10 reliquias en una sola bajada | difícil | 10 |
| Resets | Museo ambulante | 20 reliquias en una sola bajada | épico | 25 |
| Frenesí y dinamita | Se te fue la mano | Encendé el frenesí | fácil | 2 |
| Frenesí y dinamita | Un minuto sin respirar | 1 min de frenesí seguido | medio | 5 |
| Frenesí y dinamita | Máquina de picar | 5 min de frenesí seguido | difícil | 10 |
| Frenesí y dinamita | ¡Fuego en el hoyo! | Usá la dinamita 10 veces | fácil | 2 |
| Frenesí y dinamita | Artificiero | 100 veces | medio | 5 |
| Frenesí y dinamita | Demoliciones S.A. | 1.000 veces | difícil | 10 |
| Árbol | Primera luz | Encendé el Corazón | fácil | 2 |
| Árbol | Constelación | 10 estrellas encendidas | medio | 5 |
| Árbol | Primer círculo | Anillo 1 completo | medio | 5 |
| Árbol | Segundo círculo | Anillo 2 completo | difícil | 10 |
| Árbol | Piedra angular | Primera piedra angular | difícil | 10 |
| Árbol | Cuatro pilares | Las 4 piedras angulares | difícil | 10 |
| Árbol | Tender puentes | Primer puente | difícil | 10 |
| Árbol | Cielo completo | Árbol completo | épico | 25 |
| Secretos | ¿Se rompió? | Tocá el engranaje 50 veces | fácil | 2 |
| Secretos | Shhh | Silenciá y reactivá 10 veces | fácil | 2 |
| Secretos | Siesta larga | Volvé después de 24 h sin jugar | fácil | 2 |
| Secretos | Turno nocturno | Jugá entre las 3 y las 5 de la mañana | medio | 5 |
| Secretos | Brazos cruzados | Llegá a Roca en una bajada sin dar un golpe | medio | 5 |
| Secretos | Curioso | Mirá la tabla de Botín 25 veces | fácil | 2 |
| Secretos | Justo a tiempo | Un golpe crítico que suelte un Legendario | épico | 25 |
| Secretos | Gracias por leer | Abrí los Créditos y llegá hasta el final | fácil | 2 |

Contadores históricos a guardar desde v0.7 (para los Puntos de Leyenda de v0.8): golpes, críticos, oro ganado, profundidad récord, resets, reliquias ganadas, cofres por rareza, usos de dinamita, segundos de frenesí, máximo de cada generador y tiempo jugado.
