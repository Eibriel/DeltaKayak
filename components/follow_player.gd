extends Node3D
class_name FollowPlayerComponent
## Parent will follow the player.
##
## Useful for enemies.

var parent: Node3D

var SPEED := 0.5
var LOOK_PLAYER := false

func _ready():
	parent = get_parent_node_3d()
	SPEED = parent.SPEED
	LOOK_PLAYER = parent.LOOK_PLAYER
	if not LOOK_PLAYER:
		parent.rotate_y(randf()*PI*2)

func _physics_process(delta):
	if not parent.MOVING: return
	
	var target_position = Global.player.global_position + Vector3(0, 1, 0)
	var player_direction = target_position - parent.global_position
	var modified_speed = SPEED*0.015 # Dont modify this by Speed!
	parent.position += player_direction.normalized()*delta*modified_speed
	
	if LOOK_PLAYER:
		var target_rotation = Vector3(
			target_position.x,
			parent.global_position.y,
			target_position.z
		)
		parent.look_at(target_rotation)
