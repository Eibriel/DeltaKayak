extends Node3D
class_name AttackingComponent

signal received_attack
signal performed_attack
signal died

var MOVING := true
var ALIVE := true
var DIE_ON_ATTACK := false

# Set this parameters on the Enemy/Weapon!
var HEALTH: float = 1.
var POWER: float = 5.
var KB_FORCE: float = 1. # knockback to player
var KB_RESISTANCE: float = 3. # knockback resistance
var XP: float = 1. # XP to drop

func receive_attack(value:float):
	var modified_power = value * (Global.player_modifiers.might * 0.01)
	prints("POWER:", modified_power, "HEALTH:", HEALTH)
	if not ALIVE: return
	HEALTH -= modified_power
	if HEALTH <= 0:
		ALIVE = false
	MOVING = false
	var tween = create_tween()
	tween.tween_interval(1.0)
	if ALIVE:
		tween.tween_callback(func ():
			MOVING = true)
	else:
		destroy_element()
	emit_signal("received_attack")

func destroy_element():
	Global.drop_item(Global.ITEMS.XP, XP, global_position)
	Global.player_kills += 1
	queue_free()

func perform_attack():
	if not ALIVE: return
	# DIE_ON_ATTACK
	# Useful for projectiles
	# that are destroyed on impact
	if DIE_ON_ATTACK:
		queue_free()
		return
	MOVING = false
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func (): MOVING = true)
	emit_signal("performed_attack")
