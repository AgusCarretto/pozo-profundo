extends "res://game/shop_row.gd"
## Fila de un generador: icono, nombre y cantidad, producción y botón de compra (ver shop_row.gd).

const GeneratorArt := preload("res://game/generator_art.gd")
const NumberFormat := preload("res://core/number_format.gd")

var index: int = 0

## Modo de compra con el que se dibujó la fila; es el que usa el botón al apretarse.
var _mode: int = Economy.BuyMode.X1


func setup(generator_index: int) -> void:
	index = generator_index
	build(GeneratorArt.icon(Economy.generator_id(index)))
	button.pressed.connect(_on_buy_pressed)
	refresh(_mode)


## Actualiza los textos y el estado del botón según el estado de Economy y el modo de compra.
func refresh(mode: int) -> void:
	_mode = mode
	var offer: Dictionary = Economy.quote(index, mode)
	show_offer(
		"%s  ×%d" % [Economy.generator_name(index), Economy.owned_count(index)],
		"Produce %s/s" % NumberFormat.format_number(Economy.generator_output(index)),
		"Comprar ×%d\n%s" % [offer["count"], NumberFormat.format_cost(offer["cost"])],
		offer["affordable"])


func _on_buy_pressed() -> void:
	Economy.buy_generator(index, _mode)
