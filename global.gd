extends Node

signal dropped_item(item_id: int, amount: int, position: Vector3)
signal claimed_item(item_id: int, amount: int)

var player: Player
var enemies_node: Node3D


var player_level := 1
var player_xp := 0
var player_time := 0.0
var player_damage := 0.0
var player_kills := 0


var player_modifiers := {
	"max_health": 1000, # 100 max health
	"recovery": 0, # health recovery per second
	"armor": 0, # reduced incoming damage
	"move_speed": 100, # % player speed
	"might": 100, # % damage for all attacks
	"area": 100, # 100 % area for all attacks
	"speed": 100, # % speed for all projectiles
	"duration": 100, # % duration of weapon effects
	"amount": 0, # extra projectiles
	"cooldown": 100, # % wait between attacks (goes down)
	"luck": 100, # % modifies drop chances
	"growth": 100, # % modifies XP gained
	"greed": 100, # % modifies coins gained
	"curse": 100, # % modifies enemies speed, health, quantity and frequency
	"magnet": 100, # pickup radius (original 30)
	"revival": 0, # amount of extra lives
	"reroll": 0, # rerolls allowed on level-up
	"skip": 0, # skips allowed on level-up
	"banish": 0, # amount of times player can remove level-up rewards
}

const enemies = [
	"tank",
	"tires",
	"torpedo",
	"drone"
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

func drop_item(item_id: int, amount: int, position: Vector3):
	emit_signal("dropped_item", item_id, amount, position)

func claim_item(item_id: int, amount: int):
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
		
	
	
	
	
	
	
