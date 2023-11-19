extends Node

#signal dropped_item(item_id: int, amount: float, position: Vector2)
signal dropped_item
signal claimed_item(item_id: int, amount: float)

var player: Player
var camera: Camera3D
var enemies_node: Node3D


var player_level := 1
var player_xp := 0.0
var player_time := 0.0
var player_damage := 0.0
var player_kills := 0


var player_modifiers := {
	"max_health": 100., # 100 max health
	"recovery": 0., # 0 health recovery per second
	"armor": 0., # 0 reduced incoming damage
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

var skills = [
	0,
	0,
	0,
	0,
	0
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

func drop_item(item_id: int, amount: float, position: Vector2):
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

func reset():
	player_level = 1
	player_xp = 0
	player_time = 0.0
	player_damage = 0.0
	player_kills = 0


func get_onscreen_position() -> Vector2:
	var corner_intersections := get_corners()
	var point_left: Vector3 = lerp(corner_intersections[0], corner_intersections[1], randf())
	var point_right: Vector3 = lerp(corner_intersections[2], corner_intersections[3], randf())
	
	var v3p: Vector3 = lerp(point_left, point_right, randf())
	return Vector2(v3p.x, v3p.z)

func get_offscreen_position() -> Vector2:
	var corner_intersections := get_corners()
	var p = [0, 0, 0, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3].pick_random()
	var v3p: Vector3 = lerp(corner_intersections[p], corner_intersections[p+1], randf())
	return Vector2(v3p.x, v3p.z)

func get_corners() -> Array:
	#var rect_size := DisplayServer.window_get_size()
	#var rect_size: Vector2 = get_viewport().size
	#print(rect_size)
	#var width := rect_size.y
	#var height := rect_size.x
	var width:int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height:int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var screen_corners = [
		Vector2i(0, 0),
		Vector2i(0, height),
		Vector2i(width, height),
		Vector2i(width, 0),
		Vector2i(0, 0)
	]
	var corner_intersections = []
	for c in screen_corners:
		var rayVector = Global.camera.project_ray_normal(c)
		var rayPoint = Global.camera.project_ray_origin(c)
		var intersection = planeRayIntersection(rayVector,rayPoint, Vector3.ZERO, Vector3.UP)
		corner_intersections.append(intersection)
	return corner_intersections

func planeRayIntersection(rayVector: Vector3, rayPoint: Vector3, planePoint: Vector3, planeNormal: Vector3):
	var diff: Vector3 = rayPoint - planePoint
	var prod1 = diff.dot(planeNormal)
	var prod2 = rayVector.dot(planeNormal)
	var prod3 = prod1 / prod2
	var intersection: Vector3 = rayPoint - (rayVector * prod3)
	return intersection

func is_bit_enabled(mask, index):
	return mask & (1 << index) != 0

func enable_bit(mask, index):
	return mask | (1 << index)

func disable_bit(mask, index):
	return mask & ~(1 << index)
