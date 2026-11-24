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
const X10_COUNT: int = 10
## Topes para datos de partida dañados o editados a mano (evitan desbordes a infinito).
const MAX_LOADED_OWNED: float = 1000000.0
const MAX_LOADED_PICK_LEVEL: float = 300.0

var gold: float = 0.0
## Unidades compradas de cada generador (mismo orden que en el balance).
var owned: Array[int] = []
var pick_level: int = 0
## Multiplicador global de oro (biomas, reliquias). Lo escriben los sistemas que lo dan.
var multiplier: float = 1.0

## Motivo por el que se rechazó el último balance ("" si cargó bien).
var last_error: String = ""

var _generators: Array[Dictionary] = []
var _cost_growth: float = 0.0
var _pick: Dictionary = {}


func _ready() -> void:
	if not load_balance_file(DEFAULT_BALANCE_PATH):
		push_error("Economy: no se pudo cargar %s (%s)" % [DEFAULT_BALANCE_PATH, last_error])


func _process(delta: float) -> void:
	tick(delta)


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

	last_error = ""
	_cost_growth = growth
	_generators = parsed_generators
	_pick = parsed_pick
	reset()
	return true


func generator_count() -> int:
	return _generators.size()


func generator_name(index: int) -> String:
	if not _is_valid_index(index):
		return ""
	return _generators[index]["name"]


# --- Estado ------------------------------------------------------------------

## Vuelve al estado inicial (oro 0, sin unidades, pico nivel 0), conservando el balance.
func reset() -> void:
	gold = 0.0
	pick_level = 0
	multiplier = 1.0
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
	var total: float = 0.0
	for index: int in range(_generators.size()):
		total += generator_output(index)
	return total


## Producción pasiva: suma oro/s * delta. Se ignora un delta no positivo.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var rate: float = gold_per_second()
	if rate <= 0.0:
		return
	gold += rate * delta
	gold_changed.emit(gold)


# --- Golpe y pico ------------------------------------------------------------

func hit_value() -> float:
	return EconomyMath.hit_value(pick_level, _pick["power_base"], multiplier, gold_per_second(), _pick["passive_share"])


## Un golpe a la roca. Devuelve el oro ganado.
func hit() -> float:
	var amount: float = hit_value()
	gold += amount
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
	}


## Restaura el estado desde un diccionario (p. ej. un JSON). Tolera claves faltantes,
## tipos incorrectos, negativos, NaN/infinitos y cantidades de generadores distintas a
## las del balance actual: lo inválido se reemplaza por 0.
func from_dict(data: Dictionary) -> void:
	gold = maxf(_number(data.get("gold"), 0.0), 0.0)
	pick_level = int(clampf(_number(data.get("pick_level"), 0.0), 0.0, MAX_LOADED_PICK_LEVEL))
	owned.fill(0)
	var saved_owned: Variant = data.get("owned")
	if saved_owned is Array:
		for index: int in range(mini((saved_owned as Array).size(), owned.size())):
			owned[index] = int(clampf(_number(saved_owned[index], 0.0), 0.0, MAX_LOADED_OWNED))
	gold_changed.emit(gold)


# --- Internos ----------------------------------------------------------------

## Registra el motivo del rechazo en last_error y devuelve false (para `return _fail(...)`).
func _fail(message: String) -> bool:
	last_error = message
	return false


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _generators.size()


## Convierte a float solo números finitos; cualquier otra cosa devuelve `fallback`.
static func _number(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		var number: float = float(value)
		if is_finite(number):
			return number
	return fallback
