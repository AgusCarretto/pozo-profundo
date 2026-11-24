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

const SINGLE_SPRITES: Array[String] = [
	"drill", "golem", "dynamite", "rune_1", "rune_2", "rune_3", "coin", "pick", "gem",
	"miner_1", "miner_2", "miner_3", "miner_4", "miner_5", "miner_6", "miner_7", "miner_8",
]
const UI_COLORS: Array[String] = ["yellow", "green", "blue", "red", "grey"]
## Extensiones que no son assets (los genera Godot o son textos de licencia).
const IGNORED_FILES: Array[String] = ["import", "uid", "gitkeep", "txt"]


func _initialize() -> void:
	_test_palette()
	_test_every_biome_has_art()
	_test_generated_sprites()
	_test_miners_are_different()
	_test_biomes_look_different()
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
