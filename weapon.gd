extends Node3D
class_name Weapon

const MODES = {
	"ORBITING":0,
	"FOLLOW":1,
	"PROJECTILE":2,
	"WIPE": 3,
}

var target_enemy: Enemy
var cooldown_time: float = 9999
var projectiles_node: Node3D
var orbiting_axis: Node3D

var hit_enemies := {}

# Set this parameters on the Weapon!
var DAMAGE = 2
var DISTANCE = 10
var COOLDOWN = 1
var HITBOX_DELAY = 1
var PROJECTILE
var MODE = MODES.ORBITING

#func _ready():
#	call_deferred("initialize")

func _physics_process(delta):
	match MODE:
		MODES.PROJECTILE:
			fire_projectile(delta)
		MODES.ORBITING:
			orbit(delta)


func initialize():
	match MODE:
		MODES.ORBITING:
			orbiting_axis = $orbiting_axis
	

func orbit(delta):
	if orbiting_axis == null:
		initialize()
	orbiting_axis.rotate_y(0.1)
	var enemies: Array = get_alive_enemies()
	for e in enemies:
		e = e as Node3D
		if hit_enemies.has(e):
			hit_enemies[e] -= delta
			if hit_enemies[e] < 0:
				hit_enemies.erase(e)
	for p in orbiting_axis.get_children():
		p = p as Node3D
		for e in enemies:
			e = e as Node3D
			if hit_enemies.has(e): continue
			var dist = p.global_position.distance_squared_to(e.global_position)
			if dist < DISTANCE:
				print("HIT")
				e.add_damage(DAMAGE)
				hit_enemies[e] = HITBOX_DELAY


func fire_projectile(delta):
	cooldown_time += delta
	if cooldown_time < COOLDOWN: return
	var enemies: Array = get_alive_enemies()
	if enemies.size() == 0: return
	cooldown_time = 0
	
	target_enemy = enemies.pick_random()
	#print("target", target_enemy)
	var p: Projectile = PROJECTILE.instantiate()
	p.position = Global.player.position
	p.set_direction(Global.player.global_position.direction_to(target_enemy.global_position))
	p.set_mode(Projectile.MODES.ACTIVE)
	projectiles_node.add_child(p)

func get_alive_enemies() -> Array:
	var alive_enemies := []
	for e in Global.enemies_node.get_children():
		if not e.alive: continue
		alive_enemies.append(e)
	return alive_enemies
