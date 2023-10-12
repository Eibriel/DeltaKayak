extends Node3D
class_name Projectile

const MODES = {
	"ACTIVE": 0,
	"HIDDEN": 1
}

var DAMAGE: int = 2
var DISTANCE: float = 1*1*1 # Squared distance
var SPEED: float = 3
var DIRECTION: Vector3 = Vector3.FORWARD
var MODE: int = MODES.ACTIVE

var time_alive:= 0.0
#func _ready():
#	set_mode(MODES.HIDDEN)

# TODO destroy projectiles after some time

func _process(delta):
	time_alive += delta
	if time_alive > 10:
		queue_free()

func set_direction(_direction: Vector3) -> void:
	DIRECTION = _direction.normalized()

func set_speed(value: int) -> void:
	SPEED = value

func set_mode(mode: int) -> void:
	MODE = mode
	match mode:
		MODES.ACTIVE:
			visible = true
		MODES.HIDDEN:
			visible = false

func _physics_process(delta):
	if MODE == MODES.HIDDEN: return
	position += DIRECTION*delta*SPEED
	
	for e in Global.enemies_node.get_children():
		if not e.alive: continue
		var target_position = e.global_position
		var distance = global_position.distance_squared_to(target_position)
		if distance < DISTANCE:
			e.add_damage(DAMAGE)
			set_mode(MODES.HIDDEN)
			break
