extends SceneTree
## Smoke test headless de F0.
##
## Verifica la configuración del proyecto, los autoloads, la regla de independencia
## de core/ y que la escena principal cargue y responda al botón.
##
## Uso (desde la raíz del proyecto):
##   godot --headless --path . --script res://tests/smoke_test.gd
## Sale con código 0 si todo pasa y 1 si algún check falla.

var _failures: int = 0


func _initialize() -> void:
	_test_project_settings()
	_test_autoloads()
	_test_core_independence()
	await _test_main_scene()
	print("")
	if _failures == 0:
		print("OK: todos los checks pasaron")
		quit(0)
	else:
		printerr("FALLO: %d check(s) no pasaron" % _failures)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok    ", label)
	else:
		_failures += 1
		printerr("  FALLO ", label)


func _test_project_settings() -> void:
	print("Configuración del proyecto")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 720, "viewport ancho = 720")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == 1280, "viewport alto = 1280")
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "stretch mode = canvas_items")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "stretch aspect = expand")
	_check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_PORTRAIT, "orientación = portrait")
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "filtro de texturas = Nearest")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "renderer = gl_compatibility")


func _test_autoloads() -> void:
	print("Autoloads")
	for autoload_name: String in ["Save", "Audio", "Economy", "Analytics"]:
		_check(root.get_node_or_null(autoload_name) != null, "autoload %s presente" % autoload_name)


## Regla del CLAUDE.md: lo de core/ no puede depender de nada de game/.
func _test_core_independence() -> void:
	print("Independencia de core/")
	var dir: DirAccess = DirAccess.open("res://core")
	_check(dir != null, "se puede leer res://core")
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string("res://core/" + file_name)
		var references_game: bool = false
		for line: String in text.split("\n"):
			# Los comentarios pueden mencionar res://game/ (p. ej. para documentar la regla).
			if line.strip_edges().begins_with("#"):
				continue
			if line.contains("res://game"):
				references_game = true
		_check(not references_game, "core/%s no referencia res://game" % file_name)


func _test_main_scene() -> void:
	print("Escena principal")
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var packed: PackedScene = load(main_path) as PackedScene
	_check(packed != null, "carga %s" % main_path)
	if packed == null:
		return
	var scene: Control = packed.instantiate() as Control
	_check(scene != null, "instancia como Control")
	if scene == null:
		return
	root.add_child(scene)
	await process_frame
	var rect: TextureRect = scene.get_node("%PixelRect") as TextureRect
	_check(rect.texture != null, "la textura pixelada se generó")
	var button: Button = scene.get_node("%PickButton") as Button
	button.pressed.emit()
	_check(scene.call("get_hits") == 1, "el botón suma un golpe")
	var counter: Label = scene.get_node("%CounterLabel") as Label
	_check(counter.text == "Golpes: 1", "el contador muestra 'Golpes: 1'")
	scene.queue_free()
