extends Control
## Efectos de pantalla completa: un destello (el cofre legendario) y una pausa breve con cámara lenta.
##
## Va entre los hijos de la escena principal después de Opciones y antes del cartel modal: queda encima de
## todo el juego y debajo de un aviso. No come toques. La pausa baja Engine.time_scale (tweens, partículas y
## animaciones casi se frenan) y la vuelve a 1 con un reloj que no depende de esa escala. Economy no se frena:
## cuenta con el reloj real.

var _flash: ColorRect
var _flash_tween: Tween
## Cuántas pausas están en curso (si se pisan, la escala vuelve a 1 cuando termina la última).
var _stops: int = 0


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
