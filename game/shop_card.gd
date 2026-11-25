extends Button
## Tarjeta de mejora de la grilla: icono, nombre, un dato y la franja del precio. La tarjeta entera es el
## botón de compra.
##
## Es la base de GeneratorCard (un generador) y de PickCard (el pico): las dos se ven igual. Se arma por
## código (build) y se actualiza con show_offer. La franja del precio va verde si se puede comprar y gris si
## no alcanza (y la tarjeta, apagada). Los estilos salen del tema (ui/theme.tres).

const Juice := preload("res://game/juice.gd")

## Alto de la tarjeta (px de diseño): con tres filas entran las seis mejoras sin deslizar.
const CARD_MIN_HEIGHT: float = 150.0
const ICON_SIZE: float = 64.0
const PRICE_HEIGHT: float = 40.0
const PADDING: int = 8

var _name_label: Label
var _detail_label: Label
var _price_box: PanelContainer
var _price_label: Label


## Arma la tarjeta con el icono `icon_texture` (puede ser null).
func build(icon_texture: Texture2D) -> void:
	theme_type_variation = &"CardButton"
	custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	# Reacciona al apretar (no al soltar): un clicker tiene que responder al toque.
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	pressed.connect(func() -> void: Juice.bounce(self))

	# Nada de lo de adentro come el toque: toda la tarjeta es el botón.
	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PADDING)
	add_child(content)

	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	content.add_child(top)

	var icon: TextureRect = TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(icon)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	top.add_child(texts)

	# Los nombres largos ("Cuadrilla de dinamita ×1234") se parten en dos líneas en vez de cortarse.
	_name_label = Label.new()
	_name_label.theme_type_variation = &"CardNameLabel"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_name_label)

	_detail_label = Label.new()
	_detail_label.theme_type_variation = &"CardDetailLabel"
	_detail_label.clip_text = true
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_detail_label)

	_price_box = PanelContainer.new()
	_price_box.theme_type_variation = &"PriceGrey"
	_price_box.custom_minimum_size = Vector2(0, PRICE_HEIGHT)
	_price_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_price_box)

	_price_label = Label.new()
	_price_label.theme_type_variation = &"PriceOffLabel"
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_box.add_child(_price_label)


## Muestra la oferta: `affordable` falso deja la tarjeta deshabilitada y el precio en gris.
func show_offer(title: String, detail: String, price: String, affordable: bool) -> void:
	_name_label.text = title
	_detail_label.text = detail
	_price_label.text = price
	disabled = not affordable
	_price_box.theme_type_variation = &"PriceGreen" if affordable else &"PriceGrey"
	_price_label.theme_type_variation = &"PriceLabel" if affordable else &"PriceOffLabel"
