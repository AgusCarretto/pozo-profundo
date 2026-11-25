extends "res://game/shop_card.gd"
## Tarjeta de un generador: icono, nombre y cantidad, producción y precio (ver shop_card.gd).

const GeneratorArt := preload("res://game/generator_art.gd")
const NumberFormat := preload("res://core/number_format.gd")

var index: int = 0

## Modo de compra con el que se dibujó la tarjeta; es el que usa al tocarla.
var _mode: int = Economy.BuyMode.X1


func setup(generator_index: int) -> void:
	index = generator_index
	build(GeneratorArt.icon(Economy.generator_id(index)))
	pressed.connect(_on_buy_pressed)
	refresh(_mode)


## Actualiza los textos y el estado según Economy y el modo de compra. En ×10 y Máx el precio dice
## cuántas se compran.
func refresh(mode: int) -> void:
	_mode = mode
	var offer: Dictionary = Economy.quote(index, mode)
	var price: String = NumberFormat.format_cost(offer["cost"])
	if mode != Economy.BuyMode.X1:
		price = "×%d · %s" % [offer["count"], price]
	show_offer(
		"%s  ×%d" % [Economy.generator_name(index), Economy.owned_count(index)],
		"Produce %s/s" % NumberFormat.format_number(Economy.generator_output(index)),
		price,
		offer["affordable"])


func _on_buy_pressed() -> void:
	Economy.buy_generator(index, _mode)
