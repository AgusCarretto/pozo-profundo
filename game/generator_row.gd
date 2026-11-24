extends PanelContainer
## Fila de un generador: icono, nombre y cantidad, producción y botón de compra.
##
## Se arma por código y se actualiza con refresh(). Los estilos salen del tema (ui/theme.tres).

const GeneratorArt := preload("res://game/generator_art.gd")
const NumberFormat := preload("res://core/number_format.gd")

## Alto mínimo de la fila (px de diseño): entra el botón de compra de 96 px con su margen.
const ROW_MIN_HEIGHT: float = 124.0
const ICON_SIZE: float = 80.0
const BUY_BUTTON_MIN: Vector2 = Vector2(250.0, 96.0)

var index: int = 0

## Modo de compra con el que se dibujó la fila; es el que usa el botón al apretarse.
var _mode: int = Economy.BuyMode.X1
var _name_label: Label
var _detail_label: Label
var _buy_button: Button


func setup(generator_index: int) -> void:
	index = generator_index
	theme_type_variation = &"CardPanel"
	custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)
	# Un toque sobre la tarjeta (fuera del botón) sigue de largo al scroll de la lista.
	mouse_filter = Control.MOUSE_FILTER_PASS

	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var icon: TextureRect = TextureRect.new()
	icon.texture = GeneratorArt.icon(Economy.generator_id(index))
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

	_buy_button = Button.new()
	_buy_button.theme_type_variation = &"ButtonGreen"
	_buy_button.custom_minimum_size = BUY_BUTTON_MIN
	_buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_buy_button.focus_mode = Control.FOCUS_NONE
	_buy_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_buy_button.pressed.connect(_on_buy_pressed)
	box.add_child(_buy_button)

	refresh(_mode)


## Actualiza los textos y el estado del botón según el estado de Economy y el modo de compra.
func refresh(mode: int) -> void:
	_mode = mode
	_name_label.text = "%s  ×%d" % [Economy.generator_name(index), Economy.owned_count(index)]
	_detail_label.text = "Produce %s/s" % NumberFormat.format_number(Economy.generator_output(index))
	var offer: Dictionary = Economy.quote(index, mode)
	_buy_button.text = "Comprar ×%d\n%s" % [offer["count"], NumberFormat.format_cost(offer["cost"])]
	_buy_button.disabled = not offer["affordable"]


func _on_buy_pressed() -> void:
	Economy.buy_generator(index, _mode)
