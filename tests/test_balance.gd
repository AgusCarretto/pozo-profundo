extends RefCounted
## Balance completo de prueba para los tests de Economy (profundidad, botín, reliquias, offline).
##
## Es independiente de data/balance.json (que se puede ajustar libremente): los tests
## fijan acá los números del diseño y verifican las fórmulas contra ellos.
## No termina en `_test.gd`, así que tools/run_tests.ps1 no lo corre como un test.

const FULL: Dictionary = {
	"cost_growth": 1.15,
	"generators": [
		{ "id": "a", "name": "A", "base_rate": 1, "base_cost": 15 },
		{ "id": "b", "name": "B", "base_rate": 8, "base_cost": 120 },
	],
	"pick": { "power_base": 2, "cost_base": 50, "cost_growth": 6, "passive_share": 0.03 },
	"depth": { "meters_scale": 25, "gold_scale": 10 },
	"biomes": {
		"meters_each": 150,
		"mult_growth": 1.5,
		"list": [
			{ "id": "earth", "name": "Tierra" },
			{ "id": "rock", "name": "Roca" },
			{ "id": "crystal", "name": "Cristal" },
			{ "id": "magma", "name": "Magma" },
			{ "id": "abyss", "name": "Abismo" },
		],
	},
	"loot": {
		"chance_per_hit": 0.015,
		"chance_per_second": 0.005,
		"rarities": [
			{ "id": "common", "name": "Común", "weight": 78, "seconds": 5, "hits": 15, "relics": 0 },
			{ "id": "rare", "name": "Raro", "weight": 17, "seconds": 20, "hits": 50, "relics": 0 },
			{ "id": "epic", "name": "Épico", "weight": 4.5, "seconds": 60, "hits": 150, "relics": 0 },
			{ "id": "legendary", "name": "Legendario", "weight": 0.5, "seconds": 200, "hits": 500, "relics": 1 },
		],
	},
	"prestige": { "min_depth": 300, "depth_offset": 200, "depth_step": 50, "exponent": 1.3, "bonus_per_relic": 0.25 },
	"offline": { "max_hours": 8, "away_seconds": 120, "efficiency": 1 },
}


## Copia del balance completo sin las secciones indicadas (p. ej. sin "loot" para que el
## azar de los cofres no mueva el oro en un test que cuenta cada moneda).
static func make(without: Array[String] = []) -> Dictionary:
	var copy: Dictionary = FULL.duplicate(true)
	for section: String in without:
		copy.erase(section)
	return copy
