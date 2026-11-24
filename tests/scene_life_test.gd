extends "res://tests/scene_fx_base.gd"
## Tests headless de la escena viva (F2-B): botones que rebotan, cuadrilla que aparece animada, mineros que pican
## en loop, dinamita que explota en el borde de la roca y runas que orbitan. Miden estado, no cómo se ve.
## Los helpers y el armado de la escena están en scene_fx_base.gd.


func _run_tests() -> void:
	await _test_buttons_bounce()
	await _test_crew_pops_in()
	await _test_miners_swing()
	await _test_dynamite()


func _test_buttons_bounce() -> void:
	_section("Los botones rebotan")
	_economy.reset()
	_economy.gold = 1.0e6
	await _wait(0.1)
	var buy: Button = _scene.get_node("%GeneratorList").get_child(0).find_children("*", "Button", true, false)[0] as Button
	buy.pressed.emit()
	await _check_bounce(buy, "comprar")
	var pick: Button = _scene.get_node("%PickRow").find_children("*", "Button", true, false)[0] as Button
	pick.pressed.emit()
	await _check_bounce(pick, "mejorar el pico")
	var tab: Button = _scene.get_node("%TabLootButton") as Button
	tab.button_pressed = true
	await _check_bounce(tab, "una pestaña")
	(_scene.get_node("%TabCrewButton") as Button).button_pressed = true
	await _wait(0.4)
	var mode: Button = _scene.get_node("%Mode10Button") as Button
	mode.button_pressed = true
	await _check_bounce(mode, "el modo ×10")
	(_scene.get_node("%Mode1Button") as Button).button_pressed = true
	await _wait(0.4)
	var sound: Button = _scene.get_node("%SoundButton") as Button
	sound.pressed.emit()
	await _check_bounce(sound, "el silencio")
	sound.pressed.emit()
	await _wait(0.4)
	_economy.reset()
	await _wait(0.1)


func _test_crew_pops_in() -> void:
	_section("La cuadrilla nueva aparece animada")
	var mine: Control = _mine()
	var miners: Array = mine.get("miner_sprites")
	var first: Control = miners[0]
	_check(first.scale.is_equal_approx(Vector2.ONE), "al abrir el juego, la cuadrilla que ya había no aparece animada")
	_economy.reset()
	_economy.gold = 1000.0
	await _wait(0.1)
	var buy: Button = _scene.get_node("%GeneratorList").get_child(0).find_children("*", "Button", true, false)[0] as Button
	buy.pressed.emit()
	# main.gd refresca la mina en su _process, que corre después de process_frame: dos frames.
	await process_frame
	await process_frame
	_check(first.visible, "comprar un minero lo muestra en la mina")
	_check(first.scale.x < 1.0, "y aparece de a poco, creciendo (%s)" % str(first.scale))
	_check(first.pivot_offset.is_equal_approx(first.size * Vector2(0.5, 1.0)), "desde los pies")
	await _wait(0.6)
	_check(first.scale.is_equal_approx(Vector2.ONE), "hasta su tamaño")
	var drill: Control = mine.get("drill_sprite")
	_economy.gold = 1000.0
	var buy_drill: Button = _scene.get_node("%GeneratorList").get_child(1).find_children("*", "Button", true, false)[0] as Button
	buy_drill.pressed.emit()
	await process_frame
	await process_frame
	_check(drill.visible and drill.scale.x < 1.0, "el taladro también aparece animado")
	await _wait(0.6)
	# Una escena nueva con cuadrilla (una partida cargada) la muestra quieta.
	_scene.get_parent().queue_free()
	await process_frame
	await _mount()
	var reloaded: Array = _mine().get("miner_sprites")
	_check((reloaded[0] as Control).visible and (reloaded[0] as Control).scale.is_equal_approx(Vector2.ONE), "una partida cargada muestra la cuadrilla quieta, sin animar")
	_economy.reset()
	await _wait(0.1)


func _test_miners_swing() -> void:
	_section("Los mineros pican en loop, cada uno a su ritmo")
	var mine: Control = _mine()
	var script_constants: Dictionary = mine.get_script().get_script_constant_map()
	var swing: Callable = Callable(mine, "pick_angle")
	_check_near(float(swing.call(0.0)), 0.0, "el golpe arranca con el pico quieto", 1e-6)
	var lowest: float = 0.0
	var lowest_at: float = 0.0
	for step: int in range(100):
		var angle: float = float(swing.call(step / 100.0))
		if angle < lowest:
			lowest = angle
			lowest_at = step / 100.0
	_check(lowest < deg_to_rad(-40.0), "levanta el pico hacia atrás (%d°)" % int(rad_to_deg(lowest)))
	_check(lowest_at >= 0.4 and lowest_at <= 0.75, "despacio (la mayor parte del ciclo: arriba al %d%%)" % int(lowest_at * 100.0))
	var strike: float = float(swing.call(minf(lowest_at + 0.12, 0.99)))
	_check(strike > 0.0, "y lo baja de golpe contra la roca (%d°)" % int(rad_to_deg(strike)))
	_check_near(float(swing.call(1.0)), 0.0, "y vuelve a quieto al terminar el ciclo", 1e-6)
	_check(script_constants.has("SWING_PERIOD") and float(script_constants["SWING_PERIOD"]) >= 0.6 and float(script_constants["SWING_PERIOD"]) <= 2.0, "un golpe cada 0,6 a 2 segundos")

	_economy.reset()
	_economy.owned[0] = 8
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.8)
	var miners: Array = mine.get("miner_sprites")
	var rock_center: Vector2 = _rock().get_rect().get_center()
	var picks: Array[Control] = []
	var facing_ok: bool = true
	for miner: Control in miners:
		var pick: Control = miner.get_node_or_null("Pick") as Control
		if pick == null:
			continue
		picks.append(pick)
		_check_eq(pick.mouse_filter, Control.MOUSE_FILTER_IGNORE, "el pico de %s no come toques" % miner.name)
		var miner_center: Vector2 = miner.get_rect().get_center()
		var pick_center: Vector2 = miner.position + (pick.position + pick.size * 0.5) * miner.scale
		var to_rock: Vector2 = rock_center - miner_center
		if absf(to_rock.x) > absf(to_rock.y) and signf(pick_center.x - miner_center.x) != signf(to_rock.x):
			facing_ok = false
	_check_eq(picks.size(), 8, "cada minero tiene su pico")
	_check(facing_ok, "y lo tiene del lado de la roca")
	if picks.is_empty():
		return
	var first: Array[float] = []
	for pick: Control in picks:
		first.append(pick.rotation)
	await _wait(0.25)
	var moved: int = 0
	var angles: Dictionary = {}
	for index: int in range(picks.size()):
		if not is_equal_approx(picks[index].rotation, first[index]):
			moved += 1
		angles[snappedf(picks[index].rotation, 0.05)] = true
	_check_eq(moved, picks.size(), "los picos se mueven solos")
	_check(angles.size() >= 4, "y no todos al mismo tiempo: están desfasados (%d ángulos distintos)" % angles.size())
	_economy.reset()
	await _wait(0.1)


func _test_dynamite() -> void:
	_section("Dinamita: explosiones en el borde de la roca")
	var mine: Control = _mine()
	var interval: Callable = Callable(mine, "dynamite_interval")
	_check(float(interval.call(0)) == INF, "sin cuadrillas de dinamita no explota nada")
	var one: float = float(interval.call(1))
	var five: float = float(interval.call(5))
	var many: float = float(interval.call(500))
	_check(one >= 2.0 and one <= 8.0, "con una, cada tanto (%.1f s)" % one)
	_check(five < one, "con más, más seguido (5: %.1f s)" % five)
	_check(many >= 0.5 and is_equal_approx(many, float(interval.call(5000))), "con un tope: nunca más de una cada %.1f s" % many)

	_economy.reset()
	_economy.owned[2] = 0
	_economy.gold_changed.emit(_economy.gold)
	var before: int = int(mine.get("explosions"))
	await _wait(1.0)
	_check_eq(int(mine.get("explosions")), before, "sin dinamita, ninguna explosión")

	var points: Array[Vector2] = []
	var record: Callable = func(at: Vector2) -> void: points.append(at)
	mine.connect("dynamite_exploded", record)
	_economy.owned[2] = 400
	_economy.gold_changed.emit(_economy.gold)
	var saw_stick: bool = false
	var saw_glow: bool = false
	# En headless los frames corren sin límite: se espera por tiempo real, no por cantidad de frames.
	var deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if _fx().find_children("*", "TextureRect", true, false).any(func(n: Node) -> bool: return (n as TextureRect).texture != null and (n as TextureRect).texture.resource_path.ends_with("dynamite.png")):
			saw_stick = true
		if not _glows().is_empty():
			saw_glow = true
		if points.size() >= 2:
			break
	await _wait(0.1)
	_check(points.size() >= 2, "con mucha dinamita explota seguido (%d)" % points.size())
	_check(saw_stick, "antes de explotar se ve el cartucho con la mecha")
	_check(saw_glow, "y explota con un destello")
	var rock_rect: Rect2 = _rock().get_rect()
	var on_edge: bool = true
	for point: Vector2 in points:
		var relative: Vector2 = (point - rock_rect.get_center()) / rock_rect.size
		if relative.length() < 0.3 or relative.length() > 0.62:
			on_edge = false
	_check(on_edge, "en el borde de la roca (%s)" % str(points))
	var glow_nodes: Array[Node] = _glows()
	if not glow_nodes.is_empty():
		var glow: TextureRect = glow_nodes[0] as TextureRect
		_check_eq(glow.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "el destello es suave (filtro lineal, no pixel art)")
		_check(glow.material is CanvasItemMaterial and (glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "y suma luz (mezcla aditiva)")
		_check_eq(glow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "y no come toques")

	# Que se apague el destello de la última explosión antes de mirar con reducir efectos.
	await _wait(0.6)
	_settings.reduce_effects = true
	await process_frame
	points.clear()
	var glow_with_reduce: bool = false
	deadline = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not _glows().is_empty():
			glow_with_reduce = true
		if points.size() >= 1:
			break
	_check(points.size() >= 1, "con reducir efectos sigue explotando")
	_check(not glow_with_reduce, "pero sin destello")
	_settings.reduce_effects = false
	mine.disconnect("dynamite_exploded", record)
	_economy.reset()
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.8)
