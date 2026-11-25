extends RefCounted
## Lo que depende de dónde corre el juego: pantalla completa, links, vibración y el guardado del navegador.
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## La interfaz recibe un objeto de estos y los tests le pasan uno de mentira.

const WebTextDialog := preload("res://core/web_text_dialog.gd")

## En la web: ya hubo un toque completo (una vez que es true no vuelve a preguntar).
var _touched: bool = false
var _dialog: WebTextDialog = WebTextDialog.new()


## Si tiene sentido ofrecer la copia de la partida: en la web, donde el almacenamiento es del navegador.
func can_backup() -> bool:
	return OS.has_feature("web")


## El navegador puede borrar la partida aunque guardar "funcione": iPhone o iPad con el juego dentro de un iframe de
## otro sitio (itch.io). WebKit trata ese almacenamiento como de terceros: separado y efímero. No se puede detectar
## probando a escribir (escribe bien y después desaparece), así que se mira el aparato.
func has_fragile_storage() -> bool:
	if not OS.has_feature("web"):
		return false
	var agent: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
	var device: Variant = JavaScriptBridge.eval("navigator.platform", true)
	var touches: Variant = JavaScriptBridge.eval("navigator.maxTouchPoints || 0", true)
	if not is_ios(str(agent), str(device), int(touches) if (touches is int or touches is float) else 0):
		return false
	return is_true(JavaScriptBridge.eval("window.self !== window.top", true))


## iPadOS se presenta como una Mac ("MacIntel"): la pantalla táctil lo delata.
static func is_ios(user_agent: String, device: String, touch_points: int) -> bool:
	for model: String in ["iPhone", "iPad", "iPod"]:
		if user_agent.contains(model):
			return true
	return device == "MacIntel" and touch_points > 1


## El navegador no deja guardar nada (cookies bloqueadas, por ejemplo): ni user:// ni localStorage.
func storage_blocked() -> bool:
	if not OS.has_feature("web") or OS.is_userfs_persistent():
		return false
	return not is_true(JavaScriptBridge.eval("(function(){try{localStorage.setItem('__probe','1');localStorage.removeItem('__probe');return true}catch(e){return false}})()", true))


## Muestra un texto para copiarlo (ver web_text_dialog.gd).
func show_text(title: String, hint: String, text: String, labels: Dictionary) -> void:
	_dialog.show_text(title, hint, text, labels)


## Pide pegar un texto y lo pasa a `on_text`.
func ask_text(title: String, hint: String, labels: Dictionary, on_text: Callable) -> void:
	_dialog.ask_text(title, hint, labels, on_text)


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
