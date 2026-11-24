extends Control
## Escena de prueba de F0.
##
## Sirve para validar el setup de punta a punta (editor, headless y export web):
## escalado vertical 720x1280, filtro Nearest, input táctil/mouse y tweens.
## Se reemplaza por la escena real del juego en F1.

@onready var _pixel_rect: TextureRect = %PixelRect
@onready var _counter_label: Label = %CounterLabel
@onready var _info_label: Label = %InfoLabel
@onready var _pick_button: Button = %PickButton

var _hits: int = 0
var _tween: Tween


func _ready() -> void:
	_pixel_rect.texture = _make_pixel_texture()
	_info_label.text = _build_info()
	_pick_button.pressed.connect(_on_pick_pressed)
	_update_counter()


func get_hits() -> int:
	return _hits


func _on_pick_pressed() -> void:
	_hits += 1
	_update_counter()
	_squash()


func _update_counter() -> void:
	_counter_label.text = "Golpes: %d" % _hits


func _squash() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_pixel_rect.pivot_offset = _pixel_rect.size / 2.0
	_tween = create_tween()
	_tween.tween_property(_pixel_rect, "scale", Vector2(1.15, 0.85), 0.05)
	_tween.tween_property(_pixel_rect, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_info() -> String:
	var visible_size: Vector2 = get_viewport_rect().size
	return "%s · %d×%d · %s" % [
		OS.get_name(),
		int(visible_size.x),
		int(visible_size.y),
		RenderingServer.get_current_rendering_method(),
	]


## Textura de 8x8 píxeles (tierra con una gema). Se muestra ampliada: si el filtro
## del proyecto es Nearest, los píxeles se ven nítidos y no borrosos.
func _make_pixel_texture() -> ImageTexture:
	var size: int = 8
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dark := Color("3d2b20")
	var light := Color("5a3f2e")
	var gold := Color("f4c542")
	var gold_hi := Color("ffe27a")
	for y: int in range(size):
		for x: int in range(size):
			img.set_pixel(x, y, dark if (x + y) % 2 == 0 else light)
	var gem: Array[Vector2i] = [
		Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
		Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
		Vector2i(3, 5), Vector2i(4, 5),
	]
	for p: Vector2i in gem:
		img.set_pixelv(p, gold)
	img.set_pixel(3, 3, gold_hi)
	return ImageTexture.create_from_image(img)
