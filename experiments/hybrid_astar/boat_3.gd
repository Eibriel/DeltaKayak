extends RigidBody2D


var p_longitudinal_damp_coef := 0.99
var p_lateral_damp_coef := 0.99
var p_vel_damp_rel := 0.01
var p_angular_damp_coef := 0.99

func _physics_process(delta: float) -> void:
	pass

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	#prints("RB", rotation)
	var local_velocity_b := state.linear_velocity.rotated(-rotation)
	var longitudinal_damp := clampf(p_longitudinal_damp_coef * (1.0 - (local_velocity_b.x * p_vel_damp_rel)), 0.0, 1.0)
	local_velocity_b.x *= longitudinal_damp
	local_velocity_b.y *= p_lateral_damp_coef
	state.linear_velocity = local_velocity_b.rotated(rotation)
	
	#state.linear_velocity.x = 0.2
	
	state.angular_velocity *= p_angular_damp_coef
