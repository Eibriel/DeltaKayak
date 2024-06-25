extends RigidBody3D
class_name Boat3D

var speed := 0.0

var boat_speed := 1.0
var torque_speed := 1.0
var waiting := true

var torque := 0.0

#var target_position := Vector3.ZERO
var current := Vector3.ZERO

var last_rotation := 0.0
var angle_to_target := 0.0
var pid_proportional_par := 0.0
var pid_integral_par := 0.0
var pid_derivative_par := 0.0

var follow_path:Path3D
var distance_to_path := 0.0
var last_path_distance := 0.0
var pid_path_proportional_par := 0.0
var pid_path_integral_par := 0.0
var pid_path_derivative_par := 0.0

func _ready():
	last_rotation = rotation.y
	set_physics_process(false)
	call_deferred("setup_physics")

func setup_physics():
	set_physics_process(true)

func _get_target(_delta: float):
	pass

#
func get_torque_rotation(delta:float):
	#var rotation_vector := global_position.direction_to(target_position)
	#var angle_to_target := Vector3.BACK.signed_angle_to(rotation_vector, Vector3.UP)
	
	#Global.log_text += "\nangle_to_target: %f" % angle_to_target
	var error := -angle_difference(angle_to_target, rotation.y)
	#Global.log_text += "\nrotation.y: %f" % rotation.y
	#Global.log_text += "\nerror: %f" % error
	torque = 0.0
	torque += get_proportional(error) * delta
	torque += get_integral(error) * delta
	torque += get_derivative(error) * delta
	#Global.log_text += "\ntorque: %f" % torque
	last_rotation = rotation.y
	
# PID control Torque
func get_proportional(error) -> float:
	# Minimizes error
	# Adds
	return error * pid_proportional_par

func get_integral(_error) -> float:
	# External perturvations (inertia)
	# Compensates
	var integral = angular_velocity.y * pid_integral_par
	return -integral

func get_derivative(_error) -> float:
	# Error change speed
	# Substracts
	var derivative = last_rotation - rotation.y
	if absf(derivative) > PI:
		if rotation.y > last_rotation:
			derivative = -(last_rotation + rotation.y)
		else:
			derivative = -(rotation.y + last_rotation)
	return derivative * pid_derivative_par
#

func get_torque_path(delta:float):
	var closest := follow_path.curve.get_closest_point(global_position)
	closest = follow_path.to_global(closest)
	distance_to_path = global_position.distance_to(closest)
	var error := distance_to_path
	if global_position.x < closest.x:
		error *= -1
	prints("Error path", error)
	#Global.log_text += "\nrotation.y: %f" % rotation.y
	#Global.log_text += "\nerror: %f" % error
	#var angle_to_target = 0.0
	angle_to_target += get_proportional_path(error) * delta
	angle_to_target += get_integral_path(error) * delta
	angle_to_target += get_derivative_path(error) * delta
	angle_to_target = clampf(angle_to_target, deg_to_rad(-70), deg_to_rad(70))
	#Global.log_text += "\ntorque: %f" % torque
	#target_position = Vector3.BACK.rotated(Vector3.UP, angle_to_target)
	last_path_distance = distance_to_path

# PID control Path
func get_proportional_path(error) -> float:
	# Minimizes error
	# Adds
	return error * pid_path_proportional_par

func get_integral_path(_error) -> float:
	# External perturvations (inertia)
	# Compensates
	# TODO
	# Linear velocity in relation to target point
	var integral = linear_velocity * pid_path_integral_par
	return -integral

func get_derivative_path(_error) -> float:
	# Error change speed
	# Substracts
	var derivative = last_path_distance - distance_to_path
	return derivative * pid_path_derivative_par
#

func _physics_process(delta: float):
	_get_target(delta)
	if waiting: return
	get_torque_path(delta)
	get_torque_rotation(delta)
	prints(torque, angle_to_target)
	apply_torque(Vector3(0, torque, 0) * torque_speed)
	go_forward(boat_speed)

func go_forward(_speed:float):
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	apply_central_force(direction * _speed)

func _integrate_forces(state:PhysicsDirectBodyState3D):
	# TODO what happens when going backwards?
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	# Gets only the energy going forward
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	# Gets only the energy not going forward
	var side_component: Vector3 = state.linear_velocity - forward_component
	# Transfers the energy not going forward to going forward
	var transferred_energy: Vector3 = forward_direction * side_component.length()
	var side_drag := 0.99 # TODO depends on velocity
	var calculated_velocity := Vector3.ZERO
	calculated_velocity += side_component * side_drag
	calculated_velocity += forward_component
	calculated_velocity += transferred_energy * (1.0 - side_drag)
	calculated_velocity += current
	state.linear_velocity = calculated_velocity
