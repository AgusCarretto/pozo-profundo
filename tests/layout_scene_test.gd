extends "res://tests/test_base.gd"
## Tests headless del layout y el arte de la escena principal (F2-A): HUD arriba, mina al medio y
## panel con pestañas abajo, en las proporciones de un celular vertical.
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
	await _test_tabs(packed)
	await _test_hud(packed)
	await _test_text_is_not_cut(packed)
	await _test_overlays_draw_on_top(packed)
	await _test_mine_view(packed)
	await _test_relics_page(packed)
	await _test_theme(packed)
	await _test_no_loot_hides_the_loot_tab(packed)
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
		_check(bottom.global_position.y >= mine.global_position.y + mine.size.y - 0.5, "[%s] el panel de pestañas está debajo de la mina" % label)
		_check_near(bottom.global_position.y + bottom.size.y, phone.y, "[%s] y llega hasta el borde de abajo" % label, 1e-4)
		for part: Control in [hud, mine, bottom]:
			_check_near(part.size.x, DESIGN_WIDTH, "[%s] %s ocupa todo el ancho" % [label, part.name], 1e-4)
		_check(hud.size.y <= phone.y * 0.25, "[%s] el HUD no pasa del 25%% del alto (%d de %d)" % [label, int(hud.size.y), int(phone.y)])
		_check(mine.size.y >= 380.0, "[%s] la mina tiene lugar para la roca y la cuadrilla (%d px)" % [label, int(mine.size.y)])
		_check(bottom.size.y >= 520.0, "[%s] el panel de abajo tiene lugar para pestañas y lista (%d px)" % [label, int(bottom.size.y)])
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
		_check(rock.size.x >= 192.0 and rock.size.x <= 288.0, "[%s] la roca es grande (%d px)" % [label, int(rock.size.x)])
		_check(mine.get_global_rect().encloses(rock.get_global_rect()), "[%s] y entra entera en la mina" % label)
		await _free_host(scene)


func _test_touch_targets(packed: PackedScene) -> void:
	_section("Botones de al menos 48 px de alto en un celular de 360 px (96 px de diseño)")
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		_economy.gold = 1.0e6 # con oro hay filas con botón de compra habilitado
		_economy.gold_changed.emit(_economy.gold)
		await process_frame
		var too_small: Array[String] = []
		var count: int = 0
		for button: Button in _visible_buttons(scene):
			if button.name == "TapButton":
				continue # la roca entera es el botón: es enorme
			count += 1
			if button.size.y < TOUCH_MIN - 0.5:
				too_small.append("%s (%d px)" % [button.name, int(button.size.y)])
		_check(count >= 9, "[%s] hay botones que mirar: pestañas, modos, pico y compras (%d)" % [label, count])
		_check(too_small.is_empty(), "[%s] ningún botón mide menos de %d px de alto (%s)" % [label, int(TOUCH_MIN), str(too_small)])
		for tab: String in ["TabCrewButton", "TabLootButton", "TabRelicsButton"]:
			_check(_node(scene, tab).size.y >= TOUCH_MIN - 0.5, "[%s] %s mide %d px" % [label, tab, int(_node(scene, tab).size.y)])
		# los de las otras pestañas (el botón de prestigio) y los del cartel
		(_node(scene, "TabRelicsButton") as Button).button_pressed = true
		await process_frame
		_check(_node(scene, "PrestigeButton").size.y >= TOUCH_MIN - 0.5, "[%s] el botón de volver a la superficie mide %d px" % [label, int(_node(scene, "PrestigeButton").size.y)])
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


func _test_tabs(packed: PackedScene) -> void:
	_section("Panel de pestañas: Cuadrilla, Botín y Reliquias")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	var crew: Control = _node(scene, "CrewPage")
	var loot: Control = _node(scene, "LootPage")
	var relics: Control = _node(scene, "RelicsPage")
	var tab_crew: Button = _node(scene, "TabCrewButton") as Button
	var tab_loot: Button = _node(scene, "TabLootButton") as Button
	var tab_relics: Button = _node(scene, "TabRelicsButton") as Button
	_check_eq(tab_crew.text, "Cuadrilla", "primera pestaña: Cuadrilla")
	_check_eq(tab_loot.text, "Botín", "segunda: Botín")
	_check_eq(tab_relics.text, "Reliquias", "tercera: Reliquias")
	_check(tab_crew.global_position.x < tab_loot.global_position.x and tab_loot.global_position.x < tab_relics.global_position.x, "van en ese orden, de izquierda a derecha")
	_check_near(tab_crew.size.x, tab_loot.size.x, "las pestañas miden lo mismo", 0.02)
	_check(tab_crew.button_pressed and not tab_loot.button_pressed and not tab_relics.button_pressed, "arranca en Cuadrilla")
	_check(crew.visible and not loot.visible and not relics.visible, "y solo se ve la lista de la cuadrilla")
	_check(_node(scene, "GeneratorList").is_visible_in_tree() and _node(scene, "PickButton").is_visible_in_tree(), "con el pico y los generadores a la vista")
	tab_loot.button_pressed = true
	await process_frame
	_check(loot.visible and not crew.visible and not relics.visible, "Botín muestra solo el botín")
	_check(not tab_crew.button_pressed and tab_loot.button_pressed, "y la pestaña queda marcada (una sola a la vez)")
	_check(_node(scene, "LootBonusLabel").is_visible_in_tree() and _node(scene, "OddsRow").is_visible_in_tree(), "con las probabilidades y el bonus a la vista")
	tab_relics.button_pressed = true
	await process_frame
	_check(relics.visible and not crew.visible and not loot.visible, "Reliquias muestra solo las reliquias")
	_check(_node(scene, "PrestigeButton").is_visible_in_tree() and _node(scene, "RelicsLabel").is_visible_in_tree(), "con el botón de volver a la superficie")
	tab_crew.button_pressed = true
	await process_frame
	_check(crew.visible and not loot.visible and not relics.visible, "volver a Cuadrilla la muestra de nuevo")
	# tocar la pestaña ya activa no la apaga: el grupo no deja desmarcar (siempre hay una)
	_check(tab_crew.button_group != null and not tab_crew.button_group.allow_unpress, "tocar la pestaña activa no la apaga (el grupo no deja desmarcar)")
	_check(tab_crew.button_group == tab_loot.button_group and tab_loot.button_group == tab_relics.button_group, "las tres son del mismo grupo")
	await _free_host(scene)


func _test_hud(packed: PackedScene) -> void:
	_section("HUD: oro, oro/s, profundidad con barra al próximo bioma y multiplicador")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_economy.reset()
	await process_frame
	_check((_node(scene, "CoinIcon") as TextureRect).texture != null, "el oro lleva su moneda")
	_check_eq(_label_in(scene, "GoldLabel").text, "0", "oro: 0")
	_check(_label_in(scene, "RateLabel").text.contains("oro/s"), "oro/s (%s)" % _label_in(scene, "RateLabel").text)
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
	_economy.reset()
	await _free_host(scene)


## El texto más largo posible no se corta: el ancho del texto entra en el de su etiqueta. (Las cajas
## no alcanzan: una etiqueta con clip_text se ve "bien" por fuera aunque se coma el final del texto.)
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
	]
	for phone: Vector2 in PHONE_SIZES:
		var scene: Control = await _mount_host(packed, phone)
		var label: String = "%dx%d" % [int(phone.x), int(phone.y)]
		var cut: Array[String] = []
		for state: Dictionary in states:
			_economy.reset()
			_economy.run_gold = state["run_gold"]
			_economy.gold = state["gold"]
			_economy.relics = state["relics"]
			_economy.pick_level = 9
			_economy.loot_bonus = 5.0
			_economy.owned[0] = 1234
			_economy.owned[2] = 1234 # Cuadrilla de dinamita: el nombre más largo
			_economy.gold_changed.emit(_economy.gold)
			await process_frame
			await process_frame
			for node: Node in scene.find_children("*", "Label", true, false):
				var text_label: Label = node as Label
				if not text_label.is_visible_in_tree() or text_label.autowrap_mode != TextServer.AUTOWRAP_OFF:
					continue
				if scene.get_node("DebugPanel").is_ancestor_of(text_label) or _inside_scroll_container(text_label, scene, "GeneratorList"):
					continue
				var font: Font = text_label.get_theme_font("font")
				var font_size: int = text_label.get_theme_font_size("font_size")
				for line: String in text_label.text.split("\n"):
					var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					if width > text_label.size.x + 0.5:
						cut.append("%s '%s' (%d > %d px)" % [text_label.name, line, int(width), int(text_label.size.x)])
		_check(cut.is_empty(), "[%s] los textos del HUD y de las pestañas entran en su etiqueta (%s)" % [label, str(cut)])
		# las filas de la cuadrilla: el nombre largo se parte en dos líneas, no se corta ni agranda la fila
		var rows: Array[Node] = _node(scene, "GeneratorList").get_children()
		var tall_rows: Array[String] = []
		for row: Node in rows:
			if (row as Control).size.y > 150.0:
				tall_rows.append("%s (%d px)" % [row.name, int((row as Control).size.y)])
		_check(tall_rows.is_empty(), "[%s] ninguna fila de generador se agranda de más (%s)" % [label, str(tall_rows)])
		var row_text_cut: Array[String] = []
		for row: Node in rows:
			for node: Node in row.find_children("*", "Label", true, false):
				var row_label: Label = node as Label
				var row_font: Font = row_label.get_theme_font("font")
				var row_size: int = row_label.get_theme_font_size("font_size")
				var full: float = row_font.get_string_size(row_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, row_size).x
				# con autowrap el texto se parte en varias líneas (no se corta): alcanza con que la fila no crezca (arriba)
				if row_label.autowrap_mode == TextServer.AUTOWRAP_OFF and full > row_label.size.x + 0.5:
					row_text_cut.append("'%s' (%d > %d px)" % [row_label.text, int(full), int(row_label.size.x)])
		_check(row_text_cut.is_empty(), "[%s] y ningún texto de las filas se corta (%s)" % [label, str(row_text_cut)])
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
	_economy.reset()
	await _free_host(scene)


func _inside_scroll_container(control: Control, scene: Control, container_name: String) -> bool:
	var node: Node = control.get_parent()
	while node != null and node != scene:
		if node.name == container_name:
			return true
		node = node.get_parent()
	return false


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
	# nadie se pisa con la roca ni se sale de la mina
	var mine_rect: Rect2 = mine.get_global_rect()
	var out_of_mine: Array[String] = []
	var on_rock: Array[String] = []
	var rock_rect: Rect2 = rock.get_global_rect()
	var crew: Array[TextureRect] = [mine.drill_sprite, mine.golem_sprite]
	crew.append_array(miners)
	for sprite: TextureRect in crew:
		if not mine_rect.encloses(sprite.get_global_rect()):
			out_of_mine.append("%s %s" % [sprite.name, str(sprite.get_global_rect())])
		if sprite.get_global_rect().intersection(rock_rect).get_area() > sprite.get_global_rect().get_area() * 0.2:
			on_rock.append(sprite.name)
	_check(out_of_mine.is_empty(), "toda la cuadrilla entra en la mina (%s)" % str(out_of_mine))
	_check(on_rock.is_empty(), "y nadie tapa la roca (%s)" % str(on_rock))
	# tocar a un minero no cuenta como golpe: solo la roca
	for sprite: TextureRect in crew:
		_check_eq(sprite.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s no come toques (pasan a la roca)" % sprite.name)
	_economy.reset()
	await _free_host(scene)


func _test_relics_page(packed: PackedScene) -> void:
	_section("Pestaña Reliquias: runas")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_economy.reset()
	(_node(scene, "TabRelicsButton") as Button).button_pressed = true
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
	_economy.reset()
	await _free_host(scene)


func _test_theme(packed: PackedScene) -> void:
	_section("Tema de UI: UI Pack y Pixelify Sans")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0])
	_check(scene.theme != null and scene.theme.resource_path == "res://ui/theme.tres", "la escena usa res://ui/theme.tres")
	var font: Font = _label_in(scene, "GoldLabel").get_theme_font("font")
	_check(font is FontVariation and (font as FontVariation).base_font.resource_path.ends_with("PixelifySans.ttf"), "las etiquetas usan Pixelify Sans")
	var button_font: Font = (_node(scene, "PickButton") as Button).get_theme_font("font")
	_check(button_font is FontVariation and (button_font as FontVariation).base_font.resource_path.ends_with("PixelifySans.ttf"), "los botones también")
	var expectations: Dictionary = { "PickButton": "/yellow/", "PrestigeButton": "/red/", "TabCrewButton": "/grey/", "Mode1Button": "/grey/" }
	for node_name: String in expectations:
		var style: StyleBox = (_node(scene, node_name) as Button).get_theme_stylebox("normal")
		_check(style is StyleBoxTexture and (style as StyleBoxTexture).texture.resource_path.contains("ui_pack" + expectations[node_name]), "%s usa un botón del UI Pack (%s)" % [node_name, expectations[node_name]])
	# el apretado es el plano (sin profundidad) y el deshabilitado, gris
	var pressed: StyleBox = (_node(scene, "PickButton") as Button).get_theme_stylebox("pressed")
	_check(pressed is StyleBoxTexture and (pressed as StyleBoxTexture).texture.resource_path.ends_with("button_rectangle_flat.png"), "apretado: el botón plano, sin profundidad")
	var disabled: StyleBox = (_node(scene, "PickButton") as Button).get_theme_stylebox("disabled")
	_check(disabled is StyleBoxTexture and (disabled as StyleBoxTexture).texture.resource_path.contains("/grey/"), "deshabilitado: gris")
	_check((_node(scene, "TabCrewButton") as Button).toggle_mode, "las pestañas son de selección (toggle)")
	await _free_host(scene)


func _test_no_loot_hides_the_loot_tab(packed: PackedScene) -> void:
	_section("Sin botín en el balance")
	var scene: Control = await _mount_host(packed, PHONE_SIZES[0], _balance_without_loot())
	_check(not _node(scene, "TabLootButton").visible, "no hay pestaña de Botín")
	_check(_node(scene, "TabCrewButton").visible and _node(scene, "TabRelicsButton").visible, "pero sí las otras dos")
	_check(not _node(scene, "LootBonusLabel").is_visible_in_tree(), "y el bonus de botín no se ve")
	await _free_host(scene)
