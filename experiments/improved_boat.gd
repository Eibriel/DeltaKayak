extends RigidBody3D

var time := 999999999999.0
var time_horizon := 1.0
var recalc_time := 0.1
var p0 :Vector2
var p1 :Vector2
var p2 :Vector2
var p3 :Vector2

var last_rotation := 0.0
var angle_to_target := 0.0
var pid_proportional_par := 31.0 #210.0
var pid_integral_par := 0.0 #1000.0
var pid_derivative_par := 0.0 #8180.0

var torque := 0.0
var torque_speed := 10.0

func _physics_process(delta: float) -> void:
	time += delta
	if time > recalc_time:
		time = 0.0
		time_horizon = 2.0 # Aggressiveness
		var _max_force := calculate_parameters(time_horizon)
	var t := time/time_horizon
	#print(t)
	var cb := cubic_bezier_curve(p0, p1, p2, p3, t)
	%CSGSphere3D2.position = Vector3(cb.x, 0, cb.y)*1
	
	var der := second_derivaive_cubic_bezier(p0, p1, p2, p3, t)
	var force_to_apply := Vector3(der.x, 0, der.y)/(time_horizon*time_horizon)
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * force_to_apply.dot(forward_direction)
	apply_central_force(forward_component)
	
	#var rotated_force := force_to_apply.rotated(Vector3.UP, rotation.y)
	#print(rotated_force)
	#var torque := -rotated_force.x
	get_torque_rotation(Global.bi_to_tri(p3))
	apply_torque(Vector3(0, torque, 0) * torque_speed * delta)
	
	%CSGSphere3D.position = Vector3(der.x, 0, der.y)*1
	
	var input_dir:Vector2 = Input.get_vector("left", "right", "up", "down")
	var force_boat2 := Vector3(input_dir.x, 0, input_dir.y)*500.0
	%Boat2.apply_force(force_boat2*delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	#var t := time/time_horizon
	#var der := second_derivaive_cubic_bezier(p0, p1, p2, p3, t)
	#apply_central_force(Vector3(der.x, 0, der.y)*delta)
	#%CSGSphere3D.position = Vector3(der.x, 0, der.y)*1
	#linear_velocity = Vector3(der.x, 0, der.y) / time_horizon
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	state.linear_velocity = forward_component

func get_torque_rotation(target_position: Vector3):
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

func calculate_parameters(time_horizon:float) -> float:
	var start_pos := Vector2(position.x, position.z)
	var start_vel := Vector2(linear_velocity.x, linear_velocity.z)
	var predicted_pos: Vector3= %Boat2.position+(%Boat2.linear_velocity*time_horizon)
	var end_pos := Vector2(predicted_pos.x, predicted_pos.z)
	var end_vel := Vector2(%Boat2.linear_velocity.x, %Boat2.linear_velocity.z)
	p0 = start_pos
	p1 = start_pos + (start_vel * (time_horizon/3.0) )
	p2 = end_pos - (end_vel * (time_horizon/3.0) )
	p3 = end_pos
	%Path3D.curve.set_point_position(0, Global.bi_to_tri(p0))
	%Path3D.curve.set_point_out(0, Global.bi_to_tri(p1)-Global.bi_to_tri(p0))
	%Path3D.curve.set_point_in(1, Global.bi_to_tri(p2)-Global.bi_to_tri(p3))
	%Path3D.curve.set_point_position(1, Global.bi_to_tri(p3))
	
	var max_force_a := Global.bi_to_tri(second_derivaive_cubic_bezier(p0, p1, p2, p3, 0))
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * max_force_a.dot(forward_direction)
	return forward_component.length()
	
func cubic_bezier_curve(p0:Vector2, p1:Vector2, p2:Vector2, p3:Vector2, i:float) -> Vector2:
	var xya:Vector2 = lerp(p0, p1, i)
	var xyb:Vector2 = lerp(p1, p2, i)
	var xyc:Vector2 = lerp(p2, p3, i)
	var xym:Vector2 = lerp(xya, xyb, i)
	var xyn:Vector2 = lerp(xyb, xyc, i)
	var xy:Vector2 = lerp(xym, xyn, i)
	return xy

func second_derivaive_cubic_bezier(p0:Vector2, p1:Vector2, p2:Vector2, p3:Vector2, i:float) -> Vector2:
	var der:=Vector2.ZERO
	der.x = (6.0*(1.0-i)*(p2.x-(2.0*p1.x)+p0.x)) + (6.0*i*(p3.x - (2.0*p2.x) + p1.x))
	der.y = (6.0*(1.0-i)*(p2.y-(2.0*p1.y)+p0.y)) + (6.0*i*(p3.y - (2.0*p2.y) + p1.y))
	return der
