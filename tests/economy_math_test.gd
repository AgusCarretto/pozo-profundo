extends "res://tests/test_base.gd"
## Tests headless de las fórmulas puras de core/economy_math.gd y de la estructura de data/balance.json.

const EconomyMath := preload("res://core/economy_math.gd")

const GROWTH: float = 1.15
const BALANCE_PATH: String = "res://data/balance.json"


func _initialize() -> void:
	_test_single_unit_cost()
	_test_bulk_cost()
	_test_max_affordable_known_values()
	_test_max_affordable_boundaries()
	_test_max_affordable_degenerate_inputs()
	_test_pick_cost()
	_test_hit_value()
	_test_balance_file()
	_finish()


func _test_single_unit_cost() -> void:
	_section("Costo de una unidad")
	_check_near(EconomyMath.bulk_cost(15.0, GROWTH, 0, 1), 15.0, "minero #1 cuesta el costo base (15)")
	_check_near(EconomyMath.bulk_cost(15.0, GROWTH, 3, 1), 15.0 * pow(GROWTH, 3), "con 3 mineros el siguiente cuesta 15 * 1.15^3")


func _test_bulk_cost() -> void:
	_section("Costo de comprar k unidades")
	_check_near(EconomyMath.bulk_cost(15.0, GROWTH, 0, 10), 304.5557735836, "10 mineros desde 0 cuestan ~304.56", 1e-9)
	var sum_of_singles: float = 0.0
	for i: int in range(10):
		sum_of_singles += EconomyMath.bulk_cost(120.0, GROWTH, 4 + i, 1)
	_check_near(EconomyMath.bulk_cost(120.0, GROWTH, 4, 10), sum_of_singles, "comprar 10 juntos = sumar 10 compras de a una")
	_check_eq(EconomyMath.bulk_cost(15.0, GROWTH, 5, 0), 0.0, "comprar 0 unidades cuesta 0")


func _test_max_affordable_known_values() -> void:
	_section("Compra máxima: valores conocidos")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 15.0), 1, "con 15 de oro se compra 1 minero")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 14.99), 0, "con 14.99 no se compra ninguno")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 304.56), 10, "con 304.56 se compran 10 mineros")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 304.55), 9, "con 304.55 se compran solo 9")


## Cada combinación (generador, cantidad ya comprada, k) se prueba en el borde exacto:
## con el oro justo para k se compran k; con una pizca menos, k - 1.
func _test_max_affordable_boundaries() -> void:
	_section("Compra máxima: bordes exactos")
	var base_costs: Array[float] = [15.0, 120.0, 1300.0, 14000.0, 160000.0]
	var owned_values: Array[int] = [0, 1, 7, 50, 200, 1000, 2000]
	var counts: Array[int] = [1, 2, 10, 37]
	var failures_before: int = _failures
	var combos: int = 0
	for base_cost: float in base_costs:
		for owned: int in owned_values:
			for k: int in counts:
				var exact: float = EconomyMath.bulk_cost(base_cost, GROWTH, owned, k)
				var below: float = exact * (1.0 - 1e-12)
				var label: String = "base=%s owned=%d k=%d" % [str(base_cost), owned, k]
				var at_exact: int = EconomyMath.max_affordable(base_cost, GROWTH, owned, exact)
				var at_below: int = EconomyMath.max_affordable(base_cost, GROWTH, owned, below)
				combos += 1
				if at_exact != k:
					_check_eq(at_exact, k, "oro justo, " + label)
				if at_below != k - 1:
					_check_eq(at_below, k - 1, "oro apenas menos, " + label)
	_check(_failures == failures_before, "%d combinaciones respetan el borde exacto (k con oro justo, k-1 con una pizca menos)" % combos)

	# Invariante general: lo que devuelve se puede pagar y una unidad más no.
	var invariant_ok: bool = true
	for gold: float in [20.0, 999.0, 1.0e5, 3.3e9, 1.0e15, 7.7e30, 1.0e100]:
		for owned: int in owned_values:
			var k: int = EconomyMath.max_affordable(120.0, GROWTH, owned, gold)
			var affordable: bool = k == 0 or EconomyMath.bulk_cost(120.0, GROWTH, owned, k) <= gold
			var next_too_expensive: bool = EconomyMath.bulk_cost(120.0, GROWTH, owned, k + 1) > gold
			if not (affordable and next_too_expensive):
				invariant_ok = false
				printerr("    invariante rota: gold=%s owned=%d k=%d" % [str(gold), owned, k])
	_check(invariant_ok, "max_affordable(oro) siempre paga k y nunca alcanza para k+1")


func _test_max_affordable_degenerate_inputs() -> void:
	_section("Compra máxima: entradas límite")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, 0.0), 0, "con 0 de oro no se compra nada")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, -50.0), 0, "oro negativo no compra nada")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, NAN), 0, "oro NaN no compra nada")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 0, INF), 0, "oro infinito no explota (devuelve 0)")
	_check_eq(EconomyMath.max_affordable(15.0, GROWTH, 100000, 1.0e300), 0, "costo que desborda a infinito no se puede comprar")
	var big_cost: float = EconomyMath.bulk_cost(15.0, GROWTH, 2000, 1)
	_check(is_finite(big_cost) and big_cost > 1.0e100, "con 2000 unidades el costo sigue siendo finito (%s)" % str(big_cost))


func _test_pick_cost() -> void:
	_section("Costo del pico")
	_check_eq(EconomyMath.pick_cost(0, 50.0, 6.0), 50.0, "nivel 0 -> 50")
	_check_eq(EconomyMath.pick_cost(1, 50.0, 6.0), 300.0, "nivel 1 -> 300")
	_check_eq(EconomyMath.pick_cost(2, 50.0, 6.0), 1800.0, "nivel 2 -> 1800")
	_check(is_finite(EconomyMath.pick_cost(300, 50.0, 6.0)), "nivel 300 sigue siendo finito")


func _test_hit_value() -> void:
	_section("Valor del golpe")
	_check_eq(EconomyMath.hit_value(0, 2.0, 1.0, 0.0, 0.03), 1.0, "nivel 0 sin cuadrilla = 1")
	_check_eq(EconomyMath.hit_value(3, 2.0, 1.0, 0.0, 0.03), 8.0, "nivel 3 sin cuadrilla = 2^3 = 8")
	_check_near(EconomyMath.hit_value(3, 2.0, 1.0, 100.0, 0.03), 11.0, "nivel 3 con 100 oro/s = 8 + 3% de 100")
	_check_near(EconomyMath.hit_value(3, 2.0, 2.0, 100.0, 0.03), 19.0, "el multiplicador solo escala la parte del pico: 16 + 3")


## Valida la estructura y la coherencia del balance, no los valores exactos:
## así se puede ajustar el balance sin tocar el test.
func _test_balance_file() -> void:
	_section("data/balance.json")
	_check(FileAccess.file_exists(BALANCE_PATH), "existe " + BALANCE_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	_check(parsed is Dictionary, "es un objeto JSON válido")
	if not (parsed is Dictionary):
		return
	var balance: Dictionary = parsed
	_check(float(balance.get("cost_growth", 0.0)) > 1.0, "cost_growth > 1")
	var generators: Array = balance.get("generators", [])
	_check_eq(generators.size(), 5, "hay 5 generadores")
	var coherent: bool = true
	var previous_rate: float = 0.0
	var previous_cost: float = 0.0
	var ids: Dictionary = {}
	for entry: Variant in generators:
		var gen: Dictionary = entry
		var rate: float = float(gen.get("base_rate", 0.0))
		var cost: float = float(gen.get("base_cost", 0.0))
		var id: String = str(gen.get("id", ""))
		if id == "" or ids.has(id) or str(gen.get("name", "")) == "" or rate <= previous_rate or cost <= previous_cost:
			coherent = false
		ids[id] = true
		previous_rate = rate
		previous_cost = cost
	_check(coherent, "ids únicos, nombres presentes, y oro/s y costo base estrictamente crecientes")
	var pick: Dictionary = balance.get("pick", {})
	for key: String in ["power_base", "cost_base", "cost_growth", "passive_share"]:
		_check(float(pick.get(key, 0.0)) > 0.0, "pick.%s > 0" % key)
