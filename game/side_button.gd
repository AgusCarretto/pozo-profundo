extends Button
## Botón del costado de la mina (como las misiones de otros juegos): un icono (o un texto grande), su nombre
## y un aviso en la esquina. Se arma por código (build) y no sabe qué abre: de eso se ocupa main.gd.

const Juice := preload("res://game/juice.gd")

## Tamaño (px de diseño): 100 px de ancho = 50 px en un celular de 360 de ancho.
const SIDE_SIZE: Vector2 = Vector2(100.0, 104.0)
const ICON_SIZE: float = 52.0

## El aviso de la esquina (oculto si no hay nada que avisar).
var badge: PanelContainer

var _badge_label: Label
var _big_label: Label


## Con `icon_texture` null, en el lugar del icono va un texto grande (set_big_text).
func build(icon_texture: Texture2D, caption: String) -> void:
	theme_type_variation = &"SideButton"
	custom_minimum_size = SIDE_SIZE
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func() -> void: Juice.bounce(self))

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	if icon_texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	else:
		_big_label = _make_label(&"SideBigLabel")
		_big_label.custom_minimum_size = Vector2(0, ICON_SIZE)
		_big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(_big_label)

	var caption_label: Label = _make_label(&"SideCaption")
	caption_label.text = caption
	box.add_child(caption_label)

	badge = PanelContainer.new()
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = -2.0
	badge.offset_top = 2.0
	add_child(badge)
	_badge_label = _make_label(&"BadgeLabel")
	_badge_label.custom_minimum_size = Vector2(22.0, 0)
	badge.add_child(_badge_label)


## El texto grande (solo si se armó sin icono).
func set_big_text(text: String) -> void:
	if _big_label != null:
		_big_label.text = text


## Muestra `text` en la esquina ("" la oculta). `alert` lo pinta de rojo: algo para hacer ya.
func set_badge(text: String, alert: bool = false) -> void:
	badge.visible = text != ""
	_badge_label.text = text
	if text == "":
		return
	badge.theme_type_variation = &"SideBadgeAlert" if alert else &"SideBadge"
	_badge_label.theme_type_variation = &"BadgeAlertLabel" if alert else &"BadgeLabel"


func _make_label(variation: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
