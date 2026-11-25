extends "res://tests/test_base.gd"
## Tests headless del layout y el arte de la escena principal: HUD arriba, mina al medio (con los botones de
## Botín, Reliquias y modo al costado) y la grilla de mejoras abajo, en las proporciones de un celular vertical.
##
## Cada prueba arma la escena dentro de un contenedor de tamaño fijo, como si la pantalla midiera
## eso. La pantalla se diseña a 720 px de ancho; con aspect "expand" un celular de 360x640 equivale a
## 720x1280 y uno de 412x915 a 720x1599. Usa el autoload Economy real (se reinicia entre pruebas).
## El cableado con Economy (golpes, compras, cartel) se prueba en main_scene_test.gd.

const BiomePalette := preload("res://game/biome_palette.gd")

const MAIN_SCENE: String = "res://game/main.tscn"

## Alto mínimo de un botón que se toca, en px de diseño: 96 px = 48 px en un celular de 360 px de ancho.
const TOUCH_MIN: float = 96.0
const DESIGN_WIDTH: float = 720.0
const PHONE_SIZES: Array[Vector2] = [Vector2(720, 1280), Vector2(720, 1599)]

var _economy: Node


func _initialize() -> void:
	_economy = root.get_node_or_null("Economy")
	_check(_economy != null, "existe el autoload Economy")
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	_check(packed != null, "carga " + MAIN_SCENE)
	if _economy == null or packed == null:
		_finish()
		return
	# En modo --script los autoloads corren _ready() después del primer frame (ver main_scene_test.gd).
	await process_frame

	await _test_vertical_layout(packed)
	await _test_touch_targets(packed)
	await _test_side_buttons(packed)
	await _test_hud(packed)
	await _test_text_is_not_cut(packed)
	await _test_debug_toggle_below_the_hud(packed)
	await _test_overlays_draw_on_top(packed)
	await _test_mine_view(packed)
	await _test_relics_page(packed)
	await _test_theme(packed)
	await _test_shop_grid(packed)
	await _test_button_roles(packed)
	await _test_toasts_clear_the_side_column(packed)
	await _test_no_loot_hides_the_loot_button(packed)
	_economy.load_balance(_real_balance())
	_economy.reset()
	_finish()


func _real_balance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))


func _balance_without_loot() -> Dictionary:
	var balance: Dictionary = _real_balance()
	balance.erase("loot")
	return balance


## Arma la escena dentro de un contenedor de tamaño fijo (como si la pantalla midiera `host_size`),
## con el balance real (o `balance`), y la devuelve ya acomodada. Se libera con _free_host().
func _mount_host(packed: PackedScene, host_size: Vector2, balance: Dictionary = {}) -> Control:
	_check(_economy.load_balance(_real_balance() if balance.is_empty() else balance), "se carga el balance para la escena (%s)" % _economy.last_error)
	var host: Control = Control.new()
	host.size = host_size
	root.add_child(host)
	var scene: Control = packed.instantiate() as Control
	host.add_child(scene)
	await process_frame
	await process_frame
	return scene


func _free_host(scene: Control) -> void:
	scene.get_parent().queue_free()
	await process_frame


func _node(scene: Control, node_name: String) -> Control:
	return scene.get_node("%" + node_name) as Control


func _label_in(scene: Control, node_name: String) -> Label:
	return scene.get_node("%" + node_name) as Label


## Los botones que se ven en pantalla, sin los del panel de debug (que no es parte del juego).
func _visible_buttons(scene: Control) -> Array[Button]:
	var buttons: Array[Button] = []
	var debug_panel: Node = scene.get_node_or_null("DebugPanel")
	for node: Node in scene.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if not button.is_visible_in_tree():
			continue
		if debug_panel != null and debug_panel.is_ancestor_of(button):
			continue
		buttons.append(button)
	return buttons


func _inside_scroll(control: Control, scene: Control) -> bool:
	var node: Node = control.get_parent()
	while node != null and node != scene:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


## La tarjeta del pico: la primera de la grilla de mejoras.
func _pick_card(scene: Control) -> Button:
	return _node(scene, "Shop").get_child(0) as Button


## La tarjeta del generador `index` (van después de la del pico). La tarjeta entera es el botón de compra.
func _card(scene: Control, index: int) -> Button:
	return _node(scene, "Shop").get_child(index + 1) as Button


## El nombre, el dato y el precio de una tarjeta, en ese orden.
func _card_texts(card: Button) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in card.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return texts


## "green" o "grey" según la franja del precio de la tarjeta.
func _price_color(card: Button) -> String:
	for node: Node in card.find_children("*", "PanelContainer", true, false):
		var style: StyleBox = (node as PanelContainer).get_theme_stylebox("panel")
		if style is StyleBoxTexture:
			var parts: PackedStringArray = (style as StyleBoxTexture).texture.resource_path.split("/")
			return parts[parts.size() - 2]
	return "sin franja"


func _visible_count(sprites: Array) -> int:
	var count: int = 0
	for sprite: TextureRect in sprites:
		if sprite.visible:
			count += 1
	return count


func _test_vertical_layout(packed: PackedScene) -> void:
	_section("Layout vertical: HUD arriba, mina al medio, panel con pestañas abajo")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		var hud: Control = _node(scene, "HudPanel")
		var mine: Control = _node(scene, "MineView")
		var bottom: Control = _node(scene, "BottomPanel")
		_check(hud != null and mine != null and bottom != null, "[%s] existen el HUD, la mina y el panel de abajo" % label)
		if hud == null or mine == null or bottom == null:
			await _free_host(scene)
			continue
		_check_near(hud.global_position.y, 0.0, "[%s] el HUD arranca arriba de todo" % label, 1e-6)
		_check(mine.global_position.y >= hud.global_position.y + hud.size.y - 0.5, "[%s] la mina está debajo del HUD" % label)
		_check(bottom.global_position.y >= mine.global_position.y + mine.size.y - 0.5, "[%s] el panel de mejoras está debajo de la mina" % label)
		_check_near(bottom.global_position.y + bottom.size.y, phone.y, "[%s] y llega hasta el borde de abajo" % label, 1e-4)
		for part: Control in [hud, mine, bottom]:
			_check_near(part.size.x, DESIGN_WIDTH, "[%s] %s ocupa todo el ancho" % [label, part.name], 1e-4)
		_check(hud.size.y <= phone.y * 0.25, "[%s] el HUD no pasa del 25%% del alto (%d de %d)" % [label, int(hud.size.y), int(phone.y)])
		_check(mine.size.y >= 380.0, "[%s] la mina tiene lugar para la roca y la cuadrilla (%d px)" % [label, int(mine.size.y)])
		_check(bottom.size.y >= 460.0, "[%s] el panel de abajo tiene lugar para las mejoras (%d px)" % [label, int(bottom.size.y)])
		# nada visible se sale del ancho de la pantalla (lo que está dentro de un scroll se recorta: no cuenta)
		var overflowing: Array[String] = []
		for node: Node in scene.find_children("*", "Control", true, false):
			var control: Control = node as Control
			if not control.is_visible_in_tree() or scene.get_node("DebugPanel").is_ancestor_of(control) or _inside_scroll(control, scene):
				continue
			var rect: Rect2 = control.get_global_rect()
			if rect.position.x < -0.5 or rect.end.x > DESIGN_WIDTH + 0.5:
				overflowing.append("%s %s" % [control.name, str(rect)])
		_check(overflowing.is_empty(), "[%s] nada se sale del ancho de la pantalla (%s)" % [label, str(overflowing)])
		var tap: Control = _node(scene, "TapButton")
		var rock: Control = _node(scene, "Rock")
		_check(tap.get_global_rect().encloses(rock.get_global_rect()), "[%s] la zona de toque cubre toda la roca" % label)
		# Antes la roca medía 224 px a escala de diseño (208 en pantalla): ahora de 1,5 a 2 veces eso.
		_check(rock.size.x >= 312.0 and rock.size.x <= 448.0, "[%s] la roca es 1,5 a 2 veces más grande que antes (%d px; antes ~208)" % [label, int(rock.size.x)])
		_check(mine.get_global_rect().encloses(rock.get_global_rect()), "[%s] y entra entera en la mina" % label)
		var rock_center: Vector2 = rock.get_global_rect().get_center()
		var mine_center: Vector2 = mine.get_global_rect().get_center()
		# La roca va un poco corrida a la izquierda para dejarles lugar a los botones del costado.
		_check(rock_center.x < mine_center.x and mine_center.x - rock_center.x <= 40.0, "[%s] la roca está casi centrada, corrida %d px a la izquierda" % [label, int(mine_center.x - rock_center.x)])
		_check(rock_center.y > mine_center.y and rock_center.y <= mine_center.y + 0.15 * mine.size.y, "[%s] y un poco más abajo del centro (%d px bajo el centro de %d)" % [label, int(rock_center.y - mine_center.y), int(mine.size.y)])
		await _free_host(scene)


func _test_touch_targets(packed: PackedScene) -> void:
	_section("Todo lo que se toca mide al menos 48 px en un celular de 360 px (96 px de diseño)")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		_economy.gold = 1.0e6 # con oro hay tarjetas habilitadas
		_economy.gold_changed.emit(_economy.gold)
		await process_frame
		var too_small: Array[String] = []
		var count: int = 0
		for button: Button in _visible_buttons(scene):
			if button.name == "TapButton":
				continue # la roca entera es el botón: es enorme
			count += 1
			if button.size.y < TOUCH_MIN - 0.5 or button.size.x < TOUCH_MIN - 0.5:
				too_small.append("%s (%dx%d)" % [button.name, int(button.size.x), int(button.size.y)])
		_check(count >= 11, "[%s] hay botones que mirar: 6 mejoras, 3 laterales, sonido y opciones (%d)" % [label, count])
		_check(too_small.is_empty(), "[%s] ninguno mide menos de %d px de lado (%s)" % [label, int(TOUCH_MIN), str(too_small)])
		# los de adentro de los carteles de Botín y Reliquias
		for pair: Array in [["LootButton", "LootPanel"], ["RelicsButton", "RelicsPanel"]]:
			(_node(scene, pair[0]) as Button).pressed.emit()
			await process_frame
			await process_frame
			var small: Array[String] = []
			for node: Node in _node(scene, pair[1]).find_children("*", "Button", true, false):
				if (node as Button).size.y < TOUCH_MIN - 0.5:
					small.append("%s (%d px)" % [node.name, int((node as Button).size.y)])
			_check(small.is_empty(), "[%s] los botones de %s miden %d px o más (%s)" % [label, pair[1], int(TOUCH_MIN), str(small)])
			_node(scene, pair[1]).call("close")
		var modal: Control = scene.get_node("Modal")
		modal.open("Título", "Cuerpo", "Sí", "No")
		await process_frame
		await process_frame
		_check(modal.confirm_button.size.y >= TOUCH_MIN - 0.5, "[%s] el botón de confirmar del cartel mide %d px" % [label, int(modal.confirm_button.size.y)])
		_check(modal.cancel_button.size.y >= TOUCH_MIN - 0.5, "[%s] y el de cancelar %d px" % [label, int(modal.cancel_button.size.y)])
		var panel: Control = modal.find_children("*", "PanelContainer", true, false)[0] as Control
		_check(panel.get_global_rect().position.x >= 0.0 and panel.get_global_rect().end.x <= DESIGN_WIDTH + 0.5, "[%s] el cartel entra en el ancho de la pantalla" % label)
		modal.close()
		await _free_host(scene)
		_economy.reset()


## Sin pestañas: las mejoras están siempre a la vista y Botín y Reliquias son botones al costado de la
## mina que abren su cartel.
func _test_side_buttons(packed: PackedScene) -> void:
	_section("Botones al costado: Botín, Reliquias y el modo de compra")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		for gone: String in ["TabCrewButton", "TabLootButton", "TabRelicsButton", "Mode10Button"]:
			_check(scene.get_node_or_null("%" + gone) == null, "[%s] ya no hay %s" % [label, gone])
		var mine: Control = _node(scene, "MineView")
		var sides: Array[Button] = [_node(scene, "LootButton") as Button, _node(scene, "RelicsButton") as Button, _node(scene, "ModeButton") as Button]
		var inside: bool = true
		for side: Button in sides:
			if not mine.get_global_rect().encloses(side.get_global_rect()) or side.get_global_rect().end.x < DESIGN_WIDTH - 16.0:
				inside = false
		_check(inside, "[%s] los tres están dentro de la mina, pegados al borde derecho" % label)
		_check(sides[0].global_position.y < sides[1].global_position.y and sides[1].global_position.y < sides[2].global_position.y, "[%s] uno debajo del otro: Botín, Reliquias, modo" % label)
		# nadie de la cuadrilla queda tapado por ellos
		_economy.owned[0] = 40
		_economy.owned[1] = 1
		_economy.owned[3] = 1
		_economy.gold_changed.emit(_economy.gold)
		await process_frame
		await process_frame
		var covered: Array[String] = []
		var crew: Array[TextureRect] = [mine.drill_sprite, mine.golem_sprite, _node(scene, "Rock") as TextureRect]
		crew.append_array(mine.miner_sprites)
		for sprite: TextureRect in crew:
			for side: Button in sides:
				if sprite.get_global_rect().intersects(side.get_global_rect()):
					covered.append("%s/%s" % [sprite.name, side.name])
		_check(covered.is_empty(), "[%s] no tapan a nadie (%s)" % [label, str(covered)])
		var vignette: Control = _node(scene, "Vignette")
		_check(sides[0].get_parent().get_index() > vignette.get_index(), "[%s] se dibujan por encima de la viñeta" % label)
		_economy.reset()
		await _free_host(scene)

	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	var loot_button: Button = _node(scene, "LootButton") as Button
	var relics_button: Button = _node(scene, "RelicsButton") as Button
	var loot: Control = _node(scene, "LootPanel")
	var relics: Control = _node(scene, "RelicsPanel")
	_check(_card_texts(loot_button).has("Botín") and _card_texts(relics_button).has("Reliquias"), "cada botón dice qué es")
	_check(not loot.visible and not relics.visible, "arrancan cerrados")
	loot_button.pressed.emit()
	await process_frame
	_check(loot.visible and not relics.visible, "Botín abre el cartel del botín")
	_check(_node(scene, "LootBonusLabel").is_visible_in_tree() and _node(scene, "OddsRow").is_visible_in_tree(), "con las probabilidades y el bonus")
	_check_eq(loot.mouse_filter, Control.MOUSE_FILTER_STOP, "y no deja tocar lo de atrás")
	(loot.find_child("CloseButton", true, false) as Button).pressed.emit()
	_check(not loot.visible, "'Cerrar' lo cierra")
	relics_button.pressed.emit()
	await process_frame
	_check(relics.visible and not loot.visible, "Reliquias abre el cartel de reliquias")
	_check(_node(scene, "PrestigeButton").is_visible_in_tree() and _node(scene, "RelicsLabel").is_visible_in_tree(), "con el botón de volver a la superficie")
	(relics.find_child("CloseButton", true, false) as Button).pressed.emit()
	_check(not relics.visible, "y se cierra")

	# el modo de compra: un solo botón que va cambiando
	var mode: Button = _node(scene, "ModeButton") as Button
	_economy.gold = 1.0e6
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	var seen: Array[String] = []
	var prices: Array[String] = []
	for i: int in range(4):
		seen.append(_card_texts(mode)[0])
		prices.append(_card_texts(_card(scene, 0))[2])
		mode.pressed.emit()
		await process_frame
	_check_eq(seen, ["×1", "×10", "Máx", "×1"] as Array[String], "cada toque pasa de ×1 a ×10, a Máx y vuelve")
	_check(not prices[0].contains("×") and prices[1].begins_with("×10") and prices[2].begins_with("×"), "y las tarjetas muestran lo que se compra en cada modo (%s)" % str(prices))

	# los avisos en los botones
	_economy.reset()
	await process_frame
	var loot_badge: Control = loot_button.get("badge")
	var relics_badge: Control = relics_button.get("badge")
	_check(not loot_badge.visible and not relics_badge.visible, "sin bonus ni reliquias no hay avisos")
	_economy.drop_loot(3)
	await process_frame
	_check(loot_badge.visible and _card_texts(loot_button).any(func(t: String) -> bool: return t.contains("%")), "con bonus, el de Botín muestra cuánto (%s)" % str(_card_texts(loot_button)))
	_economy.relics = 3
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(relics_badge.visible and _card_texts(relics_button).has("3"), "con reliquias, cuántas (%s)" % str(_card_texts(relics_button)))
	_economy.run_gold = 2.7e6 # ~451 m: se puede volver
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(_card_texts(relics_button).has("!"), "y un ! cuando ya podés volver a la superficie (%s)" % str(_card_texts(relics_button)))
	_economy.reset()
	await _free_host(scene)


func _test_hud(packed: PackedScene) -> void:
	_section("HUD: oro, oro/s, profundidad con barra al próximo bioma y multiplicador")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_economy.reset()
	await process_frame
	_check((_node(scene, "CoinIcon") as TextureRect).texture != null, "el oro lleva su moneda")
	_check_eq(_label_in(scene, "GoldLabel").text, "0", "oro: 0")
	_check_eq(_label_in(scene, "GoldLabel").get_theme_font_size("font_size"), 80, "con poco oro, el oro se ve a 80 px")
	_check_eq(_label_in(scene, "RateLabel").text, "0 oro/s", "oro/s: 0 oro/s (%s)" % _label_in(scene, "RateLabel").text)
	# el oro por segundo es un dato principal: grande y justo debajo del oro
	var gold_label: Label = _label_in(scene, "GoldLabel")
	var rate_label: Label = _label_in(scene, "RateLabel")
	var depth_label: Label = _label_in(scene, "DepthLabel")
	var rate_size: int = rate_label.get_theme_font_size("font_size")
	_check(rate_size >= 38, "el oro/s se lee grande (%d px de diseño)" % rate_size)
	_check(rate_size > depth_label.get_theme_font_size("font_size"), "y más grande que la profundidad")
	_check(rate_label.global_position.y >= gold_label.global_position.y + gold_label.size.y - 1.0, "está debajo del oro")
	_check(rate_label.global_position.y + rate_label.size.y <= depth_label.global_position.y + 1.0, "y arriba de la profundidad")
	var hit_label: Label = _label_in(scene, "HitLabel")
	_check(hit_label.text.begins_with("Golpe"), "el golpe pasó a ser un dato chico aparte (%s)" % hit_label.text)
	_check(hit_label.get_theme_font_size("font_size") < rate_size, "más chico que el oro/s")
	_economy.owned[0] = 10
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_eq(rate_label.text, "10 oro/s", "con 10 mineros: 10 oro/s (%s)" % rate_label.text)
	_economy.reset()
	await process_frame
	_check_eq(_label_in(scene, "MultLabel").text, "×1.00", "multiplicador ×1.00 al empezar")
	var bar: ProgressBar = _node(scene, "DepthBar") as ProgressBar
	_check_near(bar.max_value, 1.0, "la barra va de 0 a 1", 1e-9)
	_check_near(bar.value, 0.0, "y arranca vacía", 1e-9)
	_check(not bar.show_percentage, "sin el porcentaje encima")
	var next_text: String = _label_in(scene, "NextBiomeLabel").text
	_check(next_text.contains("Roca") and next_text.contains("150"), "dice cuál es el próximo bioma y a cuántos metros (%s)" % next_text)

	_economy.run_gold = 70.0 # 75 m: mitad del camino a Roca
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_near(bar.value, 0.5, "a 75 m la barra está a la mitad", 1e-6)
	_check(_label_in(scene, "DepthLabel").text.contains("75 m"), "y la profundidad dice 75 m (%s)" % _label_in(scene, "DepthLabel").text)

	_economy.run_gold = 700.0 # Roca x1.5
	_economy.relics = 2 # +50%
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_eq(_label_in(scene, "MultLabel").text, "×2.25", "bioma ×1.5 por reliquias ×1.5 = ×2.25 (%s)" % _label_in(scene, "MultLabel").text)
	next_text = _label_in(scene, "NextBiomeLabel").text
	_check(next_text.contains("Cristal") and next_text.contains("300"), "en Roca, el próximo es Cristal a los 300 m (%s)" % next_text)
	_check(bar.value < 0.05, "la barra vuelve a casi vacía al cruzar a Roca (%.3f)" % bar.value)

	_economy.drop_loot(3) # +60% bruto -> ~+54.4% efectivo
	await process_frame
	_check_eq(_label_in(scene, "MultLabel").text, "×%.2f" % _economy.multiplier, "el multiplicador incluye el botín (%s)" % _label_in(scene, "MultLabel").text)

	_economy.run_gold = 1.8e8 # Abismo
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_near(bar.value, 1.0, "en el último bioma la barra está llena", 1e-9)
	_check(_label_in(scene, "NextBiomeLabel").text.contains("Fondo"), "y avisa que llegaste al fondo (%s)" % _label_in(scene, "NextBiomeLabel").text)

	# El oro comparte fila con el multiplicador y los botones de sonido y opciones: si el número no entra,
	# la fuente se achica (sin bajar de 48 px), y vuelve a 80 px cuando entra.
	_economy.gold = 8.88e15
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	var shrunk: int = gold_label.get_theme_font_size("font_size")
	_check(shrunk < 80 and shrunk >= 48, "con '%s' el oro achica la fuente para entrar, sin bajar de 48 px (%d)" % [gold_label.text, shrunk])
	_economy.gold = 12.0
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_eq(gold_label.get_theme_font_size("font_size"), 80, "y con un número corto vuelve a 80 px")
	_economy.reset()
	await _free_host(scene)


## El texto más largo posible no se corta: el ancho del texto entra en el de su etiqueta. (Las cajas
## no alcanzan: una etiqueta con clip_text se ve "bien" por fuera aunque se coma el final del texto.)
## El botón del panel de debug no tapa el HUD (si el HUD cambia de alto, se acomoda solo debajo).
func _test_debug_toggle_below_the_hud(packed: PackedScene) -> void:
	_section("El botón DBG queda debajo del HUD")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		var hud: Control = _node(scene, "HudPanel")
		var toggle: Button = scene.get_node("DebugPanel").toggle_button
		_check(toggle.global_position.y >= hud.global_position.y + hud.size.y, "[%s] el botón DBG está debajo del HUD (%d >= %d)" % [label, int(toggle.global_position.y), int(hud.global_position.y + hud.size.y)])
		_check(toggle.global_position.y + toggle.size.y <= _node(scene, "MineView").get_global_rect().end.y, "[%s] y dentro de la mina" % label)
		await _free_host(scene)


func _test_text_is_not_cut(packed: PackedScene) -> void:
	_section("Ningún texto se corta, ni en el peor caso")
	# Un estado por bioma (el nombre más largo es Cristal) y uno con profundidad de 4 cifras, con montos y
	# multiplicadores grandes y cuadrillas enormes: así se prueban los textos más anchos que se pueden ver.
	var states: Array[Dictionary] = [
		{ "run_gold": 22.0, "gold": 22.0, "relics": 0 },
		{ "run_gold": 700.0, "gold": 999.0, "relics": 2 },
		{ "run_gold": 60000.0, "gold": 999.0e3, "relics": 12 },
		{ "run_gold": 5.0e6, "gold": 999.0e6, "relics": 88 },
		{ "run_gold": 2.0e9, "gold": 999.0e9, "relics": 40 },
		{ "run_gold": 1.0e15, "gold": 999.0e12, "relics": 400 },
		# los textos de oro más anchos que da el formato: 8.88M y 8.88Qa (dígitos anchos y sufijo de dos letras)
		{ "run_gold": 5.0e6, "gold": 8.88e6, "relics": 0 },
		{ "run_gold": 1.0e15, "gold": 8.88e15, "relics": 400 },
	]
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		var cut: Array[String] = []
		var wrapped: Array[String] = []
		for state: Dictionary in states:
			for mode_taps: int in [0, 1]: # en ×1 y en ×10 (el precio más largo)
				_economy.reset()
				_economy.run_gold = state["run_gold"]
				_economy.gold = state["gold"]
				_economy.relics = state["relics"]
				_economy.pick_level = 9
				_economy.loot_bonus = 5.0
				_economy.owned[0] = 1234
				_economy.owned[2] = 1234 # Cuadrilla de dinamita: el nombre más largo
				for tap: int in range(mode_taps):
					(_node(scene, "ModeButton") as Button).pressed.emit()
				_economy.gold_changed.emit(_economy.gold)
				await process_frame
				await process_frame
				for node: Node in scene.find_children("*", "Label", true, false):
					var text_label: Label = node as Label
					if not text_label.is_visible_in_tree() or scene.get_node("DebugPanel").is_ancestor_of(text_label):
						continue
					if text_label.autowrap_mode != TextServer.AUTOWRAP_OFF:
						# los nombres de las tarjetas se parten en hasta dos líneas
						if _node(scene, "Shop").is_ancestor_of(text_label) and text_label.get_line_count() > 2:
							wrapped.append("'%s' (%d líneas)" % [text_label.text, text_label.get_line_count()])
						continue
					var font: Font = text_label.get_theme_font("font")
					var font_size: int = text_label.get_theme_font_size("font_size")
					for line: String in text_label.text.split("\n"):
						var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
						if width > text_label.size.x + 0.5:
							cut.append("%s '%s' (%d > %d px)" % [text_label.name, line, int(width), int(text_label.size.x)])
				for tap: int in range(3 - mode_taps if mode_taps > 0 else 0):
					(_node(scene, "ModeButton") as Button).pressed.emit() # vuelve a ×1
		_check(cut.is_empty(), "[%s] ningún texto se corta (%s)" % [label, str(cut)])
		_check(wrapped.is_empty(), "[%s] los nombres de las tarjetas entran en dos líneas (%s)" % [label, str(wrapped)])
		# el contenido de cada tarjeta entra en su alto
		var overflowing: Array[String] = []
		for card: Node in _node(scene, "Shop").get_children():
			var content: Control = card.get_child(0) as Control
			if not (card as Control).get_global_rect().grow(0.5).encloses(content.get_global_rect()):
				overflowing.append("%s (%s fuera de %s)" % [card.name, str(content.get_global_rect()), str((card as Control).get_global_rect())])
		_check(overflowing.is_empty(), "[%s] y nada se sale de la tarjeta (%s)" % [label, str(overflowing)])
		_economy.reset()
		await _free_host(scene)


## El cartel y el panel de debug se dibujan encima de TODO, también de los sprites de la mina.
## (Con z_index los sprites quedaban por encima del cartel; por eso la mina se ordena por posición de hijo.)
func _test_overlays_draw_on_top(packed: PackedScene) -> void:
	_section("El cartel y el panel de debug quedan por encima de la mina")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_economy.owned[0] = 40
	_economy.owned[1] = 1
	_economy.owned[3] = 1
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	await process_frame
	var with_z: Array[String] = []
	for node: Node in scene.find_children("*", "CanvasItem", true, false):
		if (node as CanvasItem).z_index != 0:
			with_z.append("%s (z %d)" % [node.name, (node as CanvasItem).z_index])
	_check(with_z.is_empty(), "ningún nodo usa z_index: lo que viene después en el árbol se dibuja encima (%s)" % str(with_z))
	_check(scene.get_node("DebugPanel").get_index() > scene.get_node("Layout").get_index(), "el panel de debug viene después de todo el layout")
	for panel_name: String in ["LootPanel", "RelicsPanel"]:
		var panel: Control = _node(scene, panel_name)
		_check(panel.get_index() > scene.get_node("DebugPanel").get_index() and panel.get_index() < scene.get_node("Modal").get_index(), "%s va encima del juego y debajo del cartel" % panel_name)
	_check(scene.get_node("Modal").get_index() > scene.get_node("DebugPanel").get_index(), "y el cartel viene último: se dibuja encima de todo")
	_check_eq(scene.get_node("Modal").get_index(), scene.get_child_count() - 1, "es el último hijo de la escena")
	# dentro de la mina: los de más abajo se dibujan delante (vienen después entre los hijos)
	var mine: Control = _node(scene, "MineView")
	var bottoms: Array[float] = []
	for child: Node in mine.get_children():
		var sprite: TextureRect = child as TextureRect
		if sprite != null and sprite.visible:
			bottoms.append(sprite.position.y + sprite.size.y)
	_check(bottoms.size() >= 11, "se ven la roca, 8 mineros, el taladro y el gólem (%d)" % bottoms.size())
	var sorted_by_depth: bool = true
	for i: int in range(1, bottoms.size()):
		if bottoms[i] < bottoms[i - 1]:
			sorted_by_depth = false
	_check(sorted_by_depth, "la roca y la cuadrilla van ordenadas por profundidad (la base más baja, al final) (%s)" % str(bottoms))
	_check(_node(scene, "HintLabel").get_index() > _node(scene, "Rock").get_index(), "y el cartel de ayuda va después de todos los sprites")
	# la viñeta oscura de los bordes: encima de los sprites, debajo del cartel de ayuda, y no come toques
	var vignette: TextureRect = _node(scene, "Vignette") as TextureRect
	_check(vignette != null, "hay una viñeta en la mina")
	if vignette != null:
		var last_sprite: int = 0
		for child: Node in mine.get_children():
			if child is TextureRect and child != vignette:
				last_sprite = maxi(last_sprite, child.get_index())
		_check(vignette.get_index() > last_sprite, "la viñeta se dibuja encima de los sprites (oscurece también a los de los bordes)")
		_check(vignette.get_index() < _node(scene, "HintLabel").get_index(), "y debajo del cartel de ayuda")
		_check_eq(vignette.mouse_filter, Control.MOUSE_FILTER_IGNORE, "la viñeta no come toques")
		_check(vignette.position.is_zero_approx() and vignette.size.is_equal_approx(mine.size), "cubre toda la mina (%s)" % str(vignette.size))
		var gradient_texture: GradientTexture2D = vignette.texture as GradientTexture2D
		_check(gradient_texture != null and gradient_texture.fill == GradientTexture2D.FILL_RADIAL, "es un degradé radial: oscuro en los bordes")
		if gradient_texture != null:
			var edge: float = gradient_texture.gradient.sample(1.0).a
			var middle: float = gradient_texture.gradient.sample(0.35).a
			_check(gradient_texture.gradient.sample(0.0).a <= 0.02 and middle <= 0.05, "el centro queda limpio (alfa %.2f a 35%%)" % middle)
			_check(edge >= 0.6, "y los bordes bien oscuros (alfa %.2f)" % edge)
			_check(gradient_texture.gradient.sample(0.7).a > middle and gradient_texture.gradient.sample(0.7).a < edge, "con transición gradual (%.2f a 70%%)" % gradient_texture.gradient.sample(0.7).a)
	_economy.reset()
	await _free_host(scene)


func _test_mine_view(packed: PackedScene) -> void:
	_section("La mina: fondo y roca por bioma, y la cuadrilla alrededor")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_economy.reset()
	await process_frame
	var mine: Control = _node(scene, "MineView")
	var rock: TextureRect = _node(scene, "Rock") as TextureRect
	_check_eq(mine.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "el pixel art se dibuja con filtro Nearest (sin borroneo)")

	# arte y paleta de cada bioma
	var run_gold_by_biome: Array = [["earth", 0.0], ["rock", 700.0], ["crystal", 41000.0], ["magma", 2.7e6], ["abyss", 1.8e8]]
	var rock_paths: Dictionary = {}
	var palettes: Dictionary = {}
	var previous_bg: Color = Color.TRANSPARENT
	for case: Array in run_gold_by_biome:
		var id: String = case[0]
		_economy.run_gold = case[1]
		_economy.gold_changed.emit(_economy.gold)
		await process_frame
		_check_eq(mine.biome_id, id, "con %s de oro ganado la mina es '%s'" % [str(case[1]), id])
		var rock_path: String = rock.texture.resource_path if rock.texture != null else "sin textura"
		_check(rock_path.ends_with("rock_%s.png" % id), "la roca es rock_%s.png (%s)" % [id, rock_path])
		_check_eq(mine.backdrop_color, BiomePalette.of(id)["bg"], "el fondo toma el color de '%s'" % id)
		_check(mine.backdrop_color != previous_bg, "'%s' cambia el color de fondo respecto del bioma anterior" % id)
		previous_bg = mine.backdrop_color
		rock_paths[rock_path] = true
		var colors: Dictionary = BiomePalette.of(id)
		palettes["%s|%s|%s|%s" % [colors["bg"].to_html(), colors["bg_dark"].to_html(), colors["bg_light"].to_html(), colors["bg_spark"].to_html()]] = true
	_check_eq(rock_paths.size(), 5, "5 biomas = 5 rocas distintas")
	_check_eq(palettes.size(), 5, "y 5 paletas de fondo distintas (base, motas oscuras, claras y destellos)")
	_economy.reset()
	await process_frame
	_check_eq(mine.biome_id, "earth", "al volver a la superficie vuelve el bioma Tierra")

	# la cuadrilla: mineros alrededor (hasta 8), el taladro y el gólem solo cuando se compran
	var miners: Array = mine.miner_sprites
	_check_eq(miners.size(), 8, "hay 8 puestos para mineros")
	_check_eq(_visible_count(miners), 0, "sin cuadrilla no se ve ningún minero")
	_check(not mine.drill_sprite.visible and not mine.golem_sprite.visible, "ni el taladro ni el gólem")
	_economy.owned[0] = 1
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_eq(_visible_count(miners), 1, "con 1 Minero se ve 1")
	_economy.owned[0] = 3
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_eq(_visible_count(miners), 3, "con 3 se ven 3")
	_economy.owned[0] = 40
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_eq(_visible_count(miners), 8, "con 40 se ven 8 (el máximo que entra alrededor de la roca)")
	_check(not mine.drill_sprite.visible, "el taladro sigue sin aparecer: no se compró")
	_economy.owned[1] = 1 # Taladro a vapor
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(mine.drill_sprite.visible, "al comprar el Taladro a vapor aparece el taladro")
	_check(not mine.golem_sprite.visible, "y el gólem todavía no")
	_economy.owned[3] = 1 # Gólem de piedra
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(mine.golem_sprite.visible, "al comprar el Gólem de piedra aparece el gólem")
	_check(mine.drill_sprite.texture.resource_path.ends_with("drill.png") and mine.golem_sprite.texture.resource_path.ends_with("golem.png"), "con sus sprites (drill.png, golem.png)")
	# los mineros se distinguen por color
	var textures: Dictionary = {}
	for sprite: TextureRect in miners:
		textures[sprite.texture.resource_path] = true
	_check_eq(textures.size(), 8, "los 8 mineros usan 8 sprites distintos (variaciones de color)")
	# nadie queda encima de la roca (ni un píxel de su cuadro) ni se sale de la mina, y entre sí casi no se pisan
	var mine_rect: Rect2 = mine.get_global_rect()
	var out_of_mine: Array[String] = []
	var on_rock: Array[String] = []
	var rock_rect: Rect2 = rock.get_global_rect()
	var crew: Array[TextureRect] = [mine.drill_sprite, mine.golem_sprite]
	crew.append_array(miners)
	for sprite: TextureRect in crew:
		if not mine_rect.encloses(sprite.get_global_rect()):
			out_of_mine.append("%s %s" % [sprite.name, str(sprite.get_global_rect())])
		if sprite.get_global_rect().intersects(rock_rect):
			on_rock.append(sprite.name)
	_check(out_of_mine.is_empty(), "toda la cuadrilla entra en la mina (%s)" % str(out_of_mine))
	_check(on_rock.is_empty(), "y ninguno está encima de la roca (%s)" % str(on_rock))
	var stacked: Array[String] = []
	for i: int in range(crew.size()):
		for j: int in range(i):
			var overlap: float = crew[i].get_global_rect().intersection(crew[j].get_global_rect()).get_area()
			var smaller: float = minf(crew[i].get_global_rect().get_area(), crew[j].get_global_rect().get_area())
			if overlap > smaller * 0.1:
				stacked.append("%s/%s" % [crew[i].name, crew[j].name])
	_check(stacked.is_empty(), "y casi no se pisan entre sí (%s)" % str(stacked))
	# cada uno mira hacia la roca: los de los costados, hacia el costado; los de arriba, hacia abajo
	var wrong_gaze: Array[String] = []
	for sprite: TextureRect in miners:
		var to_rock: Vector2 = rock_rect.get_center() - sprite.get_global_rect().get_center()
		var gaze: String = "down" if (absf(to_rock.y) >= absf(to_rock.x) and to_rock.y > 0.0) else ("right" if to_rock.x > 0.0 else "left")
		var path: String = sprite.texture.resource_path
		if not path.ends_with("_%s.png" % gaze):
			wrong_gaze.append("%s mira a '%s' y debería mirar '%s'" % [sprite.name, path.get_file(), gaze])
	_check(wrong_gaze.is_empty(), "cada minero mira hacia la roca (%s)" % str(wrong_gaze))
	var gazes: Dictionary = {}
	for sprite: TextureRect in miners:
		gazes[sprite.texture.resource_path.get_file().trim_suffix(".png").split("_")[2]] = true
	_check_eq(gazes.keys().size(), 3, "y las tres miradas aparecen: izquierda, derecha y abajo (%s)" % str(gazes.keys()))
	# parados en el piso: una sombra elíptica bajo la roca y bajo cada sprite
	var shadows: Array = mine.shadow_ellipses()
	var casters: Array[TextureRect] = [rock]
	casters.append_array(crew)
	var visible_casters: Array[TextureRect] = []
	for caster: TextureRect in casters:
		if caster.visible:
			visible_casters.append(caster)
	_check_eq(shadows.size(), visible_casters.size(), "hay una sombra por cada sprite que se ve: roca, mineros, taladro y gólem (%d)" % shadows.size())
	var bad_shadows: Array[String] = []
	var shadowed: Dictionary = {}
	for shadow: Dictionary in shadows:
		var caster: TextureRect = shadow["sprite"]
		shadowed[caster] = true
		var rect: Rect2 = Rect2(caster.position, caster.size)
		var center: Vector2 = shadow["center"]
		var radius: Vector2 = shadow["radius"]
		var min_width: float = 0.42 if caster == rock else 0.3
		if absf(center.x - rect.get_center().x) > 1.0 or center.y < rect.position.y + 0.8 * rect.size.y or center.y > rect.end.y + 0.12 * rect.size.y:
			bad_shadows.append("%s: sombra fuera de los pies (%s)" % [caster.name, str(center)])
		if radius.x < min_width * rect.size.x or radius.y > radius.x * 0.5 or radius.y < radius.x * 0.12:
			bad_shadows.append("%s: no es una elipse chata y ancha (%s)" % [caster.name, str(radius)])
	_check(bad_shadows.is_empty(), "cada sombra es una elipse ancha y chata a los pies del sprite (%s)" % str(bad_shadows))
	_check_eq(shadowed.keys().size(), visible_casters.size(), "y no se repite ni falta ninguna")
	# tocar a un minero no cuenta como golpe: solo la roca
	for sprite: TextureRect in crew:
		_check_eq(sprite.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s no come toques (pasan a la roca)" % sprite.name)
	_economy.reset()
	await _free_host(scene)


func _test_relics_page(packed: PackedScene) -> void:
	_section("Cartel de Reliquias: runas")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_economy.reset()
	(_node(scene, "RelicsButton") as Button).pressed.emit()
	await process_frame
	var row: Control = _node(scene, "RelicsRow")
	_check_eq(row.get_child_count(), 0, "sin reliquias no hay runas")
	_economy.relics = 3
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check_eq(row.get_child_count(), 3, "con 3 reliquias se ven 3 runas")
	var paths: Dictionary = {}
	for rune: Node in row.get_children():
		_check_eq((rune as TextureRect).texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "cada runa se dibuja con filtro Nearest")
		paths[(rune as TextureRect).texture.resource_path] = true
	_check_eq(paths.size(), 3, "las runas alternan entre sus 3 símbolos")
	_economy.relics = 40
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(row.get_child_count() <= 8, "con 40 no se desborda la fila (%d runas)" % row.get_child_count())
	_check_eq(_label_in(scene, "RelicsLabel").text, "Reliquias: 40 · +1000% de oro", "y el contador dice la cantidad real (%s)" % _label_in(scene, "RelicsLabel").text)
	var panel: Control = _node(scene, "RelicsPanel").find_children("*", "PanelContainer", true, false)[0] as Control
	_check(Rect2(Vector2.ZERO, PHONE_SIZES[0]).encloses(panel.get_global_rect()), "el cartel entra en la pantalla (%s)" % str(panel.get_global_rect()))
	_economy.reset()
	await _free_host(scene)


func _test_theme(packed: PackedScene) -> void:
	_section("Tema de UI: UI Pack y Pixelify Sans")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_check(scene.theme != null and scene.theme.resource_path == "res://ui/theme.tres", "la escena usa res://ui/theme.tres")
	var font: Font = _label_in(scene, "GoldLabel").get_theme_font("font")
	_check(font is FontVariation and (font as FontVariation).base_font.resource_path.ends_with("PixelifySans.ttf"), "las etiquetas usan Pixelify Sans")
	var card_font: Font = (_pick_card(scene).find_children("*", "Label", true, false)[0] as Label).get_theme_font("font")
	_check(card_font is FontVariation and (card_font as FontVariation).base_font.resource_path.ends_with("PixelifySans.ttf"), "las tarjetas también")
	# los botones de acción usan el UI Pack: apretado = el botón plano (sin profundidad); deshabilitado = gris
	var prestige: Button = _node(scene, "PrestigeButton") as Button
	var pressed: StyleBox = prestige.get_theme_stylebox("pressed")
	_check(pressed is StyleBoxTexture and (pressed as StyleBoxTexture).texture.resource_path.ends_with("button_rectangle_flat.png"), "apretado: el botón plano, sin profundidad")
	var disabled: StyleBox = prestige.get_theme_stylebox("disabled")
	_check(disabled is StyleBoxTexture and (disabled as StyleBoxTexture).texture.resource_path.contains("/grey/"), "deshabilitado: gris")
	await _free_host(scene)


## Las mejoras en una grilla de dos columnas: el pico y los cinco generadores, todos a la vista sin deslizar,
## y la tarjeta entera es el botón de compra.
func _test_shop_grid(packed: PackedScene) -> void:
	_section("Mejoras en dos columnas, todas a la vista")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		var shop: GridContainer = _node(scene, "Shop") as GridContainer
		_check_eq(shop.columns, 2, "[%s] dos columnas" % label)
		_check_eq(shop.get_child_count(), 6, "[%s] seis tarjetas: el pico y los cinco generadores" % label)
		var cards: Array[Node] = shop.get_children()
		var first: Control = cards[0] as Control
		var second: Control = cards[1] as Control
		var third: Control = cards[2] as Control
		_check_near(first.global_position.y, second.global_position.y, "[%s] la primera y la segunda van en la misma fila" % label, 1e-6)
		_check(third.global_position.y > first.global_position.y and is_equal_approx(third.global_position.x, first.global_position.x), "[%s] la tercera abre otra fila" % label)
		var screen: Rect2 = Rect2(Vector2.ZERO, phone)
		var view: Rect2 = (shop.get_parent() as Control).get_global_rect()
		var hidden: Array[String] = []
		var uneven: bool = false
		for card: Node in cards:
			var rect: Rect2 = (card as Control).get_global_rect()
			if not screen.encloses(rect) or not view.grow(0.5).encloses(rect):
				hidden.append(str(card.name))
			if not rect.size.is_equal_approx(first.size):
				uneven = true
			_check(card is Button, "[%s] %s: la tarjeta entera es el botón" % [label, card.name])
		_check(hidden.is_empty(), "[%s] las seis se ven enteras sin deslizar (%s)" % [label, str(hidden)])
		_check(not uneven, "[%s] todas del mismo tamaño (%s)" % [label, str(first.size)])
		await _free_host(scene)

	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_economy.reset()
	_economy.gold = 160.0
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	var pick: Button = _pick_card(scene)
	var texts: Array[String] = _card_texts(pick)
	_check(texts.size() == 3 and texts[0].contains("Pico") and texts[0].contains("0"), "el pico: nombre y nivel (%s)" % str(texts))
	_check(texts.size() == 3 and texts[1].contains("Golpe") and texts[2].contains("150"), "lo que pega y el precio")
	var icons: Array[Node] = pick.find_children("*", "TextureRect", true, false)
	_check(icons.size() == 1 and (icons[0] as TextureRect).texture.resource_path.ends_with("pick.png"), "con el icono del pico")
	_check_eq((icons[0] as TextureRect).texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "pixel art nítido")
	var deaf: bool = true
	for node: Node in pick.find_children("*", "Control", true, false):
		if (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			deaf = false
	_check(deaf, "nada dentro de la tarjeta se come el toque")
	pick.pressed.emit()
	await process_frame
	_check_eq(_economy.pick_level, 1, "tocar la tarjeta mejora el pico")
	_check(_card_texts(pick)[0].contains("1"), "y muestra el nivel nuevo (%s)" % _card_texts(pick)[0])
	_economy.reset()
	await _free_host(scene)


## El color tiene un único significado: verde = se puede comprar, gris = no alcanza, rojo = solo el
## prestigio. Lo demás es neutro. (El amarillo era de la pestaña activa: ya no hay pestañas.)
func _test_button_roles(packed: PackedScene) -> void:
	_section("Colores: un rol por color")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_economy.reset()
	_economy.gold = 30.0 # alcanza el Minero (25), no el Taladro (600) ni el pico (150)
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	var buy_first: Button = _card(scene, 0)
	var buy_second: Button = _card(scene, 1)
	_check(not buy_first.disabled and _price_color(buy_first) == "green", "lo que se puede comprar: precio en verde (%s)" % _price_color(buy_first))
	_check(buy_second.disabled and _price_color(buy_second) == "grey", "lo que no alcanza: gris (%s)" % _price_color(buy_second))
	_check(_pick_card(scene).disabled and _price_color(_pick_card(scene)) == "grey", "el pico sin oro suficiente, gris")
	_check(_node(scene, "PrestigeButton").disabled and _style_name(_node(scene, "PrestigeButton") as Button) == "grey", "y el prestigio todavía no disponible también")
	_economy.gold = 160.0
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(not _pick_card(scene).disabled and _price_color(_pick_card(scene)) == "green", "con oro para el pico, verde")
	_economy.run_gold = 2.7e6 # ~451 m: se puede volver a la superficie
	_economy.gold_changed.emit(_economy.gold)
	await process_frame
	_check(not _node(scene, "PrestigeButton").disabled and _style_name(_node(scene, "PrestigeButton") as Button) == "red", "el prestigio disponible es rojo")
	var colored: Array[String] = []
	var red_names: Array[String] = []
	for button: Button in _game_buttons(scene):
		var style: String = _style_name(button)
		if style in ["blue", "yellow", "green"]:
			colored.append("%s (%s)" % [button.name, style])
		if style == "red":
			red_names.append(str(button.name))
	_check(colored.is_empty(), "no quedan botones azules ni amarillos (%s)" % str(colored))
	_check_eq(red_names, ["PrestigeButton"] as Array[String], "rojo solo el prestigio (%s)" % str(red_names))
	for side_name: String in ["LootButton", "RelicsButton", "ModeButton"]:
		_check_eq(_style_name(_node(scene, side_name) as Button), "flat", "%s es neutro" % side_name)

	# los botones del cartel: el prestigio es rojo; un aviso cualquiera es neutro
	var modal: Control = scene.get_node("Modal")
	_node(scene, "PrestigeButton").pressed.emit()
	await process_frame
	_check(modal.visible and _style_name(modal.confirm_button) == "red", "confirmar el prestigio es rojo (%s)" % _style_name(modal.confirm_button))
	_check_eq(_style_name(modal.cancel_button), "flat", "y cancelar es neutro")
	modal.close()
	modal.open("Aviso", "Cuerpo", "¡A seguir!")
	await process_frame
	_check_eq(_style_name(modal.confirm_button), "flat", "un aviso común se cierra con un botón neutro")
	modal.close()
	_economy.reset()
	await _free_host(scene)


## Los botones del juego (sin el panel de debug ni la roca), estén visibles o no.
func _game_buttons(scene: Control) -> Array[Button]:
	var buttons: Array[Button] = []
	var debug_panel: Node = scene.get_node_or_null("DebugPanel")
	for node: Node in scene.find_children("*", "Button", true, false):
		if node.name == "TapButton" or (debug_panel != null and debug_panel.is_ancestor_of(node)):
			continue
		if scene.get_node("Modal").is_ancestor_of(node):
			continue
		buttons.append(node as Button)
	return buttons


## "yellow", "green", "red" o "grey" si el botón se dibuja ahora con un botón del UI Pack de ese color
## (según su estado); "flat" si usa un estilo plano sin textura. El estado: deshabilitado, apretado
## (si es de selección y está marcado) o normal.
func _style_name(button: Button) -> String:
	var state: String = "disabled" if button.disabled else ("pressed" if button.toggle_mode and button.button_pressed else "normal")
	var style: StyleBox = button.get_theme_stylebox(state)
	if style is StyleBoxTexture and (style as StyleBoxTexture).texture != null:
		var parts: PackedStringArray = (style as StyleBoxTexture).texture.resource_path.split("/")
		return parts[parts.size() - 2]
	return "flat"


## Los avisos que salen arriba de la mina (cofre, bioma nuevo) no quedan debajo de los botones del costado.
func _test_toasts_clear_the_side_column(packed: PackedScene) -> void:
	_section("Los avisos de la mina no chocan con los botones del costado")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		var mine: Control = _node(scene, "MineView")
		# el aviso más ancho: cofre legendario con los porcentajes más largos
		mine.show_toast(load("res://assets/sprites/tiny_dungeon/tile_0089.png"), "¡Cofre Legendario!", "+60% » +54.4%", Color(1.0, 0.72, 0.2))
		mine.show_banner("Bioma Cristal", "×2.25 de oro", Color.CYAN)
		await create_timer(0.7).timeout
		for notice_name: String in ["ChestToast", "BiomeBanner"]:
			var notice: Control = mine.find_child(notice_name, true, false) as Control
			_check(notice != null, "[%s] sale %s" % [label, notice_name])
			if notice == null:
				continue
			var rect: Rect2 = notice.get_global_rect()
			var covered: Array[String] = []
			for side_name: String in ["LootButton", "RelicsButton", "ModeButton"]:
				if rect.intersects(_node(scene, side_name).get_global_rect()):
					covered.append(side_name)
			_check(covered.is_empty(), "[%s] %s no queda debajo de %s (%s)" % [label, notice_name, str(covered), str(rect)])
			_check(rect.position.x >= 0.0 and rect.end.x <= DESIGN_WIDTH, "[%s] y entra en la pantalla" % label)
		await _free_host(scene)


func _test_no_loot_hides_the_loot_button(packed: PackedScene) -> void:
	_section("Sin botín en el balance")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0], _balance_without_loot())
	_check(not _node(scene, "LootButton").visible, "no hay botón de Botín")
	_check(_node(scene, "RelicsButton").visible and _node(scene, "ModeButton").visible, "pero sí los otros dos")
	_check(not _node(scene, "LootBonusLabel").is_visible_in_tree(), "y el bonus de botín no se ve")
	await _free_host(scene)
