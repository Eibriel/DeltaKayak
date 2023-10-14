extends Node3D
class_name DamageComponent
## Damage other Nodes entering the Hitbox.
##
## Useful for projectiles.

var parent: Node3D
var hitbox: Area3D

var DAMAGE: int = 2

func _ready():
	parent = get_parent_node_3d()
	hitbox = parent.get_node("Hitbox")
	hitbox.connect("area_entered", _on_hitbox_area_entered)

func _on_hitbox_area_entered(area):
	var enemy_or_player = area.get_parent_node_3d()
	enemy_or_player.receive_attack(DAMAGE)
	parent.perform_attack()
