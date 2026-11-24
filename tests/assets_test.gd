extends "res://tests/test_base.gd"
## Tests headless de los assets de arte (F2-A): que estén todos, que los sprites dibujados por
## código sean de 16x16 y usen solo la paleta de Tiny Dungeon, y que CREDITS.md los registre.
##
## No miran cómo se ven: de eso se ocupan las capturas. Miran lo que se rompe en silencio
## (un bioma nuevo sin arte, un color fuera de paleta, un asset sin crédito).

const Palette := preload("res://game/palette.gd")
const BiomePalette := preload("res://game/biome_palette.gd")

const GENERATED_DIR: String = "res://assets/sprites/generated/"
const TINY_DUNGEON_DIR: String = "res://assets/sprites/tiny_dungeon/"
const UI_PACK_DIR: String = "res://assets/ui/ui_pack/"
const FONT_PATH: String = "res://assets/fonts/PixelifySans.ttf"
const CREDITS_PATH: String = "res://CREDITS.md"
const BALANCE_PATH: String = "res://data/balance.json"

const MineView := preload("res://game/mine_view.gd")

const SINGLE_SPRITES: Array[String] = [
	"drill", "golem", "dynamite", "rune_1", "rune_2", "rune_3", "coin", "pick", "gem",
	"miner_1", "miner_2", "miner_3", "miner_4", "miner_5", "miner_6", "miner_7", "miner_8",
]
## Hacia dónde mira cada variante de un minero: cuánto se desplazan sus ojos (1 px) respecto del frente.
const GAZES: Dictionary = { "left": Vector2i(-1, 0), "right": Vector2i(1, 0), "down": Vector2i(0, 1) }
## Los colores del UI Pack que tienen un rol (amarillo: pestaña activa, verde: comprar, rojo: prestigio,
## gris: no alcanza). El azul no se usa y por eso no se importa.
const UI_COLORS: Array[String] = ["yellow", "green", "red", "grey"]
## Los 8 vecinos de un píxel, en orden circular.
const RING: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
## Extensiones que no son assets (los genera Godot o son textos de licencia).
const IGNORED_FILES: Array[String] = ["import", "uid", "gitkeep", "txt"]


func _initialize() -> void:
	_test_palette()
	_test_every_biome_has_art()
	_test_generated_sprites()
	_test_miners_are_different()
	_test_biomes_look_different()
	_test_miners_look_at_the_rock()
	_test_cracks_branch()
	_test_floor_is_seen_from_above()
	_test_background_is_low_contrast()
	_test_rock_chips()
	_test_orbit_runes()
	_test_tiny_dungeon_tiles()
	_test_ui_pack_and_font()
	_test_credits()
	_finish()


func _balance_biome_ids() -> Array[String]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	var ids: Array[String] = []
	if parsed is Dictionary and (parsed as Dictionary).has("biomes"):
		for entry: Variant in parsed["biomes"]["list"]:
			ids.append(str((entry as Dictionary)["id"]))
	return ids


## Colores (en hex) de los píxeles opacos de `img` que no están en la paleta; un alfa a medias
## también cuenta como fuera de paleta. Devuelve un diccionario hex -> cantidad.
func _off_palette(img: Image) -> Dictionary:
	var allowed: Dictionary = {}
	for color: Color in Palette.ALL:
		allowed[color.to_html(false)] = true
	var off: Dictionary = {}
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var pixel: Color = img.get_pixel(x, y)
			if pixel.a == 0.0:
				continue
			var key: String = pixel.to_html(false) if pixel.a == 1.0 else pixel.to_html(true)
			if pixel.a < 1.0 or not allowed.has(key):
				off[key] = int(off.get(key, 0)) + 1
	return off


## La imagen de un PNG ya importado (como la ve el juego), en RGBA8; null si no se puede cargar.
func _load_image(path: String) -> Image:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null
	var img: Image = texture.get_image()
	if img == null:
		return null
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _same_pixels(a: Image, b: Image) -> bool:
	return a.get_size() == b.get_size() and a.get_data() == b.get_data()


func _test_palette() -> void:
	_section("Paleta de Tiny Dungeon")
	var seen: Dictionary = {}
	for color: Color in Palette.ALL:
		seen[color.to_html(false)] = true
	_check_eq(Palette.ALL.size(), 27, "son los 27 colores del pack")
	_check_eq(seen.size(), 27, "y los 27 son distintos")
	# El validador tiene que poder fallar: un rojo puro no es de la paleta y un alfa a medias tampoco.
	var probe: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	probe.fill(T_CLEAR)
	probe.set_pixel(0, 0, Color8(255, 0, 0))
	probe.set_pixel(1, 0, Palette.GOLD)
	probe.set_pixel(0, 1, Color(Palette.GOLD, 0.5))
	var off: Dictionary = _off_palette(probe)
	_check_eq(off.size(), 2, "el validador detecta un rojo puro y un alfa a medias, y deja pasar el dorado")


const T_CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)


func _test_every_biome_has_art() -> void:
	_section("Cada bioma del balance tiene arte")
	var ids: Array[String] = _balance_biome_ids()
	_check_eq(ids.size(), 5, "el balance tiene 5 biomas")
	for id: String in ids:
		_check(BiomePalette.BY_ID.has(id), "'%s' tiene colores en game/biome_palette.gd" % id)
		_check(FileAccess.file_exists(GENERATED_DIR + "rock_%s.png" % id), "'%s' tiene su roca (rock_%s.png)" % [id, id])
		_check(FileAccess.file_exists(GENERATED_DIR + "bg_%s.png" % id), "'%s' tiene su fondo (bg_%s.png)" % [id, id])
		_check(ResourceLoader.exists(GENERATED_DIR + "rock_%s.png" % id), "y la roca de '%s' está importada" % id)
	_check_eq(BiomePalette.IDS, ids, "BiomePalette.IDS coincide con los ids del balance, en el mismo orden")


func _generated_files() -> Array[String]:
	var files: Array[String] = []
	for id: String in BiomePalette.IDS:
		files.append("rock_%s" % id)
		files.append("bg_%s" % id)
	files.append_array(SINGLE_SPRITES)
	for number: int in range(1, 9):
		for gaze: String in GAZES:
			files.append("miner_%d_%s" % [number, gaze])
	return files


func _test_generated_sprites() -> void:
	_section("Sprites dibujados por código: 16x16 y solo paleta de Tiny Dungeon")
	for file_name: String in _generated_files():
		var path: String = GENERATED_DIR + file_name + ".png"
		var img: Image = _load_image(path)
		if img == null:
			_check(false, "%s existe y se puede leer" % file_name)
			continue
		_check_eq(img.get_size(), Vector2i(16, 16), "%s es de 16x16" % file_name)
		var off: Dictionary = _off_palette(img)
		_check(off.is_empty(), "%s usa solo colores de la paleta (fuera: %s)" % [file_name, str(off)])
		if not file_name.begins_with("bg_"):
			var opaque: int = 0
			for y: int in range(16):
				for x: int in range(16):
					if img.get_pixel(x, y).a == 1.0:
						opaque += 1
			_check(opaque > 20 and opaque < 256, "%s no está vacío ni lleno: tiene silueta (%d píxeles)" % [file_name, opaque])
	_check(ResourceLoader.exists(GENERATED_DIR + "golem.png"), "los sprites están importados por Godot (se pueden cargar con load)")


func _test_miners_are_different() -> void:
	_section("Los mineros tienen variaciones de color")
	var images: Array[Image] = []
	for number: int in range(1, 9):
		images.append(_load_image(GENERATED_DIR + "miner_%d.png" % number))
	var distinct: int = 0
	for i: int in range(images.size()):
		var unique: bool = true
		for j: int in range(i):
			if _same_pixels(images[i], images[j]):
				unique = false
		if unique:
			distinct += 1
	_check_eq(distinct, 8, "los 8 mineros son todos distintos entre sí")
	# Las variantes de color de un mismo personaje comparten silueta (mismos píxeles opacos).
	var same_silhouette: bool = true
	for y: int in range(16):
		for x: int in range(16):
			if (images[0].get_pixel(x, y).a > 0.5) != (images[1].get_pixel(x, y).a > 0.5):
				same_silhouette = false
	_check(same_silhouette, "miner_2 es miner_1 con otro color de ropa (misma silueta)")
	_check(not _same_pixels(images[0], images[1]), "pero con otros colores")


func _test_biomes_look_different() -> void:
	_section("Cada bioma cambia la paleta de la roca y del fondo")
	for prefix: String in ["rock_", "bg_"]:
		var images: Array[Image] = []
		for id: String in BiomePalette.IDS:
			images.append(_load_image(GENERATED_DIR + prefix + id + ".png"))
		var all_different: bool = true
		for i: int in range(images.size()):
			for j: int in range(i):
				if _same_pixels(images[i], images[j]):
					all_different = false
		_check(all_different, "los 5 '%s*' son distintos entre sí" % prefix)
	# Los colores base de cada bioma también (si dos biomas comparten fondo y roca no se nota el cambio).
	var bases: Dictionary = {}
	for id: String in BiomePalette.IDS:
		var colors: Dictionary = BiomePalette.of(id)
		bases["%s|%s" % [colors["bg"].to_html(), colors["rock"].to_html()]] = true
	_check_eq(bases.size(), 5, "no hay dos biomas con el mismo par fondo + roca")
	_check_eq(BiomePalette.of("no_existe"), BiomePalette.of("earth"), "un bioma desconocido usa los colores de Tierra")


## Los píxeles de `img` que tienen exactamente el color `color`.
func _pixels_of(img: Image, color: Color) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var pixel: Color = img.get_pixel(x, y)
			if pixel.a == 1.0 and pixel == color:
				found.append(Vector2i(x, y))
	return found


## Cada minero tiene una variante que mira a la izquierda, a la derecha y hacia abajo (a la roca, según
## dónde esté parado): los mismos píxeles, con los ojos (los píxeles oscuros de la cara) corridos 1 px.
func _test_miners_look_at_the_rock() -> void:
	_section("Mineros que miran hacia la roca")
	for number: int in range(1, 9):
		var front: Image = _load_image(GENERATED_DIR + "miner_%d.png" % number)
		var front_eyes: Array[Vector2i] = _pixels_of(front, Palette.NAVY)
		_check_eq(front_eyes.size(), 4, "miner_%d: 4 píxeles de ojos al frente" % number)
		for gaze: String in GAZES:
			var img: Image = _load_image(GENERATED_DIR + "miner_%d_%s.png" % [number, gaze])
			if img == null:
				_check(false, "existe miner_%d_%s.png" % [number, gaze])
				continue
			var shift: Vector2i = GAZES[gaze]
			var expected: Dictionary = {}
			for eye: Vector2i in front_eyes:
				expected[eye + shift] = true
			var actual: Dictionary = {}
			for eye: Vector2i in _pixels_of(img, Palette.NAVY):
				actual[eye] = true
			_check_eq(actual.keys().size(), 4, "miner_%d_%s: sigue teniendo 4 píxeles de ojos" % [number, gaze])
			_check_eq(actual.keys(), expected.keys(), "miner_%d_%s: los ojos están corridos 1 px hacia %s" % [number, gaze, gaze])
			var same_silhouette: bool = true
			var changed: int = 0
			for y: int in range(16):
				for x: int in range(16):
					if (front.get_pixel(x, y).a > 0.5) != (img.get_pixel(x, y).a > 0.5):
						same_silhouette = false
					if front.get_pixel(x, y) != img.get_pixel(x, y):
						changed += 1
			_check(same_silhouette, "miner_%d_%s: misma silueta que al frente" % [number, gaze])
			_check(changed > 0 and changed <= 8, "miner_%d_%s: solo cambian los ojos (%d píxeles)" % [number, gaze, changed])


## Las vetas de Roca y Magma son grietas irregulares y ramificadas, no una línea diagonal: se abren en
## las dos diagonales (no caben en una franja) y tienen bifurcaciones.
func _test_cracks_branch() -> void:
	_section("Vetas de Roca y Magma: grietas ramificadas")
	for id: String in ["rock", "magma"]:
		var colors: Dictionary = BiomePalette.of(id)
		var img: Image = _load_image(GENERATED_DIR + "rock_%s.png" % id)
		var veins: Dictionary = {}
		for color: Color in [colors["vein"], colors["vein_light"]]:
			for point: Vector2i in _pixels_of(img, color):
				veins[point] = true
		_check(veins.size() >= 24 and veins.size() <= 70, "rock_%s: la veta tiene un tamaño razonable (%d píxeles)" % [id, veins.size()])
		var min_diag: int = 99
		var max_diag: int = -99
		var min_anti: int = 99
		var max_anti: int = -99
		var forks: int = 0
		for point: Vector2i in veins:
			min_diag = mini(min_diag, point.x - point.y)
			max_diag = maxi(max_diag, point.x - point.y)
			min_anti = mini(min_anti, point.x + point.y)
			max_anti = maxi(max_anti, point.x + point.y)
			# Una bifurcación real: alrededor del píxel hay 3 o más tramos de veta separados. (Una línea
			# gruesa o en diagonal tiene a lo sumo 2: de dónde viene y a dónde va.)
			var arcs: int = 0
			for index: int in range(RING.size()):
				if veins.has(point + RING[index]) and not veins.has(point + RING[(index + 7) % RING.size()]):
					arcs += 1
			if arcs >= 3:
				forks += 1
		_check(max_diag - min_diag >= 6, "rock_%s: no cabe en una franja diagonal \\ (ancho %d)" % [id, max_diag - min_diag])
		_check(max_anti - min_anti >= 6, "rock_%s: ni en una franja diagonal / (ancho %d)" % [id, max_anti - min_anti])
		_check(forks >= 3, "rock_%s: es una grieta ramificada, no una línea (%d bifurcaciones, mín 3)" % [id, forks])


## El fondo se lee como piso visto desde arriba, no como una pared con estratos: las marcas no se
## alinean en horizontal (tantos pares de píxeles vecinos en horizontal como en vertical) y no la cubren.
func _test_floor_is_seen_from_above() -> void:
	_section("El fondo es un piso visto desde arriba")
	for id: String in BiomePalette.IDS:
		var base: Color = BiomePalette.of(id)["bg"]
		var img: Image = _load_image(GENERATED_DIR + "bg_%s.png" % id)
		var marks: Dictionary = {}
		for y: int in range(16):
			for x: int in range(16):
				if img.get_pixel(x, y) != base:
					marks[Vector2i(x, y)] = true
		var horizontal: int = 0
		var vertical: int = 0
		for point: Vector2i in marks:
			if marks.has(Vector2i((point.x + 1) % 16, point.y)):
				horizontal += 1
			if marks.has(Vector2i(point.x, (point.y + 1) % 16)):
				vertical += 1
		var density: float = marks.size() / 256.0
		var ratio: float = (horizontal + 1.0) / (vertical + 1.0)
		_check(density >= 0.06 and density <= 0.45, "bg_%s: las marcas cubren una parte razonable (%.0f%%)" % [id, density * 100.0])
		_check(ratio >= 0.55 and ratio <= 1.8, "bg_%s: sin estratos, las marcas no se alinean en horizontal (H/V = %.2f)" % [id, ratio])


## El fondo tiene poco contraste (la escena lo mezcla con el color base) y la roca sigue destacándose.
func _test_background_is_low_contrast() -> void:
	_section("Fondo de bajo contraste, roca bien visible")
	var mine_script: GDScript = MineView
	var strength: float = float(mine_script.get_script_constant_map().get("BACKDROP_STRENGTH", -1.0))
	_check(strength > 0.0 and strength <= 0.7, "la escena mezcla el mosaico al %.0f%% sobre el color base" % (strength * 100.0))
	for id: String in BiomePalette.IDS:
		var base: Color = BiomePalette.of(id)["bg"]
		var tile: Image = _load_image(GENERATED_DIR + "bg_%s.png" % id)
		var widest: float = 0.0
		for y: int in range(16):
			for x: int in range(16):
				widest = maxf(widest, absf(tile.get_pixel(x, y).get_luminance() - base.get_luminance()))
		_check(widest * strength <= 0.13, "bg_%s: la marca más fuerte se ve a %.3f de luminancia del base (máx 0.13)" % [id, widest * strength])
		var rock: Image = _load_image(GENERATED_DIR + "rock_%s.png" % id)
		var total: float = 0.0
		var count: int = 0
		for y: int in range(16):
			for x: int in range(16):
				var pixel: Color = rock.get_pixel(x, y)
				if pixel.a == 1.0 and pixel != Palette.OUTLINE:
					total += pixel.get_luminance()
					count += 1
		var gap: float = absf(total / maxi(count, 1) - base.get_luminance())
		_check(gap >= 0.1, "rock_%s: la roca se despega del fondo (diferencia de luminancia %.3f, mín 0.1)" % [id, gap])


## Astillas de roca (partículas del golpe): una hoja de 16x16 por bioma con 4 astillas de 8x8 (una por
## cuarto), pintadas con las sombras de la roca de ese bioma y el contorno. Los bordes entre cuartos quedan
## transparentes: al cortar la hoja en 2x2 cuadros, una astilla no se mete en otra.
func _test_rock_chips() -> void:
	_section("Astillas de roca por bioma")
	for id: String in BiomePalette.IDS:
		var path: String = GENERATED_DIR + "chips_%s.png" % id
		var img: Image = _load_image(path)
		if img == null:
			_check(false, "existe chips_%s.png" % id)
			continue
		_check_eq(img.get_size(), Vector2i(16, 16), "chips_%s es una hoja de 16x16" % id)
		var colors: Dictionary = BiomePalette.of(id)
		var allowed: Array[Color] = [colors["rock_light"], colors["rock"], colors["rock_dark"], Palette.OUTLINE]
		var foreign: int = 0
		var used: Dictionary = {}
		var per_quadrant: Array[int] = [0, 0, 0, 0]
		var on_seams: int = 0
		for y: int in range(16):
			for x: int in range(16):
				var pixel: Color = img.get_pixel(x, y)
				if pixel.a == 0.0:
					continue
				if not allowed.has(pixel) or pixel.a < 1.0:
					foreign += 1
				used[pixel.to_html()] = true
				per_quadrant[(x / 8) + 2 * (y / 8)] += 1
				if x in [0, 7, 8, 15] or y in [0, 7, 8, 15]:
					on_seams += 1
		_check_eq(foreign, 0, "chips_%s usa solo las sombras de la roca del bioma y el contorno" % id)
		_check(used.size() >= 3, "chips_%s tiene volumen (%d colores)" % [id, used.size()])
		_check(per_quadrant.all(func(count: int) -> bool: return count >= 4 and count <= 30), "chips_%s tiene una astilla en cada cuarto (%s)" % [id, str(per_quadrant)])
		_check_eq(on_seams, 0, "chips_%s deja libres los bordes de cada cuarto" % id)
	var sheets: Array[Image] = []
	for id: String in BiomePalette.IDS:
		sheets.append(_load_image(GENERATED_DIR + "chips_%s.png" % id))
	var distinct: bool = true
	for i: int in range(sheets.size()):
		for j: int in range(i):
			if sheets[i] != null and sheets[j] != null and _same_pixels(sheets[i], sheets[j]):
				distinct = false
	_check(distinct, "las astillas de cada bioma son de su color (todas distintas)")


## Runas que orbitan la roca (excavadora rúnica): una hoja de 16x16 por bioma con 4 glifos de 8x8, pintados
## con los colores de runa del bioma (rune y rune_light de BiomePalette) y el contorno.
func _test_orbit_runes() -> void:
	_section("Runas que orbitan, del color de cada bioma")
	var pairs: Dictionary = {}
	for id: String in BiomePalette.IDS:
		var colors: Dictionary = BiomePalette.of(id)
		_check(colors.has("rune") and colors.has("rune_light"), "'%s' tiene colores de runa" % id)
		if not (colors.has("rune") and colors.has("rune_light")):
			continue
		pairs["%s|%s" % [colors["rune"].to_html(), colors["rune_light"].to_html()]] = true
		var img: Image = _load_image(GENERATED_DIR + "runes_%s.png" % id)
		if img == null:
			_check(false, "existe runes_%s.png" % id)
			continue
		_check_eq(img.get_size(), Vector2i(16, 16), "runes_%s es una hoja de 16x16" % id)
		var allowed: Array[Color] = [colors["rune"], colors["rune_light"], Palette.OUTLINE]
		var foreign: int = 0
		var strokes: Array[int] = [0, 0, 0, 0]
		var shades: int = 0
		for y: int in range(16):
			for x: int in range(16):
				var pixel: Color = img.get_pixel(x, y)
				if pixel.a == 0.0:
					continue
				if not allowed.has(pixel) or pixel.a < 1.0:
					foreign += 1
				if pixel == colors["rune_light"]:
					strokes[(x / 8) + 2 * (y / 8)] += 1
				if pixel == colors["rune"]:
					shades += 1
		_check_eq(foreign, 0, "runes_%s usa solo los colores de runa del bioma y el contorno" % id)
		_check(strokes.all(func(count: int) -> bool: return count >= 5), "runes_%s tiene un glifo en cada cuarto (%s)" % [id, str(strokes)])
		_check(shades > 0, "runes_%s tiene dos tonos" % id)
	_check_eq(pairs.size(), BiomePalette.IDS.size(), "cada bioma tiene runas de otro color")


func _test_tiny_dungeon_tiles() -> void:
	_section("Tiles de Tiny Dungeon importadas")
	var tiles: Array[String] = ["0085", "0086", "0088", "0089", "0098", "0099", "0112"]
	for tile: String in tiles:
		var path: String = TINY_DUNGEON_DIR + "tile_%s.png" % tile
		var img: Image = _load_image(path)
		_check(img != null and img.get_size() == Vector2i(16, 16), "tile_%s es de 16x16" % tile)
		if img != null:
			_check(_off_palette(img).is_empty(), "y es de la paleta (los originales del pack también)")
	# Solo se importa lo que se usa.
	var dir: DirAccess = DirAccess.open(TINY_DUNGEON_DIR)
	var pngs: int = 0
	if dir != null:
		for file_name: String in dir.get_files():
			if file_name.ends_with(".png"):
				pngs += 1
	_check_eq(pngs, tiles.size(), "no hay tiles de más (solo se importa lo que se usa)")


func _test_ui_pack_and_font() -> void:
	_section("UI Pack y fuente")
	for color: String in UI_COLORS:
		for kind: String in ["button_rectangle_depth_flat", "button_rectangle_flat"]:
			_check(ResourceLoader.exists(UI_PACK_DIR + "%s/%s.png" % [color, kind]), "existe %s/%s" % [color, kind])
	_check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(UI_PACK_DIR + "blue")), "y no hay botones azules importados (no se usan)")
	_check(FileAccess.file_exists(FONT_PATH), "existe la fuente Pixelify Sans")
	_check(ResourceLoader.exists(FONT_PATH), "y está importada")
	var font: Resource = load(FONT_PATH)
	_check(font is FontFile, "carga como fuente")
	_check(FileAccess.file_exists("res://assets/fonts/OFL.txt"), "con su licencia (OFL.txt)")


## Todo archivo bajo assets/ tiene que estar cubierto por una ruta que CREDITS.md nombra.
func _test_credits() -> void:
	_section("CREDITS.md registra cada asset")
	var credits: String = FileAccess.get_file_as_string(CREDITS_PATH)
	_check(credits != "", "existe CREDITS.md")
	var covered: Array[String] = []
	var regex: RegEx = RegEx.create_from_string("`(assets/[^`]+)`")
	for found: RegExMatch in regex.search_all(credits):
		covered.append(found.get_string(1))
	_check(covered.size() >= 4, "CREDITS.md nombra rutas de assets (%d)" % covered.size())
	var uncovered: Array[String] = []
	for path: String in _list_assets("res://assets"):
		var relative: String = path.trim_prefix("res://")
		var ok: bool = false
		for prefix: String in covered:
			# una ruta con '*' (miner_*.png) cubre por su parte fija
			var fixed: String = prefix.split("*")[0]
			if relative.begins_with(fixed):
				ok = true
		if not ok:
			uncovered.append(relative)
	_check(uncovered.is_empty(), "todo archivo de assets/ está bajo una ruta de CREDITS.md (sin crédito: %s)" % str(uncovered))
	for needle: String in ["Kenney", "CC0", "Pixelify Sans", "OFL", "Open Font License", "kenney.nl/assets/tiny-dungeon", "kenney.nl/assets/ui-pack"]:
		_check(credits.contains(needle), "CREDITS.md menciona '%s'" % needle)


func _list_assets(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_list_assets(dir_path + "/" + sub))
	for file_name: String in dir.get_files():
		if not IGNORED_FILES.has(file_name.get_extension().to_lower()):
			found.append(dir_path + "/" + file_name)
	return found
