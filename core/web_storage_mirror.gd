extends RefCounted
## Copia del guardado en el localStorage del navegador (solo en la web).
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## En la web `user://` vive en IndexedDB y se vacía de forma asíncrona: al cerrar la pestaña el navegador no
## siempre llega a hacerlo. localStorage se escribe en el acto, así que Save deja ahí una copia y al arrancar usa
## la más nueva. Todo va dentro de try/catch: en Safari privado o en un iframe con el almacenamiento bloqueado no
## hay copia y el juego sigue.

var _key: String
## Los callbacks de JavaScript se sueltan si nadie los retiene.
var _page_hide: JavaScriptObject
var _visibility_change: JavaScriptObject


func _init(key: String) -> void:
	_key = key


## Lo guardado, o "" si no hay nada (o el almacenamiento está bloqueado).
func read() -> String:
	var value: Variant = JavaScriptBridge.eval(
		"(function(){try{return window.localStorage.getItem(%s)||''}catch(e){return ''}})()" % JSON.stringify(_key), true)
	return value if value is String else ""


## Devuelve false si el navegador no dejó escribir.
func write(text: String) -> bool:
	var value: Variant = JavaScriptBridge.eval(
		"(function(){try{window.localStorage.setItem(%s,%s);return true}catch(e){return false}})()" % [JSON.stringify(_key), JSON.stringify(text)], true)
	return value is bool and value


## Llama a `callback` cuando la página se va: al cerrarla o navegar (pagehide) y al dejar de verse
## (visibilitychange), que en un celular suele ser el último aviso antes de que el sistema descarte la pestaña.
func on_page_hide(callback: Callable) -> void:
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	if window == null or document == null:
		return
	_page_hide = JavaScriptBridge.create_callback(func(_args: Array) -> void: callback.call())
	_visibility_change = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		if str(document.visibilityState) == "hidden":
			callback.call())
	window.addEventListener("pagehide", _page_hide)
	document.addEventListener("visibilitychange", _visibility_change)
