extends "res://game/shop_card.gd"
## Tarjeta de la Dinamita (la habilidad): nivel, cuánto vale cada uso y el precio de subirla. Va arriba, al lado
## del Pico. Está en "???" hasta tener el primer Taladro.

const GeneratorArt := preload("res://game/generator_art.gd")
const NumberFormat := preload("res://core/number_format.gd")


func setup() -> void:
	build(GeneratorArt.ability_icon())
	pressed.connect(_on_pressed)
	visible = Economy.has_ability()
	refresh()


func refresh() -> void:
	if not Economy.has_ability():
		return
	var hidden: bool = not Economy.ability_revealed()
	show_silhouette(hidden)
	if hidden:
		show_offer("???", "Comprá el Taladro", "???", false)
		return
	var level: int = Economy.ability_level
	var maxed: bool = level >= Economy.ability_max_level()
	var detail: String = "Golpe de %d s" % Economy.ability_seconds(maxi(level, 1))
	if maxed:
		detail = "Nv %d · %d s" % [level, Economy.ability_seconds(level)]
	elif level > 0:
		detail = "Nv %d · %d » %d s" % [level, Economy.ability_seconds(level), Economy.ability_seconds(level + 1)]
	show_offer(
		"Dinamita",
		detail,
		"Máx." if maxed else NumberFormat.format_cost(Economy.ability_cost()),
		not maxed and Economy.ability_cost() <= Economy.gold)


func _on_pressed() -> void:
	Economy.upgrade_ability()
