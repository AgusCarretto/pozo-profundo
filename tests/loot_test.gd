extends "res://tests/test_base.gd"
## Tests headless del botín de core/economy.gd: cofres por golpe y pasivos, rarezas y bonus.
##
## Cada test crea su propia instancia de Economy SIN agregarla al árbol. Para que no dependan
## del azar se usan probabilidades 0 / 1; la distribución real se mide con una semilla fija.

const EconomyScript := preload("res://core/economy.gd")
const TestBalance := preload("res://tests/test_balance.gd")

var _nodes: Array[Node] = []


func _initialize() -> void:
	_test_probability_table()
	_test_chances_are_exposed()
	_test_hit_drops_a_chest()
	_test_chest_is_never_empty()
	_test_hit_without_chest()
	_test_passive_chest_needs_a_crew()
	_test_passive_chance_scales_with_time()
	_test_hit_chance_statistics()
	_test_rarity_distribution()
	_test_loot_amount()
	_test_no_loot_section()
	_test_balance_validation()
	_test_real_balance_file()
	for node: Node in _nodes:
		node.free()
	_finish()


## `tweak` recibe la sección "loot" para ajustarla antes de cargar el balance.
func _make(tweak: Callable = Callable()) -> EconomyScript:
	var balance: Dictionary = TestBalance.make()
	if tweak.is_valid():
		tweak.call(balance["loot"])
	var economy: EconomyScript = EconomyScript.new()
	_nodes.append(economy)
	if not economy.load_balance(balance):
		printerr("    el balance de prueba no cargó: ", economy.last_error)
	economy.rng.seed = 12345
	return economy


## Un solo tipo de cofre (bonus 10%) que sale siempre que hay tirada.
func _always(chance_per_hit: float, chance_per_second: float) -> Callable:
	return func(loot: Dictionary) -> void:
		loot["chance_per_hit"] = chance_per_hit
		loot["chance_per_second"] = chance_per_second
		loot["rarities"] = [{ "id": "only", "name": "Único", "weight": 1, "bonus": 0.10 }]


func _test_probability_table() -> void:
	_section("Tabla de probabilidades (la que ve el jugador)")
	var e: EconomyScript = _make()
	var table: Array[Dictionary] = e.loot_table()
	_check_eq(table.size(), 4, "4 rarezas")
	var names: Array[String] = []
	var chances: Array[float] = []
	var bonuses: Array[float] = []
	for entry: Dictionary in table:
		names.append(entry["name"])
		chances.append(entry["chance"])
		bonuses.append(entry["bonus"])
	_check_eq(names, ["Común", "Raro", "Épico", "Legendario"] as Array[String], "Común, Raro, Épico, Legendario (en ese orden)")
	_check_near(chances[0], 0.70, "Común 70%")
	_check_near(chances[1], 0.22, "Raro 22%")
	_check_near(chances[2], 0.07, "Épico 7%")
	_check_near(chances[3], 0.01, "Legendario 1%")
	_check_near(chances[0] + chances[1] + chances[2] + chances[3], 1.0, "las probabilidades suman 100%")
	_check_eq(bonuses, [0.01, 0.04, 0.15, 0.60] as Array[float], "bonus +1%, +4%, +15%, +60%")
	# Los pesos no tienen que sumar 100: la probabilidad es peso / total.
	var odd: EconomyScript = _make(func(loot: Dictionary) -> void:
		loot["rarities"] = [
			{ "id": "a", "name": "A", "weight": 3, "bonus": 0.1 },
			{ "id": "b", "name": "B", "weight": 1, "bonus": 0.2 },
		])
	_check_near(odd.loot_table()[0]["chance"], 0.75, "pesos 3 y 1 -> 75%")
	_check_near(odd.loot_table()[1]["chance"], 0.25, "pesos 3 y 1 -> 25%")


func _test_chances_are_exposed() -> void:
	_section("Probabilidad de cofre")
	var e: EconomyScript = _make()
	_check_eq(e.loot_chance_per_hit(), 0.04, "4% por golpe")
	_check_eq(e.loot_chance_per_second(), 0.02, "2% por segundo con cuadrilla")


func _test_hit_drops_a_chest() -> void:
	_section("Un golpe con cofre seguro")
	var e: EconomyScript = _make(_always(1.0, 0.0))
	# Se anota en Dictionary y no en Vector2: Vector2 guarda float32 y degrada el monto.
	var drops: Array[Dictionary] = []
	var golds: Array[float] = []
	var hits: Array[float] = []
	e.loot_dropped.connect(func(rarity: int, amount: float) -> void: drops.append({ "rarity": rarity, "amount": amount }))
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.hit_landed.connect(func(amount: float) -> void: hits.append(amount))
	e.gold = 1000.0
	var gained: float = e.hit()
	_check_eq(gained, 1.0, "hit() devuelve solo lo del golpe (1), no el cofre")
	_check_eq(hits, [1.0] as Array[float], "hit_landed(1)")
	_check_eq(drops.size(), 1, "cae 1 cofre")
	_check_eq(drops[0]["rarity"], 0, "de la rareza 0")
	_check_near(drops[0]["amount"], 100.1, "vale 10% del oro que tenés (1001) = 100.1")
	_check_near(e.gold, 1101.1, "el oro incluye golpe + cofre")
	_check_near(e.run_gold, 101.1, "y lo ganado en la partida suma golpe + cofre (cuenta para la profundidad)")
	_check_eq(golds.size(), 1, "gold_changed se emite una sola vez por golpe")
	_check_near(golds[0], 1101.1, "con el oro final")


## Con poco oro el % no alcanza ni a un golpe: el cofre vale al menos un golpe.
func _test_chest_is_never_empty() -> void:
	_section("Un cofre nunca viene vacío")
	var e: EconomyScript = _make(_always(1.0, 0.0))
	var amounts: Array[float] = []
	e.loot_dropped.connect(func(_rarity: int, amount: float) -> void: amounts.append(amount))
	e.hit() # oro 1 -> 10% = 0.1, pero un golpe vale 1
	_check_eq(amounts, [1.0] as Array[float], "el cofre vale 1 (un golpe), no 0.1")
	_check_eq(e.gold, 2.0, "golpe + cofre = 2")


func _test_hit_without_chest() -> void:
	_section("Golpe sin cofre")
	var e: EconomyScript = _make(_always(0.0, 0.0))
	var drops: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _amount: float) -> void: drops.append(rarity))
	for i: int in range(500):
		e.hit()
	_check_eq(drops.size(), 0, "con probabilidad 0 nunca cae un cofre (500 golpes)")
	_check_eq(e.gold, 500.0, "el oro es solo de los golpes")


func _test_passive_chest_needs_a_crew() -> void:
	_section("Cofre pasivo: solo si hay cuadrilla")
	var e: EconomyScript = _make(_always(0.0, 1.0))
	var drops: Array[Dictionary] = []
	e.loot_dropped.connect(func(rarity: int, amount: float) -> void: drops.append({ "rarity": rarity, "amount": amount }))
	e.tick(1.0)
	_check_eq(drops.size(), 0, "sin cuadrilla no hay cofres pasivos")
	_check_eq(e.gold, 0.0, "ni oro")
	e.owned[0] = 10 # 10 oro/s
	var golds: Array[float] = []
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.tick(1.0)
	_check_eq(drops.size(), 1, "con cuadrilla y 100% por segundo cae 1 cofre")
	# 10 de producción + cofre de 10% de 10 (=1) -> mínimo un golpe (1 + 3% de 10 = 1.3)
	_check_near(drops[0]["amount"], 1.3, "vale al menos un golpe (1.3 con 10 oro/s)")
	_check_near(e.gold, 11.3, "oro = producción 10 + cofre 1.3")
	_check_eq(golds.size(), 1, "una sola señal gold_changed por tick")
	e.tick(0.0)
	_check_eq(drops.size(), 1, "un tick de 0 s no tira ningún cofre")


## 2% por segundo se reparte según el tiempo del tick: 0.1 s de tick = 1 - 0.98^0.1 de chance.
func _test_passive_chance_scales_with_time() -> void:
	_section("El cofre pasivo escala con el tiempo")
	var e: EconomyScript = _make(_always(0.0, 0.02))
	e.owned[0] = 1
	var drops: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _amount: float) -> void: drops.append(rarity))
	for i: int in range(100000): # 10.000 s en ticks de 0.1 s -> ~202 cofres esperados
		e.tick(0.1)
	var expected: float = 100000.0 * (1.0 - pow(0.98, 0.1))
	_check(absf(drops.size() - expected) < 60.0, "~%.0f cofres en 10.000 s de ticks cortos (salieron %d)" % [expected, drops.size()])
	var slow: EconomyScript = _make(_always(0.0, 0.02))
	slow.owned[0] = 1
	var slow_drops: Array[int] = []
	slow.loot_dropped.connect(func(rarity: int, _amount: float) -> void: slow_drops.append(rarity))
	for i: int in range(1000): # los mismos 10.000 s, en ticks de 10 s (un frame muy lento)
		slow.tick(10.0)
	var slow_expected: float = 1000.0 * (1.0 - pow(0.98, 10.0))
	_check(absf(slow_drops.size() - slow_expected) < 40.0, "~%.0f cofres en ticks de 10 s (salieron %d): la chance crece con el delta" % [slow_expected, slow_drops.size()])


func _test_hit_chance_statistics() -> void:
	_section("4% de cofre por golpe")
	var e: EconomyScript = _make()
	var chests: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _amount: float) -> void: chests.append(rarity))
	var total: int = 20000
	for i: int in range(total):
		e.hit()
	var expected: float = total * 0.04
	_check(absf(chests.size() - expected) < 120.0, "~%.0f cofres en %d golpes (salieron %d)" % [expected, total, chests.size()])


func _test_rarity_distribution() -> void:
	_section("Distribución de rarezas 70 / 22 / 7 / 1")
	var e: EconomyScript = _make(func(loot: Dictionary) -> void: loot["chance_per_hit"] = 1.0)
	var counts: Array[int] = [0, 0, 0, 0]
	e.loot_dropped.connect(func(rarity: int, _amount: float) -> void: counts[rarity] += 1)
	var total: int = 20000
	for i: int in range(total):
		e.hit()
	_check_eq(counts[0] + counts[1] + counts[2] + counts[3], total, "cada golpe dio un cofre (%d)" % total)
	_check(absf(counts[0] - 14000.0) < 300.0, "Común ~70%% (%d de %d)" % [counts[0], total])
	_check(absf(counts[1] - 4400.0) < 250.0, "Raro ~22%% (%d de %d)" % [counts[1], total])
	_check(absf(counts[2] - 1400.0) < 150.0, "Épico ~7%% (%d de %d)" % [counts[2], total])
	_check(absf(counts[3] - 200.0) < 60.0, "Legendario ~1%% (%d de %d)" % [counts[3], total])


func _test_loot_amount() -> void:
	_section("Bonus de cada rareza")
	var e: EconomyScript = _make()
	e.gold = 10000.0
	_check_near(e.loot_amount(0), 100.0, "Común: +1% de 10.000 = 100")
	_check_near(e.loot_amount(1), 400.0, "Raro: +4% = 400")
	_check_near(e.loot_amount(2), 1500.0, "Épico: +15% = 1.500")
	_check_near(e.loot_amount(3), 6000.0, "Legendario: +60% = 6.000")
	e.gold = 0.0
	_check_eq(e.loot_amount(3), 1.0, "sin oro vale un golpe (1)")
	_check_eq(e.loot_amount(99), 0.0, "una rareza inexistente vale 0 (y no explota)")
	_check_eq(e.loot_amount(-1), 0.0, "un índice negativo vale 0")


func _test_no_loot_section() -> void:
	_section("Balance sin loot")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	e.load_balance(TestBalance.make(["loot"]))
	e.owned[0] = 5
	for i: int in range(1000):
		e.hit()
		e.tick(1.0)
	_check_eq(e.loot_table().size(), 0, "tabla vacía")
	_check_eq(e.loot_chance_per_hit(), 0.0, "0% por golpe")
	_check_eq(e.loot_chance_per_second(), 0.0, "0% por segundo")
	_check_near(e.gold, e.run_gold, "no entró oro de cofres (todo el oro es ganado)")


func _test_balance_validation() -> void:
	_section("Validación de loot")
	var e: EconomyScript = _make()
	var cases: Array = [
		["rarezas vacías", func(loot: Dictionary) -> void: loot["rarities"] = []],
		["probabilidad por golpe mayor a 1", func(loot: Dictionary) -> void: loot["chance_per_hit"] = 1.5],
		["probabilidad por segundo negativa", func(loot: Dictionary) -> void: loot["chance_per_second"] = -0.1],
		["todos los pesos en 0", func(loot: Dictionary) -> void:
			for rarity: Dictionary in loot["rarities"]:
				rarity["weight"] = 0],
		["peso negativo", func(loot: Dictionary) -> void: loot["rarities"][1]["weight"] = -5],
		["bonus negativo", func(loot: Dictionary) -> void: loot["rarities"][0]["bonus"] = -0.01],
		["rareza sin nombre", func(loot: Dictionary) -> void: loot["rarities"][2]["name"] = ""],
		["sin chance_per_hit", func(loot: Dictionary) -> void: loot.erase("chance_per_hit")],
	]
	for case: Array in cases:
		var balance: Dictionary = TestBalance.make()
		(case[1] as Callable).call(balance["loot"])
		_check_eq(e.load_balance(balance), false, "%s -> inválido" % case[0])
	_check(e.last_error.contains("loot"), "last_error nombra la sección (%s)" % e.last_error)
	var not_an_object: Dictionary = TestBalance.make()
	not_an_object["loot"] = [1, 2]
	_check_eq(e.load_balance(not_an_object), false, "loot que no es un objeto -> inválido")
	_check_eq(e.loot_table().size(), 4, "un balance inválido no pisa la tabla anterior")
	var zero: Dictionary = TestBalance.make()
	zero["loot"]["chance_per_hit"] = 0
	zero["loot"]["chance_per_second"] = 0
	_check_eq(e.load_balance(zero), true, "probabilidades 0 son válidas (cofres apagados)")


func _test_real_balance_file() -> void:
	_section("data/balance.json real")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	_check_eq(e.load_balance_file("res://data/balance.json"), true, "carga el balance real (%s)" % e.last_error)
	_check_eq(e.loot_chance_per_hit(), 0.04, "4% por golpe")
	_check_eq(e.loot_chance_per_second(), 0.02, "2% por segundo")
	var table: Array[Dictionary] = e.loot_table()
	_check_eq(table.size(), 4, "4 rarezas")
	if table.size() == 4:
		_check_eq(table[0]["name"], "Común", "Común")
		_check_near(table[0]["chance"], 0.70, "Común 70%")
		_check_near(table[0]["bonus"], 0.01, "Común +1%")
		_check_near(table[1]["chance"], 0.22, "Raro 22%")
		_check_near(table[1]["bonus"], 0.04, "Raro +4%")
		_check_near(table[2]["chance"], 0.07, "Épico 7%")
		_check_near(table[2]["bonus"], 0.15, "Épico +15%")
		_check_eq(table[3]["name"], "Legendario", "Legendario")
		_check_near(table[3]["chance"], 0.01, "Legendario 1%")
		_check_near(table[3]["bonus"], 0.60, "Legendario +60%")
