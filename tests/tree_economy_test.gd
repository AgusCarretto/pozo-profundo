extends "res://tests/test_base.gd"
## core/economy.gd con el árbol de reliquias (sección "tree" del balance): reliquias como moneda, meta de volver,
## efectos de las estrellas, AFK, arrastre, Racha, fragmentos, tope de golpes, guardado y partidas anteriores.
## Usa el balance de prueba (curva propia) y el árbol real de data/arbol.json.

const EconomyScript := preload("res://core/economy.gd")
const TestBalance := preload("res://tests/test_balance.gd")

## Reloj de prueba (s) que reciben las instancias.
var _now: float = 1000.0


func _initialize() -> void:
	_test_without_tree_nothing_changes()
	_test_relics_are_currency_with_a_history_bonus()
	_test_return_target_moves_with_claimed_relics()
	_test_star_effects_on_production_and_costs()
	_test_chest_effects()
	_test_active_play_effects()
	_test_gold_vein()
	_test_offline_effects()
	_test_carry_over_between_descents()
	_test_keystones_change_on_the_next_descent()
	_test_fragments_and_debug_helpers()
	_test_tap_cap()
	_test_save_roundtrip()
	_test_old_saves_keep_their_relics()
	_finish()


func _balance(without: Array[String] = ["loot"]) -> Dictionary:
	var balance: Dictionary = TestBalance.make(without)
	balance["tree"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/arbol.json"))
	balance["tap"] = { "max_hits": 6, "window_seconds": 1 }
	balance["crit"] = { "chance": 0.0, "multiplier": 2 }
	balance["frenzy"] = { "hits_per_second": 4, "enter_seconds": 2, "exit_seconds": 3, "window_seconds": 1 }
	balance["offline"] = { "max_hours": 8, "away_seconds": 120, "efficiency": 0.05 }
	return balance


func _make(without: Array[String] = ["loot"]) -> EconomyScript:
	var e: EconomyScript = EconomyScript.new()
	_check(e.load_balance(_balance(without)), "carga el balance con árbol (%s)" % e.last_error)
	e.clock = func() -> float: return _now
	return e


## Reliquias de sobra, anillos abiertos y las estrellas de `ids` al máximo (en orden: cada una pide la anterior).
func _light(e: EconomyScript, ids: Array[String]) -> void:
	e.relics += 5000
	e.open_rings()
	for id: String in ids:
		while e.buy_star(id):
			pass
		_check(e.relic_tree.level(id) > 0, "se pudo comprar %s" % id)


## Oro ganado en la bajada para estar a `meters` m con la curva de prueba (25 m por duplicación, escala 10).
func _gold_for_depth(meters: float) -> float:
	return 10.0 * (pow(2.0, meters / 25.0) - 1.0)


func _test_without_tree_nothing_changes() -> void:
	_section("Sin árbol, como siempre")
	var e: EconomyScript = EconomyScript.new()
	e.load_balance(TestBalance.make())
	e.relics = 4
	_check(not e.has_tree(), "no hay árbol")
	_check_near(e.relic_multiplier(), 2.0, "cada reliquia sigue dando +25%")
	_check_eq(e.available_relics(), 4, "todas disponibles")
	_check_near(e.return_depth(), e.prestige_min_depth(), "la meta es la mínima")
	_check(not e.buy_star("core"), "no hay estrellas que comprar")
	e.free()


func _test_relics_are_currency_with_a_history_bonus() -> void:
	_section("Las reliquias son la moneda")
	var e: EconomyScript = _make()
	e.relics = 10
	_check_near(e.relic_multiplier(), 1.6, "10 reliquias ganadas: +6% cada una")
	_check(not e.buy_star("core"), "sin ningún reset el Corazón está sellado")
	e.resets = 1
	var changes: Array[int] = []
	e.tree_changed.connect(func() -> void: changes.append(1))
	_check(e.buy_star("core"), "se compra")
	_check_eq(changes.size(), 1, "y avisa")
	_check_eq(e.available_relics(), 9, "queda 1 menos para gastar")
	_check_eq(e.relics, 10, "las ganadas no bajan")
	_check_near(e.relic_multiplier(), 1.6 * 1.5, "gastar no debilita: Corazón x1,5")
	e.free()


func _test_return_target_moves_with_claimed_relics() -> void:
	_section("La meta de volver se corre")
	var e: EconomyScript = _make()
	var min_depth: float = e.prestige_min_depth()
	_check_near(e.return_depth(), min_depth, "al principio es la mínima")
	e.claimed_relics = 40
	e.relics = 40
	e.run_gold = _gold_for_depth(min_depth)
	_check(e.can_prestige(), "la bajada en curso conserva su meta")
	var gained: int = e.prestige()
	_check_eq(e.claimed_relics, 40 + gained, "las sacadas de bajadas se cuentan")
	_check_eq(e.relics, 40 + gained, "y se ganan")
	_check_eq(e.resets, 1, "un reset")
	_check(e.record_depth >= min_depth, "queda el récord (%d m)" % int(e.record_depth))
	var shift: float = e.relic_tree.shift_for(e.claimed_relics)
	_check_near(e.return_depth(), min_depth + shift, "la bajada nueva pide %d m más" % int(shift))
	e.run_gold = _gold_for_depth(min_depth + shift - 1.0)
	_check_eq(e.prestige_relics(), 0, "un metro antes todavía no")
	e.run_gold = _gold_for_depth(min_depth + shift + 0.1)
	var base: int = EconomyScript.EconomyMath.relics_for_depth(e.depth() - shift, min_depth, 200.0, 50.0, 1.3)
	_check_eq(e.prestige_relics(), base + int(shift / 30.0), "la fórmula de siempre desde la meta, más 1 cada 30 m corridos")
	e.claimed_relics = 500
	_check_near(e.return_depth(), min_depth + shift, "no se mueve en mitad de la bajada")
	e.free()


func _test_star_effects_on_production_and_costs() -> void:
	_section("Estrellas: producción, golpes, costos, hitos")
	var balance: Dictionary = _balance()
	balance["milestones"] = { "at": [25, 50, 100], "multiplier": 2 }
	var e: EconomyScript = EconomyScript.new()
	e.load_balance(balance)
	e.clock = func() -> float: return _now
	e.owned[0] = 30
	e.resets = 1
	var gps: float = e.gold_per_second() / e.relic_multiplier()
	var cost: float = e.quote(0, EconomyScript.BuyMode.X1)["cost"]
	var hit: float = e.hit_value()
	_light(e, ["core", "c_capataz", "c_contrato"])
	_check_near(e.gold_per_second() / e.relic_multiplier(), gps * 1.25, "Capataz 5: cuadrilla x1,25")
	_check_near(e.quote(0, EconomyScript.BuyMode.X1)["cost"], cost * 0.8, "Contrato barato 5: -20%")
	var bought_with: float = e.quote(0, EconomyScript.BuyMode.X1)["cost"]
	e.gold = bought_with
	_check_eq(e.buy_generator(0, EconomyScript.BuyMode.MAX), 1, "y en modo Máx usa el precio con descuento")
	_check_eq(e.milestone_step(), 2.0, "sin Hitos dorados el hito duplica")
	_light(e, ["c_hitos"])
	_check_near(e.milestone_step(), 2.5, "Hitos dorados 5: x2,5")
	e.owned[0] = 30
	var before: float = e.hit_value()
	_light(e, ["f_brazo", "f_templado"])
	_check(e.hit_value() > before * 2.0, "Brazo y Pico templado suben el golpe")
	_check(hit > 0.0, "(había golpe)")
	_light(e, ["f_ojo"])
	_check_near(e.crit_chance(), 0.15, "Ojo certero 5: +15% de crítico")
	e.free()


func _test_chest_effects() -> void:
	_section("Estrellas: cofres")
	var e: EconomyScript = _make([])
	e.resets = 1
	e.owned[0] = 30
	var per_hit: float = e.loot_chance_per_hit()
	var per_second: float = e.loot_chance_per_second()
	var reward: float = e.loot_reward(0) / e.relic_multiplier()
	_light(e, ["core", "o_olfato", "o_botin"])
	_check_near(e.loot_chance_per_hit(), per_hit * 2.0, "Olfato 5: el doble de cofres por golpe")
	_check_near(e.loot_chance_per_second(), per_second * 2.0, "y de la cuadrilla")
	_check_near(e.loot_reward(0) / e.relic_multiplier(), reward * 2.25, "Botín generoso 5: x2,25 de oro por cofre")
	_light(e, ["o_gemologo"])
	var table: Array[Dictionary] = e.loot_table()
	_check_near(table[1]["chance"], 0.17 * 2.5, "Gemólogo 3: Raros x2,5")
	_check_near(table[0]["chance"], 0.78 - 0.17 * 1.5, "y salen de los Comunes")
	_check_near(table[3]["chance"], 0.005, "el Legendario no se diluye")
	_light(e, ["o_doble", "o_dragon", "o_corona", "o_reliquia", "o_apostador"])
	table = e.loot_table()
	_check_eq(table[0]["chance"], 0.0, "Apostador: sin Comunes")
	var relics: int = e.relics
	var drops: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _amount: float) -> void: drops.append(rarity))
	e.rng.seed = 3
	for i: int in range(200):
		e.drop_loot(3)
	_check(drops.size() > 200, "a veces el cofre sale doble (%d de 200)" % drops.size())
	_check(e.relics - relics > drops.size(), "Reliquia escondida: más de una reliquia por Legendario")
	_check(e.last_chest_relics >= 1, "y dice cuántas dio el último")
	e.free()


func _test_active_play_effects() -> void:
	_section("A la par y Racha")
	var e: EconomyScript = _make()
	e.resets = 1
	e.owned[0] = 30
	_light(e, ["core", "c_capataz", "c_hitos", "c_memoria", "c_mina"])
	_now = 2000.0
	var idle: float = e.gold_per_second()
	e.hit()
	_check_near(e.gold_per_second(), idle / 0.7 * 1.3, "A la par: golpeando x1,3; sin golpear x0,7")
	_now += 5.1
	_check_near(e.gold_per_second(), idle, "a los 5 s sin golpear vuelve a x0,7")
	_light(e, ["t_mecha", "t_polvora", "t_veta", "t_racha"])
	_now = 3000.0
	_check_eq(e.streak_bonus(), 0.0, "sin golpear no hay racha")
	for i: int in range(125):
		e.hit()
		_now += 1.0
	_check_near(e.streak_bonus(), 0.04, "2 minutos golpeando: +4%")
	for i: int in range(1200):
		e.hit()
		_now += 1.0
	_check_near(e.streak_bonus(), 0.30, "tope +30%")
	_now += 6.0
	_check_eq(e.streak_bonus(), 0.0, "5 s sin golpear la cortan")
	e.free()


func _test_gold_vein() -> void:
	_section("Veta rica")
	var e: EconomyScript = _make()
	e.resets = 1
	e.pick_level = 3
	_light(e, ["core", "t_mecha", "t_polvora"])
	var plain: float = e.hit() / e.relic_multiplier()
	_light(e, ["t_veta"])
	e.run_gold = 0.0
	var tripled: float = e.hit()
	_check_near(tripled / e.relic_multiplier(), plain * 3.0, "antes del 95% de la meta el golpe da el triple")
	_check_near(e.run_gold, tripled, "y hit() devuelve lo que se ganó")
	e.run_gold = 0.0
	e.grant_gold(10.0)
	_check_near(e.run_gold, 30.0, "todo el oro ganado va x3")
	e.run_gold = _gold_for_depth(e.return_depth() * 0.96)
	var at: float = e.run_gold
	e.grant_gold(10.0)
	_check_near(e.run_gold, at + 10.0, "pasada la línea, lo de siempre")
	e.run_gold = 0.0
	e.owned[0] = 10
	var report: Dictionary = e.apply_offline(100.0)
	_check_near(e.run_gold, float(report["gold"]), "el AFK no se triplica")
	e.free()


func _test_offline_effects() -> void:
	_section("AFK")
	var e: EconomyScript = _make()
	e.resets = 1
	e.owned[0] = 100
	_check_near(e.offline_efficiency(), 0.05, "base 5%")
	_light(e, ["core", "t_vigilia", "t_noche"])
	_check_near(e.offline_efficiency(), 0.12, "Vigilia 3: 12%")
	_check_near(e.offline_max_seconds(), 12.0 * 3600.0, "Turno noche 2: 12 h")
	e.run_gold = 0.0
	var plain: float = float(e.apply_offline(3600.0)["gold"]) / e.relic_multiplier()
	_light(e, ["c_capataz", "c_hitos", "c_memoria", "c_mina", "t_mecha", "t_polvora", "t_veta", "t_racha", "t_cuenta", "p_turnos"])
	e.owned[0] = 100
	e.run_gold = 0.0
	e.hit()
	e.run_gold = 0.0
	var more: float = float(e.apply_offline(3600.0)["gold"]) / e.relic_multiplier()
	_check_near(more / plain, 1.25 * 0.7 * 1.5, "Capataz x1,25, A la par sin golpear x0,7 (aunque acabe de golpear) y Turnos x1,5", 1e-6)
	e.free()


func _test_carry_over_between_descents() -> void:
	_section("Lo que se arrastra a la bajada siguiente")
	var e: EconomyScript = _make()
	e.resets = 1
	_light(e, ["core", "c_capataz", "c_contrato"])
	e.owned[0] = 40
	e.owned[1] = 10
	e.pick_level = 3
	e.run_gold = _gold_for_depth(e.return_depth() + 1.0)
	var gps: float = e.gold_per_second()
	e.prestige()
	_check_eq(e.owned, [0, 0] as Array[int], "sin estrellas de arrastre se empieza de cero")
	_check(e.at_surface, "estás en la superficie")
	_check(e.buy_star("c_bolsa"), "Bolsa comprada justo al volver")
	_check_near(e.gold, 10.0 * gps, "da los 10 s de producción de la bajada anterior", 1e-6)
	_check_eq(e.run_gold, 0.0, "que no cuentan para la profundidad")
	_check(e.buy_star("c_bolsa"), "nivel 2")
	_check_near(e.gold, 20.0 * gps, "suma la diferencia, no la vuelve a dar entera", 1e-6)
	_check(e.buy_star("c_ventaja"), "Ventaja")
	_check_eq(e.owned, [10, 2] as Array[int], "25% de la cuadrilla, redondeando hacia abajo")
	_check(e.buy_star("c_hitos"), "Hitos")
	_check(e.buy_star("c_memoria"), "Memoria")
	_check_eq(e.pick_level, 3, "recupera el pico")
	e.hit()
	var owned: Array[int] = e.owned.duplicate()
	_check(e.buy_star("c_ventaja"), "ya empezada la bajada se puede comprar")
	_check_eq(e.owned, owned, "pero recién se aplica en la siguiente")
	e.run_gold = _gold_for_depth(e.return_depth() + 1.0)
	e.owned[0] = 20
	e.prestige()
	_check_eq(e.owned[0], 10, "50% de 20 mineros al volver")
	e.free()


func _test_keystones_change_on_the_next_descent() -> void:
	_section("Piedras angulares: en cualquier momento, desde la próxima bajada")
	var e: EconomyScript = _make()
	e.resets = 1
	_light(e, ["core", "f_brazo", "f_templado", "f_eco", "f_combo", "f_umbral", "f_furia"])
	_check(e.relic_tree.active_keystones.has("f_furia"), "activa al comprarla")
	_check(e.set_keystone("f_furia", false), "en la superficie se apaga")
	_check(not e.relic_tree.active_keystones.has("f_furia") and e.relic_tree.mul("crit_chance_mul") == 1.0, "y se aplica ya")
	_check(e.set_keystone("f_furia", true), "y se prende")
	_check(e.relic_tree.active_keystones.has("f_furia"), "también ya")
	e.hit()
	_check(not e.at_surface, "con un golpe ya empezó la bajada")
	_check(e.set_keystone("f_furia", false), "se puede cambiar igual")
	_check(e.relic_tree.active_keystones.has("f_furia"), "pero en esta bajada sigue activa")
	_check_near(e.relic_tree.mul("crit_chance_mul"), 0.5, "con su efecto")
	_check_eq(e.keystone_pending("f_furia"), -1, "queda anotado que se apaga")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict()))
	var other: EconomyScript = _make()
	other.from_dict(saved)
	_check_eq(other.keystone_pending("f_furia"), -1, "y sigue anotado al volver a abrir")
	other.free()
	e.run_gold = _gold_for_depth(e.return_depth() + 1.0)
	e.prestige()
	_check(not e.relic_tree.active_keystones.has("f_furia"), "al empezar la próxima se apaga")
	_check_eq(e.keystone_pending("f_furia"), 0, "y ya no queda nada pendiente")
	e.hit()
	e.set_keystone("f_furia", true)
	_check_eq(e.keystone_pending("f_furia"), 1, "prender a mitad de bajada queda pendiente")
	_check_near(float(e.frenzy_settings()["hits_per_second"]), 3.0, "Mano rápida baja el umbral del frenesí de 4 a 3")
	e.free()


func _test_fragments_and_debug_helpers() -> void:
	_section("Fragmentos y atajos de prueba")
	var e: EconomyScript = _make()
	e.add_fragments(25)
	_check_eq(e.relics, 1, "20 fragmentos = 1 reliquia")
	e.add_fragments(15)
	_check_eq(e.relics, 2, "con 40, dos")
	_check_eq(e.fragments, 40, "los fragmentos se cuentan")
	_check_eq(e.claimed_relics, 0, "no corren la meta")
	e.grant_relics(10)
	_check_eq(e.available_relics(), 12, "reliquias a mano")
	e.open_rings()
	_check(e.resets >= 25 and e.record_depth >= 400.0, "abre los anillos")
	e.reset()
	_check_eq(e.relics + e.fragments + e.resets + e.claimed_relics + e.relic_tree.total_levels(), 0, "borrar todo")
	e.free()


func _test_tap_cap() -> void:
	_section("Tope de golpes")
	var e: EconomyScript = _make()
	_now = 4000.0
	var landed: int = 0
	for i: int in range(20):
		if e.tap() > 0.0:
			landed += 1
	_check_eq(landed, 6, "solo 6 en el mismo segundo")
	var gold: float = e.gold
	e.tap()
	_check_eq(e.gold, gold, "el que sobra no da nada")
	_now += 1.01
	_check(e.tap() > 0.0, "al segundo vuelve a entrar")
	e.free()


func _test_save_roundtrip() -> void:
	_section("Guardado")
	var e: EconomyScript = _make()
	e.resets = 3
	e.claimed_relics = 40
	e.relics = 50
	e.fragments = 27
	_light(e, ["core", "c_capataz", "c_contrato", "c_bolsa"])
	e.run_gold = _gold_for_depth(e.return_depth() + 1.0)
	e.owned[0] = 12
	e.prestige()
	var copy: EconomyScript = _make()
	copy.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	for key: String in ["relics", "claimed_relics", "fragments", "resets", "at_surface"]:
		_check_eq(copy.get(key), e.get(key), "vuelve %s" % key)
	_check_near(copy.gold, e.gold, "vuelve el oro de la Bolsa", 1e-9)
	_check_eq(copy.run_gold, 0.0, "que sigue sin contar para la profundidad")
	_check_near(copy.record_depth, e.record_depth, "vuelve el récord")
	_check_near(copy.return_depth(), e.return_depth(), "vuelve la meta de la bajada")
	_check_eq(copy.relic_tree.level("c_bolsa"), 3, "vuelven las estrellas")
	var gold: float = copy.gold
	_check(copy.buy_star("c_ventaja"), "tras cargar, en la superficie")
	_check_near(copy.gold, gold, "la Bolsa no se da dos veces")
	_check_eq(copy.owned[0], 3, "y Ventaja usa la bajada anterior guardada")
	e.free()
	copy.free()


func _test_old_saves_keep_their_relics() -> void:
	_section("Partidas anteriores al árbol")
	var e: EconomyScript = _make()
	var run_gold: float = _gold_for_depth(e.prestige_min_depth() + 5.0)
	e.from_dict({ "balance_version": 2, "relics": 12, "gold": 5.0, "run_gold": run_gold, "owned": [7, 1], "pick_level": 2, "max_biome": 2 })
	_check_eq(e.relics, 12, "conserva las reliquias")
	_check_eq(e.available_relics(), 12, "todas para gastar")
	_check_eq(e.claimed_relics, 12, "cuentan como sacadas de bajadas")
	_check_eq(e.resets, 1, "y como un reset hecho")
	_check_eq(e.owned, [7, 1] as Array[int], "la bajada en curso sigue")
	_check_near(e.return_depth(), e.prestige_min_depth(), "con su meta de siempre")
	_check(e.can_prestige(), "así que puede volver como antes")
	_check_eq(e.pending_tree_report.get("relics"), 12, "queda el aviso para el jugador")
	e.dismiss_tree_report()
	_check(e.pending_tree_report.is_empty(), "que se cierra")
	_check(e.buy_star("core"), "el Corazón está disponible")
	_check_eq(e.to_dict().get("balance_version"), 3, "y ya queda guardada como nueva")
	e.from_dict({ "balance_version": 2, "relics": 0, "gold": 3.0, "run_gold": 3.0, "owned": [0, 0] })
	_check(e.pending_tree_report.is_empty(), "sin reliquias no hay nada que avisar")
	_check_eq(e.resets, 0, "ni reset regalado")
	e.free()
