extends "res://tests/test_base.gd"
## Tests headless del progreso offline de core/economy.gd (hasta 8 horas, con aviso al volver).
##
## Casi todos los tests usan una instancia propia de Economy SIN agregarla al árbol. El último
## (arranque desde un save real) agrega una al árbol para ejercitar _ready() y el autoload Save.

const EconomyScript := preload("res://core/economy.gd")
const TestBalance := preload("res://tests/test_balance.gd")

const HOUR: float = 3600.0
const MAX_SECONDS: float = 8.0 * 3600.0
const TEST_SAVE_PATH: String = "user://offline_test_save.json"

var _nodes: Array[Node] = []


func _initialize() -> void:
	_test_credit_and_report()
	_test_away_efficiency()
	_test_signal_and_gold_changed()
	_test_cap_at_8_hours()
	_test_uses_current_multiplier()
	_test_no_production_no_report()
	_test_clock_going_backwards()
	_test_short_absences_are_credited_without_notice()
	_test_reports_accumulate_until_dismissed()
	_test_offline_does_not_roll_loot()
	_test_offline_gold_counts_for_depth()
	_test_apply_offline_since()
	_test_report_is_not_saved()
	_test_in_session_gaps_go_through_offline()
	_test_frozen_monotonic_clock()
	_test_in_session_gap_without_offline_section()
	_test_balance_validation()
	_test_real_balance_file()
	await _test_boot_from_a_real_save()
	for node: Node in _nodes:
		node.free()
	_finish()


func _make(balance: Dictionary = TestBalance.make(["loot"])) -> EconomyScript:
	var economy: EconomyScript = EconomyScript.new()
	_nodes.append(economy)
	if not economy.load_balance(balance):
		printerr("    el balance de prueba no cargó: ", economy.last_error)
	return economy


## Economía con 10 oro/s (10 Mineros de 1 oro/s, en Tierra y sin reliquias).
func _crew() -> EconomyScript:
	var e: EconomyScript = _make()
	e.owned[0] = 10
	return e


func _test_credit_and_report() -> void:
	_section("Acredita lo que produjo la cuadrilla")
	var e: EconomyScript = _crew()
	_check_eq(e.offline_max_seconds(), MAX_SECONDS, "el tope son 8 h (28.800 s)")
	var report: Dictionary = e.apply_offline(HOUR)
	_check_eq(e.gold, 36000.0, "1 h * 10 oro/s = 36.000")
	_check_eq(e.run_gold, 36000.0, "cuenta como oro ganado de la partida")
	_check_eq(report.get("seconds"), HOUR, "el reporte dice 3.600 s acreditados")
	_check_eq(report.get("gold"), 36000.0, "y 36.000 de oro")
	_check_eq(report.get("capped"), false, "sin tope")
	_check_eq(e.pending_offline_report, report, "queda pendiente para avisarle al jugador")
	e.dismiss_offline_report()
	_check(e.pending_offline_report.is_empty(), "dismiss_offline_report() lo limpia")
	_check_eq(e.gold, 36000.0, "y el oro ya estaba acreditado")


## Afuera la cuadrilla rinde menos; los primeros `away_seconds` pagan completo, así volver a los 2:01 no da menos
## que volver a los 1:59.
func _test_away_efficiency() -> void:
	_section("AFK al 25%, con los primeros 2 minutos al 100%")
	var quarter: Dictionary = TestBalance.make(["loot"])
	quarter["offline"]["efficiency"] = 0.25
	var e: EconomyScript = _make(quarter)
	e.owned[0] = 10
	_check_eq(e.offline_efficiency(), 0.25, "la eficiencia sale del balance")
	var report: Dictionary = e.apply_offline(HOUR)
	_check_near(e.gold, 10.0 * (120.0 + 3480.0 * 0.25), "1 h: 2 min completos y 58 min al 25% = 9.900")
	_check_eq(report.get("seconds"), HOUR, "el reporte dice el tiempo real fuera")
	_check_near(report.get("gold"), 9900.0, "y el oro que se pagó")
	var short: EconomyScript = _make(quarter)
	short.owned[0] = 10
	short.apply_offline(100.0)
	_check_near(short.gold, 1000.0, "menos de 2 min: completo")
	var edge: EconomyScript = _make(quarter)
	edge.owned[0] = 10
	edge.apply_offline(121.0)
	_check_near(edge.gold, 10.0 * 120.25, "a los 2:01 paga un poco más que a los 2:00, no menos")
	var long: EconomyScript = _make(quarter)
	long.owned[0] = 10
	_check_eq(long.apply_offline(20.0 * HOUR).get("capped"), true, "el tope de 8 h es sobre el tiempo real")
	_check_near(long.gold, 10.0 * (120.0 + (MAX_SECONDS - 120.0) * 0.25), "8 h: 72.900")
	for bad: Variant in [-0.1, 1.5, "mucho"]:
		var broken: Dictionary = TestBalance.make(["loot"])
		broken["offline"]["efficiency"] = bad
		_check_eq(e.load_balance(broken), false, "offline.efficiency = %s -> inválido" % str(bad))


func _test_signal_and_gold_changed() -> void:
	_section("Señales")
	var e: EconomyScript = _crew()
	var reports: Array[Dictionary] = []
	var golds: Array[float] = []
	e.offline_progress.connect(func(report: Dictionary) -> void: reports.append(report))
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	e.apply_offline(120.0)
	_check_eq(reports.size(), 1, "emite offline_progress una vez")
	_check_eq(reports[0].get("gold"), 1200.0, "con el reporte (1.200 de oro)")
	_check_eq(golds, [1200.0] as Array[float], "y gold_changed una vez, con el oro final")


func _test_cap_at_8_hours() -> void:
	_section("Tope de 8 horas")
	var e: EconomyScript = _crew()
	var report: Dictionary = e.apply_offline(MAX_SECONDS)
	_check_eq(e.gold, 288000.0, "justo 8 h = 288.000")
	_check_eq(report.get("capped"), false, "justo 8 h no se considera cortado")
	var long_absence: EconomyScript = _crew()
	report = long_absence.apply_offline(20.0 * HOUR)
	_check_eq(long_absence.gold, 288000.0, "20 h fuera acreditan solo 8 h (288.000)")
	_check_eq(report.get("seconds"), MAX_SECONDS, "el reporte dice 28.800 s")
	_check_eq(report.get("capped"), true, "y avisa que se cortó")
	var forever: EconomyScript = _crew()
	forever.apply_offline(365.0 * 24.0 * HOUR)
	_check_eq(forever.gold, 288000.0, "un año fuera también: 288.000")


func _test_uses_current_multiplier() -> void:
	_section("Usa el multiplicador de hoy (bioma x reliquias)")
	var e: EconomyScript = _crew()
	e.relics = 2 # x1.5
	e.run_gold = 700.0 # Roca, x1.5
	var before: float = e.gold
	e.apply_offline(100.0)
	_check_near(e.gold - before, 10.0 * 2.25 * 100.0, "100 s * 10 oro/s * 2.25 = 2.250")


func _test_no_production_no_report() -> void:
	_section("Sin cuadrilla no hay nada que avisar")
	var e: EconomyScript = _make()
	var reports: Array[Dictionary] = []
	var golds: Array[float] = []
	e.offline_progress.connect(func(report: Dictionary) -> void: reports.append(report))
	e.gold_changed.connect(func(gold: float) -> void: golds.append(gold))
	var report: Dictionary = e.apply_offline(5.0 * HOUR)
	_check(report.is_empty(), "el reporte está vacío")
	_check_eq(e.gold, 0.0, "el oro no cambia")
	_check(e.pending_offline_report.is_empty(), "no queda aviso pendiente")
	_check_eq(reports.size() + golds.size(), 0, "no emite señales")


func _test_clock_going_backwards() -> void:
	_section("Reloj atrasado o inválido")
	var e: EconomyScript = _crew()
	for elapsed: float in [-100.0, 0.0, NAN]:
		_check(e.apply_offline(elapsed).is_empty(), "elapsed %s no acredita nada" % str(elapsed))
	_check_eq(e.gold, 0.0, "el oro sigue en 0")
	_check(e.pending_offline_report.is_empty(), "y no hay aviso")


## Menos de 2 minutos fuera cuenta como juego activo: se acredita igual y sin cartel.
func _test_short_absences_are_credited_without_notice() -> void:
	_section("Ausencias cortas: se acreditan, sin aviso")
	var e: EconomyScript = _crew()
	var reports: Array[Dictionary] = []
	e.offline_progress.connect(func(report: Dictionary) -> void: reports.append(report))
	var report: Dictionary = e.apply_offline(30.0)
	_check_eq(e.gold, 300.0, "30 s * 10 oro/s = 300 acreditados")
	_check_eq(report.get("gold"), 300.0, "el reporte devuelto sí existe")
	_check(e.pending_offline_report.is_empty(), "pero no queda aviso pendiente")
	_check_eq(reports.size(), 0, "ni se emite offline_progress")
	e.apply_offline(119.9)
	_check_eq(reports.size(), 0, "119.9 s sigue sin aviso")
	e.apply_offline(120.0)
	_check_eq(reports.size(), 1, "120 s ya avisa")
	_check(not e.pending_offline_report.is_empty(), "y queda pendiente")


## Si volvés dos veces antes de cerrar el cartel, el aviso suma ambas (no esconde la primera).
func _test_reports_accumulate_until_dismissed() -> void:
	_section("Avisos sin cerrar se acumulan")
	var e: EconomyScript = _make()
	e.owned[0] = 2 # 2 oro/s
	e.apply_offline(120.0) # 240 de oro
	e.apply_offline(120.0) # 480 en total: todavía en Tierra (140 m)
	_check_eq(e.pending_offline_report.get("gold"), 480.0, "240 + 240 = 480 de oro en el aviso")
	_check_eq(e.pending_offline_report.get("seconds"), 240.0, "240 s en total")
	_check_eq(e.pending_offline_report.get("capped"), false, "sin tope")
	_check_eq(e.gold, 480.0, "y el oro acreditado coincide")
	e.apply_offline(20.0 * HOUR)
	_check_eq(e.pending_offline_report.get("capped"), true, "si una de las dos se cortó, el aviso lo dice")
	e.dismiss_offline_report()
	var rate: float = e.gold_per_second() # con tanto oro ya está en otro bioma: rinde más
	e.apply_offline(150.0)
	_check_near(e.pending_offline_report.get("gold"), rate * 150.0, "después de cerrarlo, el aviso nuevo arranca de cero (solo 150 s)")
	_check_eq(e.pending_offline_report.get("seconds"), 150.0, "150 s")


func _test_offline_does_not_roll_loot() -> void:
	_section("Offline no tira cofres")
	var balance: Dictionary = TestBalance.make()
	balance["loot"]["chance_per_hit"] = 1.0
	balance["loot"]["chance_per_second"] = 1.0
	var e: EconomyScript = _make(balance)
	e.owned[0] = 10
	var drops: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _amount: float) -> void: drops.append(rarity))
	e.apply_offline(8.0 * HOUR)
	_check_eq(drops.size(), 0, "ningún cofre, aunque la probabilidad sea 100%")
	_check_eq(e.loot_bonus, 0.0, "ni bonus de botín")
	_check_eq(e.gold, 288000.0, "el oro es exactamente la producción")


func _test_offline_gold_counts_for_depth() -> void:
	_section("Lo ganado offline te hace bajar")
	var e: EconomyScript = _make()
	e.owned[0] = 1000 # 1.000 oro/s
	_check_eq(e.depth(), 0.0, "arranca en la superficie")
	e.apply_offline(MAX_SECONDS) # 28.8 millones de oro
	_check(e.depth() > 400.0, "después de 8 h offline está a %.0f m" % e.depth())
	_check(e.can_prestige(), "y ya puede volver a la superficie con reliquias")


func _test_apply_offline_since() -> void:
	_section("Desde la hora del último save")
	var e: EconomyScript = _crew()
	e.apply_offline_since(1000000, 1003600.0)
	_check_eq(e.gold, 36000.0, "guardado hace 1 h -> 36.000")
	var fresh: EconomyScript = _crew()
	_check(fresh.apply_offline_since(0, 1003600.0).is_empty(), "saved_at 0 (no había save): no hay offline")
	_check_eq(fresh.gold, 0.0, "el oro sigue en 0")
	_check(fresh.apply_offline_since(1005000, 1003600.0).is_empty(), "un save 'del futuro' (reloj atrasado) no acredita")
	_check_eq(fresh.gold, 0.0, "el oro sigue en 0")


## El aviso es del momento: no se escribe en el save (el oro sí, porque ya es oro).
func _test_report_is_not_saved() -> void:
	_section("El aviso no se guarda")
	var e: EconomyScript = _crew()
	e.apply_offline(HOUR)
	var data: Dictionary = e.to_dict()
	_check(not data.has("offline") and not data.has("pending_offline_report"), "to_dict no incluye el aviso")
	var restored: EconomyScript = _make()
	restored.from_dict(data)
	_check(restored.pending_offline_report.is_empty(), "y cargar un save no inventa un aviso")
	_check_eq(restored.gold, 36000.0, "pero el oro acreditado sí se conserva")


## Una pestaña oculta (o la app en segundo plano) no dibuja cuadros: al volver hay un hueco. Menos de 2 minutos
## cuenta como juego activo; de ahí en más es una ausencia (progreso offline, con tope y aviso).
func _test_in_session_gaps_go_through_offline() -> void:
	_section("Huecos dentro de la sesión: menos de 2 min es juego activo")
	var always: Dictionary = TestBalance.make()
	always["loot"]["chance_per_second"] = 1.0
	var e: EconomyScript = _make(always)
	e.owned[0] = 2 # 2 oro/s
	var drops: Array[int] = []
	e.loot_dropped.connect(func(rarity: int, _amount: float) -> void: drops.append(rarity))
	e.tick_realtime(1000000) # referencia
	e.tick_realtime(1000000 + 119000000) # 119 s oculta
	_check_near(e.gold, 238.0, "119 s se acreditan como juego activo (238)")
	_check(e.pending_offline_report.is_empty(), "sin aviso")
	_check_eq(drops.size(), 1, "y la cuadrilla puede encontrar cofres, como jugando")
	var away: EconomyScript = _make(always)
	away.owned[0] = 2
	drops.clear()
	away.loot_dropped.connect(func(rarity: int, _amount: float) -> void: drops.append(rarity))
	away.tick_realtime(1000000)
	away.tick_realtime(1000000 + 120000000) # 120 s oculta
	_check_near(away.gold, 240.0, "120 s también se acreditan")
	_check_eq(away.pending_offline_report.get("seconds"), 120.0, "pero como ausencia, con su aviso")
	_check_eq(drops.size(), 0, "y sin cofres")
	var long_gap: EconomyScript = _crew()
	long_gap.tick_realtime(1000000)
	long_gap.tick_realtime(1000000 + int(10.0 * HOUR * 1000000.0)) # 10 h
	_check_eq(long_gap.gold, 288000.0, "un hueco de 10 h acredita solo 8 h")
	_check_eq(long_gap.pending_offline_report.get("capped"), true, "y avisa que se cortó")


## En iPhone el reloj monotónico puede quedar frenado mientras el teléfono duerme: vale el que más avanzó.
func _test_frozen_monotonic_clock() -> void:
	_section("El reloj de pared respalda al monotónico")
	var e: EconomyScript = _crew()
	e.tick_realtime(1000000, 5000.0)
	e.tick_realtime(2000000, 5600.0) # 1 s para el monotónico, 10 min de verdad
	_check_near(e.gold, 6000.0, "se acreditan los 10 minutos (6.000)")
	_check_eq(e.pending_offline_report.get("seconds"), 600.0, "como ausencia, con aviso")
	e.dismiss_offline_report()
	e.tick_realtime(3000000, 100.0) # alguien atrasó el reloj del aparato
	_check_near(e.gold, 6000.0 + 10.0 * 1.5, "con el de pared atrasado manda el monotónico", 1e-6)
	_check(e.pending_offline_report.is_empty(), "sin aviso")


func _test_in_session_gap_without_offline_section() -> void:
	_section("Sin sección offline, los huecos se acreditan enteros")
	var e: EconomyScript = _make(TestBalance.make(["loot", "offline"]))
	e.owned[0] = 10
	_check(e.apply_offline(HOUR).is_empty(), "apply_offline no hace nada")
	_check_eq(e.offline_max_seconds(), 0.0, "tope 0")
	e.tick_realtime(1000000)
	e.tick_realtime(1000000 + 120000000) # 120 s
	_check_near(e.gold, 1200.0, "120 s * 10 oro/s = 1.200 como producción normal")
	_check(e.pending_offline_report.is_empty(), "sin aviso")


func _test_balance_validation() -> void:
	_section("Validación de offline")
	var e: EconomyScript = _crew()
	e.apply_offline(100.0)
	for key: String in ["max_hours", "away_seconds"]:
		var zero: Dictionary = TestBalance.make(["loot"])
		zero["offline"][key] = 0
		_check_eq(e.load_balance(zero), false, "offline.%s = 0 -> inválido" % key)
		_check(e.last_error.contains("offline"), "last_error nombra la sección (%s)" % e.last_error)
	var negative: Dictionary = TestBalance.make(["loot"])
	negative["offline"]["max_hours"] = -8
	_check_eq(e.load_balance(negative), false, "offline.max_hours negativo -> inválido")
	var missing: Dictionary = TestBalance.make(["loot"])
	missing["offline"].erase("away_seconds")
	_check_eq(e.load_balance(missing), false, "falta offline.away_seconds -> inválido")
	_check_eq(e.gold, 1000.0, "un balance inválido no toca el estado")
	_check_eq(e.offline_max_seconds(), MAX_SECONDS, "ni pisa el balance anterior")
	var other_cap: Dictionary = TestBalance.make(["loot"])
	other_cap["offline"]["max_hours"] = 2
	_check_eq(e.load_balance(other_cap), true, "otro tope es válido")
	_check_eq(e.offline_max_seconds(), 7200.0, "2 h = 7.200 s")
	_check(e.pending_offline_report.is_empty(), "cargar un balance limpia el aviso pendiente")


func _test_real_balance_file() -> void:
	_section("data/balance.json real")
	var e: EconomyScript = EconomyScript.new()
	_nodes.append(e)
	_check_eq(e.load_balance_file("res://data/balance.json"), true, "carga el balance real (%s)" % e.last_error)
	_check_eq(e.offline_max_seconds(), MAX_SECONDS, "tope de 8 horas")
	e.owned[0] = 10
	e.loot_dropped.connect(func(_rarity: int, _amount: float) -> void: _fail_loot())
	e.apply_offline(100.0 * HOUR)
	_check_near(e.gold, 72900.0, "100 h fuera acreditan 8 h (al 25% desde el minuto 2)")


func _fail_loot() -> void:
	_check(false, "el progreso offline no debe tirar cofres")


## De punta a punta: un save real en disco, el autoload Save que lo lee y un Economy nuevo que
## arranca (_ready) y acredita lo producido desde la hora del save.
func _test_boot_from_a_real_save() -> void:
	_section("Arranque desde un save real")
	await process_frame # en modo --script los autoloads recién corren _ready() después del primer frame
	var save: Node = root.get_node_or_null("Save")
	_check(save != null, "existe el autoload Save")
	if save == null:
		return
	var saved_at: int = int(Time.get_unix_time_from_system()) - 7200 # el save es de hace 2 h
	var payload: Dictionary = {
		"version": 1,
		"saved_at": saved_at,
		"sections": { "economy": { "gold": 100.0, "run_gold": 100.0, "owned": [10, 0, 0, 0, 0], "pick_level": 0 } },
	}
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var original_path: String = save.path
	save.path = TEST_SAVE_PATH
	save.persistence_enabled = true
	_check_eq(save.load_from_disk(), true, "Save lee el archivo")
	_check_eq(save.loaded_saved_at, saved_at, "y recuerda la hora del save")

	var booted: EconomyScript = EconomyScript.new()
	root.add_child(booted) # corre _ready(): carga balance, se registra en Save y acredita el offline
	_nodes.append(booted)
	_check(booted.gold >= 100.0 + 18900.0 and booted.gold < 100.0 + 18900.0 + 100.0, "100 de oro + 2 h afuera = ~19.000 (tiene %s)" % str(booted.gold))
	_check_eq(booted.pending_offline_report.get("capped"), false, "hay aviso pendiente, sin tope")
	_check(absf(float(booted.pending_offline_report.get("seconds", 0.0)) - 7200.0) < 5.0, "de ~2 h (%s s)" % str(booted.pending_offline_report.get("seconds")))
	_check_eq(booted.owned_count(0), 10, "y el resto del save se cargó")

	save.loaded_saved_at = 0 # un arranque sin save previo
	var fresh: EconomyScript = EconomyScript.new()
	root.add_child(fresh)
	_nodes.append(fresh)
	_check_eq(fresh.gold, 100.0, "con saved_at 0 no se acredita nada (queda lo que cargó el save)")
	_check(fresh.pending_offline_report.is_empty(), "ni hay aviso")

	# Deja el autoload Save como estaba: sin persistencia, sin archivo de prueba.
	save.persistence_enabled = false
	save.path = original_path
	save.loaded_saved_at = 0
	DirAccess.remove_absolute(TEST_SAVE_PATH)
