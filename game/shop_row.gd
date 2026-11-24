extends PanelContainer
## Fila de la lista de compra: icono, nombre, un dato y el botón de compra.
##
## Es la base de GeneratorRow (un generador) y de PickRow (el pico): las dos filas se ven igual. Se arma por
## código (build) y se actualiza con show_offer. Verde = se puede comprar, gris = no alcanza (lo decide el
## tema según `disabled`). Los estilos salen del tema (ui/theme.tres).

## Alto mínimo de la fila (px de diseño): entra el botón de compra de 96 px con su margen.
const ROW_MIN_HEIGHT: float = 124.0
const ICON_SIZE: float = 80.0
const BUY_BUTTON_MIN: Vector2 = Vector2(250.0, 96.0)

var button: Button

var _name_label: Label
var _detail_label: Label


## Arma la fila con el icono `icon_texture` (puede ser null).
func build(icon_texture: Texture2D) -> void:
	theme_type_variation = &"CardPanel"
	custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)
	# Un toque sobre la tarjeta (fuera del botón) sigue de largo al scroll de la lista.
	mouse_filter = Control.MOUSE_FILTER_PASS

	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var icon: TextureRect = TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(texts)

	# Los nombres largos ("Cuadrilla de dinamita ×1234") se parten en dos líneas en vez de cortarse.
	_name_label = Label.new()
	_name_label.theme_type_variation = &"RowNameLabel"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_name_label)

	_detail_label = Label.new()
	_detail_label.theme_type_variation = &"MutedLabel"
	_detail_label.clip_text = true
	texts.add_child(_detail_label)

	button = Button.new()
	button.theme_type_variation = &"ButtonGreen"
	button.custom_minimum_size = BUY_BUTTON_MIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	box.add_child(button)


## Muestra la oferta: `affordable` falso deja el botón deshabilitado (gris).
func show_offer(title: String, detail: String, button_text: String, affordable: bool) -> void:
	_name_label.text = title
	_detail_label.text = detail
	button.text = button_text
	button.disabled = not affordable
