extends "res://tests/test_base.gd"
## Tests headless de la profundidad y los biomas en core/economy.gd.
##
## Cada test crea su propia instancia de Economy SIN agregarla al árbol (no corre _ready(),
## no toca el disco ni el autoload Save). El balance es el de tests/test_balance.gd, sin
## botín: así el azar de los cofres no mueve el oro.

const EconomyScript := preload("res://core/economy.gd")
const TestBalance := preload("res://tests/test_balance.gd")

var _nodes: Array[Node] = []


func _initialize() -> void:
	_test_initial_state()
	_test_run_gold_counts_only_earnings()
	_test_depth_follows_run_gold()
	_test_biome_changes_with_depth()
	_test_last_biome_is_kept()
	_test_next_biome_progress()
	_test_biome_multiplier_scales_income()
	_test_earning_pushes_into_the_next_biome()
	_test_serialization()
	_test_old_saves_without_run_gold()
	_test_from_dict_tolerates_garbage()
	_test_reset_clears_the_run()
	_test_balance_validation()
	_test_without_depth_sections()
	_test_real_balance_file()
	for node: Node in _nodes:
		node.free()
	_finish()


func _make(balance: Dictionary = TestBalance.make(["loot"])) -> EconomyScript:
	var economy: EconomyScript = EconomyScript.new()
	_nodes.append(economy)
	if not economy.load_balance(balance):
		printerr("    el balance de prueba no cargó: ", economy.last_error)
	return economy


func _test_initial_state() -> void:
	_section("Estado inicial")
	var e: EconomyScript = _make()
	_check_eq(e.run_gold, 0.0, "0 de oro ganado en la partida")
	_check_eq(e.depth(), 0.0, "0 m de profundidad")
	_check_eq(e.biome_count(), 5, "5 biomas")
	_check_eq(e.biome_index(), 0, "bioma 0")
	_check_eq(e.biome_name(e.biome_index()), "Tierra", "arranca en Tierra")
	_check_eq(e.biome_multiplier(), 1.0, "Tierra multiplica x1")
	_check_eq(e.multiplier, 1.0, "multiplicador global x1")
	_check_eq(e.biome_id(0), "earth", "el id del bioma 0 es earth (la UI elige el arte por id)")
	_check_eq(e.biome_id(4), "abyss", "y el del 4 es abyss")
	_check_eq(e.biome_id(5), "", "un id inexistente es vacío")
	_check_eq(e.biome_name(99), "", "un bioma inexistente no tiene nombre (ni explota)")
	_check_eq(e.biome_name(-1), "", "un índice negativo tampoco")


## El oro ganado en la partida solo sube: gastar en compras no te hace subir de profundidad atrás.
func _test_run_gold_counts_only_earnings() -> void:
	_section("run_gold cuenta lo ganado, no lo que tenés")
	var e: EconomyScript = _make()
	e.hit()
	_check_eq(e.run_gold, 1.0, "un golpe suma 1")
	e.owned[0] = 10 # 10 oro/s
	e.tick(2.0)
	_check_near(e.run_gold, 21.0, "2 s de cuadrilla suman 20 más")
	var earned: float = e.run_gold
	e.gold = 500.0
	e.buy_generator(0, EconomyScript.BuyMode.X10)
	_check_eq(e.run_gold, earned, "comprar generadores no resta de run_gold")
	e.gold = 100000.0
	e.upgrade_pick()
	_check_eq(e.run_gold, earned, "mejorar el pico tampoco")
	e.tick(0.0)
	_check_eq(e.run_gold, earned, "un tick de 0 s no suma nada")


func _test_depth_follows_run_gold() -> void:
	_section("Profundidad = 25 * log2(1 + run_gold / 10)")
	var e: EconomyScript = _make()
	e.run_gold = 10.0
	_check_near(e.depth(), 25.0, "10 de oro ganado -> 25 m")
	e.run_gold = 30.0
	_check_near(e.depth(), 50.0, "30 -> 50 m")
	e.run_gold = 40950.0
	_check_near(e.depth(), 300.0, "40.950 -> 300 m", 1e-6)
	e.gold = 0.0 # el oro que tenés encima no cambia la profundidad
	_check_near(e.depth(), 300.0, "gastar todo el oro no baja la profundidad", 1e-6)


func _test_biome_changes_with_depth() -> void:
	_section("Bioma nuevo cada 150 m")
	var e: EconomyScript = _make()
	var expected: Array = [
		[0.0, 0, "Tierra"],
		[600.0, 0, "Tierra"], # ~148 m
		[700.0, 1, "Roca"], # ~154 m
		[41000.0, 2, "Cristal"], # ~300 m
		[2.7e6, 3, "Magma"], # ~450 m
		[1.8e8, 4, "Abismo"], # ~600 m
	]
	for case: Array in expected:
		e.run_gold = case[0]
		_check_eq(e.biome_index(), case[1], "con %s de oro ganado (%.0f m) el bioma es %s" % [str(case[0]), e.depth(), case[2]])
		_check_eq(e.biome_name(e.biome_index()), case[2], "y se llama %s" % case[2])


func _test_last_biome_is_kept() -> void:
	_section("Más allá del último bioma")
	var e: EconomyScript = _make()
	e.run_gold = 1.0e12 # ~913 m
	_check(e.depth() > 750.0, "pasa los 750 m (%.0f)" % e.depth())
	_check_eq(e.biome_index(), 4, "sigue siendo el último bioma")
	_check_eq(e.biome_name(e.biome_index()), "Abismo", "Abismo")
	_check_near(e.biome_multiplier(), 5.0625, "x1.5^4 = 5.0625")


## Lo que necesita la barra de profundidad del HUD: cuánto falta para el próximo bioma y cuál es.
func _test_next_biome_progress() -> void:
	_section("Progreso hacia el próximo bioma")
	var e: EconomyScript = _make()
	_check_eq(e.biome_progress(), 0.0, "en la superficie el progreso es 0")
	_check_eq(e.next_biome_index(), 1, "el próximo bioma es el 1")
	_check_eq(e.biome_name(e.next_biome_index()), "Roca", "Roca")
	_check_eq(e.next_biome_depth(), 150.0, "y empieza a los 150 m")
	e.run_gold = 70.0 # 75 m
	_check_near(e.depth(), 75.0, "con 70 de oro ganado: 75 m")
	_check_near(e.biome_progress(), 0.5, "mitad del camino a Roca: 0.5")
	e.run_gold = 700.0 # ~153 m: ya en Roca
	_check_eq(e.biome_name(e.biome_index()), "Roca", "con 700 de oro ganado ya estás en Roca")
	_check(e.biome_progress() > 0.0 and e.biome_progress() < 0.05, "el progreso vuelve a casi 0 (%.4f)" % e.biome_progress())
	_check_eq(e.biome_name(e.next_biome_index()), "Cristal", "ahora el próximo es Cristal")
	_check_eq(e.next_biome_depth(), 300.0, "a los 300 m")
	e.run_gold = 1.8e8 # Abismo
	_check_eq(e.biome_name(e.biome_index()), "Abismo", "en Abismo")
	_check_eq(e.biome_progress(), 1.0, "la barra queda llena")
	_check_eq(e.next_biome_index(), -1, "no hay próximo bioma")
	_check_eq(e.next_biome_depth(), 0.0, "ni profundidad que alcanzar")
	var no_biomes: EconomyScript = _make(TestBalance.make(["loot", "biomes"]))
	no_biomes.run_gold = 700.0
	_check_eq(no_biomes.biome_progress(), 0.0, "sin biomas en el balance: 0")
	_check_eq(no_biomes.next_biome_index(), -1, "y sin próximo bioma")
	_check_eq(no_biomes.next_biome_depth(), 0.0, "ni profundidad")


func _test_biome_multiplier_scales_income() -> void:
	_section("El multiplicador de bioma escala el oro")
	var e: EconomyScript = _make()
	e.owned[0] = 10 # 10 oro/s base
	_check_eq(e.gold_per_second(), 10.0, "en Tierra: 10 oro/s")
	_check_near(e.hit_value(), 1.3, "en Tierra el golpe vale 1 + 3% de 10")
	e.run_gold = 700.0 # Roca, x1.5
	_check_eq(e.multiplier, 1.5, "en Roca el multiplicador global es x1.5")
	_check_near(e.gold_per_second(), 15.0, "en Roca: 15 oro/s")
	_check_near(e.generator_output(0), 15.0, "el generador aporta 15/s")
	_check_near(e.hit_value(), 1.5 + 0.03 * 15.0, "el golpe: 1 * 1.5 + 3% de 15")
	e.gold = 0.0
	e.tick(2.0)
	_check_near(e.gold, 30.0, "2 s de producción en Roca = 30")
	e.pick_level = 3
	_check_near(e.hit_value(), 8.0 * 1.5 + 0.03 * 15.0, "con pico nivel 3 el multiplicador escala los 8 del pico")


## Ganar oro te mete en el bioma siguiente, y desde ahí rinde más.
func _test_earning_pushes_into_the_next_biome() -> void:
	_section("Ganar oro cruza de bioma")
	var e: EconomyScript = _make()
	e.owned[0] = 100 # 100 oro/s
	e.run_gold = 600.0
	_check_eq(e.biome_index(), 0, "con 600 de oro ganado: Tierra")
	_check_near(e.gold_per_second(), 100.0, "100 oro/s en Tierra")
	e.tick(1.0) # +100 -> 700 de oro ganado
	_check_eq(e.biome_index(), 1, "después de ganar 100 más: Roca")
	_check_near(e.gold_per_second(), 150.0, "150 oro/s en Roca")


func _test_serialization() -> void:
	_section("run_gold en to_dict / from_dict")
	var a: EconomyScript = _make()
	a.gold = 5.0
	a.run_gold = 1.2345678901234567e30
	var data: Dictionary = a.to_dict()
	_check(data.has("run_gold"), "to_dict incluye run_gold")
	var b: EconomyScript = _make()
	b.from_dict(data)
	_check_eq(b.run_gold, a.run_gold, "run_gold se conserva exacto")
	_check_eq(b.biome_index(), a.biome_index(), "y el bioma coincide")


## Un save de antes de existir la profundidad no trae run_gold: se parte del oro que había.
func _test_old_saves_without_run_gold() -> void:
	_section("Saves viejos sin run_gold")
	var e: EconomyScript = _make()
	e.from_dict({ "gold": 500.0, "owned": [3, 1], "pick_level": 2 })
	_check_eq(e.run_gold, 500.0, "se arranca desde el oro que tenía (500)")
	_check_eq(e.owned_count(0), 3, "el resto del save se respeta")
	e.from_dict({ "gold": 500.0, "run_gold": 100.0 })
	_check_eq(e.run_gold, 500.0, "run_gold menor que el oro actual es imposible: se sube a 500")


func _test_from_dict_tolerates_garbage() -> void:
	_section("run_gold tolerante a datos raros")
	var e: EconomyScript = _make()
	e.from_dict({ "run_gold": -50.0 })
	_check_eq(e.run_gold, 0.0, "negativo -> 0")
	e.from_dict({ "run_gold": "mucho" })
	_check_eq(e.run_gold, 0.0, "string -> 0")
	e.from_dict({ "run_gold": NAN })
	_check_eq(e.run_gold, 0.0, "NaN -> 0")
	e.from_dict({ "run_gold": INF })
	_check_eq(e.run_gold, 0.0, "infinito -> 0")
	e.from_dict({})
	_check_eq(e.run_gold, 0.0, "diccionario vacío -> 0")
	_check_eq(e.depth(), 0.0, "y 0 m")


func _test_reset_clears_the_run() -> void:
	_section("reset()")
	var e: EconomyScript = _make()
	e.run_gold = 1.0e9
	e.reset()
	_check_eq(e.run_gold, 0.0, "reset vuelve run_gold a 0")
	_check_eq(e.depth(), 0.0, "y la profundidad a 0")
	_check_eq(e.multiplier, 1.0, "y el multiplicador a x1")


func _test_balance_validation() -> void:
	_section("Validación de depth y biomes")
	var e: EconomyScript = _make()
	e.run_gold = 700.0
	var bad_scale: Dictionary = TestBalance.make(["loot"])
	bad_scale["depth"]["meters_scale"] = 0
	_check_eq(e.load_balance(bad_scale), false, "depth.meters_scale 0 -> inválido")
	_check(e.last_error.contains("depth"), "last_error nombra la sección (%s)" % e.last_error)
	var bad_gold_scale: Dictionary = TestBalance.make(["loot"])
	bad_gold_scale["depth"]["gold_scale"] = -1
	_check_eq(e.load_balance(bad_gold_scale), false, "depth.gold_scale negativo -> inválido")
	var no_biomes: Dictionary = TestBalance.make(["loot"])
	no_biomes["biomes"]["list"] = []
	_check_eq(e.load_balance(no_biomes), false, "lista de biomas vacía -> inválido")
	var bad_step: Dictionary = TestBalance.make(["loot"])
	bad_step["biomes"]["meters_each"] = 0
	_check_eq(e.load_balance(bad_step), false, "biomes.meters_each 0 -> inválido")
	var bad_growth: Dictionary = TestBalance.make(["loot"])
	bad_growth["biomes"]["mult_growth"] = 0
	_check_eq(e.load_balance(bad_growth), false, "biomes.mult_growth 0 -> inválido")
	var nameless: Dictionary = TestBalance.make(["loot"])
	nameless["biomes"]["list"][2]["name"] = ""
	_check_eq(e.load_balance(nameless), false, "un bioma sin nombre -> inválido")
	var not_an_object: Dictionary = TestBalance.make(["loot"])
	not_an_object["biomes"] = "muchos"
	_check_eq(e.load_balance(not_an_object), false, "biomes que no es un objeto -> inválido")
	_check_eq(e.run_gold, 700.0, "un balance inválido no toca el estado")
	_check_eq(e.biome_count(), 5, "ni pisa el balance anterior")


## Un juego sin profundidad ni biomas (o un test con balance mínimo) sigue andando: x1 y 0 m.
func _test_without_depth_sections() -> void:
	_section("Balance sin depth ni biomes")
	var e: EconomyScript = _make(TestBalance.make(["loot", "depth", "biomes"]))
	e.run_gold = 1.0e12
	_check_eq(e.depth(), 0.0, "sin sección depth: 0 m")
	_check_eq(e.biome_count(), 0, "sin sección biomes: 0 biomas")
	_check_eq(e.biome_index(), 0, "índice 0")
	_check_eq(e.biome_multiplier(), 1.0, "multiplicador x1")
	_check_eq(e.multiplier, 1.0, "multiplicador global x1")


func _test_real_balance_file() -> void:
	_section("data/balance.json real")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	_check_eq(e.load_balance_file("res://data/balance.json"), true, "carga el balance real (%s)" % e.last_error)
	_check_eq(e.biome_count(), 5, "5 biomas")
	var names: Array[String] = []
	for index: int in range(e.biome_count()):
		names.append(e.biome_name(index))
	_check_eq(names, ["Tierra", "Roca", "Cristal", "Magma", "Abismo"] as Array[String], "Tierra, Roca, Cristal, Magma, Abismo (en ese orden)")
	e.run_gold = 8.0
	_check_near(e.depth(), 15.0, "con el balance real: 8 de oro ganado -> 15 m")
	e.run_gold = 8.4e6
	_check_eq(e.biome_name(e.biome_index()), "Magma", "a los 300 m (8,4M) se llega a Magma")
	e.run_gold = 8.6e8
	_check_eq(e.biome_name(e.biome_index()), "Abismo", "y con 860M a Abismo (400 m)")
	_check_near(e.multiplier, 5.0625, "con el multiplicador x1.5^4 = x5.0625")
