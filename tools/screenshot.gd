extends SceneTree
## Saca capturas de la pantalla principal en tamaños de celular vertical, con estados de muestra.
##
## Uso (desde la raíz del proyecto; abre una ventana de verdad, así que no sirve --headless):
##   godot --path . --script res://tools/screenshot.gd -- <carpeta_de_salida>
##   godot --path . --script res://tools/screenshot.gd -- <carpeta_de_salida> --debug   # deja el botón DBG
##
## Cada captura mide exactamente el tamaño del celular (360x640, 412x915) y se ve como en un
## release: sin el botón DBG salvo que se pase --debug. NO toca la partida guardada: apaga el
## guardado de Save antes de que arranque y trabaja con un estado de muestra en memoria.

const SIZES: Array[Vector2i] = [Vector2i(360, 640), Vector2i(412, 915)]

## Estados de muestra: nombre, pestaña (0 Cuadrilla, 1 Botín, 2 Reliquias) y partida. Con "options": true la
## captura sale con el panel de Opciones abierto; con "hits": N, se golpea N veces justo antes (números flotantes,
## roca aplastada); con "chest": i, cae un cofre de la rareza i; con "wait": s, se esperan s segundos antes de
## capturar (para agarrar una explosión o el cofre ya apoyado); con "descend": oro, después de armar el estado se baja
## a esa profundidad (cambio de bioma con fundido y cartel); con "offline": s, se vuelve de s segundos fuera; con
## "prestige": true, se vuelve a la superficie (fundido y reliquias volando).
## `owned` sigue el orden del balance: Minero, Taladro, Dinamita, Gólem, Excavadora.
const SHOTS: Array[Dictionary] = [
	{ "name": "1_inicio", "tab": 0, "gold": 22.0, "run_gold": 22.0, "pick": 0, "owned": [], "loot": 0.0, "relics": 0 },
	{ "name": "2_roca", "tab": 0, "gold": 3400.0, "run_gold": 4200.0, "pick": 3, "owned": [4, 1], "loot": 0.12, "relics": 0 },
	{ "name": "3_cristal_botin", "tab": 1, "gold": 52000.0, "run_gold": 60000.0, "pick": 5, "owned": [8, 3, 1, 1], "loot": 0.45, "relics": 0 },
	{ "name": "4_magma_reliquias", "tab": 2, "gold": 4.0e6, "run_gold": 5.0e6, "pick": 7, "owned": [30, 8, 5, 2, 0], "loot": 1.1, "relics": 3 },
	{ "name": "5_abismo", "tab": 0, "gold": 9.0e8, "run_gold": 2.0e9, "pick": 9, "owned": [60, 25, 12, 6, 2], "loot": 2.0, "relics": 5 },
	{ "name": "6_opciones", "tab": 0, "gold": 8.88e15, "run_gold": 1.0e15, "pick": 9, "owned": [60, 25, 12, 6, 2], "loot": 2.0, "relics": 40, "options": true },
	{ "name": "7_golpe", "tab": 0, "gold": 3400.0, "run_gold": 4200.0, "pick": 3, "owned": [4, 1], "loot": 0.12, "relics": 0, "hits": 6 },
	{ "name": "8_dinamita", "tab": 0, "gold": 52000.0, "run_gold": 60000.0, "pick": 5, "owned": [8, 3, 400, 1], "loot": 0.45, "relics": 0, "wait": 1.12 },
	{ "name": "9_cofre", "tab": 1, "gold": 52000.0, "run_gold": 60000.0, "pick": 5, "owned": [8, 3, 1, 1], "loot": 1.0, "relics": 0, "chest": 1, "wait": 0.7 },
	{ "name": "10_legendario", "tab": 1, "gold": 4.0e6, "run_gold": 5.0e6, "pick": 7, "owned": [30, 8, 5, 2, 0], "loot": 1.1, "relics": 3, "chest": 3, "wait": 1.2 },
	{ "name": "11_bioma_nuevo", "tab": 0, "gold": 900.0, "run_gold": 600.0, "pick": 2, "owned": [4, 1], "loot": 0.0, "relics": 0, "descend": 700.0, "wait": 0.3 },
	{ "name": "12_vuelta", "tab": 0, "gold": 3400.0, "run_gold": 4200.0, "pick": 3, "owned": [12, 2], "loot": 0.12, "relics": 0, "offline": 11520.0, "wait": 0.6 },
	{ "name": "13_superficie", "tab": 2, "gold": 4.0e6, "run_gold": 5.0e6, "pick": 7, "owned": [30, 8, 5, 2, 0], "loot": 1.1, "relics": 3, "prestige": true, "wait": 0.95 },
]

var _out_dir: String = ""
var _keep_debug: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Falta la carpeta de salida: -- <carpeta>")
		quit(1)
		return
	_out_dir = args[0]
	_keep_debug = args.has("--debug")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Antes de que Save haga su _ready (los autoloads arrancan después del primer frame).
	var save: Node = root.get_node("Save")
	save.persistence_enabled = false
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load("res://game/main.tscn") as PackedScene
	var scene: Control = packed.instantiate() as Control
	root.add_child(scene)
	if not _keep_debug and scene.has_node("DebugPanel"):
		scene.get_node("DebugPanel").free()
	var economy: Node = root.get_node("Economy")
	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		for shot: Dictionary in SHOTS:
			print("tomando %dx%d_%s..." % [size.x, size.y, shot["name"]])
			_apply(economy, shot)
			# Sin restos de la captura anterior (números y astillas en el aire).
			scene.get_node("%MineView").call("clear_effects")
			(scene.get_node("%" + ["TabCrewButton", "TabLootButton", "TabRelicsButton"][shot["tab"]]) as Button).button_pressed = true
			if shot["name"].begins_with("1_"):
				scene.get_node("%Mode1Button").button_pressed = true
			var options: Node = scene.get_node("OptionsPanel")
			if shot.get("options", false):
				options.call("open")
			else:
				options.set("visible", false)
			if shot.has("descend"):
				await _settle()
				economy.run_gold = float(shot["descend"])
				economy.gold_changed.emit(economy.gold)
			if shot.has("offline"):
				economy.apply_offline(float(shot["offline"]))
			if shot.get("prestige", false):
				await _settle()
				(scene.get_node("%PrestigeButton") as Button).pressed.emit()
				(scene.get_node("Modal").get("confirm_button") as Button).pressed.emit()
			if shot.has("chest"):
				economy.drop_loot(int(shot["chest"]))
			for hit: int in range(int(shot.get("hits", 0))):
				(scene.get_node("%TapButton") as Button).button_down.emit()
				await create_timer(0.1).timeout # como alguien que golpea rápido, no todo en el mismo frame
			if shot.has("wait"):
				await create_timer(float(shot["wait"])).timeout
			await _settle()
			var image: Image = root.get_texture().get_image()
			var path: String = "%s/%dx%d_%s.png" % [_out_dir, size.x, size.y, shot["name"]]
			image.save_png(path)
			scene.get_node("Modal").call("close")
			if shot.get("prestige", false):
				await create_timer(2.0).timeout # que termine la transición antes de la próxima captura
			print("%s  (%dx%d)" % [path, image.get_width(), image.get_height()])
	economy.reset()
	# Al salir no tiene que quedar nada vivo: los números flotantes con sus tweens y el último sonido (si no,
	# Godot avisa de recursos todavía en uso).
	scene.queue_free()
	root.get_node("Audio").call("silence")
	await create_timer(0.2).timeout
	quit(0)


## Deja a Economy en el estado de muestra `shot` (en memoria; no se guarda).
func _apply(economy: Node, shot: Dictionary) -> void:
	economy.reset()
	economy.run_gold = shot["run_gold"]
	economy.gold = shot["gold"]
	economy.pick_level = shot["pick"]
	economy.loot_bonus = shot["loot"]
	economy.relics = shot["relics"]
	var owned: Array = shot["owned"]
	for index: int in range(owned.size()):
		economy.owned[index] = owned[index]
	economy.gold_changed.emit(economy.gold)


## Espera a que la escena se acomode y se dibuje (los contenedores se reacomodan en el frame siguiente).
func _settle() -> void:
	for i: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
