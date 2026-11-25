extends "res://tests/test_base.gd"
## Tests headless de core/settings.gd: las opciones del jugador (volumen de música y de SFX, silencio y
## "reducir efectos"), que se validan, avisan cuando cambian y se guardan con Save.

const SettingsScript := preload("res://core/settings.gd")

var _nodes: Array[Node] = []
var _changes: int = 0


func _initialize() -> void:
	_test_defaults()
	_test_volumes_are_clamped()
	_test_changed_signal()
	_test_round_trip()
	_test_bad_data_is_ignored()
	_test_old_music_volume_is_forgotten()
	# Los _ready de los autoloads corren después de _initialize: hay que esperar un frame.
	await process_frame
	_test_real_autoload()
	for node: Node in _nodes:
		node.free()
	_finish()


func _make() -> SettingsScript:
	var settings: SettingsScript = SettingsScript.new()
	_nodes.append(settings)
	return settings


func _count_change() -> void:
	_changes += 1


func _test_defaults() -> void:
	_section("Valores por defecto")
	var settings: SettingsScript = _make()
	_check_eq(settings.music_volume, 0.5, "la música arranca al 50%")
	_check_eq(settings.sfx_volume, 1.0, "los SFX arrancan al máximo")
	_check_eq(settings.muted, false, "no arranca en silencio")
	_check_eq(settings.reduce_effects, false, "ni con los efectos reducidos")


func _test_volumes_are_clamped() -> void:
	_section("Los volúmenes van de 0 a 1")
	var settings: SettingsScript = _make()
	settings.music_volume = 1.5
	_check_eq(settings.music_volume, 1.0, "la música no pasa de 1")
	settings.music_volume = -0.3
	_check_eq(settings.music_volume, 0.0, "ni baja de 0")
	settings.sfx_volume = 7.0
	_check_eq(settings.sfx_volume, 1.0, "los SFX no pasan de 1")
	settings.sfx_volume = 0.25
	_check_eq(settings.sfx_volume, 0.25, "un valor del medio queda tal cual")
	settings.sfx_volume = NAN
	_check_eq(settings.sfx_volume, 0.25, "un NaN se ignora")


func _test_changed_signal() -> void:
	_section("Avisa cuando algo cambia, y solo entonces")
	var settings: SettingsScript = _make()
	settings.changed.connect(_count_change)
	_changes = 0
	settings.muted = true
	_check_eq(_changes, 1, "silenciar avisa")
	settings.muted = true
	_check_eq(_changes, 1, "volver a poner el mismo valor no avisa")
	settings.music_volume = 0.3
	settings.sfx_volume = 0.4
	settings.reduce_effects = true
	_check_eq(_changes, 4, "cada opción que cambia avisa una vez")
	settings.music_volume = 2.0
	settings.music_volume = 3.0
	_check_eq(_changes, 5, "dos valores que terminan en el mismo tope avisan una sola vez")


func _test_round_trip() -> void:
	_section("Se guarda y se recupera")
	var settings: SettingsScript = _make()
	settings.music_volume = 0.35
	settings.sfx_volume = 0.6
	settings.muted = true
	settings.reduce_effects = true
	var data: Dictionary = settings.to_dict()
	var restored: SettingsScript = _make()
	restored.from_dict(JSON.parse_string(JSON.stringify(data)))
	_check_near(restored.music_volume, 0.35, "volumen de música")
	_check_near(restored.sfx_volume, 0.6, "volumen de SFX")
	_check_eq(restored.muted, true, "silencio")
	_check_eq(restored.reduce_effects, true, "reducir efectos")


func _test_bad_data_is_ignored() -> void:
	_section("Datos dañados no rompen nada")
	var settings: SettingsScript = _make()
	var defaults: Dictionary = settings.to_dict()
	settings.from_dict({ "music_volume": "fuerte", "sfx_volume": 9.0, "muted": "sí", "reduce_effects": 1 })
	_check_eq(settings.music_volume, defaults["music_volume"], "un volumen que no es número deja el anterior")
	_check_eq(settings.sfx_volume, 1.0, "uno fuera de rango se recorta")
	_check_eq(settings.muted, false, "un silencio que no es booleano se ignora")
	_check_eq(settings.reduce_effects, false, "igual que reducir efectos")
	settings.from_dict({})
	_check_eq(settings.to_dict(), { "music_volume": defaults["music_volume"], "music_scale": SettingsScript.MUSIC_SCALE, "sfx_volume": 1.0, "muted": false, "reduce_effects": false }, "una sección vacía no cambia nada")


## La música ahora suena más baja en todo el recorrido del control: un volumen elegido con la escala anterior ya
## no quiere decir lo mismo (un 5% para compensar quedaría inaudible), así que se vuelve al valor por defecto.
func _test_old_music_volume_is_forgotten() -> void:
	_section("Un volumen de música de la escala anterior no se usa")
	var settings: SettingsScript = _make()
	settings.from_dict({ "music_volume": 0.05, "sfx_volume": 0.8, "muted": true })
	_check_eq(settings.music_volume, 0.5, "el volumen de música viejo (sin marca de escala) se ignora: 50%")
	_check_near(settings.sfx_volume, 0.8, "los efectos se respetan")
	_check_eq(settings.muted, true, "y el silencio")
	settings.from_dict({ "music_volume": 0.3, "music_scale": SettingsScript.MUSIC_SCALE })
	_check_near(settings.music_volume, 0.3, "con la marca de la escala actual se respeta")
	_check_eq(int(settings.to_dict()["music_scale"]), SettingsScript.MUSIC_SCALE, "y al guardar se marca")


func _test_real_autoload() -> void:
	_section("El autoload real")
	var settings: Node = root.get_node_or_null("Settings")
	_check(settings != null, "existe el autoload Settings")
	var save: Node = root.get_node_or_null("Save")
	_check(save != null and bool(save.call("has_section", "settings")), "y se registró en Save con la sección 'settings'")
	var children: Array[Node] = root.get_children()
	_check(children.find(save) < children.find(settings), "Save carga antes que Settings (así le entrega lo guardado)")
	var audio: Node = root.get_node_or_null("Audio")
	_check(children.find(settings) < children.find(audio), "y Settings antes que Audio (que aplica los volúmenes)")
