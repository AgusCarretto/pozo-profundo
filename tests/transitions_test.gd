extends "res://tests/scene_fx_base.gd"
## Tests headless de las transiciones (F2-B): cambio de bioma (fundido del piso y la roca, cartel pasajero y
## música), la ventana de vuelta offline (contador que sube y lluvia de monedas) y la vuelta a la superficie
## (fundido a blanco y reliquias que vuelan al contador).


func _run_tests() -> void:
	await _test_biome_crossfade()
	await _test_biome_banner()
	await _test_no_banner_when_going_up()


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
