extends RigidBody3D
class_name FloatingElement

@export var model:Node3D

func _ready() -> void:
	model.rotation.x = randf_range(deg_to_rad(0), deg_to_rad(360))
