# v0.7 — Árbol de reliquias y logros: simulación

Estado al 2026-11-26 (**cuarta vuelta**, con tus decisiones aplicadas). **Nada de esto está en el juego.** Rama `v07-arbol`.
Especificación para programar, ya con estos números: [arbol-reliquias.md](arbol-reliquias.md).

## Para mirar antes de programar
1. **"Museo ambulante" no se podía resolver solo cambiando los metros**, así que le agregué una condición: **"Con la meta en 540 m o más, pasala por 10 m"**. Cuánto se pasa la meta *baja* a lo largo de la partida (~40 m el primer día, ~10 m al final). Con "pasala por 60 m", quien empuja a propósito lo saca en 33 min el día 2 y necesita más de 70 min del día 10 en adelante; jugando normal, sale al principio o nunca. La condición nueva sale en las 15 corridas, en los cinco perfiles, cerca del 83% de la partida. Si preferís otra cosa, se cambia en `logros.json`.
2. **El tope de 6 golpes/s hay que programarlo como "máximo 6 en el último segundo"** (ver "Tope de golpes"). Pidiendo en cambio 1/6 s entre golpes, quien golpea a 4,5/s pierde golpes y casi un quinto del frenesí.
3. **Leyenda viva** (100 Legendarios) y, hasta 3 golpes/s, **La roca te teme** (300.000 golpes) no salen antes de completar el árbol: quedan como logros para después. Si no lo querés así, habría que bajarlos (por ejemplo a 70 Legendarios y 200.000 golpes).

## Qué cambió en esta vuelta
| Decisión | Qué quedó | Resultado simulado |
|---|---|---|
| Bolsa inicial 10/20/40 s | Aplicado | Acorta 28% (antes 55%) |
| Ventaja inicial 25/50/75% con mineros, y Reclutas unida | Una sola estrella en el anillo 2 | Acorta 13% |
| Veta rica (antes Descenso rápido): oro ×3 hasta el 95% de la meta | Aplicado | Acorta 28% |
| Memoria con costo 10 | Aplicado | Comodidad (1%) |
| Bonus histórico normal | La variante chica se descartó y salió del árbol | — |
| El corazón del mundo 570 m | Aplicado | Sale en todos los perfiles |
| Museo ambulante por metros pasados | Con condición de meta (punto 1) | Sale cerca del 83% |
| Tope de 6 golpes/s | Simulado 6 golpes/s como techo; frenesí verificado | El frenesí (4/s) no se ve afectado |
| Recalibrar | Meta nueva, sin retoques a mano | El salto de la meta entre las 20 y las 40 reliquias bajó de ~100 m a ~70 m |

Decisiones mías al unir Reclutas: la estrella queda en el anillo 2 (como estaba Ventaja); Capataz pasa a abrir la rama Cuadrilla y Contrato barato cuelga de Capataz. "Oro/s de la bajada anterior" es el de la cuadrilla al momento de volver.

## Cómo retomar
- Archivos: `tools/simulate_tree.gd` (simulador), `tools/tree_sim/economy_tree.gd` (el Economy real con los efectos del árbol encima), `tools/tree_sim/arbol_v3.json` (todos los números), `tools/tree_sim/calibrate.mjs` (calibra la tabla de la meta), `tools/tree_sim/logros.json`.
- Correr con el Godot de consola (ruta en `tools/run_tests.ps1`); cada campaña tarda ~2 min y se pueden lanzar en paralelo:
  - `godot --headless --path . --script res://tools/simulate_tree.gd -- campaign res://tools/tree_sim/arbol_v3.json 3 1` (perfil y semilla; `3p` = con pausas; `sin=o_corona` apaga una estrella; `empuje` mide cuánto cuesta pasar la meta)
  - `... -- descents res://tools/tree_sim/arbol_v3.json 7` y `... -- stars res://tools/tree_sim/arbol_v3.json 15 <parte> <partes>`
  - `node tools/tree_sim/calibrate.mjs tools/tree_sim/arbol_v3.json salida.json` (~10 min) y pasar los `puntos` al árbol. **Cualquier cambio de estrellas pide recalibrar.**
- Jugador simulado: compra casi óptimo, usa la dinamita, entra una vez por día 60 min (23 h fuera), vuelve a la superficie cuando las reliquias por minuto dejan de mejorar y compra siempre la estrella más barata. Es optimista. "Con pausas": golpea 30–150 s y para 10–50 s (25% sin golpear), sin dejar de comprar ni de usar la dinamita.

## Decisiones tomadas
1. Las reliquias **dejan de dar +25% de oro**: son la moneda del árbol. Bonus pasivo por reliquias ganadas en la historia: +6% cada una hasta 60 y después +0,5%.
2. Testers: conservan sus reliquias, cuentan para el bonus histórico y un cartel se los avisa.
3. La meta de volver se corre según una **tabla** y se ve en el juego: "Próximo regreso a X m". Más hondo paga más.
4. El piso de ~10 min es a 3 golpes/s y **hasta completar el anillo 2**; después las bajadas pueden acortarse.
5. El jugador activo es el más beneficiado. AFK base 5%.
6. Aprobado: cofres como fuente principal de oro, 5 y 6 golpes/s por debajo del piso, bajadas 2.ª a 8.ª más largas que hoy, 1–2 compras por día del 23 al 25.
7. Nombres: "Bolsa inicial", "Veta rica", "Cuenta regresiva ★", "A la par ★". Racha como está.
8. Tope de 6 golpes/s que cuentan.

## La propuesta
### Meta de volver a la superficie
Depende de las reliquias **sacadas de bajadas**; se fija al empezar cada bajada. Lineal entre puntos:

| Reliquias | 0–3 | 6 | 9 | 12 | 20 | 40 | 65 | 100 | 180 | 300 | 500 | 700 | 1000 | 1400 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Meta (m) | 300 | 320 | 322 | 333 | 356 | 427 | 443 | 471 | 487 | 501 | 520 | 558 | 594 | 635 |

+1 reliquia por cada 30 m de meta corrida. La partida termina cerca de 580 m; más allá de 400 m todo es Abismo (los mapas nuevos quedan para más adelante).

### AFK
Base 5% (hoy 25%); Vigilia 7 / 9 / 12%; tope 8 h, con Turno noche 10 / 12 h; Turnos rotativos +50%. El AFK no abre cofres.

### Tope de golpes y frenesí
Cuánto del tiempo queda prendido el frenesí, con golpes irregulares (±40%):

| Golpes/s reales | Sin tope | Máximo 6 en el último segundo | Al menos 1/6 s entre golpes |
|---|---|---|---|
| 3,5 | 65% | 65% | 65% |
| 4 | 99% | 99% | 98% |
| 4,5 | 99% | 99% | **81%** |
| 6 | 100% | 100% (cuentan 5,3/s) | 100% (cuentan 4,0/s) |
| 15 (autoclicker) | 100% | 100% (cuentan 5,8/s) | 100% (cuentan 4,9/s) |

El umbral de 4 golpes/s (3 con Mano rápida) queda bien por debajo del tope de 6 **con la ventana de 1 s**.

### Contadores para v0.8
Además de los de la lista de logros: tiempo activo (segundos con algún golpe en los últimos 5 s), tiempo AFK (segundos acreditados como ausencia) y máximo de golpes/s sostenido (mejor promedio en 10 s, contando los que pasan el tope).

### Árbol
**1008 reliquias en 125 compras:** anillo 1: 138 · anillo 2: 272 · anillo 3: 397 · puentes: 200 · Corazón: 1. Anillo 2 = 350 m y 8 resets; anillo 3 = 400 m y 25 resets. ★ = piedra angular (máximo 2 activas). La columna "Cambió" es contra la vuelta anterior.

| id | Nombre | Efecto por nivel | Anillo | Niveles | Costo por nivel | Total | Cambió |
|---|---|---|---|---|---|---|---|
| core | Corazón del pozo | +50% de oro | 0 | 1 | 1 | 1 |  |
| f_brazo | Brazo fuerte | cada golpe suma +1,2% del oro/s | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| f_templado | Pico templado | +30% de golpe | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| f_ojo | Ojo certero | +3% de crítico | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| f_brutal | Golpe brutal | +0,6× de daño crítico | 2 | 5 | 5, 6, 7, 8, 9 | 35 |  |
| f_eco | Eco | +6% de golpe doble | 2 | 6 | 5, 6, 7, 8, 9, 10 | 45 |  |
| f_combo | Combo | en frenesí, +12% de golpe | 3 | 8 | 6, 6, 7, 8, 8, 9, 10, 10 | 64 |  |
| f_umbral | Mano rápida | frenesí con 1 golpe/s menos | 3 | 1 | 15 | 15 |  |
| f_furia | Furia ciega ★ | críticos ×4, mitad de chance | 3 | 1 | 40 | 40 |  |
| o_olfato | Olfato | +20% de chance de cofre | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| o_botin | Botín generoso | +25% de oro por cofre | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| o_gemologo | Gemólogo | +50% de Raros | 1 | 3 | 2, 2, 3 | 7 |  |
| o_dragon | Corazón de dragón | +40% de Épicos | 2 | 6 | 5, 6, 7, 8, 9, 10 | 45 |  |
| o_doble | Doble cofre | +6% de cofre doble | 2 | 6 | 5, 6, 7, 8, 9, 10 | 45 |  |
| o_corona | Corona | +25% de Legendarios | 3 | 8 | 6, 6, 7, 8, 8, 9, 10, 10 | 64 |  |
| o_reliquia | Reliquia escondida | +20% de chance de +1 reliquia por Legendario | 3 | 5 | 7, 8, 8, 9, 10 | 42 |  |
| o_apostador | Apostador ★ | sin Comunes; el resto sale ×2 | 3 | 1 | 40 | 40 |  |
| c_capataz | Capataz | +5% de cuadrilla | 1 | 5 | 2, 2, 3, 3, 3 | 13 | ahora abre la rama |
| c_contrato | Contrato barato | −4% de costo de generadores | 1 | 5 | 2, 2, 3, 3, 3 | 13 | cuelga de Capataz |
| c_bolsa | Bolsa inicial | empezás con 10 / 20 / 40 s del oro/s con el que volviste | 1 | 3 | 2, 2, 3 | 7 | **efecto** |
| c_ventaja | Ventaja inicial | empezás con 25 / 50 / 75% de la cuadrilla que tenías (mineros incluidos) | 2 | 3 | 8, 10, 14 | 32 | **unida con Reclutas** |
| c_hitos | Hitos dorados | hitos ×2,1 … ×2,5 | 2 | 5 | 6, 7, 8, 9, 10 | 40 |  |
| c_memoria | Memoria | conservás el Pico y la Dinamita (comodidad) | 3 | 1 | 10 | 10 | **costo** |
| c_mina | A la par ★ | cuadrilla ×1,3 mientras golpeás, ×0,7 si no | 3 | 1 | 40 | 40 |  |
| t_mecha | Mecha corta | −8% de recarga de dinamita | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| t_polvora | Pólvora | +20% de dinamita | 1 | 5 | 2, 2, 3, 3, 3 | 13 |  |
| t_vigilia | Vigilia | AFK 7 / 9 / 12% (base 5%) | 1 | 3 | 2, 2, 3 | 7 |  |
| t_noche | Turno noche | tope AFK 10 / 12 h (base 8) | 2 | 2 | 8, 10 | 18 |  |
| t_veta | Veta rica | oro ×3 hasta el 95% de la meta | 2 | 1 | 12 | 12 | **efecto y nombre** |
| t_racha | Racha | +2% de oro por minuto golpeando sin parar; tope 6 / 12 / 18 / 24 / 30% | 3 | 5 | 7, 8, 8, 9, 10 | 42 |  |
| t_cuenta | Cuenta regresiva ★ | dinamita recarga en la mitad, paga 10% menos | 3 | 1 | 40 | 40 |  |
| p_suerte | Golpe de suerte | 3% de cofre por crítico | 4 | 1 | 50 | 50 |  |
| p_mineros | Mineros con suerte | +100% de cofres de la cuadrilla | 4 | 1 | 50 | 50 |  |
| p_turnos | Turnos rotativos | +50% de producción AFK | 4 | 1 | 50 | 50 |  |
| p_critica | Dinamita crítica | la dinamita puede hacer crítico | 4 | 1 | 50 | 50 |  |

## Resultados
1 h por día hasta completar el árbol; rangos de 3 semillas. "Se puede volver" es el momento en que se llega a la meta (lo que tardaría quien vuelve apenas puede); el jugador simulado se queda un rato más. No cuentan las bajadas con una ausencia en el medio, que el AFK adelanta.

### Partidas completas
| | 3 g/s | 3 g/s con pausas | 1,5 g/s | 5 g/s | 6 g/s (techo) |
|---|---|---|---|---|---|
| Primer reset | 44–49 min | 45–49 min | 49–52 min | 37–43 min | 38–41 min |
| Se puede volver, hasta completar el anillo 2: mínimo | 7:56–10:01 | 9:35–10:43 | 11:34–11:52 | 5:23–6:34 | 5:09–5:43 |
| … 5% más rápido | 9:39–10:30 | 9:39–11:44 | 12:13–13:02 | 6:13–6:58 | 5:44–6:10 |
| … mediana | 11:42–12:20 | 13:22–13:44 | 14:30–14:58 | 8:18–8:29 | 7:32–7:50 |
| … bajadas bajo 10 min | 0–9% | 0–8% | 0% | 74–90% | 82–89% |
| Bajada completa (mediana), hasta completar el anillo 2 | 16:34–17:26 | 18:52–19:38 | 20:28–21:14 | 11:58–12:14 | 10:58–11:20 |
| Se puede volver, con el anillo 2 completo: mínimo | 6:48–7:21 | 7:18–9:24 | 10:01–10:23 | 4:11–4:53 | 3:59–4:36 |
| … 5% más rápido | 7:14–7:31 | 8:24–9:42 | 10:14–10:45 | 5:02–5:14 | 4:25–4:44 |
| … mediana | 8:24–8:56 | 11:05–11:38 | 12:18–13:57 | 6:38–6:48 | 5:46–6:12 |
| … bajadas bajo 10 min | 77–82% | 23–30% | 0% | 100% | 100% |
| Bajada completa (mediana), con el anillo 2 completo | 12:06–12:50 | 15:46–16:28 | 17:22–19:38 | 9:46–10:00 | 8:34–9:08 |
| Anillo 1 completo | día 7–8 | día 8 | día 9 | día 6–7 | día 6–7 |
| Anillo 2 completo | día 21–22 | día 23–24 | día 25–26 | día 16–17 | día 15–16 |
| Primera piedra angular | día 22–23 | día 24–26 | día 26–28 | día 17 | día 15–16 |
| Primer puente | día 25–26 | día 28 | día 30–32 | día 19 | día 17–18 |
| **Árbol completo** | **día 27–28** | **día 30–31** | **día 33–34** | **día 20–21** | **día 18–20** |
| Compras por día, días 10–25: promedio | 3.5–3.6 | 3.4–3.6 | 3.5–3.6 | 4.6–4.7 | 4.7–5.1 |
| … día con menos compras | 1 | 1 | 2–3 | 1–2 | 2 |
| … días con menos de 3 | 3 de 16, 4 de 16, 4 de 16 | 2 de 16, 3 de 16, 2 de 16 | 0 de 16, 0 de 16, 3 de 16 | 2 de 11, 3 de 11, 2 de 10 | 2 de 9, 3 de 10, 2 de 8 |
| Oro: golpes | 27–28% | 24–25% | 12–12% | 38–38% | 41–41% |
| Oro: cofres | 40–43% | 40–42% | 45–45% | 40–41% | 38–40% |
| Oro: dinamita | 17–18% | 19–19% | 24–25% | 13–13% | 11–12% |
| Oro: AFK | 6–7% | 8–9% | 9–9% | 4–5% | 3–5% |

### Las primeras 8 bajadas
Volviendo apenas se puede, sin ausencias (mediana de 7).

| Golpes/s | Reglas | 1.ª | 2.ª | 3.ª | 4.ª | 5.ª | 6.ª | 7.ª | 8.ª |
|---|---|---|---|---|---|---|---|---|---|
| 3 | hoy | 28:16 | 17:40 | 13:06 | 10:23 | 9:11 | 7:32 | 6:36 | 6:08 |
| 3 | árbol | 28:16 | 16:09 | 15:56 | 15:53 | 14:02 | 13:30 | 14:22 | 13:50 |
| 3 | árbol y logros | 27:13 | 14:19 | 14:22 | 14:01 | 11:56 | 12:37 | 12:24 | 13:00 |
| 3 con pausas | hoy | 29:09 | 19:07 | 14:44 | 10:46 | 9:38 | 8:10 | 6:50 | 6:24 |
| 3 con pausas | árbol | 29:09 | 17:17 | 17:19 | 17:02 | 14:07 | 14:30 | 14:07 | 15:05 |
| 3 con pausas | árbol y logros | 28:01 | 15:24 | 15:13 | 14:47 | 14:17 | 12:01 | 13:10 | 12:38 |
| 1,5 | hoy | 30:58 | 20:09 | 16:08 | 12:32 | 9:55 | 8:46 | 7:56 | 6:41 |
| 1,5 | árbol | 30:58 | 17:53 | 17:48 | 19:41 | 16:37 | 15:26 | 16:37 | 16:08 |
| 1,5 | árbol y logros | 29:54 | 16:03 | 16:11 | 17:31 | 15:14 | 16:01 | 14:13 | 14:34 |
| 5 | hoy | 24:47 | 16:01 | 12:10 | 9:14 | 8:15 | 7:13 | 6:03 | 5:41 |
| 5 | árbol | 24:47 | 14:07 | 14:09 | 14:02 | 12:37 | 11:24 | 11:50 | 11:29 |
| 5 | árbol y logros | 23:57 | 13:15 | 11:15 | 11:28 | 10:38 | 9:59 | 10:20 | 10:17 |
| 6 | hoy | 23:50 | 14:44 | 11:14 | 9:01 | 7:37 | 6:39 | 5:35 | 5:15 |
| 6 | árbol | 23:50 | 13:36 | 12:21 | 12:36 | 11:17 | 10:55 | 11:10 | 11:01 |
| 6 | árbol y logros | 23:05 | 12:06 | 11:34 | 11:15 | 10:13 | 10:02 | 10:01 | 9:56 |

### Día por día (3 golpes/s, semilla 1)
```
día | reliquias ganadas (gastadas) | compras del día | niveles | resets | se puede volver a los (mín/mediana) | bajada completa (mediana) | récord | meta | logros (frag.)
  primer reset a los 46:02: 6 reliquias (con fragmentos) → encendió core, f_brazo, sobran 1
  1 |     6 (5) |  3 |   3 |   1 | 27:58 / 27:58 |  46:02 | 341 m | 300 m | 20 (55)
  2 |    17 (17) |  6 |   9 |   4 | 12:27 / 12:52 |  22:58 | 363 m | 336 m | 25 (77)
  3 |    32 (31) |  7 |  16 |   7 | 12:34 / 12:35 |  22:30 | 383 m | 377 m | 31 (106)
  4 |    57 (55) | 11 |  27 |  11 | 10:04 / 13:16 |  18:40 | 445 m | 433 m | 36 (143)
  5 |    82 (82) |  9 |  36 |  15 | 11:07 / 11:54 |  16:52 | 459 m | 449 m | 39 (160)
  6 |   103 (103) |  7 |  43 |  18 | 12:23 / 13:44 |  19:18 | 474 m | 465 m | 40 (185)
  7 |   127 (127) |  8 |  51 |  21 | 12:41 / 13:31 |  19:02 | 497 m | 474 m | 43 (230)
  8 |   159 (159) |  8 |  59 |  25 | 10:54 / 11:55 |  16:52 | 500 m | 480 m | 47 (260)
  9 |   193 (189) |  5 |  64 |  29 | 10:54 / 11:27 |  16:14 | 505 m | 486 m | 47 (260)
 10 |   226 (220) |  5 |  69 |  33 | 11:27 / 11:45 |  16:40 | 505 m | 490 m | 49 (280)
 11 |   258 (255) |  5 |  74 |  37 | 11:41 / 12:09 |  17:12 | 505 m | 494 m | 49 (280)
 12 |   290 (285) |  4 |  78 |  41 | 10:48 / 11:47 |  16:42 | 508 m | 498 m | 49 (280)
 13 |   316 (309) |  3 |  81 |  44 | 11:06 / 12:11 |  17:14 | 511 m | 501 m | 50 (285)
 14 |   352 (349) |  5 |  86 |  48 | 11:06 / 12:31 |  17:42 | 522 m | 504 m | 50 (285)
 15 |   385 (380) |  4 |  90 |  52 | 12:10 / 13:28 |  18:56 | 522 m | 507 m | 53 (310)
 16 |   410 (405) |  3 |  93 |  55 | 10:30 / 13:01 |  18:22 | 522 m | 509 m | 53 (310)
 17 |   449 (441) |  4 |  97 |  59 | 10:01 / 11:34 |  16:26 | 530 m | 513 m | 54 (320)
 18 |   487 (487) |  5 | 102 |  63 | 12:20 / 12:43 |  17:58 | 530 m | 516 m | 54 (320)
 19 |   522 (517) |  3 | 105 |  66 | 11:39 / 12:56 |  18:14 | 530 m | 519 m | 54 (320)
 20 |   566 (557) |  4 | 109 |  70 | 12:32 / 13:45 |  19:22 | 541 m | 524 m | 56 (355)
 21 |   605 (597) |  4 | 113 |  73 | 12:01 / 13:14 |  18:40 | 541 m | 529 m | 56 (355)
 22 |   646 (633) |  3 | 116 |  77 | 10:27 / 12:07 |  17:08 | 545 m | 536 m | 58 (375)
 23 |   713 (688) |  2 | 118 |  82 |   8:14 / 9:26 |  13:30 | 552 m | 545 m | 61 (435)
 24 |   773 (768) |  2 | 120 |  87 |   7:41 / 8:10 |  11:48 | 562 m | 555 m | 62 (460)
 25 |   844 (808) |  1 | 121 |  92 |   7:09 / 8:50 |  12:42 | 570 m | 562 m | 65 (520)
 26 |   911 (908) |  2 | 123 |  97 |   7:14 / 9:12 |  13:12 | 574 m | 568 m | 67 (555)
 27 |   980 (958) |  1 | 124 | 102 |   7:52 / 9:55 |  14:10 | 581 m | 574 m | 67 (555)
 28 |  1008 (1008) |  1 | 125 | 104 | 10:47 / 10:47 |  15:20 | 584 m | 577 m | 67 (555)
```

### Estrella por estrella
Cuánto acorta una bajada pasar la estrella de 0 al máximo, con las demás de su anillo y anteriores al máximo (sin otras piedras angulares), en una bajada que viene de otra igual. La meta de cada fila es adonde se llega en 12 min sin la estrella; promedio de 15 semillas (ruido de unos ±4 puntos). "Días hasta árbol completo": campaña a 3 golpes/s con la estrella comprada pero sin efecto, contra con efecto (3 semillas). La última columna son valores sin azar a los 10 min de bajada.

| Estrella | Anillo | Costo | 3 g/s | 3 con pausas | 1,5 g/s | 5 g/s | Días hasta árbol completo (sin » con) | Qué más cambia |
|---|---|---|---|---|---|---|---|---|
| Corazón del pozo | 0 | 1 | +35% | +35% | +31% | +33% |  | 2 h fuera = 4:13 → 6:19 min de juego · 8 h fuera = 13:48 → 20:42 min de juego · 23 h fuera = 13:48 → 20:42 min de juego |
| Brazo fuerte | 1 | 13 | +11% | +7% | +6% | +12% |  | cofres 28.6% → 26.1% del ingreso |
| Pico templado | 1 | 13 | +14% | +10% | +10% | +17% |  | cofres 29.2% → 26.1% del ingreso |
| Ojo certero | 1 | 13 | +2% | +1% | +1% | +3% |  | cofres 25.9% → 25.3% del ingreso |
| Golpe brutal | 2 | 35 | +12% | +7% | +3% | +15% |  | cofres 37.3% → 33.8% del ingreso |
| Eco | 2 | 45 | +9% | +4% | +2% | +8% |  | cofres 36.4% → 33.8% del ingreso |
| Combo | 3 | 64 | +20% | +18% | +0% | +26% |  | cofres 35.9% → 28.9% del ingreso |
| Mano rápida | 3 | 15 | +20% | +18% | +0% | +0% |  | cofres 35.9% → 28.9% del ingreso |
| Furia ciega ★ | 3 | 40 | +21% | +22% | +15% | +25% |  | cofres 28.9% → 22.9% del ingreso |
| Olfato | 1 | 13 | +15% | +15% | +13% | +15% |  | cofres 15.0% → 26.1% del ingreso · 14.4 → 28.8 cofres cada 10 min · reliquias de cofres/h 0.4 → 0.9 |
| Botín generoso | 1 | 13 | +15% | +16% | +15% | +16% |  | cofres 13.5% → 26.1% del ingreso |
| Gemólogo | 1 | 7 | +7% | +8% | +7% | +9% |  | cofres 20.1% → 25.3% del ingreso |
| Corazón de dragón | 2 | 45 | +11% | +11% | +11% | +13% |  | cofres 26.8% → 33.8% del ingreso |
| Doble cofre | 2 | 45 | +10% | +8% | +7% | +8% |  | cofres 27.3% → 33.8% del ingreso · reliquias de cofres/h 0.9 → 1.2 |
| Corona | 3 | 64 | +3% | +1% | +4% | +1% | 29–31 » 27–28 | cofres 27.1% → 28.9% del ingreso · reliquias de cofres/h 2.4 → 7.1 |
| Reliquia escondida | 3 | 42 | -1% | -0% | +1% | -1% | 28–30 » 27–28 | reliquias de cofres/h 3.5 → 7.1 |
| Apostador ★ | 3 | 40 | +17% | +23% | +22% | +22% | 28–29 » 27–28 | cofres 28.9% → 42.5% del ingreso · 28.8 → 34.2 cofres cada 10 min · reliquias de cofres/h 7.1 → 14.1 |
| Capataz | 1 | 13 | +22% | +19% | +22% | +21% |  |  |
| Contrato barato | 1 | 13 | +12% | +11% | +11% | +9% |  |  |
| Bolsa inicial | 1 | 7 | +28% | +29% | +30% | +28% |  |  |
| Ventaja inicial | 2 | 32 | +13% | +11% | +11% | +13% |  |  |
| Hitos dorados | 2 | 40 | +29% | +30% | +29% | +29% |  |  |
| Memoria | 3 | 10 | +1% | +1% | +1% | +0% |  |  |
| A la par ★ | 3 | 40 | +23% | +18% | +26% | +22% |  | 2 h fuera = 1:11 → 0:50 min de juego · 8 h fuera = 4:21 → 3:03 min de juego · 23 h fuera = 6:28 → 4:32 min de juego |
| Mecha corta | 1 | 13 | +12% | +11% | +15% | +8% |  | cofres 30.2% → 26.1% del ingreso |
| Pólvora | 1 | 13 | +19% | +18% | +23% | +17% |  | cofres 32.5% → 26.1% del ingreso |
| Vigilia | 1 | 7 | +0% | +0% | +0% | +0% |  | 2 h fuera = 1:15 → 2:33 min de juego · 8 h fuera = 4:06 → 9:24 min de juego · 23 h fuera = 4:06 → 9:24 min de juego |
| Turno noche | 2 | 18 | +0% | +0% | +0% | +0% |  | 23 h fuera = 6:35 → 9:47 min de juego |
| Veta rica | 2 | 12 | +28% | +29% | +25% | +23% |  |  |
| Racha | 3 | 42 | +10% | +1% | +13% | +5% |  |  |
| Cuenta regresiva ★ | 3 | 40 | +9% | +12% | +11% | +8% |  | cofres 28.9% → 26.1% del ingreso |
| Golpe de suerte | 4 | 50 | +11% | +12% | +8% | +14% |  | cofres 28.9% → 36.8% del ingreso · 28.8 → 41.2 cofres cada 10 min · reliquias de cofres/h 7.1 → 10.1 |
| Mineros con suerte | 4 | 50 | +14% | +19% | +19% | +15% |  | cofres 28.9% → 39.7% del ingreso · 28.8 → 46.8 cofres cada 10 min · reliquias de cofres/h 7.1 → 11.5 |
| Turnos rotativos | 4 | 50 | +0% | +0% | +0% | +0% |  | 2 h fuera = 1:11 → 1:47 min de juego · 8 h fuera = 4:21 → 6:32 min de juego · 23 h fuera = 6:28 → 9:42 min de juego |
| Dinamita crítica | 4 | 50 | +16% | +17% | +19% | +13% |  |  |

Lectura:
- Las estrellas de arrastre ya se notan: Veta rica y Bolsa inicial ~28%, Ventaja ~13%.
- **Casi no aceleran:** Memoria (comodidad, a propósito) y Ojo certero (1–3%). Corona y Reliquia escondida no aceleran la bajada pero sí la campaña (reliquias de cofres); las de AFK solo se ven al volver.
- **Combo** y **Mano rápida** no hacen nada por debajo del ritmo de frenesí (y Mano rápida tampoco por encima). **Racha** casi no existe con pausas.
- **Cuenta regresiva** sigue siendo la piedra angular más floja.

## Logros
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
| Profundidad | El corazón del mundo | 570 m | épico | 25 |
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
| Resets | Mil escaleras | 90 veces | épico | 25 |
| Resets | Mochila llena | 10 reliquias en una sola bajada | difícil | 10 |
| Resets | Museo ambulante | Con la meta en 540 m o más, pasala por 10 m | épico | 25 |
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

Contadores históricos a guardar desde v0.7 (para los Puntos de Leyenda de v0.8): golpes, críticos, oro ganado, profundidad récord, resets, reliquias ganadas, cofres por rareza, usos de dinamita, segundos de frenesí, máximo de cada generador, tiempo jugado, y los tres nuevos de "Contadores para v0.8".
