extends RefCounted
## Paleta de Tiny Dungeon (Kenney, CC0): los 27 colores de todo el pack.
##
## Los sprites que se dibujan por código (tools/generate_sprites.gd) usan SOLO estos colores,
## y tests/assets_test.gd verifica que ninguno se salga. La UI también los usa para tintes.
## Los nombres describen el color, no su uso: el uso lo decide quien los toma.

const OUTLINE: Color = Color8(63, 38, 49) # 3f2631 el contorno de todos los sprites del pack
const NAVY: Color = Color8(38, 43, 68) # 262b44
const MAROON: Color = Color8(118, 59, 54) # 763b36
const TERRA: Color = Color8(189, 108, 74) # bd6c4a
const ORANGE: Color = Color8(207, 130, 84) # cf8254
const CLAY: Color = Color8(225, 154, 101) # e19a65
const SAND: Color = Color8(234, 165, 108) # eaa56c
const SAND_LIGHT: Color = Color8(247, 194, 130) # f7c282
const PEACH: Color = Color8(254, 201, 156) # fec99c
const STEEL: Color = Color8(139, 155, 180) # 8b9bb4
const STEEL_LIGHT: Color = Color8(192, 203, 220) # c0cbdc
const STEEL_PALE: Color = Color8(170, 183, 204) # aab7cc
const SLATE: Color = Color8(82, 96, 124) # 52607c
const SLATE_LIGHT: Color = Color8(90, 105, 136) # 5a6988
const FROST: Color = Color8(228, 237, 249) # e4edf9
const WHITE: Color = Color8(255, 255, 255) # ffffff
const MINT: Color = Color8(67, 225, 179) # 43e1b3
const AQUA: Color = Color8(105, 255, 212) # 69ffd4
const GREEN: Color = Color8(37, 149, 106) # 25956a
const RED: Color = Color8(232, 69, 55) # e84537
const SALMON: Color = Color8(255, 112, 109) # ff706d
const PURPLE: Color = Color8(155, 76, 163) # 9b4ca3
const PINK: Color = Color8(209, 118, 208) # d176d0
const BLUE: Color = Color8(0, 153, 219) # 0099db
const CYAN: Color = Color8(117, 227, 255) # 75e3ff
const GOLD: Color = Color8(254, 174, 52) # feae34
const YELLOW: Color = Color8(254, 231, 97) # fee761

## Los 27, para validar que un sprite no se sale de la paleta.
const ALL: Array[Color] = [
	OUTLINE, NAVY, MAROON, TERRA, ORANGE, CLAY, SAND, SAND_LIGHT, PEACH,
	STEEL, STEEL_LIGHT, STEEL_PALE, SLATE, SLATE_LIGHT, FROST, WHITE,
	MINT, AQUA, GREEN, RED, SALMON, PURPLE, PINK, BLUE, CYAN, GOLD, YELLOW,
]
