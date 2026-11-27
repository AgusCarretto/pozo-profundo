extends "res://tests/test_base.gd"
## La pantalla del árbol en la escena principal, con el balance real (árbol incluido): se abre desde Reliquias, se
## usa con el dedo (toque = elegir y comprar; arrastre = mover, sin comprar), todo lo que se toca mide 96 px o más,
## la meta de volver se ve y los avisos y el tope de golpes funcionan.

const MAIN_SCENE: String = "res://game/main.tscn"
const TOUCH_MIN: float = 96.0
const PHONE_SIZES: Array[Vector2] = [Vector2(720, 1280), Vector2(720, 1599)]

var _economy: Node
var _scene: Control
var _tree: Control


func _initialize() -> void:
	_economy = root.get_node_or_null("Economy")
	var save: Node = root.get_node_or_null("Save")
	if save != null:
		save.persistence_enabled = false
	await process_frame
	_check(_economy.load_balance_file("res://data/balance.json"), "carga el balance real (%s)" % _economy.last_error)
	_check(_economy.has_tree(), "con árbol")
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	await _test_open_and_sizes(packed)
	await _mount(packed)
	await _test_tap_selects_and_buys()
	await _test_drag_pans_without_buying()
	await _test_what_each_state_says()
	await _test_icons_and_badges()
	await _test_sky_and_effects()
	await _test_branches_are_told_apart()
	await _test_return_target_is_visible()
	await _test_tap_cap_in_the_game()
	await _test_debug_panel()
	await _test_buy_while_the_crew_works()
	await _unmount()
	await _test_testers_card(packed)
	_economy.reset()
	_finish()


func _mount(packed: PackedScene) -> void:
	_economy.reset()
	_scene = packed.instantiate() as Control
	root.add_child(_scene)
	await process_frame
	await process_frame
	_tree = _scene.find_child("TreeView", true, false) as Control


func _unmount() -> void:
	_scene.queue_free()
	await process_frame


func _frames(count: int = 2) -> void:
	for i: int in range(count):
		await process_frame


func _open_tree() -> void:
	(_scene.get_node("%RelicsButton") as Button).pressed.emit()
	await _frames()
	(_scene.find_child("TreeButton", true, false) as Button).pressed.emit()
	await _frames()


## Un toque o un arrastre de verdad por todo el camino de entrada (Godot emula el mouse a partir de ellos).
func _touch(at: Vector2, down: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = root.get_final_transform() * at
	touch.pressed = down
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await process_frame


func _tap(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	await _touch(at, true)
	await _touch(at, false)
	await _frames(1)


func _drag(from: Vector2, by: Vector2) -> void:
	await _touch(from, true)
	var last: Vector2 = from
	for step: int in range(1, 6):
		var next: Vector2 = from + by * step / 5.0
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.position = root.get_final_transform() * next
		drag.relative = root.get_final_transform().basis_xform(next - last)
		Input.parse_input_event(drag)
		Input.flush_buffered_events()
		last = next
		await process_frame
	await _touch(from + by, false)
	await _frames(1)


## Los textos de adentro de un botón armado como tarjeta.
func _text_of(button: Button) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node: Node in button.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return " ".join(parts)


func _test_open_and_sizes(packed: PackedScene) -> void:
	_section("Se abre desde Reliquias y todo lo que se toca mide 96 px o más")
	for phone: Vector2 in PHONE_SIZES:
		_economy.reset()
		var host: Control = Control.new()
		host.size = phone
		root.add_child(host)
		_scene = packed.instantiate() as Control
		host.add_child(_scene)
		await _frames()
		_tree = _scene.find_child("TreeView", true, false) as Control
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		_check(_tree != null and not _tree.visible, "[%s] el árbol arranca cerrado" % label)
		await _open_tree()
		_check(_tree.visible, "[%s] se abre" % label)
		_check(not (_scene.get_node("%RelicsPanel") as Control).visible, "[%s] y cierra el cartel de Reliquias" % label)
		_economy.resets = 1
		_economy.grant_relics(30)
		_economy.buy_star("core")
		await _frames()
		var small: Array[String] = []
		var buttons: int = 0
		for node: Node in _tree.find_children("*", "Button", true, false):
			var button: Button = node as Button
			if not button.is_visible_in_tree():
				continue
			buttons += 1
			if button.size.x < TOUCH_MIN - 0.5 or button.size.y < TOUCH_MIN - 0.5:
				small.append("%s (%dx%d)" % [button.name, int(button.size.x), int(button.size.y)])
		_check(buttons >= 8, "[%s] hay estrellas y botones a la vista (%d)" % [label, buttons])
		_check(small.is_empty(), "[%s] ninguno mide menos de 96 (%s)" % [label, str(small)])
		var cut: Array[String] = []
		for node: Node in _tree.find_children("*", "Label", true, false):
			var text: Label = node as Label
			if text.is_visible_in_tree() and text.autowrap_mode == TextServer.AUTOWRAP_OFF and text.get_global_rect().end.x > phone.x + 0.5:
				cut.append(text.text)
		_check(cut.is_empty(), "[%s] ningún texto se sale (%s)" % [label, str(cut)])
		var panel: Control = _tree.find_child("Detail", true, false) as Control
		_check(panel.get_global_rect().end.y <= phone.y + 0.5, "[%s] el panel de la estrella entra en la pantalla" % label)
		var core: Control = _tree.call("star_button", "core")
		_check((_tree.find_child("Viewport", true, false) as Control).get_global_rect().encloses(core.get_global_rect()), "[%s] al abrir se ve el Corazón entero" % label)
		(_tree.find_child("CloseTree", true, false) as Button).pressed.emit()
		await _frames()
		_check(not _tree.visible, "[%s] se cierra" % label)
		host.queue_free()
		await process_frame


func _test_tap_selects_and_buys() -> void:
	_section("Con el dedo: tocar elige y Comprar compra")
	_economy.resets = 1
	_economy.grant_relics(10)
	await _open_tree()
	await _tap(_tree.call("star_button", "core"))
	var name_label: Label = _tree.find_child("StarName", true, false) as Label
	var buy: Button = _tree.find_child("BuyButton", true, false) as Button
	_check_eq(name_label.text, "Corazón del pozo", "al tocarla se ve su nombre")
	_check(not buy.disabled and _text_of(buy).contains("1 reliquia"), "con su precio (%s)" % _text_of(buy))
	await _tap(buy)
	_check_eq(_economy.relic_tree.level("core"), 1, "un toque la compra una sola vez")
	_check_eq(_economy.available_relics(), 9, "y descuenta")
	_check(buy.disabled and _text_of(buy).contains("máximo"), "queda al máximo (%s)" % _text_of(buy))
	await _tap(_tree.call("star_button", "f_brazo"))
	_check_eq(name_label.text, "Brazo fuerte", "la vecina que apareció se puede tocar")
	await _tap(buy)
	await _tap(buy)
	_check_eq(_economy.relic_tree.level("f_brazo"), 2, "dos toques, dos niveles")


## Con la cuadrilla produciendo la pantalla se refresca todo el tiempo: un toque de verdad (que dura varios cuadros)
## igual tiene que comprar. Antes solo se podía recién vuelto a la superficie.
func _test_buy_while_the_crew_works() -> void:
	_section("Comprar en plena bajada, con la cuadrilla trabajando")
	_economy.reset()
	_economy.resets = 1
	_economy.grant_relics(400)
	_economy.open_rings()
	for id: String in ["core", "f_brazo", "f_templado", "f_eco", "f_combo", "f_umbral", "f_furia"]:
		while _economy.buy_star(id):
			pass
	_economy.owned[0] = 60
	_economy.run_gold = 1.0e12
	_economy.at_surface = false
	_check(_economy.gold_per_second() > 0.0 and _economy.can_prestige(), "(produciendo, y ya se puede volver)")
	await _frames()
	await _open_tree()
	_tree.call("select", "o_olfato")
	await _frames()
	var buy: Button = _tree.find_child("BuyButton", true, false) as Button
	await _slow_tap(buy)
	_check_eq(_economy.relic_tree.level("o_olfato"), 1, "el toque compra")
	await _slow_tap(buy)
	_check_eq(_economy.relic_tree.level("o_olfato"), 2, "y el siguiente también")
	_tree.call("select", "f_furia")
	await _frames()
	var keystone: Button = _tree.find_child("KeystoneButton", true, false) as Button
	await _slow_tap(keystone)
	_check_eq(_economy.keystone_pending("f_furia"), -1, "el botón de la piedra angular también responde")
	(_tree.find_child("CloseTree", true, false) as Button).pressed.emit()
	await _frames()


func _finger(index: int, at: Vector2, down: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = index
	touch.position = root.get_final_transform() * at
	touch.pressed = down
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await process_frame


## Un toque como el de un dedo: se apoya, pasan unos cuadros y se levanta.
func _slow_tap(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	await _touch(at, true)
	await _frames(6)
	await _touch(at, false)
	await _frames(1)


func _test_drag_pans_without_buying() -> void:
	_section("Arrastrar mueve el árbol sin comprar ni elegir")
	var canvas: Control = _tree.find_child("Canvas", true, false) as Control
	var star: Control = _tree.call("star_button", "o_olfato")
	var selected: String = _tree.get("selected")
	var level: int = _economy.relic_tree.level("o_olfato")
	var start: Vector2 = canvas.position
	await _drag(star.get_global_rect().get_center(), Vector2(-180, 60))
	_check(canvas.position.distance_to(start) > 100.0, "el árbol se movió (%s)" % str(canvas.position - start))
	_check_eq(_tree.get("selected"), selected, "sin cambiar la elegida")
	_check_eq(_economy.relic_tree.level("o_olfato"), level, "ni comprar")
	var view: Control = _tree.find_child("Viewport", true, false) as Control
	for i: int in range(6):
		await _drag(view.get_global_rect().get_center(), Vector2(-600, -600))
	var visible_stars: int = 0
	for id: String in _economy.relic_tree.ids():
		var button: Control = _tree.call("star_button", id)
		if view.get_global_rect().intersects(button.get_global_rect()):
			visible_stars += 1
	_check(visible_stars > 0, "no se puede arrastrar hasta perder el árbol de vista")
	await _tap(_tree.find_child("CenterTree", true, false) as Button)
	_check(canvas.position.distance_to(start) < 1.0, "Centrar vuelve al Corazón")
	await _tap(_tree.call("star_button", "o_olfato"))
	_check_eq(_tree.get("selected"), "o_olfato", "y después de arrastrar, un toque vuelve a elegir")


func _test_what_each_state_says() -> void:
	_section("Lo que dice cada estrella según cómo esté")
	var name_label: Label = _tree.find_child("StarName", true, false) as Label
	var info: Label = _tree.find_child("StarText", true, false) as Label
	var buy: Button = _tree.find_child("BuyButton", true, false) as Button
	var keystone: Button = _tree.find_child("KeystoneButton", true, false) as Button
	_tree.call("select", "f_umbral")
	_check_eq(name_label.text, "???", "oculta: sin nombre")
	_check(not buy.visible, "ni botón de comprar")
	_economy.grant_relics(40)
	_economy.buy_star("f_ojo")
	_tree.call("select", "f_brutal")
	_check(info.text.contains("350 m") and info.text.contains("8"), "sellada: dice qué pide el anillo (%s)" % info.text)
	_economy.grant_relics(5000)
	_economy.open_rings()
	for id: String in ["f_brazo", "f_templado", "f_eco", "f_combo", "f_umbral", "f_furia"]:
		while _economy.buy_star(id):
			pass
	_tree.call("select", "f_furia")
	await _frames()
	_check(keystone.visible and not keystone.disabled, "piedra angular comprada: se puede prender y apagar")
	var pending: Control = _part("f_furia", "Pending")
	await _tap(keystone)
	_check(not _economy.relic_tree.active_keystones.has("f_furia"), "en la superficie el toque la apaga ya")
	_check(not pending.visible, "sin nada pendiente")
	_check(keystone.size.y >= TOUCH_MIN - 0.5, "y su botón mide 96 o más")
	_economy.hit()
	_tree.call("select", "f_furia")
	await _tap(keystone)
	_check(not _economy.relic_tree.active_keystones.has("f_furia"), "ya empezada la bajada no cambia todavía")
	_check(pending.visible and str(pending.get("text")).replace("\n", " ") == "Activa desde la próxima bajada", "la estrella lo dice (%s)" % str(pending.get("text")))
	_check(info.text.contains("Activa desde la próxima bajada"), "y el panel también (%s)" % info.text)
	await _tap(keystone)
	_check_eq(_economy.keystone_pending("f_furia"), 0, "otro toque cancela el cambio")
	_check(not pending.visible, "y se va el aviso")
	_economy.relic_tree.set_keystone("f_furia", true)
	_tree.call("select", "f_furia")
	await _tap(keystone)
	_check(_economy.relic_tree.active_keystones.has("f_furia"), "una activa tampoco cambia a mitad de bajada")
	_check(str(pending.get("text")).replace("\n", " ") == "Se apaga en la próxima bajada", "y avisa que se apaga (%s)" % str(pending.get("text")))
	var over: Array[String] = []
	var balloon: Rect2 = pending.get_global_rect()
	for id: String in _economy.relic_tree.ids():
		var star: Control = _tree.call("star_button", id)
		if id != "f_furia" and star.get_global_rect().intersects(balloon):
			over.append(id)
	_check(over.is_empty(), "el aviso no tapa otra estrella (%s)" % str(over))
	var view: Control = _tree.find_child("Viewport", true, false) as Control
	for i: int in range(6):
		await _drag(view.get_global_rect().get_center(), Vector2(0, 500))
	_check(view.get_global_rect().encloses(pending.get_global_rect()), "y se puede traer a la vista aunque sea la estrella de más arriba (%s en %s)" % [str(pending.get_global_rect()), str(view.get_global_rect())])
	await _tap(_tree.find_child("CenterTree", true, false) as Button)
	(_tree.find_child("CloseTree", true, false) as Button).pressed.emit()
	await _frames()


func _test_sky_and_effects() -> void:
	_section("Cielo, destello al comprar, anillo nuevo y música")
	_economy.reset()
	_economy.resets = 1
	_economy.grant_relics(40)
	await _frames()
	var played: Array = []
	var listen: Callable = func(id: String) -> void: played.append(id)
	var audio: Node = root.get_node("Audio")
	var settings: Node = root.get_node("Settings")
	var muted: bool = settings.muted
	settings.muted = false
	audio.sfx_played.connect(listen)
	await _open_tree()
	_check(_tree.find_child("StarSky", true, false) != null, "hay un cielo de fondo")
	var director: Node = _scene.get_node("MusicDirector")
	_check_eq(director.call("wanted"), "tree", "y su música")
	var center: Button = _tree.find_child("CenterTree", true, false) as Button
	_check(center.icon != null and center.icon.resource_path.ends_with("target.png"), "Centrar lleva la mira")
	var banner: Label = _tree.find_child("RingBanner", true, false) as Label
	_check(not banner.visible, "sin anillo nuevo no hay cartel")
	await _tap(_tree.call("star_button", "core"))
	await _tap(_tree.find_child("BuyButton", true, false) as Button)
	var bursts: Array[Node] = _tree.find_children("Burst*", "CPUParticles2D", true, false)
	_check(not bursts.is_empty(), "al comprar salta un destello")
	_check(played.has("star_buy"), "con su sonido (%s)" % str(played))
	await _frames()
	_check(banner.visible and banner.text == "¡Nueva zona del cielo!", "el Corazón abre el anillo 1 y se avisa")
	_check(played.has("ring_open"), "con sonido")
	(_tree.find_child("CloseTree", true, false) as Button).pressed.emit()
	await _frames()
	_check(director.call("wanted") != "tree", "al cerrarlo vuelve la música de la mina")
	await _open_tree()
	_check(not banner.visible, "el aviso no se repite al reabrir")
	(_tree.find_child("CloseTree", true, false) as Button).pressed.emit()
	var tree_button: Button = _scene.find_child("TreeButton", true, false) as Button
	var book_button: Button = _scene.find_child("AchievementsButton", true, false) as Button
	_check(tree_button.icon != null and book_button.icon != null, "los botones de Reliquias llevan ícono")
	audio.sfx_played.disconnect(listen)
	settings.muted = muted
	await _frames()


func _part(id: String, node_name: String) -> Control:
	return (_tree.call("star_button", id) as Control).find_child(node_name, true, false) as Control


func _test_icons_and_badges() -> void:
	_section("Íconos y globitos de nivel")
	_economy.reset()
	_economy.resets = 1
	_economy.grant_relics(20)
	await _frames()
	await _open_tree()
	var icon: TextureRect = _part("core", "Icon") as TextureRect
	_check(icon.visible and icon.texture.resource_path.ends_with("stars/core.png"), "el Corazón disponible muestra su ícono")
	_check(not _part("core", "Badge").visible, "con un solo nivel no hay globito")
	_check(not _part("f_brazo", "Icon").visible, "una oculta no muestra el suyo")
	_economy.buy_star("core")
	_economy.buy_star("f_brazo")
	_economy.buy_star("f_brazo")
	await _frames()
	var badge: Control = _part("f_brazo", "Badge")
	_check(badge.visible and badge.get("text") == "2/5", "el nivel va en un globito (%s)" % str(badge.get("text")))
	var star: Control = _tree.call("star_button", "f_brazo")
	var center: Vector2 = star.get_global_rect().get_center()
	_check(badge.get_global_rect().position.x > center.x and badge.get_global_rect().position.y > center.y, "abajo a la derecha de la estrella")
	_check(not badge.get_global_rect().intersects((_part("f_brazo", "Icon")).get_global_rect().grow(-8.0)), "sin tapar el ícono")
	(_tree.find_child("CloseTree", true, false) as Button).pressed.emit()
	await _frames()


func _test_branches_are_told_apart() -> void:
	_section("Las ramas se distinguen sin depender del color")
	var shapes: Dictionary = {}
	var lights: Array[float] = []
	for id: String in ["f_brazo", "o_olfato", "c_capataz", "t_mecha"]:
		var button: Control = _tree.call("star_button", id)
		shapes[button.get("shape")] = true
		var color: Color = button.get("branch_color")
		lights.append(color.srgb_to_linear().get_luminance())
	_check_eq(shapes.size(), 4, "cada rama con su forma (%s)" % str(shapes.keys()))
	lights.sort()
	for i: int in range(1, lights.size()):
		var ratio: float = (lights[i] + 0.05) / (lights[i - 1] + 0.05)
		_check(ratio >= 1.3, "y con un brillo bien distinto del siguiente (x%.2f)" % ratio)
	_check(_tree.call("star_button", "f_furia").size.x > _tree.call("star_button", "f_brazo").size.x, "las piedras angulares son más grandes")


func _test_return_target_is_visible() -> void:
	_section("La meta de volver se ve")
	_economy.reset()
	_economy.claimed_relics = 40
	_economy.relics = 40
	_economy.run_gold = 1.0
	_economy._reset_run()
	await _frames()
	var depth: Label = _scene.get_node("%DepthLabel") as Label
	var target: int = int(_economy.return_depth())
	_check(target > 300, "(la meta está corrida: %d m)" % target)
	_check(depth.text.contains("Regreso %d m" % target), "arriba: %s" % depth.text)
	var button: Button = _scene.get_node("%PrestigeButton") as Button
	_check(button.text.contains("%d m" % target), "en el botón de volver (%s)" % button.text.replace("\n", " "))
	_economy.run_gold = 1.0e12
	_economy.gold_changed.emit(0.0)
	await _frames()
	button.pressed.emit()
	await _frames()
	var modal: Control = _scene.find_child("Modal", true, false) as Control
	var body: String = (modal.get("body_label") as Label).text
	_check(body.contains("Próximo regreso a"), "y la confirmación dice la próxima (%s)" % body.replace("\n", " "))
	_check(not body.contains("+25%"), "sin hablar del bonus viejo")
	modal.call("close")


func _test_tap_cap_in_the_game() -> void:
	_section("Tope de golpes en la pantalla")
	_economy.reset()
	await _frames()
	var landed: Array[int] = [0]
	var count: Callable = func(_amount: float) -> void: landed[0] += 1
	_economy.hit_landed.connect(count)
	for i: int in range(15):
		_scene.call("_on_tap")
	_check_eq(landed[0], 15, "una ráfaga fuerte cuenta entera: spamear la roca no se traba")
	for i: int in range(60):
		_scene.call("_on_tap")
	_check_eq(landed[0], 20, "el tope queda solo para autoclickers: 20 por segundo")

	# Dos dedos que se pisan: Godot solo emula el mouse con el primero; los demás también tienen que picar.
	_economy.reset()
	await _frames()
	var rock: Control = _scene.get_node("%TapButton") as Control
	var at: Vector2 = rock.get_global_rect().get_center()
	landed[0] = 0
	await _finger(0, at, true)
	for i: int in range(3):
		await _finger(1, at + Vector2(40, 0), true)
		await _finger(1, at + Vector2(40, 0), false)
	await _finger(0, at, false)
	_check_eq(landed[0], 4, "con dos dedos cuentan todos los toques, una vez cada uno")
	# Se levanta el primero y el segundo sigue apoyado: el que llega después también cuenta.
	landed[0] = 0
	await _finger(0, at, true)
	await _finger(1, at, true)
	await _finger(0, at, false)
	await _finger(0, at, true)
	await _finger(0, at, false)
	await _finger(1, at, false)
	_check_eq(landed[0], 3, "alternando sin levantar el otro")
	landed[0] = 0
	var elsewhere: Vector2 = (_scene.get_node("%HudPanel") as Control).get_global_rect().position + Vector2(40, 40)
	await _finger(0, at, true)
	await _finger(1, elsewhere, true)
	await _finger(1, elsewhere, false)
	await _finger(0, at, false)
	_check_eq(landed[0], 1, "un segundo dedo fuera de la roca no pica")
	_economy.hit_landed.disconnect(count)


func _test_debug_panel() -> void:
	_section("Menú de debug del árbol")
	_economy.reset()
	await _frames()
	var debug: Control = _scene.get_node("DebugPanel") as Control
	(debug.get("toggle_button") as Button).pressed.emit()
	await _frames()
	(debug.find_child("DebugRelics", true, false) as Button).pressed.emit()
	_check_eq(_economy.available_relics(), 100, "+100 reliquias")
	(debug.find_child("DebugFragments", true, false) as Button).pressed.emit()
	_check_eq(_economy.fragments, 100, "+100 fragmentos")
	_check_eq(_economy.relics, 105, "que se convierten (20 = 1)")
	(debug.find_child("DebugRings", true, false) as Button).pressed.emit()
	_check(_economy.resets >= 25 and _economy.record_depth >= 400.0, "abre los anillos")
	_economy.owned[0] = 10
	var before: float = _economy.run_gold
	(debug.find_child("DebugAfk8", true, false) as Button).pressed.emit()
	var expected: float = _economy.gold_per_second() * 0.0
	_check(_economy.run_gold > before + expected, "simula 8 h fuera")
	_check(not _economy.pending_offline_report.is_empty() or (_scene.find_child("Modal", true, false) as Control).visible, "con su aviso de vuelta")
	(_scene.find_child("Modal", true, false) as Control).call("close")
	_check(debug.find_child("DebugAfk1", true, false) != null and debug.find_child("DebugAfk23", true, false) != null, "también 1 h y 23 h")
	var wipe: Button = debug.find_child("DebugWipe", true, false) as Button
	wipe.pressed.emit()
	_check(_economy.relics > 0, "borrar pide confirmar con otro toque (%s)" % wipe.text)
	wipe.pressed.emit()
	_check_eq(_economy.relics + _economy.fragments + _economy.resets + _economy.owned_count(0), 0, "y ahí borra todo")
	var small: Array[String] = []
	for node: Node in debug.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.is_visible_in_tree() and (button.size.y < TOUCH_MIN - 0.5 or button.size.x < TOUCH_MIN - 0.5):
			small.append("%s (%dx%d)" % [button.name, int(button.size.x), int(button.size.y)])
	_check(small.is_empty(), "todo mide 96 o más (%s)" % str(small))
	var body: Control = debug.get("body") as Control
	_check(body.get_global_rect().end.y <= root.get_visible_rect().size.y + 0.5, "y el panel entra en la pantalla (%d de %d)" % [int(body.get_global_rect().end.y), int(root.get_visible_rect().size.y)])
	(debug.get("toggle_button") as Button).pressed.emit()


func _test_testers_card(packed: PackedScene) -> void:
	_section("Quien venía jugando recibe el aviso")
	_economy.reset()
	_economy.from_dict({ "balance_version": 2, "relics": 9, "gold": 10.0, "run_gold": 10.0, "owned": [1, 0, 0, 0, 0, 0] })
	_scene = packed.instantiate() as Control
	root.add_child(_scene)
	await _frames()
	var modal: Control = _scene.find_child("Modal", true, false) as Control
	_check(modal.visible, "sale el cartel")
	var body: String = (modal.get("body_label") as Label).text
	_check(body.contains("9 reliquias") and body.contains("árbol"), "dice que sus reliquias van al árbol (%s)" % body.replace("\n", " "))
	(modal.get("confirm_button") as Button).pressed.emit()
	await _frames()
	_check(_economy.pending_tree_report.is_empty(), "al cerrarlo no vuelve a salir")
	await _unmount()
