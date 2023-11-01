extends Node3D
class_name SoftCollisionComponent
## Parent will be repelled by other Nodes.
##
## Useful for enemies.

var parent: Node3D
var collisionbox: Area3D
var colliding_nodes: Array[Node3D]
var push_amount := 0
var push_direction: Vector3

var SPEED := 0.5

const MAX_PUSHES := 10

func _ready():
	parent = get_parent_node_3d()
	collisionbox = parent.get_node("Collisionbox")
	collisionbox.connect("area_entered", _on_collisionbox_area_entered)
	collisionbox.connect("area_exited", _on_collisionbox_area_exited)
	SPEED = parent.SPEED

func _physics_process(delta):
	if not parent.MOVING: return
	if colliding_nodes.size() == 0: return
	if push_amount <= 0:
		var node = colliding_nodes.pick_random()
		var target_position: Vector3 = node.global_position
		var player_direction = target_position.direction_to(parent.global_position)
		push_direction = player_direction.normalized()
		push_amount = MAX_PUSHES
	
	parent.global_position += push_direction*delta*SPEED*0.05
	push_amount -= 1

func _on_collisionbox_area_entered(area):
	var node = area.get_parent_node_3d()
	if not colliding_nodes.has(node):
		colliding_nodes.append(node)

func _on_collisionbox_area_exited(area):
	var node = area.get_parent_node_3d()
	if colliding_nodes.has(node):
		colliding_nodes.erase(node)
