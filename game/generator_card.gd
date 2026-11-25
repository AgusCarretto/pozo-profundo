extends "res://game/shop_card.gd"
## Tarjeta de un generador: icono, nombre y cantidad, producción y precio (ver shop_card.gd).

const GeneratorArt := preload("res://game/generator_art.gd")
const NumberFormat := preload("res://core/number_format.gd")

var index: int = 0

## Modo de compra con el que se dibujó la tarjeta; es el que usa al tocarla.
var _mode: int = Economy.BuyMode.X1
## Estaba en "???" la última vez que se dibujó: al revelarse rebota.
var _hidden: bool = false


func setup(generator_index: int) -> void:
	index = generator_index
	build(GeneratorArt.icon(Economy.generator_id(index)))
	pressed.connect(_on_buy_pressed)
	refresh(_mode)


## Actualiza los textos y el estado según Economy y el modo de compra. En ×10 y Máx el precio dice
## cuántas se compran.
func refresh(mode: int) -> void:
	_mode = mode
	var hidden: bool = not Economy.is_generator_revealed(index)
	show_silhouette(hidden)
	if hidden:
		_hidden = true
		show_offer("???", "Comprá el anterior", "???", false)
		return
	if _hidden and is_inside_tree():
		Juice.bounce(self)
	_hidden = false
	var offer: Dictionary = Economy.quote(index, mode)
	var price: String = NumberFormat.format_cost(offer["cost"])
	if mode != Economy.BuyMode.X1:
		price = "×%d · %s" % [offer["count"], price]
	show_offer(
		"%s  ×%d" % [Economy.generator_name(index), Economy.owned_count(index)],
		_detail(),
		price,
		offer["affordable"])


## Lo que produce y cuánto falta para el próximo hito ("42/s · 21/25"); pasado el último, cuánto multiplica.
func _detail() -> String:
	var output: String = "%s/s" % NumberFormat.format_number(Economy.generator_output(index))
	var next: int = Economy.next_milestone(index)
	if next > 0:
		return "%s · %d/%d" % [output, Economy.owned_count(index), next]
	var bonus: float = Economy.milestone_multiplier(index)
	if bonus > 1.0:
		return "%s · ×%d" % [output, int(bonus)]
	return "Produce %s" % output


func _on_buy_pressed() -> void:
	Economy.buy_generator(index, _mode)
