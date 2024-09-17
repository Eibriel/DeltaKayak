extends RigidBody2D


var p_longitudinal_damp_coef := 0.99
var p_lateral_damp_coef := 0.99
var p_vel_damp_rel := 0.01
var p_angular_damp_coef := 0.99

var simple_boat_model := SimpleBoatModel.new()

func _physics_process(delta: float) -> void:
	pass

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var dvel := simple_boat_model.damped_velocity(
		state.linear_velocity,
		state.angular_velocity,
		simple_boat_model.ticks_per_second,
		simple_boat_model.rotation
	)
	state.linear_velocity = dvel[0]
	state.angular_velocity = dvel[1]
