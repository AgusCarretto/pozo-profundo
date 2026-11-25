extends "res://tests/test_base.gd"
## Tests headless de la escena principal de F1 (game/main.tscn): cableado entre la UI
## provisoria y el autoload Economy. No miden cómo se ve, solo que cada control haga lo suyo.
##
## Usan el autoload Economy real (se reinicia antes de cada test). Save no persiste en
## headless, así que no se toca ninguna partida guardada.

const NumberFormat := preload("res://core/number_format.gd")

const MAIN_SCENE: String = "res://game/main.tscn"
const DEBUG_PANEL_SCRIPT: String = "res://game/debug_panel.gd"

var _economy: Node
var _scene: Control


func _initialize() -> void:
	_economy = root.get_node_or_null("Economy")
	_check(_economy != null, "existe el autoload Economy")
	_check_eq(ProjectSettings.get_setting("application/run/main_scene"), MAIN_SCENE, "la escena principal del proyecto es " + MAIN_SCENE)
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	_check(packed != null, "carga " + MAIN_SCENE)
	if _economy == null or packed == null:
		_finish()
		return

	# En modo --script los autoloads recién corren _ready() después del primer frame, y Economy
	# recarga ahí el balance real: hay que esperar ese frame antes de cambiárselo.
	await process_frame
	# El botín es azar: cualquier cofre movería el oro que estos tests cuentan golpe a golpe.
	_check(_economy.load_balance(_balance_without_loot()), "carga el balance real sin botín (%s)" % _economy.last_error)
	_check_eq(_economy.loot_table().size(), 0, "el botín quedó apagado (el azar no mueve el oro)")
	_scene = packed.instantiate() as Control
	root.add_child(_scene)
	await process_frame

	await _test_initial_screen()
	await _test_tap_hits_the_rock()
	await _test_buying_a_generator()
	await _test_buy_modes()
	await _test_pick_upgrade()
	await _test_one_touch_buys_once()
	await _test_large_numbers_use_suffixes()
	await _test_depth_label()
	await _test_prestige_flow()
	await _test_offline_notice()
	await _test_loot_hidden_without_loot()
	await _test_debug_panel_only_in_debug_builds()
	# Las pruebas de botín necesitan una escena nueva: arma sus carteles al cargar.
	await _mount_scene(packed, _real_balance())
	await _test_loot_odds_are_visible()
	await _test_debug_panel_tools()
	var always_chest: Dictionary = _real_balance()
	always_chest["loot"]["chance_per_hit"] = 1.0
	await _mount_scene(packed, always_chest)
	await _test_chest_message()
	await _mount_scene(packed, _real_balance())
	await _test_last_loot_follows_the_state()
	_scene.queue_free()
	await process_frame
	_economy.reset()
	_finish()


## El balance real de data/ sin la sección "loot".
func _balance_without_loot() -> Dictionary:
	var balance: Dictionary = _real_balance()
	balance.erase("loot")
	return balance


func _real_balance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))


## Reemplaza la escena por una nueva, cargando antes `balance` en Economy.
func _mount_scene(packed: PackedScene, balance: Dictionary) -> void:
	_scene.queue_free()
	await process_frame
	_check(_economy.load_balance(balance), "se carga el balance para la escena nueva (%s)" % _economy.last_error)
	_scene = packed.instantiate() as Control
	root.add_child(_scene)
	await process_frame


func _modal() -> Control:
	return _scene.get_node("Modal") as Control


## Espera (en tiempo real) a que condition dé true, o hasta seconds.
func _wait_until(condition: Callable, seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame


## Fija el oro ganado de la partida (la profundidad) y espera a que la UI se refresque.
func _set_run_gold(run_gold: float) -> void:
	_economy.run_gold = run_gold
	_economy.gold_changed.emit(_economy.gold)
	await process_frame


func _button(node_name: String) -> Button:
	if node_name == "PickButton": # la tarjeta del pico es la primera de la grilla (la tarjeta entera es el botón)
		return _scene.get_node("%Shop").get_child(0) as Button
	return _scene.get_node("%" + node_name) as Button


func _label(node_name: String) -> Label:
	return _scene.get_node("%" + node_name) as Label


## Las tarjetas de los generadores (sin la del pico).
func _rows() -> Array[Node]:
	return _scene.get_node("%Shop").get_children().slice(1)


func _row_button(index: int) -> Button:
	return _rows()[index] as Button


## Los textos de una tarjeta o de un botón del costado, juntos.
func _card_text(card: Node) -> String:
	var parts: Array[String] = []
	for label: Node in card.find_children("*", "Label", true, false):
		parts.append((label as Label).text)
	return " | ".join(parts)


## El precio de una tarjeta (su tercer texto: nombre, dato, precio).
func _price(card: Node) -> String:
	return (card.find_children("*", "Label", true, false)[2] as Label).text


## Toca el botón de modo hasta que diga `mode` ("×1", "×10" o "Máx") y espera a que la UI se refresque.
func _pick_mode(mode: String) -> void:
	for i: int in range(3):
		if _card_text(_button("ModeButton")).begins_with(mode + " |"):
			break
		_button("ModeButton").pressed.emit()
	await process_frame


## Deja el estado de Economy en `gold` (resto en cero) y espera a que la UI se refresque.
func _set_gold(gold: float) -> void:
	_economy.reset()
	_economy.gold = gold
	await process_frame


func _test_initial_screen() -> void:
	_section("Pantalla inicial")
	_check_eq(_label("GoldLabel").text, "0", "el oro arranca en 0")
	_check_eq(_rows().size(), 5, "hay una tarjeta por generador (5)")
	_check_eq(_rows().size(), _economy.generator_count(), "una por generador del balance")
	var any_enabled: bool = false
	for i: int in range(_rows().size()):
		if not _row_button(i).disabled:
			any_enabled = true
	_check(not any_enabled, "sin oro, ninguna tarjeta de generador está habilitada")
	_check(_button("PickButton").disabled, "sin oro, la tarjeta del pico está deshabilitada")
	_check(_card_text(_button("ModeButton")).begins_with("×1 |"), "el modo de compra arranca en ×1 (%s)" % _card_text(_button("ModeButton")))


func _test_tap_hits_the_rock() -> void:
	_section("Golpe a la roca")
	await _set_gold(0.0)
	_button("TapButton").button_down.emit()
	_check_eq(_economy.gold, 1.0, "tocar la roca suma el golpe a Economy")
	await process_frame
	_check_eq(_label("GoldLabel").text, "1", "el cartel de oro se actualiza a 1")
	for i: int in range(9):
		_button("TapButton").button_down.emit()
	await process_frame
	_check_eq(_label("GoldLabel").text, "10", "10 golpes -> 10 de oro")


func _test_buying_a_generator() -> void:
	_section("Compra de un generador")
	await _set_gold(24.0)
	_check(_row_button(0).disabled, "con 24 no se puede comprar el Minero (cuesta 25)")
	await _set_gold(25.0)
	_check(not _row_button(0).disabled, "con 25 la tarjeta del Minero se habilita")
	_check_eq(_price(_row_button(0)), "25", "la tarjeta muestra el precio")
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), 1, "tocar la tarjeta compra 1 Minero")
	_check_eq(_economy.gold, 0.0, "y gasta 25")
	await process_frame
	_check_eq(_label("GoldLabel").text, "0", "el oro en pantalla baja a 0")
	_check(_card_text(_row_button(0)).contains("×1"), "la tarjeta muestra ×1 (%s)" % _card_text(_row_button(0)))
	_check(_label("RateLabel").text.contains("1"), "el cartel de producción muestra 1 oro/s (%s)" % _label("RateLabel").text)


func _test_buy_modes() -> void:
	_section("Modos ×1 / ×10 / Máx")
	await _set_gold(10000.0)
	await _pick_mode("×10")
	_check(_price(_row_button(0)).begins_with("×10 · "), "en modo ×10 el precio dice ×10 (%s)" % _price(_row_button(0)))
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), 10, "tocar la tarjeta compra 10 de una")
	await _pick_mode("Máx")
	var expected: int = _economy.quote(0, 2)["count"]
	_check(expected > 1, "con el oro que queda, Máx permite más de 1 (%d)" % expected)
	_check(_price(_row_button(0)).begins_with("×%d · " % expected), "en modo Máx el precio dice ×%d (%s)" % [expected, _price(_row_button(0))])
	var before: int = _economy.owned_count(0)
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), before + expected, "tocar compra %d" % expected)
	await _pick_mode("×1")
	_check(not _price(_row_button(0)).contains("×"), "al volver a ×1 queda solo el precio (%s)" % _price(_row_button(0)))


func _test_pick_upgrade() -> void:
	_section("Mejora del pico")
	await _set_gold(149.0)
	_check(_button("PickButton").disabled, "con 149 no se puede mejorar (cuesta 150)")
	await _set_gold(150.0)
	_check(not _button("PickButton").disabled, "con 150 se habilita")
	_check(_price(_button("PickButton")).contains("150"), "muestra el precio (%s)" % _price(_button("PickButton")))
	_button("PickButton").pressed.emit()
	_check_eq(_economy.pick_level, 1, "apretar sube el pico a nivel 1")
	await process_frame
	_check(_price(_button("PickButton")).contains("1.80K"), "ahora muestra el precio del siguiente nivel (1.80K)")
	_button("TapButton").button_down.emit()
	_check_eq(_economy.gold, 2.0, "y un golpe ahora vale 2")


## Un toque de verdad, por todo el camino de entrada: Godot además emula un click a partir de él.
func _touch(control: Control) -> void:
	var at: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = down
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await process_frame


## En un celular, un botón que reacciona al apretar recibía el click emulado y también el toque: compraba de a dos.
## Con "pressed.emit()" o con el mouse no se ve.
func _test_one_touch_buys_once() -> void:
	_section("Un toque en la pantalla compra una sola vez")
	await _set_gold(10000.0)
	await _pick_mode("×1")
	await _touch(_row_button(0))
	_check_eq(_economy.owned_count(0), 1, "un toque en el Minero compra 1")
	# El minero recién comprado ya produce entre cuadro y cuadro: de ahí el margen.
	_check(_economy.gold >= 9975.0 and _economy.gold < 9976.0, "y gasta 25 una vez (quedan %.2f)" % _economy.gold)
	await _touch(_row_button(0))
	_check_eq(_economy.owned_count(0), 2, "otro toque, otro Minero")
	await _set_gold(10000.0)
	await _pick_mode("×10")
	await _touch(_row_button(0))
	_check_eq(_economy.owned_count(0), 10, "en ×10 un toque compra 10, no 20")
	await _pick_mode("×1")
	await _set_gold(10000.0)
	await _touch(_button("PickButton"))
	_check_eq(_economy.pick_level, 1, "un toque sube el pico un nivel")
	await _set_gold(0.0)
	await _touch(_button("TapButton"))
	_check_eq(_economy.gold, 1.0, "y un toque en la roca es un golpe")
	await _touch(_button("TapButton"))
	_check_eq(_economy.gold, 2.0, "dos toques, dos golpes")


func _test_large_numbers_use_suffixes() -> void:
	_section("Números grandes")
	await _set_gold(1234567.0)
	_check_eq(_label("GoldLabel").text, "1.23M", "1234567 se muestra 1.23M")
	await _set_gold(2.5e12)
	_check_eq(_label("GoldLabel").text, "2.50T", "2.5e12 se muestra 2.50T")


func _test_depth_label() -> void:
	_section("Profundidad y bioma en pantalla")
	await _set_gold(0.0)
	_check(_label("DepthLabel").text.contains("0 m"), "en la superficie: 0 m (%s)" % _label("DepthLabel").text)
	_check(_label("DepthLabel").text.contains("Tierra"), "bioma Tierra")
	await _set_run_gold(700.0)
	var text: String = _label("DepthLabel").text
	_check(text.contains("153 m"), "con 700 de oro ganado: 153 m (%s)" % text)
	_check(text.contains("Roca"), "bioma Roca")
	_check(text.contains("×1.50"), "con su multiplicador ×1.50")
	await _set_run_gold(1.8e8)
	_check(_label("DepthLabel").text.contains("Abismo"), "con 1.8e8 de oro ganado: Abismo (%s)" % _label("DepthLabel").text)
	_economy.reset()


func _test_prestige_flow() -> void:
	_section("Volver a la superficie, con confirmación")
	var button: Button = _button("PrestigeButton")
	await _set_gold(0.0)
	await _set_run_gold(600.0)
	_check(button.disabled, "a ~148 m el botón está deshabilitado")
	_check(button.text.contains("450 m"), "y dice desde cuándo se puede (%s)" % button.text.replace("\n", " | "))
	_check_eq(_label("RelicsLabel").text, "Reliquias: 0", "sin reliquias: 'Reliquias: 0' (%s)" % _label("RelicsLabel").text)
	_check(not _modal().visible, "el cartel de confirmación está cerrado")

	_economy.gold = 5000.0
	_economy.owned[0] = 3
	_economy.pick_level = 4
	await _set_run_gold(2.7e6)
	_check(not button.disabled, "a ~450 m el botón se habilita")
	_check(button.text.contains("+2 reliquias"), "y promete 2 reliquias (%s)" % button.text.replace("\n", " | "))
	_check(button.text.contains("+50%"), "y +50% de oro")

	button.pressed.emit()
	_check(_modal().visible, "apretar abre la confirmación")
	var body: String = _modal().body_label.text
	_check(body.contains("2 reliquias") and body.contains("+50%"), "que dice cuánto ganás (%s)" % body.replace("\n", " | "))
	_check(body.contains("oro") and body.contains("cuadrilla") and body.contains("pico") and body.contains("botín"), "y qué perdés: oro, cuadrilla, pico y bonus de botín")
	# El juego sigue andando con el cartel abierto (la cuadrilla produce unos centavos por frame):
	# lo que no puede pasar es que se reinicie algo.
	_check_eq(_economy.relics, 0, "todavía no se ganó ninguna reliquia")
	_check(_economy.gold >= 5000.0 and _economy.gold < 5010.0, "ni se tocó el oro (%s)" % str(_economy.gold))
	_check_eq(_economy.owned_count(0), 3, "ni la cuadrilla")

	_modal().cancel_button.pressed.emit()
	_check(not _modal().visible, "cancelar cierra el cartel")
	_check_eq(_economy.relics, 0, "sin reliquias")
	_check(_economy.gold >= 5000.0 and _economy.gold < 5010.0, "con el oro intacto (%s)" % str(_economy.gold))
	_check_eq(_economy.owned_count(0), 3, "y la cuadrilla intacta")
	_check_eq(_economy.pick_level, 4, "y el pico intacto")
	_check(_economy.run_gold >= 2.7e6 and _economy.run_gold < 2.7e6 + 100.0, "y la profundidad intacta (%s)" % str(_economy.run_gold))

	_economy.loot_bonus = 0.5
	button.pressed.emit()
	_check(_modal().visible, "se puede volver a abrir")
	_modal().confirm_button.pressed.emit()
	_check(not _modal().visible, "confirmar cierra el cartel")
	# La vuelta a la superficie pasa detrás de un fundido a blanco (ver transitions_test.gd): se espera a que pase.
	await _wait_until(func() -> bool: return _economy.relics == 2, 3.0)
	_check_eq(_economy.relics, 2, "y da 2 reliquias")
	_check_eq(_economy.loot_bonus, 0.0, "y reinicia el bonus de botín")
	_check_eq(_economy.gold, 0.0, "el oro vuelve a 0")
	_check_eq(_economy.owned_count(0), 0, "sin cuadrilla")
	_check_eq(_economy.pick_level, 0, "pico en 0")
	_check_eq(_economy.depth(), 0.0, "profundidad 0")
	# El contador de reliquias sube cuando llegan volando: se espera a que termine la transición.
	await _wait_until(func() -> bool: return _label("RelicsLabel").text.contains("+50%"), 4.0)
	_check_eq(_label("RelicsLabel").text, "Reliquias: 2 · +50% de oro", "el cartel de reliquias se actualiza (%s)" % _label("RelicsLabel").text)
	_check(_label("DepthLabel").text.contains("Tierra"), "de vuelta en Tierra")
	_check(button.disabled, "y el botón vuelve a estar deshabilitado")
	_economy.reset()


func _test_offline_notice() -> void:
	_section("Aviso de progreso offline")
	await _set_gold(0.0)
	_economy.owned[0] = 10 # 10 oro/s
	_check(not _modal().visible, "sin ausencia no hay aviso")
	_economy.apply_offline(30.0)
	_check(not _modal().visible, "30 s fuera se acreditan sin aviso")
	await _set_gold(0.0)
	_economy.owned[0] = 10
	_economy.apply_offline(11520.0) # 3 h 12 min -> 10 oro/s x (120 + 11.400 x 25%) = 29.700 de oro
	_check(_modal().visible, "al volver aparece el aviso")
	var body: String = _modal().body_label.text
	_check(body.contains("3 h 12 min"), "dice cuánto estuviste fuera (%s)" % body.replace("\n", " | "))
	_check(body.contains("29.7K"), "y cuánto oro juntó la cuadrilla")
	_check(body.contains("25%"), "y a cuánto rinde sin vos")
	_check(not _modal().cancel_button.visible, "es solo un aviso: no hay botón de cancelar")
	_modal().confirm_button.pressed.emit()
	_check(not _modal().visible, "se cierra con el botón")
	_check(_economy.pending_offline_report.is_empty(), "y Economy ya no lo tiene pendiente")

	await _set_gold(0.0)
	_economy.owned[0] = 10
	_economy.apply_offline(20.0 * 3600.0)
	body = _modal().body_label.text
	_check(_modal().visible and body.contains("8 h") and body.contains("máximo"), "si se cortó por el tope, avisa del máximo de 8 h (%s)" % body.replace("\n", " | "))
	_modal().confirm_button.pressed.emit()

	# Un aviso que ya estaba pendiente cuando arranca la escena (el caso de abrir el juego).
	_scene.queue_free()
	await process_frame
	await _set_gold(0.0)
	_economy.owned[0] = 10
	_economy.apply_offline(7200.0) # no hay escena escuchando: queda pendiente
	_check(not _economy.pending_offline_report.is_empty(), "sin escena, el aviso queda pendiente")
	_scene = (load(MAIN_SCENE) as PackedScene).instantiate() as Control
	root.add_child(_scene)
	await process_frame
	_check(_modal().visible, "si ya había un aviso pendiente al abrir la escena, se muestra")
	_check(_modal().body_label.text.contains("2 h"), "con lo que corresponde (%s)" % _modal().body_label.text.replace("\n", " | "))
	_modal().confirm_button.pressed.emit()
	_check(_economy.pending_offline_report.is_empty(), "y se limpia al cerrarlo")
	_economy.reset()


func _test_loot_hidden_without_loot() -> void:
	_section("Sin botín en el balance")
	_check(not (_scene.get_node("%LootBox") as Control).visible, "el panel de cofres no se muestra si no hay botín")
	_check(not _label("LootBonusLabel").is_visible_in_tree(), "ni el bonus de botín")


func _test_debug_panel_only_in_debug_builds() -> void:
	_section("Panel de debug: solo en builds de debug")
	# Se carga en tiempo de ejecución (no con preload): el panel usa el autoload Economy, que
	# en modo --script no existe todavía cuando se compila este test.
	var debug_panel_script: GDScript = load(DEBUG_PANEL_SCRIPT) as GDScript
	var host: Control = Control.new()
	root.add_child(host)
	_check_eq(debug_panel_script.attach_if_debug(host, false), null, "en un build de release no se crea")
	_check_eq(host.get_child_count(), 0, "y no queda nada colgado")
	var panel: Control = debug_panel_script.attach_if_debug(host, true)
	_check(panel != null, "en un build de debug sí")
	_check_eq(host.get_child_count(), 1, "y queda colgado del padre")
	host.free()
	_check_eq(OS.is_debug_build(), true, "estos tests corren con un build de debug")
	_check(_scene.has_node("DebugPanel"), "la escena principal trae el panel en este build")
	var scene_panel: Control = _scene.get_node("DebugPanel")
	_check_eq(scene_panel.chest_buttons.size(), 0, "sin botín en el balance, no hay botones de cofre")
	_check_eq(scene_panel.raw_bonus_label, null, "ni el dato del bonus bruto")
	_check(not scene_panel.body.visible, "arranca cerrado: no tapa la pantalla")


func _test_debug_panel_tools() -> void:
	_section("Panel de debug: herramientas")
	var panel: Control = _scene.get_node("DebugPanel")
	panel.toggle_button.pressed.emit()
	_check(panel.body.visible, "el botón DBG abre el panel")
	panel.toggle_button.pressed.emit()
	_check(not panel.body.visible, "y lo cierra")

	await _set_gold(0.0)
	panel.gold_button.pressed.emit()
	_check_eq(_economy.gold, 1000.0, "'Oro ×1000' desde 0 deja 1.000")
	_check_eq(_economy.run_gold, 1000.0, "y cuenta como oro ganado (la profundidad sube)")
	_check_eq(_economy.biome_name(_economy.biome_index()), "Roca", "con 1.000 ya estás en Roca (%.0f m)" % _economy.depth())
	panel.gold_button.pressed.emit()
	_check_eq(_economy.gold, 1000000.0, "otra vez: el oro que tenés × 1000 = 1.000.000")
	_check_eq(_economy.can_prestige(), false, "con dos pulsaciones todavía no se puede volver (%.0f m, hacen falta 450)" % _economy.depth())
	await process_frame
	_check(_button("PrestigeButton").disabled, "y el botón de prestigio sigue deshabilitado")
	panel.gold_button.pressed.emit()
	_check_eq(_economy.biome_name(_economy.biome_index()), "Abismo", "con tres pulsaciones llegás a Abismo (%.0f m)" % _economy.depth())
	_check_eq(_economy.can_prestige(), true, "y ya se puede volver a la superficie")

	await _set_gold(0.0)
	_economy.owned[0] = 10 # 10 oro/s
	panel.time_button.pressed.emit()
	_check_eq(_economy.gold, 9900.0, "'Adelantar 1 h' con 10 oro/s suma 9.900 (cuenta como ausencia)")
	_check(_modal().visible, "y avisa con el cartel de bienvenida")
	_check(_modal().body_label.text.contains("1 h"), "de 1 h (%s)" % _modal().body_label.text.replace("\n", " | "))
	_modal().confirm_button.pressed.emit()

	await _set_gold(0.0)
	_check(panel.raw_bonus_label != null, "el panel tiene el dato del bonus de botín bruto")
	if panel.raw_bonus_label != null:
		_check(panel.raw_bonus_label.text.contains("+0%"), "arranca en +0%% (%s)" % panel.raw_bonus_label.text)
	_check_eq(panel.chest_buttons.size(), 4, "un botón de cofre por rareza (4)")
	var table: Array[Dictionary] = _economy.loot_table()
	var expected_bonus: float = 0.0
	for index: int in range(mini(panel.chest_buttons.size(), table.size())):
		var button: Button = panel.chest_buttons[index]
		_check(button.text.contains(table[index]["name"]), "el botón %d dice %s (%s)" % [index, table[index]["name"], button.text])
		button.pressed.emit()
		expected_bonus += table[index]["bonus"]
		_check_near(_economy.loot_bonus, expected_bonus, "forzar %s suma su bonus (+%s)" % [table[index]["name"], NumberFormat.format_percent(table[index]["bonus"])])
	_check_eq(_economy.gold, 0.0, "los cofres forzados no dan oro")
	await process_frame
	_check_near(_economy.loot_bonus, 0.80, "los cuatro cofres suman +80% de bonus bruto")
	_check_eq(_label("LootBonusLabel").text, "Bonus de botín: +70.2%", "en pantalla se ve el EFECTIVO (+70.2%%), no el bruto (%s)" % _label("LootBonusLabel").text)
	_check(not _label("LootBonusLabel").text.contains("80"), "y el bruto no aparece en la pantalla del jugador")
	if panel.raw_bonus_label != null:
		var raw_text: String = panel.raw_bonus_label.text
		_check(raw_text.contains("+80%"), "el panel de debug muestra el bruto (+80%%) (%s)" % raw_text)
		_check(raw_text.contains("70.2%"), "junto al efectivo (%s)" % raw_text)
		_check(raw_text.contains("300%"), "y el techo (%s)" % raw_text)
	_check(_label("LastLootLabel").text.contains("Legendario"), "y el último cofre es el Legendario (%s)" % _label("LastLootLabel").text)
	_economy.reset()


func _test_loot_odds_are_visible() -> void:
	_section("Probabilidades del botín visibles")
	_check((_scene.get_node("%LootBox") as Control).visible, "el panel de cofres se muestra")
	var info: String = _label("LootInfoLabel").text
	_check(info.contains("1.5%") and info.contains("golpe"), "dice 1.5%% por golpe (%s)" % info)
	_check(info.contains("0.5%") and info.contains("segundo"), "y 0.5%% por segundo con cuadrilla (%s)" % info)
	var texts: Array[String] = []
	for child: Node in _scene.get_node("%OddsRow").get_children():
		texts.append((child as Label).text.replace("\n", " "))
	_check_eq(_label("LootBonusLabel").text, "Bonus de botín: +0%", "arranca en 'Bonus de botín: +0%%' (%s)" % _label("LootBonusLabel").text)
	_check_eq(texts.size(), 4, "una etiqueta por rareza (4)")
	var expected: Array = [
		["Común", "70%", "+1%"],
		["Raro", "22%", "+4%"],
		["Épico", "7%", "+15%"],
		["Legendario", "1%", "+60%"],
	]
	for index: int in range(mini(texts.size(), expected.size())):
		var parts: Array = expected[index]
		var shown: bool = true
		for part: String in parts:
			if not texts[index].contains(part):
				shown = false
		_check(shown, "%s muestra su probabilidad y su bonus (%s)" % [parts[0], texts[index]])
	var colors: Dictionary = {}
	for child: Node in _scene.get_node("%OddsRow").get_children():
		colors[(child as Label).get_theme_color("font_color")] = true
	_check_eq(colors.size(), 4, "cada rareza tiene su propio color")


func _test_chest_message() -> void:
	_section("Aviso del último cofre")
	_check(not _label("LastLootLabel").text.contains("Cofre"), "antes del primero no dice 'Cofre' (%s)" % _label("LastLootLabel").text)
	await _set_gold(0.0)
	var seen: Array[int] = []
	_economy.loot_dropped.connect(func(rarity: int, _amount: float) -> void: seen.append(rarity))
	_button("TapButton").button_down.emit()
	_check_eq(seen.size(), 1, "con 100%% por golpe, el golpe suelta un cofre")
	if seen.size() == 1:
		var entry: Dictionary = _economy.loot_table()[seen[0]]
		var text: String = _label("LastLootLabel").text
		_check(text.contains("Cofre") and text.contains(entry["name"]), "el cartel dice 'Cofre %s' (%s)" % [entry["name"], text])
		_check(text.contains("+%s" % NumberFormat.format_percent(entry["bonus"])), "y cuánto bonus sumó (%s)" % text)
		_check(not text.contains("oro"), "no habla de oro: el cofre no da oro (%s)" % text)
	_check_eq(_economy.gold, 1.0, "el golpe sumó 1 de oro y el cofre ninguno")
	await process_frame
	var expected_bonus: String = "Bonus de botín: +%s" % NumberFormat.format_percent(_economy.loot_bonus_effective())
	_check_eq(_label("LootBonusLabel").text, expected_bonus, "el bonus total (efectivo) se actualiza (%s)" % _label("LootBonusLabel").text)
	_button("TapButton").button_down.emit()
	_button("TapButton").button_down.emit()
	await process_frame
	_check_eq(seen.size(), 3, "3 golpes, 3 cofres")
	expected_bonus = "Bonus de botín: +%s" % NumberFormat.format_percent(_economy.loot_bonus_effective())
	_check_eq(_label("LootBonusLabel").text, expected_bonus, "y acumula los 3 cofres (%s)" % _label("LootBonusLabel").text)
	var summed: float = 0.0
	for rarity: int in seen:
		summed += _economy.loot_table()[rarity]["bonus"]
	_check_near(_economy.loot_bonus, summed, "la suma coincide con los bonus de cada cofre")
	_check(_economy.loot_bonus > 0.0, "y es mayor que 0 (%s)" % str(_economy.loot_bonus))


## El aviso del último cofre se deriva del estado, no solo de la señal del cofre: antes decía "Todavía no
## salió ningún cofre" aunque hubiera bonus (al cargar una partida guardada) y, al revés, seguía mostrando
## un cofre viejo cuando el bonus ya había vuelto a 0 (al volver a la superficie).
func _test_last_loot_follows_the_state() -> void:
	_section("El aviso del último cofre refleja el estado real")
	await _set_gold(0.0)
	var label: Label = _label("LastLootLabel")
	_check(label.text.contains("Todavía no salió ningún cofre"), "sin bonus dice que todavía no salió ninguno (%s)" % label.text)
	# una partida guardada con bonus (el cofre salió en una sesión anterior)
	_economy.from_dict({ "loot_bonus": 0.3 })
	await process_frame
	_check_near(_economy.loot_bonus, 0.3, "se cargó una partida con +30% de bonus bruto")
	_check(not label.text.contains("Todavía no salió"), "con bonus ya no dice 'Todavía no salió ningún cofre' (%s)" % label.text)
	_check(label.text.contains("cofres"), "dice de dónde viene el bonus (%s)" % label.text)
	# un cofre nuevo pisa el aviso con su rareza
	_economy.drop_loot(2)
	await process_frame
	_check(label.text.contains("Épico"), "un cofre nuevo muestra su rareza (%s)" % label.text)
	_check(label.has_theme_color_override("font_color"), "y su color")
	# al volver a la superficie el bonus es 0 y el aviso también
	_economy.run_gold = 2.7e6
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(_economy.prestige() > 0, "se vuelve a la superficie")
	await process_frame
	_check_eq(_economy.loot_bonus, 0.0, "el bonus vuelve a 0")
	_check(label.text.contains("Todavía no salió ningún cofre"), "y el aviso vuelve a decir que todavía no salió ninguno (%s)" % label.text)
	_check(not label.has_theme_color_override("font_color"), "sin el color del cofre viejo")
	# lo mismo al reiniciar la partida
	_economy.drop_loot(3)
	await process_frame
	_check(label.text.contains("Legendario"), "un legendario: lo muestra (%s)" % label.text)
	_economy.reset()
	await process_frame
	_check(label.text.contains("Todavía no salió ningún cofre") and _economy.loot_bonus == 0.0, "al reiniciar, el aviso se limpia (%s)" % label.text)
	_economy.reset()
