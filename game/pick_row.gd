extends "res://game/shop_row.gd"
## Fila del pico: icono, nivel, lo que pega un golpe y el botón de mejorar (ver shop_row.gd).
## Se ve igual que las filas de los generadores: el pico es una compra más de la lista.

const GeneratorArt := preload("res://game/generator_art.gd")
const NumberFormat := preload("res://core/number_format.gd")


func setup() -> void:
	build(GeneratorArt.pick_icon())
	button.pressed.connect(_on_pressed)
	refresh()


## Actualiza el nivel, el golpe y el costo según el estado de Economy.
func refresh() -> void:
	var cost: float = Economy.pick_cost()
	show_offer(
		"Pico  nivel %d" % Economy.pick_level,
		"Golpe %s" % NumberFormat.format_number(Economy.hit_value()),
		"Mejorar\n%s" % NumberFormat.format_cost(cost),
		cost <= Economy.gold)


func _on_pressed() -> void:
	Economy.upgrade_pick()
