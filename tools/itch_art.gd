extends SceneTree
## Genera las imágenes de la página de itch.io: la portada (630x500, pixel art compuesto con los sprites del juego)
## y cuatro capturas verticales de 720x1280 sacadas del juego de verdad.
##
## Uso (desde la raíz del proyecto; abre una ventana, así que no sirve --headless):
##   godot --path . --script res://tools/itch_art.gd                  # todo, en docs/itch/
##   godot --path . --script res://tools/itch_art.gd -- <carpeta>
## No toca la partida guardada: apaga el guardado antes de que arranque.

const Palette := preload("res://game/palette.gd")
const BiomePalette := preload("res://game/biome_palette.gd")

const DEFAULT_DIR: String = "res://docs/itch"
const SPRITES: String = "res://assets/sprites/generated/"
const SHOT_SIZE: Vector2i = Vector2i(720, 1280)
## La portada se dibuja chica y se amplía por un número entero: 126x100 x5 = 630x500.
const COVER_SIZE: Vector2i = Vector2i(126, 100)
const COVER_SCALE: int = 5

## `owned` sigue el orden del balance: Minero, Taladro, Dinamita, Gólem, Excavadora. "hits": golpes seguidos justo
## antes (ráfaga: números, astillas y gemas); "chest": rareza que cae; "wait": segundos antes de capturar.
const SHOTS: Array[Dictionary] = [
	{ "name": "1_tierra", "gold": 240.0, "run_gold": 320.0, "pick": 2, "owned": [5, 1], "loot": 0.06, "relics": 0, "hits": 4, "wait": 0.12 },
	{ "name": "2_cristal_frenesi", "gold": 86000.0, "run_gold": 240000.0, "pick": 6, "owned": [14, 6, 2, 1], "loot": 0.6, "relics": 1, "hits": 12, "wait": 0.08 },
	{ "name": "3_cofre_legendario", "gold": 5.6e6, "run_gold": 9.0e6, "pick": 7, "owned": [30, 10, 5, 2], "loot": 1.4, "relics": 3, "chest": 3, "wait": 1.15 },
	{ "name": "4_abismo_cuadrilla", "gold": 9.4e8, "run_gold": 2.0e9, "pick": 9, "owned": [60, 25, 12, 6, 6], "loot": 2.0, "relics": 8, "wait": 1.5 },
]

## Letras del título (5x7). Solo las que usa "POZO PROFUNDO".
const LETTERS: Dictionary = {
	"P": ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."],
	"O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"Z": ["XXXXX", "....X", "...X.", "..X..", ".X...", "X....", "XXXXX"],
	"R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
	"F": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "X...."],
	"U": ["X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"N": ["X...X", "XX..X", "XX..X", "X.X.X", "X..XX", "X..XX", "X...X"],
	"D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
}
## Trama ordenada 4x4: oscurece de a puntos en vez de con degradé, para que siga siendo pixel art.
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var _out_dir: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if not args.is_empty() else ProjectSettings.globalize_path(DEFAULT_DIR)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Antes de que Save haga su _ready (los autoloads arrancan después del primer frame).
	root.get_node("Save").persistence_enabled = false
	_run()


func _run() -> void:
	await process_frame
	_save(_cover(), "portada")
	await _screenshots()
	root.get_node("Audio").call("silence")
	await create_timer(0.3).timeout
	quit(0)


func _save(image: Image, file_name: String) -> void:
	var path: String = "%s/%s.png" % [_out_dir, file_name]
	image.save_png(path)
	print("%s  (%dx%d)" % [path, image.get_width(), image.get_height()])


# --- Capturas ----------------------------------------------------------------

## Sin cofres al azar: uno que caiga mientras se espera pisa el aviso que se quería mostrar (el "legendario"
## salía como "Común") y las imágenes cambian en cada corrida. El de la captura se pide a mano con drop_loot().
func _stop_random_chests() -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	balance["loot"]["chance_per_hit"] = 0.0
	balance["loot"]["chance_per_second"] = 0.0
	root.get_node("Economy").load_balance(balance)


func _screenshots() -> void:
	_stop_random_chests()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SHOT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var scene: Control = (load("res://game/main.tscn") as PackedScene).instantiate() as Control
	viewport.add_child(scene)
	if scene.has_node("DebugPanel"):
		scene.get_node("DebugPanel").free()
	var economy: Node = root.get_node("Economy")
	for shot: Dictionary in SHOTS:
		_apply(economy, shot)
		await _settle()
		# Que terminen el fundido de bioma y la cuadrilla que crece; después se limpia lo que quedó en el aire.
		await create_timer(1.2).timeout
		scene.get_node("%MineView").call("clear_effects")
		if shot.has("chest"):
			economy.drop_loot(int(shot["chest"]))
		for hit: int in range(int(shot.get("hits", 0))):
			(scene.get_node("%TapButton") as Button).button_down.emit()
			await create_timer(0.07).timeout
		await create_timer(float(shot.get("wait", 0.0))).timeout
		await _settle()
		_save(viewport.get_texture().get_image(), shot["name"])
	economy.reset()
	viewport.queue_free()
	await process_frame


func _apply(economy: Node, shot: Dictionary) -> void:
	economy.reset()
	economy.run_gold = shot["run_gold"]
	economy.gold = shot["gold"]
	economy.pick_level = shot["pick"]
	economy.loot_bonus = shot["loot"]
	economy.relics = shot["relics"]
	var owned: Array = shot["owned"]
	for index: int in range(owned.size()):
		economy.owned[index] = owned[index]
	economy.gold_changed.emit(economy.gold)


func _settle() -> void:
	for i: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw


# --- Portada -----------------------------------------------------------------

func _cover() -> Image:
	var canvas: Image = Image.create_empty(COVER_SIZE.x, COVER_SIZE.y, false, Image.FORMAT_RGBA8)
	var earth: Dictionary = BiomePalette.of("earth")
	_floor(canvas, earth)
	_vignette(canvas, Vector2(63.0, 70.0), 40.0, 86.0)
	_timber(canvas)
	_title(canvas)

	# La roca, al centro y apoyada en el piso.
	_shadow(canvas, Vector2i(63, 94), Vector2i(27, 5))
	_sprite(canvas, SPRITES + "rock_earth.png", Vector2i(39, 49), 3)
	# La cuadrilla: los de la izquierda miran a la derecha y al revés, con el pico hacia la roca.
	for miner: Array in [["miner_1_right", 20, 57, false], ["miner_4_right", 12, 77, false], ["miner_2_left", 90, 57, true], ["miner_6_left", 98, 77, true]]:
		var position: Vector2i = Vector2i(miner[1], miner[2])
		var mirrored: bool = miner[3]
		_shadow(canvas, position + Vector2i(8, 16), Vector2i(7, 2))
		_sprite(canvas, SPRITES + str(miner[0]) + ".png", position, 1)
		_sprite(canvas, SPRITES + "pick.png", position + Vector2i(-7 if mirrored else 7, -2), 1, mirrored)
	# Gemas que saltan y destellos.
	for gem: Vector2i in [Vector2i(36, 50), Vector2i(86, 47), Vector2i(31, 84), Vector2i(88, 88)]:
		_sprite(canvas, SPRITES + "gem.png", gem - Vector2i(4, 4), 1, false, 8)
	for spark: Vector2i in [Vector2i(45, 47), Vector2i(80, 55), Vector2i(10, 66), Vector2i(116, 70), Vector2i(57, 62)]:
		_spark(canvas, spark)

	canvas.resize(COVER_SIZE.x * COVER_SCALE, COVER_SIZE.y * COVER_SCALE, Image.INTERPOLATE_NEAREST)
	return canvas


## El piso de Tierra del juego: el mosaico mezclado con el color base.
func _floor(canvas: Image, colors: Dictionary) -> void:
	var tile: Image = _image(SPRITES + "bg_earth.png")
	var base: Color = colors["bg_dark"]
	for y: int in range(canvas.get_height()):
		for x: int in range(canvas.get_width()):
			var pixel: Color = tile.get_pixel(x % tile.get_width(), y % tile.get_height())
			canvas.set_pixel(x, y, base.lerp(Color(pixel, 1.0), 0.55))


## Oscurece hacia afuera de `center`, con trama: nada dentro de `inner`, casi negro desde `outer`.
func _vignette(canvas: Image, center: Vector2, inner: float, outer: float) -> void:
	var dark: Color = Color(0.08, 0.05, 0.06)
	for y: int in range(canvas.get_height()):
		for x: int in range(canvas.get_width()):
			var amount: float = clampf((Vector2(x, y).distance_to(center) - inner) / (outer - inner), 0.0, 1.0)
			var threshold: float = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
			var level: float = floorf(amount * 3.0 + threshold) / 3.0
			if level > 0.0:
				canvas.set_pixel(x, y, canvas.get_pixel(x, y).lerp(dark, minf(level, 1.0) * 0.9))


## La entrada de la mina: viga, dos postes y un farol colgando de cada lado.
func _timber(canvas: Image) -> void:
	for post_x: int in [2, 118]:
		_plank(canvas, Rect2i(post_x, 42, 6, 58))
	_plank(canvas, Rect2i(0, 41, COVER_SIZE.x, 5))
	for post_x: int in [2, 118]:
		for nail: Vector2i in [Vector2i(2, 2), Vector2i(2, 40)]:
			canvas.set_pixel(post_x + nail.x, 41 + nail.y, Palette.STEEL_LIGHT)
	for lantern_x: int in [13, 112]:
		canvas.fill_rect(Rect2i(lantern_x, 46, 1, 3), Palette.OUTLINE)
		_glow(canvas, Vector2(lantern_x + 0.5, 52.0), 11.0)
		canvas.fill_rect(Rect2i(lantern_x - 2, 49, 5, 6), Palette.OUTLINE)
		canvas.fill_rect(Rect2i(lantern_x - 1, 50, 3, 4), Palette.GOLD)
		canvas.fill_rect(Rect2i(lantern_x, 51, 1, 2), Palette.YELLOW)


func _plank(canvas: Image, rect: Rect2i) -> void:
	canvas.fill_rect(rect, Palette.OUTLINE)
	var inside: Rect2i = rect.grow(-1)
	canvas.fill_rect(inside, Palette.MAROON)
	var vertical: bool = rect.size.y > rect.size.x
	var light: Rect2i = Rect2i(inside.position, Vector2i(1, inside.size.y) if vertical else Vector2i(inside.size.x, 1))
	canvas.fill_rect(light, Palette.TERRA)


func _glow(canvas: Image, center: Vector2, radius: float) -> void:
	for y: int in range(maxi(int(center.y - radius), 0), mini(int(center.y + radius) + 1, canvas.get_height())):
		for x: int in range(maxi(int(center.x - radius), 0), mini(int(center.x + radius) + 1, canvas.get_width())):
			var strength: float = 1.0 - Vector2(x, y).distance_to(center) / radius
			if strength > 0.0:
				canvas.set_pixel(x, y, canvas.get_pixel(x, y).lerp(Palette.GOLD, strength * 0.4))


## "POZO" grande y "PROFUNDO" debajo, con contorno y sombra.
func _title(canvas: Image) -> void:
	_word(canvas, "POZO", 3, 3)
	_word(canvas, "PROFUNDO", 25, 2)


func _word(canvas: Image, word: String, top: int, scale: int) -> void:
	var width: int = word.length() * 5 * scale + (word.length() - 1) * scale
	var left: int = int((canvas.get_width() - width) / 2.0)
	var pixels: Array[Vector2i] = []
	for index: int in range(word.length()):
		var rows: Array = LETTERS[word[index]]
		for row: int in range(7):
			for column: int in range(5):
				if str(rows[row])[column] != "X":
					continue
				for dy: int in range(scale):
					for dx: int in range(scale):
						pixels.append(Vector2i(left + index * 6 * scale + column * scale + dx, top + row * scale + dy))
	# Sombra, contorno y letra, en ese orden: así el contorno de una letra no pisa a la de al lado.
	for pixel: Vector2i in pixels:
		_dot(canvas, pixel + Vector2i(1, 2), Color(0.05, 0.03, 0.04))
	for pixel: Vector2i in pixels:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				_dot(canvas, pixel + Vector2i(dx, dy), Palette.OUTLINE)
	for pixel: Vector2i in pixels:
		var share: float = float(pixel.y - top) / float(7 * scale)
		_dot(canvas, pixel, Palette.YELLOW if share < 0.55 else Palette.GOLD)


func _shadow(canvas: Image, center: Vector2i, radius: Vector2i) -> void:
	for y: int in range(-radius.y, radius.y + 1):
		for x: int in range(-radius.x, radius.x + 1):
			if pow(float(x) / radius.x, 2.0) + pow(float(y) / radius.y, 2.0) <= 1.0:
				var at: Vector2i = center + Vector2i(x, y)
				if at.x >= 0 and at.y >= 0 and at.x < canvas.get_width() and at.y < canvas.get_height():
					canvas.set_pixelv(at, canvas.get_pixelv(at).lerp(Color.BLACK, 0.45))


func _spark(canvas: Image, center: Vector2i) -> void:
	_dot(canvas, center, Palette.WHITE)
	for arm: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		_dot(canvas, center + arm, Palette.YELLOW)


func _dot(canvas: Image, at: Vector2i, color: Color) -> void:
	if at.x >= 0 and at.y >= 0 and at.x < canvas.get_width() and at.y < canvas.get_height():
		canvas.set_pixelv(at, color)


## Pega un sprite ampliado por un entero (o llevado a `size` píxeles de lado), opcionalmente espejado.
func _sprite(canvas: Image, path: String, at: Vector2i, scale: int, mirrored: bool = false, size: int = 0) -> void:
	var image: Image = _image(path)
	var target: Vector2i = Vector2i(size, size) if size > 0 else image.get_size() * scale
	image.resize(target.x, target.y, Image.INTERPOLATE_NEAREST)
	if mirrored:
		image.flip_x()
	canvas.blend_rect(image, Rect2i(Vector2i.ZERO, target), at)


## Una copia en RGBA8 de la imagen importada (se puede tocar sin afectar al recurso).
func _image(path: String) -> Image:
	var image: Image = (load(path) as Texture2D).get_image().duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image
