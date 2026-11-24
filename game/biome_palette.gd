extends RefCounted
## Colores de cada bioma (presentación, no balance): cambian el fondo de la mina, la roca y los acentos de la UI.
##
## Se indexan por el id del bioma en data/balance.json ("earth", "rock"...). Usan solo colores de
## game/palette.gd (Tiny Dungeon). tools/generate_sprites.gd dibuja con ellos la roca y el fondo de cada
## bioma; la escena los usa para el color de relleno y el acento de la barra de profundidad.

const Palette := preload("res://game/palette.gd")

## Por bioma:
##   rock_light / rock / rock_dark: las tres sombras de la roca; vein / vein_light: las vetas.
##   bg / bg_dark / bg_light / bg_spark: el fondo de la mina (base, motas oscuras, motas claras, destellos).
##   accent: el color de la barra de profundidad y otros detalles de la UI.
const BY_ID: Dictionary = {
	"earth": {
		"rock_light": Palette.ORANGE, "rock": Palette.TERRA, "rock_dark": Palette.MAROON,
		"vein": Palette.GOLD, "vein_light": Palette.YELLOW,
		"bg": Palette.MAROON, "bg_dark": Palette.OUTLINE, "bg_light": Palette.TERRA, "bg_spark": Palette.CLAY,
		"accent": Palette.GOLD,
	},
	"rock": {
		"rock_light": Palette.STEEL_LIGHT, "rock": Palette.STEEL, "rock_dark": Palette.SLATE,
		"vein": Palette.TERRA, "vein_light": Palette.CLAY,
		"bg": Palette.SLATE, "bg_dark": Palette.NAVY, "bg_light": Palette.SLATE_LIGHT, "bg_spark": Palette.STEEL,
		"accent": Palette.STEEL_LIGHT,
	},
	"crystal": {
		"rock_light": Palette.STEEL, "rock": Palette.SLATE_LIGHT, "rock_dark": Palette.SLATE,
		"vein": Palette.BLUE, "vein_light": Palette.CYAN,
		"bg": Palette.NAVY, "bg_dark": Palette.OUTLINE, "bg_light": Palette.SLATE, "bg_spark": Palette.CYAN,
		"accent": Palette.CYAN,
	},
	"magma": {
		"rock_light": Palette.RED, "rock": Palette.MAROON, "rock_dark": Palette.OUTLINE,
		"vein": Palette.GOLD, "vein_light": Palette.YELLOW,
		"bg": Palette.OUTLINE, "bg_dark": Palette.NAVY, "bg_light": Palette.MAROON, "bg_spark": Palette.RED,
		"accent": Palette.RED,
	},
	"abyss": {
		"rock_light": Palette.PINK, "rock": Palette.PURPLE, "rock_dark": Palette.OUTLINE,
		"vein": Palette.MINT, "vein_light": Palette.AQUA,
		"bg": Palette.NAVY, "bg_dark": Palette.OUTLINE, "bg_light": Palette.PURPLE, "bg_spark": Palette.PINK,
		"accent": Palette.PINK,
	},
}

## Los ids de los biomas, en orden (el mismo que data/balance.json).
const IDS: Array[String] = ["earth", "rock", "crystal", "magma", "abyss"]


## Colores del bioma `id`; si no se conoce, los de Tierra.
static func of(id: String) -> Dictionary:
	return BY_ID.get(id, BY_ID["earth"])
