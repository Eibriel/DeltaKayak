extends Node3D
class_name OrbitComponent
## Parent will rotate.
##
## Useful orbiting attacks.

var parent: Node3D

var SPEED = 0.1

func _ready():
	parent = get_parent_node_3d()

func _physics_process(delta):
	parent.rotate_y(SPEED)
