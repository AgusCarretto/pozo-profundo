extends Node
## Autoload Economy: estado y reglas de la economía incremental (oro, generadores, pico).
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## Los números de balance se leen de res://data/ (load_balance_file), nunca se escriben acá.
## Las fórmulas viven en economy_math.gd; el formato de números en number_format.gd.

## El oro cambió (golpe, compra, producción pasiva, carga de partida).
signal gold_changed(gold: float)
## Un golpe a la roca sumó `amount` de oro.
signal hit_landed(amount: float)
signal generator_bought(index: int, count: int)
signal pick_upgraded(level: int)
## Cayó un cofre de la rareza `rarity` (índice de loot_table()) y sumó `bonus` (0.04 = +4%)
## al bonus BRUTO de botín de la partida (el efectivo sube menos: rendimientos decrecientes).
signal loot_dropped(rarity: int, bonus: float)
## Volviste a la superficie y ganaste `relics_gained` reliquias.
signal prestiged(relics_gained: int)
## Se acreditó progreso offline y hay un aviso para el jugador: `report` = {seconds, gold, capped}
## (segundos acreditados, oro ganado y si se cortó por el tope). Es el mismo dato que
## queda en `pending_offline_report` hasta que la UI llame a dismiss_offline_report().
signal offline_progress(report: Dictionary)

enum BuyMode { X1, X10, MAX }

const EconomyMath := preload("res://core/economy_math.gd")

const DEFAULT_BALANCE_PATH: String = "res://data/balance.json"
const SAVE_SECTION: String = "economy"
const SECONDS_PER_HOUR: float = 3600.0
const X10_COUNT: int = 10
## Topes para datos de partida dañados o editados a mano (evitan desbordes a infinito).
const MAX_LOADED_OWNED: float = 1000000.0
const MAX_LOADED_PICK_LEVEL: float = 300.0
const MAX_LOADED_RELICS: float = 1000000.0
const MAX_LOADED_LOOT_BONUS: float = 1000000.0

var gold: float = 0.0
## Unidades compradas de cada generador (mismo orden que en el balance).
var owned: Array[int] = []
var pick_level: int = 0
## Oro ganado en la partida actual (producción, golpes y botín). No baja al gastar:
## de él sale la profundidad, y por eso un gasto nunca te hace retroceder de bioma.
var run_gold: float = 0.0
## Bonus de botín BRUTO acumulado en la partida (0.27 = +27%): cada cofre suma el suyo. Se
## reinicia al volver a la superficie. Lo que de verdad multiplica el oro es el efectivo
## (loot_bonus_effective()), que rinde cada vez menos y tiene techo; el jugador ve ese.
var loot_bonus: float = 0.0
## Reliquias acumuladas: sobreviven al prestigio y dan oro permanente.
var relics: int = 0
## Aviso del progreso offline que el jugador todavía no vio ({} = ninguno). No se guarda.
var pending_offline_report: Dictionary = {}
## Azar del botín. Los tests le fijan la semilla para repetir una tirada.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Multiplicador global de oro: bioma x (1 + botín efectivo) x (1 + 0.25 x reliquias).
## Se calcula en cada lectura; no se asigna.
var multiplier: float:
	get:
		return biome_multiplier() * loot_multiplier() * relic_multiplier()

## Motivo por el que se rechazó el último balance ("" si cargó bien).
var last_error: String = ""

## Instante (µs) del último tick de _process; 0 = todavía sin referencia.
var _last_tick_usec: int = 0
## Hora de pared (unix) de ese tick; 0 = sin referencia.
var _last_tick_unix: float = 0.0
## Bioma más profundo de las bajadas anteriores (ver max_biome()).
var _max_biome: int = 0
var _generators: Array[Dictionary] = []
var _cost_growth: float = 0.0
var _pick: Dictionary = {}
## Secciones opcionales del balance: vacías = ese sistema está apagado (profundidad 0 m, bioma único x1).
var _depth: Dictionary = {}
var _biomes: Array[Dictionary] = []
var _biome_meters_each: float = 0.0
var _biome_growth: float = 1.0
var _loot_hit_chance: float = 0.0
var _loot_second_chance: float = 0.0
## Techo del bonus de botín efectivo (3 = +300%). 0 = sin botín.
var _loot_bonus_cap: float = 0.0
## Rarezas de los cofres: {id, name, weight, bonus}. Vacía = no hay botín.
var _rarities: Array[Dictionary] = []
var _rarity_weights: Array[float] = []
## Reglas del prestigio (min_depth, depth_offset, depth_step, exponent, bonus_per_relic). Vacío = sin prestigio.
var _prestige: Dictionary = {}
## Reglas del progreso offline (max_hours, away_seconds, efficiency). Vacío = sin progreso offline.
var _offline: Dictionary = {}
## Umbrales del frenesí (hits_per_second, enter_seconds, exit_seconds, window_seconds). Vacío = sin frenesí.
var _frenzy: Dictionary = {}


func _init() -> void:
	rng.randomize()


func _ready() -> void:
	if not load_balance_file(DEFAULT_BALANCE_PATH):
		# Sin balance no se registra en Save: si no, el autosave pisaría la partida con un estado vacío.
		push_error("Economy: no se pudo cargar %s (%s)" % [DEFAULT_BALANCE_PATH, last_error])
		return
	var save: Node = get_node_or_null("/root/Save")
	if save != null and save.has_method("register_section"):
		save.register_section(SAVE_SECTION, to_dict, from_dict)
		# Save ya leyó el archivo (es el primer autoload): si había partida, la cuadrilla
		# siguió trabajando desde la hora de ese save.
		apply_offline_since(int(save.loaded_saved_at), Time.get_unix_time_from_system())


func _process(_delta: float) -> void:
	# No se usa `delta`: Godot lo recorta a ~0.13 s por frame, y a pocos fps (celulares
	# lentos, pestañas web en segundo plano) la cuadrilla produciría una fracción de lo debido.
	tick_realtime(Time.get_ticks_usec(), Time.get_unix_time_from_system())


# --- Balance -----------------------------------------------------------------

func load_balance_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return _fail("no existe %s" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _fail("%s no es un JSON válido" % path)
	return load_balance(parsed)


## Valida y carga un balance, y reinicia el estado. Si es inválido devuelve false y no
## toca nada (ni el balance anterior ni el estado).
func load_balance(balance: Dictionary) -> bool:
	var growth: float = _number(balance.get("cost_growth"), 0.0)
	if growth <= 1.0:
		return _fail("cost_growth tiene que ser > 1")

	var raw_generators: Variant = balance.get("generators")
	if not (raw_generators is Array) or (raw_generators as Array).is_empty():
		return _fail("el balance necesita al menos un generador")
	var parsed_generators: Array[Dictionary] = []
	for entry: Variant in raw_generators:
		if not (entry is Dictionary):
			return _fail("un generador no es un objeto")
		var rate: float = _number(entry.get("base_rate"), 0.0)
		var cost: float = _number(entry.get("base_cost"), 0.0)
		if rate <= 0.0 or cost <= 0.0:
			return _fail("base_rate y base_cost de '%s' tienen que ser > 0" % str(entry.get("id")))
		parsed_generators.append({
			"id": str(entry.get("id", "")),
			"name": str(entry.get("name", "")),
			"base_rate": rate,
			"base_cost": cost,
		})

	var raw_pick: Variant = balance.get("pick")
	if not (raw_pick is Dictionary):
		return _fail("falta la sección 'pick'")
	var parsed_pick: Dictionary = {}
	for key: String in ["power_base", "cost_base", "cost_growth", "passive_share"]:
		var value: float = _number((raw_pick as Dictionary).get(key), -1.0)
		if value < 0.0 or (value == 0.0 and key != "passive_share"):
			return _fail("pick.%s es inválido" % key)
		parsed_pick[key] = value

	var parsed_depth: Variant = _read_numbers(balance, "depth", ["meters_scale", "gold_scale"])
	if parsed_depth == null:
		return false
	var parsed_biomes: Variant = _read_biomes(balance)
	if parsed_biomes == null:
		return false
	var parsed_loot: Variant = _read_loot(balance)
	if parsed_loot == null:
		return false
	var parsed_prestige: Variant = _read_numbers(balance, "prestige", ["min_depth", "depth_step", "exponent", "bonus_per_relic"], ["depth_offset"])
	if parsed_prestige == null:
		return false
	var parsed_offline: Variant = _read_numbers(balance, "offline", ["max_hours", "away_seconds"], ["efficiency"])
	if parsed_offline == null:
		return false
	if not (parsed_offline as Dictionary).is_empty() and parsed_offline["efficiency"] > 1.0:
		return _fail("offline.efficiency es una fracción: tiene que estar entre 0 y 1")
	var parsed_frenzy: Variant = _read_numbers(balance, "frenzy", ["hits_per_second", "enter_seconds", "exit_seconds", "window_seconds"])
	if parsed_frenzy == null:
		return false

	last_error = ""
	_cost_growth = growth
	_generators = parsed_generators
	_pick = parsed_pick
	_depth = parsed_depth
	_prestige = parsed_prestige
	_offline = parsed_offline
	_frenzy = parsed_frenzy
	_biomes = []
	_biome_meters_each = 0.0
	_biome_growth = 1.0
	if not (parsed_biomes as Dictionary).is_empty():
		_biomes.assign(parsed_biomes["list"])
		_biome_meters_each = parsed_biomes["meters_each"]
		_biome_growth = parsed_biomes["mult_growth"]
	_rarities = []
	_rarity_weights = []
	_loot_hit_chance = 0.0
	_loot_second_chance = 0.0
	_loot_bonus_cap = 0.0
	if not (parsed_loot as Dictionary).is_empty():
		_rarities.assign(parsed_loot["rarities"])
		for rarity: Dictionary in _rarities:
			_rarity_weights.append(rarity["weight"])
		_loot_hit_chance = parsed_loot["chance_per_hit"]
		_loot_second_chance = parsed_loot["chance_per_second"]
		_loot_bonus_cap = parsed_loot["bonus_cap"]
	reset()
	return true


func generator_count() -> int:
	return _generators.size()


func generator_name(index: int) -> String:
	if not _is_valid_index(index):
		return ""
	return _generators[index]["name"]


## Id del generador en el balance ("miner", "steam_drill"...), para que la UI elija su arte.
func generator_id(index: int) -> String:
	if not _is_valid_index(index):
		return ""
	return _generators[index]["id"]


# --- Profundidad y biomas ------------------------------------------------------

## Profundidad en metros, según el oro ganado en la partida. 0 si el balance no tiene "depth".
func depth() -> float:
	if _depth.is_empty():
		return 0.0
	return EconomyMath.depth(run_gold, _depth["meters_scale"], _depth["gold_scale"])


func biome_count() -> int:
	return _biomes.size()


## Índice del bioma en el que estás ahora (0 = el de la superficie).
func biome_index() -> int:
	return EconomyMath.biome_index(depth(), _biome_meters_each, _biomes.size())


func biome_name(index: int) -> String:
	if index < 0 or index >= _biomes.size():
		return ""
	return _biomes[index]["name"]


## Id del bioma `index` en el balance ("earth", "rock"...), para que la UI elija su arte.
## "" si el índice no existe.
func biome_id(index: int) -> String:
	if index < 0 or index >= _biomes.size():
		return ""
	return _biomes[index]["id"]


## Cuánto del tramo del bioma actual ya recorriste (0 a 1). En el último bioma, 1.
func biome_progress() -> float:
	return EconomyMath.biome_progress(depth(), _biome_meters_each, _biomes.size())


## Índice del bioma siguiente, o -1 si ya estás en el último (o no hay biomas).
func next_biome_index() -> int:
	var next: int = biome_index() + 1
	return next if next < _biomes.size() else -1


## Profundidad (m) a la que empieza el bioma siguiente; 0 si ya estás en el último.
func next_biome_depth() -> float:
	var next: int = next_biome_index()
	return next * _biome_meters_each if next >= 0 else 0.0


## Índice del bioma más profundo al que llegaste alguna vez (0 = el de la superficie). Sobrevive al prestigio.
func max_biome() -> int:
	return maxi(_max_biome, biome_index())


## Multiplicador de oro del bioma actual (x1 si el balance no tiene biomas).
func biome_multiplier() -> float:
	if _biomes.is_empty():
		return 1.0
	return EconomyMath.biome_multiplier(biome_index(), _biome_growth)


# --- Botín -------------------------------------------------------------------

## Probabilidad (0 a 1) de que un golpe suelte un cofre.
func loot_chance_per_hit() -> float:
	return _loot_hit_chance


## Probabilidad (0 a 1) por segundo de que la cuadrilla encuentre un cofre (solo si produce).
func loot_chance_per_second() -> float:
	return _loot_second_chance


## Las rarezas con su probabilidad real (peso / suma de pesos) y su bonus, para mostrarlas
## al jugador: [{id, name, chance, bonus}] en el orden del balance.
func loot_table() -> Array[Dictionary]:
	var total: float = 0.0
	for weight: float in _rarity_weights:
		total += weight
	var table: Array[Dictionary] = []
	for index: int in range(_rarities.size()):
		var rarity: Dictionary = _rarities[index]
		table.append({
			"id": rarity["id"],
			"name": rarity["name"],
			"chance": _rarity_weights[index] / total,
			"bonus": rarity["bonus"],
		})
	return table


## Techo del bonus de botín efectivo (3 = +300%). 0 si el balance no tiene botín.
func loot_bonus_cap() -> float:
	return _loot_bonus_cap


## Bonus de botín EFECTIVO (0.27 = +27%): el bruto acumulado con rendimientos decrecientes,
## cap * (1 - e^(-bruto / cap)). Es el que multiplica el oro y el que se le muestra al jugador.
func loot_bonus_effective() -> float:
	return EconomyMath.loot_bonus_effective(loot_bonus, _loot_bonus_cap)


## Multiplicador de oro del botín acumulado en la partida: 1 + bonus efectivo.
func loot_multiplier() -> float:
	return 1.0 + loot_bonus_effective()


## Suelta un cofre de la rareza `rarity` (índice de loot_table()): su bonus se suma al bonus
## bruto de botín de la partida (el efectivo sube menos: ver loot_bonus_effective()). No da oro. Un índice inexistente no hace nada. Lo usan el sorteo y las
## herramientas de debug.
func drop_loot(rarity: int) -> void:
	if rarity < 0 or rarity >= _rarities.size():
		return
	var bonus: float = _rarities[rarity]["bonus"]
	loot_bonus = minf(loot_bonus + bonus, MAX_LOADED_LOOT_BONUS)
	loot_dropped.emit(rarity, bonus)


# --- Reliquias y prestigio ---------------------------------------------------

## Multiplicador de oro de las reliquias que tenés (x1 si el balance no tiene prestigio).
func relic_multiplier() -> float:
	return relic_multiplier_for(relics)


## Multiplicador que darían `count` reliquias (para mostrar cómo quedaría tras una subida).
func relic_multiplier_for(count: int) -> float:
	if _prestige.is_empty():
		return 1.0
	return EconomyMath.relic_multiplier(count, _prestige["bonus_per_relic"])


## Bonus de oro de cada reliquia (0.25 = +25%).
func relic_bonus() -> float:
	return _prestige.get("bonus_per_relic", 0.0)


## Profundidad mínima (m) para volver a la superficie con reliquias.
func prestige_min_depth() -> float:
	return _prestige.get("min_depth", 0.0)


## Reliquias que daría volver a la superficie ahora: 0 si todavía no llegaste a la profundidad mínima.
func prestige_relics() -> int:
	if _prestige.is_empty():
		return 0
	return EconomyMath.relics_for_depth(depth(), _prestige["min_depth"], _prestige["depth_offset"], _prestige["depth_step"], _prestige["exponent"])


func can_prestige() -> bool:
	return prestige_relics() > 0


## Vuelve a la superficie: suma las reliquias de esta bajada y reinicia la partida (oro,
## profundidad, bonus de botín, cuadrilla y pico). Devuelve las reliquias ganadas; si todavía no se puede,
## devuelve 0 y no toca nada. Ejecuta ya mismo: la confirmación al jugador la pide la UI antes.
func prestige() -> int:
	var gained: int = prestige_relics()
	if gained <= 0:
		return 0
	relics = mini(relics + gained, int(MAX_LOADED_RELICS))
	_max_biome = max_biome()
	_reset_run()
	prestiged.emit(gained)
	return gained


# --- Botín (tirada) -----------------------------------------------------------

## Tira por un cofre con probabilidad `chance`. Si sale, sortea la rareza y lo suelta.
func _roll_loot(chance: float) -> void:
	if _rarities.is_empty() or chance <= 0.0 or rng.randf() >= chance:
		return
	drop_loot(EconomyMath.pick_weighted(_rarity_weights, rng.randf()))


# --- Estado ------------------------------------------------------------------

## Empieza una partida de cero (también sin reliquias), conservando el balance.
func reset() -> void:
	relics = 0
	_max_biome = 0
	pending_offline_report = {}
	_reset_run()


## Reinicia solo la partida en curso: oro, oro ganado (profundidad), bonus de botín,
## cuadrilla y pico. Las reliquias no se tocan.
func _reset_run() -> void:
	gold = 0.0
	run_gold = 0.0
	loot_bonus = 0.0
	pick_level = 0
	owned.resize(_generators.size())
	owned.fill(0)
	gold_changed.emit(gold)


func owned_count(index: int) -> int:
	if not _is_valid_index(index):
		return 0
	return owned[index]


## Oro por segundo que aporta el generador `index` (unidades * oro/s base * multiplicador).
func generator_output(index: int) -> float:
	if not _is_valid_index(index):
		return 0.0
	return owned[index] * float(_generators[index]["base_rate"]) * multiplier


func gold_per_second() -> float:
	var base_total: float = 0.0
	for index: int in range(_generators.size()):
		base_total += owned[index] * float(_generators[index]["base_rate"])
	return base_total * multiplier


## Producción pasiva según un reloj monotónico (µs, p. ej. Time.get_ticks_usec()) y, de respaldo, la hora de
## pared (unix; 0 = no usarla): en iPhone el monotónico puede quedar frenado mientras el teléfono duerme, así que
## vale el que más avanzó. La primera llamada solo fija la referencia; un reloj que retrocede no suma ni resta.
## Un hueco (pestaña oculta o app en segundo plano) de menos de `away_seconds` es juego activo; de ahí en más es
## una ausencia: se acredita como progreso offline, con tope y aviso.
func tick_realtime(now_usec: int, now_unix: float = 0.0) -> void:
	if _last_tick_usec > 0 and now_usec > _last_tick_usec:
		var gap: float = (now_usec - _last_tick_usec) / 1000000.0
		if now_unix > 0.0 and _last_tick_unix > 0.0:
			gap = maxf(gap, now_unix - _last_tick_unix)
		if not _offline.is_empty() and gap >= _offline["away_seconds"]:
			apply_offline(gap)
		else:
			tick(gap)
	_last_tick_usec = now_usec
	_last_tick_unix = now_unix


## Oro que entra de afuera (un anuncio con recompensa, herramientas de debug): suma al oro y
## cuenta como ganado en la partida (la profundidad sube). Se ignora lo no positivo o inválido.
func grant_gold(amount: float) -> void:
	if not (amount > 0.0):
		return
	_earn(amount)
	gold_changed.emit(gold)


## Producción pasiva: suma oro/s * delta. Se ignora un delta no positivo.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var rate: float = gold_per_second()
	if rate <= 0.0:
		return
	_earn(rate * delta)
	# La chance por segundo es p: en un tick de `delta` segundos la chance es 1 - (1 - p)^delta,
	# así un frame lento no tira menos cofres que varios rápidos.
	_roll_loot(1.0 - pow(1.0 - _loot_second_chance, delta))
	gold_changed.emit(gold)


# --- Frenesí -----------------------------------------------------------------

## Los umbrales del frenesí del balance (para core/frenzy_meter.gd); {} si el balance no tiene "frenzy".
func frenzy_settings() -> Dictionary:
	return _frenzy.duplicate()


# --- Progreso offline ------------------------------------------------------------

## Tope de segundos de ausencia que se acreditan (0 si el balance no tiene "offline").
func offline_max_seconds() -> float:
	if _offline.is_empty():
		return 0.0
	return float(_offline["max_hours"]) * SECONDS_PER_HOUR


## Cuánto rinde la cuadrilla mientras no estás (0.25 = 25%). 0 si el balance no tiene "offline".
func offline_efficiency() -> float:
	return _offline.get("efficiency", 0.0)


## Acredita lo que produjo la cuadrilla durante `elapsed` segundos de ausencia, hasta el tope: los primeros
## `away_seconds` completos y el resto a `efficiency`.
## Usa la producción de hoy (bioma y reliquias actuales), no la que iría subiendo por el camino:
## es una cuenta conservadora. No sortea cofres. Devuelve el reporte {seconds, gold, capped},
## o {} si no acreditó nada (ausencia nula o inválida, sin cuadrilla, o sin sección offline).
## Si la ausencia llega a `away_seconds`, deja el aviso en pending_offline_report y emite
## offline_progress; una ausencia más corta se acredita igual, pero sin cartel.
func apply_offline(elapsed: float) -> Dictionary:
	if _offline.is_empty():
		return {}
	var seconds: float = EconomyMath.offline_seconds(elapsed, offline_max_seconds())
	var gained: float = gold_per_second() * EconomyMath.offline_paid_seconds(seconds, _offline["away_seconds"], _offline["efficiency"])
	if seconds <= 0.0 or gained <= 0.0:
		return {}
	_earn(gained)
	var report: Dictionary = { "seconds": seconds, "gold": gained, "capped": elapsed > offline_max_seconds() }
	gold_changed.emit(gold)
	if elapsed >= _offline["away_seconds"]:
		_queue_offline_notice(report)
	return report


## Offline desde la hora (unix) en que se guardó la partida. saved_at <= 0 = no había save.
func apply_offline_since(saved_at: int, now: float) -> Dictionary:
	if saved_at <= 0:
		return {}
	return apply_offline(now - saved_at)


## El jugador ya vio el aviso.
func dismiss_offline_report() -> void:
	pending_offline_report = {}


## Deja `report` como aviso pendiente. Si ya había uno sin cerrar, los suma: así el cartel
## nunca esconde oro que ya se acreditó.
func _queue_offline_notice(report: Dictionary) -> void:
	if pending_offline_report.is_empty():
		pending_offline_report = report
	else:
		pending_offline_report = {
			"seconds": float(pending_offline_report["seconds"]) + float(report["seconds"]),
			"gold": float(pending_offline_report["gold"]) + float(report["gold"]),
			"capped": bool(pending_offline_report["capped"]) or bool(report["capped"]),
		}
	offline_progress.emit(pending_offline_report)


# --- Golpe y pico ------------------------------------------------------------

func hit_value() -> float:
	return EconomyMath.hit_value(pick_level, _pick["power_base"], multiplier, gold_per_second(), _pick["passive_share"])


## Un golpe a la roca. Devuelve el oro ganado.
func hit() -> float:
	var amount: float = hit_value()
	_earn(amount)
	hit_landed.emit(amount)
	_roll_loot(_loot_hit_chance)
	gold_changed.emit(gold)
	return amount


func pick_cost() -> float:
	return EconomyMath.pick_cost(pick_level, _pick["cost_base"], _pick["cost_growth"])


func upgrade_pick() -> bool:
	var cost: float = pick_cost()
	if cost > gold:
		return false
	gold -= cost
	pick_level += 1
	pick_upgraded.emit(pick_level)
	gold_changed.emit(gold)
	return true


# --- Compra de generadores ---------------------------------------------------

## Qué compraría `buy_generator` ahora: {count: int, cost: float, affordable: bool}.
## En modo MAX sin oro suficiente para ninguno, muestra el costo de 1 (affordable = false).
func quote(index: int, mode: int) -> Dictionary:
	if not _is_valid_index(index):
		return { "count": 0, "cost": 0.0, "affordable": false }
	var base_cost: float = _generators[index]["base_cost"]
	var count: int = 1
	if mode == BuyMode.X10:
		count = X10_COUNT
	elif mode == BuyMode.MAX:
		count = maxi(EconomyMath.max_affordable(base_cost, _cost_growth, owned[index], gold), 1)
	var cost: float = EconomyMath.bulk_cost(base_cost, _cost_growth, owned[index], count)
	return { "count": count, "cost": cost, "affordable": cost <= gold }


## Compra según el modo (todo o nada). Devuelve cuántas unidades compró (0 si no alcanzó).
func buy_generator(index: int, mode: int) -> int:
	var offer: Dictionary = quote(index, mode)
	if not offer["affordable"]:
		return 0
	var count: int = offer["count"]
	gold -= offer["cost"]
	owned[index] += count
	generator_bought.emit(index, count)
	gold_changed.emit(gold)
	return count


# --- Guardado ----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"owned": owned.duplicate(),
		"pick_level": pick_level,
		"run_gold": run_gold,
		"loot_bonus": loot_bonus,
		"relics": relics,
		"max_biome": max_biome(),
	}


## Restaura el estado desde un diccionario (p. ej. un JSON). Tolera claves faltantes,
## tipos incorrectos, negativos, NaN/infinitos y cantidades de generadores distintas a
## las del balance actual: lo inválido se reemplaza por 0.
func from_dict(data: Dictionary) -> void:
	gold = maxf(_number(data.get("gold"), 0.0), 0.0)
	# Lo ganado nunca puede ser menos que lo que tenés: cubre saves anteriores a la
	# profundidad (sin run_gold) y datos editados a mano.
	run_gold = maxf(_number(data.get("run_gold"), 0.0), gold)
	loot_bonus = clampf(_number(data.get("loot_bonus"), 0.0), 0.0, MAX_LOADED_LOOT_BONUS)
	relics = int(clampf(_number(data.get("relics"), 0.0), 0.0, MAX_LOADED_RELICS))
	pick_level = int(clampf(_number(data.get("pick_level"), 0.0), 0.0, MAX_LOADED_PICK_LEVEL))
	owned.fill(0)
	var saved_owned: Variant = data.get("owned")
	if saved_owned is Array:
		for index: int in range(mini((saved_owned as Array).size(), owned.size())):
			owned[index] = int(clampf(_number(saved_owned[index], 0.0), 0.0, MAX_LOADED_OWNED))
	var deepest: int = maxi(biome_count() - 1, 0)
	_max_biome = int(clampf(_number(data.get("max_biome"), 0.0), 0.0, deepest))
	# Quien tiene reliquias llegó al menos hasta donde se puede volver a la superficie (partidas sin el dato).
	if relics > 0:
		_max_biome = maxi(_max_biome, EconomyMath.biome_index(prestige_min_depth(), _biome_meters_each, biome_count()))
	gold_changed.emit(gold)


# --- Internos ----------------------------------------------------------------

## Suma oro ganado: va al oro y a lo ganado en la partida (profundidad). No emite señales.
func _earn(amount: float) -> void:
	gold += amount
	run_gold += amount


## Registra el motivo del rechazo en last_error y devuelve false (para `return _fail(...)`).
func _fail(message: String) -> bool:
	last_error = message
	return false


## Lee una sección opcional del balance cuyos valores son números: `positive_keys` tienen
## que ser > 0 y `non_negative_keys` >= 0 (una clave faltante es inválida).
## Devuelve {} si la sección no está (ese sistema queda apagado), null si es inválida
## (el motivo queda en last_error) o un Dictionary clave -> float.
func _read_numbers(balance: Dictionary, section: String, positive_keys: Array[String], non_negative_keys: Array[String] = []) -> Variant:
	if not balance.has(section):
		return {}
	var raw: Variant = balance[section]
	if not (raw is Dictionary):
		_fail("'%s' no es un objeto" % section)
		return null
	var numbers: Dictionary = {}
	for key: String in positive_keys:
		var value: float = _number((raw as Dictionary).get(key), 0.0)
		if value <= 0.0:
			_fail("%s.%s tiene que ser > 0" % [section, key])
			return null
		numbers[key] = value
	for key: String in non_negative_keys:
		var value: float = _number((raw as Dictionary).get(key), -1.0)
		if value < 0.0:
			_fail("%s.%s tiene que ser >= 0" % [section, key])
			return null
		numbers[key] = value
	return numbers


## Lee la sección opcional "biomes": {meters_each, mult_growth, list: [{id, name}]}.
## Mismo contrato que _read_numbers: {} si no está, null si es inválida.
func _read_biomes(balance: Dictionary) -> Variant:
	var numbers: Variant = _read_numbers(balance, "biomes", ["meters_each", "mult_growth"])
	if numbers == null or (numbers as Dictionary).is_empty():
		return numbers
	var raw_list: Variant = (balance["biomes"] as Dictionary).get("list")
	if not (raw_list is Array) or (raw_list as Array).is_empty():
		_fail("biomes.list necesita al menos un bioma")
		return null
	var list: Array[Dictionary] = []
	for entry: Variant in raw_list:
		if not (entry is Dictionary) or str((entry as Dictionary).get("name", "")) == "":
			_fail("cada bioma de biomes.list necesita un nombre")
			return null
		list.append({ "id": str(entry.get("id", "")), "name": str(entry["name"]) })
	numbers["list"] = list
	return numbers


## Lee la sección opcional "loot": {chance_per_hit, chance_per_second, bonus_cap, rarities: [{id, name, weight, bonus}]}.
## Mismo contrato que _read_numbers: {} si no está, null si es inválida.
func _read_loot(balance: Dictionary) -> Variant:
	var numbers: Variant = _read_numbers(balance, "loot", ["bonus_cap"], ["chance_per_hit", "chance_per_second"])
	if numbers == null or (numbers as Dictionary).is_empty():
		return numbers
	for key: String in ["chance_per_hit", "chance_per_second"]:
		if numbers[key] > 1.0:
			_fail("loot.%s es una probabilidad: tiene que estar entre 0 y 1" % key)
			return null
	var raw_rarities: Variant = (balance["loot"] as Dictionary).get("rarities")
	if not (raw_rarities is Array) or (raw_rarities as Array).is_empty():
		_fail("loot.rarities necesita al menos una rareza")
		return null
	var rarities: Array[Dictionary] = []
	var total_weight: float = 0.0
	for entry: Variant in raw_rarities:
		if not (entry is Dictionary) or str((entry as Dictionary).get("name", "")) == "":
			_fail("cada rareza de loot.rarities necesita un nombre")
			return null
		var weight: float = _number(entry.get("weight"), -1.0)
		var bonus: float = _number(entry.get("bonus"), -1.0)
		if weight < 0.0 or bonus < 0.0:
			_fail("el peso y el bonus de la rareza '%s' tienen que ser >= 0" % str(entry["name"]))
			return null
		total_weight += weight
		rarities.append({ "id": str(entry.get("id", "")), "name": str(entry["name"]), "weight": weight, "bonus": bonus })
	if total_weight <= 0.0:
		_fail("loot.rarities necesita al menos un peso > 0")
		return null
	numbers["rarities"] = rarities
	return numbers


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _generators.size()


## Convierte a float solo números finitos; cualquier otra cosa devuelve `fallback`.
static func _number(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		var number: float = float(value)
		if is_finite(number):
			return number
	return fallback
