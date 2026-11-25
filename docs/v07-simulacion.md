# v0.7 — Árbol de reliquias y logros: simulación

Estado al 2026-11-25. **Nada de esto está en el juego**: es la simulación previa y espera aprobación. Rama `v07-arbol`.
Especificación de partida: [arbol-reliquias.md](arbol-reliquias.md).

## Cómo retomar
- Archivos: `tools/simulate_tree.gd` (simulador), `tools/tree_sim/economy_tree.gd` (el Economy real con los efectos del árbol encima), `tools/tree_sim/arbol_v1.json` (propuesta), `arbol_doc.json` (números originales), `logros.json`.
- Correr (usar el Godot de consola; ver la ruta en `tools/run_tests.ps1`):
  - `godot --headless --path . --script res://tools/simulate_tree.gd -- campaign res://tools/tree_sim/arbol_v1.json` (1 h por día hasta completar; ~4 min)
  - `... -- descents res://tools/tree_sim/arbol_v1.json 7` (bajadas seguidas contra las reglas de hoy)
  - `... -- stars res://tools/tree_sim/arbol_v1.json 3 <parte> <partes>` (valor de cada estrella; repartible en procesos)
- Jugador simulado: 3 golpes/s sin pausas, compra casi óptima, usa la dinamita, entra una vez por día 60 min (23 h fuera), vuelve cuando las reliquias por minuto dejan de mejorar y compra siempre la estrella más barata. Es optimista.

## Decisiones ya tomadas
1. Las reliquias **dejan de dar +25% de oro**: son solo la moneda del árbol.
2. Bonus pasivo chico (~+5%) por **reliquias ganadas en toda la historia**, para que gastar nunca debilite.
3. Con el árbol, las bajadas siguientes tienen que acortarse al menos tanto como hoy.
4. Testers: conservan sus reliquias para gastarlas, cuentan para el bonus histórico y un cartel se los avisa la primera vez.
5. Correr la profundidad por reliquia, **visible en el juego: "Próxima reliquia a X m"**.
6. "Planos viejos" pasa a ser **"Bolsa inicial"** (empezás la bajada con algo de oro).
7. Otra piedra angular para Tiempo en lugar de "Reloj de arena", que no castigue a quien juega una vez por día.

## Hallazgos
- Con los números del documento y el +25% de hoy, el árbol se completaba en **6 h** (objetivo: 21–35 h).
- Sin el +25%, con los números del documento: 52 días (el anillo 1 se lleva más de la mitad del costo).
- Con +5% y las estrellas del documento **no** se cumple la condición de las bajadas (6.ª bajada 16:01 contra 7:10 de hoy).
- Costos y forma del bonus no controlan el ritmo solos: las reliquias salen 2 por llegar a 300 m, y con el árbol 300 m queda a segundos (7–10 h con cualquier forma de bonus).
- "Planos viejos" no hacía nada: los generadores revelados ya se conservan al volver.
- "Reloj de arena" (AFK 100%, tope 2 h) era una trampa para quien entra una vez por día: 2 h pagas contra 11,2 h con Vigilia y Turno noche.
- "Magma" como requisito del anillo 2 se cumple solo (volver ya pide 300 m).

## Cómo quedan tus cambios
- **Profundidad por reliquia:** cada reliquia sacada de una bajada corre más abajo la profundidad para volver (mínimo y fórmula de reliquias). Con 0 reliquias todo es igual que hoy; con 0,28 m y 100 reliquias, se vuelve desde 328 m. Las de cofres y logros no la corren. Un dato nuevo en el guardado (reliquias sacadas de bajadas); testers: arranca con las que ya tienen. En el juego: **"Próxima reliquia a X m"** junto a la profundidad y en la confirmación de volver, y un número en `data/` para ajustarlo.
- **Bolsa inicial** (reemplaza a Planos viejos, anillo 1, 3 niveles): oro para gastar al empezar; no cuenta para la profundidad.
- **Cuenta regresiva ★** (propuesta, reemplaza a Reloj de arena): la dinamita recarga en la mitad de tiempo y cada explosión paga 25% menos (en neto ~+50% de oro de dinamita). Premia jugar activo; la desventaja son explosiones más chicas y tocarla el doble. **No toca el AFK**, así que no castiga a quien entra una vez por día.

## Otras propuestas (falta tu OK)
- **Bonus histórico:** +6% por reliquia hasta 60 y después +0,5% cada una. Con +5% la 6.ª bajada quedaba justo corta. El tope es agregado mío: sin él el final se dispara.
- **Corazón:** +50% de oro (era +10%), para que el primer reset rinda como hoy.
- **Anillos:** anillo 2 = 350 m y 8 resets; anillo 3 = 400 m y 25 resets.
- **Profundidad por reliquia:** 0,28 m.

## Costos por estrella
| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total |
|---|---|---|---|---|---|
| core | Corazón del pozo | +50% de oro | 0 | 1 | 1 |
| f_brazo | Brazo fuerte | cada golpe suma +1,2% del oro/s | 1 | 1, 2, 2, 3, 5 | 13 |
| f_templado | Pico templado | +30% de golpe | 1 | 1, 2, 2, 3, 5 | 13 |
| f_ojo | Ojo certero | +3% de crítico | 1 | 1, 2, 2, 3, 5 | 13 |
| f_brutal | Golpe brutal | +0,6× de daño crítico | 2 | 4, 6, 9, 14, 20 | 53 |
| f_eco | Eco | +12% de golpe doble | 2 | 6, 9, 14 | 29 |
| f_combo | Combo | en frenesí, +30% de golpe | 3 | 10, 15, 23 | 48 |
| f_umbral | Mano rápida | frenesí con 1 golpe/s menos | 3 | 20 | 20 |
| f_furia | Furia ciega ★ | críticos ×4, mitad de chance | 3 | 60 | 60 |
| o_olfato | Olfato | +15% de chance de cofre | 1 | 1, 2, 2, 3, 5 | 13 |
| o_botin | Botín generoso | +30% de oro por cofre | 1 | 1, 2, 2, 3, 5 | 13 |
| o_gemologo | Gemólogo | +40% de peso del Raro | 1 | 2, 3, 5 | 10 |
| o_dragon | Corazón de dragón | +40% de peso del Épico | 2 | 6, 9, 14 | 29 |
| o_doble | Doble cofre | +8% de cofre doble | 2 | 6, 9, 14 | 29 |
| o_corona | Corona | +50% de peso del Legendario | 3 | 15, 23 | 38 |
| o_reliquia | Reliquia escondida | el Legendario da +1 reliquia | 3 | 30 | 30 |
| o_apostador | Apostador ★ | sin Comunes; el resto sale ×2 | 3 | 60 | 60 |
| c_reclutas | Reclutas | empezás con +5 mineros | 1 | 1, 2, 2, 3, 5 | 13 |
| c_capataz | Capataz | +20% de cuadrilla | 1 | 2, 3, 5, 7, 10 | 27 |
| c_contrato | Contrato barato | −4% de costo de generadores | 1 | 1, 2, 2, 3, 5 | 13 |
| c_bolsa | Bolsa inicial | empezás con 500 / 5.000 / 50.000 de oro | 1 | 2, 3, 5 | 10 |
| c_ventaja | Ventaja inicial | empezás con 1 Taladro / Topo / Gólem | 2 | 8, 12, 18 | 38 |
| c_hitos | Hitos dorados | hitos ×2,5 | 2 | 25 | 25 |
| c_memoria | Memoria | conservás el Pico | 3 | 30 | 30 |
| c_mina | Mina sola ★ | cuadrilla ×1,5, golpes ×0,25 | 3 | 60 | 60 |
| t_mecha | Mecha corta | −8% de recarga de dinamita | 1 | 1, 2, 2, 3, 5 | 13 |
| t_polvora | Pólvora | +25% de dinamita | 1 | 1, 2, 2, 3, 5 | 13 |
| t_vigilia | Vigilia | AFK 40 / 55 / 70% | 1 | 2, 3, 5 | 10 |
| t_noche | Turno noche | tope AFK 12 / 16 h | 2 | 8, 12 | 20 |
| t_descenso | Descenso rápido | hasta 200 m, oro ×3 | 2 | 15 | 15 |
| t_memoria_din | Mecha guardada | conservás la Dinamita | 3 | 30 | 30 |
| t_cuenta | Cuenta regresiva ★ | dinamita recarga en la mitad, paga 25% menos | 3 | 60 | 60 |
| p_suerte | Golpe de suerte | 3% de cofre por crítico | 4 | 60 | 60 |
| p_mineros | Mineros con suerte | +50% de cofres de la cuadrilla | 4 | 60 | 60 |
| p_turnos | Turnos rotativos | +50% de producción AFK | 4 | 60 | 60 |
| p_critica | Dinamita crítica | la dinamita puede hacer crítico | 4 | 60 | 60 |

Por anillo: anillo 0 = 1 · anillo 1 = 174 · anillo 2 = 238 · anillo 3 = 436 · anillo 4 = 240. **Árbol completo = 1089 reliquias.** ★ = piedra angular (máximo 2 activas).

## Resultados
### Bajadas seguidas (tu condición)
Con 3 golpes/s, **árbol + logros cumple las seis bajadas**: 25:28 · 12:15 · 11:11 · 9:29 · 7:28 · 6:38 contra 28:15 · 18:06 · 12:36 · 10:34 · 8:53 · 7:10 de hoy.
**Solo el árbol, sin las reliquias de los logros, no la cumple** de la 4.ª a la 6.ª (11:38 · 10:39 · 9:12). A 1,5 golpes/s quedaban cortas la 5.ª y la 6.ª en la prueba anterior.

```
Bajadas seguidas hasta poder volver (mediana de 7). Entre paréntesis: reliquias ganadas en total / estrellas encendidas.
3.0 golpes/s
  hoy             28:15 (2/0) · 18:06 (5/0) · 12:36 (7/0) · 10:34 (10/0) · 8:53 (12/0) · 7:10 (15/0)
  arbol           28:15 (2/2) · 15:40 (5/5) · 13:32 (7/7) · 11:38 (10/10) · 10:39 (12/10) · 9:12 (15/10)
  arbol y logros  25:28 (5/5) · 12:15 (8/8) · 11:11 (11/10) · 9:29 (15/10) · 7:28 (19/10) · 6:38 (21/10)
1.5 golpes/s
  hoy             30:52 (2/0) · 20:08 (4/0) · 15:05 (7/0) · 12:38 (9/0) · 9:44 (11/0) · 8:19 (14/0)
```

### Ritmo según la profundidad por reliquia
Corridas con bonus +5% y Corazón +25% (anteriores a los últimos ajustes). Horas jugadas, 1 h por día.

| Metros por reliquia | Anillo 1 completo | Anillo 2 completo | Árbol completo |
|---|---|---|---|
| 0,10 | 5,3 h | 7,4 h | 11,0 h |
| 0,20 | 5,8 h | 8,8 h | 17,5 h |
| 0,35 | 6,7 h | 13,0 h | 42,1 h |
| 0,60 | 8,8 h | 33,0 h | más de 60 h |

### Resultado de la propuesta final (0,28 m, +6%, Corazón +50%, con tus cambios)
Una partida simulada a 3 golpes/s, 1 h por día. **Cumple el objetivo de 3 a 5 semanas.**

| Hito | Día | Horas jugadas |
|---|---|---|
| Anillo 2 abierto | 3 | 2,0 |
| Anillo 3 abierto | 4 | 3,3 |
| Anillo 1 completo | 6 | 5,2 |
| Anillo 2 completo | 10 | 9,2 |
| Primera piedra angular | 13 | 12,4 |
| Anillo 3 completo | 19 | 18,2 |
| Primer puente | 21 | 20,2 |
| **Árbol completo** | **28** | **27,1** |

No cumple "primer reset: Corazón y 1–2 estrellas": con los fragmentos de los logros son 7 reliquias y se encienden el Corazón y 6 estrellas.

Fragmentos acumulados: día 1: 60 · día 3: 116 · día 7: 275 · día 14: 405 · día 28: 520 (de 630). Los de frenesí y secretos usan un día estimado, no simulado.

Detalle día por día:

```
3.0 golpes/s, semilla 1. El árbol entero cuesta 1089 reliquias.
día | reliquias ganadas (gastadas) | estrellas | niveles | resets | bajada típica | prof. récord | logros (fragmentos) | se vuelve desde
  primer reset a los 43:12: 7 reliquias (con fragmentos) → encendió core, f_brazo, f_templado, f_ojo, o_olfato, o_botin, c_reclutas, sobran 0
  1 |    10 (7) |  7 |   7 |   1 |  43:12 | 340 m | 21 (60) | 300 m
  2 |    34 (34) | 11 |  22 |   7 |  10:22 | 397 m | 30 (107) | 306 m
  3 |    87 (87) | 14 |  43 |  20 |   4:36 | 397 m | 33 (116) | 321 m
  4 |   157 (157) | 15 |  58 |  37 |   3:38 | 433 m | 36 (138) | 340 m
  5 |   244 (236) | 20 |  69 |  57 |   3:10 | 464 m | 41 (195) | 362 m
  6 |   322 (317) | 21 |  76 |  76 |   3:10 | 485 m | 43 (210) | 384 m
  7 |   396 (390) | 23 |  81 |  92 |   3:56 | 525 m | 48 (275) | 402 m
  8 |   452 (448) | 24 |  84 | 106 |   4:08 | 525 m | 49 (280) | 417 m
  9 |   508 (494) | 24 |  86 | 121 |   3:56 | 553 m | 50 (305) | 432 m
 10 |   567 (549) | 26 |  88 | 135 |   4:32 | 553 m | 53 (335) | 448 m
 11 |   609 (609) | 28 |  90 | 148 |   4:32 | 553 m | 53 (335) | 460 m
 12 |   650 (609) | 28 |  90 | 160 |   4:58 | 553 m | 54 (360) | 470 m
 13 |   691 (669) | 29 |  91 | 172 |   5:02 | 564 m | 56 (395) | 481 m
 14 |   725 (669) | 29 |  91 | 183 |   5:34 | 564 m | 57 (405) | 490 m
 15 |   766 (729) | 30 |  92 | 194 |   5:10 | 574 m | 59 (415) | 500 m
 16 |   794 (789) | 31 |  93 | 204 |   5:44 | 574 m | 59 (415) | 508 m
 17 |   819 (789) | 31 |  93 | 210 |  11:36 | 588 m | 59 (415) | 513 m
 18 |   843 (789) | 31 |  93 | 217 |   8:54 | 588 m | 59 (415) | 518 m
 19 |   876 (849) | 32 |  94 | 223 |  10:50 | 588 m | 60 (425) | 522 m
 20 |   907 (849) | 32 |  94 | 229 |  10:30 | 591 m | 62 (460) | 527 m
 21 |   925 (909) | 33 |  95 | 234 |   9:48 | 591 m | 63 (470) | 530 m
 22 |   961 (909) | 33 |  95 | 240 |   9:30 | 607 m | 64 (495) | 534 m
 23 |   980 (969) | 34 |  96 | 245 |  12:06 | 607 m | 64 (495) | 538 m
 24 |  1012 (969) | 34 |  96 | 250 |  13:06 | 609 m | 64 (495) | 542 m
 25 |  1031 (1029) | 35 |  97 | 255 |  12:02 | 610 m | 64 (495) | 545 m
 26 |  1056 (1029) | 35 |  97 | 260 |  11:52 | 610 m | 64 (495) | 549 m
 27 |  1085 (1029) | 35 |  97 | 264 |  16:18 | 610 m | 65 (520) | 552 m
 28 |  1093 (1089) | 36 |  98 | 265 |  16:02 | 620 m | 65 (520) | 553 m

Hitos (día de juego, horas jugadas):
  anillo 2 abierto: día 3 (2.0 h)
  anillo 3 abierto: día 4 (3.3 h)
  anillo 1 completo: día 6 (5.2 h)
  anillo 2 completo: día 10 (9.2 h)
  primera piedra angular: día 13 (12.4 h)
  primer puente: día 21 (20.2 h)
  anillo 3 completo: día 19 (18.2 h)
  completo: día 28 (27.1 h)

Cofres: 5081 · oro de cofres 38156742802516.12 · reliquias de cofres 134
Logros: 70 en total = 630 fragmentos = 63 reliquias. Sin conseguir: La roca te teme (300.000 golpes), Leyenda viva (100 Legendarios), Mochila llena (10 reliquias en una sola bajada), Museo ambulante (20 reliquias en una sola bajada), Cielo completo (Árbol completo)
Fragmentos acumulados: día 1: 21 logros, 60 frag. · día 2: 30 logros, 107 frag. · día 3: 33 logros, 116 frag. · día 7: 48 logros, 275 frag. · día 14: 57 logros, 405 frag. · día 21: 63 logros, 470 frag. · día 28: 65 logros, 520 frag. · día 35: 65 logros, 520 frag.

Bajada nueva (mediana de 5): momento | reliquias | 300 m sin árbol → con árbol | 400 m sin árbol → con árbol
```

### Cómo se acortan las bajadas con el árbol (bajada nueva, mediana de 5)
| Momento | Reliquias ganadas | 300 m: sin árbol → con árbol | 400 m: sin árbol → con árbol |
|---|---|---|---|


**Problema abierto:** desde el anillo 1 completo, llegar a 300 m tarda menos de un minuto. En la partida las bajadas duran 3–16 min porque la profundidad para volver se va corriendo, pero conviene revisar las estrellas multiplicativas antes de programar. (Los momentos "sin árbol" usan solo el bonus histórico.)

### Estrella por estrella (propuesta final)
Cuánto acorta una bajada nueva pasar la estrella de 0 al máximo, con las demás de su anillo y anteriores al máximo. 3 semillas.

| Estrella | Anillo | Costo | 3 golpes/s | 5 golpes/s | 1 golpe/s |
|---|---|---|---|---|---|
| core | 0 | 1 | 300 m: 29:19 → 19:18 (+34%) | +33% | +34% |
| f_brazo | 1 | 13 | 300 m: 0:53 → 0:50 (+6%) | +28% | +7% |
| f_templado | 1 | 13 | 300 m: 0:57 → 0:50 (+13%) | +28% | +7% |
| f_ojo | 1 | 13 | 300 m: 0:53 → 0:50 (+5%) | +0% | +0% |
| f_brutal | 2 | 53 | 350 m: 0:53 → 0:45 (+15%) | +25% | +12% |
| f_eco | 2 | 29 | 350 m: 1:01 → 0:44 (+27%) | +18% | +9% |
| f_combo | 3 | 48 | 400 m: 1:27 → 1:07 (+23%) | +16% | +0% |
| f_umbral | 3 | 20 | 400 m: 1:23 → 1:06 (+20%) | +0% | +0% |
| f_furia | 3 | 60 | 400 m: 1:06 → 0:53 (+20%) | +16% | +13% |
| o_olfato | 1 | 13 | 300 m: 0:51 → 0:50 (+1%) | +0% | +7% |
| o_botin | 1 | 13 | 300 m: 0:53 → 0:50 (+5%) | +0% | +7% |
| o_gemologo | 1 | 10 | 300 m: 0:50 → 0:50 (+0%) | +0% | +0% |
| o_dragon | 2 | 29 | 350 m: 0:44 → 0:44 (+0%) | +0% | +0% |
| o_doble | 2 | 29 | 350 m: 0:50 → 0:44 (+11%) | +17% | +2% |
| o_corona | 3 | 38 | 400 m: 1:07 → 1:07 (+0%) | +0% | +0% |
| o_reliquia | 3 | 30 | 400 m: 1:07 → 1:07 (+0%) | +0% | +0% |
| o_apostador | 3 | 60 | 400 m: 1:06 → 1:01 (+9%) | +11% | +10% |
| c_reclutas | 1 | 13 | 300 m: 0:51 → 0:50 (+2%) | +1% | +0% |
| c_capataz | 1 | 27 | 300 m: 1:32 → 0:50 (+45%) | +45% | +48% |
| c_contrato | 1 | 13 | 300 m: 0:53 → 0:50 (+6%) | +0% | +7% |
| c_bolsa | 1 | 10 | 300 m: 0:54 → 0:50 (+7%) | +0% | +11% |
| c_ventaja | 2 | 38 | 350 m: 0:46 → 0:46 (-1%) | +5% | +13% |
| c_hitos | 2 | 25 | 350 m: 0:49 → 0:44 (+10%) | +15% | +14% |
| c_memoria | 3 | 30 | 400 m: 1:07 → 1:07 (+0%) | +0% | +0% |
| c_mina | 3 | 60 | 400 m: 1:06 → 1:15 (-12%) | -23% | +19% |
| t_mecha | 1 | 13 | 300 m: 0:50 → 0:50 (+0%) | +0% | +26% |
| t_polvora | 1 | 13 | 300 m: 0:53 → 0:50 (+5%) | +0% | +19% |
| t_vigilia | 1 | 10 | 300 m: 0:50 → 0:50 (+0%) | +0% | +0% |
| t_noche | 2 | 20 | 350 m: 0:44 → 0:44 (+0%) | +0% | +0% |
| t_descenso | 2 | 15 | 350 m: 0:46 → 0:44 (+4%) | +2% | +10% |
| t_memoria_din | 3 | 30 | 400 m: 1:07 → 1:07 (+0%) | +0% | +0% |
| t_cuenta | 3 | 60 | 400 m: 1:06 → 1:02 (+7%) | +5% | +13% |
| p_suerte | 4 | 60 | 400 m: 1:06 → 1:02 (+7%) | +15% | +10% |
| p_mineros | 4 | 60 | 400 m: 1:06 → 1:06 (+0%) | +0% | +9% |
| p_turnos | 4 | 60 | 400 m: 1:06 → 1:06 (+0%) | +0% | +0% |
| p_critica | 4 | 60 | 400 m: 1:06 → 1:06 (+0%) | +10% | +12% |

Lectura:
- **Demasiado fuerte:** c_capataz (+45% por 27 reliquias). El Corazón (+34% por 1) es a propósito.
- **Perjudica:** c_mina (−12% y −23% jugando activo; solo ayuda a 1 golpe/s). Propuesta, sin simular: golpes ×0,5 en vez de ×0,25.
- **Casi sin efecto en esta prueba:** o_gemologo, o_dragon, o_olfato, p_mineros. Hay que subirles los números.
- **Esta prueba no las mide** (no dan 0 de verdad): c_memoria y t_memoria_din (actúan al volver), t_vigilia, t_noche y p_turnos (AFK), o_corona y o_reliquia (dan reliquias).
- Las de anillo 1 se miden sobre bajadas de ~50 s, así que sus porcentajes tienen mucho ruido.

### Falta
1. Repetir la corrida final con otras semillas y a 1,5 y 5 golpes/s (hay una sola partida).
2. Ajustar c_mina, c_capataz y las de Fortuna, y volver a medir.
3. Medir las estrellas que esta prueba no cubre.
4. Decidir si el primer reset puede encender 7 estrellas o si los fragmentos tempranos bajan.


## Logros propuestos
70 logros, 630 fragmentos = **63 reliquias** en total. Fácil 2, medio 5, difícil 10, épico 25.

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
