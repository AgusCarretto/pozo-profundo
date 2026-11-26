extends Control
## La pantalla del árbol de reliquias (interfaz mínima de la build de prueba): las estrellas unidas por líneas, que se
## arrastran con el dedo, y abajo el panel de la elegida con su botón de compra. Las reglas están en Economy y
## core/relic_tree.gd; acá solo se muestran y se piden.

signal opened
signal closed

const Palette := preload("res://game/palette.gd")
const RelicTree := preload("res://core/relic_tree.gd")
const TreeStar := preload("res://game/tree_star.gd")
const Juice := preload("res://game/juice.gd")

const SPACING: float = 132.0
const BUTTON_HEIGHT: float = 104.0
const PRICE_HEIGHT: float = 40.0
const TOP_BUTTON_WIDTH: float = 160.0
## Cuánto hay que mover el dedo para que sea un arrastre y no un toque (px de diseño).
const DRAG_THRESHOLD: float = 18.0
const COLORS: Dictionary = {
	"frost": Palette.FROST, "clay": Palette.CLAY, "yellow": Palette.YELLOW, "purple": Palette.PURPLE,
	"blue": Palette.BLUE, "steel_light": Palette.STEEL_LIGHT,
}

## La estrella que muestra el panel.
var selected: String = "core"

var _stars: Dictionary = {}
var _viewport: Control
var _canvas: Control
var _available_label: Label
var _name_label: Label
var _text_label: Label
var _buy_button: Button
var _buy_title: Label
var _price_box: PanelContainer
var _price_label: Label
var _keystone_button: Button
var _pan: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _dragged: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _dirty: bool = true


func _init() -> void:
	name = "TreeView"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var sky: ColorRect = ColorRect.new()
	sky.color = Palette.OUTLINE.darkened(0.45)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	column.add_child(_build_top())
	_viewport = Control.new()
	_viewport.name = "Viewport"
	_viewport.clip_contents = true
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport.resized.connect(_place_canvas)
	column.add_child(_viewport)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_links)
	_viewport.add_child(_canvas)
	column.add_child(_build_detail())
	_build_stars()
	Economy.tree_changed.connect(_mark_dirty)
	Economy.gold_changed.connect(_mark_dirty.unbind(1))
	Economy.prestiged.connect(_mark_dirty.unbind(1))


func open() -> void:
	if visible or not Economy.has_tree():
		return
	visible = true
	_pan = Vector2.ZERO
	_pressing = false
	_dragged = false
	_place_canvas()
	_refresh()
	Audio.play_sfx("tab")
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	Audio.play_sfx("close")
	closed.emit()


func star_button(id: String) -> Button:
	return _stars.get(id) as Button


func select(id: String) -> void:
	if not _stars.has(id):
		return
	selected = id
	_refresh()


func _process(_delta: float) -> void:
	if visible and _dirty:
		_refresh()


func _mark_dirty() -> void:
	_dirty = true


# --- Armado -----------------------------------------------------------------------

func _build_top() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"HudPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_available_label = Label.new()
	_available_label.name = "AvailableLabel"
	_available_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_available_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_available_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_available_label.add_theme_font_size_override("font_size", 28)
	row.add_child(_available_label)
	var center: Button = _button("CenterTree", "Centrar", &"ButtonNeutral", TOP_BUTTON_WIDTH)
	center.pressed.connect(func() -> void:
		_pan = Vector2.ZERO
		_place_canvas())
	row.add_child(center)
	var shut: Button = _button("CloseTree", "Cerrar", &"ButtonNeutral", TOP_BUTTON_WIDTH)
	shut.pressed.connect(close)
	row.add_child(shut)
	return panel


func _build_detail() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Detail"
	panel.theme_type_variation = &"BottomPanel"
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_name_label = Label.new()
	_name_label.name = "StarName"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 34)
	box.add_child(_name_label)
	_text_label = Label.new()
	_text_label.name = "StarText"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 150)
	_text_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_text_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	box.add_child(row)
	_buy_button = _button("BuyButton", "", &"CardButton", 0.0)
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_button.pressed.connect(_on_buy)
	row.add_child(_buy_button)
	_build_price(_buy_button)
	_keystone_button = _button("KeystoneButton", "", &"ButtonNeutral", 0.0)
	_keystone_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keystone_button.pressed.connect(_on_keystone)
	row.add_child(_keystone_button)
	return panel


## Como las tarjetas de la tienda: el botón es neutro y el verde (alcanza) o gris (no) va en la franja del precio.
func _build_price(button: Button) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	button.add_child(box)
	_buy_title = Label.new()
	_buy_title.theme_type_variation = &"CardNameLabel"
	_buy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_buy_title)
	_price_box = PanelContainer.new()
	_price_box.custom_minimum_size = Vector2(0, PRICE_HEIGHT)
	_price_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_price_box)
	_price_label = Label.new()
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_box.add_child(_price_label)


func _show_price(title: String, price: String, affordable: bool) -> void:
	_buy_title.text = title
	_price_label.text = price
	_buy_button.disabled = not affordable
	_price_box.theme_type_variation = &"PriceGreen" if affordable else &"PriceGrey"
	_price_label.theme_type_variation = &"PriceLabel" if affordable else &"PriceOffLabel"


func _button(node_name: String, text: String, variation: StringName, width: float) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 26)
	return button


func _build_stars() -> void:
	if not Economy.has_tree():
		return
	for id: String in Economy.relic_tree.ids():
		var data: Dictionary = Economy.relic_tree.star(id)
		var branch: Dictionary = Economy.relic_tree.branch(id)
		var star: TreeStar = TreeStar.new()
		star.setup(id, str(branch.get("shape", "circle")), COLORS.get(str(branch.get("color", "")), Palette.FROST), Economy.relic_tree.is_keystone(id))
		star.position = _at(data) - star.custom_minimum_size * 0.5
		star.pressed.connect(_on_star_pressed.bind(id))
		_canvas.add_child(star)
		_stars[id] = star


func _at(data: Dictionary) -> Vector2:
	var pos: Array = data.get("pos", [0, 0])
	return Vector2(float(pos[0]), float(pos[1])) * SPACING


# --- Arrastre ---------------------------------------------------------------------

## Los toques llegan como mouse (Godot lo emula). Se miran acá, antes que los botones, para que un arrastre que empieza
## sobre una estrella mueva el árbol y no la elija.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_pressing = false
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click: InputEventMouseButton = event
		if click.pressed:
			_dragged = false
			_pressing = _viewport.get_global_rect().has_point(click.position)
			_press_at = click.position
		else:
			_pressing = false
	elif event is InputEventMouseMotion and _pressing:
		var motion: InputEventMouseMotion = event
		if not _dragged and motion.position.distance_to(_press_at) > DRAG_THRESHOLD:
			_dragged = true
			_pan += motion.position - _press_at
			_place_canvas()
		elif _dragged:
			_pan += motion.relative
			_place_canvas()


## Pone el Corazón en el centro, corrido por el arrastre, sin dejar que el árbol se pierda de vista.
func _place_canvas() -> void:
	if _viewport == null or _stars.is_empty():
		return
	var bounds: Rect2 = Rect2()
	for star: Control in _stars.values():
		var rect: Rect2 = Rect2(star.position, star.custom_minimum_size)
		bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
	var half: Vector2 = _viewport.size * 0.5
	_pan.x = clampf(_pan.x, minf(0.0, half.x - bounds.end.x), maxf(0.0, -half.x - bounds.position.x))
	_pan.y = clampf(_pan.y, minf(0.0, half.y - bounds.end.y), maxf(0.0, -half.y - bounds.position.y))
	_canvas.position = (half + _pan).round()


# --- Mostrar ----------------------------------------------------------------------

func _refresh() -> void:
	_dirty = false
	if not Economy.has_tree():
		return
	var available: int = Economy.available_relics()
	_available_label.text = "1 reliquia para gastar" if available == 1 else "%d reliquias para gastar" % available
	for id: String in _stars:
		var star: TreeStar = _stars[id]
		star.show_state(Economy.star_state(id), Economy.relic_tree.level(id), Economy.relic_tree.max_level(id), id == selected)
	_canvas.queue_redraw()
	_refresh_detail()


func _refresh_detail() -> void:
	var tree: RelicTree = Economy.relic_tree
	var data: Dictionary = tree.star(selected)
	var state: int = Economy.star_state(selected)
	_keystone_button.visible = false
	_buy_button.visible = false
	if state == RelicTree.State.HIDDEN:
		_name_label.text = "???"
		if data.has("requires_max"):
			_text_label.text = "Todavía no se ve. Antes llevá al máximo la estrella anterior."
		elif data.has("bridge"):
			_text_label.text = "Une dos piedras angulares: comprá las dos para verla."
		else:
			_text_label.text = "Todavía no se ve. Encendé una estrella vecina."
		return
	if state == RelicTree.State.SEALED:
		var ring: int = int(data.get("ring", 0))
		var gate: Dictionary = tree.ring_requirement(ring)
		_name_label.text = "Estrella sellada"
		if gate.is_empty():
			_text_label.text = "Se abre con tu primera vuelta a la superficie."
		else:
			_text_label.text = "Anillo %d: llegá a %d m y volvé %d veces a la superficie.\nLlevás %d m y %d veces." % [
				ring, int(gate["depth"]), gate["resets"], int(Economy.record_depth_now()), Economy.resets]
		return
	var level: int = tree.level(selected)
	var top: int = tree.max_level(selected)
	_name_label.text = str(data["name"])
	var lines: Array[String] = ["%s%s · Nivel %d de %d" % [str(tree.branch(selected).get("name", "")), " · piedra angular" if tree.is_keystone(selected) else "", level, top], str(data["description"])]
	_buy_button.visible = true
	if level >= top:
		_show_price("Al máximo", "—", false)
	else:
		var cost: int = tree.next_cost(selected)
		_show_price("Comprar", "1 reliquia" if cost == 1 else "%d reliquias" % cost, Economy.can_buy_star(selected))
	if tree.is_keystone(selected) and level > 0:
		var active: bool = tree.active_keystones.has(selected)
		_keystone_button.visible = true
		_keystone_button.text = "Activa\ntocá para apagar" if active else "Apagada\ntocá para prender"
		var full: bool = not active and tree.active_keystones.size() >= tree.max_keystones()
		_keystone_button.disabled = full or not Economy.at_surface or Economy.resets < 1
		if full:
			lines.append("Ya hay %d piedras activas: apagá otra primero." % tree.max_keystones())
		elif not Economy.at_surface:
			lines.append("Se cambian recién vuelto a la superficie.")
	_text_label.text = "\n".join(lines)


func _draw_links() -> void:
	if not Economy.has_tree():
		return
	var tree: RelicTree = Economy.relic_tree
	for id: String in _stars:
		var data: Dictionary = tree.star(id)
		var to: Vector2 = _at(data)
		var parents: Array = (data.get("from", []) as Array).duplicate()
		if data.has("requires_max") and not parents.has(data["requires_max"]):
			parents.append(data["requires_max"])
		for parent: String in parents:
			var lit: bool = tree.level(parent) > 0 and tree.level(id) > 0
			_canvas.draw_line(_at(tree.star(parent)), to, Palette.FROST if lit else Palette.SLATE, 6.0 if lit else 3.0, true)
		for end: String in data.get("bridge", []):
			var both: bool = tree.level(end) > 0 and tree.level(id) > 0
			_canvas.draw_dashed_line(_at(tree.star(end)), to, Palette.FROST if both else Palette.SLATE, 3.0, 14.0)


# --- Toques -----------------------------------------------------------------------

func _on_star_pressed(id: String) -> void:
	if _dragged:
		return
	Audio.play_sfx("mode")
	select(id)


func _on_buy() -> void:
	if not Economy.buy_star(selected):
		return
	Audio.play_sfx("relic")
	Juice.bounce(_stars[selected])
	_refresh()


func _on_keystone() -> void:
	if Economy.set_keystone(selected, not Economy.relic_tree.active_keystones.has(selected)):
		Audio.play_sfx("toggle")
		_refresh()
