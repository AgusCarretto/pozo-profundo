extends "res://game/shop_card.gd"
## Tarjeta del pico: icono, nivel, lo que pega un golpe y el precio de mejorarlo (ver shop_card.gd).
## Se ve igual que las de los generadores: el pico es una mejora más de la grilla.

const GeneratorArt := preload("res://game/generator_art.gd")
const NumberFormat := preload("res://core/number_format.gd")


func setup() -> void:
	build(GeneratorArt.pick_icon())
	pressed.connect(_on_pressed)
	refresh()


## Actualiza el nivel, el golpe y el precio según Economy.
func refresh() -> void:
	var cost: float = Economy.pick_cost()
	show_offer(
		"Pico  nivel %d" % Economy.pick_level,
		"Golpe %s" % NumberFormat.format_number(Economy.hit_value()),
		NumberFormat.format_cost(cost),
		cost <= Economy.gold)


func _on_pressed() -> void:
	Economy.upgrade_pick()
