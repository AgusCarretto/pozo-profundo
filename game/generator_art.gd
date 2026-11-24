extends RefCounted
## Arte de cada generador (presentación, no balance): el icono de su fila de compra.
##
## Se indexa por el id del generador en data/balance.json. Un generador sin icono se muestra sin él.

const SPRITE_DIR: String = "res://assets/sprites/generated/"

const ICON_FILES: Dictionary = {
	"miner": "miner_1.png",
	"steam_drill": "drill.png",
	"dynamite_crew": "dynamite.png",
	"stone_golem": "golem.png",
	"rune_excavator": "rune_1.png",
}


## La textura del icono del generador `id`, o null si no tiene.
static func icon(id: String) -> Texture2D:
	if not ICON_FILES.has(id):
		return null
	return load(SPRITE_DIR + str(ICON_FILES[id])) as Texture2D
