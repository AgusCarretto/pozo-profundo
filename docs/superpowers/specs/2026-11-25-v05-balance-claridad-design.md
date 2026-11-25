# v0.5 — Balance y claridad (aprobado el 2026-11-25)

## Para qué
Primera bajada larga (30–40 min de juego activo, volviendo a los 300 m), botín que se siente al instante y metas
visibles (hitos y generadores por descubrir). Feedback de los testers.

## Números (aprobados, salen de simular la economía)
- Profundidad `15 · log2(1 + oro / 8)`; bioma nuevo cada 100 m.
- Volver a la superficie desde 300 m; reliquias `floor(((p − 200) / 50)^1.3)` (2 a 300, 4 a 350, 6 a 400). +25% cada una.
- Crecimiento de precio de los generadores 1.15 (antes 1.2). Costos y oro/s base y pico: sin cambios.
- Críticos: 8% de chance, golpe ×2.
- AFK al 25%, tope 8 h. Los primeros 2 minutos de una ausencia pagan al 100%.
- Hitos: con 25, 50 y 100 unidades, ese generador produce ×2 cada vez (×2, ×4, ×8).
- Cofres: 0,3% por golpe y 1,5% por segundo con cuadrilla. Dan oro al instante: el mayor entre N segundos de
  cuadrilla y M golpes. Se elimina el bonus porcentual de botín.

| Rareza | Prob. | Segundos | Golpes | Reliquias |
|---|---|---|---|---|
| Común | 78% | 5 | 15 | 0 |
| Raro | 17% | 20 | 50 | 0 |
| Épico | 4,5% | 60 | 150 | 0 |
| Legendario | 0,5% | 200 | 500 | 1 |

- Lluvia de monedas al abrir un cofre, más grande cuanto más rara la rareza.
- Generadores ocultos como "???" hasta comprar el anterior. Lo revelado sigue revelado al volver a la superficie.
- Partidas guardadas antes de v0.5: reciben las reliquias que ya tenían ganadas con la regla vieja y la bajada se
  reinicia, con un aviso.
