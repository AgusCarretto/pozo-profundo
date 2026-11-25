extends "res://tests/scene_fx_base.gd"
## @lento (animaciones: corre con -All o -Slow, ver tools/run_tests.ps1)
## Tests headless de la escena viva (F2-B): botones que rebotan, cuadrilla que aparece animada, mineros que pican
## en loop, dinamita que explota en el borde de la roca y runas que orbitan. Miden estado, no cómo se ve.
## Los helpers y el armado de la escena están en scene_fx_base.gd.


func _run_tests() -> void:
	await _test_buttons_bounce()
	await _test_crew_pops_in()
	await _test_miners_swing()
	await _test_dynamite()
	await _test_orbit_runes()
	await _test_troops()


func _test_buttons_bounce() -> void:
	_section("Los botones rebotan")
	_economy.reset()
	_economy.gold = 1.0e6
	await _wait(0.1)
	var buy: Button = _scene.get_node("%Shop").get_child(1) as Button
	buy.pressed.emit()
	await _check_bounce(buy, "comprar")
	var pick: Button = _scene.get_node("%Shop").get_child(0) as Button
	pick.pressed.emit()
	await _check_bounce(pick, "mejorar el pico")
	var side: Button = _scene.get_node("%LootButton") as Button
	side.pressed.emit()
	await _check_bounce(side, "el botón de Botín")
	(_scene.get_node("%LootPanel") as Control).call("close")
	await _wait(0.4)
	var mode: Button = _scene.get_node("%ModeButton") as Button
	mode.pressed.emit()
	await _check_bounce(mode, "el modo de compra")
	mode.pressed.emit()
	mode.pressed.emit() # de vuelta en ×1
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
	var buy: Button = _scene.get_node("%Shop").get_child(1) as Button
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
	var buy_drill: Button = _scene.get_node("%Shop").get_child(2) as Button
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
	_section("Dinamita: dos dinamiteros la tiran a la roca")
	var mine: Control = _mine()
	var dynamiters: Array = mine.get("dynamiter_sprites")
	_economy.reset()
	await _wait(0.2)
	_check(dynamiters.size() == 2 and not (dynamiters[0] as Control).visible, "sin la habilidad no se ven")
	_economy.owned[1] = 1
	_economy.gold = 1.0e6
	_economy.upgrade_ability()
	await _wait(0.2)
	_check((dynamiters[0] as Control).visible and (dynamiters[1] as Control).visible, "al comprarla aparecen los dos")
	var points: Array[Vector2] = []
	var record: Callable = func(at: Vector2) -> void: points.append(at)
	mine.connect("dynamite_exploded", record)
	_economy.use_ability()
	await process_frame
	var sticks: Array = _fx().get_children().filter(func(n: Node) -> bool: return n.has_meta(&"stick"))
	_check_eq(sticks.size(), 2, "cada uno tira su cartucho")
	_check((dynamiters[0] as TextureRect).texture.resource_path.ends_with("dynamiter_throw.png"), "con la pose de tirar")
	await _wait(1.0)
	_check_eq(points.size(), 1, "una explosión (un solo estruendo)")
	if not points.is_empty():
		_check(_rock().get_rect().has_point(points[0]), "sobre la roca")
	_check((dynamiters[0] as TextureRect).texture.resource_path.ends_with("dynamiter_idle.png"), "y vuelven a su pose")
	mine.disconnect("dynamite_exploded", record)
	_economy.reset()
	await _wait(1.0)

func _file(sprite: TextureRect) -> String:
	return sprite.texture.resource_path.get_file()


func _test_troops() -> void:
	_section("Cada tropa se anima y cambia de aspecto con sus hitos")
	var mine: Control = _mine()
	_economy.reset()
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.2)
	var mole: TextureRect = mine.get("mole_sprite")
	var worm: TextureRect = mine.get("worm_sprite")
	var golem: TextureRect = mine.get("golem_sprite")
	var drill: TextureRect = mine.get("drill_sprite")
	_check(not mole.visible and not worm.visible, "sin comprarlos no se ven el topo ni el gusano")
	for index: int in range(6):
		_economy.owned[index] = 1
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.2)
	_check(mole.visible and worm.visible and golem.visible and drill.visible, "al comprarlos aparecen")
	var seen: Dictionary = {}
	var drill_positions: Dictionary = {}
	var mole_positions: Dictionary = {}
	var clock: SceneTreeTimer = create_timer(9.0)
	while clock.time_left > 0.0:
		await process_frame
		for sprite: TextureRect in [mole, worm, golem]:
			seen[_file(sprite)] = true
		drill_positions[drill.position] = true
		mole_positions[mole.position] = true
	for expected: String in ["golem.png", "golem_0_1.png", "golem_0_2.png", "mole_hole.png", "mole_0_1.png", "mole_0_2.png", "worm_0_0.png", "worm_0_1.png", "worm_0_2.png"]:
		_check(seen.has(expected), "se ve el cuadro %s" % expected)
	_check(drill_positions.size() > 2, "el taladro tiembla")
	_check(mole_positions.size() >= 2, "y el topo cambia de lugar")
	_check((_fx().get_node("Steam") as CPUParticles2D).emitting, "el taladro echa vapor")
	for index: int in range(6):
		_economy.owned[index] = 100
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.3)
	_check_eq(_file(drill), "drill_3.png", "a las 100 unidades el taladro es de gema")
	_check(_file(golem).begins_with("golem_3_") and _file(worm).begins_with("worm_3_"), "gólem y gusano de cristal (%s, %s)" % [_file(golem), _file(worm)])
	var miner: TextureRect = (mine.get("miner_sprites") as Array)[0]
	var helmet: TextureRect = miner.get_node("Helmet") as TextureRect
	_check(helmet.visible and _file(helmet) == "helmet_gold.png", "los mineros con casco dorado")
	_check_eq(_file(miner.get_node("Pick") as TextureRect), "pick_gem.png", "y pico de gema")
	_economy.reset()
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.3)
	_check(not helmet.visible and _file(drill) == "drill.png", "al empezar de nuevo vuelven al primer aspecto")


func _orbit_runes() -> Array[TextureRect]:
	var runes: Array[TextureRect] = []
	for child: Node in _fx().get_children():
		if child is TextureRect and str(child.name).begins_with("OrbitRune") and (child as TextureRect).visible:
			runes.append(child as TextureRect)
	return runes


func _test_orbit_runes() -> void:
	_section("Excavadoras rúnicas: runas que orbitan la roca")
	const BiomePalette := preload("res://game/biome_palette.gd")
	var mine: Control = _mine()
	_economy.reset()
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.1)
	_check_eq(_orbit_runes().size(), 0, "sin excavadoras no hay runas")
	_economy.owned[4] = 3
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.1)
	var runes: Array[TextureRect] = _orbit_runes()
	_check_eq(runes.size(), 3, "con 3 excavadoras orbitan 3 runas")
	if runes.size() != 3:
		return
	var atlas: AtlasTexture = runes[0].texture as AtlasTexture
	_check(atlas != null and atlas.atlas.resource_path.ends_with("runes_earth.png"), "son glifos de la hoja de runas de Tierra")
	_check_eq(runes[0].mouse_filter, Control.MOUSE_FILTER_IGNORE, "no comen toques")
	var rock_rect: Rect2 = _rock().get_rect()
	var first: Array[Vector2] = []
	var near: bool = true
	for rune: TextureRect in runes:
		var center: Vector2 = rune.position + rune.size * 0.5
		first.append(center)
		var relative: Vector2 = (center - rock_rect.get_center()) / rock_rect.size
		if relative.length() < 0.2 or relative.length() > 0.75:
			near = false
	_check(near, "giran pegadas a la roca (%s)" % str(first))
	_check(first[0].distance_to(first[1]) > rock_rect.size.x * 0.2 and first[1].distance_to(first[2]) > rock_rect.size.x * 0.2, "repartidas alrededor, no amontonadas")
	await _wait(0.4)
	var moved: int = 0
	for index: int in range(runes.size()):
		if (runes[index].position + runes[index].size * 0.5).distance_to(first[index]) > 2.0:
			moved += 1
	_check_eq(moved, 3, "y se mueven: orbitan")
	var glows: Array[Node] = runes[0].find_children("*", "TextureRect", true, false)
	_check(not glows.is_empty(), "cada runa tiene un aura")
	if not glows.is_empty():
		var glow: TextureRect = glows[0] as TextureRect
		_check(glow.texture.resource_path.ends_with("circle_05.png") and glow.material is CanvasItemMaterial and (glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "un brillo suave que suma luz")
		# Las excavadoras producen mucho: en la espera la mina puede haber bajado a Roca. Se compara con el bioma
		# que se está mostrando.
		var rune_color: Color = BiomePalette.of(str(mine.get("biome_id")))["rune"]
		_check(Color(glow.modulate, 1.0).is_equal_approx(Color(rune_color, 1.0)), "del color de las runas del bioma (%s, esperado %s)" % [glow.modulate.to_html(), rune_color.to_html()])
		mine.call("show_biome", "crystal")
		_check((runes[0].texture as AtlasTexture).atlas.resource_path.ends_with("runes_crystal.png"), "en Cristal las runas son las de Cristal")
		_check(Color(glow.modulate, 1.0).is_equal_approx(Color(BiomePalette.of("crystal")["rune"], 1.0)), "y el aura cambia de color")
		mine.call("show_biome", "earth")
	mine.call("clear_effects")
	await process_frame
	_check_eq(_orbit_runes().size(), 3, "limpiar los efectos no se lleva las runas (son parte de la escena)")
	_economy.owned[4] = 500
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.1)
	var cap: int = int(mine.get_script().get_script_constant_map().get("ORBIT_RUNES_MAX", 0))
	_check(cap >= 3 and cap <= 8, "hay un tope de runas (%d)" % cap)
	_check_eq(_orbit_runes().size(), cap, "con muchas excavadoras orbitan %d, no más" % cap)
	_economy.reset()
	_economy.gold_changed.emit(_economy.gold)
	await _wait(0.1)
