extends "res://tests/test_base.gd"
## Tests headless del frenesí: core/frenzy_meter.gd (cuándo el ritmo de golpes es "alto" el tiempo suficiente) y
## la sección "frenzy" del balance, que lee Economy.
##
## El medidor no mira el reloj: cada llamada recibe el segundo actual, así los tests no esperan en tiempo real.

const FrenzyMeter := preload("res://core/frenzy_meter.gd")
const EconomyScript := preload("res://core/economy.gd")
const TestBalance := preload("res://tests/test_balance.gd")

## Los umbrales de prueba (los de data/balance.json se pueden ajustar libremente).
const SETTINGS: Dictionary = { "hits_per_second": 4.0, "enter_seconds": 2.0, "exit_seconds": 3.0, "window_seconds": 1.0 }
## Paso de "frame" de la simulación.
const STEP: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func _initialize() -> void:
	_test_enters_after_sustained_rhythm()
	_test_slow_rhythm_never_enters()
	_test_short_burst_does_not_enter()
	_test_exits_after_quiet()
	_test_brief_pause_keeps_frenzy()
	_test_hold_keeps_frenzy()
	_test_disabled_without_settings()
	_test_balance_section()
	_test_real_balance()
	for node: Node in _nodes:
		node.free()
	_finish()


func _meter() -> FrenzyMeter:
	var meter: FrenzyMeter = FrenzyMeter.new()
	meter.configure(SETTINGS)
	return meter


## Simula `seconds` segundos golpeando `rate` veces por segundo (0 = sin golpes) desde `start`, llamando update cada
## frame. Devuelve el segundo en el que se prendió el frenesí (-1 si no se prendió) y deja el reloj en `clock[0]`.
func _play(meter: FrenzyMeter, start: float, seconds: float, rate: float, clock: Array[float]) -> float:
	var now: float = start
	var next_hit: float = start
	var turned_on: float = -1.0
	var was_active: bool = meter.active
	while now < start + seconds:
		if rate > 0.0 and now >= next_hit:
			meter.hit(now)
			next_hit += 1.0 / rate
		meter.update(now)
		if meter.active and not was_active and turned_on < 0.0:
			turned_on = now
		was_active = meter.active
		now += STEP
	clock[0] = now
	return turned_on


func _test_enters_after_sustained_rhythm() -> void:
	_section("Golpear rápido un rato prende el frenesí")
	var meter: FrenzyMeter = _meter()
	var clock: Array[float] = [0.0]
	_check(not meter.active, "arranca apagado")
	var on_at: float = _play(meter, 0.0, 4.0, 6.0, clock)
	_check(meter.active, "6 golpes por segundo durante 4 s lo prenden")
	# El ritmo cuenta como alto cuando ya hay 4 golpes en el último segundo (~0,5 s a 6/s); de ahí, 2 s más.
	_check(on_at >= 2.0 and on_at <= 3.0, "recién después de sostener el ritmo alto 2 s (se prendió a los %.2f s)" % on_at)
	_check(meter.rate(clock[0]) >= 4.0, "el ritmo medido es alto (%.1f golpes/s)" % meter.rate(clock[0]))


func _test_slow_rhythm_never_enters() -> void:
	_section("Golpear tranquilo no lo prende")
	var meter: FrenzyMeter = _meter()
	var clock: Array[float] = [0.0]
	_play(meter, 0.0, 10.0, 3.0, clock)
	_check(not meter.active, "3 golpes por segundo durante 10 s no lo prenden")


func _test_short_burst_does_not_enter() -> void:
	_section("Una ráfaga corta no lo prende")
	var meter: FrenzyMeter = _meter()
	var clock: Array[float] = [0.0]
	_play(meter, 0.0, 1.5, 8.0, clock)
	_play(meter, clock[0], 1.0, 0.0, clock)
	_play(meter, clock[0], 1.5, 8.0, clock)
	_check(not meter.active, "dos ráfagas de 1,5 s con una pausa en el medio no lo prenden (el ritmo alto tiene que ser seguido)")


func _test_exits_after_quiet() -> void:
	_section("Sin ritmo alto un rato, se apaga")
	var meter: FrenzyMeter = _meter()
	var clock: Array[float] = [0.0]
	_play(meter, 0.0, 4.0, 6.0, clock)
	_check(meter.active, "prendido")
	var stop_at: float = clock[0]
	var off_at: float = -1.0
	var now: float = stop_at
	while now < stop_at + 6.0:
		meter.update(now)
		if not meter.active and off_at < 0.0:
			off_at = now
		now += STEP
	_check(not meter.active, "al dejar de golpear se apaga")
	# El ritmo deja de ser alto cuando el último segundo tiene menos de 4 golpes (~0,5 s); de ahí, 3 s más.
	var after: float = off_at - stop_at
	_check(after >= 3.0 and after <= 4.0, "a los 3 s sin ritmo alto (se apagó %.2f s después del último golpe)" % after)
	_check_near(meter.rate(now), 0.0, "y el ritmo medido vuelve a 0")


func _test_brief_pause_keeps_frenzy() -> void:
	_section("Una pausa corta no lo apaga")
	var meter: FrenzyMeter = _meter()
	var clock: Array[float] = [0.0]
	_play(meter, 0.0, 4.0, 6.0, clock)
	_play(meter, clock[0], 2.0, 0.0, clock)
	_check(meter.active, "2 s sin golpear: sigue prendido")
	_play(meter, clock[0], 2.0, 6.0, clock)
	_play(meter, clock[0], 2.0, 2.0, clock)
	_check(meter.active, "volver a golpear rápido reinicia la cuenta; 2 s de ritmo bajo no lo apagan")
	_play(meter, clock[0], 2.0, 2.0, clock)
	_check(not meter.active, "pero 4 s de ritmo bajo sí")
	meter.reset()
	_check(not meter.active and meter.rate(clock[0]) == 0.0, "reset() lo apaga y olvida los golpes")


## hold() (comprar en la tienda) mantiene un frenesí prendido sin golpear: la cuenta para apagarse vuelve a empezar.
func _test_hold_keeps_frenzy() -> void:
	_section("Comprar mantiene el frenesí")
	var meter: FrenzyMeter = _meter()
	var clock: Array[float] = [0.0]
	meter.hold(0.0)
	_play(meter, 0.0, 1.0, 0.0, clock)
	_check(not meter.active, "hold() con el frenesí apagado no lo prende")
	_play(meter, clock[0], 4.0, 6.0, clock)
	_check(meter.active, "prendido")
	for second: int in range(8):
		meter.hold(clock[0])
		_play(meter, clock[0], 1.0, 0.0, clock)
	_check(meter.active, "8 s sin golpear pero comprando cada segundo: sigue prendido")
	# La última compra fue al principio del último segundo.
	_play(meter, clock[0], 1.5, 0.0, clock)
	_check(meter.active, "2,5 s después de la última compra, todavía")
	_play(meter, clock[0], 1.0, 0.0, clock)
	_check(not meter.active, "3 s después de la última compra (sin golpear), se apaga")


func _test_disabled_without_settings() -> void:
	_section("Sin umbrales no hay frenesí")
	var meter: FrenzyMeter = FrenzyMeter.new()
	meter.configure({})
	var clock: Array[float] = [0.0]
	_play(meter, 0.0, 5.0, 10.0, clock)
	_check(not meter.active, "un medidor sin configurar nunca se prende")
	_check(not meter.enabled(), "y dice que está apagado")


func _test_balance_section() -> void:
	_section("La sección \"frenzy\" del balance")
	var economy: EconomyScript = EconomyScript.new()
	_nodes.append(economy)
	var balance: Dictionary = TestBalance.make()
	balance["frenzy"] = SETTINGS.duplicate()
	_check(economy.load_balance(balance), "un balance con frenesí carga (%s)" % economy.last_error)
	_check_eq(economy.frenzy_settings(), SETTINGS, "y frenzy_settings() devuelve sus umbrales")
	_check(economy.load_balance(TestBalance.make()), "sin la sección también carga")
	_check(economy.frenzy_settings().is_empty(), "y entonces no hay frenesí ({})")
	for key: String in SETTINGS:
		for bad: Variant in [0, -1, "rápido"]:
			var broken: Dictionary = TestBalance.make()
			broken["frenzy"] = SETTINGS.duplicate()
			broken["frenzy"][key] = bad
			_check(not economy.load_balance(broken), "rechaza frenzy.%s = %s" % [key, str(bad)])
	var missing: Dictionary = TestBalance.make()
	missing["frenzy"] = { "hits_per_second": 4 }
	_check(not economy.load_balance(missing), "rechaza una sección incompleta (%s)" % economy.last_error)


func _test_real_balance() -> void:
	_section("El balance real")
	var balance: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	_check(balance is Dictionary and (balance as Dictionary).has("frenzy"), "data/balance.json tiene la sección \"frenzy\"")
	var economy: EconomyScript = EconomyScript.new()
	_nodes.append(economy)
	_check(economy.load_balance(balance), "y carga (%s)" % economy.last_error)
	var settings: Dictionary = economy.frenzy_settings()
	_check(float(settings.get("hits_per_second", 0)) >= 3.0 and float(settings.get("hits_per_second", 0)) <= 6.0, "unos 4 golpes por segundo (%s)" % str(settings.get("hits_per_second")))
	_check(float(settings.get("enter_seconds", 0)) > 0.0 and float(settings.get("exit_seconds", 0)) > 0.0, "con tiempos para entrar y salir")
