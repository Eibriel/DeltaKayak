extends RigidBody3D
class_name Boat3D

var speed := 0.0

var boat_speed_multiplyer := 10.0
var boat_speed := 1.0
var torque_speed := 10.0
var waiting := true

var torque := 0.0

var target_position := Vector3.ZERO
var current := Vector3.ZERO

var last_rotation := 0.0
var angle_to_target := 0.0
var pid_proportional_par := 31.0 #210.0
var pid_integral_par := 0.0 #1000.0
var pid_derivative_par := 0.0 #8180.0

var follow_path:Path3D
var distance_to_path := 0.0
var last_path_distance := 0.0
var pid_path_proportional_par := 7.0
var pid_path_integral_par := 0.0
var pid_path_derivative_par := 7500.0

#Pa: 135 Ia: 713.9 Da: 8180
#Pp: 47 Ip: 0.0 Dp: 0

var path_target_indicator:CSGBox3D

func _ready():
	last_rotation = rotation.y
	set_physics_process(false)
	call_deferred("setup_physics")
	path_target_indicator = CSGBox3D.new()
	add_child(path_target_indicator)

func setup_physics():
	set_physics_process(true)

func _get_target(_delta: float):
	pass

#
func get_torque_rotation(delta:float):
	var rotation_vector := global_position.direction_to(target_position)
	var angle_to_target := Vector3.BACK.signed_angle_to(rotation_vector, Vector3.UP)
	
	#Global.log_text += "\nangle_to_target: %f" % angle_to_target
	var error := angle_difference(angle_to_target, rotation.y)
	#Global.log_text += "\nrotation.y: %f" % rotation.y
	#Global.log_text += "\nerror: %f" % error
	var poportional := get_proportional(error)
	var integral := get_proportional(error)
	var derivative := get_derivative(error)
	#prints(poportional, integral, derivative)
	torque = 0.0
	torque += poportional * delta
	torque += integral * delta
	torque += derivative * delta
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
	#prints("Error path", error)
	#Global.log_text += "\nrotation.y: %f" % rotation.y
	#Global.log_text += "\nerror: %f" % error
	#var angle_to_target = 0.0
	angle_to_target += get_proportional_path(error) * delta
	angle_to_target += get_integral_path(error, closest) * delta
	angle_to_target += get_derivative_path(error) * delta
	angle_to_target = clampf(angle_to_target, deg_to_rad(-120), deg_to_rad(120))
	
	# Combine with target in path
	var closest_offset := follow_path.curve.get_closest_offset(global_position)
	#print(closest_offset)
	var path_target_position := follow_path.curve.sample_baked(closest_offset + 7, true)
	path_target_position = follow_path.to_global(path_target_position)
	path_target_indicator.global_position = path_target_position
	var rotation_vector_to_path_target := global_position.direction_to(path_target_position)
	var angle_to_path_target := Vector3.BACK.signed_angle_to(rotation_vector_to_path_target, Vector3.UP)
	angle_to_target = (angle_to_target*0.0) + angle_to_path_target
	#%PathTargetIndicator.global_position = path_target_position
	#Global.log_text += "\ntorque: %f" % torque
	#target_position = Vector3.BACK.rotated(Vector3.UP, angle_to_target)
	last_path_distance = distance_to_path

# PID control Path
func get_proportional_path(error) -> float:
	# Minimizes error
	# Adds
	return error * pid_path_proportional_par

func get_integral_path(_error, closest:Vector3) -> float:
	# External perturvations (inertia)
	# Compensates
	# TODO
	var test_global_position := Vector3.ZERO
	var test_closest := Vector3(0, 1, 1)
	var test_linear_velocity := Vector3(0, 1, 1)
	var test_path_direction := test_global_position.direction_to(test_closest)
	var test_path_component: Vector3 = test_path_direction * test_linear_velocity.dot(test_path_direction)
	#print(test_path_component.dot(test_path_direction))
	#
	var path_direction := global_position.direction_to(closest)
	var path_component: Vector3 = path_direction * linear_velocity.dot(path_direction)
	var integral = path_component.dot(path_direction) * pid_path_integral_par
	if global_position.x < closest.x:
		integral *= -1
	#print(integral)
	return -integral

func get_derivative_path(_error) -> float:
	# Error change speed
	# Substracts
	var derivative = last_path_distance - distance_to_path
	return -derivative * pid_path_derivative_par
#

func _physics_process(delta: float):
	_get_target(delta)
	if waiting: return
	#get_torque_path(delta)
	get_torque_rotation(delta)
	#prints(torque, angle_to_target)
	
	apply_torque(Vector3(0, torque, 0) * torque_speed * remap(linear_velocity.length(), 0, 3, 0, 1))
	go_forward(boat_speed * boat_speed_multiplyer)

func go_forward(_speed:float):
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	apply_central_force(direction * _speed)

func _integrate_forces(state:PhysicsDirectBodyState3D):
	_handle_contacts(state)
	#state.linear_velocity *= 0.999
	state.angular_velocity *= 0.999
	# TODO what happens when going backwards?
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	# Gets only the energy going forward
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	# Gets only the energy not going forward
	var side_component: Vector3 = state.linear_velocity - forward_component
	#prints("side_component",side_component)
	# Transfers the energy not going forward to going forward
	var transferred_energy: Vector3 = forward_direction * side_component.length()
	var side_drag := 0.99 # TODO depends on velocity
	var calculated_velocity := Vector3.ZERO
	calculated_velocity += side_component * side_drag
	calculated_velocity += forward_component
	calculated_velocity += transferred_energy * (1.0 - side_drag)
	calculated_velocity += current
	state.linear_velocity = calculated_velocity

func _handle_contacts(state: PhysicsDirectBodyState3D):
	pass
