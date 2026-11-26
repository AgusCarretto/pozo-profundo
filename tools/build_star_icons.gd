extends SceneTree
## Arma los íconos de las estrellas del árbol: uno por estrella de data/arbol.json, de 16x16 y con la paleta del juego.
##
## Uso (desde la raíz del proyecto):
##   godot --headless --path . --script res://tools/build_star_icons.gd
##   godot --headless --path . --import      # para que Godot importe los PNG nuevos
##
## Hay tres orígenes: sprites que el juego ya tiene (REUSED), los cinco de la lámina aprobada
## (docs/lamina-v07-iconos.png, con su contorno dibujado; APPROVED) y el resto, dibujado acá sin contorno (DRAWN): se
## lo pone _outline, como a los sprites. Es determinista: correrlo de nuevo reescribe los mismos archivos.

const Palette := preload("res://game/palette.gd")

const OUT_DIR: String = "res://assets/sprites/generated/stars/"
const GENERATED_DIR: String = "res://assets/sprites/generated/"
const SIZE: int = 16
const COLORS: Dictionary = {
	"K": Palette.OUTLINE, "N": Palette.NAVY, "m": Palette.MAROON, "t": Palette.TERRA, "h": Palette.ORANGE,
	"c": Palette.CLAY, "d": Palette.SAND, "D": Palette.SAND_LIGHT, "p": Palette.PEACH, "s": Palette.STEEL,
	"l": Palette.STEEL_LIGHT, "e": Palette.SLATE, "E": Palette.SLATE_LIGHT, "f": Palette.FROST, "w": Palette.WHITE,
	"M": Palette.MINT, "q": Palette.AQUA, "g": Palette.GREEN, "R": Palette.RED, "S": Palette.SALMON,
	"P": Palette.PURPLE, "k": Palette.PINK, "B": Palette.BLUE, "C": Palette.CYAN, "G": Palette.GOLD, "y": Palette.YELLOW,
}

## Estrella » sprite del juego que se usa tal cual.
const REUSED: Dictionary = {
	"f_templado": "res://assets/sprites/generated/pick_gold.png",
	"o_botin": "res://assets/sprites/tiny_dungeon/tile_0089.png",
	"o_gemologo": "res://assets/sprites/generated/gem.png",
	"o_reliquia": "res://assets/sprites/generated/rune_1.png",
	"c_capataz": "res://assets/sprites/generated/miner_1.png",
	"t_mecha": "res://assets/sprites/generated/dynamite.png",
	"t_veta": "res://assets/sprites/generated/rock_earth.png",
}

## Los cinco de la lámina aprobada: llama, corona, dado, luna y reloj de arena.
const APPROVED_COLORS: Dictionary = {
	"o": Palette.OUTLINE, "r": Palette.RED, "g": Palette.GOLD, "y": Palette.YELLOW, "w": Palette.WHITE,
	"c": Palette.CLAY, "f": Palette.FROST, "b": Palette.BLUE, "s": Palette.STEEL,
}
## El dado, en gris claro en lugar de blanco para que no resalte más que el resto.
const DIE_COLORS: Dictionary = { "o": Palette.OUTLINE, "w": Palette.STEEL_LIGHT, "f": Palette.STEEL_PALE, "s": Palette.STEEL }
const APPROVED: Dictionary = {
	"f_furia": [
		"................",
		".......oo.......",
		"......oggo......",
		"......oggo..o...",
		".....ogggo.ogo..",
		"....ogggggoggo..",
		"....ogggygggo...",
		"...oggyyyggggo..",
		"..ogggyyyygggo..",
		"..ogryyyyyygro..",
		"..orryywwyyrro..",
		"..orryywwyyrro..",
		"...orryyyyrro...",
		"....orrrrrro....",
		".....oooooo.....",
		"................",
	],
	"o_corona": [
		"................",
		"................",
		".......oo.......",
		"......oyyo......",
		".o....oyyo....o.",
		"oyo...oyyo...oyo",
		"oyyo.oyggyo.oyyo",
		"oyggoyggggyoggyo",
		"oyggggggggggggyo",
		"oyggrggbbggrggyo",
		"oyggggggggggggyo",
		"oooooooooooooooo",
		"oyyyyyyyyyyyyyyo",
		"oooooooooooooooo",
		"................",
		"................",
	],
	"o_apostador": [
		"................",
		"................",
		"..oooooooooooo..",
		"..owwwwwwwwwwo..",
		"..owoowwwwoowo..",
		"..owoowwwwoowo..",
		"..owwwwwwwwwwo..",
		"..owwwwoowwwwo..",
		"..owwwwoowwwwo..",
		"..owwwwwwwwwwo..",
		"..owoowwwwoowo..",
		"..owoowwwwoowo..",
		"..offffffffffo..",
		"..osssssssssso..",
		"..oooooooooooo..",
		"................",
	],
	"t_vigilia": [
		"................",
		"......oooo......",
		"....ooyyyo......",
		"...oyyyyo.......",
		"..oyyyyo......w.",
		"..oyyyo......www",
		".oyyyyo.......w.",
		".oyyyyo.........",
		".oyyyyo....w....",
		".oyyyyyo........",
		"..oyyyyyo.....o.",
		"..oggyyyyooooyo.",
		"...oggyyyyyyyo..",
		"....ooggggyoo...",
		"......ooooo.....",
		"................",
	],
	"t_cuenta": [
		"................",
		"...oooooooooo...",
		"...occcccccco...",
		"...oooooooooo...",
		"....ofyyyyfo....",
		"....ofyyyyfo....",
		".....ofyyfo.....",
		"......oyyo......",
		".......oo.......",
		"......offo......",
		".....offyfo.....",
		"....offyyffo....",
		"....ofyyyyfo....",
		"...oooooooooo...",
		"...occcccccco...",
		"...oooooooooo...",
	],
}

const DRAWN: Dictionary = {
	# Corazón del pozo: un corazón de cristal.
	"core": [
		"................",
		"................",
		"...qqq....qqq...",
		"..qwwqq..qqqqq..",
		"..qwqqqqqqqqqM..",
		"..qqqqqqqqqqqM..",
		"..qqqqqqqqqqqM..",
		"...qqqqqqqqqM...",
		"....qqqqqqqM....",
		".....qqqqqM.....",
		"......qqqM......",
		".......qM.......",
		"................",
		"................",
		"................",
		"................",
	],
	# Brazo fuerte: un guantelete cerrado.
	"f_brazo": [
		"................",
		"................",
		"....ll.ll.ll....",
		"...fllsllsll....",
		"...fllsllsllsl..",
		"...fllsllsllsll.",
		"...flllllllllsl.",
		"..flllllllllls..",
		"..fsssssslllll..",
		"...llllllllls...",
		"....lllllllss...",
		".....BBBBBBB....",
		".....BBBBBBB....",
		".....CCCCCCC....",
		"................",
		"................",
	],
	# Ojo certero.
	"f_ojo": [
		"................",
		"................",
		"................",
		"................",
		".....wwwwww.....",
		"...wwwBBBBwww...",
		"..wwwBBNNBBwww..",
		".wwwwBNwNNBwwww.",
		".wwwwBNNNNBwwww.",
		"..wwwBBNNBBwww..",
		"...wwwBBBBwww...",
		".....wwwwww.....",
		"................",
		"................",
		"................",
		"................",
	],
	# Golpe brutal: un estallido.
	"f_brutal": [
		"................",
		".......R........",
		"..R....R....R...",
		"...R..RyR..R....",
		"....RRyyyRR.....",
		"....RyyyyyR.....",
		"..RRyyywyyyRR...",
		".RRyyywwwyyyRR..",
		"..RRyyywyyyRR...",
		"....RyyyyyR.....",
		"....RRyyyRR.....",
		"...R..RyR..R....",
		"..R....R....R...",
		".......R........",
		"................",
		"................",
	],
	# Eco: un golpe y sus ondas.
	"f_eco": [
		"................",
		"..........ff....",
		"......ff....ff..",
		".......ff....f..",
		"...ff...ff...ff.",
		"....ff...f....f.",
		"..y..f...ff...f.",
		".yGy.f...ff...f.",
		"..y..f...ff...f.",
		"....ff...f....f.",
		"...ff...ff...ff.",
		".......ff....f..",
		"......ff....ff..",
		"..........ff....",
		"................",
		"................",
	],
	# Combo: un rayo.
	"f_combo": [
		"................",
		".......yyyyy....",
		"......yyyyG.....",
		"......yyyG......",
		".....yyyG.......",
		".....yyyG.......",
		"....yyyyyyyy....",
		"....GGGyyyG.....",
		"......yyyG......",
		"......yyG.......",
		".....yyG........",
		".....yG.........",
		"....yG..........",
		"....G...........",
		"................",
		"................",
	],
	# Mano rápida: una mano abierta con líneas de velocidad.
	"f_umbral": [
		"................",
		"................",
		".......f.f.f....",
		".......f.f.f....",
		".......f.f.f.f..",
		"....yy.f.f.f.f..",
		".......fffffff..",
		".yy..f.fffffff..",
		".....fffffffff..",
		"......ffffffff..",
		"....yy.ffffffl..",
		"........ffffll..",
		"........BBBBB...",
		"........CCCCC...",
		"................",
		"................",
	],
	# Olfato: una lupa.
	"o_olfato": [
		"................",
		".....llll.......",
		"...llCCCCll.....",
		"...lCwwCCCl.....",
		"..lCwCCCCCCl....",
		"..lCCCCCCCCl....",
		"..lCCCCCCCCl....",
		"...lCCCCCCl.....",
		"...llCCCCll.....",
		".....llllcc.....",
		"..........tt....",
		"...........tt...",
		"............tt..",
		"................",
		"................",
		"................",
	],
	# Corazón de dragón: la cabeza de un dragón.
	"o_dragon": [
		"................",
		".........k...k..",
		"........kk..kk..",
		".......PPk.kk...",
		".....PPPPPPPk...",
		"...PPPPPPPPPP...",
		"..PPPPyNPPPPPk..",
		".PPPPPPPPPPPPP..",
		".PNPPPPPPPPPPPk.",
		".PPPPPPPPPPPPP..",
		"..wPwPwPPkkPPPk.",
		"......PPPkkPPP..",
		"..PPPPPPkkkPPPk.",
		"...kkkkkkkPPPP..",
		"................",
		"................",
	],
	# Doble cofre.
	"o_doble": [
		"................",
		".......hhhhhhh..",
		"......hcccccccc.",
		"......mmmmGGmmm.",
		"......hhhhGGhhh.",
		"......hhhhhhhhh.",
		".KKKKKKKKKKhhhh.",
		"..hhhhhhhhKhhhh.",
		".hcccccccccK....",
		".mmmmmGGmmmm....",
		".hhhhhGGhhhh....",
		".hhhhhhhhhhh....",
		".hhhhhhhhhhh....",
		"................",
		"................",
		"................",
	],
	# Contrato barato: un pergamino con una moneda.
	"c_contrato": [
		"................",
		"...DDDDDDDDD....",
		"..dDDDDDDDDDD...",
		"..dd.DDDDDDDD...",
		".....DmmmmmmD...",
		".....DDDDDDDD...",
		".....DmmmmmDD...",
		".....DDDDDDDD...",
		".....DmmmDGGG...",
		".....DDDDGyyyG..",
		".....DDDDGyGyG..",
		"..DDDDDDDGyyyG..",
		"..ddddddd.GGG...",
		"................",
		"................",
		"................",
	],
	# Bolsa inicial.
	"c_bolsa": [
		"................",
		"......ttt.t.....",
		".......ttt......",
		"......GGGG......",
		".....hhhhhh.....",
		"....hchhhhhh....",
		"...hchhyyhhhh...",
		"..hchhyGGyhhht..",
		"..hchhyGyyhhht..",
		"..hhhhyGGyhhht..",
		"..hhhhhyyhhhht..",
		"...hhhhhhhhhtt..",
		"....tttttttt....",
		"................",
		"................",
		"................",
	],
	# Ventaja inicial: la bandera de largada.
	"c_ventaja": [
		"................",
		"...ll...........",
		"...lMMMM........",
		"...lMMMMMMM.....",
		"...lMMMMMMMMMM..",
		"...lMMMMMMMgg...",
		"...lMMMMggg.....",
		"...lgggg........",
		"...l............",
		"...l............",
		"...l............",
		"...l............",
		"..ttttt.........",
		".ttttttt........",
		"................",
		"................",
	],
	# Hitos dorados: una medalla.
	"c_hitos": [
		"................",
		"..BBB......RRR..",
		"...BBB....RRR...",
		"....BBB..RRR....",
		".....BBBRRR.....",
		"......BBRR......",
		".....GGGGGG.....",
		"....GyyyyyyG....",
		"...GyyyGGyyyG...",
		"...GyyGGGGyyG...",
		"...GyyyGGyyyG...",
		"....GyyyyyyG....",
		".....GGGGGG.....",
		"................",
		"................",
		"................",
	],
	# Memoria: la mochila donde te guardás las herramientas.
	"c_memoria": [
		"................",
		"......tttt......",
		".....t....t.....",
		"....hhhhhhhh....",
		"...hcccccccch...",
		"...hcccccccch...",
		"..mhhhhhhhhhhm..",
		"..mhhhhGGhhhhm..",
		"..mhttttttttthm.",
		"..mhtcccccccthm.",
		"..mhtcccccccthm.",
		"..mhttttttttthm.",
		"...hhhhhhhhhh...",
		"................",
		"................",
		"................",
	],
	# A la par: dos picos cruzados.
	"c_mina": [
		"................",
		"..lll......lll..",
		".llllt....tllll.",
		".ll..mt..tm..ll.",
		".l....mttm....l.",
		"......tmmt......",
		".......mm.......",
		"......mttm......",
		".....mt..tm.....",
		"....mt....tm....",
		"...mt......tm...",
		"..mt........tm..",
		"..m..........m..",
		"................",
		"................",
		"................",
	],
	# Pólvora: un barril con la mecha encendida.
	"t_polvora": [
		"...........y.y..",
		"............w...",
		".........tty.y..",
		"........t.......",
		"....cccccccc....",
		"...hhhhhhhhhh...",
		"..eeeeeeeeeeee..",
		"..hchhmhhhmhmm..",
		"..hchhmRRRmhmm..",
		"..hchhmRRRmhmm..",
		"..hchhmhhhmhmm..",
		"..eeeeeeeeeeee..",
		"...hhhhhhhhhh...",
		"....mmmmmmmm....",
		"................",
		"................",
	],
	# Turno noche: un farol.
	"t_noche": [
		"................",
		"......ssss......",
		".....s....s.....",
		"......ssss......",
		"....eeeeeeee....",
		"....eyyyyyye....",
		"....eyyGGyye....",
		"....eyGwwGye....",
		"....eyGwwGye....",
		"....eyyGGyye....",
		"....eyyyyyye....",
		"....eeeeeeee....",
		"...eeeeeeeeee...",
		"................",
		"................",
		"................",
	],
	# Racha: una flecha que no para de subir.
	"t_racha": [
		"................",
		"................",
		".........MMMMM..",
		"..........MMMM..",
		".........MMMMM..",
		"........MMMgMM..",
		".......MMMg..M..",
		"..M...MMMg......",
		".MMM.MMMg.......",
		".gMMMMMg........",
		"..gMMMg.........",
		"...gMg..........",
		"....g...........",
		"................",
		"................",
		"................",
	],
	# Golpe de suerte: un trébol.
	"p_suerte": [
		"................",
		"....MM....MM....",
		"...MMMM..MMMM...",
		"...MMMMM.MMMM...",
		"...MMMMMMMMMM...",
		"....MMMggMMM....",
		"......gggg......",
		"....MMMggMMM....",
		"...MMMMgMMMMM...",
		"...MMMM.gMMMM...",
		"....MM...gMM....",
		"..........g.....",
		"...........g....",
		"................",
		"................",
		"................",
	],
	# Mineros con suerte: una herradura.
	"p_mineros": [
		"................",
		".....yyyyyy.....",
		"...yyyyyyyyyy...",
		"..yyyGGGGGGyyy..",
		"..yyG......yyG..",
		".yyG........yyG.",
		".yyG........yyG.",
		".yyN........yNG.",
		".yyG........yyG.",
		".yyG........yyG.",
		"..yNG......yNG..",
		"..yyyG....yyyG..",
		"...yyG....yyG...",
		"................",
		"................",
		"................",
	],
	# Turnos rotativos: dos flechas en círculo.
	"p_turnos": [
		"................",
		"......BBBB...B..",
		"....BBBBBBBB.B..",
		"...BBB....BBBB..",
		"..BBB......BBB..",
		"..BB.....BBBBB..",
		"..BB............",
		"............GG..",
		"..GGGGG.....GG..",
		"..GGG......GGG..",
		"..GGGG....GGG...",
		"..G.GGGGGGGG....",
		"..G...GGGG......",
		"................",
		"................",
		"................",
	],
	# Dinamita crítica: una bomba con la chispa encendida.
	"p_critica": [
		"................",
		"...........y.y..",
		"............w...",
		"..........t.y.y.",
		".........t......",
		".......EEE......",
		".....EEEEEEE....",
		"....EElEEEEEE...",
		"...EEllEEEEEEe..",
		"...EElEEEEEEEe..",
		"...EEEEEEEEEEe..",
		"....EEEEEEEee...",
		".....EEEEEee....",
		".......eee......",
		"................",
		"................",
	],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var count: int = 0
	for id: String in REUSED:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(REUSED[id]))
		image.convert(Image.FORMAT_RGBA8)
		_save(image, id)
		count += 1
	for id: String in APPROVED:
		_save(_ascii(id, APPROVED[id], DIE_COLORS if id == "o_apostador" else APPROVED_COLORS), id)
		count += 1
	for id: String in DRAWN:
		var image: Image = _ascii(id, DRAWN[id], COLORS)
		_outline(image)
		_save(image, id)
		count += 1
	print("%d íconos en %s" % [count, OUT_DIR])
	quit(0)


func _ascii(id: String, rows: Array, colors: Dictionary) -> Image:
	assert(rows.size() == SIZE, "%s: %d filas" % [id, rows.size()])
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in range(SIZE):
		var row: String = rows[y]
		if row.length() != SIZE:
			push_error("%s fila %d: %d columnas" % [id, y, row.length()])
		for x: int in range(mini(row.length(), SIZE)):
			if row[x] != ".":
				image.set_pixel(x, y, colors[row[x]])
	return image


## El mismo contorno de un píxel que llevan los sprites (tools/generate_sprites.gd).
func _outline(image: Image) -> void:
	var source: Image = image.duplicate()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			if source.get_pixel(x, y).a > 0.5:
				continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = Vector2i(x, y) + step
				if next.x >= 0 and next.y >= 0 and next.x < SIZE and next.y < SIZE and source.get_pixel(next.x, next.y).a > 0.5:
					image.set_pixel(x, y, Palette.OUTLINE)
					break


func _save(image: Image, id: String) -> void:
	var error: Error = image.save_png(ProjectSettings.globalize_path(OUT_DIR + id + ".png"))
	if error != OK:
		push_error("no se pudo guardar %s (%d)" % [id, error])
