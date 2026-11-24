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

enum BuyMode { X1, X10, MAX }

const EconomyMath := preload("res://core/economy_math.gd")

const DEFAULT_BALANCE_PATH: String = "res://data/balance.json"
const SAVE_SECTION: String = "economy"
const X10_COUNT: int = 10
## Topes para datos de partida dañados o editados a mano (evitan desbordes a infinito).
const MAX_LOADED_OWNED: float = 1000000.0
const MAX_LOADED_PICK_LEVEL: float = 300.0

var gold: float = 0.0
## Unidades compradas de cada generador (mismo orden que en el balance).
var owned: Array[int] = []
var pick_level: int = 0
## Oro ganado en la partida actual (producción, golpes y botín). No baja al gastar:
## de él sale la profundidad, y por eso un gasto nunca te hace retroceder de bioma.
var run_gold: float = 0.0

## Multiplicador global de oro: el del bioma actual (y, más adelante, el de las reliquias).
## Se calcula en cada lectura; no se asigna.
var multiplier: float:
	get:
		return biome_multiplier()

## Motivo por el que se rechazó el último balance ("" si cargó bien).
var last_error: String = ""

## Instante (µs) del último tick de _process; 0 = todavía sin referencia.
var _last_tick_usec: int = 0
var _generators: Array[Dictionary] = []
var _cost_growth: float = 0.0
var _pick: Dictionary = {}
## Secciones opcionales del balance: vacías = ese sistema está apagado (profundidad 0 m, bioma único x1).
var _depth: Dictionary = {}
var _biomes: Array[Dictionary] = []
var _biome_meters_each: float = 0.0
var _biome_growth: float = 1.0


func _ready() -> void:
	if not load_balance_file(DEFAULT_BALANCE_PATH):
		# Sin balance no se registra en Save: si no, el autosave pisaría la partida con un estado vacío.
		push_error("Economy: no se pudo cargar %s (%s)" % [DEFAULT_BALANCE_PATH, last_error])
		return
	var save: Node = get_node_or_null("/root/Save")
	if save != null and save.has_method("register_section"):
		save.register_section(SAVE_SECTION, to_dict, from_dict)


func _process(_delta: float) -> void:
	# No se usa `delta`: Godot lo recorta a ~0.13 s por frame, y a pocos fps (celulares
	# lentos, pestañas web en segundo plano) la cuadrilla produciría una fracción de lo debido.
	tick_realtime(Time.get_ticks_usec())


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

	last_error = ""
	_cost_growth = growth
	_generators = parsed_generators
	_pick = parsed_pick
	_depth = parsed_depth
	_biomes = []
	_biome_meters_each = 0.0
	_biome_growth = 1.0
	if not (parsed_biomes as Dictionary).is_empty():
		_biomes.assign(parsed_biomes["list"])
		_biome_meters_each = parsed_biomes["meters_each"]
		_biome_growth = parsed_biomes["mult_growth"]
	reset()
	return true


func generator_count() -> int:
	return _generators.size()


func generator_name(index: int) -> String:
	if not _is_valid_index(index):
		return ""
	return _generators[index]["name"]


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


## Multiplicador de oro del bioma actual (x1 si el balance no tiene biomas).
func biome_multiplier() -> float:
	if _biomes.is_empty():
		return 1.0
	return EconomyMath.biome_multiplier(biome_index(), _biome_growth)


# --- Estado ------------------------------------------------------------------

## Vuelve al estado inicial (oro 0, sin unidades, pico nivel 0), conservando el balance.
func reset() -> void:
	gold = 0.0
	run_gold = 0.0
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


## Producción pasiva según un reloj monotónico (µs, p. ej. Time.get_ticks_usec()).
## La primera llamada solo fija la referencia; un reloj que retrocede no suma ni resta.
func tick_realtime(now_usec: int) -> void:
	if _last_tick_usec > 0 and now_usec > _last_tick_usec:
		tick((now_usec - _last_tick_usec) / 1000000.0)
	_last_tick_usec = now_usec


## Producción pasiva: suma oro/s * delta. Se ignora un delta no positivo.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var rate: float = gold_per_second()
	if rate <= 0.0:
		return
	_earn(rate * delta)
	gold_changed.emit(gold)


# --- Golpe y pico ------------------------------------------------------------

func hit_value() -> float:
	return EconomyMath.hit_value(pick_level, _pick["power_base"], multiplier, gold_per_second(), _pick["passive_share"])


## Un golpe a la roca. Devuelve el oro ganado.
func hit() -> float:
	var amount: float = hit_value()
	_earn(amount)
	hit_landed.emit(amount)
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
	}


## Restaura el estado desde un diccionario (p. ej. un JSON). Tolera claves faltantes,
## tipos incorrectos, negativos, NaN/infinitos y cantidades de generadores distintas a
## las del balance actual: lo inválido se reemplaza por 0.
func from_dict(data: Dictionary) -> void:
	gold = maxf(_number(data.get("gold"), 0.0), 0.0)
	# Lo ganado nunca puede ser menos que lo que tenés: cubre saves anteriores a la
	# profundidad (sin run_gold) y datos editados a mano.
	run_gold = maxf(_number(data.get("run_gold"), 0.0), gold)
	pick_level = int(clampf(_number(data.get("pick_level"), 0.0), 0.0, MAX_LOADED_PICK_LEVEL))
	owned.fill(0)
	var saved_owned: Variant = data.get("owned")
	if saved_owned is Array:
		for index: int in range(mini((saved_owned as Array).size(), owned.size())):
			owned[index] = int(clampf(_number(saved_owned[index], 0.0), 0.0, MAX_LOADED_OWNED))
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


## Lee una sección opcional del balance cuyos valores son números > 0.
## Devuelve {} si la sección no está (ese sistema queda apagado), null si es inválida
## (el motivo queda en last_error) o un Dictionary clave -> float.
func _read_numbers(balance: Dictionary, section: String, positive_keys: Array[String]) -> Variant:
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


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _generators.size()


## Convierte a float solo números finitos; cualquier otra cosa devuelve `fallback`.
static func _number(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		var number: float = float(value)
		if is_finite(number):
			return number
	return fallback
