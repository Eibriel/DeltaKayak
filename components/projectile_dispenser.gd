extends Node3D
class_name ProjectileDispenserComponent
## Will spawn Nodes.
##
## Useful to spawn projectiles.

const MODES = {
	"ORBITING":0,
	"FOLLOW":1,
	"PROJECTILE":2,
	"WIPE": 3, # Area ? (thunder, bomb, 
}

var target_enemy: Node3D
var cooldown_time: float = 9999

var parent: Node3D
var hit_enemies := {}

# Set this parameters on the Weapon!
var DAMAGE = 2
#var DISTANCE = 10
var COOLDOWN = 0.8
var HITBOX_DELAY = 1
var MODE = MODES.ORBITING

func _ready():
	parent = get_parent_node_3d()
	DAMAGE = parent.DAMAGE
	COOLDOWN = parent.COOLDOWN


func _physics_process(delta):
	fire_projectile(delta)


func fire_projectile(delta):
	cooldown_time += delta
	var modified_cooldown = COOLDOWN * (Global.player_modifiers.cooldown * 0.01)
	if cooldown_time < modified_cooldown: return
	var enemies: Array = get_alive_enemies()
	if enemies.size() == 0: return
	cooldown_time = 0
	
	target_enemy = enemies.pick_random()
	#print("target", target_enemy)
	var p: Node3D = parent.PROJECTILE.instantiate()
	p.set_meta("projectile_direction", Global.player.global_position.direction_to(target_enemy.global_position))
	p.set_meta("projectile_mode", ProjectileComponent.MODES.ACTIVE)
	parent.projectiles_node.add_child(p)
	p.global_position = Global.player.global_position
	#p.set_direction(Global.player.global_position.direction_to(target_enemy.global_position))
	#p.set_mode(Projectile.MODES.ACTIVE)
	var target_rotation = Vector3(
		target_enemy.global_position.x,
		Global.player.global_position.y,
		target_enemy.global_position.z
	)
	p.look_at_from_position(Global.player.global_position, target_rotation)

func get_alive_enemies() -> Array:
	var alive_enemies := []
	for e in Global.enemies_node.get_children():
		#if not e.alive: continue
		alive_enemies.append(e)
	return alive_enemies
