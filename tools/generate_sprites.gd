extends SceneTree
## Dibuja por código los sprites 16x16 que Tiny Dungeon no trae y recolorea los mineros.
##
## Uso (desde la raíz del proyecto):
##   godot --headless --path . --script res://tools/generate_sprites.gd
##   godot --headless --path . --import      # para que Godot importe los PNG nuevos
##
## Todo sale a res://assets/sprites/generated/ como PNG de 16x16 con SOLO los 27 colores de
## Tiny Dungeon (game/palette.gd): roca y fondo de cada bioma, taladro, gólem, dinamita, runas,
## moneda, pico y las variantes de color de los mineros. Cada sprite se dibuja "relleno" y
## después se le pone el contorno oscuro del pack automáticamente (un píxel alrededor).
## Es determinista: correrlo de nuevo reescribe exactamente los mismos archivos.

const Palette := preload("res://game/palette.gd")
const BiomePalette := preload("res://game/biome_palette.gd")

const OUT_DIR: String = "res://assets/sprites/generated/"
const TINY_DUNGEON_DIR: String = "res://assets/sprites/tiny_dungeon/"
const SIZE: int = 16
const T: Color = Color(0.0, 0.0, 0.0, 0.0)

## Variantes de color de los mineros: [archivo, tile de Tiny Dungeon, {color original -> color nuevo}].
## Sin mapa = el personaje tal cual viene en el pack.
const MINERS: Array = [
	["miner_1", "0085", {}],
	["miner_2", "0085", { Palette.STEEL_LIGHT: Palette.SALMON, Palette.STEEL: Palette.RED }],
	["miner_3", "0098", { Palette.STEEL_LIGHT: Palette.CYAN, Palette.STEEL: Palette.BLUE, Palette.SLATE: Palette.SLATE_LIGHT }],
	["miner_4", "0086", {}],
	["miner_5", "0088", {}],
	["miner_6", "0099", { Palette.PINK: Palette.MINT, Palette.PURPLE: Palette.GREEN }],
	["miner_7", "0112", { Palette.MINT: Palette.SALMON, Palette.GREEN: Palette.RED }],
	["miner_8", "0098", { Palette.STEEL_LIGHT: Palette.YELLOW, Palette.STEEL: Palette.GOLD, Palette.SLATE: Palette.TERRA }],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for id: String in BiomePalette.IDS:
		_save(_rock(id), "rock_%s.png" % id)
		_save(_background(id), "bg_%s.png" % id)
	_save(_drill(), "drill.png")
	_save(_golem(), "golem.png")
	_save(_dynamite(), "dynamite.png")
	for number: int in range(1, 4):
		_save(_rune(number), "rune_%d.png" % number)
	_save(_coin(), "coin.png")
	_save(_pick(), "pick.png")
	_save(_gem(), "gem.png")
	for entry: Array in MINERS:
		_save(_miner(entry[1], entry[2]), "%s.png" % entry[0])
	print("Sprites generados en ", OUT_DIR)
	quit(0)


# --- Roca y fondo de cada bioma ---------------------------------------------------------

## Roca grande de 16x16 con vetas propias de cada bioma. Siluetas y sombras comunes (L luz, B base,
## D sombra); las vetas se superponen (v / w) y los cristales o brasas salen de la propia silueta.
func _rock(id: String) -> Image:
	var colors: Dictionary = BiomePalette.of(id)
	var palette: Dictionary = {
		"L": colors["rock_light"], "B": colors["rock"], "D": colors["rock_dark"],
		"v": colors["vein"], "w": colors["vein_light"],
	}
	var img: Image = _ascii([
		"................",
		"................",
		".....LLLLLL.....",
		"...LLLLLLBBBB...",
		"..LLLLBBBBBBBD..",
		".LLLBBBBBBBBBDD.",
		".LLBBBBBBBBBBDD.",
		".LBBBBBBBBBBBDD.",
		".LBBBBBBBBBBBDD.",
		".BBBBBBBBBBBBDD.",
		".BBBBBBBBBBBDDD.",
		".BBBBBBBBBDDDDD.",
		"..BBBBBDDDDDDD..",
		"..DDDDDDDDDDDD..",
		"................",
		"................",
	], palette)
	# grietas y facetas comunes: dan volumen sin cambiar la silueta
	for point: Vector2i in [Vector2i(7, 4), Vector2i(7, 5), Vector2i(8, 6), Vector2i(8, 7), Vector2i(9, 8),
			Vector2i(3, 9), Vector2i(4, 10), Vector2i(11, 5), Vector2i(12, 6)]:
		img.set_pixelv(point, colors["rock_dark"])
	for point: Vector2i in [Vector2i(4, 6), Vector2i(3, 7), Vector2i(5, 5), Vector2i(10, 3), Vector2i(9, 9)]:
		img.set_pixelv(point, colors["rock_light"])
	_overlay(img, _veins(id), palette)
	_outline(img)
	return img


## Vetas de cada bioma ('.' no toca nada).
func _veins(id: String) -> Array[String]:
	match id:
		"earth": # pepitas de oro
			return [
				"................",
				"................",
				"................",
				"................",
				"................",
				".....wv.....wv..",
				".....vv......v..",
				"................",
				"...........w....",
				"..wv.......vv...",
				"..vv...vw.......",
				".......vv.......",
				"................",
				"................",
				"................",
				"................",
			]
		"rock": # vetas de óxido que cruzan la roca
			return [
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
				"........w.......",
				".......wv.......",
				"......wv....w...",
				".....wv....wv...",
				"....wv....wv....",
				"...wv....wv.....",
				"................",
				"................",
				"................",
				"................",
			]
		"crystal": # cristales que le brotan de arriba
			return [
				"................",
				"........w.......",
				".....w..w..w....",
				"....wv.wv.wv....",
				"....vv.vv.vv....",
				".....v.vv.v.....",
				"................",
				"..............w.",
				".............wv.",
				"..w...........v.",
				".wv.............",
				".vv.............",
				"................",
				"................",
				"................",
				"................",
			]
		"magma": # grietas de lava
			return [
				"................",
				"................",
				"................",
				"...........w....",
				"..........wv....",
				".....wv..wv.....",
				"....wv..wv......",
				".....wvwv.......",
				"......vv........",
				"......wv...w....",
				".....wv...wv....",
				"....wv.....v....",
				"................",
				"................",
				"................",
				"................",
			]
		"abyss": # vetas y ojos que brillan
			return [
				"................",
				"................",
				"................",
				"................",
				".....w.......w..",
				"....wv.......v..",
				"....v...........",
				"................",
				"....w..ww..w....",
				"...wv..vv..wv...",
				"...v........v...",
				"................",
				"................",
				"................",
				"................",
				"................",
			]
	return []


## Mosaico de fondo 16x16 que se repite sin costuras: base con motas oscuras, claras y destellos.
func _background(id: String) -> Image:
	var colors: Dictionary = BiomePalette.of(id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) # los mismos píxeles cada vez que se genera
	var img: Image = _blank()
	img.fill(colors["bg"])
	var dark: Array[Vector2i] = []
	var light: Array[Vector2i] = []
	for i: int in range(18):
		dark.append(Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1)))
	for i: int in range(12):
		light.append(Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1)))
	for point: Vector2i in dark:
		img.set_pixelv(point, colors["bg_dark"])
		if rng.randf() < 0.45: # algunas motas son de dos píxeles
			img.set_pixelv(Vector2i((point.x + 1) % SIZE, point.y), colors["bg_dark"])
	for point: Vector2i in light:
		img.set_pixelv(point, colors["bg_light"])
	for i: int in range(3):
		img.set_pixelv(Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1)), colors["bg_spark"])
	return img


# --- Máquinas y objetos --------------------------------------------------------------------

## Taladro a vapor: caldera con chimenea, mecha de taladro a la izquierda y vapor.
func _drill() -> Image:
	var img: Image = _blank()
	# chimenea
	_rect(img, 10, 3, 3, 4, Palette.SLATE)
	_rect(img, 9, 2, 5, 1, Palette.STEEL)
	# caldera
	_rect(img, 5, 6, 9, 6, Palette.STEEL)
	_rect(img, 5, 6, 9, 1, Palette.STEEL_LIGHT)
	_rect(img, 5, 11, 9, 1, Palette.SLATE)
	_rect(img, 7, 6, 1, 6, Palette.RED)
	_rect(img, 12, 6, 1, 6, Palette.RED)
	img.set_pixel(7, 8, Palette.SALMON)
	img.set_pixel(12, 8, Palette.SALMON)
	# ruedas
	_rect(img, 6, 12, 3, 2, Palette.SLATE)
	_rect(img, 11, 12, 3, 2, Palette.SLATE)
	img.set_pixel(7, 13, Palette.STEEL_LIGHT)
	img.set_pixel(12, 13, Palette.STEEL_LIGHT)
	# boca y mecha del taladro, que apunta a la roca (a la izquierda)
	_rect(img, 3, 7, 2, 4, Palette.SLATE)
	_rect(img, 2, 8, 1, 2, Palette.GOLD)
	img.set_pixel(3, 7, Palette.GOLD)
	img.set_pixel(3, 10, Palette.GOLD)
	img.set_pixel(1, 8, Palette.YELLOW)
	img.set_pixel(1, 9, Palette.GOLD)
	_outline(img)
	# vapor (sin contorno: es una nube)
	for point: Vector2i in [Vector2i(10, 1), Vector2i(11, 0), Vector2i(12, 1), Vector2i(13, 0)]:
		img.set_pixelv(point, Palette.FROST)
	img.set_pixel(11, 1, Palette.WHITE)
	return img


## Gólem de piedra: cuerpo de bloques de roca con musgo y ojos que brillan.
func _golem() -> Image:
	var img: Image = _blank()
	# cabeza (más angosta que el torso)
	_rect(img, 5, 1, 6, 4, Palette.STEEL)
	_rect(img, 5, 1, 6, 1, Palette.STEEL_LIGHT)
	_rect(img, 10, 2, 1, 3, Palette.SLATE)
	img.set_pixel(6, 3, Palette.AQUA)
	img.set_pixel(9, 3, Palette.AQUA)
	# torso
	_rect(img, 4, 5, 8, 6, Palette.STEEL)
	_rect(img, 4, 5, 8, 1, Palette.STEEL_LIGHT)
	_rect(img, 4, 10, 8, 1, Palette.SLATE)
	_rect(img, 10, 6, 2, 4, Palette.SLATE)
	# runa que brilla en el pecho y musgo
	_rect(img, 7, 7, 2, 2, Palette.CYAN)
	img.set_pixel(7, 7, Palette.AQUA)
	img.set_pixel(5, 6, Palette.GREEN)
	img.set_pixel(6, 6, Palette.GREEN)
	img.set_pixel(5, 7, Palette.GREEN)
	img.set_pixel(9, 9, Palette.GREEN)
	# brazos y puños, separados del torso por un hueco (se ve el contorno entre ambos)
	_rect(img, 1, 5, 2, 5, Palette.STEEL)
	_rect(img, 13, 5, 2, 5, Palette.SLATE)
	_rect(img, 0, 10, 4, 3, Palette.SLATE)
	_rect(img, 12, 10, 4, 3, Palette.SLATE)
	_rect(img, 0, 10, 4, 1, Palette.STEEL)
	_rect(img, 12, 10, 4, 1, Palette.STEEL)
	# piernas
	_rect(img, 5, 11, 2, 3, Palette.SLATE)
	_rect(img, 9, 11, 2, 3, Palette.SLATE)
	_outline(img)
	return img


## Cuadrilla de dinamita: tres cartuchos atados con la mecha encendida.
func _dynamite() -> Image:
	var img: Image = _blank()
	for x: int in [3, 6, 9]:
		_rect(img, x, 5 if x != 6 else 4, 3, 9 if x != 6 else 10, Palette.RED)
		_rect(img, x, 5 if x != 6 else 4, 1, 9 if x != 6 else 10, Palette.SALMON)
	_rect(img, 3, 8, 9, 2, Palette.SAND)
	_rect(img, 3, 8, 9, 1, Palette.SAND_LIGHT)
	# mecha y chispa
	img.set_pixel(7, 3, Palette.TERRA)
	img.set_pixel(8, 2, Palette.TERRA)
	_outline(img)
	img.set_pixel(9, 1, Palette.YELLOW)
	img.set_pixel(10, 0, Palette.WHITE)
	img.set_pixel(10, 2, Palette.GOLD)
	img.set_pixel(8, 1, Palette.GOLD)
	return img


## Piedra rúnica con un símbolo que brilla (1, 2 y 3 son tres símbolos distintos).
func _rune(number: int) -> Image:
	var img: Image = _blank()
	_rect(img, 4, 2, 8, 12, Palette.SLATE_LIGHT)
	_rect(img, 4, 2, 8, 1, Palette.STEEL)
	_rect(img, 4, 2, 1, 12, Palette.STEEL)
	_rect(img, 11, 3, 1, 11, Palette.SLATE)
	_rect(img, 5, 13, 7, 1, Palette.SLATE)
	for corner: Vector2i in [Vector2i(4, 2), Vector2i(11, 2), Vector2i(4, 13), Vector2i(11, 13)]:
		img.set_pixelv(corner, T)
	var glyph: Array[Vector2i] = []
	match number:
		1: # una "F": tronco y dos ramas
			glyph = [Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6), Vector2i(7, 7), Vector2i(7, 8), Vector2i(7, 9), Vector2i(7, 10),
				Vector2i(8, 5), Vector2i(9, 4), Vector2i(8, 7), Vector2i(9, 6)]
		2: # un rombo con punto
			glyph = [Vector2i(7, 4), Vector2i(6, 5), Vector2i(8, 5), Vector2i(5, 6), Vector2i(9, 6), Vector2i(6, 7), Vector2i(8, 7),
				Vector2i(7, 8), Vector2i(7, 10), Vector2i(7, 6)]
		_: # una "thorn": tronco y triángulo
			glyph = [Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6), Vector2i(6, 7), Vector2i(6, 8), Vector2i(6, 9), Vector2i(6, 10),
				Vector2i(7, 5), Vector2i(8, 6), Vector2i(8, 7), Vector2i(7, 8)]
	for point: Vector2i in glyph:
		img.set_pixelv(point, Palette.AQUA)
	for point: Vector2i in glyph:
		var below: Vector2i = point + Vector2i(1, 1)
		if img.get_pixelv(below) == Palette.SLATE_LIGHT:
			img.set_pixelv(below, Palette.CYAN) # resplandor
	_outline(img)
	return img


# --- Iconos ------------------------------------------------------------------------------------

func _coin() -> Image:
	var img: Image = _blank()
	for y: int in range(2, 14):
		for x: int in range(2, 14):
			var dx: float = x - 7.5
			var dy: float = y - 7.5
			if dx * dx + dy * dy <= 30.0:
				img.set_pixel(x, y, Palette.GOLD)
	for y: int in range(4, 12):
		for x: int in range(4, 12):
			var dx: float = x - 7.5
			var dy: float = y - 7.5
			if dx * dx + dy * dy <= 12.0:
				img.set_pixel(x, y, Palette.YELLOW)
	_rect(img, 7, 5, 2, 6, Palette.GOLD)
	_rect(img, 5, 4, 2, 1, Palette.WHITE)
	_outline(img)
	return img


func _pick() -> Image:
	var img: Image = _blank()
	# mango en diagonal
	for i: int in range(9):
		img.set_pixel(3 + i, 13 - i, Palette.TERRA)
		img.set_pixel(4 + i, 13 - i, Palette.MAROON)
	# cabeza curva de acero
	for point: Vector2i in [Vector2i(3, 5), Vector2i(4, 4), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3),
			Vector2i(9, 3), Vector2i(10, 4), Vector2i(11, 5), Vector2i(12, 6), Vector2i(12, 7), Vector2i(2, 6)]:
		img.set_pixelv(point, Palette.STEEL_LIGHT)
	for point: Vector2i in [Vector2i(4, 5), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4),
			Vector2i(10, 5), Vector2i(11, 6), Vector2i(11, 7), Vector2i(3, 6)]:
		img.set_pixelv(point, Palette.STEEL)
	img.set_pixel(7, 3, Palette.WHITE)
	_outline(img)
	return img


## Gema que suelta la roca al picar.
func _gem() -> Image:
	var img: Image = _blank()
	_ascii_into(img, [
		"................",
		"................",
		"................",
		"................",
		".....CCCCCC.....",
		"....CWCCBBBC....",
		"...CCCCCBBBBC...",
		"....CCCBBBBC....",
		".....CBBBBC.....",
		"......CBBC......",
		".......CC.......",
		"................",
		"................",
		"................",
		"................",
		"................",
	], { "C": Palette.CYAN, "W": Palette.WHITE, "B": Palette.BLUE })
	_outline(img)
	return img


# --- Mineros ---------------------------------------------------------------------------------------

## Un personaje de Tiny Dungeon (res://assets/sprites/tiny_dungeon/tile_XXXX.png), con un cambio de
## paleta opcional ({color original -> color nuevo}): así los mineros no son todos iguales.
func _miner(tile: String, swaps: Dictionary) -> Image:
	# Se lee el PNG original del disco (no el importado) para partir de los píxeles exactos del pack.
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(TINY_DUNGEON_DIR + "tile_%s.png" % tile))
	img.convert(Image.FORMAT_RGBA8)
	if swaps.is_empty():
		return img
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var current: Color = img.get_pixel(x, y)
			if current.a > 0.5 and swaps.has(current):
				img.set_pixel(x, y, swaps[current])
	return img


# --- Herramientas de dibujo -----------------------------------------------------------------------

func _blank() -> Image:
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(T)
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < SIZE and yy < SIZE:
				img.set_pixel(xx, yy, color)


## Dibuja un arte en texto: cada letra es un color del diccionario y '.' deja el píxel como está.
func _ascii(rows: Array[String], colors: Dictionary) -> Image:
	var img: Image = _blank()
	_ascii_into(img, rows, colors)
	return img


func _ascii_into(img: Image, rows: Array[String], colors: Dictionary) -> void:
	for y: int in range(mini(rows.size(), SIZE)):
		for x: int in range(mini(rows[y].length(), SIZE)):
			var key: String = rows[y][x]
			if key != "." and colors.has(key):
				img.set_pixel(x, y, colors[key])


func _overlay(img: Image, rows: Array[String], colors: Dictionary) -> void:
	_ascii_into(img, rows, colors)


## Contorno oscuro de un píxel alrededor de todo lo que no es transparente (como en Tiny Dungeon).
func _outline(img: Image) -> void:
	var source: Image = img.duplicate()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			if source.get_pixel(x, y).a > 0.5:
				continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx >= 0 and ny >= 0 and nx < SIZE and ny < SIZE and source.get_pixel(nx, ny).a > 0.5:
					img.set_pixel(x, y, Palette.OUTLINE)
					break


func _save(img: Image, file_name: String) -> void:
	var path: String = ProjectSettings.globalize_path(OUT_DIR + file_name)
	var error: Error = img.save_png(path)
	if error != OK:
		push_error("No se pudo guardar %s (%s)" % [path, error_string(error)])
