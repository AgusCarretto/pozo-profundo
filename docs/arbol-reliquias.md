# Árbol de reliquias — especificación (v0.7)

Escrito para: vos y quien programe la v0.7. Estado al 2026-11-26: **números aprobados, sin programar**.
Los números salen de la simulación (`tools/tree_sim/arbol_v3.json` y `logros.json`; resultados en [v07-simulacion.md](v07-simulacion.md)). Al programar pasan a `data/`.

## Definiciones que agregué (revisalas)
La simulación necesitaba menos detalle que el juego. Estas reglas son propuesta mía:
1. **Veta rica no se aplica al AFK.** En la simulación sí se aplicaba (y triplicaba todo el AFK aunque cruzara la línea); quitarlo no cambia el piso ni el ritmo.
2. **A la par:** "mientras golpeás" = algún golpe en los últimos 5 s.
3. **Un golpe que pasa el tope** no cuenta para nada.
4. **Testers:** quien ya tiene reliquias cuenta como un reset hecho; si no, el Corazón quedaría trabado hasta volver otra vez.

## 1. Concepto
- Un "cielo" de estrellas donde se gastan las reliquias en mejoras permanentes.
- Un centro, **4 ramas** (Fuerza, Fortuna, Cuadrilla, Tiempo), **piedras angulares** al final de cada rama y **puentes** entre ramas vecinas.
- Se revela de a poco: niebla y anillos que se abren con hitos de juego.
- Junto con el árbol entran los **logros** y los **fragmentos de reliquia**.
- Las reliquias **dejan de dar +25% de oro**: son la moneda del árbol (con un bonus pasivo chico, sección 6).

## 2. Ritmo (simulado, 1 h por día)
| Golpes/s | Árbol completo | Bajada mediana hasta poder volver (antes de completar el anillo 2) |
|---|---|---|
| 1,5 | día 33–34 | 14:30–15:00 |
| 3 | día 27–28 | 11:40–12:20 |
| 3 con pausas | día 30–31 | 13:20–13:45 |
| 5 | día 20–21 | 8:20–8:30 |
| 6 (techo) | día 18–20 | 7:30–7:50 |

- Primer reset (~45 min): alcanza para el Corazón y 1–2 estrellas.
- A 3 golpes/s, ninguna bajada de menos de ~10 min hasta completar el anillo 2 (0–9% quedan por debajo, la más corta 7:56). Después pueden acortarse.
- El jugador activo es el más beneficiado.

## 3. Estructura y desbloqueo
**1008 reliquias en 125 compras.** Anillo 1: 138 · anillo 2: 272 · anillo 3: 397 · puentes: 200 · Corazón: 1. Costo del nivel n = redondear(base × crecimiento^(n−1)); las tablas ya traen el resultado.

| Anillo | Qué contiene | Se abre con |
|---|---|---|
| 0 | Corazón | Primer reset |
| 1 | Primeras estrellas de cada rama | Comprar el Corazón |
| 2 | Estrellas intermedias | Récord ≥ 350 m **y** 8 resets |
| 3 | Estrellas avanzadas y piedras angulares | Récord ≥ 400 m **y** 25 resets |
| 4 | Puentes | Tener las dos piedras angulares que une |

- **Prerrequisitos:** al menos una de las estrellas de "Requiere" con nivel ≥ 1; las piedras angulares piden la anterior al máximo.
- **Niebla:** comprada = encendida con el color de su rama; disponible (anillo abierto y requisito cumplido) = nombre, efecto y costo; más lejos o en anillo cerrado = apagada con "?" (en un anillo cerrado, al tocarla se ve el requisito).

## 4. Las estrellas
### Centro
| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total | Requiere |
|---|---|---|---|---|---|---|
| `core` | Corazón del pozo | +50% de oro | 0 | 1 | 1 | primer reset |

### Fuerza (golpes)
| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total | Requiere |
|---|---|---|---|---|---|---|
| `f_brazo` | Brazo fuerte | cada golpe suma +1,2% del oro/s (además del 6% de hoy) | 1 | 2, 2, 3, 3, 3 | 13 | Corazón del pozo |
| `f_templado` | Pico templado | +30% de golpe | 1 | 2, 2, 3, 3, 3 | 13 | Brazo fuerte |
| `f_ojo` | Ojo certero | +3% de chance de crítico | 1 | 2, 2, 3, 3, 3 | 13 | Brazo fuerte |
| `f_brutal` | Golpe brutal | +0,6× de daño crítico | 2 | 5, 6, 7, 8, 9 | 35 | Ojo certero |
| `f_eco` | Eco | +6% de chance de que el golpe valga doble | 2 | 5, 6, 7, 8, 9, 10 | 45 | Pico templado |
| `f_combo` | Combo | en frenesí, +12% de golpe | 3 | 6, 6, 7, 8, 8, 9, 10, 10 | 64 | Eco |
| `f_umbral` | Mano rápida | el frenesí pide 1 golpe/s menos | 3 | 15 | 15 | Combo o Golpe brutal |
| `f_furia` | Furia ciega (piedra angular) | daño crítico ×4 y la mitad de chance | 3 | 40 | 40 | Mano rápida al máximo |

### Fortuna (cofres)
| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total | Requiere |
|---|---|---|---|---|---|---|
| `o_olfato` | Olfato | +20% de chance de cofre (golpes y cuadrilla) | 1 | 2, 2, 3, 3, 3 | 13 | Corazón del pozo |
| `o_botin` | Botín generoso | +25% de oro por cofre | 1 | 2, 2, 3, 3, 3 | 13 | Olfato |
| `o_gemologo` | Gemólogo | +50% de Raros | 1 | 2, 2, 3 | 7 | Olfato |
| `o_dragon` | Corazón de dragón | +40% de Épicos | 2 | 5, 6, 7, 8, 9, 10 | 45 | Gemólogo |
| `o_doble` | Doble cofre | +6% de chance de que salga doble | 2 | 5, 6, 7, 8, 9, 10 | 45 | Botín generoso |
| `o_corona` | Corona | +25% de Legendarios | 3 | 6, 6, 7, 8, 8, 9, 10, 10 | 64 | Corazón de dragón |
| `o_reliquia` | Reliquia escondida | +20% de chance de +1 reliquia por Legendario | 3 | 7, 8, 8, 9, 10 | 42 | Corona o Doble cofre |
| `o_apostador` | Apostador (piedra angular) | no salen Comunes; los demás salen el doble de seguido | 3 | 40 | 40 | Reliquia escondida al máximo |

### Cuadrilla
| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total | Requiere |
|---|---|---|---|---|---|---|
| `c_capataz` | Capataz | +5% de producción de la cuadrilla | 1 | 2, 2, 3, 3, 3 | 13 | Corazón del pozo |
| `c_contrato` | Contrato barato | −4% de costo de la cuadrilla | 1 | 2, 2, 3, 3, 3 | 13 | Capataz |
| `c_bolsa` | Bolsa inicial | empezás con 10 / 20 / 40 s del oro/s con el que volviste | 1 | 2, 2, 3 | 7 | Contrato barato |
| `c_ventaja` | Ventaja inicial | empezás con el 25 / 50 / 75% de la cuadrilla que tenías, mineros incluidos | 2 | 8, 10, 14 | 32 | Capataz |
| `c_hitos` | Hitos dorados | cada hito multiplica ×2,1 / 2,2 / 2,3 / 2,4 / 2,5 en vez de ×2 | 2 | 6, 7, 8, 9, 10 | 40 | Capataz o Contrato barato |
| `c_memoria` | Memoria | conservás el nivel del Pico y de la Dinamita | 3 | 10 | 10 | Hitos dorados |
| `c_mina` | A la par (piedra angular) | la cuadrilla rinde ×1,3 mientras golpeás y ×0,7 si no (también AFK) | 3 | 40 | 40 | Memoria al máximo |

### Tiempo (AFK y dinamita)
| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total | Requiere |
|---|---|---|---|---|---|---|
| `t_mecha` | Mecha corta | −8% de recarga de la dinamita | 1 | 2, 2, 3, 3, 3 | 13 | Corazón del pozo |
| `t_polvora` | Pólvora | +20% de dinamita | 1 | 2, 2, 3, 3, 3 | 13 | Mecha corta |
| `t_vigilia` | Vigilia | AFK al 7 / 9 / 12% | 1 | 2, 2, 3 | 7 | Corazón del pozo |
| `t_noche` | Turno noche | tope AFK de 10 / 12 h | 2 | 8, 10 | 18 | Vigilia |
| `t_veta` | Veta rica | oro ×3 hasta el 95% de la meta | 2 | 12 | 12 | Pólvora |
| `t_racha` | Racha | +2% de oro por cada minuto golpeando sin parar; tope 6 / 12 / 18 / 24 / 30% | 3 | 7, 8, 8, 9, 10 | 42 | Veta rica o Turno noche |
| `t_cuenta` | Cuenta regresiva (piedra angular) | la dinamita recarga en la mitad y paga 10% menos | 3 | 40 | 40 | Racha al máximo |

### Puentes (anillo 4)
| id | Nombre | Efecto por nivel | Anillo | Costo por nivel | Total | Requiere |
|---|---|---|---|---|---|---|
| `p_suerte` | Golpe de suerte | cada crítico tiene 3% de chance de soltar un cofre | 4 | 50 | 50 | tener Furia ciega y Apostador |
| `p_mineros` | Mineros con suerte | el doble de cofres de la cuadrilla | 4 | 50 | 50 | tener Apostador y A la par |
| `p_turnos` | Turnos rotativos | +50% de oro AFK | 4 | 50 | 50 | tener A la par y Cuenta regresiva |
| `p_critica` | Dinamita crítica | la dinamita puede salir crítica | 4 | 50 | 50 | tener Cuenta regresiva y Furia ciega |

### Reglas de los efectos
- Los porcentajes de una estrella **suman** entre niveles; estrellas distintas multiplican.
- **Cofres:** el peso extra de Raros, Épicos y Legendarios sale de los Comunes. Con Apostador no hay Comunes y los demás salen el doble de seguido que antes. Un cofre doble paga también sus reliquias dos veces.
- **Arrastre** (Bolsa, Ventaja, Memoria): al volver se guarda cuadrilla, oro/s de la cuadrilla, Pico y Dinamita, y se aplica al empezar la bajada siguiente (también a una estrella comprada justo al volver). El oro de la Bolsa no cuenta para la profundidad. Las cantidades de Ventaja se redondean hacia abajo.
- **Veta rica:** triplica todo el oro ganado (golpes, cuadrilla, cofres y dinamita; no el AFK) mientras la profundidad esté por debajo del 95% de la meta.
- **Racha:** multiplica todo el oro. Sube un escalón por minuto entero; se corta con 5 s sin golpear y al volver a la superficie; no corre AFK.
- **A la par:** "mientras golpeás" = algún golpe en los últimos 5 s.

## 5. Piedras angulares y reasignar
- Ventaja y desventaja. **Máximo 2 activas**; se pueden comprar las 4. Se cambian solo en la superficie, justo después de un reset.
- Los puentes piden tener **compradas** las dos piedras angulares que unen, no activas.
- "Reasignar estrellas": devuelve todas las reliquias gastadas (salvo el Corazón). Gratis la primera vez; después cuesta 10% de lo devuelto. Solo en la superficie. *(Sin simular.)*

## 6. Reliquias y meta de volver
- **Bonus histórico:** cada reliquia ganada en la historia (gastada o no) da +6% de oro hasta 60, y +0,5% desde ahí. Gastar nunca debilita.
- **Meta:** profundidad desde la que se puede volver. Depende de las reliquias **sacadas de bajadas** (las de cofres y logros no la corren), se fija al empezar cada bajada y se muestra como **"Próximo regreso a X m"** (en juego y en la confirmación). Lineal entre puntos, redondeada; 300 m con 0–3 reliquias; más allá del último punto sigue la pendiente del último tramo.

| Reliquias sacadas de bajadas | 3 | 6 | 9 | 12 | 20 | 40 | 65 | 100 | 180 | 300 | 500 | 700 | 1000 | 1400 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Meta (m) | 300 | 320 | 322 | 333 | 356 | 427 | 443 | 471 | 487 | 501 | 520 | 558 | 594 | 635 |

- **Reliquias por bajada:** con `corrida = meta − 300` y `d = profundidad − corrida`: si `d ≥ 300`, `floor(((d − 200) / 50)^1.3) + floor(corrida / 30)`. Más hondo paga más.
- Más allá de 400 m todo es Abismo (la partida termina cerca de 580 m). Mapas nuevos: más adelante.

## 7. AFK
- Base **5%** (hoy 25%); Vigilia 7 / 9 / 12%; tope 8 h, con Turno noche 10 / 12 h; Turnos rotativos +50%.
- Los primeros 2 min siguen pagando completo. El AFK no abre cofres.

## 8. Tope de golpes y frenesí
- **Máximo 6 golpes en el último segundo** (ventana deslizante). No pedir 1/6 s entre golpes: quien golpea a 4,5/s perdería golpes y casi un quinto del frenesí.
- Un golpe que pasa el tope no cuenta para nada (oro, cofres, frenesí, logros).
- El frenesí sigue en 4 golpes/s (3 con Mano rápida). Hoy solo cambia la música; con Combo y Mano rápida también da oro, así que su medición pasa a ser parte de las reglas.

## 9. Logros y fragmentos
- **20 fragmentos = 1 reliquia** (automático). Fácil 2, medio 5, difícil 10, épico 25.
- 70 logros, 630 fragmentos = 31 reliquias.
- Pantalla de logros con progreso ("3.412 / 10.000 golpes"). Aviso con sonido al conseguir uno; en el primer reset salen unos 20 juntos, así que los avisos se **agrupan**.
- Los **Secretos** están ocultos hasta conseguirlos.
- **Leyenda viva** y **La roca te teme** quedan, a propósito, para después de completar el árbol.

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

**Contadores históricos** (para logros y para los Puntos de Leyenda de v0.8): golpes, críticos, oro ganado, profundidad récord, resets, reliquias ganadas, cofres por rareza, usos de dinamita, segundos de frenesí, máximo de cada generador, tiempo jugado, **tiempo activo** (segundos con algún golpe en los últimos 5 s), **tiempo AFK** (segundos acreditados como ausencia) y **máximo de golpes/s sostenido** (mejor promedio en 10 s, contando también los que pasan el tope).

## 10. Visual y experiencia
- Pantalla propia: cielo oscuro con estrellas y líneas tenues entre estrellas conectadas; puentes con línea punteada; piedras angulares más grandes (distinguidas por forma y tamaño: la fuente del juego no tiene "★").
- Un color por rama. **Pendiente:** la regla del juego reserva verde para "se puede comprar" y rojo para el prestigio, así que las ramas no pueden usar esos dos tonos en botones.
- Zoom con pellizco y arrastre; botón para centrar en el Corazón. Botones de 96 px de diseño o más.
- Tocar una estrella: panel con nombre, efecto actual → siguiente nivel, costo y botón Comprar.
- Al comprar: destello, partículas y un sonido "celestial" que sube de tono con el nivel. Al abrirse un anillo: la niebla se barre y sale "¡Nueva zona del cielo!".
- Acceso por el botón Reliquias. La confirmación de volver muestra cuántas reliquias ganás y un atajo "Ir al árbol".
- Respetar "reducir efectos".

## 11. Datos y guardado
- `data/arbol.json` (estrellas, posiciones, efectos, costos, anillos, prerrequisitos, meta, bonus) y `data/logros.json`. Nada de números en el código.
- Los efectos se aplican en `core/Economy` con una capa de modificadores por tipo (sumas y multiplicadores), no con `if` por estrella. `core/` no depende de `game/`.
- Guardado: niveles por id, piedras activas, reliquias ganadas, gastadas y sacadas de bajadas, meta de la bajada en curso, arrastre de la bajada anterior, fragmentos, logros y contadores.
- **Partidas de v0.6:** conservan sus reliquias para gastarlas; cuentan para el bonus histórico y como sacadas de bajadas; un cartel lo avisa la primera vez. Quien ya tenía reliquias cuenta como un reset hecho (el Corazón queda disponible); el resto de los contadores arranca en cero.

## 12. Tests y validación
- Tests: prerrequisitos, apertura de anillos, niebla, costos, cada tipo de efecto, límite de piedras angulares, reasignar, meta y reliquias por bajada, conversión de fragmentos, logros, tope de golpes, compatibilidad de guardados.
- Cualquier cambio de estrellas pide recalibrar la meta (`tools/tree_sim/calibrate.mjs`) y volver a simular.
- Capturas en vertical: árbol al inicio, anillo 1 completo, con niebla y avanzado.
