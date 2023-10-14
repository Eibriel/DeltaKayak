extends Node3D
class_name AttackingComponent

signal received_attack
signal performed_attack
signal died

var MOVING := true
var ALIVE := true
var DIE_ON_ATTACK := false

# Set this parameters on the Enemy!
var HEALTH: int = 1
var POWER: int = 5
var KB_FORCE: int = 1 # knockback to player
var KB_RESISTANCE: int = 3 # knockback resistance
var XP: int = 1 # XP to drop

func receive_attack(value:int):
	if not ALIVE: return
	HEALTH -= value
	if HEALTH < 0:
		ALIVE = false
	MOVING = false
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func ():
		check_if_alive()
		MOVING = true)
	emit_signal("received_attack")

func check_if_alive():
	if not ALIVE:
		Global.drop_item(Global.ITEMS.XP, XP, global_position)
		Global.player_kills += 1
		queue_free()

func perform_attack():
	if not ALIVE: return
	if DIE_ON_ATTACK:
		queue_free()
		return
	MOVING = false
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func (): MOVING = true)
	emit_signal("performed_attack")

"""

var target_position := Vector3()

# Set this parameters on the Enemy!
var HEALTH: int = 1
var POWER: int = 5
#var SPEED: int = 140
var KB_FORCE: int = 1
var KB_RESISTANCE: int = 3
var XP: int = 1

# health
# power
# speed
# knockback to player
# knockback resistance
# XP

var current_healt: int = HEALTH
var alive:bool = true
var on_attack_cooldown:bool = false

func add_damage(value:int):
	current_healt -= value
	if current_healt < 0:
		alive = false
		visible = false
		Global.drop_item(Global.ITEMS.XP, XP, global_position)
		Global.player_kills += 1
		queue_free()
	target_position = Global.player.global_position + Vector3(0, 1, 0)
	var player_direction: Vector3 = global_position.direction_to(target_position)
	knockback(player_direction)

func knockback(player_direction: Vector3):
	print("Knowckback")
	on_attack_cooldown = true
	var new_position = position - (player_direction.normalized() * 2.0)
	print(position, new_position)
	var tween = create_tween()
	tween.tween_property(self, "position", new_position, 1.1)
	#tween.tween_callback(func (): on_attack_cooldown = false)
"""
