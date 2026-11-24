extends Control
## Efectos de pantalla completa: un destello (el cofre legendario), una pausa breve con cámara lenta, un fundido
## que tapa la pantalla (volver a la superficie) y cosas que vuelan por encima (las reliquias al contador).
##
## Va entre los hijos de la escena principal después de Opciones y antes del cartel modal: queda encima de
## todo el juego y debajo de un aviso. No come toques. La pausa baja Engine.time_scale (tweens, partículas y
## animaciones casi se frenan) y la vuelve a 1 con un reloj que no depende de esa escala. Economy no se frena:
## cuenta con el reloj real.

var _flash: ColorRect
var _flash_tween: Tween
## Cuántas pausas están en curso (si se pisan, la escala vuelve a 1 cuando termina la última).
var _stops: int = 0
## Cuántas figuras volaron (para que cada una tenga su nombre).
var _flights: int = 0


func _init() -> void:
	name = "ScreenFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)


## Pantalla de `color` que se apaga en `fade` segundos (de tiempo real: no lo frena una pausa).
func flash(color: Color, fade: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = color
	_flash_tween = create_tween()
	_flash_tween.set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash, "color:a", 0.0, fade).set_ease(Tween.EASE_IN)


## Tapa la pantalla fundiendo a `color` (opaco) en `seconds`; mientras está tapada no se puede tocar nada. Se
## espera con `await`.
func cover(color: Color, seconds: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = Color(color, 0.0)
	_flash_tween = create_tween()
	_flash_tween.set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash, "color:a", 1.0, seconds).set_trans(Tween.TRANS_SINE)
	await _flash_tween.finished


## Destapa la pantalla en `seconds` y la vuelve a dejar tocable. Se espera con `await`.
func uncover(seconds: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash, "color:a", 0.0, seconds).set_trans(Tween.TRANS_SINE)
	await _flash_tween.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Una figura (`texture`, de `size`) que vuela de `from` a `to` (coordenadas de esta capa) arrancando a los `delay`
## segundos y tardando `seconds`; al llegar llama a `on_arrive` y desaparece. Se dibuja encima del fundido.
func fly(texture: Texture2D, from: Vector2, to: Vector2, size_px: float, delay: float, seconds: float, on_arrive: Callable) -> void:
	var figure: TextureRect = TextureRect.new()
	_flights += 1
	figure.name = "FlyingRelic%d" % _flights
	figure.texture = texture
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_SCALE
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.size = Vector2.ONE * size_px
	figure.pivot_offset = figure.size * 0.5
	figure.position = from - figure.size * 0.5
	figure.scale = Vector2.ONE * 1.4
	figure.modulate.a = 0.0
	add_child(figure)
	var tween: Tween = figure.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(figure, "modulate:a", 1.0, 0.12)
	tween.tween_property(figure, "position", to - figure.size * 0.5, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(figure, "scale", Vector2.ONE * 0.6, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(on_arrive)
	tween.tween_callback(figure.queue_free)


## Casi congela la escena (`slow` = escala de tiempo) durante `seconds` de tiempo real.
func hit_stop(seconds: float, slow: float) -> void:
	_stops += 1
	Engine.time_scale = slow
	await get_tree().create_timer(seconds, true, false, true).timeout
	_stops -= 1
	if _stops <= 0:
		_stops = 0
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	# Que una escena que se va en medio de una pausa no deje el juego en cámara lenta.
	if _stops > 0:
		_stops = 0
		Engine.time_scale = 1.0
