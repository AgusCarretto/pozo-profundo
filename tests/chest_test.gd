extends "res://tests/scene_fx_base.gd"
## Tests headless del cofre (F2-B): cae en la mina con un brillo del color de su rareza, sale un aviso con el
## bonus que suma (el del cofre y lo que de verdad sube el efectivo, que rinde cada vez menos) y el legendario
## tiene su momento: una pausa breve y un destello (sin destello con "reducir efectos").

const EconomyMath := preload("res://core/economy_math.gd")
const CHEST_TEXTURE: String = "tile_0089.png"


## El color de cada rareza es el de la escena (main.gd), no uno copiado acá.
func _rarity_color(id: String) -> Color:
	return (load("res://game/main.gd") as GDScript).get_script_constant_map()["RARITY_COLORS"][id]


func _balance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))


func _run_tests() -> void:
	await _test_chest_falls()
	await _test_toast()
	await _test_many_chests()
	await _test_legendary()
	await _test_legendary_reduced()


func _chests() -> Array[TextureRect]:
	var found: Array[TextureRect] = []
	for child: Node in _fx().get_children():
		if child is TextureRect and (child as TextureRect).texture != null and (child as TextureRect).texture.resource_path.ends_with(CHEST_TEXTURE) and not child.is_queued_for_deletion():
			found.append(child as TextureRect)
	return found


func _toasts() -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in _fx().get_children():
		if str(child.name).begins_with("ChestToast") and not child.is_queued_for_deletion():
			found.append(child as Control)
	return found


func _labels_text(control: Control) -> String:
	var texts: Array[String] = []
	for node: Node in control.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return " | ".join(texts)


func _screen_flash() -> ColorRect:
	var screen_fx: Node = _scene.get_node_or_null("ScreenFx")
	return screen_fx.get_node_or_null("Flash") as ColorRect if screen_fx != null else null


func _test_chest_falls() -> void:
	_section("El cofre cae en la mina")
	_economy.reset()
	await _wait(0.1)
	_check(_chests().is_empty(), "sin cofres, no hay nada")
	_economy.drop_loot(1) # Raro
	await process_frame
	var chests: Array[TextureRect] = _chests()
	_check_eq(chests.size(), 1, "un cofre aparece en la mina")
	if chests.is_empty():
		return
	var chest: TextureRect = chests[0]
	var rock_rect: Rect2 = _rock().get_rect()
	var start_y: float = chest.position.y
	_check(start_y + chest.size.y < rock_rect.position.y, "arranca arriba, sobre la roca")
	_check_eq(chest.mouse_filter, Control.MOUSE_FILTER_IGNORE, "no come toques")
	var glows: Array[Node] = chest.find_children("*", "TextureRect", true, false)
	_check(not glows.is_empty(), "tiene un brillo")
	if not glows.is_empty():
		var glow: TextureRect = glows[0] as TextureRect
		_check(glow.texture.resource_path.ends_with("circle_05.png") and (glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "suave, que suma luz")
		_check(Color(glow.modulate, 1.0).is_equal_approx(Color(_rarity_color("rare"), 1.0)), "del color de la rareza (azul para Raro) (%s)" % glow.modulate.to_html())
	var stars: Array[Node] = chest.find_children("*", "CPUParticles2D", true, false)
	_check(not stars.is_empty() and (stars[0] as CPUParticles2D).texture.resource_path.ends_with("star_06.png"), "y destellos de estrellas")
	if not stars.is_empty():
		_check(Color((stars[0] as CPUParticles2D).color, 1.0).is_equal_approx(Color(_rarity_color("rare"), 1.0)), "del mismo color")
	await _wait(0.7)
	_check(is_instance_valid(chest) and chest.position.y > start_y, "cae")
	if is_instance_valid(chest):
		var center: Vector2 = chest.get_rect().get_center()
		_check(absf(center.x - rock_rect.get_center().x) <= rock_rect.size.x * 0.25, "sobre la roca")
		_check(center.y >= rock_rect.position.y - chest.size.y and center.y <= rock_rect.position.y + rock_rect.size.y * 0.35, "y se apoya arriba de la roca")
	await _wait(2.5)
	_check(_chests().is_empty(), "al rato se va")


func _test_toast() -> void:
	_section("Aviso del cofre con el bonus real")
	_economy.reset()
	_economy.loot_bonus = 1.0 # ya hay +100% bruto: el próximo cofre rinde menos que lo que dice
	await _wait(0.1)
	_economy.drop_loot(1) # Raro, +4% bruto
	await process_frame
	var toasts: Array[Control] = _toasts()
	_check_eq(toasts.size(), 1, "sale un aviso")
	if toasts.is_empty():
		return
	var toast: Control = toasts[0]
	var cap: float = _economy.loot_bonus_cap()
	var gain: float = EconomyMath.loot_bonus_effective(1.04, cap) - EconomyMath.loot_bonus_effective(1.0, cap)
	var expected: String = "+4%% → +%s" % NumberFormat.format_percent(gain)
	var text: String = _labels_text(toast)
	_check(text.contains("Raro"), "dice la rareza (%s)" % text)
	_check(text.contains(expected), "y el bonus: lo del cofre → lo que de verdad sube (%s; esperado %s)" % [text, expected])
	_check(gain < 0.04, "(con bonus acumulado, sube menos que el 4%% del cofre: %.2f%%)" % (gain * 100.0))
	var title: Label = toast.find_children("*", "Label", true, false)[0] as Label
	_check(Color(title.get_theme_color("font_color"), 1.0).is_equal_approx(Color(_rarity_color("rare"), 1.0)), "con el color de la rareza")
	_check_eq(toast.mouse_filter, Control.MOUSE_FILTER_IGNORE, "no come toques")
	await _wait(0.5)
	var rect: Rect2 = toast.get_rect()
	_check(rect.position.x >= 0.0 and rect.end.x <= _mine().size.x and rect.position.y >= 0.0 and rect.end.y <= _rock().position.y + _rock().size.y * 0.5, "entra en la mina, arriba (%s)" % str(rect))
	var font: Font = title.get_theme_font("font")
	var cut: Array[String] = []
	for node: Node in toast.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x > label.size.x + 0.5:
			cut.append(label.text)
	_check(cut.is_empty(), "sin texto cortado (%s)" % str(cut))
	await _wait(3.0)
	_check(_toasts().is_empty(), "y se va solo")
	_economy.reset()


func _test_many_chests() -> void:
	_section("Muchos cofres seguidos")
	_economy.reset()
	await _wait(0.1)
	for index: int in range(6):
		_economy.drop_loot(index % 3)
	await process_frame
	var cap: int = int(_mine().get_script().get_script_constant_map().get("MAX_CHESTS", 0))
	_check(cap >= 2 and cap <= 4, "hay un tope de cofres a la vez (%d)" % cap)
	_check(_chests().size() <= cap, "6 cofres seguidos dejan como mucho %d en pantalla (%d)" % [cap, _chests().size()])
	_check_eq(_toasts().size(), 1, "y un solo aviso: el del último")
	_check(_labels_text(_toasts()[0]).contains(_economy.loot_table()[2]["name"]) if not _toasts().is_empty() else false, "que es el del último cofre")
	await _wait(3.5)
	_economy.reset()


func _test_legendary() -> void:
	_section("El legendario tiene su momento")
	_economy.reset()
	await _wait(0.1)
	_check(_scene.get_node_or_null("ScreenFx") != null, "hay una capa de efectos de pantalla")
	var screen_fx: Control = _scene.get_node_or_null("ScreenFx") as Control
	if screen_fx == null:
		return
	_check(screen_fx.get_index() < _scene.get_node("Modal").get_index(), "debajo del cartel modal")
	_check(screen_fx.get_index() > _scene.get_node("OptionsPanel").get_index(), "y encima de todo lo demás")
	_check_eq(screen_fx.mouse_filter, Control.MOUSE_FILTER_IGNORE, "y no come toques")
	_economy.drop_loot(0) # común: nada especial
	await process_frame
	_check_eq(Engine.time_scale, 1.0, "un cofre común no pausa nada")
	_check(_screen_flash() == null or _screen_flash().color.a == 0.0, "ni destella")
	await _wait(0.3)
	_economy.drop_loot(3) # legendario
	await process_frame
	_check(Engine.time_scale < 0.5, "el legendario congela la escena un momento (escala de tiempo %.2f)" % Engine.time_scale)
	var flash: ColorRect = _screen_flash()
	_check(flash != null and flash.color.a > 0.3, "y destella")
	_check(flash != null and flash.get_rect().size.is_equal_approx(screen_fx.size), "en toda la pantalla")
	var start: int = Time.get_ticks_msec()
	while Engine.time_scale < 1.0 and Time.get_ticks_msec() - start < 3000:
		await process_frame
	var paused_ms: int = Time.get_ticks_msec() - start
	_check(paused_ms >= 150 and paused_ms <= 900, "la pausa es breve (%d ms)" % paused_ms)
	await _wait(0.8)
	_check(flash == null or flash.color.a == 0.0, "y el destello se apaga")
	await _wait(2.5)
	_economy.reset()


func _test_legendary_reduced() -> void:
	_section("Legendario con reducir efectos")
	_settings.reduce_effects = true
	await process_frame
	_economy.drop_loot(3)
	var bright: bool = false
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 900:
		await process_frame
		if _screen_flash() != null and _screen_flash().color.a > 0.0:
			bright = true
	_check(not bright, "sin destello")
	_check_eq(_chests().size(), 1, "pero el cofre cae igual")
	_settings.reduce_effects = false
	await _wait(2.5)
	_economy.reset()
