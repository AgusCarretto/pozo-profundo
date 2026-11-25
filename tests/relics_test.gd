extends "res://tests/test_base.gd"
## Tests headless de las reliquias y el prestigio de core/economy.gd.
##
## Economy.prestige() ejecuta la subida ya mismo: la confirmación al jugador es de la UI
## (se prueba en main_scene_test). Cada test crea su propia instancia SIN agregarla al árbol,
## con el balance de tests/test_balance.gd y sin botín (el azar no mueve el oro).

const EconomyScript := preload("res://core/economy.gd")
const EconomyMath := preload("res://core/economy_math.gd")
const TestBalance := preload("res://tests/test_balance.gd")

## Oro ganado que deja justo pasados los 300 m (~300.04 m) / justo antes (~299.2 m).
const GOLD_AT_300M: float = 41000.0
const GOLD_BEFORE_300M: float = 40000.0

var _nodes: Array[Node] = []


func _initialize() -> void:
	_test_initial_state()
	_test_not_available_before_300m()
	_test_available_from_300m()
	_test_relics_grow_with_depth()
	_test_prestige_resets_the_run_and_keeps_relics()
	_test_prestige_signals()
	_test_relics_multiply_income()
	_test_relics_stack_with_the_biome()
	_test_relics_accumulate_over_runs()
	_test_new_run_can_reach_300m_again()
	_test_serialization()
	_test_old_saves_without_relics()
	_test_from_dict_tolerates_garbage()
	_test_reset_wipes_relics()
	_test_without_prestige_section()
	_test_balance_validation()
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


## Deja una partida "armada" para ver qué se pierde y qué se conserva al volver a la superficie.
## Lleva la sección de botín (sin ella el bonus de botín no cuenta) pero con los cofres apagados:
## el bonus se fija a mano y el azar no lo mueve.
func _loaded_run(run_gold: float) -> EconomyScript:
	var balance: Dictionary = TestBalance.make()
	balance["loot"]["chance_per_hit"] = 0.0
	balance["loot"]["chance_per_second"] = 0.0
	var e: EconomyScript = _make(balance)
	e.run_gold = run_gold
	e.gold = 5000.0
	e.owned[0] = 3
	e.owned[1] = 2
	e.pick_level = 4
	e.loot_bonus = 0.5
	return e


func _test_initial_state() -> void:
	_section("Estado inicial")
	var e: EconomyScript = _make()
	_check_eq(e.relics, 0, "0 reliquias")
	_check_eq(e.relic_multiplier(), 1.0, "multiplicador de reliquias x1")
	_check_eq(e.prestige_min_depth(), 300.0, "se puede desde los 300 m")
	_check_eq(e.relic_bonus(), 0.25, "cada reliquia da +25%")
	_check_eq(e.prestige_relics(), 0, "en la superficie, una subida daría 0")
	_check_eq(e.can_prestige(), false, "no se puede volver a la superficie desde la superficie")


func _test_not_available_before_300m() -> void:
	_section("Antes de los 300 m no hay prestigio")
	var e: EconomyScript = _loaded_run(GOLD_BEFORE_300M)
	_check(e.depth() < 300.0 and e.depth() > 299.0, "la partida está a %.2f m" % e.depth())
	_check_eq(e.prestige_relics(), 0, "no ofrece reliquias")
	_check_eq(e.can_prestige(), false, "can_prestige() es false")
	var golds: Array[float] = []
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	_check_eq(e.prestige(), 0, "prestige() devuelve 0")
	_check_eq(e.relics, 0, "sin reliquias nuevas")
	_check_eq(e.gold, 5000.0, "el oro sigue igual")
	_check_eq(e.run_gold, GOLD_BEFORE_300M, "la profundidad sigue igual")
	_check_eq(e.owned_count(0), 3, "la cuadrilla sigue igual")
	_check_eq(e.pick_level, 4, "el pico sigue igual")
	_check_eq(e.loot_bonus, 0.5, "el bonus de botín sigue igual")
	_check_eq(golds.size(), 0, "y no emite señales")
	var shallow: EconomyScript = _make()
	shallow.run_gold = 630.0 # 150 m: la fórmula sola daría 0 de todos modos, pero 250 m daría 1
	_check_eq(shallow.prestige(), 0, "a 150 m tampoco")
	var deep_enough_for_formula: EconomyScript = _make()
	deep_enough_for_formula.run_gold = 10300.0 # ~250 m: floor(((250-200)/50)^1.3) = 1, pero falta para los 300 m
	_check(deep_enough_for_formula.depth() > 249.0 and deep_enough_for_formula.depth() < 252.0, "a ~250 m (%.1f)" % deep_enough_for_formula.depth())
	_check_eq(deep_enough_for_formula.prestige_relics(), 0, "a ~250 m la fórmula daría 1, pero el mínimo es 300 m -> 0")
	_check_eq(deep_enough_for_formula.can_prestige(), false, "y no se puede")


func _test_available_from_300m() -> void:
	_section("Desde los 300 m")
	var e: EconomyScript = _make()
	e.run_gold = GOLD_AT_300M
	_check(e.depth() >= 300.0 and e.depth() < 301.0, "la partida está a %.2f m" % e.depth())
	_check_eq(e.prestige_relics(), 2, "300 m ofrece floor(2^1.3 = 2.46) = 2 reliquias")
	_check_eq(e.can_prestige(), true, "can_prestige() es true")
	_check_eq(e.relics, 0, "ofrecer no entrega: todavía 0 reliquias")
	_check_eq(e.prestige_relics(), e.prestige_relics(), "preguntar muchas veces no cambia nada")
	_check_near(e.relic_multiplier_for(e.relics + e.prestige_relics()), 1.5, "después de la subida el multiplicador sería x1.5")


func _test_relics_grow_with_depth() -> void:
	_section("Más profundo, más reliquias")
	var previous: int = 0
	var monotonic: bool = true
	var matches_formula: bool = true
	for exponent: int in range(4, 11): # de 1e4 a 1e10 de oro ganado
		var e: EconomyScript = _make()
		e.run_gold = pow(10.0, exponent)
		var expected: int = EconomyMath.relics_for_depth(e.depth(), 300.0, 200.0, 50.0, 1.3)
		if e.prestige_relics() != expected:
			matches_formula = false
		if e.prestige_relics() < previous:
			monotonic = false
		previous = e.prestige_relics()
	_check(matches_formula, "prestige_relics() es la fórmula floor(((prof - 200) / 50)^1.3)")
	_check(monotonic, "nunca baja al sumar oro")
	var deep: EconomyScript = _make()
	deep.run_gold = 2.7e6 # ~451 m: floor(5.02^1.3 = 8.15) = 8
	_check_eq(deep.prestige_relics(), 8, "a ~451 m son 8 reliquias")


func _test_prestige_resets_the_run_and_keeps_relics() -> void:
	_section("Volver a la superficie")
	var e: EconomyScript = _loaded_run(GOLD_AT_300M)
	_check_eq(e.biome_name(e.biome_index()), "Cristal", "se parte desde Cristal")
	# El botín es +50% BRUTO: efectivo 3 x (1 - e^(-0.5 / 3)) = +46.06%, o sea x1.4606.
	_check_near(e.multiplier, 2.25 * (1.0 + 3.0 * (1.0 - exp(-0.5 / 3.0))), "antes de subir: Cristal x2.25 por botín +50% bruto (x1.4606) = x3.286")
	_check_eq(e.prestige(), 2, "prestige() devuelve las reliquias ganadas (2)")
	_check_eq(e.relics, 2, "ahora hay 2 reliquias")
	_check_eq(e.loot_bonus, 0.0, "el bonus de botín se reinicia con la partida")
	_check_near(e.multiplier, 1.5, "y el multiplicador queda solo con las reliquias: x1.5")
	_check_eq(e.gold, 0.0, "el oro vuelve a 0")
	_check_eq(e.run_gold, 0.0, "el oro ganado de la partida vuelve a 0")
	_check_eq(e.depth(), 0.0, "profundidad 0 m")
	_check_eq(e.biome_name(e.biome_index()), "Tierra", "otra vez en Tierra")
	_check_eq(e.owned_count(0), 0, "sin mineros")
	_check_eq(e.owned_count(1), 0, "sin taladros")
	_check_eq(e.pick_level, 0, "el pico vuelve al nivel 0")
	_check_eq(e.can_prestige(), false, "recién vuelto, no se puede repetir")
	_check_eq(e.prestige(), 0, "un segundo prestige() seguido no da nada")
	_check_eq(e.relics, 2, "y no pierde ni suma reliquias")


func _test_prestige_signals() -> void:
	_section("Señales del prestigio")
	var e: EconomyScript = _loaded_run(GOLD_AT_300M)
	var gained: Array[int] = []
	var golds: Array[float] = []
	e.prestiged.connect(func(relics: int) -> void: gained.append(relics))
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.prestige()
	_check_eq(gained, [2] as Array[int], "emite prestiged(2)")
	_check_eq(golds, [0.0] as Array[float], "emite gold_changed(0) una sola vez para que la UI se refresque")


func _test_relics_multiply_income() -> void:
	_section("Cada reliquia da +25% de oro")
	var e: EconomyScript = _make()
	e.owned[0] = 10 # 10 oro/s
	e.relics = 4
	_check_eq(e.relic_multiplier(), 2.0, "4 reliquias = x2")
	_check_eq(e.multiplier, 2.0, "el multiplicador global es x2")
	_check_eq(e.gold_per_second(), 20.0, "10 oro/s -> 20 oro/s")
	_check_near(e.hit_value(), 2.0 + 0.03 * 20.0, "el golpe: 1 * 2 + 3% de 20")
	e.tick(1.0)
	_check_eq(e.gold, 20.0, "1 s de producción = 20")


func _test_relics_stack_with_the_biome() -> void:
	_section("Reliquias x bioma")
	var e: EconomyScript = _make()
	e.owned[0] = 10
	e.relics = 2 # x1.5
	e.run_gold = 700.0 # Roca, x1.5
	_check_near(e.multiplier, 2.25, "x1.5 de bioma por x1.5 de reliquias = x2.25")
	_check_near(e.gold_per_second(), 22.5, "10 oro/s -> 22.5 oro/s")


## Las reliquias de una vuelta mejoran la siguiente: subirlas más rápido llega antes a los 300 m,
## y cada subida suma a las que ya tenías.
func _test_relics_accumulate_over_runs() -> void:
	_section("Las reliquias se acumulan")
	var e: EconomyScript = _make()
	e.run_gold = GOLD_AT_300M
	e.prestige()
	_check_eq(e.relics, 2, "primera subida: 2")
	e.run_gold = 2.7e6 # ~451 m -> 8 reliquias más
	e.prestige()
	_check_eq(e.relics, 10, "segunda subida desde ~451 m: 2 + 8 = 10")
	_check_eq(e.relic_multiplier(), 3.5, "10 reliquias = x3.5")


func _test_new_run_can_reach_300m_again() -> void:
	_section("Una partida nueva vuelve a poder bajar")
	var e: EconomyScript = _make()
	e.run_gold = GOLD_AT_300M
	e.prestige()
	e.owned[0] = 10
	e.tick(1.0) # 10 oro/s * x1.5 de reliquias = 15
	_check_near(e.run_gold, 15.0, "la nueva partida cuenta su propio oro ganado (15)")
	e.run_gold = GOLD_AT_300M
	_check_eq(e.can_prestige(), true, "y a los 300 m se puede de nuevo")
	_check_eq(e.prestige(), 2, "otra vez 2 reliquias")
	_check_eq(e.relics, 4, "4 en total")


func _test_serialization() -> void:
	_section("Reliquias en to_dict / from_dict")
	var a: EconomyScript = _make()
	a.relics = 7
	var data: Dictionary = a.to_dict()
	_check_eq(data.get("relics"), 7, "to_dict incluye relics")
	var b: EconomyScript = _make()
	b.from_dict(data)
	_check_eq(b.relics, 7, "se conservan")
	_check_eq(b.relic_multiplier(), 2.75, "y el multiplicador (1 + 7 * 0.25)")
	# Pasa por JSON de verdad (el save real es JSON, donde los enteros vuelven como float).
	var c: EconomyScript = _make()
	c.from_dict(JSON.parse_string(JSON.stringify(data)))
	_check_eq(c.relics, 7, "también después de ir y volver por JSON")


func _test_old_saves_without_relics() -> void:
	_section("Saves viejos sin reliquias")
	var e: EconomyScript = _make()
	e.relics = 5
	e.from_dict({ "gold": 100.0, "owned": [1, 1], "pick_level": 1 })
	_check_eq(e.relics, 0, "un save sin 'relics' deja 0 (no conserva las de la sesión)")


func _test_from_dict_tolerates_garbage() -> void:
	_section("relics tolerante a datos raros")
	var e: EconomyScript = _make()
	e.from_dict({ "relics": -4 })
	_check_eq(e.relics, 0, "negativas -> 0")
	e.from_dict({ "relics": "muchas" })
	_check_eq(e.relics, 0, "string -> 0")
	e.from_dict({ "relics": NAN })
	_check_eq(e.relics, 0, "NaN -> 0")
	e.from_dict({ "relics": INF })
	_check_eq(e.relics, 0, "infinito -> 0")
	e.from_dict({ "relics": 3.7 })
	_check_eq(e.relics, 3, "un decimal se trunca (3.7 -> 3)")
	e.from_dict({ "relics": 1.0e30 })
	_check(e.relics > 0 and e.relics <= EconomyScript.MAX_LOADED_RELICS, "un valor absurdo se topa (%d)" % e.relics)
	_check(is_finite(e.relic_multiplier()), "y el multiplicador sigue siendo finito")


func _test_reset_wipes_relics() -> void:
	_section("reset() es empezar de cero")
	var e: EconomyScript = _make()
	e.relics = 9
	e.reset()
	_check_eq(e.relics, 0, "reset() borra también las reliquias")
	_check_eq(e.relic_multiplier(), 1.0, "multiplicador x1")


func _test_without_prestige_section() -> void:
	_section("Balance sin prestige")
	var e: EconomyScript = _make(TestBalance.make(["loot", "prestige"]))
	e.run_gold = 1.0e12
	_check_eq(e.prestige_relics(), 0, "sin sección: no ofrece reliquias")
	_check_eq(e.can_prestige(), false, "no se puede")
	_check_eq(e.prestige(), 0, "prestige() no hace nada")
	_check_eq(e.run_gold, 1.0e12, "la partida sigue igual")
	e.relics = 5 # de un save hecho con otro balance
	_check_eq(e.relic_multiplier(), 1.0, "sin sección las reliquias no multiplican")


func _test_balance_validation() -> void:
	_section("Validación de prestige")
	var e: EconomyScript = _make()
	e.run_gold = 123.0
	for key: String in ["min_depth", "depth_step", "exponent", "bonus_per_relic"]:
		var zero: Dictionary = TestBalance.make(["loot"])
		zero["prestige"][key] = 0
		_check_eq(e.load_balance(zero), false, "prestige.%s = 0 -> inválido" % key)
		_check(e.last_error.contains("prestige"), "last_error nombra la sección (%s)" % e.last_error)
	var negative_offset: Dictionary = TestBalance.make(["loot"])
	negative_offset["prestige"]["depth_offset"] = -1
	_check_eq(e.load_balance(negative_offset), false, "prestige.depth_offset negativo -> inválido")
	var missing: Dictionary = TestBalance.make(["loot"])
	missing["prestige"].erase("exponent")
	_check_eq(e.load_balance(missing), false, "falta prestige.exponent -> inválido")
	var not_an_object: Dictionary = TestBalance.make(["loot"])
	not_an_object["prestige"] = 300
	_check_eq(e.load_balance(not_an_object), false, "prestige que no es un objeto -> inválido")
	_check_eq(e.run_gold, 123.0, "un balance inválido no toca el estado")
	_check_eq(e.prestige_min_depth(), 300.0, "ni pisa el balance anterior")


func _test_real_balance_file() -> void:
	_section("data/balance.json real")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	_check_eq(e.load_balance_file("res://data/balance.json"), true, "carga el balance real (%s)" % e.last_error)
	_check_eq(e.prestige_min_depth(), 450.0, "desde los 450 m")
	_check_eq(e.relic_bonus(), 0.15, "+15% por reliquia")
	e.run_gold = 41000.0 # 300 m
	_check_eq(e.prestige_relics(), 0, "a 300 m todavía no se puede")
	e.run_gold = 2.7e6 # ~451 m
	_check_eq(e.prestige_relics(), 2, "a ~450 m: 2 reliquias")
	_check_eq(e.prestige(), 2, "prestige() las entrega")
	_check_near(e.relic_multiplier(), 1.3, "x1.3")
