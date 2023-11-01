extends Node3D
class_name OrbitComponent
## Parent will rotate.
##
## Useful orbiting attacks.

var parent: Node3D

var SPEED: float = 10.0

func _ready():
	parent = get_parent_node_3d()

func _process(delta):
	parent.rotate_y(delta*SPEED*(Global.player_modifiers.speed * 0.01))
