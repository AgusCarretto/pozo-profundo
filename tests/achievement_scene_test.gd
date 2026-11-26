extends "res://tests/test_base.gd"
## Logros en la escena principal (balance real): aviso agrupado que no tapa lo que se toca, librito de logros usable
## con el dedo, secretos ocultos, contadores que vienen de la interfaz y atajos de debug.

const MAIN_SCENE: String = "res://game/main.tscn"
const TOUCH_MIN: float = 96.0

var _economy: Node
var _scene: Control


func _initialize() -> void:
	_economy = root.get_node_or_null("Economy")
	var save: Node = root.get_node_or_null("Save")
	if save != null:
		save.persistence_enabled = false
	await process_frame
	_check(_economy.load_balance_file("res://data/balance.json"), "carga el balance real (%s)" % _economy.last_error)
	_check(_economy.has_achievements(), "con logros")
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	await _mount(packed)
	await _test_grouped_notice()
	await _test_book()
	await _test_book_scrolls_with_a_finger()
	await _test_counters_from_the_interface()
	await _test_debug_panel()
	await _unmount()
	await _test_conversion_shows_card_then_notice(packed)
	for phone: Vector2 in [Vector2(720, 1280), Vector2(720, 1599)]:
		await _test_sizes(packed, phone)
	_economy.reset()
	_finish()


func _mount(packed: PackedScene) -> void:
	_economy.reset()
	_scene = packed.instantiate() as Control
	root.add_child(_scene)
	await _frames(3)


func _unmount() -> void:
	_scene.queue_free()
	await process_frame


func _frames(count: int = 2) -> void:
	for i: int in range(count):
		await process_frame


func _find(node_name: String) -> Node:
	return _scene.find_child(node_name, true, false)


func _toast() -> Button:
	return _find("AchievementToast") as Button


func _book() -> Control:
	return _find("AchievementBook") as Control


func _texts(node: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for child: Node in node.find_children("*", "Label", true, false):
		if (child as Label).visible:
			parts.append((child as Label).text)
	return " | ".join(parts)


func _row(id: String) -> Control:
	return _book().find_child("Row_" + id, true, false) as Control


func _open_book() -> void:
	(_scene.get_node("%RelicsButton") as Button).pressed.emit()
	await _frames()
	(_find("AchievementsButton") as Button).pressed.emit()
	await _frames()


func _touch(at: Vector2, down: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = root.get_final_transform() * at
	touch.pressed = down
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await process_frame


func _test_grouped_notice() -> void:
	_section("Aviso agrupado")
	_check(not _toast().visible, "sin logros no hay aviso")
	_economy.achievements.add("hits", 1000.0)
	_economy.achievements.add("crits", 100.0)
	_economy.check_achievements()
	await _frames()
	var toast: Button = _toast()
	_check(toast.visible, "sale el aviso")
	_check(toast.text.contains("3 logros") and toast.text.contains("+6 fragmentos"), "uno solo, con los tres (%s)" % toast.text.replace("\n", " "))
	_check(_economy.pending_achievements.is_empty(), "y queda visto")
	var hud: Control = _scene.get_node("%HudPanel") as Control
	_check(hud.get_global_rect().encloses(toast.get_global_rect()), "va sobre la barra de arriba: no tapa la roca ni las tarjetas")
	var sound: Control = _scene.get_node("%SoundButton") as Control
	_check(not toast.get_global_rect().intersects(sound.get_global_rect()), "ni los botones de arriba")
	_check(toast.size.y >= TOUCH_MIN - 0.5, "se puede tocar (%d px)" % int(toast.size.y))
	_economy.unlock_achievement("gear_opens_50")
	await _frames()
	_check(_toast().text.contains("4 logros"), "otro que llega mientras está se suma (%s)" % _toast().text.replace("\n", " "))
	_toast().pressed.emit()
	await _frames()
	_check(_book().visible and not _toast().visible, "tocarlo abre el librito")
	_book().call("close")
	_economy.unlock_achievement("loot_views_25")
	await _frames()
	_check(_toast().text.contains("Curioso"), "uno solo se nombra (%s)" % _toast().text.replace("\n", " "))
	_toast().call("dismiss")


func _test_book() -> void:
	_section("Librito de logros")
	_economy.reset()
	_economy.achievements.add("hits", 342.0)
	_economy.achievements.set_max("frenzy_best", 42.0)
	_economy.check_achievements()
	await _open_book()
	_check(_book().visible, "se abre desde Reliquias")
	_check(not (_scene.get_node("%RelicsPanel") as Control).visible, "y cierra ese cartel")
	var rows: int = _book().find_children("Row_*", "", true, false).size()
	_check_eq(rows, 70, "están los 70")
	var all: String = _texts(_book())
	for category: String in ["Golpes", "Profundidad", "Cofres", "Cuadrilla", "Resets", "Frenesí y dinamita", "Árbol", "Secretos"]:
		_check(all.contains(category), "categoría %s" % category)
	_check(all.contains("1 de 70"), "cuántos llevás (%s)" % all.left(80))
	_check(all.contains("2 fragmentos"), "y los fragmentos")
	_check(_texts(_row("hits_1000")).contains("342 / 1.000 golpes"), "progreso (%s)" % _texts(_row("hits_1000")))
	_check(_texts(_row("hits_100")).contains("Conseguido"), "el que ya está (%s)" % _texts(_row("hits_100")))
	_check(_texts(_row("frenzy_best_60")).contains("0:42 / 1:00"), "los de tiempo en minutos (%s)" % _texts(_row("frenzy_best_60")))
	var secret: String = _texts(_row("gear_opens_50"))
	_check(secret.contains("???") and not secret.contains("engranaje") and not secret.contains("¿Se rompió?"), "un secreto no se cuenta (%s)" % secret)
	_economy.unlock_achievement("gear_opens_50")
	_book().call("refresh")
	_check(_texts(_row("gear_opens_50")).contains("¿Se rompió?"), "hasta conseguirlo")
	(_find("CloseBook") as Button).pressed.emit()
	await _frames()
	_check(not _book().visible, "se cierra")


func _test_book_scrolls_with_a_finger() -> void:
	_section("Se desliza con el dedo")
	# Como en un celular: ScrollContainer solo desliza con el dedo si hay pantalla táctil (en headless no hay).
	Input.set_emulate_touch_from_mouse(true)
	await _open_book()
	var scroll: ScrollContainer = _find("BookScroll") as ScrollContainer
	var from: Vector2 = scroll.get_global_rect().get_center() + Vector2(0, 150)
	var before: int = scroll.scroll_vertical
	await _touch(from, true)
	var last: Vector2 = from
	for step: int in range(1, 9):
		var next: Vector2 = from + Vector2(0, -300) * step / 8.0
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.position = root.get_final_transform() * next
		drag.relative = root.get_final_transform().basis_xform(next - last)
		Input.parse_input_event(drag)
		Input.flush_buffered_events()
		last = next
		await process_frame
	await _touch(last, false)
	await _frames()
	_check(scroll.scroll_vertical > before + 100, "baja (%d » %d)" % [before, scroll.scroll_vertical])
	_book().call("close")
	Input.set_emulate_touch_from_mouse(false)


func _test_counters_from_the_interface() -> void:
	_section("Contadores que vienen de la interfaz")
	_economy.reset()
	await _frames()
	(_scene.get_node("%LootButton") as Button).pressed.emit()
	_check_eq(_economy.stat("loot_views"), 1.0, "mirar la tabla de Botín")
	(_scene.get_node("%LootPanel") as Control).call("close")
	(_scene.get_node("%OptionsButton") as Button).pressed.emit()
	_check_eq(_economy.stat("gear_opens"), 1.0, "tocar el engranaje")
	var options: Control = _find("OptionsPanel") as Control
	var credits: Control = options.get("credits_panel")
	(options.get("credits_button") as Button).pressed.emit()
	await _frames()
	_check_eq(_economy.stat("credits_end"), 0.0, "abrir los créditos no alcanza")
	var scroll: ScrollContainer = credits.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	scroll.scroll_vertical = 100000
	await _frames()
	_check(_economy.stat("credits_end") > 0.0, "llegar al final sí")
	options.call("close")
	var sound: Button = _scene.get_node("%SoundButton") as Button
	var settings: Node = root.get_node("Settings")
	var muted_before: bool = settings.muted
	settings.muted = false
	sound.pressed.emit()
	_check_eq(_economy.stat("mute_cycles"), 0.0, "silenciar solo no cuenta")
	sound.pressed.emit()
	_check_eq(_economy.stat("mute_cycles"), 1.0, "silenciar y reactivar, una vez")
	settings.muted = muted_before


func _test_debug_panel() -> void:
	_section("Menú de debug: logros")
	_economy.reset()
	await _frames()
	var debug: Control = _scene.get_node("DebugPanel") as Control
	(debug.get("toggle_button") as Button).pressed.emit()
	await _frames()
	(debug.find_child("DebugTabAchievements", true, false) as Button).pressed.emit()
	await _frames()
	(debug.find_child("DebugUnlock", true, false) as Button).pressed.emit()
	_check_eq(_economy.achievements.unlocked_count(), 1, "desbloquear el siguiente")
	(debug.find_child("DebugHits", true, false) as Button).pressed.emit()
	_check_eq(_economy.stat("hits"), 1000.0, "+1.000 golpes")
	for pair: Array in [["DebugCrits", "crits", 100.0], ["DebugChests", "chests", 100.0], ["DebugLegendaries", "chest_legendary", 10.0], ["DebugDynamite", "dynamite", 100.0], ["DebugPlayTime", "play_seconds", 3600.0]]:
		(debug.find_child(pair[0], true, false) as Button).pressed.emit()
		# El tiempo jugado sigue corriendo mientras se mira: se compara sin decimales.
		_check_eq(floorf(_economy.stat(pair[1])), pair[2], "suma %s" % pair[1])
	(debug.find_child("DebugResets", true, false) as Button).pressed.emit()
	_check_eq(_economy.resets, 5, "+5 vueltas")
	var small: Array[String] = []
	for node: Node in debug.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.is_visible_in_tree() and (button.size.y < TOUCH_MIN - 0.5 or button.size.x < TOUCH_MIN - 0.5):
			small.append("%s (%dx%d)" % [button.name, int(button.size.x), int(button.size.y)])
	_check(small.is_empty(), "todo mide 96 o más (%s)" % str(small))
	var body: Control = debug.get("body") as Control
	_check(body.get_global_rect().end.y <= root.get_visible_rect().size.y + 0.5, "el panel entra en la pantalla")
	(debug.find_child("DebugTabGame", true, false) as Button).pressed.emit()
	await _frames()
	_check((debug.find_child("DebugRelics", true, false) as Button).is_visible_in_tree(), "se vuelve a la pestaña de partida")
	(debug.get("toggle_button") as Button).pressed.emit()


func _test_conversion_shows_card_then_notice(packed: PackedScene) -> void:
	_section("Quien venía jugando: primero el cartel, después un solo aviso")
	_economy.reset()
	_economy.from_dict({ "balance_version": 2, "relics": 8, "gold": 10.0, "run_gold": 3.0e7, "owned": [60, 30, 26, 0, 0, 0], "max_biome": 3 })
	_scene = packed.instantiate() as Control
	root.add_child(_scene)
	await create_timer(0.8).timeout
	var modal: Control = _find("Modal") as Control
	_check(modal.visible, "primero el cartel del árbol")
	_check(not _toast().visible, "el aviso de logros espera")
	(modal.get("confirm_button") as Button).pressed.emit()
	await _frames(4)
	if modal.visible:
		(modal.get("confirm_button") as Button).pressed.emit()
		await _frames(4)
	_check(_toast().visible and _toast().text.contains("logros nuevos"), "y ahora todos juntos (%s)" % _toast().text.replace("\n", " "))
	await _unmount()


func _test_sizes(packed: PackedScene, phone: Vector2) -> void:
	var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
	_section("Librito en %s" % label)
	_economy.reset()
	var host: Control = Control.new()
	host.size = phone
	root.add_child(host)
	_scene = packed.instantiate() as Control
	host.add_child(_scene)
	await _frames()
	await _open_book()
	var small: Array[String] = []
	for node: Node in _book().find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.is_visible_in_tree() and (button.size.x < TOUCH_MIN - 0.5 or button.size.y < TOUCH_MIN - 0.5):
			small.append(button.name)
	_check(small.is_empty(), "[%s] los botones miden 96 o más (%s)" % [label, str(small)])
	var wide: Array[String] = []
	for node: Node in _book().find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree() and not control is ScrollBar and (control.get_global_rect().position.x < -0.5 or control.get_global_rect().end.x > phone.x + 0.5):
			wide.append(str(control.name))
	_check(wide.is_empty(), "[%s] nada se sale a los costados (%s)" % [label, str(wide.slice(0, 5))])
	host.queue_free()
	await process_frame
