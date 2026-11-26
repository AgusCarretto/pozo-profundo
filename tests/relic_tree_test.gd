extends "res://tests/test_base.gd"
## core/relic_tree.gd con los datos reales de data/arbol.json: costos, anillos, niebla, piedras angulares, efectos,
## meta de volver y bonus histórico.

const RelicTree := preload("res://core/relic_tree.gd")
const DATA: String = "res://data/arbol.json"


func _initialize() -> void:
	_test_loads_the_data()
	_test_rings_and_fog()
	_test_buying_and_costs()
	_test_keystones_and_bridges()
	_test_effects()
	_test_return_target_and_history_bonus()
	_test_save_roundtrip()
	_test_rejects_broken_data()
	_finish()


func _make() -> RelicTree:
	var tree: RelicTree = RelicTree.new()
	_check(tree.load_file(DATA), "carga data/arbol.json (%s)" % tree.last_error)
	return tree


## Compra `id` hasta `level` sin mirar requisitos de anillo (reliquias de sobra, récord y resets altos).
func _buy(tree: RelicTree, id: String, level: int = 1) -> void:
	for i: int in range(level):
		tree.buy(id, 100000, 1000.0, 1000)


func _test_loads_the_data() -> void:
	_section("Datos")
	var tree: RelicTree = _make()
	_check_eq(tree.ids().size(), 35, "35 estrellas")
	var total: int = 0
	var levels: int = 0
	for id: String in tree.ids():
		for cost: int in tree.star(id)["costs"]:
			total += cost
			levels += 1
	_check_eq(total, 1008, "el árbol entero cuesta 1008 reliquias")
	_check_eq(levels, 125, "en 125 compras")
	_check_eq(tree.fragments_per_relic(), 20, "20 fragmentos = 1 reliquia")
	for id: String in tree.ids():
		var star: Dictionary = tree.star(id)
		_check(str(star["name"]) != "" and str(star["description"]) != "" and star["pos"].size() == 2, "%s tiene nombre, efecto y posición" % id)


func _test_rings_and_fog() -> void:
	_section("Anillos y niebla")
	var tree: RelicTree = _make()
	_check_eq(tree.state("core", 0.0, 0), RelicTree.State.SEALED, "sin ningún reset el Corazón está sellado")
	_check_eq(tree.state("core", 300.0, 1), RelicTree.State.OPEN, "con el primer reset se abre")
	_check_eq(tree.state("f_brazo", 300.0, 1), RelicTree.State.HIDDEN, "lo que sigue está oculto")
	_buy(tree, "core")
	_check_eq(tree.state("core", 300.0, 1), RelicTree.State.OWNED, "comprado")
	_check_eq(tree.state("f_brazo", 300.0, 1), RelicTree.State.OPEN, "y aparece la vecina")
	_check_eq(tree.state("f_templado", 300.0, 1), RelicTree.State.HIDDEN, "la de más lejos no")
	_buy(tree, "f_brazo")
	_buy(tree, "f_ojo")
	_check_eq(tree.state("f_brutal", 300.0, 1), RelicTree.State.SEALED, "anillo 2: pide 350 m y 8 resets")
	_check_eq(tree.state("f_brutal", 350.0, 7), RelicTree.State.SEALED, "con 7 resets no alcanza")
	_check_eq(tree.state("f_brutal", 349.0, 8), RelicTree.State.SEALED, "con 349 m tampoco")
	_check_eq(tree.state("f_brutal", 350.0, 8), RelicTree.State.OPEN, "con los dos, sí")
	_check_eq(tree.ring_requirement(3), { "depth": 400.0, "resets": 25 }, "anillo 3: 400 m y 25 resets")


func _test_buying_and_costs() -> void:
	_section("Compras")
	var tree: RelicTree = _make()
	_check(not tree.buy("core", 0, 300.0, 1), "sin reliquias no se compra")
	_check(tree.buy("core", 1, 300.0, 1), "el Corazón cuesta 1")
	_check_eq(tree.next_cost("core"), 0, "al máximo no cuesta nada más")
	_check(not tree.buy("core", 100, 300.0, 1), "ni se vuelve a comprar")
	_check_eq(tree.next_cost("f_brazo"), 2, "Brazo fuerte arranca en 2")
	_buy(tree, "f_brazo", 3)
	_check_eq(tree.level("f_brazo"), 3, "nivel 3")
	_check_eq(tree.next_cost("f_brazo"), 3, "el 4.º cuesta 3")
	_check_eq(tree.spent(), 1 + 2 + 2 + 3, "gastado: lo que costaron")
	_check(not tree.buy("f_templado", 1, 300.0, 1), "con 1 reliquia no alcanza para 2")
	_check(not tree.buy("noexiste", 100, 300.0, 1), "una estrella que no existe no se compra")


func _test_keystones_and_bridges() -> void:
	_section("Piedras angulares y puentes")
	var tree: RelicTree = _make()
	_buy(tree, "core")
	for id: String in ["f_brazo", "f_templado", "f_eco", "f_combo"]:
		_buy(tree, id)
	_check_eq(tree.state("f_furia", 1000.0, 1000), RelicTree.State.HIDDEN, "la piedra pide Mano rápida al máximo")
	_buy(tree, "f_umbral")
	_check_eq(tree.state("f_furia", 1000.0, 1000), RelicTree.State.OPEN, "y ahora aparece")
	_check(not tree.set_keystone("f_furia", true), "sin comprarla no se activa")
	_buy(tree, "f_furia")
	_check(tree.active_keystones.has("f_furia"), "al comprarla queda activa si hay lugar")
	_check_eq(tree.state("p_suerte", 1000.0, 1000), RelicTree.State.HIDDEN, "el puente pide las dos piedras")
	for id: String in ["o_olfato", "o_botin", "o_doble", "o_reliquia"]:
		_buy(tree, id, 8)
	_buy(tree, "o_apostador")
	_check_eq(tree.state("p_suerte", 1000.0, 1000), RelicTree.State.OPEN, "con las dos compradas se ve")
	for id: String in ["c_capataz", "c_hitos"]:
		_buy(tree, id, 5)
	_buy(tree, "c_memoria")
	_buy(tree, "c_mina")
	_check_eq(tree.active_keystones.size(), 2, "máximo 2 activas")
	_check(not tree.active_keystones.has("c_mina"), "la tercera queda apagada")
	_check(not tree.set_keystone("c_mina", true), "y no entra sin apagar otra")
	_check(tree.set_keystone("f_furia", false), "se puede apagar")
	_check(tree.set_keystone("c_mina", true), "y ahí entra")

	# Cambios para la próxima bajada: se anotan y no surten efecto hasta aplicarlos.
	_check(tree.set_keystone("c_mina", false, false), "apagar para después")
	_check(tree.active_keystones.has("c_mina") and not tree.planned_keystones.has("c_mina"), "sigue activa y queda anotado")
	_check(tree.set_keystone("f_furia", true, false), "hay lugar para la otra en la próxima")
	_check(not tree.active_keystones.has("f_furia"), "pero todavía no surte efecto")
	_check(not tree.set_keystone("c_mina", true, false) , "la próxima ya tiene 2")
	var copy: RelicTree = _make()
	copy.from_dict(JSON.parse_string(JSON.stringify(tree.to_dict())))
	_check(copy.active_keystones.has("c_mina") and copy.planned_keystones.has("f_furia"), "lo anotado se guarda")
	tree.apply_keystones()
	_check(tree.active_keystones.has("f_furia") and not tree.active_keystones.has("c_mina"), "al aplicarlo cambian")
	copy.from_dict({ "levels": copy.levels.duplicate(), "keystones": ["f_furia"] })
	_check_eq(copy.planned_keystones, ["f_furia"] as Array[String], "un guardado sin lo anotado usa las activas")


func _test_effects() -> void:
	_section("Efectos")
	var tree: RelicTree = _make()
	_check_eq(tree.add("crew"), 0.0, "sin estrellas no suma nada")
	_check_eq(tree.mul("crit_mult_mul"), 1.0, "ni multiplica")
	_check_eq(tree.value("offline_eff", 0.05), 0.05, "ni cambia valores")
	_buy(tree, "core")
	_check_near(tree.add("gold"), 0.5, "Corazón: +50% de oro")
	_buy(tree, "c_capataz", 2)
	_check_near(tree.add("crew"), 0.10, "Capataz 2: +10%")
	_buy(tree, "t_vigilia", 3)
	_check_near(tree.value("offline_eff", 0.05), 0.12, "Vigilia 3: AFK al 12%")
	_buy(tree, "c_contrato")
	_buy(tree, "c_bolsa", 3)
	_check_eq(tree.value("carry_gold_seconds", 0.0), 40.0, "Bolsa 3: 40 s")
	for id: String in ["f_brazo", "f_templado", "f_eco", "f_combo", "f_umbral", "f_furia"]:
		_buy(tree, id)
	_check_eq(tree.mul("crit_mult_mul"), 4.0, "Furia activa: críticos x4")
	tree.set_keystone("f_furia", false)
	_check_eq(tree.mul("crit_mult_mul"), 1.0, "apagada no hace nada")


func _test_return_target_and_history_bonus() -> void:
	_section("Meta de volver y bonus histórico")
	var tree: RelicTree = _make()
	var points: Dictionary = { 0: 0.0, 3: 0.0, 6: 20.0, 20: 56.0, 30: 92.0, 40: 127.0, 1000: 294.0, 1400: 335.0, 1800: 376.0 }
	for claimed: int in points:
		_check_near(tree.shift_for(claimed), points[claimed], "con %d reliquias de bajadas la meta se corre %d m" % [claimed, int(points[claimed])])
	_check_eq(tree.return_extra_every(), 30.0, "+1 reliquia cada 30 m corridos")
	_check_near(tree.history_multiplier(0), 1.0, "sin reliquias x1")
	_check_near(tree.history_multiplier(60), 4.6, "60 reliquias: +6% cada una")
	_check_near(tree.history_multiplier(260), 5.6, "después +0,5% cada una")


func _test_save_roundtrip() -> void:
	_section("Guardado")
	var tree: RelicTree = _make()
	_buy(tree, "core")
	_buy(tree, "f_brazo", 2)
	var copy: RelicTree = _make()
	copy.from_dict(JSON.parse_string(JSON.stringify(tree.to_dict())))
	_check_eq(copy.level("f_brazo"), 2, "los niveles vuelven")
	_check_eq(copy.spent(), tree.spent(), "y lo gastado se calcula igual")
	copy.from_dict({ "levels": { "f_brazo": 99, "inventada": 3, "core": -4 }, "keystones": ["f_brazo", "inventada"] })
	_check_eq(copy.level("f_brazo"), 5, "un nivel de más se recorta al máximo")
	_check_eq(copy.level("core"), 0, "uno negativo queda en 0")
	_check_eq(copy.level("inventada"), 0, "una estrella que no existe se ignora")
	_check(copy.active_keystones.is_empty(), "y solo las piedras compradas pueden estar activas")
	copy.clear()
	_check_eq(copy.spent(), 0, "clear() la deja vacía")


func _test_rejects_broken_data() -> void:
	_section("Datos rotos")
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var tree: RelicTree = RelicTree.new()
	_check(not tree.load_data({}), "vacío: no carga")
	var bad_from: Dictionary = good.duplicate(true)
	bad_from["stars"][1]["from"] = ["inventada"]
	_check(not tree.load_data(bad_from), "un prerrequisito que no existe: no carga")
	var no_costs: Dictionary = good.duplicate(true)
	no_costs["stars"][1]["costs"] = []
	_check(not tree.load_data(no_costs), "una estrella sin costos: no carga")
	var no_return: Dictionary = good.duplicate(true)
	no_return.erase("return")
	_check(not tree.load_data(no_return), "sin tabla de meta: no carga")
	_check(tree.last_error != "", "y dice por qué")
