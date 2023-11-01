extends Node

signal dropped_item(item_id: int, amount: float, position: Vector3)
signal claimed_item(item_id: int, amount: float)

var player: Player
var enemies_node: Node3D


var player_level := 1
var player_xp := 0
var player_time := 0.0
var player_damage := 0.0
var player_kills := 0


var player_modifiers := {
	"max_health": 100., # 100 max health
	"recovery": 0., # 0 health recovery per second
	"armor": 1000., # 0 reduced incoming damage
	"move_speed": 100., # 100 % player speed
	"might": 100., # 100 % damage for all attacks
	"area": 100., # 100 % area for all attacks
	"speed": 100., # 100 % speed for all projectiles
	"duration": 100., # 100 % duration of weapon effects
	"amount": 0., # 0 extra projectiles
	"cooldown": 100., # 100 % wait between attacks (goes down)
	"luck": 100., # 100 % modifies drop chances
	"growth": 100., # 100 % modifies XP gained
	"greed": 100., # 100 % modifies coins gained
	"curse": 100., # 100 % modifies enemies speed, health, quantity and frequency
	"magnet": 100., # 100 pickup radius (original 30)
	"revival": 0., # 0 amount of extra lives
	"reroll": 0., # 0 rerolls allowed on level-up
	"skip": 0., # 0 skips allowed on level-up
	"banish": 0., # 0 amount of times player can remove level-up rewards
}

var powerups = {
	# Attacks
	"snowplow": {
		"type": "attack",
		"name": "Snowplow",
		"description": "Push enemies around",
		"requires": "",
		"levels": 3,
		"current_level": 0
	},
	"fireball": {
		"type": "attack",
		"name": "Fireball",
		"description": "Fireballs hitting a random enemy",
		"requires": "",
		"levels": 1,
		"current_level": 0
	},
	"laser": {
		"type": "attack",
		"name": "Laser",
		"description": "A laser rotating around the character",
		"requires": "",
		"levels": 1,
		"current_level": 0
	},
	"lighthouse": {
		"type": "attack",
		"name": "Lighthouse",
		"description": "A rotating light",
		"requires": "",
		"levels": 1,
		"current_level": 0
	},
	"peace_meteor": {
		"type": "attack",
		"name": "Peace Meteor",
		"description": "Meteors falling from the sky",
		"requires": "",
		"levels": 1,
		"current_level": 0
	},
	
	# PowerUps
	"might": {
		"type": "powerup",
		"name": "Might",
		"description": "Increases inflicted damage by 5%",
		"requires": "",
		"stat": "might",
		"adds": 5,
		"ranks": 5,
		"current_rank": 0
	},
	"armor": {
		"type": "powerup",
		"name": "Armor",
		"description": "Increases Armor by 1",
		"requires": "",
		"stat": "armor",
		"adds": 1,
		"ranks": 3,
		"current_rank": 0
	},
	"max_health": {
		"type": "powerup",
		"name": "Max Health",
		"description": "Increases Max Health by 10%",
		"requires": "",
		"stat": "max_health",
		"adds": 10,
		"ranks": 3,
		"current_rank": 0
	},
	"recovery": {
		"type": "powerup",
		"name": "Recovery",
		"description": "Recovers additional 0.1 per second",
		"requires": "",
		"stat": "recovery",
		"adds": 0.1,
		"ranks": 3,
		"current_rank": 0
	},
	"cooldown": {
		"type": "powerup",
		"name": "Colldown",
		"description": "Colldown reduced by 2.5%",
		"requires": "",
		"stat": "cooldown",
		"adds": -2.5,
		"ranks": 2,
		"current_rank": 0
	},
	"area": {
		"type": "powerup",
		"name": "Area",
		"description": "Increases area by 5%",
		"requires": "",
		"stat": "area",
		"adds": 5,
		"ranks": 2,
		"current_rank": 0
	},
	"speed": {
		"type": "powerup",
		"name": "Speed",
		"description": "Projectile speed increased by 10%",
		"requires": "",
		"stat": "area",
		"adds": 10,
		"ranks": 2,
		"current_rank": 0
	},
	# Duration
	# Amount
	"move_speed": {
		"type": "powerup",
		"name": "Move Speed",
		"description": "Character speed increased by 5%",
		"requires": "",
		"stat": "move_speed",
		"adds": 5,
		"ranks": 2,
		"current_rank": 0
	},
	"magnet": {
		"type": "powerup",
		"name": "Magnet",
		"description": "Item pickup area increased by 25%",
		"requires": "",
		"stat": "magnet",
		"adds": 25,
		"ranks": 2,
		"current_rank": 0
	},
	# Luck
	"growth": {
		"type": "powerup",
		"name": "Growth",
		"description": "XP drops value increase by 3%",
		"requires": "",
		"stat": "growth",
		"adds": 3,
		"ranks": 5,
		"current_rank": 0
	}
}

const enemies = [
	"tank",
	"tires",
	"torpedo",
	"drone",
	"glowing_drone",
	"fridge",
	"surface_bubbles",
	"rocket"
]

const weapons = [
	"snowplow",
	"fireball",
	"laser",
	"lighthouse",
	"peace_meteor"
]

const ITEMS = {
	"XP":0,
	"COINS": 1
}

const waves = [
	# 0
	{
		"enemies": ["drone"],
		"min": 15,
		"time": 1.0
	},
	# 1
	{
		"enemies": ["tank", "torpedo"],
		"bosses": ["glowing_drone"],
		"min": 30,
		"time": 1.0
	},
	# 2
	{
		"enemies": ["drone", "torpedo"],
		"min": 50,
		"time": 0.5
	},
	# 3
	{
		"enemies": ["tires"],
		"bosses": ["glowing_drone"],
		"min": 40,
		"time": 0.25
	},
	# 4
	{
		"enemies": ["tires", "surface_bubbles"], 
		"min": 30,
		"time": 1.0
	},
	# 5
	{
		"enemies": ["fridge"],
		"bosses": ["rocket"],
		"min": 10,
		"time": 1.0
	},
	# 6
	{
		"enemies": ["tank", "fridge"],
		"min": 20,
		"time": 0.5
	},
	# 7 - test
	{
		"enemies": [
			"tank",
			"fridge",
			"tires",
			"surface_bubbles",
			"drone",
			"torpedo"
		],
		"bosses": ["rocket"],
		"min": 600,
		"time": 0.04
	},
]

func drop_item(item_id: int, amount: float, position: Vector3):
	emit_signal("dropped_item", item_id, amount, position)

func claim_item(item_id: int, amount: float):
	prints("Claim- id:", item_id, "amount:", amount)
	emit_signal("claimed_item", item_id, amount)

func level_xp(level: int):
	var xp := 5
	if level > 1:
		xp += (level * 10)
	if level > 20:
		xp += ((level-20) * 13)
	if level > 40:
		xp += ((level-40) * 16)
	if level == 40:
		xp += 600
	if level == 60:
		xp += 2400
	return xp

