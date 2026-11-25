extends Node
## Autoload Settings: las opciones del jugador (volumen de música y de SFX, silencio y "reducir efectos").
##
## Código reutilizable entre juegos: no debe depender de nada de res://game/.
## Se guarda con Save en la sección "settings" (por eso va después de Save entre los autoloads) y avisa con
## `changed` cada vez que algo cambia de verdad: Audio aplica los volúmenes y la escena mira reduce_effects.
## Los valores que llegan (de la UI o de un save dañado) se validan: volúmenes de 0 a 1, NaN ignorado.

## Cambió alguna opción (solo si el valor nuevo es distinto del anterior).
signal changed

const SAVE_SECTION: String = "settings"
## La música arranca a la mitad: de base ya suena más baja (ver "music_volume_db" en data/sounds.json).
const DEFAULT_MUSIC_VOLUME: float = 0.5
## Versión de la escala del volumen de música. Si cambia cuán fuerte suena un mismo valor, se sube: un volumen
## guardado con otra escala no quiere decir lo mismo y se vuelve al de por defecto.
const MUSIC_SCALE: int = 2
const DEFAULT_SFX_VOLUME: float = 1.0

## Volumen de la música, de 0 (nada) a 1 (completo).
var music_volume: float = DEFAULT_MUSIC_VOLUME:
	set(value):
		var clamped: float = _volume(value, music_volume)
		if clamped != music_volume:
			music_volume = clamped
			changed.emit()

## Volumen de los efectos de sonido, de 0 a 1.
var sfx_volume: float = DEFAULT_SFX_VOLUME:
	set(value):
		var clamped: float = _volume(value, sfx_volume)
		if clamped != sfx_volume:
			sfx_volume = clamped
			changed.emit()

## Silencia todo (música y SFX) sin perder los volúmenes elegidos.
var muted: bool = false:
	set(value):
		if value != muted:
			muted = value
			changed.emit()

## Menos movimiento en pantalla: sin sacudidas, destellos ni vibración, y con menos partículas.
var reduce_effects: bool = false:
	set(value):
		if value != reduce_effects:
			reduce_effects = value
			changed.emit()


## El jugador ya vio el aviso de que su navegador puede borrar la partida. No cambia nada en pantalla (sin
## `changed`). Si el navegador borra el guardado, se borra también esto y el aviso vuelve: es lo que se quiere.
var storage_notice_seen: bool = false


func _ready() -> void:
	var save: Node = get_node_or_null("/root/Save")
	if save != null and save.has_method("register_section"):
		save.register_section(SAVE_SECTION, to_dict, from_dict)


func to_dict() -> Dictionary:
	return {
		"music_volume": music_volume,
		"music_scale": MUSIC_SCALE,
		"sfx_volume": sfx_volume,
		"muted": muted,
		"reduce_effects": reduce_effects,
		"storage_notice_seen": storage_notice_seen,
	}


## Toma de `data` lo que sea válido y deja el resto como está.
func from_dict(data: Dictionary) -> void:
	var music: Variant = data.get("music_volume")
	var scale: Variant = data.get("music_scale")
	if (music is float or music is int) and (scale is float or scale is int) and int(scale) == MUSIC_SCALE:
		music_volume = float(music)
	var sfx: Variant = data.get("sfx_volume")
	if sfx is float or sfx is int:
		sfx_volume = float(sfx)
	var mute: Variant = data.get("muted")
	if mute is bool:
		muted = mute
	var reduce: Variant = data.get("reduce_effects")
	if reduce is bool:
		reduce_effects = reduce
	var notice: Variant = data.get("storage_notice_seen")
	if notice is bool:
		storage_notice_seen = notice


## `value` recortado a [0, 1]; si no es un número finito, `current`.
static func _volume(value: float, current: float) -> float:
	if not is_finite(value):
		return current
	return clampf(value, 0.0, 1.0)
