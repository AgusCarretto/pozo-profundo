extends Node
## Autoload Economy: estado y reglas de la economía incremental (oro, generadores, pico).
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## Los números de balance se leen de res://data/ (load_balance_file), nunca se escriben acá.
## Las fórmulas viven en economy_math.gd; el formato de números en number_format.gd.
##
## Con la sección "tree" (árbol de reliquias, ver relic_tree.gd; en el balance se nombra con "tree_file") las
## reliquias son una moneda: `relics` son las ganadas en toda la historia (dan un bonus pasivo), lo gastado lo
## lleva el árbol y la profundidad para volver se corre. Sin esa sección todo funciona como antes del árbol.
##
## Con la sección "achievements" (logros, ver achievements.gd; en el balance "achievements_file") se llevan los
## contadores históricos de la partida y se consiguen logros, que pagan fragmentos de reliquia.

## El oro cambió (golpe, compra, producción pasiva, carga de partida).
signal gold_changed(gold: float)
## Un golpe a la roca sumó `amount` de oro. Si fue crítico, last_hit_critical ya está puesto.
signal hit_landed(amount: float)
signal generator_bought(index: int, count: int)
## Una compra llevó al generador `index` a `threshold` unidades: desde ahí produce más.
signal milestone_reached(index: int, threshold: int)
signal pick_upgraded(level: int)
## Se abrió un cofre de la rareza `rarity` (índice de loot_table()) y pagó `amount` de oro. Si la rareza da
## reliquias (loot_table()[rarity]["relics"]), ya están sumadas.
signal loot_dropped(rarity: int, amount: float)
## Volviste a la superficie y ganaste `relics_gained` reliquias.
signal prestiged(relics_gained: int)
## La habilidad subió de nivel.
signal ability_upgraded(level: int)
## Se usó la habilidad y pagó `amount` de oro.
signal ability_used(amount: float)
## Se acreditó progreso offline y hay un aviso para el jugador: `report` = {seconds, gold, capped}
## (segundos acreditados, oro ganado y si se cortó por el tope). Es el mismo dato que
## queda en `pending_offline_report` hasta que la UI llame a dismiss_offline_report().
signal offline_progress(report: Dictionary)
## Cambió el árbol de reliquias o lo que se le puede dar (una compra, una piedra angular, reliquias de afuera).
signal tree_changed
## Se consiguieron logros (todos los de esta tanda juntos). Quedan además en pending_achievements.
signal achievements_unlocked(ids: Array)

enum BuyMode { X1, X10, MAX }

const EconomyMath := preload("res://core/economy_math.gd")
const RelicTree := preload("res://core/relic_tree.gd")
const TapLimiter := preload("res://core/tap_limiter.gd")
const Achievements := preload("res://core/achievements.gd")
## Cada cuánto se miran los logros mientras se juega (s).
const ACHIEVEMENT_CHECK_SECONDS: float = 0.5
## Ventana en la que se mide el ritmo de golpes sostenido (s).
const TAP_RATE_SECONDS: float = 10.0
## Horas (locales) que cuentan como jugar de madrugada: desde la primera hasta antes de la segunda.
const NIGHT_HOURS: Vector2i = Vector2i(3, 5)
## Segundos sin golpear con los que se sigue jugando activo, si no hay árbol que lo diga.
const DEFAULT_WORKING_SECONDS: float = 5.0

const DEFAULT_BALANCE_PATH: String = "res://data/balance.json"
const SAVE_SECTION: String = "economy"
## Versión de lo que se guarda. Una partida sin este dato se jugó con las reglas de la sección "legacy".
const BALANCE_VERSION: int = 2
## Lo mismo cuando el balance tiene árbol de reliquias.
const TREE_VERSION: int = 3
## Nombre de la copia que Save guarda antes de convertir una partida de antes del árbol (web/restaurar.html la usa).
const BACKUP_BEFORE_TREE: String = "antes-0.7"
const SECONDS_PER_HOUR: float = 3600.0
const X10_COUNT: int = 10
## Topes para datos de partida dañados o editados a mano (evitan desbordes a infinito).
const MAX_LOADED_OWNED: float = 1000000.0
const MAX_LOADED_PICK_LEVEL: float = 300.0
const MAX_LOADED_RELICS: float = 1000000.0
const MAX_LOADED_COUNTER: float = 10000000.0
const MAX_LOADED_METERS: float = 100000.0

var gold: float = 0.0
## Unidades compradas de cada generador (mismo orden que en el balance).
var owned: Array[int] = []
var pick_level: int = 0
## Oro ganado en la partida actual (producción, golpes y botín). No baja al gastar:
## de él sale la profundidad, y por eso un gasto nunca te hace retroceder de bioma.
var run_gold: float = 0.0
## Habilidad activa (en este juego, la dinamita): nivel comprado en la bajada (0 = sin comprar) y segundos de
## recarga que faltan. El nivel se reinicia al volver a la superficie.
var ability_level: int = 0
var ability_cooldown_left: float = 0.0
## Reliquias acumuladas: sobreviven al prestigio y dan oro permanente.
var relics: int = 0
## Aviso del progreso offline que el jugador todavía no vio ({} = ninguno). No se guarda.
var pending_offline_report: Dictionary = {}
## El último golpe fue crítico.
var last_hit_critical: bool = false
## Aviso de que la partida se convirtió al balance nuevo y el jugador todavía no lo vio ({} = ninguno):
## {relics_gained}. No se guarda.
var pending_migration_report: Dictionary = {}
## Azar del botín y de los críticos. Los tests le fijan la semilla para repetir una tirada.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Árbol de reliquias; null si el balance no tiene "tree".
var relic_tree: RelicTree = null
## Reliquias sacadas de bajadas (no las de cofres ni fragmentos): de ellas sale cuánto se corre la meta.
var claimed_relics: int = 0
## Fragmentos de reliquia juntados en la historia.
var fragments: int = 0
## Veces que se volvió a la superficie y profundidad máxima de las bajadas anteriores (abren anillos del árbol).
var resets: int = 0
var record_depth: float = 0.0
## Metros que se corrió la meta de volver en la bajada en curso (se fija al empezarla).
var run_shift: float = 0.0
## Recién llegado a la superficie (todavía no golpeaste ni compraste): se pueden cambiar las piedras angulares.
var at_surface: bool = true
## Aviso de que la partida pasó al árbol de reliquias y el jugador todavía no lo vio ({} = ninguno): {relics}.
var pending_tree_report: Dictionary = {}
## Reliquias que dio el último cofre abierto.
var last_chest_relics: int = 0
## Reloj monotónico en segundos para lo que depende del ritmo (tope de golpes, racha). Los tests lo reemplazan.
var clock: Callable = func() -> float: return Time.get_ticks_usec() / 1000000.0

## Con qué terminó la bajada anterior: {owned, gps, pick, ability}. Lo usan las estrellas que arrastran.
var _last_descent: Dictionary = {}
## Lo que esas estrellas ya dieron en la bajada en curso, para sumar solo la diferencia al comprar otra.
var _applied_start: Dictionary = {}
var _tap_limiter: TapLimiter = TapLimiter.new()
## Logros y contadores; null si el balance no tiene "achievements".
var achievements: Achievements = null
## Logros conseguidos que la pantalla todavía no mostró. No se guarda.
var pending_achievements: Array[String] = []
## Hora local (0 a 23), para los logros que la miran. Los tests la reemplazan.
var hour_of_day: Callable = func() -> int: return int(Time.get_datetime_dict_from_system()["hour"])
## Golpes de la bajada en curso.
var _descent_hits: int = 0
## Se está tirando el cofre de un golpe crítico.
var _crit_roll: bool = false
## Segundos del frenesí en curso.
var _frenzy_run: float = 0.0
## Segundos de los toques de la ventana de ritmo (todos, también los que pasan el tope).
var _tap_times: Array[float] = []
var _check_wait: float = 0.0
var _frenzied: bool = false
## Mientras se acredita una ausencia (la racha y el bonus por jugar activo no cuentan).
var _away: bool = false
var _last_hit_time: float = -1.0e12
var _streak_since: float = 0.0

## Multiplicador global de oro: bioma x (1 + 0.25 x reliquias).
## Se calcula en cada lectura; no se asigna.
var multiplier: float:
	get:
		return biome_multiplier() * relic_multiplier()

## Motivo por el que se rechazó el último balance ("" si cargó bien).
var last_error: String = ""

## Instante (µs) del último tick de _process; 0 = todavía sin referencia.
var _last_tick_usec: int = 0
## Hora de pared (unix) de ese tick; 0 = sin referencia.
var _last_tick_unix: float = 0.0
## Bioma más profundo de las bajadas anteriores (ver max_biome()).
var _max_biome: int = 0
## Cuántos generadores ya se revelaron en bajadas anteriores (ver is_generator_revealed()).
var _revealed: int = 1
var _generators: Array[Dictionary] = []
var _cost_growth: float = 0.0
var _pick: Dictionary = {}
## Golpes críticos (chance, multiplier). Vacío = sin críticos.
var _crit: Dictionary = {}
## Hitos: con estas cantidades (crecientes) un generador multiplica su producción por _milestone_multiplier.
var _milestones: Array[int] = []
var _milestone_multiplier: float = 1.0
## Secciones opcionales del balance: vacías = ese sistema está apagado (profundidad 0 m, bioma único x1).
var _depth: Dictionary = {}
var _biomes: Array[Dictionary] = []
var _biome_meters_each: float = 0.0
var _biome_growth: float = 1.0
var _loot_hit_chance: float = 0.0
var _loot_second_chance: float = 0.0
## Rarezas de los cofres: {id, name, weight, seconds, hits, relics}. Vacía = no hay botín.
var _rarities: Array[Dictionary] = []
var _rarity_weights: Array[float] = []
## Reglas del prestigio (min_depth, depth_offset, depth_step, exponent, bonus_per_relic). Vacío = sin prestigio.
var _prestige: Dictionary = {}
## Reglas del progreso offline (max_hours, away_seconds, efficiency). Vacío = sin progreso offline.
var _offline: Dictionary = {}
## Reglas de la habilidad (cooldown, seconds, step, hits, cost, growth, max_level, reveal_with). Vacío = no hay.
var _ability: Dictionary = {}
## Profundidad y reliquias de las reglas anteriores, para convertir partidas. Vacío = no se convierte nada.
var _legacy: Dictionary = {}
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
		save.register_section(SAVE_SECTION, to_dict, from_dict, save_backup_tag)
		# Save ya leyó el archivo (es el primer autoload): si había partida, la cuadrilla
		# siguió trabajando desde la hora de ese save.
		apply_offline_since(int(save.loaded_saved_at), Time.get_unix_time_from_system())


func _process(_delta: float) -> void:
	# No se usa `delta`: Godot lo recorta a ~0.13 s por frame, y a pocos fps (celulares
	# lentos, pestañas web en segundo plano) la cuadrilla produciría una fracción de lo debido.
	tick_realtime(Time.get_ticks_usec(), Time.get_unix_time_from_system())
	if achievements != null:
		_check_wait += _delta
		if _check_wait >= ACHIEVEMENT_CHECK_SECONDS:
			_check_wait = 0.0
			check_achievements()


# --- Balance -----------------------------------------------------------------

func load_balance_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return _fail("no existe %s" % path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _fail("%s no es un JSON válido" % path)
	var tree_file: String = str((parsed as Dictionary).get("tree_file", ""))
	if tree_file != "":
		var tree_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(tree_file)) if FileAccess.file_exists(tree_file) else null
		if not (tree_data is Dictionary):
			return _fail("no se pudo leer el árbol %s" % tree_file)
		(parsed as Dictionary)["tree"] = tree_data
	var achievements_file: String = str((parsed as Dictionary).get("achievements_file", ""))
	if achievements_file != "":
		var list: Variant = JSON.parse_string(FileAccess.get_file_as_string(achievements_file)) if FileAccess.file_exists(achievements_file) else null
		if not (list is Dictionary):
			return _fail("no se pudieron leer los logros de %s" % achievements_file)
		(parsed as Dictionary)["achievements"] = list
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

	var parsed_crit: Variant = _read_numbers(balance, "crit", ["multiplier"], ["chance"])
	if parsed_crit == null:
		return false
	if not (parsed_crit as Dictionary).is_empty() and (parsed_crit["chance"] > 1.0 or parsed_crit["multiplier"] < 1.0):
		return _fail("crit: la chance va de 0 a 1 y el multiplicador es de 1 o más")
	var parsed_milestones: Variant = _read_milestones(balance)
	if parsed_milestones == null:
		return false
	var parsed_ability: Variant = _read_ability(balance, parsed_generators)
	if parsed_ability == null:
		return false
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
	var parsed_legacy: Variant = _read_numbers(balance, "legacy", ["meters_scale", "gold_scale", "min_depth", "depth_step", "exponent"], ["depth_offset"])
	if parsed_legacy == null:
		return false
	var parsed_frenzy: Variant = _read_numbers(balance, "frenzy", ["hits_per_second", "enter_seconds", "exit_seconds", "window_seconds"])
	if parsed_frenzy == null:
		return false

	var parsed_tree: RelicTree = null
	if balance.has("tree"):
		parsed_tree = RelicTree.new()
		if not (balance["tree"] is Dictionary) or not parsed_tree.load_data(balance["tree"]):
			return _fail("tree: %s" % parsed_tree.last_error)
	var parsed_tap: Variant = _read_numbers(balance, "tap", ["max_hits", "window_seconds"])
	if parsed_tap == null:
		return false
	var parsed_achievements: Achievements = null
	if balance.has("achievements"):
		parsed_achievements = Achievements.new()
		if not (balance["achievements"] is Dictionary) or not parsed_achievements.load_data(balance["achievements"]):
			return _fail("achievements: %s" % parsed_achievements.last_error)

	last_error = ""
	relic_tree = parsed_tree
	achievements = parsed_achievements
	_tap_limiter.configure(parsed_tap)
	_cost_growth = growth
	_generators = parsed_generators
	_pick = parsed_pick
	_crit = parsed_crit
	_milestones = []
	_milestone_multiplier = 1.0
	if not (parsed_milestones as Dictionary).is_empty():
		_milestones.assign(parsed_milestones["at"])
		_milestone_multiplier = parsed_milestones["multiplier"]
	_depth = parsed_depth
	_prestige = parsed_prestige
	_offline = parsed_offline
	_legacy = parsed_legacy
	_ability = parsed_ability
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
	if not (parsed_loot as Dictionary).is_empty():
		_rarities.assign(parsed_loot["rarities"])
		for rarity: Dictionary in _rarities:
			_rarity_weights.append(rarity["weight"])
		_loot_hit_chance = parsed_loot["chance_per_hit"]
		_loot_second_chance = parsed_loot["chance_per_second"]
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


## Un generador se descubre al comprar el anterior y, desde ahí, se ve siempre (también después de volver a la
## superficie). Comprarlo no está prohibido acá: la interfaz es la que lo esconde.
func is_generator_revealed(index: int) -> bool:
	return _is_valid_index(index) and index < _revealed_count()


func _revealed_count() -> int:
	var count: int = _revealed
	for index: int in range(owned.size()):
		if owned[index] > 0:
			count = maxi(count, index + 2)
	return clampi(count, 1, maxi(_generators.size(), 1))


# --- Habilidad -----------------------------------------------------------------

func has_ability() -> bool:
	return not _ability.is_empty()


## Se descubre junto con el generador "reveal_with" del balance (y desde ahí se ve siempre).
func ability_revealed() -> bool:
	return has_ability() and (ability_level > 0 or is_generator_revealed(_ability["reveal_index"]))


func ability_max_level() -> int:
	return int(_ability.get("max_level", 0))


## Costo de subir al nivel siguiente.
func ability_cost() -> float:
	if not has_ability():
		return 0.0
	return float(_ability["cost"]) * pow(float(_ability["growth"]), ability_level)


## Segundos de producción de la cuadrilla que vale un uso en el nivel `level`.
func ability_seconds(level: int) -> float:
	if not has_ability() or level <= 0:
		return 0.0
	return float(_ability["seconds"]) + float(_ability["step"]) * (level - 1)


func ability_cooldown() -> float:
	return float(_ability.get("cooldown", 0.0)) * (1.0 - _tree_add("cooldown_cut")) * _tree_mul("cooldown_mul")


## Lo que pagaría usarla ahora: lo que más sea entre sus segundos de producción y sus golpes. 0 sin comprarla.
func ability_reward() -> float:
	if not has_ability() or ability_level <= 0:
		return 0.0
	var amount: float = EconomyMath.chest_reward(gold_per_second(), hit_value(), ability_seconds(ability_level), _ability["hits"])
	return amount * (1.0 + _tree_add("ability")) * _tree_mul("ability_mul")


func ability_ready() -> bool:
	return has_ability() and ability_level > 0 and ability_cooldown_left <= 0.0


func upgrade_ability() -> bool:
	if not ability_revealed() or ability_level >= ability_max_level() or ability_cost() > gold:
		return false
	gold -= ability_cost()
	ability_level += 1
	at_surface = false
	ability_upgraded.emit(ability_level)
	gold_changed.emit(gold)
	return true


## Usa la habilidad si está lista y devuelve el oro que dio (0 si no estaba). No es un golpe: sin cofre, y solo es
## crítico si el árbol lo permite.
func use_ability() -> float:
	if not ability_ready():
		return 0.0
	at_surface = false
	var amount: float = ability_reward()
	if _tree_add("ability_crit") > 0.0 and rng.randf() < crit_chance():
		amount *= crit_multiplier()
	amount = _earn(amount)
	count("dynamite")
	ability_cooldown_left = ability_cooldown()
	ability_used.emit(amount)
	gold_changed.emit(gold)
	return amount


## Pasa tiempo de recarga (el reloj real, también con el juego cerrado; el simulador lo llama a mano).
func advance_ability(seconds: float) -> void:
	if seconds > 0.0:
		ability_cooldown_left = maxf(ability_cooldown_left - seconds, 0.0)


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
	return minf(_loot_hit_chance * (1.0 + _tree_add("chest_chance")) * _loot_rate(), 1.0)


## Probabilidad (0 a 1) por segundo de que la cuadrilla encuentre un cofre (solo si produce).
func loot_chance_per_second() -> float:
	return minf(_loot_second_chance * (1.0 + _tree_add("chest_chance")) * (1.0 + _tree_add("passive_chest")) * _loot_rate(), 1.0)


## Las rarezas con su probabilidad real (peso / suma de pesos) y su premio, para mostrarlas al jugador:
## [{id, name, chance, seconds, hits, relics}] en el orden del balance.
func loot_table() -> Array[Dictionary]:
	var weights: Array[float] = _effective_weights()
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var table: Array[Dictionary] = []
	for index: int in range(_rarities.size()):
		var rarity: Dictionary = _rarities[index]
		table.append({
			"id": rarity["id"],
			"name": rarity["name"],
			"chance": weights[index] / total,
			"seconds": rarity["seconds"],
			"hits": rarity["hits"],
			"relics": rarity["relics"],
		})
	return table


## El oro que pagaría ahora un cofre de la rareza `rarity`: lo que más sea entre sus segundos de cuadrilla y sus
## golpes (así también vale la pena antes de tener cuadrilla). 0 si la rareza no existe.
func loot_reward(rarity: int) -> float:
	if rarity < 0 or rarity >= _rarities.size():
		return 0.0
	var amount: float = EconomyMath.chest_reward(gold_per_second(), hit_value(), _rarities[rarity]["seconds"], _rarities[rarity]["hits"])
	return amount * (1.0 + _tree_add("chest_gold"))


## Los pesos de las rarezas con el árbol encima: lo que ganan las que no son la primera (la común) sale de ella, así
## subir una rareza no diluye a las demás. "no_common" la saca.
func _effective_weights() -> Array[float]:
	var weights: Array[float] = _rarity_weights.duplicate()
	if relic_tree == null or weights.is_empty():
		return weights
	var gained: float = 0.0
	for index: int in range(1, weights.size()):
		var extra: float = weights[index] * _tree_add("weight_" + str(_rarities[index]["id"]))
		weights[index] += extra
		gained += extra
	weights[0] = 0.0 if relic_tree.has_effect("no_common") else maxf(weights[0] - gained, 0.0)
	return weights


## Cuánto más (o menos) seguido salen cofres cuando "no_common" saca los comunes: cada una de las otras rarezas sale
## ese tanto de veces más seguido que antes.
func _loot_rate() -> float:
	if relic_tree == null or not relic_tree.has_effect("no_common"):
		return 1.0
	var total: float = 0.0
	for weight: float in _rarity_weights:
		total += weight
	var rest: float = 0.0
	for weight: float in _effective_weights():
		rest += weight
	# El total con los comunes es el mismo de siempre: los pesos extra salieron de ellos.
	return rest * relic_tree.mul("no_common") / total


## Abre un cofre de la rareza `rarity` (índice de loot_table()): el oro entra en el acto y, si la rareza las da,
## suma reliquias. Un índice inexistente no hace nada. Lo usan el panel de debug y las capturas.
func drop_loot(rarity: int) -> void:
	if rarity < 0 or rarity >= _rarities.size():
		return
	_open_chest(rarity)
	gold_changed.emit(gold)


## El cofre sin avisar gold_changed: el golpe y el tick lo avisan una sola vez, al final.
func _open_chest(rarity: int) -> void:
	var double_chance: float = _tree_add("double_chest")
	var times: int = 2 if double_chance > 0.0 and rng.randf() < double_chance else 1
	for i: int in range(times):
		var amount: float = _earn(loot_reward(rarity))
		# Después de calcular el oro: la reliquia nueva multiplica de acá en adelante.
		var given: int = int(_rarities[rarity]["relics"])
		if given > 0:
			var extra: float = _tree_add("legendary_relics")
			if extra > 0.0:
				given += int(extra) + (1 if rng.randf() < extra - int(extra) else 0)
		last_chest_relics = given
		relics = mini(relics + given, int(MAX_LOADED_RELICS))
		count("chests")
		count("chest_" + str(_rarities[rarity]["id"]))
		if _crit_roll and rarity == _rarities.size() - 1:
			_record_max("crit_rarest", 1.0)
		loot_dropped.emit(rarity, amount)


# --- Reliquias y prestigio ---------------------------------------------------

## Multiplicador de oro de las reliquias que tenés (x1 si el balance no tiene prestigio). Con árbol incluye además
## lo que multiplica a todo el oro: las estrellas y la racha.
func relic_multiplier() -> float:
	return relic_multiplier_for(relics) * (1.0 + streak_bonus())


## Multiplicador que darían `count` reliquias (para mostrar cómo quedaría tras una subida).
func relic_multiplier_for(count: int) -> float:
	if relic_tree != null:
		return relic_tree.history_multiplier(count) * (1.0 + relic_tree.add("gold"))
	if _prestige.is_empty():
		return 1.0
	return EconomyMath.relic_multiplier(count, _prestige["bonus_per_relic"])


## Bonus de oro de cada reliquia (0.25 = +25%).
func relic_bonus() -> float:
	return _prestige.get("bonus_per_relic", 0.0)


## Profundidad mínima (m) para volver a la superficie con reliquias.
func prestige_min_depth() -> float:
	return _prestige.get("min_depth", 0.0)


## Profundidad desde la que se puede volver en la bajada en curso: la mínima más lo que se corrió la meta.
func return_depth() -> float:
	return prestige_min_depth() + run_shift


## Reliquias que daría volver a la superficie ahora: 0 si todavía no llegaste a la meta. La fórmula se mide desde la
## meta corrida y, con árbol, bajar a una meta más honda paga más.
func prestige_relics() -> int:
	if _prestige.is_empty():
		return 0
	var gained: int = EconomyMath.relics_for_depth(depth() - run_shift, _prestige["min_depth"], _prestige["depth_offset"], _prestige["depth_step"], _prestige["exponent"])
	var every: float = 0.0 if relic_tree == null else relic_tree.return_extra_every()
	if gained <= 0 or every <= 0.0:
		return gained
	return gained + int(run_shift / every)


func can_prestige() -> bool:
	return prestige_relics() > 0


## Vuelve a la superficie: suma las reliquias de esta bajada y reinicia la partida (oro,
## profundidad, cuadrilla y pico). Devuelve las reliquias ganadas; si todavía no se puede,
## devuelve 0 y no toca nada. Ejecuta ya mismo: la confirmación al jugador la pide la UI antes.
func prestige() -> int:
	var gained: int = prestige_relics()
	if gained <= 0:
		return 0
	if relic_tree != null:
		# Antes de reiniciar: con qué termina esta bajada (para las estrellas que arrastran) y los hitos.
		_last_descent = { "owned": owned.duplicate(), "gps": gold_per_second(), "pick": pick_level, "ability": ability_level }
		record_depth = record_depth_now()
		resets += 1
		claimed_relics = mini(claimed_relics + gained, int(MAX_LOADED_RELICS))
	relics = mini(relics + gained, int(MAX_LOADED_RELICS))
	_record_max("best_reset", gained)
	# Antes de reiniciar: hay logros que solo se ven con la bajada todavía puesta.
	check_achievements()
	_max_biome = max_biome()
	_revealed = _revealed_count()
	_reset_run()
	prestiged.emit(gained)
	return gained


# --- Árbol de reliquias --------------------------------------------------------

func has_tree() -> bool:
	return relic_tree != null


## Reliquias para gastar (sin árbol, todas las que tenés).
func available_relics() -> int:
	if relic_tree == null:
		return relics
	return maxi(relics - relic_tree.spent(), 0)


## La profundidad máxima contando la bajada en curso (abre los anillos).
func record_depth_now() -> float:
	return maxf(record_depth, depth())


func star_state(id: String) -> int:
	if relic_tree == null:
		return RelicTree.State.HIDDEN
	return relic_tree.state(id, record_depth_now(), resets)


func can_buy_star(id: String) -> bool:
	return relic_tree != null and relic_tree.can_buy(id, available_relics(), record_depth_now(), resets)


func buy_star(id: String) -> bool:
	if relic_tree == null or not relic_tree.buy(id, available_relics(), record_depth_now(), resets):
		return false
	# Recién vuelto: las estrellas que arrastran y las piedras anotadas valen ya para esta bajada.
	if at_surface:
		relic_tree.apply_keystones()
		_apply_start_bonuses()
	tree_changed.emit()
	gold_changed.emit(gold)
	return true


## 1 = la piedra se prende desde la próxima bajada, -1 = se apaga, 0 = no hay nada pendiente.
func keystone_pending(id: String) -> int:
	if relic_tree == null:
		return 0
	return int(relic_tree.planned_keystones.has(id)) - int(relic_tree.active_keystones.has(id))


## Las piedras angulares se prenden y apagan cuando sea; el cambio vale desde la próxima bajada. En la superficie, sin
## haber empezado la bajada, vale ya.
func set_keystone(id: String, active: bool) -> bool:
	if relic_tree == null or not relic_tree.set_keystone(id, active, at_surface):
		return false
	tree_changed.emit()
	gold_changed.emit(gold)
	return true


func dismiss_tree_report() -> void:
	pending_tree_report = {}


## Fragmentos de reliquia: al juntar los que pide el árbol se convierten solos en una.
func add_fragments(count: int) -> void:
	if relic_tree == null or count <= 0:
		return
	var each: int = relic_tree.fragments_per_relic()
	var before: int = fragments
	fragments = mini(fragments + count, int(MAX_LOADED_COUNTER))
	relics = mini(relics + fragments / each - before / each, int(MAX_LOADED_RELICS))
	tree_changed.emit()
	gold_changed.emit(gold)


## Reliquias de afuera (herramientas de prueba): no corren la meta.
func grant_relics(count: int) -> void:
	if count <= 0:
		return
	relics = mini(relics + count, int(MAX_LOADED_RELICS))
	tree_changed.emit()
	gold_changed.emit(gold)


## Cumple los hitos que abren los anillos (herramientas de prueba).
func open_rings() -> void:
	if relic_tree == null:
		return
	for ring: int in [2, 3]:
		var gate: Dictionary = relic_tree.ring_requirement(ring)
		resets = maxi(resets, int(gate.get("resets", 0)))
		record_depth = maxf(record_depth, float(gate.get("depth", 0.0)))
	tree_changed.emit()


## Segundos desde el último golpe.
func _since_hit() -> float:
	return float(clock.call()) - _last_hit_time


## Racha: un escalón por cada minuto entero golpeando sin parar, hasta el tope. No corre mientras no estás.
func streak_bonus() -> float:
	if relic_tree == null or _away or not relic_tree.has_effect("streak_cap") or _since_hit() >= relic_tree.streak_break_seconds():
		return 0.0
	var minutes: float = floorf((float(clock.call()) - _streak_since) / 60.0)
	return minf(minutes * relic_tree.value("streak_rate", 0.0), relic_tree.add("streak_cap"))


## Lo que multiplica a la cuadrilla según estés golpeando o no.
func _crew_stance() -> float:
	if relic_tree == null:
		return 1.0
	var working: bool = not _away and _since_hit() < relic_tree.working_seconds()
	return relic_tree.mul("crew_active" if working else "crew_idle")


## El medidor de frenesí vive en quien mide el ritmo; acá solo importa si está prendido (algunas estrellas lo usan).
func set_frenzy(active: bool) -> void:
	if active and not _frenzied:
		count("frenzy_starts")
	elif not active:
		_frenzy_run = 0.0
	_frenzied = active


## Lo que se tiene al empezar una bajada gracias a la anterior: {gold, owned, pick, ability}.
func _start_bonuses() -> Dictionary:
	var crew: Array[int] = []
	crew.resize(owned.size())
	crew.fill(0)
	var result: Dictionary = { "gold": 0.0, "owned": crew, "pick": 0, "ability": 0 }
	if relic_tree == null or _last_descent.is_empty():
		return result
	result["gold"] = relic_tree.value("carry_gold_seconds", 0.0) * float(_last_descent.get("gps", 0.0))
	var before: Array = _last_descent.get("owned", [])
	for index: int in range(mini(crew.size(), before.size())):
		crew[index] = int(float(before[index]) * relic_tree.add("carry_crew"))
	if relic_tree.add("keep_pick") > 0.0:
		result["pick"] = int(_last_descent.get("pick", 0))
	if relic_tree.add("keep_ability") > 0.0:
		result["ability"] = int(_last_descent.get("ability", 0))
	return result


## Da lo que falte de los bonus de arranque: comprar una estrella en la superficie suma solo la diferencia. El oro es
## para gastar y no cuenta para la profundidad.
func _apply_start_bonuses() -> void:
	var now: Dictionary = _start_bonuses()
	var given_owned: Array = _applied_start.get("owned", [])
	gold += float(now["gold"]) - float(_applied_start.get("gold", 0.0))
	for index: int in range(owned.size()):
		var had: int = int(given_owned[index]) if index < given_owned.size() else 0
		owned[index] += int(now["owned"][index]) - had
	pick_level = maxi(pick_level, int(now["pick"]))
	ability_level = maxi(ability_level, mini(int(now["ability"]), ability_max_level()))
	_applied_start = now


# --- Logros ----------------------------------------------------------------------

func has_achievements() -> bool:
	return achievements != null


## Suma a un contador histórico (también los que solo conoce la interfaz).
func count(stat_name: String, amount: float = 1.0) -> void:
	if achievements != null:
		achievements.add(stat_name, amount)


## El valor actual de un contador o de un dato que miran los logros.
func stat(stat_name: String) -> float:
	return 0.0 if achievements == null else achievements.value(stat_name, _stat_values())


## Mira qué logros se cumplen ahora, paga sus fragmentos y avisa una sola vez con todos. Devuelve los nuevos.
func check_achievements() -> Array[String]:
	if achievements == null:
		return []
	for index: int in range(_generators.size()):
		_record_max("max_" + str(_generators[index]["id"]), owned[index])
	if _descent_hits == 0 and run_gold > 0.0 and biome_index() >= 1:
		_record_max("no_hit_rock", 1.0)
	var new_ones: Array[String] = achievements.check(_stat_values())
	if not new_ones.is_empty():
		_reward(new_ones)
	return new_ones


## Da un logro a mano (herramientas de prueba).
func unlock_achievement(id: String) -> bool:
	if achievements == null or not achievements.unlock(id):
		return false
	var one: Array[String] = [id]
	_reward(one)
	return true


func dismiss_achievements() -> void:
	pending_achievements.clear()


func _reward(ids: Array[String]) -> void:
	var total: int = 0
	for id: String in ids:
		total += achievements.fragments_for(id)
	pending_achievements.append_array(ids)
	add_fragments(total)
	achievements_unlocked.emit(ids)


## Lo que los logros miran y no es un contador: se calcula del estado.
func _stat_values() -> Dictionary:
	var values: Dictionary = {
		"record_depth": record_depth_now(),
		"resets": resets,
		"return_depth": return_depth(),
		"overshoot": depth() - return_depth(),
		"relics_earned": relics,
	}
	if relic_tree == null:
		return values
	var lit: int = 0
	var keystones: int = 0
	var bridges: int = 0
	var complete: bool = true
	var ring_done: Dictionary = { 1: true, 2: true }
	for id: String in relic_tree.ids():
		var level: int = relic_tree.level(id)
		var ring: int = int(relic_tree.star(id).get("ring", 0))
		values["star_" + id] = 1 if level > 0 else 0
		if level < relic_tree.max_level(id):
			complete = false
			ring_done[ring] = false
		if level > 0:
			lit += 1
			keystones += int(relic_tree.is_keystone(id))
			bridges += int(relic_tree.star(id).has("bridge"))
	values["stars"] = lit
	values["keystones"] = keystones
	values["bridges"] = bridges
	values["ring1_done"] = int(ring_done[1])
	values["ring2_done"] = int(ring_done[2])
	values["complete"] = int(complete)
	return values


func _record_max(stat_name: String, amount: float) -> void:
	if achievements != null:
		achievements.set_max(stat_name, amount)


## Tiempo de juego de verdad (no las ausencias): jugado, activo y en frenesí.
func _count_play_time(seconds: float) -> void:
	if achievements == null:
		return
	achievements.add("play_seconds", seconds)
	var working: float = DEFAULT_WORKING_SECONDS if relic_tree == null else relic_tree.working_seconds()
	if _since_hit() < working:
		achievements.add("active_seconds", seconds)
	if _frenzied:
		_frenzy_run += seconds
		achievements.add("frenzy_seconds", seconds)
		achievements.set_max("frenzy_best", _frenzy_run)


## El mejor ritmo sostenido: toques de los últimos TAP_RATE_SECONDS, contando también los que pasan el tope.
func _measure_tap_rate(now: float) -> void:
	if achievements == null:
		return
	_tap_times.append(now)
	while not _tap_times.is_empty() and _tap_times[0] <= now - TAP_RATE_SECONDS:
		_tap_times.pop_front()
	achievements.set_max("max_hps", _tap_times.size() / TAP_RATE_SECONDS)


# --- Botín (tirada) -----------------------------------------------------------

## Tira por un cofre con probabilidad `chance`. Si sale, sortea la rareza y lo abre.
func _roll_loot(chance: float) -> void:
	if _rarities.is_empty() or chance <= 0.0 or rng.randf() >= chance:
		return
	_open_chest(EconomyMath.pick_weighted(_effective_weights(), rng.randf()))


# --- Estado ------------------------------------------------------------------

## Empieza una partida de cero (también sin reliquias), conservando el balance.
func reset() -> void:
	relics = 0
	_max_biome = 0
	_revealed = 1
	pending_offline_report = {}
	pending_migration_report = {}
	pending_tree_report = {}
	claimed_relics = 0
	fragments = 0
	resets = 0
	record_depth = 0.0
	_last_descent = {}
	_tap_limiter.reset()
	_tap_times.clear()
	pending_achievements.clear()
	if achievements != null:
		achievements.clear()
	if relic_tree != null:
		relic_tree.clear()
	_reset_run()
	tree_changed.emit()


## Reinicia solo la partida en curso: oro, oro ganado (profundidad), cuadrilla y pico. Las reliquias no se tocan.
func _reset_run() -> void:
	gold = 0.0
	run_gold = 0.0
	pick_level = 0
	ability_level = 0
	ability_cooldown_left = 0.0
	owned.resize(_generators.size())
	owned.fill(0)
	run_shift = 0.0 if relic_tree == null else relic_tree.shift_for(claimed_relics)
	if relic_tree != null:
		relic_tree.apply_keystones()
	at_surface = true
	_applied_start = {}
	_last_hit_time = -1.0e12
	_frenzied = false
	_frenzy_run = 0.0
	_descent_hits = 0
	_apply_start_bonuses()
	gold_changed.emit(gold)


func owned_count(index: int) -> int:
	if not _is_valid_index(index):
		return 0
	return owned[index]


## Oro por segundo que aporta el generador `index` (unidades * oro/s base * hitos * multiplicador).
func generator_output(index: int) -> float:
	if not _is_valid_index(index):
		return 0.0
	return _base_output(index) * multiplier


func gold_per_second() -> float:
	var base_total: float = 0.0
	for index: int in range(_generators.size()):
		base_total += _base_output(index)
	return base_total * multiplier


## Cuánto multiplican los hitos que ya alcanzó el generador `index` (1 = ninguno).
func milestone_multiplier(index: int) -> float:
	return pow(milestone_step(), milestone_tier(index))


## Cuántos hitos alcanzó el generador `index` (0 = ninguno): la interfaz lo usa para su aspecto.
func milestone_tier(index: int) -> int:
	if not _is_valid_index(index):
		return 0
	var reached: int = 0
	for threshold: int in _milestones:
		if owned[index] >= threshold:
			reached += 1
	return reached


## Por cuánto multiplica cada hito (2 = el doble). 1 si no hay hitos.
func milestone_step() -> float:
	if relic_tree == null or _milestones.is_empty():
		return _milestone_multiplier
	return relic_tree.value("milestone_mult", _milestone_multiplier)


## Cantidad del próximo hito del generador `index`; 0 si ya no queda ninguno (o no hay hitos).
func next_milestone(index: int) -> int:
	if not _is_valid_index(index):
		return 0
	for threshold: int in _milestones:
		if owned[index] < threshold:
			return threshold
	return 0


func _base_output(index: int) -> float:
	return owned[index] * float(_generators[index]["base_rate"]) * milestone_multiplier(index) * (1.0 + _tree_add("crew")) * _crew_stance()


## Precio base del generador con los descuentos del árbol.
func _base_cost(index: int) -> float:
	return float(_generators[index]["base_cost"]) * (1.0 - _tree_add("discount"))


func _tree_add(type: String) -> float:
	return 0.0 if relic_tree == null else relic_tree.add(type)


func _tree_mul(type: String) -> float:
	return 1.0 if relic_tree == null else relic_tree.mul(type)


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
		advance_ability(gap)
		if not _offline.is_empty() and gap >= _offline["away_seconds"]:
			_record_max("max_away", gap)
			apply_offline(gap)
		else:
			_count_play_time(gap)
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
	_roll_loot(1.0 - pow(1.0 - loot_chance_per_second(), delta))
	gold_changed.emit(gold)


# --- Frenesí -----------------------------------------------------------------

## Los umbrales del frenesí del balance (para core/frenzy_meter.gd); {} si el balance no tiene "frenzy".
func frenzy_settings() -> Dictionary:
	var settings: Dictionary = _frenzy.duplicate()
	if settings.has("hits_per_second"):
		settings["hits_per_second"] = maxf(float(settings["hits_per_second"]) - _tree_add("frenzy_threshold"), 1.0)
	return settings


# --- Progreso offline ------------------------------------------------------------

## Tope de segundos de ausencia que se acreditan (0 si el balance no tiene "offline").
func offline_max_seconds() -> float:
	if _offline.is_empty():
		return 0.0
	var hours: float = float(_offline["max_hours"])
	if relic_tree != null:
		hours = relic_tree.value("offline_hours", hours)
	return hours * SECONDS_PER_HOUR


## Cuánto rinde la cuadrilla mientras no estás (0.25 = 25%). 0 si el balance no tiene "offline".
func offline_efficiency() -> float:
	var efficiency: float = _offline.get("efficiency", 0.0)
	if relic_tree != null:
		efficiency = relic_tree.value("offline_eff", efficiency)
	return efficiency


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
	_away = true
	var gained: float = gold_per_second() * EconomyMath.offline_paid_seconds(seconds, _offline["away_seconds"], offline_efficiency()) * (1.0 + _tree_add("offline_gain"))
	if seconds <= 0.0 or gained <= 0.0:
		_away = false
		return {}
	_earn(gained)
	_away = false
	var report: Dictionary = { "seconds": seconds, "gold": gained, "capped": elapsed > offline_max_seconds() }
	count("afk_seconds", seconds)
	gold_changed.emit(gold)
	if elapsed >= _offline["away_seconds"]:
		_queue_offline_notice(report)
	return report


## Offline desde la hora (unix) en que se guardó la partida. saved_at <= 0 = no había save.
func apply_offline_since(saved_at: int, now: float) -> Dictionary:
	if saved_at <= 0:
		return {}
	_record_max("max_away", now - saved_at)
	advance_ability(now - saved_at)
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
	var value: float = EconomyMath.hit_value(pick_level, _pick["power_base"], multiplier, gold_per_second(), float(_pick["passive_share"]) + _tree_add("hit_share"))
	return value * (1.0 + _tree_add("hit")) * _tree_mul("hit_mul")


func crit_chance() -> float:
	if _crit.is_empty():
		return 0.0
	return (float(_crit["chance"]) + _tree_add("crit_chance")) * _tree_mul("crit_chance_mul")


func crit_multiplier() -> float:
	if _crit.is_empty():
		return 1.0
	return (float(_crit["multiplier"]) + _tree_add("crit_mult")) * _tree_mul("crit_mult_mul")


## Un toque del jugador: un golpe, salvo que ya haya demasiados en el último segundo (balance "tap"). Devuelve el
## oro ganado, o 0 si el toque no contó.
func tap() -> float:
	var now: float = float(clock.call())
	_measure_tap_rate(now)
	if not _tap_limiter.allow(now):
		return 0.0
	return hit()


## Un golpe a la roca, que puede salir crítico. Devuelve el oro ganado. No mira el tope de golpes: eso es tap().
func hit() -> float:
	var now: float = clock.call()
	if relic_tree != null and now - _last_hit_time >= relic_tree.streak_break_seconds():
		_streak_since = now
	_last_hit_time = now
	at_surface = false
	_descent_hits += 1
	var amount: float = hit_value()
	if _frenzied:
		amount *= 1.0 + _tree_add("frenzy_hit")
	var chance: float = crit_chance()
	last_hit_critical = chance > 0.0 and rng.randf() < chance
	if last_hit_critical:
		amount *= crit_multiplier()
	var double_chance: float = _tree_add("double_hit")
	if double_chance > 0.0 and rng.randf() < double_chance:
		amount *= 2.0
	amount = _earn(amount)
	count("hits")
	if last_hit_critical:
		count("crits")
	var hour: int = int(hour_of_day.call()) if achievements != null else -1
	if hour >= NIGHT_HOURS.x and hour < NIGHT_HOURS.y:
		_record_max("night_play", 1.0)
	hit_landed.emit(amount)
	_crit_roll = last_hit_critical
	_roll_loot(loot_chance_per_hit())
	if last_hit_critical and _tree_add("crit_chest") > 0.0:
		_roll_loot(_tree_add("crit_chest"))
	_crit_roll = false
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
	at_surface = false
	pick_upgraded.emit(pick_level)
	gold_changed.emit(gold)
	return true


# --- Compra de generadores ---------------------------------------------------

## Qué compraría `buy_generator` ahora: {count: int, cost: float, affordable: bool}.
## En modo MAX sin oro suficiente para ninguno, muestra el costo de 1 (affordable = false).
func quote(index: int, mode: int) -> Dictionary:
	if not _is_valid_index(index):
		return { "count": 0, "cost": 0.0, "affordable": false }
	var base_cost: float = _base_cost(index)
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
	at_surface = false
	gold -= offer["cost"]
	var before: int = owned[index]
	owned[index] += count
	generator_bought.emit(index, count)
	for threshold: int in _milestones:
		if before < threshold and owned[index] >= threshold:
			milestone_reached.emit(index, threshold)
	gold_changed.emit(gold)
	return count


# --- Guardado ----------------------------------------------------------------

func to_dict() -> Dictionary:
	var data: Dictionary = {
		"balance_version": BALANCE_VERSION,
		"gold": gold,
		"owned": owned.duplicate(),
		"pick_level": pick_level,
		"run_gold": run_gold,
		"relics": relics,
		"max_biome": max_biome(),
		"revealed": _revealed_count(),
		"ability_level": ability_level,
		"ability_wait": ability_cooldown_left,
	}
	if relic_tree != null:
		data["balance_version"] = TREE_VERSION
		data["tree"] = relic_tree.to_dict()
		data["claimed_relics"] = claimed_relics
		data["fragments"] = fragments
		data["resets"] = resets
		data["record_depth"] = record_depth_now()
		data["run_shift"] = run_shift
		data["at_surface"] = at_surface
		data["last_descent"] = _last_descent.duplicate(true)
		data["applied_start"] = _applied_start.duplicate(true)
	if achievements != null:
		data["achievements"] = achievements.to_dict()
		data["descent_hits"] = _descent_hits
	return data


## Qué copia pedirle a Save antes de cargar `data`: una partida sin árbol se convierte y conviene conservar la de antes.
func save_backup_tag(data: Dictionary) -> String:
	if relic_tree != null and int(_number(data.get("balance_version"), 1.0)) < TREE_VERSION:
		return BACKUP_BEFORE_TREE
	return ""


## Restaura el estado desde un diccionario (p. ej. un JSON). Tolera claves faltantes,
## tipos incorrectos, negativos, NaN/infinitos y cantidades de generadores distintas a
## las del balance actual: lo inválido se reemplaza por 0.
func from_dict(data: Dictionary) -> void:
	# El árbol primero: de él salen topes de lo demás (por ejemplo, la recarga de la habilidad).
	if relic_tree != null:
		var saved_tree: Variant = data.get("tree")
		relic_tree.from_dict(saved_tree if saved_tree is Dictionary else {})
	_last_hit_time = -1.0e12
	_frenzied = false
	_frenzy_run = 0.0
	pending_tree_report = {}
	pending_achievements.clear()
	_tap_times.clear()
	if achievements != null:
		var saved_achievements: Variant = data.get("achievements")
		achievements.from_dict(saved_achievements if saved_achievements is Dictionary else {})
	gold = maxf(_number(data.get("gold"), 0.0), 0.0)
	# Lo ganado nunca puede ser menos que lo que tenés: cubre saves anteriores a la
	# profundidad (sin run_gold) y datos editados a mano. Con árbol sí puede: el oro con el que arranca una bajada
	# (la Bolsa) no se ganó en ella.
	var carries_bag: bool = relic_tree != null and int(_number(data.get("balance_version"), 1.0)) >= TREE_VERSION
	run_gold = maxf(_number(data.get("run_gold"), 0.0), 0.0 if carries_bag else gold)
	relics = int(clampf(_number(data.get("relics"), 0.0), 0.0, MAX_LOADED_RELICS))
	pick_level = int(clampf(_number(data.get("pick_level"), 0.0), 0.0, MAX_LOADED_PICK_LEVEL))
	owned.fill(0)
	var saved_owned: Variant = data.get("owned")
	if saved_owned is Array:
		for index: int in range(mini((saved_owned as Array).size(), owned.size())):
			owned[index] = int(clampf(_number(saved_owned[index], 0.0), 0.0, MAX_LOADED_OWNED))
	_revealed = int(clampf(_number(data.get("revealed"), 1.0), 1.0, maxi(_generators.size(), 1)))
	ability_level = int(clampf(_number(data.get("ability_level"), 0.0), 0.0, ability_max_level()))
	ability_cooldown_left = clampf(_number(data.get("ability_wait"), 0.0), 0.0, ability_cooldown())
	var deepest: int = maxi(biome_count() - 1, 0)
	_max_biome = int(clampf(_number(data.get("max_biome"), 0.0), 0.0, deepest))
	# Quien tiene reliquias llegó al menos hasta donde se puede volver a la superficie (partidas sin el dato).
	if relics > 0:
		_max_biome = maxi(_max_biome, EconomyMath.biome_index(prestige_min_depth(), _biome_meters_each, biome_count()))
	var version: int = int(_number(data.get("balance_version"), 1.0))
	if relic_tree != null and version >= TREE_VERSION:
		_load_tree_state(data)
	else:
		claimed_relics = 0
		fragments = 0
		resets = 0
		record_depth = 0.0
		run_shift = 0.0
		at_surface = run_gold <= 0.0
		_last_descent = {}
		_applied_start = {}
	if version < BALANCE_VERSION:
		_migrate_old_run()
	if relic_tree != null and version < TREE_VERSION:
		_migrate_to_tree()
	_descent_hits = int(clampf(_number(data.get("descent_hits"), 0.0 if run_gold <= 0.0 else 1.0), 0.0, MAX_LOADED_COUNTER))
	gold_changed.emit(gold)
	tree_changed.emit()


func _load_tree_state(data: Dictionary) -> void:
	claimed_relics = int(clampf(_number(data.get("claimed_relics"), 0.0), 0.0, MAX_LOADED_RELICS))
	fragments = int(clampf(_number(data.get("fragments"), 0.0), 0.0, MAX_LOADED_COUNTER))
	resets = int(clampf(_number(data.get("resets"), 0.0), 0.0, MAX_LOADED_COUNTER))
	record_depth = clampf(_number(data.get("record_depth"), 0.0), 0.0, MAX_LOADED_METERS)
	run_shift = clampf(_number(data.get("run_shift"), 0.0), 0.0, MAX_LOADED_METERS)
	at_surface = data.get("at_surface") == true
	_last_descent = _read_descent(data.get("last_descent"))
	_applied_start = _read_descent(data.get("applied_start"))


## Una "foto" de bajada guardada ({owned, gps o gold, pick, ability}) con sus números saneados; {} si no hay.
func _read_descent(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not (value.get("owned") is Array):
		return {}
	var crew: Array[int] = []
	for entry: Variant in value["owned"]:
		crew.append(int(clampf(_number(entry, 0.0), 0.0, MAX_LOADED_OWNED)))
	return {
		"owned": crew,
		"gps": maxf(_number(value.get("gps"), 0.0), 0.0),
		"gold": maxf(_number(value.get("gold"), 0.0), 0.0),
		"pick": int(clampf(_number(value.get("pick"), 0.0), 0.0, MAX_LOADED_PICK_LEVEL)),
		"ability": int(clampf(_number(value.get("ability"), 0.0), 0.0, ability_max_level())),
	}


## La partida es de antes del árbol: las reliquias quedan para gastar y cuentan como sacadas de bajadas. La bajada en
## curso sigue con su meta de siempre; la corrida arranca en la próxima.
func _migrate_to_tree() -> void:
	claimed_relics = relics
	resets = 1 if relics > 0 else 0
	record_depth = maxf(depth(), _max_biome * _biome_meters_each)
	if relics > 0:
		record_depth = maxf(record_depth, prestige_min_depth())
		pending_tree_report = { "relics": relics }


## El jugador ya vio el aviso de la conversión.
func dismiss_migration_report() -> void:
	pending_migration_report = {}


## La partida en curso se jugó con la curva anterior, que no se puede traducir (la misma profundidad cuesta otro
## oro): se entregan las reliquias que ya tenía ganadas con las reglas de entonces y se vuelve a la superficie.
## Las reliquias de antes y lo revelado se conservan. Sin bajada en curso no hay nada que convertir.
func _migrate_old_run() -> void:
	var crew: bool = owned.any(func(count: int) -> bool: return count > 0)
	if _legacy.is_empty() or (run_gold <= 0.0 and pick_level <= 0 and not crew):
		return
	var old_depth: float = EconomyMath.depth(run_gold, _legacy["meters_scale"], _legacy["gold_scale"])
	var gained: int = EconomyMath.relics_for_depth(old_depth, _legacy["min_depth"], _legacy["depth_offset"], _legacy["depth_step"], _legacy["exponent"])
	relics = mini(relics + gained, int(MAX_LOADED_RELICS))
	_revealed = _revealed_count()
	_reset_run()
	pending_migration_report = { "relics_gained": gained }


# --- Internos ----------------------------------------------------------------

## Suma oro ganado: va al oro y a lo ganado en la partida (profundidad). No emite señales. Devuelve lo que entró:
## con la veta del árbol, antes de cierta fracción de la meta todo vale más (no lo juntado estando fuera).
func _earn(amount: float) -> float:
	if relic_tree != null and not _away and relic_tree.has_effect("shallow_fraction") and depth() < relic_tree.add("shallow_fraction") * return_depth():
		amount *= relic_tree.mul("shallow_mul")
	gold += amount
	run_gold += amount
	count("gold_earned", amount)
	return amount


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


## Lee la sección opcional "ability": números y "reveal_with" (id del generador junto al que se descubre).
## Mismo contrato que _read_numbers.
func _read_ability(balance: Dictionary, generators: Array[Dictionary]) -> Variant:
	var numbers: Variant = _read_numbers(balance, "ability", ["cooldown", "seconds", "hits", "cost", "growth", "max_level"], ["step"])
	if numbers == null or (numbers as Dictionary).is_empty():
		return numbers
	if numbers["growth"] < 1.0 or numbers["max_level"] < 1.0:
		_fail("ability.growth y ability.max_level tienen que ser 1 o más")
		return null
	var reveal: String = str((balance["ability"] as Dictionary).get("reveal_with", ""))
	for index: int in range(generators.size()):
		if generators[index]["id"] == reveal:
			numbers["reveal_index"] = index
			return numbers
	_fail("ability.reveal_with tiene que ser el id de un generador")
	return null


## Lee la sección opcional "milestones": {at: [25, 50, 100], multiplier}. Mismo contrato que _read_numbers.
func _read_milestones(balance: Dictionary) -> Variant:
	var numbers: Variant = _read_numbers(balance, "milestones", ["multiplier"])
	if numbers == null or (numbers as Dictionary).is_empty():
		return numbers
	if numbers["multiplier"] < 1.0:
		_fail("milestones.multiplier tiene que ser 1 o más")
		return null
	var raw: Variant = (balance["milestones"] as Dictionary).get("at")
	if not (raw is Array) or (raw as Array).is_empty():
		_fail("milestones.at necesita al menos una cantidad")
		return null
	var thresholds: Array[int] = []
	for entry: Variant in raw:
		var threshold: int = int(_number(entry, 0.0))
		if threshold <= 0 or (not thresholds.is_empty() and threshold <= thresholds.back()):
			_fail("milestones.at tiene que ser una lista creciente de cantidades > 0")
			return null
		thresholds.append(threshold)
	numbers["at"] = thresholds
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


## Lee la sección opcional "loot": {chance_per_hit, chance_per_second, rarities: [{id, name, weight, seconds,
## hits, relics}]}. Mismo contrato que _read_numbers: {} si no está, null si es inválida.
func _read_loot(balance: Dictionary) -> Variant:
	var numbers: Variant = _read_numbers(balance, "loot", [], ["chance_per_hit", "chance_per_second"])
	if numbers == null or not balance.has("loot"):
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
		var seconds: float = _number(entry.get("seconds"), -1.0)
		var hits: float = _number(entry.get("hits"), -1.0)
		var relics_given: float = _number(entry.get("relics"), -1.0)
		# hits > 0: sin cuadrilla el cofre paga por golpes, y no puede pagar nada.
		if weight < 0.0 or seconds < 0.0 or hits <= 0.0 or relics_given < 0.0:
			_fail("loot: la rareza '%s' necesita weight, seconds y relics >= 0 y hits > 0" % str(entry["name"]))
			return null
		total_weight += weight
		rarities.append({ "id": str(entry.get("id", "")), "name": str(entry["name"]), "weight": weight, "seconds": seconds, "hits": hits, "relics": int(relics_given) })
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
