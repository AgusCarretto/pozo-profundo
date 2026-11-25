extends SceneTree
## Simula partidas con el Economy real y data/balance.json, para ver el ritmo antes de publicar un cambio de balance.
##
##   godot --headless --path . --script res://tools/simulate_economy.gd
##   (opcional: -- <partidas por ritmo>, por defecto 20)
##
## El jugador simulado golpea sin parar a un ritmo fijo y compra lo que antes se paga solo (contando la espera); si
## lo mejor tarda más de PATIENCE segundos en poder pagarse, compra mientras tanto otra cosa. Solo compra lo que ya
## está revelado. Es optimista: una persona hace pausas y compra peor, así que tarda algo más. No toca la partida
## guardada.

const EconomyScript := preload("res://core/economy.gd")
const EconomyMath := preload("res://core/economy_math.gd")
const NumberFormat := preload("res://core/number_format.gd")

const STEP: float = 0.25
const PATIENCE: float = 90.0
const MAX_SECONDS: float = 4.0 * 3600.0
const TAPS: Array[float] = [1.5, 3.0, 5.0]
## Se mira de comprar de a una o, si falta poco, de un salto hasta el próximo hito.
const MILESTONE_REACH: int = 12

var _balance: Dictionary
var _crit_average: float = 1.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = maxi(int(args[0]), 1) if not args.is_empty() else 20
	_balance = JSON.parse_string(FileAccess.get_file_as_string(EconomyScript.DEFAULT_BALANCE_PATH))
	var crit: Dictionary = _balance.get("crit", {})
	_crit_average = 1.0 + float(crit.get("chance", 0.0)) * (float(crit.get("multiplier", 1.0)) - 1.0)
	_first_descent(runs)
	_following_descents()
	_abyss()
	quit(0)


func _new_economy(seed_value: int) -> EconomyScript:
	var economy: EconomyScript = EconomyScript.new()
	if not economy.load_balance(_balance):
		push_error(economy.last_error)
		quit(1)
	economy.rng.seed = seed_value
	return economy


func _first_descent(runs: int) -> void:
	print("\nPrimera bajada hasta poder volver a la superficie (%d partidas por ritmo, medianas)" % runs)
	for taps: float in TAPS:
		var results: Array[Dictionary] = []
		for seed_value: int in range(1, runs + 1):
			var economy: EconomyScript = _new_economy(seed_value)
			results.append(_play(economy, taps, economy.prestige_min_depth()))
			economy.free()
		var times: Array = results.map(func(r: Dictionary) -> float: return r["time"])
		times.sort()
		print("  %.1f golpes/s: 100 m %s · 200 m %s · 300 m %s (p10 %s, p90 %s)" % [
			taps, _clock(_median(results, "100")), _clock(_median(results, "200")), _clock(_median(results, "time")),
			_clock(times[int(times.size() * 0.1)]), _clock(times[int(times.size() * 0.9)])])
		print("      oro: golpes %d%% · cuadrilla %d%% · cofres %d%% | compras %d, espera más larga %s | cofres %d, con legendario %d de %d" % [
			roundi(_median(results, "from_hits") * 100.0), roundi(_median(results, "from_crew") * 100.0), roundi(_median(results, "from_chests") * 100.0),
			int(_median(results, "purchases")), _clock(_median(results, "longest_wait")), int(_median(results, "chests")),
			results.filter(func(r: Dictionary) -> bool: return r["legendary"]).size(), results.size()])
		print("      %s" % results[0]["story"])


func _following_descents() -> void:
	var economy: EconomyScript = _new_economy(100)
	var line: PackedStringArray = PackedStringArray()
	var total: float = 0.0
	for number: int in range(1, 7):
		var result: Dictionary = _play(economy, 3.0, economy.prestige_min_depth())
		total += result["time"]
		economy.prestige()
		line.append("#%d %s → %d reliquias" % [number, _clock(result["time"]), economy.relics])
	economy.free()
	print("\nBajadas seguidas a 3 golpes/s: %s (en total %.1f h)" % [" · ".join(line), total / 3600.0])


func _abyss() -> void:
	var line: PackedStringArray = PackedStringArray()
	var target: float = 0.0
	for relics: int in [0, 4, 10]:
		var economy: EconomyScript = _new_economy(7)
		economy.relics = relics
		target = (economy.biome_count() - 1) * float(_balance["biomes"]["meters_each"])
		line.append("%d reliquias: %s" % [relics, _clock(_play(economy, 3.0, target)["time"])])
		economy.free()
	print("\nLlegar a %s (%d m) a 3 golpes/s: %s" % [str(_balance["biomes"]["list"][-1]["name"]), int(target), " · ".join(line)])


## Juega desde el estado actual de `economy` hasta `target` metros.
func _play(economy: EconomyScript, taps: float, target: float) -> Dictionary:
	var result: Dictionary = { "chests": 0, "legendary": false, "purchases": 0, "longest_wait": 0.0, "100": 0.0, "200": 0.0 }
	var from: Dictionary = { "hits": 0.0, "chests": 0.0 }
	var story: PackedStringArray = PackedStringArray()
	var clock: Array[float] = [0.0]
	var last_chest_amount: Array[float] = [0.0]
	var on_chest: Callable = func(rarity: int, amount: float) -> void:
		result["chests"] += 1
		from["chests"] += amount
		last_chest_amount[0] += amount
		if int(economy.loot_table()[rarity]["relics"]) > 0:
			result["legendary"] = true
	var on_milestone: Callable = func(index: int, threshold: int) -> void:
		story.append("%s ×%d %s" % [economy.generator_name(index), threshold, _clock(clock[0])])
	economy.loot_dropped.connect(on_chest)
	economy.milestone_reached.connect(on_milestone)
	var start_run_gold: float = economy.run_gold
	var pending_hits: float = 0.0
	var last_purchase: float = 0.0
	while clock[0] < MAX_SECONDS and economy.depth() < target:
		economy.tick(STEP)
		pending_hits += taps * STEP
		while pending_hits >= 1.0:
			last_chest_amount[0] = 0.0
			from["hits"] += economy.hit()
			pending_hits -= 1.0
		var bought: int = _shop(economy, taps, story, clock[0])
		if bought > 0:
			result["purchases"] += bought
			result["longest_wait"] = maxf(result["longest_wait"], clock[0] - last_purchase)
			last_purchase = clock[0]
		clock[0] += STEP
		for mark: int in [100, 200]:
			if result[str(mark)] == 0.0 and economy.depth() >= mark:
				result[str(mark)] = clock[0]
	economy.loot_dropped.disconnect(on_chest)
	economy.milestone_reached.disconnect(on_milestone)
	var earned: float = maxf(economy.run_gold - start_run_gold, 1.0)
	result["time"] = clock[0]
	result["from_hits"] = from["hits"] / earned
	result["from_chests"] = from["chests"] / earned
	result["from_crew"] = maxf(1.0 - result["from_hits"] - result["from_chests"], 0.0)
	result["story"] = " · ".join(story)
	return result


func _income(economy: EconomyScript, taps: float) -> float:
	return economy.gold_per_second() + taps * _crit_average * economy.hit_value()


## Compra todo lo que convenga ahora. Devuelve cuántas compras hizo.
func _shop(economy: EconomyScript, taps: float, story: PackedStringArray, time: float) -> int:
	var done: int = 0
	while done < 400:
		var best: Dictionary = _best_option(economy, taps)
		if best.is_empty() or best["cost"] > economy.gold:
			break
		if best["index"] < 0:
			economy.upgrade_pick()
		else:
			if economy.owned_count(best["index"]) == 0:
				story.append("%s %s" % [economy.generator_name(best["index"]), _clock(time)])
			for unit: int in range(best["count"]):
				economy.buy_generator(best["index"], EconomyScript.BuyMode.X1)
		done += 1
	return done


func _best_option(economy: EconomyScript, taps: float) -> Dictionary:
	var now: float = _income(economy, taps)
	var options: Array[Dictionary] = []
	for index: int in range(economy.generator_count()):
		if not economy.is_generator_revealed(index):
			continue
		var owned: int = economy.owned_count(index)
		var counts: Array[int] = [1]
		var next: int = economy.next_milestone(index)
		if next > 0 and next - owned > 1 and next - owned <= MILESTONE_REACH:
			counts.append(next - owned)
		for count: int in counts:
			var cost: float = EconomyMath.bulk_cost(float(_balance["generators"][index]["base_cost"]), float(_balance["cost_growth"]), owned, count)
			economy.owned[index] += count
			var gain: float = _income(economy, taps) - now
			economy.owned[index] -= count
			_add_option(options, index, count, cost, gain, now, economy.gold)
	var pick_cost: float = economy.pick_cost()
	economy.pick_level += 1
	var pick_gain: float = _income(economy, taps) - now
	economy.pick_level -= 1
	_add_option(options, -1, 1, pick_cost, pick_gain, now, economy.gold)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	for option: Dictionary in options:
		if option["wait"] <= PATIENCE:
			return option
	return options[0] if not options.is_empty() else {}


func _add_option(options: Array[Dictionary], index: int, count: int, cost: float, gain: float, income: float, gold: float) -> void:
	if gain <= 0.0:
		return
	var wait: float = maxf(cost - gold, 0.0) / income
	options.append({ "index": index, "count": count, "cost": cost, "wait": wait, "score": wait + cost / gain })


func _median(results: Array[Dictionary], key: String) -> float:
	var values: Array = results.map(func(r: Dictionary) -> float: return float(r[key]))
	values.sort()
	return values[values.size() / 2]


func _clock(seconds: float) -> String:
	var total: int = roundi(seconds)
	return "%d:%02d" % [total / 60, total % 60]
