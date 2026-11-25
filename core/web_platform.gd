extends RefCounted
## Lo que depende de dónde corre el juego: pantalla completa y abrir links.
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## La interfaz recibe un objeto de estos y los tests le pasan uno de mentira.


## Solo en la web y si el navegador la permite (Safari en iPhone normalmente no, y un iframe sin permiso tampoco).
## En Android nativo el juego ya ocupa toda la pantalla.
func can_fullscreen() -> bool:
	if not OS.has_feature("web"):
		return false
	var supported: Variant = JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true)
	return supported is bool and supported


func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## El navegador solo lo acepta poco después de un toque: llamarlo desde un botón.
func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


## En la web abre otra pestaña (también hay que llamarlo desde un botón).
func open_url(url: String) -> void:
	OS.shell_open(url)
