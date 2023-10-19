extends Node3D
class_name KnockbackComponent

var parent: Node3D

func _ready():
	parent = get_parent_node_3d()
	parent.connect("received_attack", play_knockback)
	parent.connect("performed_attack", play_knockback)

func play_knockback():
	var target_position = Global.player.global_position + Vector3(0, 1, 0)
	var player_direction = target_position - parent.global_position
	var new_position = parent.position - (player_direction.normalized() * 3.0)
	var tween = create_tween()
	tween.tween_property(parent, "position", new_position, 0.1)
