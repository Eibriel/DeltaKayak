extends RigidBody3D
class_name Boat3D

var time := 999999999999.0
var time_horizon := 1.0
var recalc_time := 0.1
var p0 :Vector2
var p1 :Vector2
var p2 :Vector2
var p3 :Vector2

var speed := 0.0
var force_limit := 5.0

var boat_speed_multiplyer := 10.0
var boat_speed := 1.0
var torque_speed := 10.0
var waiting := false

var last_position:Vector3
var real_velocity_integral:Vector3
var real_velocity:Vector3
var last_rotationb:float
var last_angle_to_target:float
var real_angular_velocity:float
var about_to_collide:=false

var torque := 0.0
var last_applied_torque := 0.0

var target_position := Vector3.ZERO
var target_velocity := Vector3.ZERO
var current := Vector3.ZERO

var last_rotation := 0.0
var angle_to_target := 0.0
var pid_proportional_par := 200.0#175.0 #31.0 #210.0
var pid_integral_par := 760.0 #1000.0
var pid_derivative_par := 20140.0 #8180.0

var path_visualization:Path3D

var last_applied_force: Vector3

var inside_turn_radius:=false

func _ready():
	last_rotation = rotation.y
	last_position = position
	set_physics_process(false)
	#call_deferred("setup_physics")
	#path_target_indicator = CSGBox3D.new()
	#add_child(path_target_indicator)
	path_visualization = Path3D.new()
	path_visualization.top_level = true
	path_visualization.curve = Curve3D.new()
	path_visualization.curve.add_point(Vector3.ZERO, Vector3.ONE, Vector3.ONE)
	path_visualization.curve.add_point(Vector3.ONE, Vector3.ONE, Vector3.ONE)
	add_child(path_visualization)
	

#func setup_physics():
#	set_physics_process(true)

func _get_target(_delta: float):
	pass

#
func get_torque_rotation(_target_position:Vector3):
	var rotation_vector := global_position.direction_to(_target_position)
	var _angle_to_target := Vector3.BACK.signed_angle_to(rotation_vector, Vector3.UP)
	last_angle_to_target = -_angle_to_target
	
	#Global.log_text += "\nangle_to_target: %f" % angle_to_target
	var error := angle_difference(_angle_to_target, rotation.y)
	#Global.log_text += "\nrotation.y: %f" % rotation.y
	#Global.log_text += "\nerror: %f" % error
	var poportional := get_proportional(error)
	var integral := get_integral(error)
	var derivative := get_derivative(error)
	#Global.log_text += "\npoportional: %f" % poportional
	#Global.log_text += "\nintegral: %f" % integral
	#Global.log_text += "\nderivative: %f" % derivative
	#prints(poportional, integral, derivative)
	torque = 0.0
	torque += poportional
	torque += integral
	torque += derivative
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

func _physics_process(delta: float):
	_get_target(delta)
	#prints(last_position, position, delta)
	var new_real_velocity:Vector3 = (last_position - position) / delta
	real_velocity_integral = real_velocity-new_real_velocity
	real_velocity = new_real_velocity
	last_position = position
	#
	var new_real_angular_velocity:float = (rotation.y - last_rotationb) / delta
	real_angular_velocity = new_real_angular_velocity
	last_rotationb = rotation.y
	if waiting:
		return
	"""#get_torque_path(delta)
	get_torque_rotation(delta)
	#prints(torque, angle_to_target)
	
	apply_torque(Vector3(0, torque, 0) * torque_speed * remap(linear_velocity.length(), 0, 3, 0, 1))
	go_forward(boat_speed * boat_speed_multiplyer)"""
	time += delta
	if time > recalc_time:
		time = 0.0
		time_horizon = 2.0 # Aggressiveness
		var _max_force := calculate_parameters(time_horizon)
	var t := time/time_horizon
	#print(t)
	var _cb := cubic_bezier_curve(p0, p1, p2, p3, t)
	#%CSGSphere3D2.position = Vector3(cb.x, 0, cb.y)*1
	
	var der := second_derivaive_cubic_bezier(p0, p1, p2, p3, t)
	var force_to_apply := Vector3(der.x, 0, der.y)/(time_horizon*time_horizon)
	if inside_turn_radius:
		force_to_apply = real_velocity * 1.5
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * force_to_apply.dot(forward_direction)
	
	if false:
		#Cheat
		var sensor_data := _get_sensor_data()
		if sensor_data["right_front"] or sensor_data["right_back"]:
			Global.log_text += "\nRight"
			var left_direction := (transform.basis * Vector3.LEFT).normalized()
			apply_central_force(left_direction*10)
			if sensor_data["right_front"] and not sensor_data["right_back"]:
				apply_torque(Vector3(0, 100, 0) * torque_speed * delta)
			elif not sensor_data["right_front"] and sensor_data["right_back"]:
				apply_torque(Vector3(0, -100, 0) * torque_speed * delta)
		if sensor_data["left_front"] or sensor_data["left_back"]:
			var right_direction := (transform.basis * Vector3.RIGHT).normalized()
			apply_central_force(right_direction*10)
			if sensor_data["left_front"] and not sensor_data["left_back"]:
				apply_torque(Vector3(0, -100, 0) * torque_speed * delta)
			elif not sensor_data["left_front"] and sensor_data["left_back"]:
				apply_torque(Vector3(0, 100, 0) * torque_speed * delta)
		if sensor_data["behind"]:
			apply_central_force(forward_direction*50)
		if sensor_data["ahead"]:
			apply_central_force(-forward_direction*50)
	
	if forward_component.length() > force_limit:
		forward_component = forward_component.normalized() * force_limit
	
	apply_central_force(forward_component)
	#Global.log_text += "\nEnemy forward_component: %.2f" % forward_component.length()
	last_applied_force = forward_component
	#var rotated_force := force_to_apply.rotated(Vector3.UP, rotation.y)
	#print(rotated_force)
	#var torque := -rotated_force.x
	get_torque_rotation(Global.bi_to_tri(p3))
	var torque_to_apply = Vector3(0, torque, 0) * torque_speed * delta
	apply_torque(torque_to_apply)
	last_applied_torque = torque_to_apply.y
	#Global.log_text += "\ntorque: %.2f" % torque
	#%CSGSphere3D.position = Vector3(der.x, 0, der.y)*1

#func go_forward(_speed:float):
	#var direction := (transform.basis * Vector3.FORWARD).normalized()
	#apply_central_force(direction * _speed)

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

func _handle_contacts(_state: PhysicsDirectBodyState3D):
	pass

func _get_sensor_data() -> Dictionary:
	return {}

# Cubic Bezier path planning
func calculate_parameters(_time_horizon:float) -> float:
	var start_pos := Global.tri_to_bi(position)
	var start_vel := Global.tri_to_bi(linear_velocity)
	#var predicted_pos: Vector3= target_position+(target_velocity*_time_horizon)
	#var end_pos := Global.tri_to_bi(predicted_pos)
	var end_pos := Global.tri_to_bi(target_position)
	var end_vel :=  Global.tri_to_bi(target_velocity)
	p0 = start_pos
	p1 = start_pos + (start_vel * (_time_horizon/3.0) )
	p2 = end_pos - (end_vel * (_time_horizon/3.0) )
	p3 = end_pos
	path_visualization.curve.set_point_position(0, Global.bi_to_tri(p0, 0.2))
	path_visualization.curve.set_point_out(0, Global.bi_to_tri(p1)-Global.bi_to_tri(p0))
	path_visualization.curve.set_point_in(1, Global.bi_to_tri(p2)-Global.bi_to_tri(p3))
	path_visualization.curve.set_point_position(1, Global.bi_to_tri(p3, 0.2))
	
	var max_force_a := Global.bi_to_tri(second_derivaive_cubic_bezier(p0, p1, p2, p3, 0))
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * max_force_a.dot(forward_direction)
	return forward_component.length()
	
func cubic_bezier_curve(_p0:Vector2, _p1:Vector2, _p2:Vector2, _p3:Vector2, i:float) -> Vector2:
	var xya:Vector2 = lerp(_p0, _p1, i)
	var xyb:Vector2 = lerp(_p1, _p2, i)
	var xyc:Vector2 = lerp(_p2, _p3, i)
	var xym:Vector2 = lerp(xya, xyb, i)
	var xyn:Vector2 = lerp(xyb, xyc, i)
	var xy:Vector2 = lerp(xym, xyn, i)
	return xy

func second_derivaive_cubic_bezier(_p0:Vector2, _p1:Vector2, _p2:Vector2, _p3:Vector2, i:float) -> Vector2:
	var der:=Vector2.ZERO
	der.x = (6.0*(1.0-i)*(_p2.x-(2.0*_p1.x)+_p0.x)) + (6.0*i*(_p3.x - (2.0*_p2.x) + _p1.x))
	der.y = (6.0*(1.0-i)*(_p2.y-(2.0*_p1.y)+_p0.y)) + (6.0*i*(_p3.y - (2.0*_p2.y) + _p1.y))
	return der
