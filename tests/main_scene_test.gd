extends "res://tests/test_base.gd"
## Tests headless de la escena principal de F1 (game/main.tscn): cableado entre la UI
## provisoria y el autoload Economy. No miden cómo se ve, solo que cada control haga lo suyo.
##
## Usan el autoload Economy real (se reinicia antes de cada test). Save no persiste en
## headless, así que no se toca ninguna partida guardada.

const MAIN_SCENE: String = "res://game/main.tscn"

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
	await _test_large_numbers_use_suffixes()
	await _test_depth_label()
	await _test_prestige_flow()
	await _test_offline_notice()
	await _test_loot_hidden_without_loot()
	# Las pruebas de botín necesitan una escena nueva: arma sus carteles al cargar.
	await _mount_scene(packed, _real_balance())
	await _test_loot_odds_are_visible()
	var always_chest: Dictionary = _real_balance()
	always_chest["loot"]["chance_per_hit"] = 1.0
	await _mount_scene(packed, always_chest)
	await _test_chest_message()
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


## Fija el oro ganado de la partida (la profundidad) y espera a que la UI se refresque.
func _set_run_gold(run_gold: float) -> void:
	_economy.run_gold = run_gold
	_economy.gold_changed.emit(_economy.gold)
	await process_frame


func _button(node_name: String) -> Button:
	return _scene.get_node("%" + node_name) as Button


func _label(node_name: String) -> Label:
	return _scene.get_node("%" + node_name) as Label


func _rows() -> Array[Node]:
	return _scene.get_node("%GeneratorList").get_children()


func _row_button(index: int) -> Button:
	return _rows()[index].find_children("*", "Button", true, false)[0] as Button


## Deja el estado de Economy en `gold` (resto en cero) y espera a que la UI se refresque.
func _set_gold(gold: float) -> void:
	_economy.reset()
	_economy.gold = gold
	await process_frame


func _test_initial_screen() -> void:
	_section("Pantalla inicial")
	_check_eq(_label("GoldLabel").text, "0", "el oro arranca en 0")
	_check_eq(_rows().size(), 5, "hay una fila por generador (5)")
	_check_eq(_rows().size(), _economy.generator_count(), "una fila por generador del balance")
	var any_enabled: bool = false
	for i: int in range(_rows().size()):
		if not _row_button(i).disabled:
			any_enabled = true
	_check(not any_enabled, "sin oro, ningún botón de compra está habilitado")
	_check(_button("PickButton").disabled, "sin oro, el botón del pico está deshabilitado")
	_check_eq(_button("Mode1Button").button_pressed, true, "el modo de compra arranca en x1")


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
	await _set_gold(14.0)
	_check(_row_button(0).disabled, "con 14 no se puede comprar el Minero (cuesta 15)")
	await _set_gold(15.0)
	_check(not _row_button(0).disabled, "con 15 el botón del Minero se habilita")
	_check(_row_button(0).text.contains("15"), "el botón muestra el costo (%s)" % _row_button(0).text.replace("\n", " | "))
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), 1, "apretar el botón compra 1 Minero")
	_check_eq(_economy.gold, 0.0, "y gasta 15")
	await process_frame
	_check_eq(_label("GoldLabel").text, "0", "el oro en pantalla baja a 0")
	_check(_rows()[0].find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.contains("×1")), "la fila muestra ×1")
	_check(_label("RateLabel").text.contains("1"), "el cartel de producción muestra 1 oro/s (%s)" % _label("RateLabel").text)


func _test_buy_modes() -> void:
	_section("Modos ×1 / ×10 / Máx")
	await _set_gold(10000.0)
	_button("Mode10Button").button_pressed = true
	await process_frame
	_check(_row_button(0).text.contains("×10"), "en modo ×10 el botón dice ×10 (%s)" % _row_button(0).text.replace("\n", " | "))
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), 10, "apretar compra 10 de una")
	_button("ModeMaxButton").button_pressed = true
	await process_frame
	var expected: int = _economy.quote(0, 2)["count"]
	_check(expected > 1, "con el oro que queda, Máx permite más de 1 (%d)" % expected)
	_check(_row_button(0).text.contains("×%d" % expected), "en modo Máx el botón dice ×%d (%s)" % [expected, _row_button(0).text.replace("\n", " | ")])
	var before: int = _economy.owned_count(0)
	_row_button(0).pressed.emit()
	_check_eq(_economy.owned_count(0), before + expected, "apretar compra %d" % expected)
	_button("Mode1Button").button_pressed = true
	await process_frame
	_check(_row_button(0).text.contains("×1") and not _row_button(0).text.contains("×1\n×"), "al volver a ×1 el botón vuelve a decir ×1")


func _test_pick_upgrade() -> void:
	_section("Mejora del pico")
	await _set_gold(49.0)
	_check(_button("PickButton").disabled, "con 49 no se puede mejorar (cuesta 50)")
	await _set_gold(50.0)
	_check(not _button("PickButton").disabled, "con 50 se habilita")
	_check(_button("PickButton").text.contains("50"), "muestra el costo (%s)" % _button("PickButton").text.replace("\n", " | "))
	_button("PickButton").pressed.emit()
	_check_eq(_economy.pick_level, 1, "apretar sube el pico a nivel 1")
	await process_frame
	_check(_button("PickButton").text.contains("300"), "ahora muestra el costo del siguiente nivel (300)")
	_button("TapButton").button_down.emit()
	_check_eq(_economy.gold, 2.0, "y un golpe ahora vale 2")


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
	_check(button.text.contains("300 m"), "y dice desde cuándo se puede (%s)" % button.text.replace("\n", " | "))
	_check_eq(_label("RelicsLabel").text, "Reliquias: 0", "sin reliquias: 'Reliquias: 0' (%s)" % _label("RelicsLabel").text)
	_check(not _modal().visible, "el cartel de confirmación está cerrado")

	_economy.gold = 5000.0
	_economy.owned[0] = 3
	_economy.pick_level = 4
	await _set_run_gold(41000.0)
	_check(not button.disabled, "a 300 m el botón se habilita")
	_check(button.text.contains("+2 reliquias"), "y promete 2 reliquias (%s)" % button.text.replace("\n", " | "))
	_check(button.text.contains("+50%"), "y +50% de oro")

	button.pressed.emit()
	_check(_modal().visible, "apretar abre la confirmación")
	var body: String = _modal().body_label.text
	_check(body.contains("2 reliquias") and body.contains("+50%"), "que dice cuánto ganás (%s)" % body.replace("\n", " | "))
	_check(body.contains("oro") and body.contains("cuadrilla") and body.contains("pico"), "y qué perdés")
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
	_check(_economy.run_gold >= 41000.0 and _economy.run_gold < 41010.0, "y la profundidad intacta (%s)" % str(_economy.run_gold))

	button.pressed.emit()
	_check(_modal().visible, "se puede volver a abrir")
	_modal().confirm_button.pressed.emit()
	_check(not _modal().visible, "confirmar cierra el cartel")
	_check_eq(_economy.relics, 2, "y da 2 reliquias")
	_check_eq(_economy.gold, 0.0, "el oro vuelve a 0")
	_check_eq(_economy.owned_count(0), 0, "sin cuadrilla")
	_check_eq(_economy.pick_level, 0, "pico en 0")
	_check_eq(_economy.depth(), 0.0, "profundidad 0")
	await process_frame
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
	_economy.apply_offline(11520.0) # 3 h 12 min -> 115.200 de oro
	_check(_modal().visible, "al volver aparece el aviso")
	var body: String = _modal().body_label.text
	_check(body.contains("3 h 12 min"), "dice cuánto estuviste fuera (%s)" % body.replace("\n", " | "))
	_check(body.contains("115K"), "y cuánto oro juntó la cuadrilla")
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


func _test_loot_odds_are_visible() -> void:
	_section("Probabilidades del botín visibles")
	_check((_scene.get_node("%LootBox") as Control).visible, "el panel de cofres se muestra")
	var info: String = _label("LootInfoLabel").text
	_check(info.contains("4%") and info.contains("golpe"), "dice 4%% por golpe (%s)" % info)
	_check(info.contains("2%") and info.contains("segundo"), "y 2%% por segundo con cuadrilla")
	var texts: Array[String] = []
	for child: Node in _scene.get_node("%OddsRow").get_children():
		texts.append((child as Label).text.replace("\n", " "))
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
		var rarity_name: String = _economy.loot_table()[seen[0]]["name"]
		var text: String = _label("LastLootLabel").text
		_check(text.contains("Cofre") and text.contains(rarity_name), "el cartel dice 'Cofre %s' (%s)" % [rarity_name, text])
		_check(text.contains("+1"), "y cuánto oro dio (%s)" % text)
