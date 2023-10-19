extends Node3D
class_name ProjectileComponent
## Parent will move on a direction at a speed.
##
## Useful for projectiles.

const MODES = {
	"ACTIVE": 0,
	"HIDDEN": 1
}

var parent: Node3D
var time_alive:= 0.0

# Set outside
var DAMAGE: int = 2
var DISTANCE: float = 1*1*1 # Squared distance
var SPEED: float = 3
var DIRECTION: Vector3 = Vector3.FORWARD
var MODE: int = MODES.ACTIVE

func _ready():
	parent = get_parent_node_3d()
	DIRECTION = parent.get_meta("projectile_direction")
	# get_meta("projectile_mode", ProjectileComponent.MODES.ACTIVE)

func _process(delta):
	time_alive += delta
	if time_alive > 10:
		parent.queue_free()

func set_direction(_direction: Vector3) -> void:
	DIRECTION = _direction.normalized()

func set_speed(value: int) -> void:
	SPEED = value

func set_mode(mode: int) -> void:
	MODE = mode
	match mode:
		MODES.ACTIVE:
			parent.visible = true
		MODES.HIDDEN:
			parent.visible = false

func _physics_process(delta):
	if MODE == MODES.HIDDEN: return
	parent.global_position += DIRECTION*delta*SPEED*(Global.player_modifiers.speed * 0.01)
	
