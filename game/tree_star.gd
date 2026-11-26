extends Button
## Una estrella del árbol: un botón sin estilo que se dibuja solo. Cada rama tiene su forma (además de su color y su
## brillo, para quien no distingue colores o mira en una pantalla chica); las piedras angulares son más grandes y con
## doble borde. Comprada: llena y con un halo; disponible: borde del color de la rama; oculta o sellada: apagada con "?".
## Adentro lleva su ícono; el nivel va en un globito abajo a la derecha, y un cambio pendiente de piedra angular, en
## otro debajo (o arriba) de la estrella.

const Palette := preload("res://game/palette.gd")
const RelicTree := preload("res://core/relic_tree.gd")

const SIZE: float = 108.0
const KEYSTONE_SIZE: float = 128.0
const MARGIN: float = 8.0
const FONT_SIZE: int = 24
const ICON_SIZE: float = 48.0
const ICON_DIR: String = "res://assets/sprites/generated/stars/"
const GLOW: Texture2D = preload("res://assets/particles/particle_pack/circle_05.png")
## Cuánto más grande que la estrella es el halo de una comprada, y qué tan fuerte.
const GLOW_SCALE: float = 1.7
const GLOW_ALPHA: float = 0.55
const BADGE_FONT: int = 22
const PENDING_FONT: int = 20
const PENDING_ON: String = "Activa desde la\npróxima bajada"
const PENDING_OFF: String = "Se apaga en la\npróxima bajada"


## Un rótulo con fondo redondeado. Se dibuja a mano: un Label suelto en el árbol contaría como texto de la pantalla.
class Balloon extends Control:
	var text: String = ""
	var font_size: int = 22
	var border: Color = Color.WHITE

	func _init(node_name: String, size_px: int) -> void:
		name = node_name
		font_size = size_px
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_text(value: String, edge: Color) -> void:
		text = value
		border = edge
		var font: Font = get_theme_font("font", "Label")
		var area: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		size = Vector2(ceilf(area.x) + 18.0, ceilf(area.y) + 6.0)
		visible = true
		queue_redraw()

	func _draw() -> void:
		var back: StyleBoxFlat = StyleBoxFlat.new()
		back.bg_color = Color(0.1, 0.08, 0.13, 0.96)
		back.border_color = border
		back.set_border_width_all(2)
		back.set_corner_radius_all(10)
		draw_style_box(back, Rect2(Vector2.ZERO, size))
		var font: Font = get_theme_font("font", "Label")
		draw_multiline_string(font, Vector2(0.0, 3.0 + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, -1, Color.WHITE)


var id: String = ""
## "triangle", "diamond", "square", "circle", "star" o "hexagon" (data/arbol.json).
var shape: String = "circle"
var branch_color: Color = Color.WHITE
var keystone: bool = false
## El globito de pendiente va arriba en lugar de abajo (cuando abajo hay otra estrella).
var balloon_above: bool = false

var _state: int = RelicTree.State.HIDDEN
var _selected: bool = false
var _icon: TextureRect
var _badge: Balloon
var _pending: Balloon


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
	_icon = TextureRect.new()
	_icon.name = "Icon"
	var path: String = ICON_DIR + star_id + ".png"
	if ResourceLoader.exists(path):
		_icon.texture = load(path) as Texture2D
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size = Vector2.ONE * ICON_SIZE
	# En el triángulo el centro de la figura queda más abajo.
	var drop: float = (side * 0.5 - MARGIN) * 0.2 if shape == "triangle" else 0.0
	_icon.position = (size - _icon.size) * 0.5 + Vector2(0.0, drop)
	_icon.visible = false
	add_child(_icon)
	_badge = Balloon.new("Badge", BADGE_FONT)
	add_child(_badge)
	_pending = Balloon.new("Pending", PENDING_FONT)
	add_child(_pending)


## `pending`: 1 = la piedra se prende en la próxima bajada, -1 = se apaga, 0 = nada.
func show_state(state: int, level: int, max_level: int, selected: bool, pending: int = 0) -> void:
	_state = state
	_selected = selected
	var known: bool = state == RelicTree.State.OPEN or state == RelicTree.State.OWNED
	_icon.visible = known
	_icon.modulate = Color.WHITE if state == RelicTree.State.OWNED else Color(0.86, 0.86, 0.9)
	_badge.visible = false
	if known and max_level > 1:
		_badge.show_text("%d/%d" % [level, max_level], branch_color if level > 0 else Palette.SLATE_LIGHT)
		_badge.position = size - _badge.size + Vector2(10.0, 10.0)
	_pending.visible = false
	if pending != 0:
		_pending.show_text(PENDING_ON if pending > 0 else PENDING_OFF, Palette.YELLOW if pending > 0 else Palette.STEEL)
		_pending.position = Vector2((size.x - _pending.size.x) * 0.5, 6.0 - _pending.size.y if balloon_above else size.y - 6.0)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = size.x * 0.5 - MARGIN
	var owned: bool = _state == RelicTree.State.OWNED
	var open: bool = _state == RelicTree.State.OPEN
	if owned:
		var halo: Vector2 = size * GLOW_SCALE
		draw_texture_rect(GLOW, Rect2(center - halo * 0.5, halo), false, Color(branch_color, GLOW_ALPHA))
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
	if owned or open:
		return
	var font: Font = get_theme_font("font")
	var text_size: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var drop: float = radius * 0.18 if shape == "triangle" else 0.0
	draw_string(font, center + Vector2(-text_size.x * 0.5, FONT_SIZE * 0.35 + drop), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.STEEL)


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
