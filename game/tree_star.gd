extends Button
## Una estrella del árbol: un botón sin estilo que se dibuja solo. Cada rama tiene su forma (además de su color y su
## brillo, para quien no distingue colores o mira en una pantalla chica); las piedras angulares son más grandes y con
## doble borde. Comprada: llena; disponible: borde del color de la rama; oculta o sellada: apagada con "?".

const Palette := preload("res://game/palette.gd")
const RelicTree := preload("res://core/relic_tree.gd")

const SIZE: float = 108.0
const KEYSTONE_SIZE: float = 128.0
const MARGIN: float = 8.0
const FONT_SIZE: int = 24

var id: String = ""
## "triangle", "diamond", "square", "circle", "star" o "hexagon" (data/arbol.json).
var shape: String = "circle"
var branch_color: Color = Color.WHITE
var keystone: bool = false

var _state: int = RelicTree.State.HIDDEN
var _label: String = ""
var _selected: bool = false


func setup(star_id: String, star_shape: String, color: Color, is_keystone: bool) -> void:
	id = star_id
	name = "Star_" + star_id
	shape = star_shape
	branch_color = color
	keystone = is_keystone
	var side: float = KEYSTONE_SIZE if keystone else SIZE
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	for style: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())


func show_state(state: int, level: int, max_level: int, selected: bool) -> void:
	_state = state
	_selected = selected
	if state == RelicTree.State.HIDDEN or state == RelicTree.State.SEALED:
		_label = "?"
	elif max_level > 1:
		_label = "%d/%d" % [level, max_level]
	else:
		_label = ""
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = size.x * 0.5 - MARGIN
	var owned: bool = _state == RelicTree.State.OWNED
	var open: bool = _state == RelicTree.State.OPEN
	var fill: Color = branch_color if owned else (Palette.NAVY if open else Palette.NAVY.lerp(Palette.SLATE, 0.35))
	var border: Color = Palette.FROST if owned else (branch_color if open else Palette.SLATE_LIGHT)
	var width: float = 6.0 if open else 4.0
	var points: PackedVector2Array = _outline(center, radius)
	draw_colored_polygon(points, fill)
	_stroke(points, border, width)
	if keystone:
		_stroke(_outline(center, radius - 11.0), Palette.OUTLINE if owned else border, 3.0)
	if _selected:
		draw_arc(center, size.x * 0.5 - 2.0, 0.0, TAU, 48, Palette.WHITE, 4.0, true)
	if _label == "":
		return
	var font: Font = get_theme_font("font")
	var color: Color = Palette.OUTLINE if owned and branch_color.srgb_to_linear().get_luminance() > 0.3 else Palette.WHITE
	if not owned and not open:
		color = Palette.STEEL
	var text_size: Vector2 = font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var drop: float = radius * 0.18 if shape == "triangle" else 0.0
	draw_string(font, center + Vector2(-text_size.x * 0.5, FONT_SIZE * 0.35 + drop), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


func _outline(center: Vector2, radius: float) -> PackedVector2Array:
	match shape:
		"triangle":
			var middle: Vector2 = center + Vector2(0.0, radius * 0.12)
			return PackedVector2Array([middle + Vector2(0.0, -radius * 1.1), middle + Vector2(radius * 1.05, radius * 0.75), middle + Vector2(-radius * 1.05, radius * 0.75)])
		"diamond":
			return PackedVector2Array([center + Vector2(0.0, -radius), center + Vector2(radius, 0.0), center + Vector2(0.0, radius), center + Vector2(-radius, 0.0)])
		"square":
			var half: float = radius * 0.84
			return PackedVector2Array([center + Vector2(-half, -half), center + Vector2(half, -half), center + Vector2(half, half), center + Vector2(-half, half)])
		"star":
			var points: PackedVector2Array = PackedVector2Array()
			for i: int in range(10):
				points.append(center + Vector2.UP.rotated(TAU * i / 10.0) * (radius * 1.1 if i % 2 == 0 else radius * 0.62))
			return points
		"hexagon":
			return _regular(center, radius, 6)
		_:
			return _regular(center, radius * 0.95, 32)


func _regular(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(sides):
		points.append(center + Vector2.RIGHT.rotated(TAU * i / sides) * radius)
	return points
