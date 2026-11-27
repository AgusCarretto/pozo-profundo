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
const StarSky := preload("res://game/star_sky.gd")
const CENTER_ICON: Texture2D = preload("res://assets/ui/game_icons/target.png")
const SPARK: Texture2D = preload("res://assets/particles/particle_pack/star_06.png")

const SPACING: float = 132.0
const BUTTON_HEIGHT: float = 104.0
const PRICE_HEIGHT: float = 40.0
const TOP_BUTTON_WIDTH: float = 160.0
## Cuánto hay que mover el dedo para que sea un arrastre y no un toque (px de diseño).
const DRAG_THRESHOLD: float = 18.0
## Aire alrededor del árbol al arrastrar: para ver entero el aviso de la estrella de la punta.
const PAN_MARGIN: float = 90.0
## El destello al comprar: cuántas chispas, cuánto duran y cuánto sube el sonido por nivel.
const BURST_AMOUNT: int = 22
const BURST_SECONDS: float = 0.7
const PITCH_PER_LEVEL: float = 0.07
## Cuánto se ve el aviso de anillo nuevo.
const BANNER_SECONDS: float = 3.0
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
var _banner: Label
var _banner_left: float = 0.0
## Los anillos que ya estaban abiertos la última vez que se miró (para avisar solo los nuevos).
var _open_rings: Array[int] = []


func _init() -> void:
	name = "TreeView"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	add_child(StarSky.new())
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
	_build_banner()
	sync_rings()
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
	_banner_left = 0.0
	_banner.visible = false
	Audio.play_sfx("close")
	closed.emit()


func star_button(id: String) -> Button:
	return _stars.get(id) as Button


func select(id: String) -> void:
	if not _stars.has(id):
		return
	selected = id
	_refresh()


func _process(delta: float) -> void:
	if visible and _dirty:
		_refresh()
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.visible = _banner_left > 0.0
		_banner.modulate.a = clampf(_banner_left / 0.5, 0.0, 1.0)


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
	center.icon = CENTER_ICON
	center.add_theme_constant_override("icon_max_width", 30)
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
		# El aviso de cambio pendiente va del lado donde no está la estrella de la que cuelga.
		star.balloon_above = (data.get("from", []) as Array).any(func(parent: Variant) -> bool:
			return _at(Economy.relic_tree.star(str(parent))).y > _at(data).y)
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
	bounds = bounds.grow(PAN_MARGIN)
	var half: Vector2 = _viewport.size * 0.5
	_pan.x = clampf(_pan.x, minf(0.0, half.x - bounds.end.x), maxf(0.0, -half.x - bounds.position.x))
	_pan.y = clampf(_pan.y, minf(0.0, half.y - bounds.end.y), maxf(0.0, -half.y - bounds.position.y))
	_canvas.position = (half + _pan).round()


# --- Mostrar ----------------------------------------------------------------------

func _refresh() -> void:
	_dirty = false
	if not Economy.has_tree():
		return
	_announce_new_rings()
	var available: int = Economy.available_relics()
	_available_label.text = "1 reliquia para gastar" if available == 1 else "%d reliquias para gastar" % available
	for id: String in _stars:
		var star: TreeStar = _stars[id]
		star.show_state(Economy.star_state(id), Economy.relic_tree.level(id), Economy.relic_tree.max_level(id), id == selected, Economy.keystone_pending(id))
	_canvas.queue_redraw()
	_refresh_detail()


func _refresh_detail() -> void:
	var tree: RelicTree = Economy.relic_tree
	var data: Dictionary = tree.star(selected)
	var state: int = Economy.star_state(selected)
	# La visibilidad de los botones se fija una sola vez: esto corre en cada cuadro mientras la cuadrilla produce, y
	# ocultar un botón un instante cancela el toque que lo esté apretando (no se podía comprar en plena bajada).
	var known: bool = state != RelicTree.State.HIDDEN and state != RelicTree.State.SEALED
	_buy_button.visible = known
	_keystone_button.visible = known and tree.is_keystone(selected) and tree.level(selected) > 0
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
	if level >= top:
		_show_price("Al máximo", "—", false)
	else:
		var cost: int = tree.next_cost(selected)
		_show_price("Comprar", "1 reliquia" if cost == 1 else "%d reliquias" % cost, Economy.can_buy_star(selected))
	if tree.is_keystone(selected) and level > 0:
		var chosen: bool = tree.planned_keystones.has(selected)
		var pending: int = Economy.keystone_pending(selected)
		if pending != 0:
			_keystone_button.text = "Cambio anotado\ntocá para cancelar"
			lines.append("Activa desde la próxima bajada." if pending > 0 else "Se apaga en la próxima bajada.")
		else:
			_keystone_button.text = "Activa\ntocá para apagar" if chosen else "Apagada\ntocá para prender"
		var full: bool = not chosen and tree.planned_keystones.size() >= tree.max_keystones()
		_keystone_button.disabled = full
		if full:
			lines.append("Ya hay %d piedras elegidas: apagá otra primero." % tree.max_keystones())
		elif pending == 0 and not Economy.at_surface:
			lines.append("Los cambios valen desde la próxima bajada.")
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
	# Suena más agudo cuanto más alto el nivel.
	Audio.play_sfx("star_buy", 1.0 + PITCH_PER_LEVEL * (Economy.relic_tree.level(selected) - 1))
	Juice.bounce(_stars[selected])
	_burst(_stars[selected])
	_refresh()


## Chispas del color de la rama que salen de la estrella comprada.
func _burst(star: TreeStar) -> void:
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.name = "Burst"
	sparks.position = star.position + star.size * 0.5
	sparks.texture = SPARK
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = BURST_AMOUNT / 3 if Settings.reduce_effects else BURST_AMOUNT
	sparks.lifetime = BURST_SECONDS
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 140.0
	sparks.initial_velocity_max = 300.0
	sparks.damping_min = 200.0
	sparks.damping_max = 320.0
	sparks.scale_amount_min = 24.0 / SPARK.get_width()
	sparks.scale_amount_max = 64.0 / SPARK.get_width()
	sparks.color = star.branch_color.lerp(Color.WHITE, 0.35)
	var fade: Gradient = Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	sparks.color_ramp = fade
	_canvas.add_child(sparks, true)
	sparks.emitting = true
	get_tree().create_timer(BURST_SECONDS + 0.3).timeout.connect(sparks.queue_free)


func _build_banner() -> void:
	_banner = Label.new()
	_banner.name = "RingBanner"
	_banner.text = "¡Nueva zona del cielo!"
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 24.0
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_color_override("font_color", Palette.YELLOW)
	_banner.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_banner.add_theme_constant_override("outline_size", 12)
	_viewport.add_child(_banner)


## Los anillos abiertos ahora, sin avisar (al armar la pantalla o al cambiar de partida).
func sync_rings() -> void:
	_open_rings = _rings_open_now()


func _rings_open_now() -> Array[int]:
	var open: Array[int] = []
	if Economy.has_tree():
		for ring: int in range(4):
			if Economy.relic_tree.ring_open(ring, Economy.record_depth_now(), Economy.resets):
				open.append(ring)
	return open


func _announce_new_rings() -> void:
	var now: Array[int] = _rings_open_now()
	if now.any(func(ring: int) -> bool: return not _open_rings.has(ring)):
		_banner_left = BANNER_SECONDS
		_banner.visible = true
		_banner.modulate.a = 1.0
		Audio.play_sfx("ring_open")
	_open_rings = now


func _on_keystone() -> void:
	if Economy.set_keystone(selected, not Economy.relic_tree.planned_keystones.has(selected)):
		Audio.play_sfx("toggle")
		_refresh()
