extends RefCounted
## Lo que depende de dónde corre el juego: pantalla completa y abrir links.
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## La interfaz recibe un objeto de estos y los tests le pasan uno de mentira.

## En la web: ya hubo un toque completo (una vez que es true no vuelve a preguntar).
var _touched: bool = false


## Solo en la web y si el navegador la permite (Safari en iPhone normalmente no, y un iframe sin permiso tampoco).
## En Android nativo el juego ya ocupa toda la pantalla.
func can_fullscreen() -> bool:
	if not OS.has_feature("web"):
		return false
	return is_true(JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true))


## Si lo que devolvió JavaScriptBridge.eval es un sí. Un `true` de JavaScript no llega como bool sino como el
## entero 1 (Godot 4.7), así que `valor is bool` da siempre falso.
static func is_true(value: Variant) -> bool:
	return (value is bool or value is int or value is float) and bool(value)


func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## El navegador solo lo acepta poco después de un toque: llamarlo desde un botón.
func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


## En la web abre otra pestaña (también hay que llamarlo desde un botón).
func open_url(url: String) -> void:
	OS.shell_open(url)


## Vibración corta (solo hace algo en celulares). En la web el navegador la bloquea, y lo anota como error en la
## consola, hasta que se completó un primer toque: al apoyar el dedo por primera vez todavía no cuenta.
func vibrate(milliseconds: int) -> void:
	if not _touched and OS.has_feature("web"):
		_touched = is_true(JavaScriptBridge.eval("!navigator.userActivation || navigator.userActivation.hasBeenActive", true))
		if not _touched:
			return
	Input.vibrate_handheld(milliseconds)
