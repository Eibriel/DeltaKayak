extends RigidBody3D

func _physics_process(delta: float) -> void:
	return
	if position.x > 0:
		var direction :Vector3 = (get_parent().transform.basis * Vector3.LEFT).normalized()
		var vel := linear_velocity.length()
		var force_amount = remap(vel, 0.0, 1.0, 100.0, 0.0)
		apply_central_force(direction*force_amount)
	
