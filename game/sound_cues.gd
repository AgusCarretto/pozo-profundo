extends Node
## Qué suena cuando pasa algo en la economía: golpe, compra, pico, cofre (por rareza) y prestigio.
##
## Solo traduce señales de Economy a ids del catálogo de sonidos (data/sounds.json); qué archivo suena y
## con qué tono lo decide Audio. Los sonidos de la interfaz (pestañas, modos, carteles) los pide cada
## control, y el del bioma nuevo, main.gd (que sabe cuándo se entra a uno más profundo).


func _ready() -> void:
	Economy.hit_landed.connect(_on_hit_landed.unbind(1))
	Economy.generator_bought.connect(_play.bind("buy").unbind(2))
	Economy.milestone_reached.connect(_play.bind("milestone").unbind(2))
	Economy.pick_upgraded.connect(_play.bind("pick").unbind(1))
	Economy.loot_dropped.connect(_on_loot_dropped)
	Economy.prestiged.connect(_play.bind("prestige").unbind(1))


## Un golpe crítico tiene su sonido, en lugar del de siempre.
func _on_hit_landed() -> void:
	_play("crit" if Economy.last_hit_critical else "hit")


## El cofre suena según su rareza: "chest_<id de la rareza en el balance>".
func _on_loot_dropped(rarity: int, _amount: float) -> void:
	var table: Array[Dictionary] = Economy.loot_table()
	if rarity >= 0 and rarity < table.size():
		_play("chest_%s" % table[rarity]["id"])


func _play(id: String) -> void:
	Audio.play_sfx(id)
