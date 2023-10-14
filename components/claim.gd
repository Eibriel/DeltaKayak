extends Node3D
class_name ClaimComponent
## Parent is claimed when a Node enter the Hitbox.
##
## Useful for claimeable objects.

var parent: Node3D
var hitbox: Area3D

func _ready():
	parent = get_parent_node_3d()
	hitbox = parent.get_node("Hitbox")
	hitbox.connect("area_entered", _on_hitbox_area_entered)

func _on_hitbox_area_entered(area):
	parent.claim()
