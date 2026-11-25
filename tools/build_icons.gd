extends SceneTree
## Dibuja el ícono del juego (la roca y el pico sobre fondo oscuro) con los sprites propios, para la PWA y la
## pantalla de inicio del celular. Escala siempre entera: cada píxel de sprite es un cuadrado.
##
##   godot --headless --path . --script res://tools/build_icons.gd
##   godot --headless --path . --import

const OUT_DIR: String = "res://web/icons/"
const SPRITE_DIR: String = "res://assets/sprites/generated/"
const BACKGROUND: Color = Color(0.102, 0.071, 0.055)
const HALO: Color = Color(0.36, 0.23, 0.2)
## Lado del dibujo base en píxeles de sprite; el contenido queda en el 70% del centro (los íconos se recortan).
const BASE: int = 28
const SIZES: Array[int] = [144, 180, 512]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var base: Image = _draw()
	for side: int in SIZES:
		var scale: int = side / BASE
		var art: Image = base.duplicate()
		art.resize(BASE * scale, BASE * scale, Image.INTERPOLATE_NEAREST)
		var icon: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		icon.fill(BACKGROUND)
		var margin: int = (side - BASE * scale) / 2
		icon.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(margin, margin))
		icon.save_png(ProjectSettings.globalize_path(OUT_DIR + "icon_%d.png" % side))
	print("Íconos en ", OUT_DIR)
	quit(0)


func _draw() -> Image:
	var canvas: Image = Image.create_empty(BASE, BASE, false, Image.FORMAT_RGBA8)
	canvas.fill(BACKGROUND)
	for y: int in range(BASE):
		for x: int in range(BASE):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(BASE, BASE) * 0.5) <= BASE * 0.4:
				canvas.set_pixel(x, y, HALO)
	_stamp(canvas, "rock_earth.png", Vector2i(5, 8))
	_stamp(canvas, "pick.png", Vector2i(9, 3))
	return canvas


func _stamp(canvas: Image, file_name: String, at: Vector2i) -> void:
	var sprite: Image = Image.load_from_file(ProjectSettings.globalize_path(SPRITE_DIR + file_name))
	sprite.convert(Image.FORMAT_RGBA8)
	canvas.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), at)
