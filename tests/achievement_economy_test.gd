extends "res://tests/test_base.gd"
## core/economy.gd con logros (sección "achievements" del balance): contadores históricos que se llevan solos,
## desbloqueo y fragmentos, aviso agrupado, secretos y guardado. Con el balance real.

const EconomyScript := preload("res://core/economy.gd")

var _now: float = 100.0


func _initialize() -> void:
	_test_without_achievements()
	_test_actions_are_counted()
	_test_unlocking_pays_fragments_in_one_notice()
	_test_depth_resets_and_crew()
	_test_tree_achievements()
	_test_time_counters()
	_test_frenzy_and_tap_rate()
	_test_secrets()
	_test_save_and_old_saves()
	_finish()


func _balance() -> Dictionary:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	balance["tree"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/arbol.json"))
	balance["achievements"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/logros.json"))
	balance.erase("loot")
	balance["crit"] = { "chance": 0.0, "multiplier": 2 }
	return balance


func _make(balance: Dictionary = {}) -> EconomyScript:
	var e: EconomyScript = EconomyScript.new()
	var data: Dictionary = _balance() if balance.is_empty() else balance
	_check(e.load_balance(data), "carga el balance (%s)" % e.last_error)
	e.clock = func() -> float: return _now
	e.hour_of_day = func() -> int: return 15
	return e


func _depth_gold(meters: float) -> float:
	return 8.0 * (pow(2.0, meters / 15.0) - 1.0)


func _test_without_achievements() -> void:
	_section("Sin logros en el balance no pasa nada")
	var balance: Dictionary = _balance()
	balance.erase("achievements")
	var e: EconomyScript = _make(balance)
	_check(not e.has_achievements(), "no hay logros")
	e.count("loot_views")
	e.hit()
	_check_eq(e.check_achievements().size(), 0, "ni se consiguen")
	_check(not e.to_dict().has("achievements"), "ni se guardan")
	e.free()


func _test_actions_are_counted() -> void:
	_section("Lo que hacés se cuenta")
	var balance: Dictionary = _balance()
	balance["loot"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))["loot"]
	balance["loot"]["chance_per_hit"] = 0.0
	balance["loot"]["chance_per_second"] = 0.0
	var e: EconomyScript = _make(balance)
	var gold: float = 0.0
	for i: int in range(3):
		gold += e.hit()
	_check_eq(e.stat("hits"), 3.0, "3 golpes")
	_check_eq(e.stat("crits"), 0.0, "ningún crítico")
	_check_near(e.stat("gold_earned"), gold, "el oro ganado")
	var sure: Dictionary = balance.duplicate(true)
	sure["crit"] = { "chance": 1.0, "multiplier": 2 }
	var c: EconomyScript = _make(sure)
	c.hit()
	_check_eq(c.stat("crits"), 1.0, "un crítico")
	e.drop_loot(1)
	e.drop_loot(1)
	e.drop_loot(0)
	_check_eq(e.stat("chests"), 3.0, "3 cofres")
	_check_eq(e.stat("chest_rare"), 2.0, "2 Raros")
	e.owned[2] = 1
	e.gold = 1.0e9
	e.upgrade_ability()
	e.use_ability()
	_check_eq(e.stat("dynamite"), 1.0, "una dinamita")
	e.count("loot_views", 2.0)
	_check_eq(e.stat("loot_views"), 2.0, "lo que cuenta la interfaz")
	e.free()
	c.free()


func _test_unlocking_pays_fragments_in_one_notice() -> void:
	_section("Conseguir paga fragmentos, en un solo aviso")
	var e: EconomyScript = _make()
	var notices: Array = []
	e.achievements_unlocked.connect(func(ids: Array) -> void: notices.append(ids))
	e.achievements.add("hits", 1000.0)
	e.achievements.add("crits", 100.0)
	var new_ones: Array[String] = e.check_achievements()
	_check_eq(new_ones, ["hits_100", "hits_1000", "crits_100"] as Array[String], "tres de una")
	_check_eq(notices.size(), 1, "un solo aviso")
	_check_eq(e.pending_achievements, new_ones, "que queda pendiente hasta que la pantalla lo muestre")
	_check_eq(e.fragments, 6, "+6 fragmentos")
	e.check_achievements()
	_check_eq(e.fragments, 6, "no se pagan dos veces")
	e.dismiss_achievements()
	_check(e.pending_achievements.is_empty(), "visto")
	e.achievements.add("gear_opens", 50.0)
	e.achievements.add("hits", 9000.0)
	e.achievements.add("crits", 900.0)
	e.check_achievements()
	_check_eq(e.fragments, 6 + 2 + 5 + 5, "engranaje, 10.000 golpes y 1.000 críticos")
	_check_eq(e.relics, 0, "18 fragmentos todavía no son una reliquia")
	_check(e.unlock_achievement("loot_views_25"), "uno a mano (pruebas)")
	_check_eq(e.fragments, 20, "paga igual")
	_check_eq(e.relics, 1, "y con 20 hay una reliquia")
	_check_eq(e.pending_achievements.size(), 4, "se juntan en el aviso pendiente")
	e.free()


func _test_depth_resets_and_crew() -> void:
	_section("Profundidad, vueltas y cuadrilla")
	var e: EconomyScript = _make()
	e.owned[0] = 26
	e.run_gold = _depth_gold(205.0)
	var new_ones: Array[String] = e.check_achievements()
	_check(new_ones.has("record_depth_100") and new_ones.has("record_depth_200") and new_ones.has("max_miner_25"), "205 m y 26 mineros (%s)" % str(new_ones))
	e.owned[0] = 0
	_check_eq(e.stat("max_miner"), 26.0, "el máximo queda guardado")
	e.run_gold = _depth_gold(302.0)
	e.prestige()
	e.check_achievements()
	_check(e.achievements.is_unlocked("resets_1"), "volviste")
	_check(e.stat("best_reset") >= 2.0, "las reliquias de la mejor bajada (%d)" % int(e.stat("best_reset")))
	_check_eq(e.stat("resets"), 1.0, "una vuelta")
	e.run_shift = 240.0
	e.run_gold = _depth_gold(551.0)
	e.prestige()
	_check(e.achievements.is_unlocked("overshoot_10"), "pasar una meta de 540 m por 10 se ve al volver, antes de reiniciar")
	e.free()


func _test_tree_achievements() -> void:
	_section("Los del árbol")
	var e: EconomyScript = _make()
	e.resets = 1
	e.grant_relics(5000)
	e.buy_star("core")
	_check(e.check_achievements().has("star_core_1"), "encender el Corazón")
	e.open_rings()
	var again: bool = true
	while again:
		again = false
		for id: String in e.relic_tree.ids():
			if e.buy_star(id):
				again = true
	var new_ones: Array[String] = e.check_achievements()
	for id: String in ["stars_10", "ring1_done_1", "ring2_done_1", "keystones_1", "keystones_4", "bridges_1", "complete_1"]:
		_check(new_ones.has(id), "árbol completo: %s" % id)
	e.free()


func _test_time_counters() -> void:
	_section("Tiempo jugado, activo y AFK")
	var e: EconomyScript = _make()
	e.owned[0] = 5
	var usec: int = 1000000
	e.tick_realtime(usec)
	for i: int in range(10):
		usec += 1000000
		_now += 1.0
		e.tick_realtime(usec)
	_check_near(e.stat("play_seconds"), 10.0, "10 s de juego", 1e-6)
	_check_eq(e.stat("active_seconds"), 0.0, "sin golpear no es tiempo activo")
	e.hit()
	for i: int in range(8):
		usec += 1000000
		_now += 1.0
		e.tick_realtime(usec)
	_check_near(e.stat("active_seconds"), 4.0, "activo mientras el último golpe tiene menos de 5 s", 1e-6)
	usec += 3600 * 1000000
	e.tick_realtime(usec)
	_check_near(e.stat("afk_seconds"), 3600.0, "una hora fuera es AFK", 1e-6)
	_check_near(e.stat("play_seconds"), 18.0, "y no es tiempo jugado", 1e-6)
	_check_near(e.stat("max_away"), 3600.0, "la ausencia más larga", 1e-6)
	e.apply_offline_since(1000, 1000.0 + 90000.0)
	_check(e.check_achievements().has("max_away_86400"), "volver después de más de 24 h")
	_check_near(e.stat("afk_seconds"), 3600.0 + 8.0 * 3600.0, "AFK acreditado con su tope", 1e-6)
	e.free()


func _test_frenzy_and_tap_rate() -> void:
	_section("Frenesí y golpes por segundo")
	var e: EconomyScript = _make()
	var usec: int = 1000000
	e.tick_realtime(usec)
	e.set_frenzy(true)
	e.set_frenzy(true)
	_check_eq(e.stat("frenzy_starts"), 1.0, "se prendió una vez")
	for i: int in range(61):
		usec += 1000000
		e.tick_realtime(usec)
	e.set_frenzy(false)
	e.set_frenzy(true)
	usec += 1000000
	e.tick_realtime(usec)
	_check_near(e.stat("frenzy_seconds"), 62.0, "segundos de frenesí en total", 1e-6)
	_check_near(e.stat("frenzy_best"), 61.0, "el más largo seguido", 1e-6)
	_check(e.check_achievements().has("frenzy_best_60"), "un minuto sin respirar")
	_now = 500.0
	for i: int in range(20):
		e.tap()
	_check_near(e.stat("max_hps"), 2.0, "20 toques en 10 s, aunque el tope solo cuente 6")
	_now = 520.0 # la ráfaga anterior ya salió de la ventana
	for i: int in range(80):
		_now += 0.125
		e.tap()
	_check_near(e.stat("max_hps"), 8.0, "ritmo sostenido de 8/s", 0.05)
	e.free()


func _test_secrets() -> void:
	_section("Secretos")
	var e: EconomyScript = _make()
	e.hour_of_day = func() -> int: return 4
	e.hit()
	_check(e.check_achievements().has("night_play_1"), "jugar a las 4 de la mañana")
	e.reset()
	e.run_gold = _depth_gold(101.0)
	_check(e.check_achievements().has("no_hit_rock_1"), "llegar a Roca sin golpear")
	e.reset()
	e.hit()
	e.run_gold = _depth_gold(101.0)
	_check(not e.check_achievements().has("no_hit_rock_1"), "con un golpe en la bajada no vale")
	e.free()
	var balance: Dictionary = _balance()
	balance["loot"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))["loot"]
	balance["loot"]["chance_per_hit"] = 1.0
	for rarity: Dictionary in balance["loot"]["rarities"]:
		rarity["weight"] = 1.0 if rarity["id"] == "legendary" else 0.0
	var plain: EconomyScript = _make(balance)
	plain.hit()
	_check(not plain.check_achievements().has("crit_rarest_1"), "un Legendario sin crítico no")
	plain.free()
	balance["crit"] = { "chance": 1.0, "multiplier": 2 }
	var lucky: EconomyScript = _make(balance)
	lucky.hit()
	_check(lucky.check_achievements().has("crit_rarest_1"), "un golpe crítico que suelta un Legendario")
	lucky.free()


func _test_save_and_old_saves() -> void:
	_section("Guardado y partidas anteriores")
	var e: EconomyScript = _make()
	e.achievements.add("hits", 150.0)
	e.check_achievements()
	var copy: EconomyScript = _make()
	copy.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	_check_eq(copy.stat("hits"), 150.0, "vuelven los contadores")
	_check_eq(copy.fragments, 2, "y los fragmentos")
	_check_eq(copy.check_achievements().size(), 0, "no se paga dos veces")
	_check(copy.pending_achievements.is_empty(), "ni se avisa de nuevo")
	var old: EconomyScript = _make()
	old.from_dict({ "balance_version": 2, "relics": 12, "gold": 10.0, "run_gold": _depth_gold(310.0), "owned": [60, 30, 0, 0, 0, 0], "max_biome": 3 })
	var found: Array[String] = old.check_achievements()
	_check(found.size() >= 6, "quien venía jugando recibe de golpe los que ya cumplía (%d)" % found.size())
	_check(found.has("resets_1") and found.has("record_depth_300") and found.has("max_miner_50") and found.has("max_steam_drill_25"), "vuelta, Magma y cuadrilla (%s)" % str(found))
	old.reset()
	_check_eq(old.achievements.unlocked_count() + int(old.stat("hits")) + old.fragments, 0, "borrar todo también borra los logros")
	e.free()
	copy.free()
	old.free()
