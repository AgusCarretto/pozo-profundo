extends Control
## Cartel de un botón del costado (Botín, Reliquias): oscurece la pantalla y muestra su contenido hasta que
## se toca "Cerrar". El contenido se arma en la escena (main.tscn, con un botón llamado "CloseButton"); acá
## solo se abre y se cierra. Mientras está abierto traga los toques. El juego sigue corriendo atrás.


func _ready() -> void:
	(find_child("CloseButton", true, false) as Button).pressed.connect(close)


func open() -> void:
	if visible:
		return
	Audio.play_sfx("tab")
	visible = true


func close() -> void:
	if not visible:
		return
	Audio.play_sfx("close")
	visible = false
