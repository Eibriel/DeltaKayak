extends RigidBody3D
class_name FloatingElement

@export var model:Node3D

func _ready() -> void:
	model.rotation.x = randf_range(deg_to_rad(0), deg_to_rad(360))

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.get_contact_count() > 0:
		var collision_impulse:float = state.get_contact_impulse(0).length()
		#print("Impulse:", collision_impulse)
		if collision_impulse > 10.0:
			destroy()

func destroy() -> void:
	queue_free()
