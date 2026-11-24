extends "res://tests/scene_fx_base.gd"
## @lento (animaciones: corre con -All o -Slow, ver tools/run_tests.ps1)
## Tests headless de las transiciones (F2-B): cambio de bioma (fundido del piso y la roca, cartel pasajero y
## música), la ventana de vuelta offline (contador que sube y lluvia de monedas) y la vuelta a la superficie
## (fundido a blanco y reliquias que vuelan al contador).


func _run_tests() -> void:
	await _test_biome_crossfade()
	await _test_biome_banner()
	await _test_no_banner_when_going_up()
	await _test_offline_welcome()
	await _test_prestige_whiteout()
	await _test_prestige_reduced()


func _banners() -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in _fx().get_children():
		if str(child.name).begins_with("BiomeBanner") and not child.is_queued_for_deletion():
			found.append(child as Control)
	return found


func _labels_text(control: Control) -> String:
	var texts: Array[String] = []
	for node: Node in control.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return " | ".join(texts)


func _set_run_gold(run_gold: float) -> void:
	_economy.run_gold = run_gold
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	await process_frame


func _test_biome_crossfade() -> void:
	_section("Cambio de bioma: el piso y la roca se funden al nuevo")
	_economy.reset()
	await _set_run_gold(0.0)
	await _wait(0.2)
	var mine: Control = _mine()
	var rock: TextureRect = _rock() as TextureRect
	_check_eq(str(mine.get("biome_id")), "earth", "arranca en Tierra")
	_check_near(float(mine.get("biome_blend")), 1.0, "sin transición en curso", 1e-6)
	await _set_run_gold(700.0) # Roca
	_check_eq(str(mine.get("biome_id")), "rock", "al bajar a Roca la mina pasa a Roca")
	_check(rock.texture.resource_path.ends_with("rock_rock.png"), "la roca ya es la de Roca")
	var blend: float = float(mine.get("biome_blend"))
	_check(blend < 1.0, "pero se funde: el piso nuevo aparece de a poco (%.2f)" % blend)
	var old_rock: TextureRect = rock.get_node_or_null("OldRock") as TextureRect
	_check(old_rock != null and old_rock.texture.resource_path.ends_with("rock_earth.png"), "y la roca de Tierra se desvanece encima de la nueva")
	if old_rock != null:
		_check(old_rock.size.is_equal_approx(rock.size) and old_rock.position.is_zero_approx(), "tapándola justo")
		_check_eq(old_rock.mouse_filter, Control.MOUSE_FILTER_IGNORE, "sin comer toques")
		var alpha: float = old_rock.modulate.a
		await _wait(0.2)
		_check(is_instance_valid(old_rock) and old_rock.modulate.a < alpha, "cada vez más transparente")
	await _wait(1.0)
	_check_near(float(mine.get("biome_blend")), 1.0, "al rato el fundido termina", 1e-6)
	_check(rock.get_node_or_null("OldRock") == null, "y la roca vieja se va")


func _test_biome_banner() -> void:
	_section("Cambio de bioma: cartel pasajero")
	_economy.reset()
	await _set_run_gold(0.0)
	await _wait(2.5)
	_check(_banners().is_empty(), "en Tierra, sin cartel")
	await _set_run_gold(60000.0) # Cristal
	var banners: Array[Control] = _banners()
	_check_eq(banners.size(), 1, "al bajar a otro bioma sale un cartel")
	if banners.is_empty():
		return
	var banner: Control = banners[0]
	var text: String = _labels_text(banner)
	_check(text.contains("Cristal"), "con el nombre del bioma (%s)" % text)
	_check(text.contains("×%.2f" % _economy.biome_multiplier()), "y su multiplicador de oro (%s)" % text)
	_check_eq(banner.mouse_filter, Control.MOUSE_FILTER_IGNORE, "no come toques (se puede seguir golpeando)")
	_check(_scene.get_node("Modal").visible == false, "no es un cartel modal: el juego sigue")
	await _wait(0.4)
	var rect: Rect2 = banner.get_rect()
	_check(rect.position.x >= 0.0 and rect.end.x <= _mine().size.x and rect.position.y >= 0.0 and rect.end.y <= _mine().size.y, "entra en la mina (%s)" % str(rect))
	var cut: Array[String] = []
	for node: Node in banner.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x > label.size.x + 0.5:
			cut.append(label.text)
	_check(cut.is_empty(), "sin texto cortado (%s)" % str(cut))
	await _wait(2.5)
	_check(_banners().is_empty(), "y se va solo")


func _test_no_banner_when_going_up() -> void:
	_section("Volver a un bioma de arriba no es una novedad")
	_economy.reset()
	await _set_run_gold(5.0e6) # Magma
	await _wait(2.5)
	_check(_banners().is_empty(), "(el cartel de Magma ya se fue)")
	_economy.reset() # como al volver a la superficie
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	await process_frame
	_check_eq(str(_mine().get("biome_id")), "earth", "la mina vuelve a Tierra")
	_check(_banners().is_empty(), "sin cartel")
	# Abrir el juego en un bioma profundo tampoco muestra cartel.
	_scene.get_parent().queue_free()
	await process_frame
	_economy.run_gold = 60000.0
	await _mount()
	_check_eq(str(_mine().get("biome_id")), "crystal", "abrir el juego en Cristal muestra Cristal")
	_check(_banners().is_empty(), "sin cartel de bioma nuevo")
	_check_near(float(_mine().get("biome_blend")), 1.0, "y sin fundido", 1e-6)
	_economy.reset()


func _test_offline_welcome() -> void:
	_section("Vuelta offline: el contador sube y llueven monedas")
	var modal: Control = _scene.get_node("Modal") as Control
	var heard: Array[String] = []
	var record: Callable = func(id: String) -> void: heard.append(id)
	root.get_node("Audio").sfx_played.connect(record)
	_economy.reset()
	_economy.owned[0] = 10
	_economy.apply_offline(11520.0) # 3 h 12 min con 10 oro/s -> 115.200 de oro
	await process_frame
	_check(modal.visible, "aparece el aviso de vuelta")
	var counter: Label = modal.get("counter_label") as Label
	var coins: CPUParticles2D = modal.get("coins") as CPUParticles2D
	_check(counter != null and counter.visible, "con un contador de oro")
	_check(coins != null and coins.emitting and coins.texture.resource_path.ends_with("coin.png"), "y una lluvia de monedas")
	_check(heard.has("coins"), "que suena")
	if counter == null or coins == null:
		return
	_check(counter.text != "+115K", "el contador arranca de abajo (%s)" % counter.text)
	var panel: Control = modal.find_children("*", "PanelContainer", true, false)[0] as Control
	_check(coins.get_index() < panel.get_parent().get_index(), "caen detrás del cartel (se lee igual)")
	var seen: Dictionary = {}
	var deadline: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline:
		await process_frame
		seen[counter.text] = true
	_check(seen.size() >= 4, "va subiendo de a poco (%d valores)" % seen.size())
	_check_eq(counter.text, "+115K", "y termina en lo que juntó la cuadrilla")
	(modal.get("confirm_button") as Button).pressed.emit()
	await process_frame
	_check(not modal.visible, "se cierra con el botón")
	_check(not coins.emitting, "y dejan de caer monedas")
	modal.call("open", "Aviso", "Otro cartel", "Listo")
	await process_frame
	_check(not counter.visible and not coins.emitting, "otro cartel cualquiera no tiene contador ni monedas")
	modal.call("close")
	root.get_node("Audio").sfx_played.disconnect(record)
	_economy.reset()


func _flash() -> ColorRect:
	return _scene.get_node("ScreenFx/Flash") as ColorRect


func _flying_relics() -> Array[TextureRect]:
	var found: Array[TextureRect] = []
	for child: Node in _scene.get_node("ScreenFx").get_children():
		if str(child.name).begins_with("FlyingRelic") and not child.is_queued_for_deletion():
			found.append(child as TextureRect)
	return found


## Deja todo listo para volver a la superficie con 2 reliquias (300 m), en la pestaña Reliquias, y confirma.
func _start_prestige() -> void:
	_economy.reset()
	_economy.gold = 5000.0
	_economy.owned[0] = 3
	_economy.run_gold = 41000.0
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	(_scene.get_node("%TabRelicsButton") as Button).button_pressed = true
	await process_frame
	(_scene.get_node("%PrestigeButton") as Button).pressed.emit()
	var modal: Node = _scene.get_node("Modal")
	(modal.get("confirm_button") as Button).pressed.emit()


func _test_prestige_whiteout() -> void:
	_section("Volver a la superficie: fundido a blanco y reliquias que vuelan")
	var heard: Array[String] = []
	var record: Callable = func(id: String) -> void: heard.append(id)
	root.get_node("Audio").sfx_played.connect(record)
	await _start_prestige()
	var screen_fx: Control = _scene.get_node("ScreenFx") as Control
	_check_eq(_economy.relics, 0, "al confirmar todavía no pasó nada: primero se funde a blanco")
	_check_eq(screen_fx.mouse_filter, Control.MOUSE_FILTER_STOP, "mientras dura no se puede tocar nada")
	var alpha_at_reset: float = -1.0
	var relics_label: Label = _scene.get_node("%RelicsLabel") as Label
	var labels: Dictionary = {}
	var max_flying: int = 0
	var flying_textures: Dictionary = {}
	var deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if alpha_at_reset < 0.0 and _economy.relics == 2:
			alpha_at_reset = _flash().color.a
		labels[relics_label.text] = true
		var flying: Array[TextureRect] = _flying_relics()
		max_flying = maxi(max_flying, flying.size())
		for relic: TextureRect in flying:
			flying_textures[relic.texture.resource_path.get_file()] = true
		if alpha_at_reset >= 0.0 and flying.is_empty() and _flash().color.a == 0.0 and relics_label.text.contains("+50%"):
			break
	_check(alpha_at_reset >= 0.95, "la partida se reinicia con la pantalla blanca (no se ve el oro bajar a 0) (%.2f)" % alpha_at_reset)
	var flash_color: Color = _flash().color
	_check(flash_color.r > 0.9 and flash_color.g > 0.9 and flash_color.b > 0.9, "el fundido es a blanco")
	_check_eq(max_flying, 2, "las 2 reliquias vuelan")
	_check(flying_textures.keys().all(func(file: String) -> bool: return file.begins_with("rune_")), "con forma de runa (%s)" % str(flying_textures.keys()))
	_check(labels.has("Reliquias: 0") or labels.has("Reliquias: 1"), "el contador las va sumando al llegar (%s)" % str(labels.keys()))
	_check_eq(relics_label.text, "Reliquias: 2 · +50% de oro", "y termina en el total")
	_check(heard.count("relic") >= 2, "cada una suena al llegar (%d)" % heard.count("relic"))
	_check_eq(_flash().color.a, 0.0, "la pantalla vuelve a verse")
	_check_eq(screen_fx.mouse_filter, Control.MOUSE_FILTER_IGNORE, "y se puede tocar de nuevo")
	_check_eq(str(_mine().get("biome_id")), "earth", "de vuelta en Tierra")
	root.get_node("Audio").sfx_played.disconnect(record)
	(_scene.get_node("%TabCrewButton") as Button).button_pressed = true
	_economy.reset()
	# Que termine la transición (la cola de la última reliquia) antes de la próxima vuelta a la superficie.
	await _wait(1.0)


func _test_prestige_reduced() -> void:
	_section("Volver a la superficie con reducir efectos")
	_settings.reduce_effects = true
	await _start_prestige()
	var brightest: float = 0.0
	var deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var color: Color = _flash().color
		if color.a > 0.5:
			brightest = maxf(brightest, color.get_luminance())
		if _economy.relics == 2 and color.a == 0.0 and _flying_relics().is_empty():
			break
	_check(brightest > 0.0 and brightest < 0.4, "funde a oscuro en vez de a blanco (sin destello) (luminancia %.2f)" % brightest)
	_check_eq(_economy.relics, 2, "y vuelve a la superficie igual")
	_settings.reduce_effects = false
	(_scene.get_node("%TabCrewButton") as Button).button_pressed = true
	_economy.reset()
