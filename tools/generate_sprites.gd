extends SceneTree
## Dibuja por código los sprites 16x16 que Tiny Dungeon no trae y recolorea los mineros.
##
## Uso (desde la raíz del proyecto):
##   godot --headless --path . --script res://tools/generate_sprites.gd
##   godot --headless --path . --import      # para que Godot importe los PNG nuevos
##
## Todo sale a res://assets/sprites/generated/ como PNG de 16x16 con SOLO los 27 colores de
## Tiny Dungeon (game/palette.gd): roca y piso (visto desde arriba) de cada bioma, taladro, gólem,
## dinamita, runas, moneda, pico, gema y las variantes de los mineros (de color y de mirada: izquierda,
## derecha y abajo). Cada sprite se dibuja "relleno" y
## después se le pone el contorno oscuro del pack automáticamente (un píxel alrededor).
## Es determinista: correrlo de nuevo reescribe exactamente los mismos archivos.

const Palette := preload("res://game/palette.gd")
const BiomePalette := preload("res://game/biome_palette.gd")

const OUT_DIR: String = "res://assets/sprites/generated/"
const TINY_DUNGEON_DIR: String = "res://assets/sprites/tiny_dungeon/"
const SIZE: int = 16
const T: Color = Color(0.0, 0.0, 0.0, 0.0)

## Hacia dónde mira cada variante de un minero: cuánto se corren los ojos (1 px) respecto del frente. Los
## personajes de Tiny Dungeon miran de frente; así se los puede parar mirando hacia la roca.
const GAZES: Dictionary = { "left": Vector2i(-1, 0), "right": Vector2i(1, 0), "down": Vector2i(0, 1) }

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
		_save(_chips(id), "chips_%s.png" % id)
	_save(_drill(), "drill.png")
	_save(_golem(), "golem.png")
	_save(_dynamite(), "dynamite.png")
	for number: int in range(1, 4):
		_save(_rune(number), "rune_%d.png" % number)
	_save(_coin(), "coin.png")
	_save(_pick(), "pick.png")
	_save(_gem(), "gem.png")
	for entry: Array in MINERS:
		var front: Image = _miner(entry[1], entry[2])
		_save(front, "%s.png" % entry[0])
		for gaze: String in GAZES:
			_save(_look(front, GAZES[gaze]), "%s_%s.png" % [entry[0], gaze])
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
	if CRACKS.has(id):
		_draw_cracks(img, CRACKS[id], colors["vein"], colors["vein_light"])
	else:
		_overlay(img, _veins(id), palette)
	_outline(img)
	return img


## Grietas de Roca (óxido) y Magma (lava): líneas quebradas por estos puntos, con un tronco irregular y
## ramas que salen a los costados (ninguna es una diagonal recta). La primera lista de cada una es el
## tronco; las demás nacen en puntos del tronco o de otra rama.
const CRACKS: Dictionary = {
	"rock": [
		[Vector2i(10, 3), Vector2i(9, 4), Vector2i(9, 6), Vector2i(8, 7), Vector2i(8, 9), Vector2i(7, 10), Vector2i(8, 12)],
		[Vector2i(9, 6), Vector2i(11, 6), Vector2i(12, 8), Vector2i(12, 10)],
		[Vector2i(8, 7), Vector2i(6, 7), Vector2i(5, 9), Vector2i(3, 9)],
		[Vector2i(8, 9), Vector2i(10, 10), Vector2i(11, 12)],
		[Vector2i(9, 4), Vector2i(7, 4), Vector2i(6, 5)],
	],
	"magma": [
		[Vector2i(8, 3), Vector2i(7, 5), Vector2i(8, 6), Vector2i(7, 8), Vector2i(8, 10), Vector2i(7, 12)],
		[Vector2i(7, 5), Vector2i(5, 5), Vector2i(4, 7), Vector2i(2, 7)],
		[Vector2i(8, 6), Vector2i(10, 6), Vector2i(11, 8), Vector2i(13, 8)],
		[Vector2i(7, 8), Vector2i(5, 9), Vector2i(4, 11)],
		[Vector2i(8, 10), Vector2i(10, 11), Vector2i(12, 11)],
		[Vector2i(10, 6), Vector2i(11, 4), Vector2i(12, 3)],
	],
}


## Pinta las grietas `lines` (listas de puntos) solo sobre la roca; cada tercer píxel de una grieta es
## "luz" (más claro), para que parezca que brilla o que tiene relieve.
func _draw_cracks(img: Image, lines: Array, vein: Color, vein_light: Color) -> void:
	for points: Array in lines:
		var painted: Array[Vector2i] = []
		for index: int in range(points.size() - 1):
			for point: Vector2i in _line_points(points[index], points[index + 1]):
				if img.get_pixelv(point).a > 0.5 and not painted.has(point):
					painted.append(point)
		for index: int in range(painted.size()):
			img.set_pixelv(painted[index], vein_light if index % 3 == 0 else vein)


## Los píxeles de la línea de `from` a `to` (Bresenham), extremos incluidos.
func _line_points(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var delta: Vector2i = Vector2i(absi(to.x - from.x), -absi(to.y - from.y))
	var step: Vector2i = Vector2i(1 if from.x < to.x else -1, 1 if from.y < to.y else -1)
	var error: int = delta.x + delta.y
	var current: Vector2i = from
	while true:
		points.append(current)
		if current == to:
			break
		var doubled: int = 2 * error
		if doubled >= delta.y:
			error += delta.y
			current.x += step.x
		if doubled <= delta.x:
			error += delta.x
			current.y += step.y
	return points


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


## Formas con las que se arman las marcas del piso. Hay de todas las orientaciones y tantas en horizontal
## como en vertical: un piso visto desde arriba no tiene un "arriba" ni estratos (las marcas alargadas en
## horizontal parecen capas de una pared).
const CLUMPS: Array = [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
]
const PAIRS: Array = [
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(0, 1)],
]
const BLOCK: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
## La sombra de una piedra chica (la luz viene de arriba a la izquierda, como en las rocas).
const PEBBLE_SHADOW: Array = [Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
const DOT: Array = [Vector2i(0, 0)]


## Mosaico de fondo 16x16 que se repite sin costuras: un piso visto desde arriba. Cada bioma tiene el
## suyo (tierra con piedritas, lajas, esquirlas de cristal, basalto agrietado con brasas, penumbra con
## motas). Los colores quedan cerca del base: la escena además lo mezcla con él para bajar el contraste.
func _background(id: String) -> Image:
	var colors: Dictionary = BiomePalette.of(id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) # los mismos píxeles cada vez que se genera
	var img: Image = _blank()
	img.fill(colors["bg"])
	match id:
		"earth": # tierra apisonada: terrones oscuros, piedritas con su sombra y alguna chispa
			_scatter(img, rng, CLUMPS, colors["bg_dark"], 5)
			_pebbles(img, rng, colors["bg_light"], colors["bg_dark"], 5)
			_scatter(img, rng, [DOT], colors["bg_spark"], 3)
		"rock": # lajas de piedra con sus juntas
			_flagstones(img, colors)
			_scatter(img, rng, [DOT], colors["bg_spark"], 3)
		"crystal": # piso oscuro con piedras y esquirlas de cristal
			_pebbles(img, rng, colors["bg_light"], colors["bg_dark"], 4)
			_scatter(img, rng, [[Vector2i(0, 0), Vector2i(1, 1)], [Vector2i(1, 0), Vector2i(0, 1)]], colors["bg_spark"], 5)
			_scatter(img, rng, [DOT], colors["bg_spark"], 3)
		"magma": # basalto agrietado, con brasas
			for walk: int in range(3):
				_crack_walk(img, rng, colors["bg_light"], 14)
			_scatter(img, rng, [DOT], colors["bg_spark"], 5)
			_scatter(img, rng, PAIRS, colors["bg_spark"], 1)
		"abyss": # penumbra con manchas y motas
			_scatter(img, rng, CLUMPS, colors["bg_dark"], 6)
			_scatter(img, rng, PAIRS, colors["bg_light"], 4)
			_scatter(img, rng, [DOT], colors["bg_light"], 8)
	return img


## Estampa `count` veces una forma al azar de `shapes` (con vuelta al otro borde: el mosaico no tiene costura).
func _scatter(img: Image, rng: RandomNumberGenerator, shapes: Array, color: Color, count: int) -> void:
	for i: int in range(count):
		_stamp(img, Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1)), shapes[rng.randi_range(0, shapes.size() - 1)], color)


## Piedritas de 2x2 con su sombra abajo a la derecha.
func _pebbles(img: Image, rng: RandomNumberGenerator, light: Color, shadow: Color, count: int) -> void:
	for i: int in range(count):
		var origin: Vector2i = Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
		_stamp(img, origin, PEBBLE_SHADOW, shadow)
		_stamp(img, origin, BLOCK, light)


func _stamp(img: Image, origin: Vector2i, shape: Array, color: Color) -> void:
	for offset: Vector2i in shape:
		img.set_pixelv(Vector2i(posmod(origin.x + offset.x, SIZE), posmod(origin.y + offset.y, SIZE)), color)


## Una grieta del piso: camina al azar `steps` pasos (mitad en horizontal, mitad en vertical).
func _crack_walk(img: Image, rng: RandomNumberGenerator, color: Color, steps: int) -> void:
	var position: Vector2i = Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
	var heading: Vector2i = Vector2i(1, 0)
	for step: int in range(steps):
		img.set_pixelv(position, color)
		if rng.randf() < 0.4: # cambia de rumbo: doblá 90 grados para cualquiera de los dos lados
			heading = Vector2i(heading.y, heading.x) * (1 if rng.randf() < 0.5 else -1)
		position = Vector2i(posmod(position.x + heading.x, SIZE), posmod(position.y + heading.y, SIZE))


## Lajas de piedra: juntas torcidas que forman celdas de 8x8 (como en un piso, no como ladrillos de pared).
func _flagstones(img: Image, colors: Dictionary) -> void:
	var joint: Color = colors["bg_dark"]
	var light: Color = colors["bg_light"]
	for x: int in range(SIZE):
		img.set_pixel(x, 1 if x in [5, 6, 12] else 0, joint)
		img.set_pixel(x, 9 if x in [2, 3, 10, 11] else 8, joint)
	for y: int in range(1, 8):
		img.set_pixel(3 if y in [3, 4] else 2, y, joint)
		img.set_pixel(11 if y in [5, 6] else 10, y, joint)
	for y: int in range(10, 16):
		img.set_pixel(7 if y in [12, 13] else 6, y, joint)
		img.set_pixel(15 if y in [12] else 14, y, joint)
	# el brillo de cada laja: una L clara en su esquina de arriba a la izquierda
	for corner: Vector2i in [Vector2i(4, 2), Vector2i(12, 2), Vector2i(8, 11), Vector2i(0, 11)]:
		for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			img.set_pixelv(Vector2i(posmod(corner.x + offset.x, SIZE), posmod(corner.y + offset.y, SIZE)), light)


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


## Astillas que saltan de la roca al golpear: 4 dibujos de 4x4 en una hoja de 16x16 (uno en el medio de cada
## cuarto de 8x8), con las tres sombras de la roca del bioma y contorno. La escena corta la hoja en 2x2
## cuadros y a cada partícula le toca uno al azar. El contorno no llega a los bordes de cada cuarto.
const CHIPS: Array = [
	[".LL.", "LRRD", "RRDD", ".DD."],
	["..L.", ".LRR", "LRRD", ".RD."],
	["....", "LLRR", ".RDD", "...."],
	[".L..", "LRR.", ".RDD", "..D."],
]


func _chips(id: String) -> Image:
	var colors: Dictionary = BiomePalette.of(id)
	var keys: Dictionary = { "L": colors["rock_light"], "R": colors["rock"], "D": colors["rock_dark"] }
	var img: Image = _blank()
	for index: int in range(CHIPS.size()):
		var origin: Vector2i = Vector2i((index % 2) * 8 + 2, (index / 2) * 8 + 2)
		var rows: Array = CHIPS[index]
		for y: int in range(rows.size()):
			for x: int in range(str(rows[y]).length()):
				var key: String = str(rows[y])[x]
				if keys.has(key):
					img.set_pixel(origin.x + x, origin.y + y, keys[key])
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


## El mismo minero con los ojos (los píxeles oscuros de la cara) corridos `shift`: mira para ese lado.
## Donde estaba el ojo queda la piel que tenía detrás (contra el sentido del giro).
func _look(img: Image, shift: Vector2i) -> Image:
	var result: Image = img.duplicate()
	var eyes: Array[Vector2i] = []
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			if img.get_pixel(x, y) == Palette.NAVY:
				eyes.append(Vector2i(x, y))
	for eye: Vector2i in eyes:
		var behind: Vector2i = eye - shift
		while eyes.has(behind):
			behind -= shift
		result.set_pixelv(eye, img.get_pixelv(behind))
	for eye: Vector2i in eyes:
		result.set_pixelv(eye + shift, Palette.NAVY)
	return result


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
