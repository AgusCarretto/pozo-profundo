extends RefCounted
## Fórmulas puras de economía incremental: sin estado, sin autoloads y sin números de balance.
##
## Todo el balance (costos base, crecimiento, constantes del pico) llega por parámetro,
## desde res://data/. Código reutilizable entre juegos: no debe depender de nada de game/.


## Costo total de comprar `count` unidades teniendo `owned`:
## base * growth^owned * (growth^count - 1) / (growth - 1)
static func bulk_cost(base_cost: float, growth: float, owned: int, count: int) -> float:
	if count <= 0:
		return 0.0
	return base_cost * pow(growth, owned) * (pow(growth, count) - 1.0) / (growth - 1.0)


## Cantidad máxima de unidades que se pueden pagar con `gold`.
## Parte de la fórmula cerrada (logaritmo) y la corrige contra `bulk_cost`, así el
## error de redondeo de los floats nunca deja comprar de más ni de menos.
static func max_affordable(base_cost: float, growth: float, owned: int, gold: float) -> int:
	if not is_finite(gold) or gold <= 0.0:
		return 0
	# Se compara contra bulk_cost (no contra base * growth^owned): puede diferir en 1 ulp
	# por redondeo, y lo que muestra la UI como "costo de 1" es bulk_cost.
	var first_cost: float = bulk_cost(base_cost, growth, owned, 1)
	if not is_finite(first_cost) or gold < first_cost:
		return 0
	var estimate: float = log(gold * (growth - 1.0) / (base_cost * pow(growth, owned)) + 1.0) / log(growth)
	var count: int = maxi(int(floor(estimate)), 0)
	while count > 0 and bulk_cost(base_cost, growth, owned, count) > gold:
		count -= 1
	while bulk_cost(base_cost, growth, owned, count + 1) <= gold:
		count += 1
	return count


## Costo de subir el pico del nivel `level` al siguiente: cost_base * cost_growth^level.
static func pick_cost(level: int, cost_base: float, cost_growth: float) -> float:
	return cost_base * pow(cost_growth, level)


## Oro de un golpe: power_base^level * mult + passive_share * oro por segundo.
## `mult` (biomas, reliquias) escala solo la parte del pico; el oro/s ya viene multiplicado.
static func hit_value(level: int, power_base: float, mult: float, gold_per_second: float, passive_share: float) -> float:
	return pow(power_base, level) * mult + passive_share * gold_per_second
