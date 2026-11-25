extends RefCounted
## Arte y nombre en pantalla de cada generador (presentación, no balance).
##
## Se indexa por el id del generador en data/balance.json. Un generador sin icono se muestra sin él.

const SPRITE_DIR: String = "res://assets/sprites/generated/"

const ICON_FILES: Dictionary = {
	"miner": "miner_1.png",
	"steam_drill": "drill.png",
	"mole": "mole_0_2.png",
	"stone_golem": "golem.png",
	"rune_excavator": "rune_1.png",
	"abyss_worm": "worm_0_1.png",
}

## Mineros que caben en la mina: con más, no aparecen más figuras, sube el nivel.
const MAX_MINERS: int = 7
## Desde cuántas unidades la tarjeta dice "Nv N" en vez de "×N": cuando en la mina ya no se suman figuras.
## Los que son una sola figura (taladro, topo, gólem, gusano) tienen nivel siempre.
const LEVEL_FROM: Dictionary = { "miner": MAX_MINERS + 1, "steam_drill": 0, "mole": 0, "stone_golem": 0, "abyss_worm": 0 }


## "×5" o "Nv 23" según el generador y cuántos hay.
static func count_text(id: String, count: int) -> String:
	if LEVEL_FROM.has(id) and count >= int(LEVEL_FROM[id]):
		return "Nv %d" % count
	return "×%d" % count


## El icono de la tarjeta del pico.
static func pick_icon() -> Texture2D:
	return load(SPRITE_DIR + "pick.png") as Texture2D


## El icono de la Dinamita (la tarjeta y el botón).
static func ability_icon() -> Texture2D:
	return load(SPRITE_DIR + "dynamite.png") as Texture2D


## La textura del icono del generador `id`, o null si no tiene.
static func icon(id: String) -> Texture2D:
	if not ICON_FILES.has(id):
		return null
	return load(SPRITE_DIR + str(ICON_FILES[id])) as Texture2D
