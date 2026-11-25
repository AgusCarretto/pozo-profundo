extends SceneTree
## Smoke test headless del proyecto.
##
## Verifica la configuración del proyecto, los autoloads, la regla de independencia
## de core/ y que la escena principal cargue con sus controles clave.
##
## Uso (desde la raíz del proyecto):
##   godot --headless --path . --script res://tests/smoke_test.gd
## Sale con código 0 si todo pasa y 1 si algún check falla.

var _failures: int = 0


func _initialize() -> void:
	_test_project_settings()
	_test_autoloads()
	_test_export_settings()
	_test_core_independence()
	await _test_main_scene()
	# Igual que test_base._finish(): cortar el audio y esperar un ciclo de mezcla, o Godot reporta el último
	# sonido como recurso en uso al salir.
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("silence"):
		audio.call("silence")
		# Un OGG que sonaba tarda más de 0,1 s en soltarse. (Los tests lentos ya devolvieron Engine.time_scale a 1.)
		await create_timer(0.3).timeout
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
	for autoload_name: String in ["Save", "Settings", "Audio", "Economy", "Analytics"]:
		_check(root.get_node_or_null(autoload_name) != null, "autoload %s presente" % autoload_name)


## Lo que hace falta para publicar en la web (F4): versión, preset de export y pantalla de carga propia.
func _test_export_settings() -> void:
	print("Export web")
	_check(ProjectSettings.get_setting("application/config/version", "") == "0.6.0", "versión = 0.6.0")
	_check(ProjectSettings.get_setting("application/boot_splash/show_image", true) == false, "sin el logo de Godot al arrancar")
	var preset: ConfigFile = ConfigFile.new()
	_check(preset.load("res://export_presets.cfg") == OK, "se lee export_presets.cfg")
	var excluded: PackedStringArray = str(preset.get_value("preset.0", "exclude_filter", "")).split(",")
	for pattern: String in ["tests/*", "docs/*", "tools/*", "build/*", "data/online.example.json"]:
		_check(excluded.has(pattern), "el export no lleva %s" % pattern)
	var included: PackedStringArray = str(preset.get_value("preset.0", "include_filter", "")).split(",")
	_check(included.has("assets/fonts/OFL.txt"), "el export lleva la licencia de la fuente")
	_check(included.has("assets/fonts/VT323-OFL.txt"), "y la de la fuente de los números")
	var shell: String = str(preset.get_value("preset.0.options", "html/custom_html_shell", ""))
	_check(shell == "res://web/shell.html", "usa la pantalla de carga propia")
	var html: String = FileAccess.get_file_as_string("res://web/shell.html") if FileAccess.file_exists("res://web/shell.html") else ""
	for piece: String in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_PROJECT_NAME", "$GODOT_HEAD_INCLUDE", "onProgress", "VT323Digits.ttf", "unicode-range: U+0030-0039"]:
		_check(html.contains(piece), "la pantalla de carga tiene %s" % piece)


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
	# El comportamiento de la escena se prueba a fondo en tests/main_scene_test.gd.
	var tap: Button = scene.get_node_or_null("%TapButton") as Button
	_check(tap != null, "la escena tiene el botón de golpe (%TapButton)")
	var gold_label: Label = scene.get_node_or_null("%GoldLabel") as Label
	_check(gold_label != null, "la escena tiene el cartel de oro (%GoldLabel)")
	scene.queue_free()
